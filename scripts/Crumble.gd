class_name Crumble
extends Node3D
## A thing struck down breaks up (I62, I69): the pieces of assets/art/3d/<look>_rubble.glb, cut from the model by
## art/game/assets/3d/fracture.py, a node per part holding its pieces, fly from the shot as rigid bodies in the part's
## own material from where the part stands as it dies, land on the slab and on the standing walls
## (BuildingPlace._wall_body) and sink into the ground. Walls and their storeys, guns, the castle as it falls to
## ruins, trees, bushes and boulders. A wall look without pieces of its own wears the plain block's. The heap stands
## under the thing's tile at the art's foot, so the slab top is its y 0. The project runs Jolt physics for these bodies,
## the game's only ones.

const LIFE := 4.0
const SINK := 1.0
## The pieces' collision shrinks so neighbours do not start inside each other.
const SHRINK := 0.95
## The physics layer of a decoration's pieces.
const DEBRIS := 2

static var _shapes := {}
static var _stone: PhysicsMaterial
## One ground plane at the slab top for every heap of the game: an infinite plane per heap paired every piece with
## every heap's plane.
static var _floor: StaticBody3D


## Breaks `go` up before it dies: a building with its art under it, or a decoration, which is its own art. `from` is
## where the shot came from, Vector3.INF for no side. `look` names the pieces instead of the art's own look (the
## castle falls as castle_d3 whatever it wore). Null when the look has no pieces.
static func crumble(go: Node3D, from: Vector3, look := "") -> Crumble:
	var art: Node3D = go if go.has_meta("art_look") else go.get_node_or_null("Art")
	if art == null:
		return null
	if look == "":
		look = art.get_meta("art_look", "")
	var rubble := Art.instance(rubble_id(look))
	if rubble == null:
		return null
	# another look than the one worn lends its parts' places and materials
	var lent: Node3D = Art.instance(look) if look != art.get_meta("art_look", "") else null
	var heap := Crumble.new()
	go.get_parent().add_child(heap)
	heap.global_position = art.global_position
	_ground(go.get_tree(), art.global_position.y)
	for other in go.get_parent().get_children():
		if other is Crumble and other != heap:
			other._wake()  # rubble lying on the thing falls with it
	var dir := (art.global_position - from) * Vector3(1, 0, 1) if from.is_finite() else Vector3.ZERO
	if dir.length() < 0.1:
		dir = Vector3(Art._rng.randf() - 0.5, 0.0, Art._rng.randf() - 0.5)
	dir = dir.normalized()
	for group in rubble.get_children():
		var part: Node3D = (go if lent == null else lent).find_child(group.name, true, false)
		var frame: Transform3D = art.global_transform
		if part != null:
			frame = part.global_transform if lent == null else art.global_transform * Art._rel(part, lent)
		var material: Material = null
		if part is MeshInstance3D:
			material = part.material_override if part.material_override != null else part.get_active_material(0)
		for piece in group.find_children("*", "MeshInstance3D", true, false):
			var t: Transform3D = frame * piece.transform
			var scale := t.basis.get_scale()
			var body := RigidBody3D.new()
			body.name = piece.name
			body.physics_material_override = _stone_material()
			if go == art:
				# a decoration's pieces skip each other, the ground and the walls only: a tile of five trees throws 30
				body.collision_layer = DEBRIS
				body.collision_mask = 1
			var mi := MeshInstance3D.new()
			mi.mesh = piece.mesh
			mi.material_override = material
			mi.scale = scale
			body.add_child(mi)
			var shape := CollisionShape3D.new()
			shape.shape = _shape(piece.mesh)
			shape.scale = scale * SHRINK
			body.add_child(shape)
			heap.add_child(body)
			body.global_transform = Transform3D(t.basis.orthonormalized(), t.origin)
			body.linear_velocity = dir * (1.5 + 2.5 * Art._rng.randf()) + Vector3.UP * (1.0 + 3.0 * Art._rng.randf()) + _scatter(0.8)
			body.angular_velocity = _scatter(8.0)
	rubble.free()
	if lent != null:
		lent.free()
	heap._fade()
	return heap


## The pieces of a look: <look>_rubble; a wall look without its own wears the plain block's.
static func rubble_id(look: String) -> String:
	if Art.has_model(look + "_rubble") or not look.begins_with("wall"):
		return look + "_rubble"
	return "wall_upper_rubble" if look.ends_with("_upper") else "wall_rubble"


## Under the tree's root, which outlives every scene: a game can crumble a tree before it is the current scene.
static func _ground(tree: SceneTree, y: float) -> void:
	if U.alive(_floor) and _floor.is_inside_tree():
		return
	_floor = StaticBody3D.new()
	var plane := CollisionShape3D.new()
	plane.shape = WorldBoundaryShape3D.new()
	_floor.add_child(plane)
	tree.root.add_child(_floor)
	_floor.global_position = Vector3(0, y, 0)


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
