extends MeshInstance3D
## A gun's reload (Unity: SpriteMask whose alphaCutoff grows from 0 to 1), round 27 of
## blender-ai: a ring flat on the gun's plate round the gun's foot, in the gun's iron shifted
## toward the owner's team colour, whose band thins outward to nothing over the reload; then
## the plate pulses red once at ready. See scripts/Indicators.gd.

const PULSE_S := 0.7
const BAND := 0.36  # inner radius of the band in quad units; the outer is 0.5

var enabled := false:
	set(v):
		enabled = v
		visible = v
var alphaCutoff := 0.0:
	set(v):
		alphaCutoff = v
		if _mat:
			_mat.set_shader_parameter("progress", clampf(v, 0.0, 1.0))

var _mat: ShaderMaterial
var _start := 0.0
var _duration := 0.0
var _placed := false
var _pulse_until := 0.0


func _ready() -> void:
	var base := get_surface_override_material(0)
	if base:
		_mat = base.duplicate()
		set_surface_override_material(0, _mat)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	set_process(false)


## Equivalent of the _Cooldown coroutine of Shooter / RocketLauncher.
func run(seconds: float) -> void:
	if not _placed:
		_place()
	if _pulse_until > 0.0:  # a new shot cuts a running pulse: the plate goes back to iron now
		var plate := _plate()
		if plate != null:
			U._unique_material(plate, 0).albedo_color = Color.WHITE
	_pulse_until = 0.0
	enabled = true
	alphaCutoff = 0.0
	_start = U.time
	_duration = maxf(seconds, 0.0001)
	set_process(true)


func _process(_delta: float) -> void:
	if _pulse_until > 0.0:
		var k := clampf((_pulse_until - U.time) / PULSE_S, 0.0, 1.0)
		var plate := _plate()
		if plate != null:
			U._unique_material(plate, 0).albedo_color = Color.WHITE.lerp(Indicators.pulse_red, k * k)
		if k <= 0.0:
			_pulse_until = 0.0
			set_process(false)
		return
	var waited := U.time - _start
	alphaCutoff = waited / _duration
	if waited > _duration:
		enabled = false
		alphaCutoff = 1.0
		_pulse_until = U.time + PULSE_S


## Lays the ring flat on the plate, centred on the gun's foot. The mount is the part that stands
## on the plate; a building without one (a placeholder) takes a ring inside its footprint.
## Scale in the quad's own plane first, then lay it flat: the other order draws an ellipse.
func _place() -> void:
	_placed = true
	var root := get_parent() as Node3D
	var mount := root.find_child("mount", true, false) as MeshInstance3D
	var plate := _plate()
	var centre := root.global_position
	var r := 0.4
	var st = U.comp(root, "Structure")
	if st != null and st.def != null:
		r = st.def.size * 0.4
	var top := centre.y + 0.1
	if mount != null:
		var mw := mount.global_transform * mount.get_aabb()
		r = maxf(mw.size.x, mw.size.z) * 0.5 + 0.06
		centre = mw.get_center()
	if plate != null:
		var pw := plate.global_transform * plate.get_aabb()
		top = pw.end.y
		r = minf(r, pw.size.x * 0.5)  # the ring stays on the plate, inside the gun's square
	top_level = true
	global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(r * 2.0, r * 2.0, 1.0)).rotated(Vector3.RIGHT, -PI / 2),
		Vector3(centre.x, top + 0.02, centre.z))
	if _mat:
		var bb = U.comp(root, "BuildingBlock")
		var team: Color = bb.player.mainColor if bb != null and bb.player != null else Indicators.plate_iron
		_mat.set_shader_parameter("color", Color(Indicators.plate_iron.lerp(team, Indicators.ring_shift), 0.95))
		_mat.set_shader_parameter("inner", BAND)


func _plate() -> MeshInstance3D:
	return get_parent().find_child("plate", true, false) as MeshInstance3D
