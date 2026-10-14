extends Node3D
## Builds a game from one of the original Unity scenes' configurations
## (singlePlayer, multiPlayer, 4ai) and wires up camera, light and UI.
##
## Command line (after "--"): --mode=single|versus|ai2|ai4 --seed=N
##   --round=SECONDS --size=TILES --timescale=F --quit-after=SECONDS --no-decorations

const GameController = preload("res://scripts/components/GameController.gd")
const MapScript = preload("res://scripts/components/Map.gd")
const ShipFleet = preload("res://scripts/components/ShipFleet.gd")
const PlayerController = preload("res://scripts/components/PlayerController.gd")
const AIScript = preload("res://scripts/components/AI.gd")
const CameraRig = preload("res://scripts/CameraRig.gd")

const MODES := {
	# Assets/Scenes/singlePlayer.unity: one human against the ship fleet
	"single": {"players": ["human"], "size": 20, "round": 250.0, "pitch": 71.42, "fov": 37.44, "ships": 7},
	# Assets/Scenes/multiPlayer.unity: human against one AI
	"versus": {"players": ["human", "ai"], "size": 30, "round": 150.0, "pitch": 60.0, "fov": 30.0, "ships": 7},
	# two AIs (handy to watch / for tests)
	"ai2": {"players": ["ai", "ai"], "size": 30, "round": 30.0, "pitch": 60.0, "fov": 30.0, "ships": 7},
	# Assets/Scenes/4ai.unity: four AIs
	"ai4": {"players": ["ai", "ai", "ai", "ai"], "size": 60, "round": 25.0, "pitch": 71.42, "fov": 37.44, "ships": 7},
}
# The team set of the art kit, game/art-direction/palette.json in the blender-ai repo (D21): main, highlight plus, highlight minus.
const PLAYER_COLORS := [
	["#2d55c4", "#aaaadd", "#ad3030"],
	["#7b2fa3", "#c9a0e0", "#e01414"],
	["#197059", "#aaddab", "#ad3030"],
	["#8c7a1f", "#e0d58a", "#ad3030"],
]

static var requested_mode := ""
static var requested_args := {}

var mode := "versus"
var game = null
var camera: Camera3D
var ui: CanvasLayer
var phase_label: Label
var quit_after := -1.0
## Set before adding the node to build from this config instead of a mode
## (used by the sandbox). Extra keys: "seed", "decorate", "colors" (hex per
## player), "hud" (timer / phase / help, default true), "previews" (next piece
## previews, default true).
var config := {}


func _ready() -> void:
	U.reset()
	if not config.is_empty():
		seed(int(config.get("seed", 1)))
		build(config, config.get("decorate", true))
		return
	var args := _parse_args()
	args.merge(requested_args, true)
	mode = requested_mode if requested_mode != "" else args.get("mode", "versus")
	if not MODES.has(mode):
		mode = "versus"
	if args.has("seed"):
		seed(int(args["seed"]))
	else:
		randomize()
	if args.has("timescale"):
		Engine.time_scale = float(args["timescale"])
	if args.has("quit-after"):
		quit_after = float(args["quit-after"])
	var cfg: Dictionary = MODES[mode].duplicate()
	if args.has("round"):
		cfg["round"] = float(args["round"])
	if args.has("size"):
		cfg["size"] = int(args["size"])
	build(cfg, not args.has("no-decorations"))


func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return out


func _component(node_name: String, script: Script, parent: Node = self) -> Node:
	var go := Node3D.new()
	go.name = node_name
	parent.add_child(go)
	var c := Node.new()
	c.name = script.resource_path.get_file().get_basename()
	c.set_script(script)
	go.add_child(c)
	return c


