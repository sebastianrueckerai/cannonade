extends Node
## Menu -> game -> Esc -> pause menu -> menu flow, the Tutorial & Controls panel, remapping.
##   godot --headless --fixed-fps 30 res://tests/menu_test.tscn

var ok := true


func _ready() -> void:
	# this node is the running scene; hand that role to a dummy so the scene
	# changes below do not free the test
	await get_tree().process_frame
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	await _frames(3)
	var menu := get_tree().current_scene
	var buttons := menu.find_children("*", "Button", true, false)
	_check(buttons.size() == 7, "menu has 7 buttons (3 modes, Tutorial & Controls, Volume, Sandbox, Quit)")
	_check(buttons.any(func(b): return b.text.contains("Player vs. AI"))
			and buttons.any(func(b): return b.text.contains("Practice"))
			and not buttons.any(func(b): return b.text.contains("Single player"))
			and not buttons.any(func(b): return b.text.contains("4 AIs")),
			"the menu keeps versus, watch and practice; the parked modes are gone")
	var tut: Button = null
	for b in buttons:
		if b.text == "Tutorial & Controls":
			tut = b
	# the browser build shows every entry but Sandbox; Quit has no window to close there (I88)
	var web_box := VBoxContainer.new()
	menu.add_child(web_box)
	menu._build_buttons(web_box, true)
	var web_buttons: Array = web_box.find_children("*", "Button", true, false)
	_check(web_buttons.size() == 5
			and web_buttons.any(func(b): return b.text.contains("Player vs. AI"))
			and web_buttons.any(func(b): return b.text.contains("Watch"))
			and web_buttons.any(func(b): return b.text.contains("Practice"))
			and not web_buttons.any(func(b): return b.text.contains("Sandbox"))
			and not web_buttons.any(func(b): return b.text.contains("Quit")),
		"the web build shows all three modes and both panels, Sandbox and Quit stay desktop (%s)"
			% [web_buttons.map(func(b): return b.text)])
	web_box.queue_free()
	_check(tut != null, "the menu has a Tutorial & Controls button")
	# the menu and the help overlay both fit the 1280x720 canvas, the smallest any window shows
	var panels: Array = menu.find_children("*", "PanelContainer", true, false)
	var menu_panel: PanelContainer = panels[0]
	_check(menu_panel.get_combined_minimum_size().y < 700.0,
			"menu panel min height %s fits a 720 window without scaling"
			% menu_panel.get_combined_minimum_size().y)
	get_window().size = Vector2i(1280, 720)
	tut.pressed.emit()
	await _frames(3)
	var help_panel: PanelContainer = null
	for p in menu.find_children("*", "PanelContainer", true, false):
		if p != menu_panel:
			help_panel = p
	var win := Rect2(Vector2.ZERO, menu.size)
	var help_rect: Rect2 = help_panel.get_global_rect() if help_panel != null else Rect2()
	_check(help_panel != null and win.encloses(help_rect),
			"the Tutorial & Controls panel %s fits inside the %s window" % [help_rect, menu.size])
	_check(help_panel != null and help_rect.get_center().distance_to(win.get_center()) < 1.0,
			"the Tutorial & Controls panel is centred")
	var close0: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if b.text == "Close":
			close0 = b
	_check(close0 != null and win.encloses(close0.get_global_rect()),
			"the Close button %s is inside the window" % (close0.get_global_rect() if close0 != null else Rect2()))
	# Close holds the focus, so its text must keep the readable ink: the default focus colour is near-white
	_check(close0 != null and close0.has_focus()
			and close0.get_theme_color("font_focus_color") == close0.get_theme_color("font_color"),
			"the focused Close button keeps its font colour (%s)"
			% (close0.get_theme_color("font_focus_color") if close0 != null else Color()))
	# Close runs the full width below both columns
	var style: StyleBox = help_panel.get_theme_stylebox("panel")
	var inner := help_rect.grow_individual(-style.get_content_margin(SIDE_LEFT),
			-style.get_content_margin(SIDE_TOP), -style.get_content_margin(SIDE_RIGHT),
			-style.get_content_margin(SIDE_BOTTOM))
	var close_rect: Rect2 = close0.get_global_rect() if close0 != null else Rect2()
	_check(close0 != null and absf(close_rect.position.x - inner.position.x) < 1.0
			and absf(close_rect.end.x - inner.end.x) < 1.0,
			"the Close button %s spans the panel's content width %s" % [close_rect, inner])
	var above := true
	for c in help_panel.find_children("*", "Control", true, false):
		if c != close0 and (c is Label or c is Button) and c.get_global_rect().end.y > close_rect.position.y:
			above = false
	_check(above, "every label and button of Tutorial & Controls ends above the Close button")
	# the tutorial reads smaller than the controls and keeps every paragraph to three lines
	var tutorial: Array = []
	var act_row: Label = null
	for l in help_panel.find_children("*", "Label", true, false):
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.text != "":
			tutorial.append(l)
		elif l.text == "place the piece or the cannon, fuse, fire":
			act_row = l
	_check(tutorial.size() == 4 and act_row != null
			and tutorial.all(func(l): return l.get_theme_font_size("font_size") < act_row.get_theme_font_size("font_size")),
			"the %d tutorial paragraphs use a smaller font (%s) than the controls (%s)"
			% [tutorial.size(), tutorial[0].get_theme_font_size("font_size") if not tutorial.is_empty() else 0,
			act_row.get_theme_font_size("font_size") if act_row != null else 0])
	_check(not tutorial.is_empty() and tutorial.all(func(l): return l.get_line_count() <= 3),
			"no tutorial paragraph runs past three lines (%s)"
			% str(tutorial.map(func(l): return l.get_line_count())))
	# a click on the parchment, off every button, keeps the help open
	_click(help_rect.position + Vector2(8, 8))
	await _frames(2)
	_check(_labels_with("place the piece or the cannon, fuse, fire", menu) == 1,
			"a click on the panel itself keeps Tutorial & Controls open")
	_click(Vector2(8, 8))
	await _frames(2)
	_check(_labels_with("place the piece or the cannon, fuse, fire", menu) == 0,
			"a click outside the panel closes Tutorial & Controls")
	await _frames(2)
	# a corrupt input_remap.cfg must not stop the menu building or later rows loading
	var t_key0 := InputEventKey.new()
	t_key0.device = -1
	t_key0.physical_keycode = KEY_T
	var cfg := ConfigFile.new()
	cfg.set_value("map", "act", "nonsense")
	cfg.set_value("map", "rotate_cw", var_to_str([t_key0]))
	cfg.save("user://input_remap.cfg")
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	await _frames(3)
	menu = get_tree().current_scene
	_check(menu.find_children("*", "Button", true, false).size() == 7,
			"menu builds with a corrupt input_remap.cfg")
	tut = null
	for b in menu.find_children("*", "Button", true, false):
		if b.text == "Tutorial & Controls":
			tut = b
	tut.pressed.emit()
	await _frames(2)
	var cw0: Button = menu.find_children("rotate_cw", "Button", true, false)[0]
	_check(cw0.text.contains("T"), "a corrupt row does not stop later rows loading")
	_check(not cw0.text.contains("X"), "the corrupt row's action keeps no stale binding")
	_esc()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://input_remap.cfg"))
	InputMap.action_erase_events("rotate_cw")
	var x0 := InputEventKey.new()
	x0.device = -1
	x0.physical_keycode = KEY_X
	InputMap.action_add_event("rotate_cw", x0)
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	await _frames(3)
	menu = get_tree().current_scene
	tut = null
	for b in menu.find_children("*", "Button", true, false):
		if b.text == "Tutorial & Controls":
			tut = b
	if not ok:
		print("MENU TEST FAILED")
		get_tree().quit(1)
		return
	tut.pressed.emit()
	await _frames(2)
	_check(_labels_with("place the piece or the cannon, fuse, fire", menu) == 1, "Tutorial & Controls lists the controls")
	var cw_btn: Button = menu.find_children("rotate_cw", "Button", true, false)[0]
	_check(cw_btn.text.contains("X"), "a remappable row shows its current binding")
	var ccw_btn: Button = menu.find_children("rotate_ccw", "Button", true, false)[0]
	_check(ccw_btn.text.contains("Y / Z"), "a row with two keys shows both")
	cw_btn.pressed.emit()
	await _frames(2)
	_check(cw_btn.text.contains("press"), "clicking a binding waits for the next input")
	_key(KEY_T)
	await _frames(2)
	_check(cw_btn.text.contains("T"), "the next key becomes the binding")
	var t_key := InputEventKey.new()
	t_key.device = -1
	t_key.physical_keycode = KEY_T
	_check(InputMap.action_has_event("rotate_cw", t_key), "the new binding is in the input map")
	_esc()
	await _frames(2)
	_check(_labels_with("place the piece or the cannon, fuse, fire", menu) == 0, "Esc closes Tutorial & Controls")
	# a fresh menu load applies the saved bindings
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	await _frames(3)
	menu = get_tree().current_scene
	tut = null
	for b in menu.find_children("*", "Button", true, false):
		if b.text == "Tutorial & Controls":
			tut = b
	tut.pressed.emit()
	await _frames(2)
	cw_btn = menu.find_children("rotate_cw", "Button", true, false)[0]
	_check(cw_btn.text.contains("T"), "a remapped binding survives a menu reload")
	var act_btn: Button = menu.find_children("act", "Button", true, false)[0]
	_check(act_btn.text.contains("Left"), "an untouched action keeps its default binding")
	act_btn.pressed.emit()
	await _frames(2)
	_key(KEY_T)
	await _frames(2)
	_check(act_btn.text.contains("Left"), "an input already on another action is rejected")
	_check(InputMap.action_has_event("rotate_cw", t_key), "the rejected input leaves the other binding alone")
	var close: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if b.text == "Close":
			close = b
	_check(close != null, "Tutorial & Controls has a Close button")
	close.pressed.emit()
	await _frames(2)
	_check(_labels_with("place the piece or the cannon, fuse, fire", menu) == 0, "the Close button closes Tutorial & Controls")
	# hermetic cleanup: drop the saved map and the in-process remap
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://input_remap.cfg"))
	InputMap.action_erase_event("rotate_cw", t_key)
	var x_key := InputEventKey.new()
	x_key.device = -1
	x_key.physical_keycode = KEY_X
	InputMap.action_add_event("rotate_cw", x_key)
	# the Volume panel: three sliders, live on the buses, saved and reloaded through the file
	var volume: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if b.text == "Volume":
			volume = b
	_check(volume != null, "the menu has a Volume button")
	volume.pressed.emit()
	await _frames(2)
	var sliders := {}
	for kind in ["master", "sound", "music"]:
		sliders[kind] = menu.find_children(kind, "HSlider", true, false)[0]
		_check(sliders[kind].value == 100.0, "the %s slider starts at full (%s, Sound %s)"
				% [kind, sliders[kind].value, Sound.volume(kind)])
	await _drag_slider(sliders["master"], 0.25)
	_check(absf(sliders["master"].value - 25.0) < 8.0,
			"a drag to a quarter of the track sets the master slider near 25 (%s)" % sliders["master"].value)
	_check(absf(_bus_db("Master") - linear_to_db(sliders["master"].value / 100.0)) < 0.01,
			"the master drag moves the Master bus to the slider's level (%.1f dB)" % _bus_db("Master"))
	_check(_bus_db("SFX") == 0.0 and _bus_db("UI") == 0.0 and _bus_db("Music") == 0.0,
			"the master drag leaves the other buses at full")
	await _drag_slider(sliders["sound"], 0.1)
	_check(absf(_bus_db("SFX") - linear_to_db(sliders["sound"].value / 100.0)) < 0.01
			and absf(_bus_db("UI") - linear_to_db(sliders["sound"].value / 100.0)) < 0.01,
			"the sound slider moves the SFX and UI buses together to its level (%.1f dB)" % _bus_db("SFX"))
	await _drag_slider(sliders["music"], 0.6)
	_check(absf(_bus_db("Music") - linear_to_db(sliders["music"].value / 100.0)) < 0.01,
			"the music slider moves the Music bus alone")
	var pct: Label = menu.find_children("master_value", "Label", true, false)[0]
	_check(pct.text == "%d%%" % sliders["master"].value,
			"the row's percent follows its slider (%s)" % pct.text)
	var saved := {}
	var vol_cfg := ConfigFile.new()
	_check(vol_cfg.load("user://volume.cfg") == OK, "the sliders save to user://volume.cfg")
	for kind in ["master", "sound", "music"]:
		saved[kind] = sliders[kind].value / 100.0
		_check(absf(float(vol_cfg.get_value("volume", kind, 1.0)) - saved[kind]) < 0.002,
				"the file holds the %s volume %.2f" % [kind, saved[kind]])
	_esc()
	await _frames(2)
	# a fresh menu load reads the file back and applies it
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	await _frames(3)
	menu = get_tree().current_scene
	volume = null
	for b in menu.find_children("*", "Button", true, false):
		if b.text == "Volume":
			volume = b
	volume.pressed.emit()
	await _frames(2)
	for kind in ["master", "sound", "music"]:
		var reloaded: HSlider = menu.find_children(kind, "HSlider", true, false)[0]
		_check(absf(reloaded.value / 100.0 - saved[kind]) < 0.005,
				"the saved %s volume survives a menu reload (%.2f)" % [kind, reloaded.value / 100.0])
	_check(absf(_bus_db("Master") - linear_to_db(saved["master"])) < 0.01
			and absf(_bus_db("Music") - linear_to_db(saved["music"])) < 0.01,
			"a fresh menu applies the saved volumes to the buses")
	for kind in ["master", "sound", "music"]:
		Sound.set_volume(kind, 1.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://volume.cfg"))
	_esc()
	await _frames(2)
	# the sound icon: a subtle speaker over the painting's bottom-right corner, one click mutes everything
	var mutes: Array = menu.find_children("Mute", "BaseButton", true, false)
	_check(mutes.size() == 1, "the menu carries one sound icon (%d)" % mutes.size())
	var mute: BaseButton = mutes[0] if mutes.size() == 1 else null
	if mute != null:
		var rect: Rect2 = mute.get_global_rect()
		var gap: Vector2 = menu.size - rect.end
		_check(gap.x >= 16.0 and gap.x <= 36.0 and gap.y >= 16.0 and gap.y <= 36.0,
				"the sound icon sits in the bottom-right corner (%s off the edge)" % gap)
		_check(rect.size.x >= 32.0 and rect.size.x <= 64.0,
				"the sound icon stays subtle (%s)" % rect.size)
		var icon: TextureButton = mute if mute is TextureButton else null
		_check(icon != null and icon.modulate.a < 0.75,
				"the icon idles at low opacity (%.2f)" % (icon.modulate.a if icon != null else 1.0))
		_click(rect.get_center())
		await _frames(2)
		_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
				"one click on the icon mutes the Master bus")
		_check(icon != null and icon.texture_normal != null
				and icon.texture_normal.resource_path.ends_with("sound_off.svg"),
				"the icon shows the muted glyph")
		var mute_cfg := ConfigFile.new()
		mute_cfg.load("user://volume.cfg")
		_check(mute_cfg.get_value("volume", "muted", false) == true, "the mute saves to volume.cfg")
		# a slider move rewrites the file; the mute must survive it
		for b in menu.find_children("*", "Button", true, false):
			if b.text == "Volume":
				b.pressed.emit()
		await _frames(2)
		await _drag_slider(menu.find_children("master", "HSlider", true, false)[0], 0.25)
		mute_cfg.load("user://volume.cfg")
		_check(mute_cfg.get_value("volume", "muted", false) == true
				and mute_cfg.get_value("volume", "master", 1.0) < 0.5,
				"a slider move saves its own volume and keeps the mute in the file")
		_esc()
		await _frames(2)
	# a fresh menu opens with the sound muted, and a second click restores it
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	await _frames(3)
	menu = get_tree().current_scene
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
			"a fresh menu opens with the sound muted")
	mutes = menu.find_children("Mute", "BaseButton", true, false)
	if mutes.size() == 1:
		_click(mutes[0].get_global_rect().get_center())
		await _frames(2)
		_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
				"a second click restores the sound")
	Sound.set_volume("master", 1.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://volume.cfg"))
	for b in menu.find_children("*", "Button", true, false):
		if b.text.contains("AI vs. AI"):
			b.pressed.emit()
	# the loading screen stays up while the game is built underneath; an Esc meanwhile does not reach the game
	var main: Node = null
	var bar_values := {}
	var art := ""
	for i in 900:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.name == "Main":
			main = scene
		var loading := get_tree().root.get_node_or_null("Loading")
		if main != null and loading != null:
			bar_values[loading.find_children("*", "ProgressBar", true, false)[0].value] = true
			for tr in loading.find_children("*", "TextureRect", true, false):
				art = tr.texture.resource_path
			if bar_values.size() == 2:
				_esc()
		if is_instance_valid(main) and main.game != null and main.game.started:
			break
	_check(art.begins_with("res://assets/art/ui/loading"), "the loading screen shows concept art, not the splash (%s)" % art)
	_check(bar_values.size() >= 3, "the loading bar moves while the game is built (%d steps)" % bar_values.size())
	_check(is_instance_valid(main) and main.game.started and get_tree().current_scene == main,
			"game started from the menu, Esc while loading changed nothing")
	_check(get_tree().root.get_node_or_null("Loading") == null, "the loading screen is gone once the game runs")
	_check(main.mode == "ai2", "selected mode is used")
	await _frames(30)
	_esc()
	await _frames(5)
	var pause: Node = main.get_node_or_null("UI/Pause")
	_check(pause != null and get_tree().paused, "Esc in the game opens the pause menu and pauses play")
	var leave: Button = null
	if pause != null:
		for b in pause.find_children("*", "Button", true, false):
			if b.text == "Menu":
				leave = b
	_check(leave != null, "the pause menu has a Menu button")
	if leave != null:
		leave.pressed.emit()
	await _frames(5)
	_check(get_tree().current_scene.name == "Menu" and not get_tree().paused,
			"the pause menu's Menu button returns to the menu unpaused")
	print("MENU TEST PASSED" if ok else "MENU TEST FAILED")
	get_tree().quit(0 if ok else 1)


func _esc() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)


func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = pos
		ev.global_position = pos
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _key(k: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)


## One bus's volume in dB, the number the slider writes.
func _bus_db(bus: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))


## Drags a slider with the mouse from three quarters of its track to `ratio` of it, then waits a
## frame for the queued input to reach the control.
func _drag_slider(s: HSlider, ratio: float) -> void:
	var r := s.get_global_rect()
	var y := r.get_center().y
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(r.position.x + r.size.x * 0.75, y)
	press.global_position = press.position
	Input.parse_input_event(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(r.position.x + r.size.x * ratio, y)
	motion.global_position = motion.position
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	var release := press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame
	await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _labels_with(part: String, root: Node) -> int:
	var n := 0
	for l in root.find_children("*", "Label", true, false):
		if l.text.contains(part):
			n += 1
	return n


func _check(c: bool, msg: String) -> void:
	print(("ok: " if c else "FAIL: ") + msg)
	ok = ok and c
