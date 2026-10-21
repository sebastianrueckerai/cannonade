extends Node3D
## Where the muzzle effect really sits, live. The catalog's cannon aims at a fixed target and
## fires FX.muzzle in a loop, one look per shot, at the same anchor and along the same launch
## direction try_shoot uses. The green sphere is the ProjectileSpawn anchor (where the shell
## and the flash spawn), the small yellow one the flash quad's centre 0.2 m along the launch
## direction (the fire look; smoke and soft sit at 0.16 m). In the editor, expand Cannon and
## select ProjectileSpawn to see the same point as a gizmo. The camera is the boards' muzzle
## profile view. tools/godot_render.sh res://tools/fx_check.tscn -- --at=1.92 --fxstyle=fire --out=/tmp/fx
## catches the fire look's flash (shots at 0, 1.8, 3.6...).

const FX = preload("res://scripts/FX.gd")

const TARGET := Vector3(2.0, 0.0, -2.0)
const PERIOD := 1.8
const STYLES := ["smoke", "fire", "soft"]

var cannon: Node3D
var shooter
var camera: Camera3D
var framed := false
var i := 0

func _ready() -> void:
	cannon = $Cannon
	Art.attach(cannon, "cannon")
	Catalog.configure(cannon, Catalog.get_def("cannon"))
	shooter = U.comp(cannon, "Shooter")
	_setup_environment()
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=")
			args[kv[0]] = kv[1] if kv.size() > 1 else true
	if args.has("at"):
		var at: float = float(args["at"])
		await get_tree().create_timer(maxf(0.0, at - 0.12)).timeout
		_fire(args.get("fxstyle", "smoke"))
		await get_tree().create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		var path := "%s.png" % args.get("out", "/tmp/fx_check")
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
		get_tree().quit()
		return
	_fire("")
	while true:
		await get_tree().create_timer(PERIOD).timeout
		_fire("")

func _fire(forced: String) -> void:
	FX.ENABLED = true
	FX.style = forced if forced != "" else STYLES[i % STYLES.size()]
	i += 1
	shooter.try_aim(TARGET)
	var sp: Node3D = shooter.get_node(shooter.projectileSpawn)
	var flat := TARGET - sp.global_position
	flat.y = 0.0
	flat = flat.normalized() if flat.length_squared() > 0.0001 else -cannon.global_transform.basis.z
	var dir := (flat * cos(shooter.angleRads) + Vector3.UP * sin(shooter.angleRads)).normalized()
	FX.muzzle(sp.global_position, dir)
	var centre := sp.global_position + dir * 0.2
	if not framed:
		framed = true
		_marker(self, sp.global_position, Color(0.0, 1.0, 0.0), 0.045)
		_marker(self, centre, Color(1.0, 0.9, 0.0), 0.03)
		var perp := flat.cross(Vector3.UP).normalized()
		camera.global_position = sp.global_position + perp * 2.6 + Vector3.UP * 1.15
		camera.look_at(sp.global_position + flat * 0.6)
	print("fx_check style=%s barrel=%.1f deg anchor=%s flash_centre=%s anchor_screen=%s centre_screen=%s"
			% [FX.style, shooter.angleDegrees, sp.global_position, centre,
			camera.unproject_position(sp.global_position), camera.unproject_position(centre)])

## The game's look (Main._setup_environment) minus the map fog, so the flash glows as in game.
func _setup_environment() -> void:
	var elevation := deg_to_rad(38.0)
	var azimuth := deg_to_rad(40.0)
	var to_sun := Vector3(cos(elevation) * sin(azimuth), sin(elevation), cos(elevation) * cos(azimuth))
	var light := DirectionalLight3D.new()
	light.basis = Basis.looking_at(-to_sun, Vector3.UP)
	light.light_color = Color("#ffd29d")
	light.light_energy = 0.65
	light.shadow_enabled = true
	light.shadow_opacity = 0.56
	add_child(light)
	var env := Environment.new()
	var sky_tex := Art.sky_texture()
	if sky_tex != null:
		var sky := Sky.new()
		var sky_mat := PanoramaSkyMaterial.new()
		sky_mat.panorama = sky_tex
		sky.sky_material = sky_mat
		env.sky = sky
		env.background_mode = Environment.BG_SKY
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("#6cb9f5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#bec3c4")
	env.ambient_light_energy = 0.46
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.97
	env.tonemap_white = 6.25
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.07
	env.glow_enabled = true
	env.glow_intensity = 0.26
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	camera = Camera3D.new()
	camera.fov = 37.44
	camera.far = 100.0
	add_child(camera)
	camera.make_current()

func _marker(parent: Node, local: Vector3, col: Color, r: float) -> void:
	var m := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = r
	sphere.height = r * 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 10
	m.mesh = sphere
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.position = local
