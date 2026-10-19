extends Node
## Sandbox through real mouse / key input: drawing walls, placing and erasing,
## undo / redo, save / load, mirror, battles with all match setups, target
## choice, stats, winner and Reset, background runs.
##   godot --headless --fixed-fps 30 res://tests/sandbox_test.tscn

const SandboxScene = preload("res://scenes/sandbox.tscn")

var sb: Node
var mouse := Vector2.ZERO
var failures: Array = []


func check(cond: bool, msg: String) -> void:
	print(("ok: " if cond else "FAIL: ") + msg)
	if not cond:
		failures.append(msg)


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func seconds(t: float) -> void:
	var end: float = U.time + t
	while U.time < end:
		await get_tree().process_frame


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	seed(3)
	sb = SandboxScene.instantiate()
	get_tree().root.add_child.call_deferred(sb)
	await frames(3)
	await _run()
	print("SANDBOX TEST PASSED" if failures.is_empty() else "SANDBOX TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)


# ------------------------------------------------------------ input helpers
func screen_of(xz: Vector2i) -> Vector2:
	return sb.get_viewport().get_camera_3d().unproject_position(sb.map.tile_position(xz.x, xz.y, 0.1))


func move_to(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = p - mouse
	ev.position = p
	mouse = p
	Input.parse_input_event(ev)
	await frames(1)


func button(index: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = index
	ev.position = mouse
	ev.pressed = pressed
	Input.parse_input_event(ev)
	await frames(1)


func click_at(p: Vector2, index := MOUSE_BUTTON_LEFT) -> void:
	await move_to(p)
	await button(index, true)
	await button(index, false)


func click_tile(xz: Vector2i, index := MOUSE_BUTTON_LEFT) -> void:
	await click_at(screen_of(xz), index)


## Drags the left mouse button through the tiles in order.
func drag(tiles: Array, index := MOUSE_BUTTON_LEFT) -> void:
	await move_to(screen_of(tiles[0]))
	await button(index, true)
	for t in tiles:
		await move_to(screen_of(t))
	await button(index, false)


func ui_click(name: String) -> void:
	var b: Control = sb.ui.find_child(name, true, false)
	await click_at(b.get_global_rect().get_center())


func key(code: int, ctrl := false) -> void:
	for pressed in [true, false]:
		var k := InputEventKey.new()
		k.keycode = code
		k.physical_keycode = code
		k.ctrl_pressed = ctrl
		k.pressed = pressed
		Input.parse_input_event(k)
		await frames(1)


func select_option(name: String, index: int) -> void:
	var o: OptionButton = sb.ui.find_child(name, true, false)
	o.select(index)
	o.item_selected.emit(index)
	await frames(1)


## Tiles along the border of a rectangle, in drawing order.
func border(x0: int, z0: int, x1: int, z1: int) -> Array:
	var out: Array = []
	for x in range(x0, x1 + 1):
		out.append(Vector2i(x, z0))
	for z in range(z0 + 1, z1 + 1):
		out.append(Vector2i(x1, z))
	for x in range(x1 - 1, x0 - 1, -1):
		out.append(Vector2i(x, z1))
	for z in range(z1 - 1, z0, -1):
		out.append(Vector2i(x0, z))
	return out


func structure_id(xz: Vector2i) -> String:
	var s = sb.map.tiles[xz.x][xz.y].structure
	return Catalog.def_of(s).id if U.alive(s) else ""


# --------------------------------------------------------------------- run
func _run() -> void:
	var map = sb.map
	check(sb.snapshot().size() == 26, "a new layout has two walled-in bases")

	# drawing walls: drag around a rectangle, corners connect and enclose it
	await drag(border(3, 3, 7, 6))
	var enclosed := true
	for x in range(4, 7):
		for z in range(4, 6):
			enclosed = enclosed and map.is_tile_enclosed(x, z)
	check(enclosed, "dragging walls around a rectangle encloses it")
	check(sb.player(0).wallTiles.size() == 12 + 14, "the walls belong to blue")

	# buildings: cannons inside and outside the walls both work
	await ui_click("Tool_cannon")
	await click_tile(Vector2i(5, 4))
	await click_tile(Vector2i(10, 10))
	await seconds(0.4)
	check(structure_id(Vector2i(5, 4)) == "cannon" and structure_id(Vector2i(10, 10)) == "cannon", "click places cannons")
	check(sb.player(0).activeCannons.size() == 2, "both cannons are active, inside or outside the walls")

	# a 2x2 building takes four tiles; it cannot overlap
	await ui_click("Tool_flak22")
	await click_tile(Vector2i(12, 12))
	var flak_tiles := 0
	for t in [Vector2i(12, 12), Vector2i(13, 12), Vector2i(12, 13), Vector2i(13, 13)]:
		if structure_id(t) == "flak22":
			flak_tiles += 1
	check(flak_tiles == 4, "a 2x2 building occupies four tiles")
	var before: int = sb.snapshot().size()
	await click_tile(Vector2i(13, 13))
	check(sb.snapshot().size() == before, "nothing is placed over an occupied tile")

	# erase with the right mouse button, undo and redo with the keyboard
	await click_tile(Vector2i(10, 10), MOUSE_BUTTON_RIGHT)
	check(structure_id(Vector2i(10, 10)) == "", "right click erases")
	await key(KEY_Z, true)
	check(structure_id(Vector2i(10, 10)) == "cannon", "Ctrl+Z brings it back")
	await key(KEY_Y, true)
	check(structure_id(Vector2i(10, 10)) == "", "Ctrl+Y erases it again")
	await click_tile(Vector2i(13, 12), MOUSE_BUTTON_RIGHT)
	check(structure_id(Vector2i(12, 13)) == "", "erasing one tile of a 2x2 building removes all of it")

	# breaking the rectangle opens it; undo closes it again
	await click_tile(Vector2i(5, 3), MOUSE_BUTTON_RIGHT)
	check(not sb.map.is_tile_enclosed(5, 4), "erasing a wall opens the area")
	await key(KEY_Z, true)
	check(sb.map.is_tile_enclosed(5, 4), "undo closes it again")

	# red: a walled area with two cannons
	await key(KEY_2)
	await ui_click("Tool_wall")
	await drag(border(20, 21, 24, 25))
	await ui_click("Tool_cannon")
	await click_tile(Vector2i(21, 22))
	await click_tile(Vector2i(23, 24))
	check(sb.player(1).cannons.size() == 2, "key 2 switches to red; red has two cannons")

	# save, start over, load
	var layout: Array = sb.snapshot()
	(sb.ui.find_child("SaveName", true, false) as LineEdit).text = "sandbox_test"
	await ui_click("Save")
	await ui_click("New")
	check(sb.snapshot().size() == 26, "New starts an empty layout")
	var opts: OptionButton = sb.ui.find_child("Scenarios", true, false)
	for i in opts.item_count:
		if str(opts.get_item_metadata(i)).ends_with("sandbox_test.tres"):
			await select_option("Scenarios", i)
	await ui_click("Load")
	check(_same(sb.snapshot(), layout), "Load restores the saved layout")
	DirAccess.remove_absolute("user://scenarios/sandbox_test.tres")


	# battle: AI vs AI, fast, with a time limit
	(sb.ui.find_child("TimeLimit", true, false) as SpinBox).value = 120
	await select_option("TargetRed", 1)  # red shoots at guns
	await ui_click("Play")
	await ui_click("Speed4")
	check(sb.mode == sb.Mode.BATTLE and Engine.time_scale == 8.0, "Play starts the battle; 8x speed")
	var red_first_target = null
	var end: float = U.time + 125.0
	while U.time < end and sb.mode == sb.Mode.BATTLE:
		if red_first_target == null:
			for p in U.projectiles:
				if p.player == sb.player(1) and U.alive(p.destinationTile):
					# remember what was aimed at when the shell was fired
					red_first_target = U.shooter(p.destinationTile.structure) != null
					break
		await frames(1)
	check(red_first_target == true, "red, set to shoot at guns, aims at a gun")
	var s0: Dictionary = sb.player(0).stats
	var s1: Dictionary = sb.player(1).stats
	check(s0.get("shots", 0) > 0 and s1.get("shots", 0) > 0, "both sides fire (%s / %s shots)" % [s0.get("shots", 0), s1.get("shots", 0)])
	check(s0.get("hits", 0) + s1.get("hits", 0) > 0, "shots hit enemy buildings")
	check(sb.mode == sb.Mode.ENDED and sb.ui.find_child("Status", true, false).text != "", "the battle ends with a result: %s" % sb.ui.find_child("Status", true, false).text)

	# Reset returns to the layout before the battle
	await ui_click("Play")
	check(sb.mode == sb.Mode.EDIT and _same(sb.snapshot(), layout), "Back to editing restores the layout")

	# player vs dormant AI: red never fires, the player can
	await select_option("Match", 2)
	await ui_click("Play")
	await ui_click("Speed1")
	var red_wall = sb.map.tiles[20][23]
	await move_to(screen_of(Vector2i(red_wall.idxX, red_wall.idxZ)))
	await seconds(1.0)
	await key(KEY_SPACE)
	await seconds(6.0)
	check(sb.player(1).stats.get("shots", 0) == 0, "the dormant AI never fires")
	check(sb.player(0).stats.get("shots", 0) >= 1, "the player fires with Space")
	await ui_click("Play")

	# Mirror: blue's layout replaces red's, mirrored top to bottom; undo brings red's back
	await key(KEY_1)
	await ui_click("Mirror")
	check(structure_id(Vector2i(5, 25)) == "cannon" and structure_id(Vector2i(21, 22)) == ""
			and sb.player(1).cannons.size() == sb.player(0).cannons.size(), "Mirror copies blue's layout to red, mirrored")
	check(sb.map.is_tile_enclosed(5, 25) and sb.map.tiles[5][25].player == sb.player(1), "the mirrored walls enclose red's copy")
	await key(KEY_Z, true)
	check(structure_id(Vector2i(21, 22)) == "cannon" and structure_id(Vector2i(5, 25)) == "", "Ctrl+Z undoes the mirror")

	# Run: the layout is played in a background process with the match settings
	await select_option("Match", 3)  # AI vs dormant AI
	(sb.ui.find_child("Runs", true, false) as SpinBox).value = 2
	await ui_click("Run")
	var deadline := Time.get_ticks_msec() + 120000
	while sb.lab_pid > 0 and Time.get_ticks_msec() < deadline:
		await frames(1)
	var lab_text: String = sb.ui.find_child("Lab", true, false).text
	print(lab_text)
	var shots := Array(lab_text.split("\n")).filter(func(l): return l.begins_with("shots"))
	check(lab_text.contains("4 battles (seeds 1-2, also swapped)") and lab_text.contains("Blue's layout wins"),
			"Run shows the result of 2 seeds, each played both ways round")
	check(shots.size() == 1 and float(shots[0].split(" ", false)[1]) > 0 and float(shots[0].split(" ", false)[2]) == 0,
			"the runs use the match setting: the dormant red layout never fires")
	await select_option("Match", 0)

	# every shipped example loads completely and everything in it works
	for path in sb.saved_scenarios():
		if path.begins_with(sb.EXAMPLE_DIR):
			var example: ScenarioDef = load(path)
			sb.load_scenario(path)
			await seconds(0.4)
			check(sb.snapshot().size() == example.items.size() and sb.inactive_count() == 0,
					"example %s loads with everything placed and working" % path.get_file())
			await select_option("Match", 0)
			await ui_click("Play")  # and fights without errors
			await seconds(20.0)
			check(sb.player(0).stats.get("shots", 0) > 0 and sb.player(1).stats.get("shots", 0) > 0,
					"both sides of %s fire" % path.get_file())
			await ui_click("Play")


func _same(a: Array, b: Array) -> bool:
	var ka := a.map(func(it): return "%s" % [it])
	var kb := b.map(func(it): return "%s" % [it])
	ka.sort()
	kb.sort()
	return ka == kb
