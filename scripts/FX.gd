extends Object
## Battle effects at the muzzle (Shooter) and the landing (TileImpactor):
## textured billboard bursts on Kenney's CC0 particle sprites
## (assets/art/fx, LICENSE there), sized, ramped and damped after Godot's
## official 3D particles demo (I78). The look is fire (Sebastian's pick,
## board 12, session 49); `style` names the look: smoke (the demo
## look), fire, soft. Particle seeds make the randomness, never the game RNG.

static var style := "fire"

const RING := preload("res://materials/fx_ring.gdshader")

const SMOKE := preload("res://assets/art/fx/smoke_05.png")
const SMOKE_SOFT := preload("res://assets/art/fx/smoke_04.png")
const MIST := preload("res://assets/art/fx/mist.png")
const SMOKE_DARK := preload("res://assets/art/fx/smoke_07.png")
const FLASH := preload("res://assets/art/fx/muzzle_04.png")
const FLASH_BIG := preload("res://assets/art/fx/muzzle_05.png")
const FIRE := preload("res://assets/art/fx/fire_01.png")
const FIRE2 := preload("res://assets/art/fx/fire_02.png")
const SPARK := preload("res://assets/art/fx/spark_05.png")
const DIRT := preload("res://assets/art/fx/dirt_01.png")


static func muzzle(pos: Vector3, dir: Vector3) -> void:
	var root := _root("muzzle", 2.6)
	var drift := (dir + Vector3.UP * 0.75).normalized()
	match style:
		"fire":
			_burst(root, pos + dir * 0.2, {"tex": FLASH_BIG, "count": 3, "life": 0.16, "s": [0.42, 0.58],
					"grow": false, "col": Color(3.2, 2.6, 1.6), "add": true, "hold": 1.0})
			_burst(root, pos + dir * 0.12, {"tex": FIRE2, "count": 4, "life": 0.35, "s": [0.3, 0.45],
					"col": Color(2.6, 1.4, 0.5), "add": true, "dir": drift, "spread": 20.0,
					"v": [1.2, 2.2], "damp": 3.0, "hold": 0.3})
			_burst(root, pos + dir * 0.15, {"tex": SMOKE_DARK, "count": 9, "life": 1.9, "s": [0.28, 0.55],
					"col": Color(0.78, 0.75, 0.71), "dir": drift, "spread": 28.0, "v": [0.7, 1.7],
					"damp": 1.4, "ang": 160.0, "hold": 0.35})
		"soft":
			_burst(root, pos + dir * 0.16, {"tex": FLASH, "count": 1, "life": 0.13, "s": [0.22, 0.32],
					"grow": false, "col": Color(2.4, 2.1, 1.5), "add": true, "hold": 1.0})
			_burst(root, pos, {"tex": SMOKE_SOFT, "count": 3, "life": 2.2, "s": [0.2, 0.45],
					"col": Color(0.88, 0.86, 0.83), "dir": drift, "spread": 18.0, "v": [0.4, 0.9],
					"damp": 0.8, "ang": 60.0, "hold": 0.5})
		_:
			_burst(root, pos + dir * 0.16, {"tex": FLASH, "count": 2, "life": 0.17, "s": [0.34, 0.5],
					"grow": false, "col": Color(2.8, 2.3, 1.5), "add": true, "hold": 1.0})
			_burst(root, pos + dir * 0.12, {"tex": SPARK, "count": 5, "life": 0.4, "s": [0.06, 0.1],
					"col": Color(2.2, 1.7, 0.9), "add": true, "dir": dir, "spread": 24.0,
					"v": [2.5, 4.5], "grav": Vector3(0, -6, 0), "hold": 0.2})
			_burst(root, pos + dir * 0.15, {"tex": SMOKE, "count": 7, "life": 1.6, "s": [0.25, 0.55],
					"col": Color(0.85, 0.82, 0.78), "dir": drift, "spread": 26.0, "v": [0.8, 1.8],
					"damp": 1.5, "ang": 150.0, "hold": 0.35})


