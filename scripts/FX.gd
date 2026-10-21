extends Object
## Battle effects: the muzzle flash and smoke at the barrel when a gun fires
## (Shooter), the plume or water splash where a shell lands (TileImpactor).
## The art bible's fairground look: round puffs that pop in, drift, pop away.
## The smoke and shock-ring looks of the boards live in this file's first
## commit (7fd5437) for the day Sebastian picks one of them instead.

const FLASH := Color(1.0, 0.93, 0.62)
const SMOKE := Color(0.84, 0.81, 0.76)
const SMOKE_DARK := Color(0.66, 0.62, 0.57)
const DUST := Color(0.87, 0.81, 0.7)
const FOAM := Color(0.95, 0.98, 1.0)


static func muzzle(pos: Vector3, dir: Vector3) -> void:
	var root := _root("muzzle", 1.4)
	_toon(root, pos, 0.17, FLASH, 0.0, dir * 0.3, true)
	var side := dir.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 0.0001 else Vector3.RIGHT
	for i in 5:
		var out := side * Art._rng.randf_range(-0.8, 0.8) + Vector3.UP * Art._rng.randf_range(0.1, 0.5)
		_toon(root, pos + dir * 0.15, Art._rng.randf_range(0.07, 0.13), SMOKE if i % 2 == 0 else SMOKE_DARK,
				0.03 * i, dir * Art._rng.randf_range(1.4, 2.4) + out)


static func impact(pos: Vector3, water: bool, damage: float) -> void:
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


static func _root(kind: String, life: float) -> Node3D:
	var root := Node3D.new()
	root.name = "FX %s" % kind.capitalize()
	root.set_meta("fx", kind)
	U.world().add_child(root)
	root.get_tree().create_timer(life).timeout.connect(func():
		if is_instance_valid(root):
			root.queue_free())
	return root
