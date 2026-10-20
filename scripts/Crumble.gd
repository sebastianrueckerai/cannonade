class_name Crumble
extends Node3D
## A wall block struck down breaks up (I62): the pieces of assets/art/3d/wall_rubble.glb, a storey's of
## wall_rubble_upper.glb, cut from the plain block by art/game/assets/3d/wall_fracture.py, fly from the shot as rigid
## bodies in the block's own material, land on the slab and on the standing walls (BuildingPlace._wall_body), and
## sink into the ground. The heap stands under the block's tile at the block's art, so the slab top is its y 0.
## Every look wears the plain block's pieces for now.

const WallComp := preload("res://scripts/components/Wall.gd")
const LIFE := 4.0
const SINK := 1.0
## The pieces' collision shrinks so neighbours do not start inside each other.
const SHRINK := 0.95

static var _shapes := {}
static var _stone: PhysicsMaterial


## Breaks `block` up before it dies. `from` is where the shot came from, Vector3.INF for no side.
static func crumble(block: Node3D, from: Vector3) -> Crumble:
	var art: Node3D = block.get_node_or_null("Art")
	var material := WallComp.material(art)
	if material == null:
		return null
	var rubble := Art.instance("wall_rubble_upper" if str(art.get_meta("art_id", "")).ends_with("_upper") else "wall_rubble")
	if rubble == null:
		return null
	var heap := Crumble.new()
	block.get_parent().add_child(heap)
	heap.global_transform = art.global_transform
	heap._ground()
	for other in block.get_parent().get_children():
		if other is Crumble and other != heap:
			other._wake()  # rubble lying on the block falls with it
	var dir := (art.global_position - from) * Vector3(1, 0, 1) if from.is_finite() else Vector3.ZERO
	if dir.length() < 0.1:
		dir = Vector3(Art._rng.randf() - 0.5, 0.0, Art._rng.randf() - 0.5)
	dir = dir.normalized()
	for part in rubble.find_children("*", "MeshInstance3D", true, false):
		var body := RigidBody3D.new()
		body.transform = Art._rel(part, rubble)
		body.physics_material_override = _stone_material()
		var mi := MeshInstance3D.new()
		mi.mesh = part.mesh
		mi.material_override = material
		body.add_child(mi)
		var shape := CollisionShape3D.new()
		shape.shape = _shape(part.mesh)
		shape.scale = Vector3.ONE * SHRINK
		body.add_child(shape)
		heap.add_child(body)
		body.linear_velocity = dir * (1.5 + 2.5 * Art._rng.randf()) + Vector3.UP * (1.0 + 3.0 * Art._rng.randf()) + _scatter(0.8)
		body.angular_velocity = _scatter(8.0)
	rubble.free()
	heap._fade()
	return heap


func _ground() -> void:
	var ground := StaticBody3D.new()
	var plane := CollisionShape3D.new()
	plane.shape = WorldBoundaryShape3D.new()
	ground.add_child(plane)
	add_child(ground)


func _wake() -> void:
	for b in get_children():
		if b is RigidBody3D:
			b.sleeping = false


## The pieces lie still for a while, then sink into the ground and go.
func _fade() -> void:
	var tw := create_tween()
	tw.tween_interval(LIFE - SINK)
	tw.tween_callback(func():
		for b in get_children():
			if b is RigidBody3D:
				b.freeze = true)
	tw.tween_property(self, "position:y", -0.6, SINK).as_relative()
	tw.tween_callback(queue_free)


static func _shape(mesh: Mesh) -> Shape3D:
	if not _shapes.has(mesh):
		_shapes[mesh] = mesh.create_convex_shape(true, false)
	return _shapes[mesh]


static func _stone_material() -> PhysicsMaterial:
	if _stone == null:
		_stone = PhysicsMaterial.new()
		_stone.friction = 0.9
		_stone.bounce = 0.15
	return _stone


static func _scatter(s: float) -> Vector3:
	return Vector3(Art._rng.randf() - 0.5, Art._rng.randf() - 0.5, Art._rng.randf() - 0.5) * 2.0 * s
