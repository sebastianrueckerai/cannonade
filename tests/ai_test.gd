extends Node
## The AI's hand while it builds: a gun goes only into a plan's enclosure, a drawn
## shooter it cannot afford (the parts cap) is discarded quietly and redrawn on the
## usual cooldown; no building ever flies away from the AI's gui while it waits.
##   godot --headless --fixed-fps 30 res://tests/ai_test.tscn

const Main = preload("res://scripts/Main.gd")

var main: Node
var game
var enemy
var map
var failures: Array = []


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)  # headless windows are 64 x 64
	Main.requested_mode = "versus"
	Main.requested_args = {"seed": "7", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	game = main.game
	map = game.map
	enemy = game.players[1]
	enemy.dormant = true  # keep the AI idle until the scripted checks run it
	await _run()
	print("AI TEST PASSED" if failures.is_empty() else "AI TEST FAILED: %s" % [failures])
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


## Live FlyAndVanish flights of buildings. The wall's discard may fly (that is
## the shape rotation, not the churn under test), so walls are filtered out.
func flying_buildings() -> Array:
	var out: Array = []
	for fv in get_tree().root.find_children("FlyAndVanish", "", true, false):
		if fv.fly and not fv.isWall:
			out.append(fv)
	return out


## Free, dry, buildable tiles in the enemy's build range.
func enemy_free_tiles() -> Array:
	var b := Vector2i(map.sizeX / 2, map.sizeZ - map.sizeZ / 4)
	var out: Array = []
	for r in range(2, 6):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var t = map.tiles[b.x + dx][b.y + dz]
				if enemy.in_reach(t.idxX, t.idxZ) and not U.alive(t.structure) and t.buildable():
					out.append(t)
	return out


func _run() -> void:
	await frames(3)
	# a gun goes only where a plan walls it: with no plan yet, the drawn cannon stays in hand
	check(enemy.activePlans.is_empty(), "the dormant enemy has no plan yet")
	U.destroy(enemy.nextBuilding)
	enemy.nextBuilding = Catalog.spawn("cannon", enemy.buildingSpawn)
	var held = enemy.nextBuilding
	enemy.execute_building_plan()
	check(U.alive(held) and enemy.nextBuilding == held and enemy.cannons.is_empty(),
			"with no plan to wall it, the AI keeps the drawn gun in hand")
	U.destroy(held)
	enemy.nextBuilding = null
	# the enemy sits at its parts cap, built the real way
	var spots := enemy_free_tiles()
	check(spots.size() >= 6, "the enemy has free tiles in build range")
	for i in 6:
		enemy.build_building(spots[i], Catalog.spawn("cannon"))
	check(enemy.parts_used() == 6, "six guns sit at the enemy's parts cap")

	# a drawn shooter over the cap is discarded without flying away
	enemy.nextBuilding = Catalog.spawn("cannon", enemy.buildingSpawn)
	check(enemy.over_parts_cap(enemy.nextBuilding), "the drawn cannon is over the cap")
	enemy.execute_building_plan()
	check(not U.alive(enemy.nextBuilding), "the over-cap shooter is discarded")
	check(flying_buildings().is_empty(), "the discard flies nothing away")

	# live build phase: the AI churns through draws, no building ever flies
	enemy.dormant = false
	enemy.nextAction = 0.0
	await seconds(5.0)
	check(flying_buildings().is_empty(),
			"five seconds of building phase fly no building away")
	await frames(2)
