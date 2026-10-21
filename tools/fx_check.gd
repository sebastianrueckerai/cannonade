@tool
extends Node3D
## Where the muzzle effect really sits. The editor view is the baked copy of the real build
## (fx_check_cannon.tscn): the catalog's cannon, art model and all, aimed at the target, with
## the ProjectileSpawn anchor marked by the green Origin sphere and the flash quad's centre
## (0.2 m along the launch direction, the fire look; smoke and soft sit at 0.16 m) by the
## yellow one, so the origin checks in the scene without playing. Playing rebuilds the cannon
## through the game's own path and fires FX.muzzle in a loop, one look per shot, at that same
## anchor; each shot prints style, barrel angle, anchor and flash centre in world and screen
## coordinates. The camera starts as the boards' muzzle profile view, then any drag orbits it
## around the anchor and the wheel zooms. Re-bake after a model or anchor change:
##   tools/godot_render.sh res://tools/fx_check.tscn -- --bake
## Headless check render:
##   tools/godot_render.sh res://tools/fx_check.tscn -- --at=1.92 --fxstyle=fire --out=/tmp/fx
##   (shots at 0, 1.8, 3.6...; the --at time lands 0.12 s into a flash)

const FX = preload("res://scripts/FX.gd")

const BAKE_PATH := "res://tools/fx_check_cannon.tscn"
const TARGET := Vector3(2.0, 0.0, -2.0)
const PERIOD := 1.8
const STYLES := ["smoke", "fire", "soft"]

var cannon: Node3D
var shooter
var camera: Camera3D
var framed := false
var i := 0
var orbit_pivot := Vector3.UP
var orbit_yaw := 0.0
var orbit_pitch := 0.35
var orbit_dist := 3.0
var orbiting := false
var manual_cam := false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=")
			args[kv[0]] = kv[1] if kv.size() > 1 else true
	if args.has("bake"):
		_bake()
		return
	_setup_environment()
	_build()
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

## The cannon through the game's own path, so the art model and the moved anchors are real.
## The baked copy in the scene is the editor's picture only; play always rebuilds.
func _build() -> void:
	var baked := get_node_or_null("Cannon")
	if baked != null:
		baked.free()
	cannon = Catalog.spawn("cannon", self)
	cannon.name = "Cannon"
	shooter = U.comp(cannon, "Shooter")
	shooter.try_aim(TARGET)
	var sp: Node3D = shooter.get_node(shooter.projectileSpawn)
	if cannon.find_child("Origin", true, false) == null:
		_marker(cannon, sp.global_position, Color(0.0, 1.0, 0.0), 0.045, "Origin")
	print("fx_check origin ", sp.global_position)

## Saves the built, aimed cannon with its markers as the scene the editor opens.
func _bake() -> void:
	_build()
	var sp: Node3D = shooter.get_node(shooter.projectileSpawn)
	if cannon.find_child("FlashCentre", true, false) == null:
		_marker(cannon, sp.global_position + _aim_dir(sp) * 0.2, Color(1.0, 0.9, 0.0), 0.03, "FlashCentre")
	for n in cannon.find_children("*", "Node", true, false):
		n.owner = cannon
	var packed := PackedScene.new()
	if packed.pack(cannon) != OK or ResourceSaver.save(packed, BAKE_PATH) != OK:
		push_error("fx_check bake failed")
		get_tree().quit(1)
		return
	var check := (load(BAKE_PATH) as PackedScene).instantiate()
	print("fx_check baked meshes=", check.find_children("*", "MeshInstance3D", true, false).size(),
			" origin=", check.find_child("Origin", true, false) != null,
			" flash=", check.find_child("FlashCentre", true, false) != null)
	check.free()
	get_tree().quit()

func _aim_dir(sp: Node3D) -> Vector3:
	var flat := TARGET - sp.global_position
	flat.y = 0.0
	flat = flat.normalized() if flat.length_squared() > 0.0001 else -cannon.global_transform.basis.z
	return (flat * cos(shooter.angleRads) + Vector3.UP * sin(shooter.angleRads)).normalized()

func _fire(forced: String) -> void:
	FX.ENABLED = true
	FX.style = forced if forced != "" else STYLES[i % STYLES.size()]
	i += 1
	shooter.try_aim(TARGET)
	var sp: Node3D = shooter.get_node(shooter.projectileSpawn)
	var dir := _aim_dir(sp)
	FX.muzzle(sp.global_position, dir)
	var centre := sp.global_position + dir * 0.2
	if not framed:
		framed = true
		orbit_pivot = sp.global_position
		if not has_node("FlashCentre"):
			_marker(self, centre, Color(1.0, 0.9, 0.0), 0.03, "FlashCentre")
		var flat := TARGET - sp.global_position
		flat.y = 0.0
		flat = flat.normalized()
		var perp := flat.cross(Vector3.UP).normalized()
		orbit_yaw = atan2(perp.x, perp.z)
		camera.global_position = sp.global_position + perp * 2.6 + Vector3.UP * 1.15
		camera.look_at(sp.global_position + flat * 0.6)
	print("fx_check style=%s barrel=%.1f deg anchor=%s flash_centre=%s anchor_screen=%s centre_screen=%s"
			% [FX.style, shooter.angleDegrees, sp.global_position, centre,
			camera.unproject_position(sp.global_position), camera.unproject_position(centre)])

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or camera == null or not framed:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			orbit_dist = maxf(0.6, orbit_dist * 0.88)
			_place_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			orbit_dist = minf(40.0, orbit_dist / 0.88)
			_place_camera()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			orbiting = event.pressed
	elif event is InputEventMouseMotion and orbiting:
		manual_cam = true
		orbit_yaw -= event.relative.x * 0.005
		orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.005, -1.45, 1.45)
		_place_camera()

func _place_camera() -> void:
	var flat := Vector3(cos(orbit_pitch) * sin(orbit_yaw), sin(orbit_pitch), cos(orbit_pitch) * cos(orbit_yaw))
	camera.global_position = orbit_pivot + flat * orbit_dist
	camera.look_at(orbit_pivot)

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

func _marker(parent: Node, at: Vector3, col: Color, r: float, node_name: String) -> void:
	var m := MeshInstance3D.new()
	m.name = node_name
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
	m.global_position = at
