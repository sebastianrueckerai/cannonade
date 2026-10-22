extends Node
## Global helpers replacing the Unity engine API used by the original game
## (autoload "U"): game time, Unity style random numbers, component lookup,
## instantiation, colours and the projectile registry that replaces the
## "projectiles" physics layer.

## Seconds since the game started (Unity's Time.time). Advanced before any
## other node is processed.
var time := 0.0
## All projectiles currently in flight (TileImpactor components).
var projectiles: Array = []


func _ready() -> void:
	process_priority = -1000
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	time += delta


func reset() -> void:
	time = 0.0
	projectiles.clear()


# ------------------------------------------------------------------ objects
func alive(n) -> bool:
	return n != null and is_instance_valid(n) and not n.is_queued_for_deletion()


func destroy(n) -> void:
	if alive(n):
		if n is Node and n.get_parent() != null:
			n.get_parent().remove_child(n)
		n.queue_free()


## Unity's GetComponent<T>(): components are child nodes named after their script.
func comp(go, name: String) -> Node:
	if not alive(go):
		return null
	return go.get_node_or_null(NodePath(name))


func shooter(go) -> Node:
	var c := comp(go, "Shooter")
	if c == null:
		c = comp(go, "RocketLauncher")
	return c


func support(go) -> Node:
	var c := comp(go, "Flak")
	if c == null:
		c = comp(go, "ShieldGenerator")
	return c


func projectile(go) -> Node:
	for n in ["Projectile", "ClusterBomb", "S2SRocket", "ProjectileStraightFlight"]:
		var c := comp(go, n)
		if c != null:
			return c
	return null


## Instantiate a prefab scene, optionally as child of parent (local transform kept).
func instantiate(scene: PackedScene, parent: Node = null) -> Node3D:
	var n := scene.instantiate() as Node3D
	if parent != null:
		parent.add_child(n)
	return n


## Unity's transform.SetParent(parent, false): keeps the local transform.
func set_parent(n: Node3D, parent: Node) -> void:
	if not alive(n) or n.get_parent() == parent:
		return
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	parent.add_child(n)



func world() -> Node:
	return get_tree().current_scene


# ------------------------------------------------------------------- random
## Unity Random.Range(int, int): max exclusive.
func rint(a: int, b: int) -> int:
	if b <= a:
		return a
	return a + randi() % (b - a)


## Unity Random.Range(float, float): both inclusive.
func rfloat(a: float, b: float) -> float:
	return randf_range(a, b)


## Unity Random.value
func value() -> float:
	return randf()


# ------------------------------------------------------------------- colours
func meshes(root: Node) -> Array:
	var out: Array = []
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		if c is MeshInstance3D or c.get_child_count() > 0:
			out.append_array(meshes(c))
	return out


func _unique_material(mi: MeshInstance3D, surface: int) -> StandardMaterial3D:
	var key := "unique_mat_%d" % surface
	if mi.has_meta(key):
		return mi.get_meta(key)
	var base: Material = mi.get_surface_override_material(surface)
	if base == null and mi.mesh != null and surface < mi.mesh.get_surface_count():
		base = mi.mesh.surface_get_material(surface)
	var m: StandardMaterial3D
	if base is StandardMaterial3D:
		m = base.duplicate()
	else:
		m = StandardMaterial3D.new()
	mi.set_surface_override_material(surface, m)
	mi.set_meta(key, m)
	return m


## renderer.material.color = c (for the first material of every mesh below root)
func set_color(root: Node, c: Color) -> void:
	if not alive(root):
		return
	for mi in meshes(root):
		if mi.get_script() != null:
			continue  # line renderers / cooldown indicators
		_unique_material(mi, 0).albedo_color = c


## Every surface of a building turns see-through (a < 1) or solid again.
func set_alpha(root: Node, a: float) -> void:
	if not alive(root):
		return
	for mi in meshes(root):
		if mi.get_script() != null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := _unique_material(mi, s)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if a < 1.0 \
					else BaseMaterial3D.TRANSPARENCY_DISABLED
			m.albedo_color.a = a


## renderer.materials[i].color = c
func set_surface_color(mi: MeshInstance3D, surface: int, c: Color) -> void:
	_unique_material(mi, surface).albedo_color = c


## Colour of the first visible mesh (a placeholder the art layer hid does not count).
func get_color(root: Node) -> Color:
	for mi in meshes(root):
		if mi.get_script() != null or not mi.visible:
			continue
		var m: Material = mi.get_surface_override_material(0)
		if m == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			m = mi.mesh.surface_get_material(0)
		if m is StandardMaterial3D:
			return m.albedo_color
		return Color.WHITE
	return Color.WHITE


func set_shadows(root: Node, on: bool) -> void:
	if not alive(root):
		return
	for mi in meshes(root):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_visible_meshes(root: Node, on: bool) -> void:
	for mi in meshes(root):
		mi.visible = on


# ------------------------------------------------------------------- math
## Basis whose -Z axis looks along dir (Unity LookRotation; forward is -Z in Godot).
func look_basis(dir: Vector3) -> Basis:
	if dir.length_squared() < 1e-8:
		return Basis.IDENTITY
	var up := Vector3.UP
	if absf(dir.normalized().dot(up)) > 0.999:
		up = Vector3.FORWARD
	return Basis.looking_at(dir, up)


func look_at(n: Node3D, target: Vector3) -> void:
	var dir := target - n.global_position
	if dir.length_squared() < 1e-8:
		return
	var s := n.global_transform.basis.get_scale()
	n.global_transform.basis = look_basis(dir).scaled(s)


func shuffle_index(length: int) -> Array:
	# Fisher-Yates as in GameController.RandomShuffleIndex (including its quirk of
	# stopping two elements early).
	var shuffled: Array = []
	for i in length:
		shuffled.append(i)
	for i in range(0, length - 2):
		var r := rint(i, length)
		var tmp = shuffled[r]
		shuffled[r] = shuffled[i]
		shuffled[i] = tmp
	return shuffled
