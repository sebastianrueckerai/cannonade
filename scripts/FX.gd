extends Object
## Battle effects: the muzzle flash and smoke at the barrel when a gun fires
## (Shooter), the plume or water splash where a shell lands (TileImpactor).
## Three looks live here for the boards; `style` names the shipped one.

const RING_SHADER = preload("res://materials/fx_ring.gdshader")

static var style := "puffs"

static var _tex: GradientTexture2D

const FLASH := Color(1.0, 0.93, 0.62)
const SMOKE := Color(0.84, 0.81, 0.76)
const SMOKE_DARK := Color(0.66, 0.62, 0.57)
const DUST := Color(0.87, 0.81, 0.7)
const FOAM := Color(0.95, 0.98, 1.0)


static func muzzle(pos: Vector3, dir: Vector3) -> void:
	match style:
		"smoke": _muzzle_particles(pos, dir)
		"shock": _muzzle_shock(pos, dir)
		_: _muzzle_puffs(pos, dir)


static func impact(pos: Vector3, water: bool, damage: float) -> void:
	match style:
		"smoke": _impact_particles(pos, water, damage)
		"shock": _impact_shock(pos, water, damage)
		_: _impact_puffs(pos, water, damage)


## A chunky sphere that pops in, drifts and pops away. `quick` is the muzzle
## flash, gone before the smoke puffs finish their pop.
static func _toon(parent: Node3D, pos: Vector3, r: float, col: Color, delay: float, vel: Vector3,
		quick := false) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = 2.0 * r
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	if col == FLASH:
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.72, 0.3)
		mat.emission_energy_multiplier = 1.4
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3.ONE * 0.01
	parent.add_child(mi)
	var tw := mi.create_tween()
	var hold := 0.04 if quick else 0.3
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.07 if quick else 0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.parallel().tween_property(mi, "position", pos + vel, hold) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.12 if quick else 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


static func _muzzle_puffs(pos: Vector3, dir: Vector3) -> void:
	var root := _root("muzzle", 1.4)
	_toon(root, pos, 0.17, FLASH, 0.0, dir * 0.3, true)
	var side := dir.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 0.0001 else Vector3.RIGHT
	for i in 5:
		var out := side * Art._rng.randf_range(-0.8, 0.8) + Vector3.UP * Art._rng.randf_range(0.1, 0.5)
		_toon(root, pos + dir * 0.15, Art._rng.randf_range(0.07, 0.13), SMOKE if i % 2 == 0 else SMOKE_DARK,
				0.03 * i, dir * Art._rng.randf_range(1.4, 2.4) + out)


static func _impact_puffs(pos: Vector3, water: bool, damage: float) -> void:
	var s := clampf(damage / 10.0, 0.7, 2.2)
	var root := _root("impact", 2.2)
	if water:
		for i in 7:
			var a := TAU * float(i) / 7.0 + Art._rng.randf_range(-0.3, 0.3)
			var side := Vector3(cos(a), 0.0, sin(a))
			_toon(root, pos + side * 0.12, Art._rng.randf_range(0.07, 0.14) * s, FOAM, 0.02 * i,
					(side * Art._rng.randf_range(0.5, 1.3) + Vector3.UP * Art._rng.randf_range(2.2, 3.4)) * sqrt(s))
		return
	for i in 4:
		var a := TAU * float(i) / 4.0 + Art._rng.randf_range(-0.4, 0.4)
		var side := Vector3(cos(a), 0.0, sin(a))
		_toon(root, pos + Vector3.UP * 0.08, Art._rng.randf_range(0.1, 0.16) * s, DUST, 0.02 * i,
				side * Art._rng.randf_range(0.9, 1.7) * sqrt(s))
	for i in 5:
		var sway := Vector3(Art._rng.randf_range(-0.25, 0.25), 0.0, Art._rng.randf_range(-0.25, 0.25))
		_toon(root, pos + Vector3.UP * (0.12 + 0.22 * float(i)), (0.13 + 0.05 * float(i)) * s,
				SMOKE if i % 2 == 0 else SMOKE_DARK, 0.06 * float(i),
				(Vector3.UP * Art._rng.randf_range(0.9, 1.5) + sway) * sqrt(s))


## One-shot billboard burst for the soft smoke look.
static func _burst(parent: Node3D, pos: Vector3, cfg: Dictionary) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = cfg.get("amount", 10)
	p.lifetime = cfg.get("lifetime", 0.8)
	p.explosiveness = 1.0
	p.direction = cfg.get("direction", Vector3.UP)
	p.spread = cfg.get("spread", 20.0)
	p.initial_velocity_min = cfg.get("vmin", 1.5)
	p.initial_velocity_max = cfg.get("vmax", 2.5)
	p.gravity = cfg.get("gravity", Vector3(0.0, 0.8, 0.0))
	p.scale_amount_min = cfg.get("smin", 0.25)
	p.scale_amount_max = cfg.get("smax", 0.5)
	var ramp := Gradient.new()
	ramp.set_color(0, cfg.get("from", Color(0.8, 0.77, 0.72, 0.9)))
	ramp.set_color(1, cfg.get("to", Color(0.6, 0.57, 0.52, 0.0)))
	p.color_ramp = ramp
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _grad_tex()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if cfg.get("add", false):
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh.material = mat
	p.mesh = mesh
	parent.add_child(p)
	p.position = pos
	p.emitting = true


