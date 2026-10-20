extends Node3D
## Builds a game from one of the original Unity scenes' configurations
## (singlePlayer, multiPlayer, 4ai) and wires up camera, light and UI.
##
## Command line (after "--"): --mode=single|versus|ai2|ai4|practice --seed=N
##   --walls=SECONDS --guns=SECONDS --battle=SECONDS --size=TILES --width=TILES --timescale=F
##   --quit-after=SECONDS --no-decorations

const GameController = preload("res://scripts/components/GameController.gd")
const MapScript = preload("res://scripts/components/Map.gd")
const ShipFleet = preload("res://scripts/components/ShipFleet.gd")
const PlayerController = preload("res://scripts/components/PlayerController.gd")
const AIScript = preload("res://scripts/components/AI.gd")
const CameraRig = preload("res://scripts/CameraRig.gd")

## "size" is the board's depth and its width unless "width" says otherwise; a round is "walls", "guns" and
## "battle" seconds. The 52 by 34 board fills the 16:9 window at the home view (session 38).
const MODES := {
	# Assets/Scenes/singlePlayer.unity: one human against the ship fleet
	"single": {"players": ["human"], "size": 20, "walls": 200.0, "guns": 50.0, "battle": 250.0, "pitch": 71.42,
		"fov": 37.44, "ships": 7},
	# Assets/Scenes/multiPlayer.unity: human against one AI; rules v3: 45 s walls, 15 s cannons, 30 s battle
	"versus": {"players": ["human", "ai"], "size": 34, "width": 52, "walls": 45.0, "guns": 15.0, "battle": 30.0,
		"pitch": 60.0, "fov": 30.0, "ships": 7},
	# two AIs (handy to watch / for tests)
	"ai2": {"players": ["ai", "ai"], "size": 34, "width": 52, "walls": 45.0, "guns": 15.0, "battle": 30.0,
		"pitch": 60.0, "fov": 30.0, "ships": 7},
	# Assets/Scenes/4ai.unity: four AIs
	"ai4": {"players": ["ai", "ai", "ai", "ai"], "size": 60, "walls": 20.0, "guns": 5.0, "battle": 25.0,
		"pitch": 71.42, "fov": 37.44, "ships": 7},
	# practice: you against a dormant AI on the standard map; Enter steps to the next phase, no timer
	"practice": {"players": ["human", "ai"], "size": 34, "width": 52, "walls": 1e9, "guns": 1e9, "battle": 1e9,
		"pitch": 60.0, "fov": 30.0, "ships": 0, "practice": true},
}
## The HUD's parchment, from palette.json: ink on parchment, the accent red, and a colour a phase.
const INK := Color("#3a2e28")
const PARCHMENT := Color("#fbefd9")
const ACCENT := Color("#c8322d")
const PHASE_COLORS := [Color("#3d7f34"), Color("#7a4a2e"), ACCENT]
const PHASE_NAMES := ["BUILD WALLS", "PLACE CANNONS", "BATTLE"]
## Space between a plaque and the window's edge
const HUD_GAP := 6.0
const HELP := [
	"LMB: place the piece, or stack it on your walls   X / Y: rotate   click off the board: discard   Wheel: zoom   MMB drag: pan   Esc: menu",
	"LMB: place the cannon (costs parts), on a cannon: fuse   click off the board: discard   Wheel: zoom   MMB drag: pan   Esc: menu",
	"LMB: fire at the cursor   Wheel: zoom   MMB drag: pan   Esc: menu",
]
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
var quit_after := -1.0
var practice := false
## The seed this game runs on, captured wherever it is set, so Retry replays the same map
var _used_seed := 1
## The HUD: the countdown, the phase word, the help line, and a parts / castles pair a player
var _count: Label
var _phase: Label
## The banner that counts each phase in: its phase word and its seconds
var _banner: PanelContainer
var _bannerPhase: Label
var _bannerCount: Label
var _help: Label
var _huds: Array = []
## Set before adding the node to build from this config instead of a mode
## (used by the sandbox). Extra keys: "seed", "decorate", "colors" (hex per
## player), "hud" (timer / phase / help, default true), "band" (the share of the
## view's height kept clear of the board at the top and the bottom, Vector2).
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
	for key in ["walls", "guns", "battle", "ready"]:
		if args.has(key):
			cfg[key] = float(args[key])
	for key in ["size", "width"]:
		if args.has(key):
			cfg[key] = int(args[key])
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
	map.sizeX = cfg.get("width", cfg["size"])
	map.sizeZ = cfg["size"]
	map.decorate = decorate
	map.staged = staged
	var fleet = _component("FleetControll", ShipFleet)
	game = _component("Game", GameController)
	game.wallDuration = cfg["walls"]
	game.gunDuration = cfg["guns"]
	game.battleDuration = cfg["battle"]
	game.readyDuration = cfg.get("ready", game.readyDuration)
	game.initialShips = cfg["ships"]
	game.castles = cfg.get("castles", true)
	game.map = map
	game.fleet = fleet
	game.hudBand = cfg.get("band", _hud_band() if cfg.get("hud", true) else Vector2.ZERO)
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
		_huds.append(_make_player_hud(i, kinds[i] == "ai", Color.html(colors[0])))
	fleet.enemyPlayers = game.players.duplicate()
	game.phase_changed.connect(_on_phase_changed)
	game.game_over.connect(_on_game_over)
	await game.start_game()
	if practice:
		game.players[1].dormant = true
		ui.get_node("Hud2").visible = false
		_count.visible = false
	camera.capture_home_view(Vector2(map.sizeX, map.sizeZ) * map.tileSize / 2.0)
	# The fog starts at the far edge of the board and is full at 1.8 times that distance from the camera, so it
	# never covers a tile the player builds on.
	var far_edge := camera.global_position.distance_to(Vector3(0, 0, -map.sizeZ * map.tileSize / 2.0))
	var env: Environment = $WorldEnvironment.environment
	env.fog_depth_begin = far_edge
	env.fog_depth_end = far_edge * 1.8
	_on_phase_changed(game.phase)
	if not cfg.get("hud", true):
		for n in ["Timer", "Help"]:
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