static func impact(pos: Vector3, water: bool, damage: float, splash := 0.0, smoke := false) -> void:
	var s := clampf(damage / 10.0, 0.7, 2.2) * (1.0 + 0.5 * splash)
	var q := sqrt(s)
	var root := _root("impact", 2.6)
	## A splash shell also puffs every tile it hit round the point; with `smoke`
	## those puffs cloud the whole 3x3, the heavy shell's landing (I101). Over
	## water the puffs turn to mist, blue at the core, white as it disperses, and
	## a river throws no dirt.
	if splash > 0.0:
		for d in [Vector3(splash, 0, 0), Vector3(-splash, 0, 0), Vector3(0, 0, splash), Vector3(0, 0, -splash),
				Vector3(splash, 0, splash), Vector3(splash, 0, -splash), Vector3(-splash, 0, splash), Vector3(-splash, 0, -splash)]:
			if not water:
				_burst(root, pos + d, {"tex": DIRT, "count": 4, "life": 0.8, "s": [0.12, 0.24],
						"col": Color(0.85, 0.72, 0.55), "spread": 75.0, "v": [1.2, 2.4],
						"grav": Vector3(0, -6, 0), "hold": 0.15})
			if smoke:
				var puff := {"tex": SMOKE_DARK, "count": 3, "life": 1.9, "s": [0.25 * s, 0.55 * s],
						"col": Color(0.66, 0.62, 0.58), "spread": 25.0, "v": [0.5 * q, 1.2 * q],
						"damp": 1.1, "ang": 150.0, "hold": 0.3}
				if water:
					puff.tex = MIST
					puff.col = Color(0.45, 0.62, 0.95)
					puff.to = Color(0.95, 0.98, 1.0)
				_burst(root, pos + d, puff)
	## The water family rides a white puff (MIST: smoke_04's soft round
	## alpha with white RGB), not the smoke sprites: those are grey and a
	## tint can only darken them, which reads as black smoke over a river.
	## White tints to true water blue, and every puff runs blue at its
	## start to white as it disperses.
	if water:
		_burst(root, pos, {"tex": MIST, "count": 20, "life": 1.1, "s": [0.12 * s, 0.26 * s],
				"col": Color(0.45, 0.62, 0.95), "to": Color(0.95, 0.98, 1.0), "spread": 15.0,
				"v": [2.5 * q, 4.5 * q], "grav": Vector3(0, -9, 0), "damp": 0.3, "ang": 30.0,
				"hold": 0.5})
		_burst(root, pos, {"tex": MIST, "count": 12, "life": 0.85, "s": [0.1 * s, 0.2 * s],
				"col": Color(0.5, 0.66, 0.97), "to": Color(0.95, 0.98, 1.0), "spread": 55.0,
				"v": [1.2 * q, 2.2 * q], "grav": Vector3(0, -7, 0), "damp": 0.3, "hold": 0.4})
		_burst(root, pos, {"tex": MIST, "count": 7, "life": 0.55, "s": [0.3 * s, 0.55 * s],
				"col": Color(0.6, 0.73, 1.0), "to": Color(0.97, 0.99, 1.0), "spread": 20.0,
				"v": [0.6 * q, 1.2 * q], "damp": 2.0, "hold": 0.35})
		_ring(root, pos, s, Color(0.7, 0.85, 1.0, 0.65))
		return
	match style:
		"fire":
			_burst(root, pos, {"tex": FIRE, "count": 6, "life": 0.5, "s": [0.45 * s, 0.85 * s],
					"col": Color(3.0, 1.5, 0.5), "add": true, "spread": 35.0, "v": [0.8 * q, 2.0 * q],
					"damp": 2.5, "ang": 180.0, "hold": 0.25})
			_burst(root, pos, {"tex": FIRE2, "count": 4, "life": 0.4, "s": [0.35 * s, 0.6 * s],
					"col": Color(2.2, 0.9, 0.3), "add": true, "spread": 40.0, "v": [1.0 * q, 2.2 * q],
					"damp": 2.5, "hold": 0.2})
			_burst(root, pos + Vector3.UP * 0.1, {"tex": DIRT, "count": 6, "life": 0.9,
					"s": [0.15 * s, 0.3 * s], "col": Color(0.85, 0.72, 0.55), "spread": 75.0,
					"v": [1.5 * q, 3.0 * q], "grav": Vector3(0, -6, 0), "hold": 0.15})
			_burst(root, pos, {"tex": SMOKE_DARK, "count": 10, "life": 2.2, "s": [0.3 * s, 0.8 * s],
					"col": Color(0.62, 0.58, 0.55), "v": [1.0 * q, 2.2 * q], "damp": 1.2, "ang": 170.0,
					"hold": 0.3})
			_burst(root, pos, {"tex": SPARK, "count": 8, "life": 0.35, "s": [0.06, 0.11],
					"col": Color(1.9, 1.3, 0.6), "add": true, "spread": 45.0, "v": [2.0 * q, 3.6 * q],
					"grav": Vector3(0, -9, 0), "hold": 0.15})
			_ring(root, pos, 1.1 * s, Color(1.0, 0.75, 0.4, 0.8))
		"soft":
			_burst(root, pos, {"tex": SMOKE, "count": 5, "life": 2.3, "s": [0.3 * s, 0.75 * s],
					"col": Color(0.85, 0.83, 0.8), "v": [0.8 * q, 1.6 * q], "damp": 1.0, "ang": 90.0,
					"hold": 0.4})
			_ring(root, pos, 0.8 * s, Color(1.0, 0.9, 0.7, 0.4))
		_:
			_burst(root, pos, {"tex": FIRE, "count": 2, "life": 0.2, "s": [0.4 * s, 0.6 * s],
					"grow": false, "col": Color(3.0, 2.0, 1.1), "add": true, "hold": 1.0})
			_burst(root, pos + Vector3.UP * 0.05, {"tex": SMOKE_DARK, "count": 6, "life": 0.8,
					"s": [0.18 * s, 0.3 * s], "col": Color(0.82, 0.74, 0.6), "spread": 80.0,
					"v": [1.2 * q, 2.4 * q], "grav": Vector3(0, -2, 0), "hold": 0.2})
			_burst(root, pos + Vector3.UP * 0.1, {"tex": SMOKE, "count": 9, "life": 2.0,
					"s": [0.28 * s, 0.7 * s], "col": Color(0.8, 0.77, 0.73), "v": [1.0 * q, 2.2 * q],
					"damp": 1.3, "ang": 160.0, "hold": 0.3})
			_ring(root, pos, 0.95 * s, Color(1.0, 0.85, 0.55, 0.75))


