extends MeshInstance3D
## Cooldown ring above a gun (Unity: SpriteMask whose alphaCutoff grows from 0 to 1).

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
	enabled = true
	alphaCutoff = 0.0
	_start = U.time
	_duration = maxf(seconds, 0.0001)
	set_process(true)


func _process(_delta: float) -> void:
	var waited := U.time - _start
	alphaCutoff = waited / _duration
	if waited > _duration:
		enabled = false
		set_process(false)