func build(cfg: Dictionary, decorate := true) -> void:
	_setup_environment(cfg)
	_setup_ui()
	var map = _component("Map", MapScript)
	map.sizeX = cfg["size"]
	map.sizeZ = cfg["size"]
	map.decorate = decorate
	var fleet = _component("FleetControll", ShipFleet)
	game = _component("Game", GameController)
	game.roundDuration = cfg["round"]
	game.initialShips = cfg["ships"]
	game.startBases = cfg.get("start_bases", true)
	game.map = map
	game.fleet = fleet
	game.roundTimer = ui.get_node("Timer")
	var kinds: Array = cfg["players"]
	Indicators.own_player = null  # static: reset every game, then the human owns the aim arcs
	for i in kinds.size():
		var script: Script = AIScript if kinds[i] == "ai" else PlayerController
		var p = _component("%s%d" % ["AI" if kinds[i] == "ai" else "HumanPlayer", i + 1], script)
		if kinds[i] != "ai":
			Indicators.own_player = p
		var colors: Array = PLAYER_COLORS[i % PLAYER_COLORS.size()].duplicate()
		if cfg.has("colors"):
			colors[0] = cfg["colors"][i]
		p.mainColorHexCode = colors[0]
		p.highlightPosColorHexCode = colors[1]
		p.highlightNegColorHexCode = colors[2]
		game.players.append(p)
		var spawns := _make_spawns(i, kinds.size())
		game.wallSpawns.append(spawns[0])
		game.buildingSpawns.append(spawns[1])
		for s in spawns:
			s.visible = cfg.get("previews", true)
		var bars := _make_supply_bars(i, kinds[i] == "ai", Color.html(colors[0]))
		game.supplyBars.append(bars[0])
		game.supplyNeededBars.append(bars[1])
	fleet.enemyPlayers = game.players.duplicate()
	game.round_changed.connect(_on_round_changed)
	game.start_game()
	camera.capture_home_view(map.sizeX * map.tileSize / 2.0)
	# The fog starts at the far edge of the board and is full at 1.8 times that distance from the camera, so it
	# never covers a tile the player builds on.
	var far_edge := camera.global_position.distance_to(Vector3(0, 0, -map.sizeZ * map.tileSize / 2.0))
	var env: Environment = $WorldEnvironment.environment
	env.fog_depth_begin = far_edge
	env.fog_depth_end = far_edge * 1.8
	_on_round_changed(0, true)
	if not cfg.get("hud", true):
		for n in ["Timer", "Phase", "Help"]:
			ui.get_node(n).visible = false


func _setup_environment(cfg: Dictionary) -> void:
	camera = CameraRig.new()
	camera.name = "MainCamera"
	camera.fov = cfg["fov"]
	camera.far = 500.0
	add_child(camera)
	camera.rotation_degrees = Vector3(-cfg["pitch"], 0, 0)
	camera.make_current()
	# The shipped look of round 25 (D52), the midpoint of candidates 9 and 10 that Sebastian picked:
	# the sun 38 degrees up, 40 degrees to the right of the line from the board to the camera, warm,
	# strong shadows, near-neutral ambient, filmic grade with a touch of glow. Values mirror the
	# soft_honey entry of tools/looks.json and lighting_rules.yaml in the blender-ai repo.
	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight"
	var elevation := deg_to_rad(38.0)
	var azimuth := deg_to_rad(40.0)
	var to_sun := Vector3(cos(elevation) * sin(azimuth), sin(elevation), cos(elevation) * cos(azimuth))
	light.basis = Basis.looking_at(-to_sun, Vector3.UP)
	light.light_color = Color("#ffd29d")
	light.light_energy = 0.65
	light.shadow_enabled = true
	light.shadow_opacity = 0.56
	add_child(light)
	var env := Environment.new()
	var sky_tex := Art.sky_texture()
	if sky_tex != null:
		var sky_mat := PanoramaSkyMaterial.new()
		sky_mat.panorama = sky_tex
		env.sky = Sky.new()
		env.sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("#6cb9f5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#bec3c4")
	env.ambient_light_energy = 0.46
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("#f4e6cd")
	env.fog_sky_affect = 0.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.97
	env.tonemap_white = 6.25
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.07
	env.glow_enabled = true
	env.glow_intensity = 0.26
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)


