extends MeshInstance3D
## Cooldown indicator of a gun (Unity: SpriteMask whose alphaCutoff grows from 0 to 1). The
## shipped look is the white ring above the gun. Indicators.reload_style (round 27 candidates) picks
## another: a warm barrel cooling to iron, the plate filling toward its grey, or the ring laid
## flat round the plate. The ring quad is hidden under every style but "ring" and "ground".

var enabled := false:
	set(v):
		enabled = v
		visible = v and Indicators.reload_style in ["ring", "ground", "base"]
var alphaCutoff := 0.0:
	set(v):
		alphaCutoff = v
		if _mat:
			_mat.set_shader_parameter("progress", clampf(v, 0.0, 1.0))
		_apply_style(clampf(v, 0.0, 1.0))

const PULSE_S := 0.7
const BAND := 0.36  # inner radius of the ring band in quad units: a 0.14 m band on the small gun

var _mat: ShaderMaterial
var _start := 0.0
var _duration := 0.0
var _grounded := false
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
	if Indicators.reload_style == "ground" and not _grounded:
		_ground()
	if Indicators.reload_style == "base" and not _grounded:
		_base()
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
	var waited := U.time - _start
	if _pulse_until > 0.0:
		# base style: the plate flashes red once at the ready moment, then settles back to iron
		var k := clampf((_pulse_until - U.time) / PULSE_S, 0.0, 1.0)
		var plate := _plate()
		if plate != null:
			U._unique_material(plate, 0).albedo_color = Color.WHITE.lerp(Indicators.pulse_red, k * k)
		if k <= 0.0:
			_pulse_until = 0.0
			set_process(false)
		return
	alphaCutoff = waited / _duration
	if waited > _duration:
		enabled = false
		alphaCutoff = 1.0
		if Indicators.reload_style == "base":
			_pulse_until = U.time + PULSE_S
		else:
			set_process(false)


## The ring flat on the ground round the plate: it sits at the plate's size and height.
func _ground() -> void:
	_grounded = true
	var plate := _plate()
	var side := 1.0
	if plate != null:
		side = plate.get_aabb().size.x * plate.scale.x
	top_level = true
	global_transform = Transform3D(Basis.IDENTITY.rotated(Vector3.RIGHT, -PI / 2).scaled(Vector3(side * 1.25, side * 1.25, 1.0)),
		get_parent().global_position + Vector3(0, 0.115, 0))
	if _mat:
		_mat.set_shader_parameter("color", Color(1, 1, 1, 0.55))


## base (round 27, Sebastian's candidate): a red ring flat on the plate, hugging the gun's base,
## that shrinks in toward the gun as the reload runs and is gone at ready; then the plate
## pulses red once. The ring's outer edge starts at the plate's edge, its inner edge at the mount.
func _base() -> void:
	_grounded = true
	# The ring sits on the mount's real footprint, not the plate's: the mount is centred ahead
	# of the plate centre (0.05 / 0.14 / 0.24 m on the three guns, measured), so a ring drawn at
	# the plate centre misses the gun foot. Outer radius just past the mount, a band 0.14 m
	# wide, lifted 2 cm above the plate top so it never z-fights the painted plate.
	var mount := get_parent().find_child("mount", true, false) as MeshInstance3D
	var plate := _plate()
	var r := 0.5
	var centre: Vector3 = get_parent().global_position
	var top := 0.1
	if mount != null:
		var mw := mount.global_transform * mount.get_aabb()
		r = maxf(mw.size.x, mw.size.z) * 0.5 + 0.06
		centre = Vector3(mw.get_center().x, 0.0, mw.get_center().z)
	if plate != null:
		top = (plate.global_transform * plate.get_aabb()).end.y
	var quad := r * 2.0  # a 1x1 quad: the shader's outer radius 0.5 lands on r at scale 2r
	top_level = true
	# scale in the quad's own plane FIRST, then lay it flat: scaling after the rotation
	# stretched world X and world Y (height) and left world Z at 1 m, which drew an ellipse
	global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(quad, quad, 1.0)).rotated(Vector3.RIGHT, -PI / 2),
		Vector3(centre.x, top + 0.02, centre.z))
	if _mat:
		# the gun's own iron, shifted toward the owner's team colour (Sebastian, round 27)
		var sh = U.comp(get_parent(), "Shooter")
		var team: Color = sh.player.mainColor if sh != null and sh.player != null else Color.GRAY
		_mat.set_shader_parameter("color", Color(Indicators.plate_iron.lerp(team, Indicators.ring_shift), 0.95))
		_mat.set_shader_parameter("shrink", 1.0)
		_mat.set_shader_parameter("inner", BAND)


func _plate() -> MeshInstance3D:
	return get_parent().find_child("plate", true, false) as MeshInstance3D


func _barrel_meshes() -> Array:
	var b := get_parent().find_child("Barrel", true, false)
	return U.meshes(b) if b != null else []


## heat: the barrel's albedo goes from a warm glow at the shot to its own texture at ready.
## plate: the plate's albedo from a warm tint at the shot to its own texture at ready.
func _apply_style(k: float) -> void:
	match Indicators.reload_style:
		"heat":
			var c := Indicators.heat_colour.lerp(Color.WHITE, k)
			var ms := _barrel_meshes()
			for mi in ms:
				U._unique_material(mi, 0).albedo_color = c
		"plate":
			var plate := _plate()
			if plate != null:
				U._unique_material(plate, 0).albedo_color = Indicators.plate_warm.lerp(Color.WHITE, k)
