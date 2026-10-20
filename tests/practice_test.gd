extends Node
## Practice mode through real key input on the standard castle map: Enter switches between build
## and battle, the dormant enemy holds its walled start castle and never fires, wall damage stays
## across phases, and ruining the enemy castle ends the game with the VICTORY overlay.
##   godot --headless --fixed-fps 30 res://tests/practice_test.tscn

const Main = preload("res://scripts/Main.gd")

var main: Node
var game
var map
var human
var enemy
var mouse := Vector2.ZERO
var failures: Array = []


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)  # headless windows are 64 x 64
	Main.requested_mode = "practice"
	Main.requested_args = {"seed": "7", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	game = main.game
	map = game.map
	human = game.players[0]
	enemy = game.players[1]
	await _run()
	print("PRACTICE TEST PASSED" if failures.is_empty() else "PRACTICE TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)


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


func point_at_tile(xz: Vector2i) -> void:
	mouse = main.camera.unproject_position(map.tile_position(xz.x, xz.y, 0.1))
	var ev := InputEventMouseMotion.new()
	ev.position = mouse
	Input.parse_input_event(ev)
	await frames(2)


func click() -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = mouse
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await frames(1)


func press_key(key: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await frames(1)
	await frames(1)


func enemy_castle():
	for c in map.castles:
		if U.alive(c) and c.owner() == enemy:
			return c
	return null


func _find_label(node, text: String) -> bool:
	if node is Label and node.text == text:
		return true
	for child in node.get_children():
		if _find_label(child, text):
			return true
	return false


func _run() -> void:
	await frames(3)
	# the standard versus map with a dormant enemy
	var ec = enemy_castle()
	check(ec != null and map.is_tile_enclosed(map.sizeX / 2, map.sizeZ - 1 - map.sizeZ / 4), "the enemy starts with its castle walled in")
	var neutral := 0
	for c in map.castles:
		if U.alive(c) and c.owner() == null:
			neutral += 1
	check(map.castles.size() == 10 and neutral == 8, "ten castles, eight of them neutral")
	check(human.partsCap == 6, "one castle caps the parts at 6")
	check(game.buildingAllowed and not main.get_node("UI/Timer").visible, "practice starts building, without a timer")

	# a pocket on the start ring for a gun (the ring itself has no free tile), then Enter: battle
	var b := Vector2i(map.sizeX / 2, map.sizeZ / 4)  # the player's castle
	human.build_wall(map.tiles[b.x + 3][b.y - 2], Catalog.spawn("wall"))
	human.build_wall(map.tiles[b.x + 4][b.y - 2], Catalog.spawn("wall"))
	for z in range(b.y - 1, b.y + 2):
		human.build_wall(map.tiles[b.x + 4][z], Catalog.spawn("wall"))
	human.build_wall(map.tiles[b.x + 4][b.y + 2], Catalog.spawn("wall"))
	human.build_wall(map.tiles[b.x + 3][b.y + 2], Catalog.spawn("wall"))
	check(map.is_tile_enclosed(b.x + 3, b.y), "the pocket is walled in")
	human.build_building(map.tiles[b.x + 3][b.y], Catalog.spawn("cannon"))
	await frames(2)
	check(human.activeCannons.size() == 1, "the player's gun is active")
	await press_key(KEY_ENTER)
	check(game.shootingAllowed and not game.buildingAllowed, "Enter starts the battle")
	await seconds(6.0)
	check(enemy.stats.get("shots", 0) == 0, "the dormant enemy never fires")

	# a shell destroys an enemy wall; nothing rebuilds it
	var front := Vector2i(b.x, map.sizeZ - 1 - map.sizeZ / 4 - 2)  # the ring wall south of the enemy's castle
	await point_at_tile(front)
	await press_key(KEY_SPACE)
	await seconds(12.0)
	check(not U.alive(map.tiles[front.x][front.y].structure), "a shell destroys the aimed enemy wall")
	await press_key(KEY_ENTER)
	check(game.buildingAllowed and not game.shootingAllowed, "Enter goes back to building")
	await frames(3)
	check(not U.alive(map.tiles[front.x][front.y].structure), "the damage stays while building")
	check(human.cannons.size() == 1 and game.started, "the walled gun survives the check and the game runs on")

	# twelve shells ruin the enemy castle; the next check ends the game
	for i in 12:
		map.tiles[map.sizeX / 2][map.sizeZ - 1 - map.sizeZ / 4].damage_building_place(10.0)
	check(ec.is_ruin() and U.alive(ec.go) and map.get_mini(map.sizeX / 2, map.sizeZ - 1 - map.sizeZ / 4) == 255, "twelve shells leave a ruin")
	await press_key(KEY_ENTER)
	check(not game.started, "the enemy without a castle is out at the check")
	var overlay := main.get_node_or_null("GameOver")
	check(overlay != null and _find_label(overlay, "VICTORY"), "the overlay shows the victory")
