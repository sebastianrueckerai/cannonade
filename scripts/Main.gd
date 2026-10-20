extends Node3D
## Builds a game from one of the original Unity scenes' configurations
## (singlePlayer, multiPlayer, 4ai) and wires up camera, light and UI.
##
## Command line (after "--"): --mode=single|versus|ai2|ai4|practice --seed=N
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
	# Assets/Scenes/multiPlayer.unity: human against one AI; rules v3: 45 s build, 30 s battle
	"versus": {"players": ["human", "ai"], "size": 34, "round": 45.0, "battle": 30.0, "pitch": 60.0, "fov": 30.0, "ships": 7},
	# two AIs (handy to watch / for tests)
	"ai2": {"players": ["ai", "ai"], "size": 34, "round": 45.0, "battle": 30.0, "pitch": 60.0, "fov": 30.0, "ships": 7},
	# Assets/Scenes/4ai.unity: four AIs
	"ai4": {"players": ["ai", "ai", "ai", "ai"], "size": 60, "round": 25.0, "pitch": 71.42, "fov": 37.44, "ships": 7},
	# practice: you against a dormant AI on the standard map; Enter switches between build and battle, no timer
	"practice": {"players": ["human", "ai"], "size": 34, "round": 1e9, "battle": 1e9, "pitch": 60.0, "fov": 30.0, "ships": 0,
		"practice": true},
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
var practice := false
## The seed this game runs on, captured wherever it is set, so Retry replays the same map
var _used_seed := 1
var _preview_env: Environment = null
## Set before adding the node to build from this config instead of a mode
## (used by the sandbox). Extra keys: "seed", "decorate", "colors" (hex per
## player), "hud" (timer / phase / help, default true), "previews" (next piece
## previews, default true).
var config := {}
## Set by the loading screen before the node enters the tree: the map is then built over many frames, `progress`
## says how far (0..1) and `built` follows once the game runs.
var staged := false
var progress: float:
	get:
		return game.map.progress if game != null and game.map != null else 0.0

signal built


func _ready() -> void:
	U.reset()
	if not config.is_empty():
		_used_seed = int(config.get("seed", 1))
		seed(_used_seed)
		build(config, config.get("decorate", true))
		return
	var args := _parse_args()
	args.merge(requested_args, true)
	mode = requested_mode if requested_mode != "" else args.get("mode", "versus")
	if not MODES.has(mode):
		mode = "versus"
	if args.has("seed"):
		_used_seed = int(args["seed"])
	else:
		randomize()
		_used_seed = randi()
	seed(_used_seed)
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
	practice = cfg.get("practice", false)
	_setup_environment(cfg)
	_setup_ui()
	var map = _component("Map", MapScript)
	map.sizeX = cfg["size"]
	map.sizeZ = cfg["size"]
	map.decorate = decorate
	map.staged = staged
	var fleet = _component("FleetControll", ShipFleet)
	game = _component("Game", GameController)
	game.roundDuration = cfg["round"]
	game.battleDuration = cfg.get("battle", cfg["round"])
	game.initialShips = cfg["ships"]
	game.castles = cfg.get("castles", true)
	game.map = map
	game.fleet = fleet
	game.roundTimer = ui.get_node("Timer")
	var kinds: Array = cfg["players"]
	Indicators.own_player = null  # static: reset every game, then the human owns the aim arcs
	var looks: Array = Catalog.deal_wall_looks()  # every player another look, no look twice (D81)
	for i in kinds.size():
		var script: Script = AIScript if kinds[i] == "ai" else PlayerController
		var p = _component("%s%d" % ["AI" if kinds[i] == "ai" else "HumanPlayer", i + 1], script)
		if kinds[i] != "ai":
			Indicators.own_player = p
		var colors: Array = PLAYER_COLORS[i % PLAYER_COLORS.size()].duplicate()
		if cfg.has("colors"):
			colors[0] = cfg["colors"][i]
		p.mainColorHexCode = colors[0]
		p.wallLook = looks[i % looks.size()]
		p.highlightPosColorHexCode = colors[1]
		p.highlightNegColorHexCode = colors[2]
		game.players.append(p)
		var spawns := _make_spawns(i, kinds.size())
		game.wallSpawns.append(spawns[0])
		game.buildingSpawns.append(spawns[1])
		for s in spawns:
			s.visible = cfg.get("previews", true)
		var hud := _make_player_hud(i, kinds[i] == "ai", Color.html(colors[0]))
		game.partsLabels.append(hud[0])
		game.castlesLabels.append(hud[1])
	fleet.enemyPlayers = game.players.duplicate()
	game.round_changed.connect(_on_round_changed)
	game.game_over.connect(_on_game_over)
	await game.start_game()
	if practice:
		game.players[1].dormant = true
		for n in [game.wallSpawns[1], game.buildingSpawns[1], ui.get_node("Hud2"), ui.get_node("Timer")]:
			n.visible = false
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
	built.emit()


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


