extends Control
## Main menu: pick one of the original game modes. Background and title come from the art layer when present.

const Main = preload("res://scripts/Main.gd")
const Loading = preload("res://scripts/Loading.gd")

const MODES := [
	["single", "Single player (vs. ships)"],
	["versus", "Player vs. AI"],
	["ai2", "Watch: AI vs. AI"],
	["ai4", "Watch: 4 AIs"],
	["practice", "Practice (a fort that never fires back)"],
]
const CONTROLS := [
	["Left mouse", "place the next wall / stack it on one of your walls"],
	["Right mouse", "place the next building / combine it with the one below"],
	["X / Y or Z", "rotate the wall"],
	["Mouse wheel", "zoom in / out towards the cursor"],
	["Middle mouse drag", "pan the view while zoomed in"],
	["Space", "fire the cannons"],
	["Click outside the map", "discard the wall / building in hand"],
]

## The help overlay while open, null when closed.
var _help: Control = null


func _ready() -> void:
	theme = Art.theme()
	var bg := Art.texture("menu_background.png")
	if bg != null:
		var tr := TextureRect.new()
		tr.texture = bg
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		add_child(tr)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.grow_horizontal = GROW_DIRECTION_BOTH
	panel.grow_vertical = GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var logo := Art.texture("logo.png")
	if logo != null:
		var tr := TextureRect.new()
		tr.texture = logo
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(360, 120)
		box.add_child(tr)
	else:
		var title := Label.new()
		title.text = "CANNONADE"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 44)
		box.add_child(title)
	# the shipped web build carries the two showcase modes only
	var web := OS.has_feature("web")
	var modes: Array = [MODES[1], MODES[2]] if web else MODES
	for entry in modes:
		var b := Button.new()
		b.text = entry[1]
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(_start.bind(entry[0]))
		box.add_child(b)
	var help := Button.new()
	help.text = "How to play"
	help.custom_minimum_size = Vector2(0, 44)
	help.pressed.connect(_show_help)
	box.add_child(help)
	if not web:
		var sandbox := Button.new()
		sandbox.text = "Sandbox (build & test battles)"
		sandbox.custom_minimum_size = Vector2(0, 44)
		sandbox.pressed.connect(func(): Loading.go("res://scenes/sandbox.tscn"))
		box.add_child(sandbox)
		var quit := Button.new()
		quit.text = "Quit"
		quit.custom_minimum_size = Vector2(0, 36)
		quit.pressed.connect(get_tree().quit)
		box.add_child(quit)
	var errors: Array[String] = []
	errors.append_array(Catalog.errors)
	errors.append_array(Art.validate())
	if not errors.is_empty():
		var problems := Label.new()
		problems.text = "Problems in data/buildings or assets/art:\n" + "\n".join(errors)
		problems.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
		problems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(problems)


func _start(mode: String) -> void:
	Main.requested_mode = mode
	Loading.go("res://scenes/game.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if _help != null and event.is_action_pressed("ui_cancel"):
		_close_help()
		get_viewport().set_input_as_handled()


func _show_help() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_help())
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.grow_horizontal = GROW_DIRECTION_BOTH
	panel.grow_vertical = GROW_DIRECTION_BOTH
	dim.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "How to play"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	var intro := Label.new()
	intro.text = "You and an AI opponent build forts on one island. Rounds switch between a green build phase and a red battle phase.\n\nWall your guns in: only cannons inside a fully walled-in area can fire, and supply depots inside keep them fed. Upgrade blocks placed in 2x2 squares merge into heavier guns, flak, shield generators or supply depots.\n\nDestroy the enemy base before yours falls."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	var rows: Array = CONTROLS.duplicate()
	if not OS.has_feature("web"):
		rows.append(["Enter", "switch between build and battle (Practice)"])
	rows.append(["Esc", "back to the menu"])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for row in rows:
		var key := Label.new()
		key.text = row[0]
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(key)
		var what := Label.new()
		what.text = row[1]
		grid.add_child(what)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(_close_help)
	box.add_child(close)
	close.grab_focus()
	_help = dim


func _close_help() -> void:
	if _help == null:
		return
	_help.queue_free()
	_help = null
