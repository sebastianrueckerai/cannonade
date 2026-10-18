extends Node
## Practice mode through real key input: Enter switches between build and battle, the target fort never
## fires and never grows, and it stands again, complete, at the start of every battle.
##   godot --headless --fixed-fps 30 res://tests/practice_test.tscn

const Main = preload("res://scripts/Main.gd")

var main: Node
var game
var map
var human
var target
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
	target = game.players[1]
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


## Building id per tile of the target's fort.
func fort() -> Dictionary:
	var out := {}
	for column in map.tiles:
		for t in column:
			if t.player == target and U.alive(t.structure):
				out[Vector2i(t.idxX, t.idxZ)] = Catalog.def_of(t.structure).id
	return out


func _run() -> void:
	await frames(3)
	var start := fort()
	var ids: Array = start.values()
	check(ids.has("base") and ids.has("cannon22a") and ids.has("supply22") and ids.count("cannon") == 4,
			"the fort holds the base, a 2x2 cannon, the depots and four cannons")
	var base = target.startBase.buildingPlace
	check(map.is_tile_enclosed(base.idxX, base.idxZ), "the fort is walled in")
	check(game.buildingAllowed and not main.get_node("UI/Timer").visible, "practice starts building, without a timer")

	# a wall the fort could aim at (left click), a gun in the player's walls (fixture), then Enter: battle
	var b := Vector2i(map.sizeX / 2, map.sizeZ / 4)
	await point_at_tile(b + Vector2i(0, 3))
	await click()
	check(human.wallTiles.size() == 1, "left click builds a wall")
	map.tiles[b.x][b.y].un_build()
	human.build_building(map.tiles[b.x][b.y], Catalog.spawn("cannon"))
	await frames(2)
	check(human.activeCannons.size() == 1, "the player's gun is active")
	await press_key(KEY_ENTER)
	check(game.shootingAllowed and not game.buildingAllowed, "Enter starts the battle")
	await seconds(6.0)
	check(target.activeCannons.size() == 5 and target.stats.get("shots", 0) == 0,
			"the fort's guns are ready but never fire back")

	var front := Vector2i(map.sizeX / 2, base.idxZ - 3)
	check(start.has(front) and map.tiles[front.x][front.y].isWall, "aimed tile is a wall of the fort")
	await point_at_tile(front)
	await press_key(KEY_SPACE)
	await seconds(12.0)
	check(not U.alive(map.tiles[front.x][front.y].structure), "a shell destroys the aimed fort wall")

	await press_key(KEY_ENTER)
	check(game.buildingAllowed and not game.shootingAllowed, "Enter goes back to building")
	await seconds(8.0)
	var damaged := fort()
	check(not damaged.has(front), "the damage stays while building")
	check(damaged.keys().all(func(k): return start.has(k)), "the fort does not grow")

	await press_key(KEY_ENTER)
	check(fort() == start, "the next battle starts with the whole fort again")
	check(map.is_tile_enclosed(base.idxX, base.idxZ), "the rebuilt fort is walled in")