## One one-shot burst of camera-facing textured quads. The config keys:
## tex, count, life, s = [min, max] quad size, grow (size over life), col
## (may exceed 1 for additive fire), to (end colour, for bursts that recolour
## over life), add, dir, spread, v = [min, max] velocity, damp, ang (spin),
## grav, hold (fraction of life before fade).
static func _burst(parent: Node3D, pos: Vector3, cfg: Dictionary) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = cfg.get("count", 6)
	p.lifetime = cfg.get("life", 1.0)
	var sizes: Array = cfg.get("s", [0.3, 0.5])
	p.scale_amount_min = sizes[0]
	p.scale_amount_max = sizes[1]
	p.scale_amount_curve = _curve(cfg.get("grow", true))
	p.mesh = _quad(cfg["tex"], cfg.get("add", false))
	p.direction = cfg.get("dir", Vector3.UP)
	p.spread = cfg.get("spread", 0.0)
	var v: Array = cfg.get("v", [0.0, 0.0])
	p.initial_velocity_min = v[0]
	p.initial_velocity_max = v[1]
	p.gravity = cfg.get("grav", Vector3.ZERO)
	p.damping_min = cfg.get("damp", 0.0)
	p.damping_max = p.damping_min
	p.angular_velocity_min = -float(cfg.get("ang", 0.0))
	p.angular_velocity_max = float(cfg.get("ang", 0.0))
	p.color_ramp = _ramp(cfg.get("hold", 0.35), cfg.get("col", Color.WHITE), cfg.get("to", cfg.get("col", Color.WHITE)))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	parent.add_child(p)
	p.position = pos
	p.restart()


static func _quad(tex: Texture2D, add: bool) -> QuadMesh:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = m
	return q


static func _curve(grow: bool) -> Curve:
	var c := Curve.new()
	if grow:
		c.add_point(Vector2(0.0, 0.35))
		c.add_point(Vector2(1.0, 1.0))
	else:
		c.add_point(Vector2(0.0, 1.0))
		c.add_point(Vector2(1.0, 0.55))
	return c


## Alpha holds to `hold`, then fades out; the colour runs `col` to `to` over the
## held span, so `to` alone turns a burst that changes colour as it disperses.
static func _ramp(hold: float, col := Color.WHITE, to := Color.WHITE) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, hold, 1.0])
	g.colors = PackedColorArray([col, to, Color(to.r, to.g, to.b, 0.0)])
	return g


## The donut of board 6: one flat expanding ring on the ground.
static func _ring(parent: Node3D, pos: Vector3, r: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = RING
	mat.set_shader_parameter("ring_color", col)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(r * 2.0, r * 2.0)
	mesh.material = mat
	mi.mesh = mesh
	mi.rotation_degrees.x = -90.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos + Vector3.UP * 0.06
	var tw := mi.create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.55)



static func _root(kind: String, life: float) -> Node3D:
	var root := Node3D.new()
	root.name = "FX %s" % kind.capitalize()
	root.set_meta("fx", kind)
	U.world().add_child(root)
	root.get_tree().create_timer(life, false).timeout.connect(root.queue_free)
	return root
