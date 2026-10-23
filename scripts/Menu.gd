extends Control
## Main menu: pick one of the original game modes. Background and title come from the art layer when present.

const Main = preload("res://scripts/Main.gd")
const Loading = preload("res://scripts/Loading.gd")

const MODES := [
	["versus", "Player vs. AI"],
	["ai2", "Watch: AI vs. AI"],
	["practice", "Practice (a fort that never fires back)"],
]
## The three actions the panel remaps; everything else (wheel, middle drag,
## Enter, Esc) is hardcoded where it is used and listed as a fixed row.
const REMAP := [
	["act", "place the piece or the cannon, fuse, fire"],
	["rotate_cw", "rotate the wall piece clockwise"],
	["rotate_ccw", "rotate the wall piece counter-clockwise"],
]
const FIXED := [
	["zoom in / out towards the cursor", "Mouse wheel"],
	["pan the view while zoomed in", "Middle mouse drag"],
	["discard the piece / building in hand", "Click outside the map"],
]
const INTRO := "You and the AI each start with a walled castle. A round is three phases: build walls, place cannons, battle.\n\nTurn and drop wall pieces. Pieces that share a side join; corners do not. Build within two tiles of your walls or a castle you hold.\n\nRing in neutral castles to claim them and raise your parts cap. Place cannons; fuse four in a 2x2 square into a heavy gun. Buildings outside your walls burn when the battle starts.\n\nRuin the enemy's last castle before yours falls."
const REMAP_PATH := "user://input_remap.cfg"

## The open overlay (its dim root), null when closed.
var _overlay: Control = null
var _note: Label = null
## The sound icon in the painting's bottom-right corner, a TextureButton with the art layer.
var _mute: BaseButton = null
var _capturing := ""
var _capture_btn: Button = null


func _ready() -> void:
	_load_remap()
	Sound.load_volumes()
	Sound.music("menu")
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
	_build_buttons(box, OS.has_feature("web"))
	Sound.buttons(box)
	_add_mute()
	var errors: Array[String] = []
	errors.append_array(Catalog.errors)
	errors.append_array(Art.validate())
	if not errors.is_empty():
		var problems := Label.new()
		problems.text = "Problems in data/buildings or assets/art:\n" + "\n".join(errors)
		problems.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
		problems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(problems)


## The menu's buttons: every entry everywhere but Sandbox and Quit, which stay desktop
## (the browser shows the whole game, and the tab is its own quit button).
func _build_buttons(box: VBoxContainer, web: bool) -> void:
	for entry in MODES:
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
	var volume := Button.new()
	volume.text = "Volume"
	volume.custom_minimum_size = Vector2(0, 44)
	volume.pressed.connect(_show_volume)
	box.add_child(volume)
	if web:
		return
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


func _start(mode: String) -> void:
	Main.requested_mode = mode
	Loading.go("res://scenes/game.tscn")


## The sound icon over the painting's bottom-right corner: one click mutes everything, one more restores it.
func _add_mute() -> void:
	var on := Art.texture("sound_on.svg")
	var off := Art.texture("sound_off.svg")
	_mute = TextureButton.new() if on != null and off != null else Button.new()
	_mute.name = "Mute"
	_mute.tooltip_text = "Sound"
	_mute.focus_mode = Control.FOCUS_NONE
	_mute.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	_mute.offset_left = -68
	_mute.offset_top = -68
	_mute.offset_right = -24
	_mute.offset_bottom = -24
	_mute.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_mute.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_mute.modulate.a = 0.55
	_mute.mouse_entered.connect(func(): _mute.modulate.a = 1.0)
	_mute.mouse_exited.connect(func(): _mute.modulate.a = 0.55)
	_mute.pressed.connect(_toggle_mute)
	if _mute is TextureButton:
		var icon := _mute as TextureButton
		icon.ignore_texture_size = true
		icon.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_mute)
	_refresh_mute()


func _toggle_mute() -> void:
	Sound.set_muted(not Sound.muted())
	_refresh_mute()


## The icon shows the state: the muted glyph, or a text button when the art layer is absent.
func _refresh_mute() -> void:
	if _mute is TextureButton:
		(_mute as TextureButton).texture_normal = Art.texture(
				"sound_off.svg" if Sound.muted() else "sound_on.svg")
	else:
		_mute.text = "Muted" if Sound.muted() else "Sound"


func _unhandled_input(event: InputEvent) -> void:
	if _overlay != null and event.is_action_pressed("ui_cancel"):
		_close_overlay()
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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "Tutorial & Controls"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	# the tutorial left, the controls right: the 1280x720 canvas is wide, not tall
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	box.add_child(columns)
	var intro := VBoxContainer.new()
	intro.custom_minimum_size = Vector2(560, 0)
	intro.add_theme_constant_override("separation", 8)
	columns.add_child(intro)
	for paragraph in INTRO.split("\n\n"):
		var text := Label.new()
		text.text = paragraph
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_font_size_override("font_size", 17)  # smaller than the controls, so the columns tell apart
		intro.add_child(text)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	columns.add_child(controls)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	controls.add_child(grid)
	for row in REMAP:
		var what := Label.new()
		what.text = row[1]
		grid.add_child(what)
		var bind := Button.new()
		bind.name = row[0]
		bind.text = _binding_text(InputMap.action_get_events(row[0]))
		bind.custom_minimum_size = Vector2(200, 0)
		bind.pressed.connect(_capture.bind(row[0], bind))
		grid.add_child(bind)
	var fixed: Array = FIXED.duplicate()
	fixed.append(["next phase (Practice)", "Enter"])
	fixed.append(["pause the game (in play)", "Esc"])
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
	controls.add_child(_note)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(_close_overlay)
	box.add_child(close)
	_open_panel(box)
	close.grab_focus()


## The Volume panel: the shared slider rows (Sound.volume_rows), live on the buses and saved on every change.
func _show_volume() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "Volume"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	box.add_child(Sound.volume_rows())
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(_close_overlay)
	box.add_child(close)
	_open_panel(box)
	close.grab_focus()


## One centred panel over a dim that fills the screen; a click on the dim closes it.
func _open_panel(box: VBoxContainer) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_overlay())
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.grow_horizontal = GROW_DIRECTION_BOTH
	panel.grow_vertical = GROW_DIRECTION_BOTH
	dim.add_child(panel)
	panel.add_child(box)
	Sound.buttons(dim)
	_overlay = dim


func _close_overlay() -> void:
	if _overlay == null:
		return
	_capturing = ""
	_capture_btn = null
	_overlay.queue_free()
	_overlay = null
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
		var events: Array = []
		var raw = str_to_var(str(cfg.get_value("map", row[0])))
		if raw is Array:
			for ev in raw:
				if ev is InputEvent:
					events.append(ev)
		if events.is_empty():
			continue
		for old in InputMap.action_get_events(row[0]):
			InputMap.action_erase_event(row[0], old)
		for ev in events:
			InputMap.action_add_event(row[0], ev)
