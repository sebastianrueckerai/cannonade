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
## The five actions the panel remaps; everything else (wheel, middle drag,
## Enter, Esc) is hardcoded where it is used and listed as a fixed row.
const REMAP := [
	["build_wall", "place the next wall / stack it on one of your walls"],
	["build_building", "place the next building / combine it with the one below"],
	["rotate_cw", "rotate the wall clockwise"],
	["rotate_ccw", "rotate the wall counter-clockwise"],
	["fire", "fire the cannons"],
]
const FIXED := [
	["zoom in / out towards the cursor", "Mouse wheel"],
	["pan the view while zoomed in", "Middle mouse drag"],
	["discard the wall / building in hand", "Click outside the map"],
]
const REMAP_PATH := "user://input_remap.cfg"

## The help overlay while open, null when closed.
var _help: Control = null
var _note: Label = null
var _capturing := ""
var _capture_btn: Button = null


func _ready() -> void:
	_load_remap()
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
	help.text = "Tutorial & Controls"
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


## While a capture runs, every key or mouse button press rebuilds that action's
## binding (in _input, so no button behind the overlay can swallow it first).
func _input(event: InputEvent) -> void:
	if _capturing == "":
		return
	if event.is_action_pressed("ui_cancel"):
		_end_capture()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_apply_remap(_normalized_key(event))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
				MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return
		_apply_remap(_normalized_mouse(event))
	else:
		return
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
	title.text = "Tutorial & Controls"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	var intro := Label.new()
	intro.text = "You and an AI opponent build forts on one island. Rounds switch between a green build phase and a red battle phase.\n\nWall your guns in: only cannons inside a fully walled-in area can fire, and supply depots inside keep them fed. Upgrade blocks placed in 2x2 squares merge into heavier guns, flak, shield generators or supply depots.\n\nDestroy the enemy base before yours falls."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for row in REMAP:
		var what := Label.new()
		what.text = row[1]
		grid.add_child(what)
		var bind := Button.new()
		bind.name = row[0]
		bind.text = _binding_text(InputMap.action_get_events(row[0]))
		bind.custom_minimum_size = Vector2(220, 0)
		bind.pressed.connect(_capture.bind(row[0], bind))
		grid.add_child(bind)
	var fixed: Array = FIXED.duplicate()
	if not OS.has_feature("web"):
		fixed.append(["switch between build and battle (Practice)", "Enter"])
	fixed.append(["back to the menu", "Esc"])
	for row in fixed:
		var what := Label.new()
		what.text = row[0]
		grid.add_child(what)
		var key := Label.new()
		key.text = row[1]
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(key)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	_note.visible = false
	box.add_child(_note)
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
	_capturing = ""
	_capture_btn = null
	_help.queue_free()
	_help = null
	_note = null


func _capture(action: String, btn: Button) -> void:
	_capturing = action
	_capture_btn = btn
	btn.text = "press a key or mouse button"
	_note.visible = false


func _end_capture() -> void:
	if _capture_btn != null:
		_capture_btn.text = _binding_text(InputMap.action_get_events(_capturing))
	_capturing = ""
	_capture_btn = null


func _apply_remap(ev: InputEvent) -> void:
	var action := _capturing
	var btn := _capture_btn
	_end_capture()
	for row in REMAP:
		if row[0] != action and InputMap.action_has_event(row[0], ev):
			_note.text = "\"%s\" already maps %s." % [_event_text(ev), row[1]]
			_note.visible = true
			return
	for old in InputMap.action_get_events(action):
		InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, ev)
	btn.text = _event_text(ev)
	_save_remap()


## The captured event rebuilt in the project's own event shape: all devices,
## physical keycode only, so it compares equal to the defaults.
func _normalized_key(e: InputEventKey) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.device = -1
	ev.physical_keycode = e.physical_keycode
	ev.alt_pressed = e.alt_pressed
	ev.ctrl_pressed = e.ctrl_pressed
	ev.shift_pressed = e.shift_pressed
	return ev


func _normalized_mouse(e: InputEventMouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.device = -1
	ev.button_index = e.button_index
	ev.alt_pressed = e.alt_pressed
	ev.ctrl_pressed = e.ctrl_pressed
	ev.shift_pressed = e.shift_pressed
	return ev


func _event_text(e: InputEvent) -> String:
	if e is InputEventKey:
		var s := ""
		if e.alt_pressed:
			s += "Alt+"
		if e.ctrl_pressed:
			s += "Ctrl+"
		if e.shift_pressed:
			s += "Shift+"
		var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		return s + OS.get_keycode_string(code)
	if e is InputEventMouseButton:
		match e.button_index:
			MOUSE_BUTTON_LEFT: return "Left mouse"
			MOUSE_BUTTON_RIGHT: return "Right mouse"
			MOUSE_BUTTON_MIDDLE: return "Middle mouse"
			_: return "Mouse %d" % e.button_index
	return e.as_text()


func _binding_text(events: Array) -> String:
	var parts: Array[String] = []
	for e in events:
		parts.append(_event_text(e))
	return " / ".join(parts)


func _save_remap() -> void:
	var cfg := ConfigFile.new()
	for row in REMAP:
		cfg.set_value("map", row[0], var_to_str(InputMap.action_get_events(row[0])))
	cfg.save(REMAP_PATH)


func _load_remap() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(REMAP_PATH) != OK:
		return
	for row in REMAP:
		if not cfg.has_section_key("map", row[0]):
			continue
		var events: Array = str_to_var(cfg.get_value("map", row[0]))
		if events.is_empty():
			continue
		for old in InputMap.action_get_events(row[0]):
			InputMap.action_erase_event(row[0], old)
		for ev in events:
			InputMap.action_add_event(row[0], ev)
