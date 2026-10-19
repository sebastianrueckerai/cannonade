extends Node
## The loading screen's label and bar sit inside the panel skin's drawn frame:
## the parchment of ui/panel.png carries a double-line frame 31-36 px from the
## top edge, 35-41 px from the bottom, 33-38 px from the left and 34-39 px from
## the right (measured on the 917x512 texture), and the 46 px slice margins keep
## those bands unscaled in every panel, so laid-out content must clear them.
##   godot --headless --fixed-fps 30 res://tests/loading_test.tscn

const Loading = preload("res://scripts/Loading.gd")

var ok := true


func _ready() -> void:
	# this node is the running scene; hand that role to a dummy so the loading
	# screen's scene handover does not free the test
	await get_tree().process_frame
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	get_tree().root.size = Vector2i(1280, 720)
	Loading.next_scene = "res://tests/loading_target.tscn"
	var loading: Node = (load("res://scenes/loading.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(loading)
	await _frames(3)
	var panel: PanelContainer = loading.find_children("*", "PanelContainer", true, false)[0]
	var pr := panel.get_global_rect()
	_check(pr.size.x >= 300.0, "the loading panel is laid out (%s)" % pr)
	for child in loading.find_children("*", "Control", true, false):
		if not (child is Label or child is ProgressBar):
			continue
		var r: Rect2 = child.get_global_rect()
		var inside: bool = (
			r.position.x - pr.position.x >= 39.0
			and r.position.y - pr.position.y >= 37.0
			and r.end.x - pr.position.x <= pr.size.x - 40.0
			and r.end.y - pr.position.y <= pr.size.y - 42.0
		)
		_check(inside, "the %s sits inside the drawn frame (control %s in panel %s)"
				% [child.get_class(), r, pr])
	loading.queue_free()
	get_tree().current_scene.queue_free()
	dummy.queue_free()
	await _frames(1)
	print("LOADING TEST PASSED" if ok else "LOADING TEST FAILED")
	get_tree().quit(0 if ok else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(c: bool, msg: String) -> void:
	print(("ok: " if c else "FAIL: ") + msg)
	ok = ok and c