## The HUD wears the menu's parchment (D7): ink on parchment plaques in the Alegreya of Art.theme(). The
## countdown with the phase word under it at the top, a parts / castles plaque a player in the top corners, the
## help line for the phase at the bottom, the banner that counts each phase in at the centre.
func _setup_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var timer := _plaque("Timer")
	timer.anchor_left = 0.5
	timer.anchor_right = 0.5
	timer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	timer.offset_top = HUD_GAP
	timer.offset_bottom = HUD_GAP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	timer.add_child(row)
	_count = _label("Count", 30)
	_count.custom_minimum_size.x = 44
	row.add_child(_count)
	_phase = _label("Phase", 15)
	_phase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_phase)
	var help := _plaque("Help")
	help.anchor_left = 0.5
	help.anchor_right = 0.5
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help.offset_top = -HUD_GAP
	help.offset_bottom = -HUD_GAP
	_help = _label("Text", 12)
	help.add_child(_help)
	_banner = _plaque("Banner")
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -6)
	_banner.add_child(col)
	_bannerPhase = _label("Word", 26)
	col.add_child(_bannerPhase)
	_bannerCount = _label("Seconds", 44, ACCENT)
	col.add_child(_bannerCount)


## The board fits between the timer and the help line: the share of the view's height each takes, with a gap.
func _hud_band() -> Vector2:
	var h: float = get_viewport().get_visible_rect().size.y
	var top: float = ui.get_node("Timer").get_combined_minimum_size().y + 2.0 * HUD_GAP
	var bottom: float = ui.get_node("Help").get_combined_minimum_size().y + 2.0 * HUD_GAP
	return Vector2(top, bottom) / h


## One parchment plaque, themed like the menu. It only shows: the mouse goes through to the board and the camera.
func _plaque(name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme = Art.theme()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PARCHMENT, 0.92)
	sb.border_color = INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", sb)
	ui.add_child(panel)
	return panel


func _label(name: String, size: int, color := INK) -> Label:
	var l := Label.new()
	l.name = name
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## One plaque a player: the name in the player's colour, parts used over cap and castles held. Players 1 and 2
## take the top corners, 3 and 4 the plaques under them.
func _make_player_hud(i: int, is_ai: bool, color: Color) -> Dictionary:
	var panel := _plaque("Hud%d" % (i + 1))
	var right := i % 2 == 1
	var y := HUD_GAP + (i / 2) * 84.0
	panel.anchor_left = 1.0 if right else 0.0
	panel.anchor_right = panel.anchor_left
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	panel.offset_left = -HUD_GAP if right else HUD_GAP
	panel.offset_right = panel.offset_left
	panel.offset_top = y
	panel.offset_bottom = y
	panel.custom_minimum_size.x = 136
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	panel.add_child(box)
	box.add_child(_label("Name", 17, color))
	box.get_child(0).text = "%s %d" % ["AI" if is_ai else "Player", i + 1]
	var parts := _label("Parts", 14)
	var castles := _label("Castles", 14)
	for l in [parts, castles]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(l)
	return {"parts": parts, "castles": castles}


func _on_phase_changed(phase: int) -> void:
	_phase.text = PHASE_NAMES[phase] + ("   Enter: next" if practice else "")
	_phase.add_theme_color_override("font_color", PHASE_COLORS[phase])
	_bannerPhase.text = PHASE_NAMES[phase]
	_bannerPhase.add_theme_color_override("font_color", PHASE_COLORS[phase])
	_help.text = HELP[phase]


func _process(_delta: float) -> void:
	if quit_after > 0 and U.time >= quit_after:
		print("quit-after reached at t=%.1f" % U.time)
		get_tree().quit()
	_update_hud()


## The banner while it counts, the countdown, red in its last seconds, and every player's parts and castles.
func _update_hud() -> void:
	_banner.visible = game != null and game.started and game.readyLeft > 0.0
	if game == null or not game.started:
		return
	_bannerCount.text = "%d" % ceili(game.readyLeft)
	var left := int(ceilf(game.timeLeftInRound))
	_count.text = "%d" % left
	_count.add_theme_color_override("font_color", ACCENT if left <= game.COUNTDOWN else INK)
	for i in game.players.size():
		var p = game.players[i]
		var used: int = p.parts_used()
		_huds[i]["parts"].text = "parts %d / %d" % [used, p.partsCap]
		# the cap drops with a lost castle; the guns already placed can then exceed it
		_huds[i]["parts"].add_theme_color_override("font_color", ACCENT if used > p.partsCap else INK)
		_huds[i]["castles"].text = "castles %d" % p.castle_count()


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
	var panel := _plaque("Toast")
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var l := _label("Text", 18)
	l.text = text
	panel.add_child(l)
	get_tree().create_timer(4.0 if Catalog.errors.is_empty() else 10.0).timeout.connect(panel.queue_free)
