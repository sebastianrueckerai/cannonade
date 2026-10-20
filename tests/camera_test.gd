extends Node
## Camera zoom / pan through real mouse events.
##   godot --headless --fixed-fps 30 res://tests/camera_test.tscn

const Main = preload("res://scripts/Main.gd")

var main: Node
var cam: Camera3D
var failures: Array = []


func check(cond: bool, msg: String) -> void:
	print(("ok: " if cond else "FAIL: ") + msg)
	if not cond:
		failures.append(msg)


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func wheel(pos: Vector2, up: bool, times := 1) -> void:
	for i in times:
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
			ev.position = pos
			ev.pressed = pressed
			Input.parse_input_event(ev)
		await frames(1)


func middle_drag(from: Vector2, to: Vector2) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_MIDDLE
	b.position = from
	b.pressed = true
	Input.parse_input_event(b)
	await frames(1)
	var steps := 5
	for i in steps:
		var m := InputEventMouseMotion.new()
		m.position = from.lerp(to, float(i + 1) / steps)
		m.relative = (to - from) / steps
		m.button_mask = MOUSE_BUTTON_MASK_MIDDLE
		Input.parse_input_event(m)
		await frames(1)
	b = b.duplicate()
	b.position = to
	b.pressed = false
	Input.parse_input_event(b)
	await frames(1)


func ground(screen: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	return o + d * (-o.y / d.y)


func whole_map_visible() -> bool:
	var m = main.game.map
	var size := get_viewport().get_visible_rect().size
	for c in [Vector2i(0, 0), Vector2i(m.sizeX - 1, 0), Vector2i(0, m.sizeZ - 1), Vector2i(m.sizeX - 1, m.sizeZ - 1)]:
		var p: Vector2 = cam.unproject_position(m.tile_position(c.x, c.y))
		if p.x < 0 or p.y < 0 or p.x > size.x or p.y > size.y:
			return false
	return true


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)  # headless windows are 64x64
	Main.requested_mode = "versus"
	Main.requested_args = {"seed": "3", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	for p in main.game.players:
		if p.is_ai():
			p.nextAction = 1e9
	cam = main.camera
	await frames(2)
	var home := cam.global_position
	var size := get_viewport().get_visible_rect().size
	var cursor := size * Vector2(0.3, 0.6)
	check(whole_map_visible(), "start view shows the whole map")

	# zooming out further than the start view is not possible
	await wheel(cursor, false, 3)
	check(cam.global_position.is_equal_approx(home), "cannot zoom out beyond the whole map view")

	# wheel up zooms in towards the point under the cursor
	var under := ground(cursor)
	var human = main.game.players[0]
	U.destroy(human.nextWall)
	human.nextWall = Catalog.spawn("wall_t", human.hand)  # no quarter turn maps a T onto itself
	var wall = U.comp(human.nextWall, "BuildingBlock")
	var cells: Array[Vector2i] = wall.cells.duplicate()
	await wheel(cursor, true)
	check(cam.global_position.y < home.y, "wheel up zooms in")
	check(ground(cursor).distance_to(under) < 0.05, "the point under the cursor stays under the cursor")
	check(wall.cells == cells, "the wheel no longer rotates the wall piece")

	# zooming in stops at a sane distance
	await wheel(cursor, true, 40)
	var dist := cam.global_position.distance_to(ground(size / 2.0))
	check(dist > 6.0 and dist < 8.0, "zoom in stops at the minimum distance (%.1f)" % dist)

	# middle mouse drag pans: the grabbed ground point follows the cursor
	var grab := size / 2.0
	var grabbed := ground(grab)
	var to := grab + Vector2(-120, 80)
	await middle_drag(grab, to)
	check(ground(to).distance_to(grabbed) < 0.05, "middle drag moves the map with the cursor")

	# zooming all the way out returns to the whole map view, where panning is off
	await wheel(cursor, false, 40)
	check(cam.global_position.is_equal_approx(home), "zooming out returns to the whole map view")
	await middle_drag(grab, to)
	check(cam.global_position.is_equal_approx(home), "no panning in the whole map view")

	print("CAMERA TEST PASSED" if failures.is_empty() else "CAMERA TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)