## Next wall / next building previews (Unity: wallSpawnN / upgradeSpawnN on the
## camera overlay canvas). Children of the camera, in the screen corners.
func _make_spawns(i: int, _n: int) -> Array:
	var d := 8.0
	var half_h := tan(deg_to_rad(camera.fov) / 2.0) * d
	var half_w := half_h * 16.0 / 9.0
	var right := i % 2 == 1
	var top := i >= 2
	var x := (half_w - 0.45) * (1.0 if right else -1.0)
	var y := (half_h * 0.55) * (1.0 if top else -1.0)
	var out: Array = []
	for k in 2:
		var s := Node3D.new()
		s.name = "%sSpawn%d" % ["wall" if k == 0 else "building", i + 1]
		camera.add_child(s)
		s.position = Vector3(x, y + (0.0 if k == 0 else 0.75), -d)
		# model up axis towards the camera, model "up" (-z) towards screen up
		s.basis = Basis(Vector3.RIGHT, PI / 2.0).scaled(Vector3.ONE * 0.4)
		out.append(s)
	return out


func _setup_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var timer := Label.new()
	timer.name = "Timer"
	timer.add_theme_font_size_override("font_size", 40)
	timer.add_theme_color_override("font_outline_color", Color.BLACK)
	timer.add_theme_constant_override("outline_size", 8)
	timer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.offset_left = -60
	timer.offset_right = 60
	timer.offset_top = 8
	ui.add_child(timer)
	phase_label = Label.new()
	phase_label.name = "Phase"
	phase_label.add_theme_font_size_override("font_size", 20)
	phase_label.add_theme_color_override("font_outline_color", Color.BLACK)
	phase_label.add_theme_constant_override("outline_size", 6)
	phase_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.offset_left = -200
	phase_label.offset_right = 200
	phase_label.offset_top = 58
	ui.add_child(phase_label)
	var help := Label.new()
	help.name = "Help"
	help.text = "LMB: place wall   RMB: place building / combine   X / Y: rotate wall   Space: fire   Wheel: zoom   MMB drag: pan   Esc: menu"
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 4)
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.offset_left = -400
	help.offset_right = 400
	help.offset_top = -28
	ui.add_child(help)


func _make_supply_bars(i: int, is_ai: bool, color: Color) -> Array:
	var box := VBoxContainer.new()
	box.name = "Supply%d" % (i + 1)
	var right := i % 2 == 1
	var top_y := 10.0 if i < 2 else 260.0
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT if right else Control.PRESET_TOP_LEFT)
	box.position = Vector2(-190 if right else 10, top_y)
	if right:
		box.anchor_left = 1.0
		box.anchor_right = 1.0
		box.offset_left = -190
		box.offset_right = -10
		box.offset_top = top_y
	box.custom_minimum_size = Vector2(180, 0)
	ui.add_child(box)
	var title := Label.new()
	title.text = "%s %d" % ["AI" if is_ai else "Player", i + 1]
	title.add_theme_color_override("font_color", color.lightened(0.4))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	box.add_child(title)
	var bars: Array = []
	for k in 2:
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.step = 0.001
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(180, 14)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.2, 0.75, 0.3) if k == 0 else Color(0.85, 0.35, 0.2)
		bar.add_theme_stylebox_override("fill", fill)
		var label := Label.new()
		label.text = "supply" if k == 0 else "supply needed"
		label.add_theme_font_size_override("font_size", 11)
		box.add_child(label)
		box.add_child(bar)
		bars.append(bar)
	return bars


func _on_round_changed(_n: int, building: bool) -> void:
	if phase_label:
		phase_label.text = "BUILD PHASE" if building else "BATTLE PHASE"
		phase_label.modulate = Color.GREEN if building else Color.RED


func _process(_delta: float) -> void:
	if quit_after > 0 and U.time >= quit_after:
		print("quit-after reached at t=%.1f" % U.time)
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		Catalog.reload()
		_toast("Building data reloaded" if Catalog.errors.is_empty()
				else "Building data reloaded – %d problem(s):\n%s" % [Catalog.errors.size(), "\n".join(Catalog.errors)])
	if event.is_action_pressed("ui_cancel"):
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file("res://scenes/menu.tscn")


## Short message in the middle of the screen.
func _toast(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	ui.add_child(l)
	get_tree().create_timer(4.0 if Catalog.errors.is_empty() else 10.0).timeout.connect(l.queue_free)
