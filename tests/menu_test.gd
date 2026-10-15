extends Node
## Menu -> game -> Esc -> menu flow.
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
	_check(buttons.size() == 7, "menu has 7 buttons")
	for b in buttons:
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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(c: bool, msg: String) -> void:
	print(("ok: " if c else "FAIL: ") + msg)
	ok = ok and c
