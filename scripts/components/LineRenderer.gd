extends MeshInstance3D
## Replacement for Unity's LineRenderer: draws a flat ribbon through `positions`. With `taper` the
## ribbon fades from 0.9 to 0.15 opacity toward its end (the aim arc, round 27 of blender-ai).

@export var width := 0.1
@export var loop := false
@export var world_space := true
@export var taper := false

var positions := PackedVector3Array()
var enabled := true:
	set(v):
		enabled = v
		visible = v
var color := Color.WHITE:
	set(v):
		color = v
		if _mat:
			_mat.albedo_color = v

var _mat: StandardMaterial3D
var _imesh: ImmediateMesh


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_color = color
	if taper:
		_mat.vertex_color_use_as_albedo = true
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = world_space
	if world_space:
		global_transform = Transform3D.IDENTITY
	_rebuild()


func set_positions(points: PackedVector3Array) -> void:
	positions = points
	if is_inside_tree():
		if world_space:
			global_transform = Transform3D.IDENTITY
		_rebuild()


func _rebuild() -> void:
	if _imesh == null:
		return
	_imesh.clear_surfaces()
	var pts := positions.duplicate()
	if pts.size() < 2:
		return
	if loop:
		pts.append(pts[0])
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	var n := float(pts.size() - 1)
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d := b - a
		var side := d.cross(Vector3.UP)
		if side.length_squared() < 1e-8:
			side = Vector3.RIGHT
		side = side.normalized() * hw
		# extend segments by half a width so corners are closed
		var e := d.normalized() * hw if loop else Vector3.ZERO
		var a0 := a - e - side
		var a1 := a - e + side
		var b0 := b + e - side
		var b1 := b + e + side
		var ca := Color(1, 1, 1, 0.9 - 0.75 * float(i) / n) if taper else Color.WHITE
		var cb := Color(1, 1, 1, 0.9 - 0.75 * float(i + 1) / n) if taper else Color.WHITE
		for v in [[a0, ca], [b0, cb], [b1, cb], [a0, ca], [b1, cb], [a1, ca]]:
			_imesh.surface_set_color(v[1])
			_imesh.surface_add_vertex(v[0])
	_imesh.surface_end()
