extends Node
## Menu -> game -> Esc -> menu flow, the Tutorial & Controls panel, remapping.
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
	_check(buttons.size() == 8, "menu has 8 buttons (5 modes, Tutorial & Controls, Sandbox, Quit)")
	_check(buttons.any(func(b): return b.text.contains("Single player"))
			and buttons.any(func(b): return b.text.contains("4 AIs"))
			and buttons.any(func(b): return b.text.contains("Practice")),
			"desktop keeps the modes the web build hides")
	var tut: Button = null
	for b in buttons:
		if b.text == "Tutorial & Controls":
			tut = b
	_check(tut != null, "the menu has a Tutorial & Controls button")
	if not ok:
		print("MENU TEST FAILED")
		get_tree().quit(1)
		return
	tut.pressed.emit()
	await _frames(2)
	_check(_labels_with("fire the cannons", menu) == 1, "Tutorial & Controls lists the controls")
	var fire_btn: Button = menu.find_children("fire", "Button", true, false)[0]
	_check(fire_btn.text.contains("Space"), "a remappable row shows its current binding")
	var ccw_btn: Button = menu.find_children("rotate_ccw", "Button", true, false)[0]
	_check(ccw_btn.text.contains("Y / Z"), "a row with two keys shows both")
	fire_btn.pressed.emit()
	await _frames(2)
	_check(fire_btn.text.contains("press"), "clicking a binding waits for the next input")
	_key(KEY_T)
	await _frames(2)
	_check(fire_btn.text.contains("T"), "the next key becomes the binding")
	var t_key := InputEventKey.new()
	t_key.device = -1
	t_key.physical_keycode = KEY_T
	_check(InputMap.action_has_event("fire", t_key), "the new binding is in the input map")
	_esc()
	await _frames(2)
	_check(_labels_with("fire the cannons", menu) == 0, "Esc closes Tutorial & Controls")
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
	fire_btn = menu.find_children("fire", "Button", true, false)[0]
	_check(fire_btn.text.contains("T"), "a remapped binding survives a menu reload")
	var wall_btn: Button = menu.find_children("build_wall", "Button", true, false)[0]
	_check(wall_btn.text.contains("Left"), "an untouched action keeps its default binding")
	wall_btn.pressed.emit()
	await _frames(2)
	_key(KEY_T)
	await _frames(2)
	_check(wall_btn.text.contains("Left"), "an input already on another action is rejected")
	_check(InputMap.action_has_event("fire", t_key), "the rejected input leaves the other binding alone")
	var close: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if b.text == "Close":
			close = b
	_check(close != null, "Tutorial & Controls has a Close button")
	close.pressed.emit()
	await _frames(2)
	_check(_labels_with("fire the cannons", menu) == 0, "the Close button closes Tutorial & Controls")
	# hermetic cleanup: drop the saved map and the in-process remap
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://input_remap.cfg"))
	InputMap.action_erase_event("fire", t_key)
	var space := InputEventKey.new()
	space.device = -1
	space.physical_keycode = KEY_SPACE
	InputMap.action_add_event("fire", space)
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
	_check(get_tree().current_scene.name == "Menu", "Esc returns to the menu")
	print("MENU TEST PASSED" if ok else "MENU TEST FAILED")
	get_tree().quit(0 if ok else 1)


func _esc() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)


func _key(k: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)


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