static func _grad_tex() -> GradientTexture2D:
	if _tex == null:
		_tex = GradientTexture2D.new()
		_tex.width = 64
		_tex.height = 64
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.5, 0.5)
		_tex.fill_to = Vector2(0.5, 0.0)
		var g := Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		_tex.gradient = g
	return _tex


static func _muzzle_particles(pos: Vector3, dir: Vector3) -> void:
	var root := _root("muzzle", 1.4)
	_burst(root, pos, {
		"amount": 6, "lifetime": 0.18, "direction": dir, "spread": 14.0,
		"vmin": 3.0, "vmax": 5.0, "smin": 0.2, "smax": 0.4,
		"from": Color(1.0, 0.9, 0.55, 1.0), "to": Color(1.0, 0.6, 0.2, 0.0), "add": true,
	})
	_burst(root, pos + dir * 0.1, {
		"amount": 12, "lifetime": 0.9, "direction": dir, "spread": 24.0,
		"vmin": 1.4, "vmax": 2.6, "smin": 0.3, "smax": 0.55, "gravity": Vector3(0.0, 1.0, 0.0),
	})


static func _impact_particles(pos: Vector3, water: bool, damage: float) -> void:
	var s := clampf(damage / 10.0, 0.7, 2.2)
	var root := _root("impact", 2.2)
	if water:
		_burst(root, pos, {
			"amount": 16, "lifetime": 0.9, "spread": 8.0,
			"vmin": 3.0, "vmax": 5.0, "smin": 0.15, "smax": 0.3, "gravity": Vector3(0.0, -6.0, 0.0),
			"from": Color(1.0, 1.0, 1.0, 0.95), "to": Color(0.75, 0.85, 0.95, 0.0),
		})
		return
	_burst(root, pos, {
		"amount": 8, "lifetime": 0.55, "spread": 55.0,
		"vmin": 1.0, "vmax": 2.0, "smin": 0.2, "smax": 0.4, "gravity": Vector3(0.0, 0.4, 0.0),
		"from": Color(0.87, 0.81, 0.7, 0.9), "to": Color(0.8, 0.74, 0.62, 0.0),
	})
	_burst(root, pos + Vector3.UP * 0.2, {
		"amount": 14, "lifetime": 1.1, "spread": 10.0,
		"vmin": 1.6, "vmax": 3.0, "smin": 0.35, "smax": 0.65, "gravity": Vector3(0.0, 0.8, 0.0),
	})


## A bright billboard that swells and fades.
static func _flash(parent: Node3D, pos: Vector3, size: float, col: Color, dur: float) -> void:
	var mi := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = _grad_tex()
	mat.albedo_color = col
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.scale = Vector3.ONE * 0.15
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, dur * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(a: float): mat.albedo_color.a = a, col.a, 0.0, dur * 0.65)
	tw.tween_callback(mi.queue_free)


static func _ground_ring(parent: Node3D, pos: Vector3, size: float, col: Color, dur: float) -> void:
	var mi := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var mat := ShaderMaterial.new()
	mat.shader = RING_SHADER
	mat.set_shader_parameter("color", col)
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos + Vector3.UP * 0.02
	mi.rotation.x = -PI / 2.0
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, dur)
	tw.tween_callback(mi.queue_free)


static func _muzzle_shock(pos: Vector3, dir: Vector3) -> void:
	var root := _root("muzzle", 1.2)
	_flash(root, pos, 0.9, Color(1.0, 0.85, 0.5, 0.9), 0.28)
	_ground_ring(root, pos - dir * 0.3 + Vector3.UP * 0.05, 1.1, Color(1.0, 0.9, 0.65, 0.7), 0.4)


static func _impact_shock(pos: Vector3, water: bool, damage: float) -> void:
	var s := clampf(damage / 10.0, 0.7, 2.2)
	var root := _root("impact", 2.0)
	var col := Color(0.85, 0.95, 1.0, 0.9) if water else Color(0.95, 0.88, 0.72, 0.9)
	_ground_ring(root, pos, 1.6 * sqrt(s), col, 0.5)
	_flash(root, pos + Vector3.UP * 0.25, 1.1 * sqrt(s),
			Color(0.9, 0.97, 1.0, 0.9) if water else Color(1.0, 0.9, 0.6, 0.9), 0.3)
	if not water:
		for i in 4:
			var a := TAU * float(i) / 4.0 + Art._rng.randf_range(-0.4, 0.4)
			var side := Vector3(cos(a), 0.0, sin(a))
			_toon(root, pos + Vector3.UP * 0.1, Art._rng.randf_range(0.08, 0.13) * s, DUST, 0.04 * i,
					side * Art._rng.randf_range(0.8, 1.4) * sqrt(s))


static func _root(kind: String, life: float) -> Node3D:
	var root := Node3D.new()
	root.name = "FX %s" % kind.capitalize()
	root.set_meta("fx", kind)
	U.world().add_child(root)
	root.get_tree().create_timer(life).timeout.connect(func():
		if is_instance_valid(root):
			root.queue_free())
	return root
