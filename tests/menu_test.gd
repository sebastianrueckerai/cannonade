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
	_check(buttons.size() == 6, "menu has 6 buttons")
	for b in buttons:
		if b.text.contains("AI vs. AI"):
			b.pressed.emit()
	await _frames(5)
	var main := get_tree().current_scene
	_check(main.name == "Main" and main.game != null and main.game.started, "game started from the menu")
	_check(main.mode == "ai2", "selected mode is used")
	await _frames(30)
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(5)
	_check(get_tree().current_scene.name == "Menu", "Esc returns to the menu")
	print("MENU TEST PASSED" if ok else "MENU TEST FAILED")
	get_tree().quit(0 if ok else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(c: bool, msg: String) -> void:
	print(("ok: " if c else "FAIL: ") + msg)
	ok = ok and c
