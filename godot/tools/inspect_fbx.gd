extends SceneTree
func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and n.mesh:
		var a: AABB = t * n.mesh.get_aabb()
		acc[0] = a if acc[0] == null else acc[0].merge(a)
		acc[1].append("%s surf=%d mat=%s" % [n.name, n.mesh.get_surface_count(), str(n.mesh.surface_get_material(0).resource_name if n.mesh.surface_get_material(0) else n.get_active_material(0))])
	for c in n.get_children():
		_aabb(c, t, acc)
func _init() -> void:
	for f in ["res://assets/fbx/line_base1.fbx","res://assets/fbx/curve_base1.fbx","res://assets/fbx/cross_upper1.fbx","res://assets/fbx/tri_base1.fbx","res://assets/nature/Bush01.fbx","res://assets/nature/BigLeafTree01.fbx"]:
		var s: Node = load(f).instantiate()
		var acc := [null, []]
		_aabb(s, Transform3D.IDENTITY, acc)
		print(f, " root=", s.get_class(), " children=", s.get_child_count(), " aabb=", acc[0], " ", acc[1])
	quit()