## Next wall / next building previews (Unity: wallSpawnN / upgradeSpawnN on the camera
## overlay canvas). Each piece sits in its own orthogonal SubViewport, shown as a
## TextureRect in a screen corner: the wall icon is the piece seen from above (its
## tetris footprint, square to the screen), the building icon its front. Pieces placed
## on the camera itself came out skewed by the corner perspective.
func _make_spawns(i: int, _n: int) -> Array:
	var right := i % 2 == 1
	var top := i >= 2
	return [
		_make_preview_slot("wall", i, right, top),
		_make_preview_slot("building", i, right, top),
	]


func _make_preview_slot(kind: String, i: int, right: bool, top: bool) -> Node3D:
	var wall := kind == "wall"
	var size := Vector2i(120, 120) if wall else Vector2i(150, 100)
	# distance of the icon from its screen corner (the panel adds 8 px all round); the
	# building sits above the wall. In ai4 the top corners also carry the supply bars,
	# so players 3 / 4's icons start below those.
	var margin_y := (16 if wall else 162) if not top else (262 if wall else 136)
	var vp := SubViewport.new()
	vp.name = "%sPreview%d" % [kind, i + 1]
	vp.size = size
	vp.transparent_bg = true
	vp.world_3d = World3D.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	if wall:
		cam.size = 4.4  # a four-long piece fits
		cam.position = Vector3(0, 6, 0)
		# looks down; map up (-z) is screen up
		cam.basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	else:
		cam.size = 3.2
		cam.position = Vector3(0, 1.3, 6)  # default orientation: front view
	vp.add_child(cam)
	var light := DirectionalLight3D.new()
	light.light_color = Color("#ffd29d")
	light.basis = Basis.looking_at(-Vector3(0.44, 0.62, 0.65), Vector3.UP)  # the board's sun
	vp.add_child(light)
	if _preview_env == null:
		_preview_env = Environment.new()
		_preview_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_preview_env.ambient_light_color = Color("#bec3c4")
		_preview_env.ambient_light_energy = 0.46
	var we := WorldEnvironment.new()
	we.environment = _preview_env
	vp.add_child(we)
	var spawn := Node3D.new()
	spawn.name = "%sSpawn%d" % [kind, i + 1]
	vp.add_child(spawn)
	var panel := PanelContainer.new()
	panel.name = "%sPanel%d" % [kind, i + 1]
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.09, 0.45)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	var rect := TextureRect.new()
	rect.name = "%sRect%d" % [kind, i + 1]
	rect.texture = vp.get_texture()
	rect.custom_minimum_size = size
	panel.add_child(rect)
	panel.anchor_left = 1.0 if right else 0.0
	panel.anchor_right = panel.anchor_left
	panel.anchor_top = 0.0 if top else 1.0
	panel.anchor_bottom = panel.anchor_top
	var w := float(size.x + 16)
	var h := float(size.y + 16)
	var mx := 16.0
	var my := float(margin_y)
	panel.offset_left = -mx - w if right else mx
	panel.offset_right = -mx if right else mx + w
	panel.offset_top = my if top else -my - h
	panel.offset_bottom = my + h if top else -my
	ui.add_child(panel)
	spawn.visibility_changed.connect(_slot_visibility_changed.bind(spawn, vp, panel))
	return spawn


## The "previews" config flag and the practice mode toggle the spawns; the icons follow.
func _slot_visibility_changed(spawn: Node3D, vp: SubViewport, panel: Control) -> void:
	panel.visible = spawn.visible
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if spawn.visible else SubViewport.UPDATE_DISABLED


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
	help.text = "LMB: place / stack wall piece   RMB: place gun (costs parts) / combine   X / Y: rotate piece   Space: fire   Wheel: zoom   MMB drag: pan   Esc: menu"
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 4)
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.offset_left = -400
	help.offset_right = 400
	help.offset_top = -28
	ui.add_child(help)


