extends Node
## Applies one entry of tools/looks.json to a running Main, after its _setup_environment built
## the WorldEnvironment, the DirectionalLight and the sky (round 25 of blender-ai). Tool-side
## only: the game itself never reads looks.json.

static func apply(main, cfg: Dictionary) -> void:
	var env: Environment = main.get_node("WorldEnvironment").environment
	var light = main.get_node("DirectionalLight")
	if cfg.has("sky"):
		var mat := PanoramaSkyMaterial.new()
		mat.panorama = load("res://assets/art/sky/%s.png" % cfg["sky"])
		env.sky = Sky.new()
		env.sky.sky_material = mat
		env.background_mode = Environment.BG_SKY
	if cfg.has("bg"):
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(cfg["bg"])
	if cfg.has("sun"):
		light.light_color = Color(cfg["sun"][0])
		light.light_energy = cfg["sun"][1]
	if cfg.has("shadow"):
		light.shadow_opacity = cfg["shadow"]
	if cfg.has("sun_angle"):
		var elevation := deg_to_rad(cfg["sun_angle"])
		var azimuth := deg_to_rad(40.0)
		var to_sun := Vector3(cos(elevation) * sin(azimuth), sin(elevation), cos(elevation) * cos(azimuth))
		light.basis = Basis.looking_at(-to_sun, Vector3.UP)
	if cfg.has("ambient"):
		env.ambient_light_color = Color(cfg["ambient"][0])
		env.ambient_light_energy = cfg["ambient"][1]
	if cfg.has("fog"):
		var f: Dictionary = cfg["fog"]
		if f.has("colour"):
			env.fog_light_color = Color(f["colour"])
		if f.has("sky"):
			env.fog_sky_affect = f["sky"]
		if f.has("range"):
			env.fog_depth_end = env.fog_depth_begin + (env.fog_depth_end - env.fog_depth_begin) * f["range"]
	var p: Dictionary = cfg.get("post", {})
	if p.has("tonemap"):
		env.tonemap_mode = {
			"linear": Environment.TONE_MAPPER_LINEAR, "filmic": Environment.TONE_MAPPER_FILMIC,
			"aces": Environment.TONE_MAPPER_ACES, "reinhard": Environment.TONE_MAPPER_REINHARDT,
		}[p["tonemap"]]
	if p.has("exposure"):
		env.tonemap_exposure = p["exposure"]
	if p.has("white"):
		env.tonemap_white = p["white"]
	if p.has("brightness") or p.has("contrast") or p.has("saturation"):
		env.adjustment_enabled = true
		env.adjustment_brightness = p.get("brightness", 1.0)
		env.adjustment_contrast = p.get("contrast", 1.0)
		env.adjustment_saturation = p.get("saturation", 1.0)
	if p.has("glow"):
		env.glow_enabled = true
		env.glow_intensity = p["glow"]