## One HUD panel a player: parts used over cap and castles held, [parts, castles] labels.
func _make_player_hud(i: int, is_ai: bool, color: Color) -> Array:
	var box := VBoxContainer.new()
	box.name = "Hud%d" % (i + 1)
	var right := i % 2 == 1
	var x := 10.0  # ai4: players 3 / 4's panels sit beside players 1 / 2's, above their icons
	if i >= 2:
		x = 200.0
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT if right else Control.PRESET_TOP_LEFT)
	box.position = Vector2(-x - 180.0 if right else x, 10.0)
	if right:
		box.anchor_left = 1.0
		box.anchor_right = 1.0
		box.offset_left = -x - 180.0
		box.offset_right = -x
		box.offset_top = 10.0
	box.custom_minimum_size = Vector2(180, 0)
	ui.add_child(box)
	var title := Label.new()
	title.text = "%s %d" % ["AI" if is_ai else "Player", i + 1]
	title.add_theme_color_override("font_color", color.lightened(0.4))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	box.add_child(title)
	var labels: Array = []
	for text in ["parts 0 / 0", "castles 0"]:
		var l := Label.new()
		l.text = text
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 4)
		box.add_child(l)
		labels.append(l)
	return labels


func _on_round_changed(_n: int, building: bool) -> void:
	if phase_label:
		phase_label.text = "BUILD PHASE" if building else "BATTLE PHASE"
		if practice:
			phase_label.text += "   Enter: " + ("battle" if building else "build")
		phase_label.modulate = Color.GREEN if building else Color.RED


func _process(_delta: float) -> void:
	if quit_after > 0 and U.time >= quit_after:
		print("quit-after reached at t=%.1f" % U.time)
		get_tree().quit()
	_update_hud()


func _update_hud() -> void:
	if game == null or game.players.is_empty():
		return
	for p in game.players:
		if p.partsLabel != null:
			var used: int = p.parts_used()
			p.partsLabel.text = "parts %d / %d" % [used, p.partsCap]
			# the cap drops with a lost castle; the guns already placed can then exceed it
			if used > p.partsCap:
				p.partsLabel.add_theme_color_override("font_color", Color.RED)
			else:
				p.partsLabel.remove_theme_color_override("font_color")
		if p.castlesLabel != null:
			p.castlesLabel.text = "castles %d" % p.castle_count()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		Catalog.reload()
		_toast("Building data reloaded" if Catalog.errors.is_empty()
				else "Building data reloaded – %d problem(s):\n%s" % [Catalog.errors.size(), "\n".join(Catalog.errors)])
	if practice and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		game.next_phase()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_K, KEY_L]:
		_test_end(event.keycode == KEY_K)
	if event.is_action_pressed("ui_cancel"):
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file("res://scenes/menu.tscn")


## Testing keys: K wins the running game for the human, L loses it to the first other player.
func _test_end(win: bool) -> void:
	var own = Indicators.own_player
	if own == null or not game.started:
		return
	game.end(own if win else game.players.filter(func(p): return p != own)[0])


## Rules v3 end: VICTORY / DEFEAT against the human's side (the winner's name in watch mode, DRAW on a draw)
## over the win or lose art, which covers the screen like the menu's, or over the dimmed board without it.
## Retry replays the seed.
func _on_game_over(winner) -> void:
	var own = Indicators.own_player
	Sound.music("win" if winner != null and (own == null or winner == own) else "lose")
	var title := "DRAW"
	if winner != null:
		if own == null:
			title = "%s WINS" % winner.go.name.to_upper()
		elif winner == own:
			title = "VICTORY"
		else:
			title = "DEFEAT"
	var layer := CanvasLayer.new()
	layer.name = "GameOver"
	layer.layer = 10
	add_child(layer)
	var screen := Control.new()
	screen.theme = Art.theme()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(screen)
	var tex := Art.texture("win.png" if winner == own else "lose.png") if own != null and winner != null else null
	if tex != null:
		var img := TextureRect.new()
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen.add_child(img)
	else:
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.55)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen.add_child(dim)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 72)
	label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_top = 24
	screen.add_child(label)
	# the buttons sit in the bottom right like the loading screen's bar, off the art's subject
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.position -= Vector2(24, 16)
	screen.add_child(panel)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	panel.add_child(buttons)
	for text in ["Retry", "Menu"]:
		var b := Button.new()
		b.text = text
		b.custom_minimum_size = Vector2(160, 44)
		b.pressed.connect(_retry if text == "Retry" else _to_menu)
		buttons.add_child(b)
	Sound.buttons(buttons)


func _retry() -> void:
	Engine.time_scale = 1.0
	requested_mode = mode
	requested_args = {"seed": str(_used_seed)}
	get_tree().reload_current_scene()


func _to_menu() -> void:
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
