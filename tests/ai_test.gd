extends Node
## The AI's hand while it builds: a gun goes only into a plan's enclosure, a drawn
## shooter it cannot afford (the parts cap) is discarded quietly and redrawn on the
## usual cooldown; no building ever flies away from the AI's gui while it waits.
## Its reaction time: every build action and every shot waits secondsBetweenActions.
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


## Game times over `t` seconds at which the enemy acted: its held piece or gun left
## its hand (placed, stacked, dropped, discarded), or one of its guns fired.
func action_times(t: float) -> Array:
	var out: Array = []
	var held := [_id(enemy.nextWall), _id(enemy.nextBuilding)]
	var shots: int = enemy.stats.get("shots", 0)
	var end: float = U.time + t
	while U.time < end:
		await get_tree().process_frame
		var now := [_id(enemy.nextWall), _id(enemy.nextBuilding)]
		var fired: int = enemy.stats.get("shots", 0)
		for i in 2:
			if held[i] != 0 and now[i] != held[i]:
				out.append(U.time)
		for i in fired - shots:
			out.append(U.time)
		held = now
		shots = fired
	return out


func _id(n) -> int:
	return n.get_instance_id() if U.alive(n) else 0


## Each gap between two actions is at least the reaction time; with `slack`, while the
## AI always has an action at hand, at most that much longer.
func check_pace(times: Array, pace: float, phase: String, slack := INF) -> void:
	var gaps: Array = []
	for i in range(1, times.size()):
		gaps.append(snappedf(times[i] - times[i - 1], 0.001))
	print("%s gaps: %s" % [phase, gaps])
	check(times.size() >= 4, "%s: the AI acts (%d actions)" % [phase, times.size()])
	check(gaps.all(func(g): return g >= pace),
			"%s: every action waits the %.1f s reaction time %s" % [phase, pace, gaps])
	if slack < INF:
		check(gaps.all(func(g): return g <= pace + slack),
				"%s: the next action follows the reaction time within %.1f s %s" % [phase, slack, gaps])


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
	var piece = enemy.nextWall
	enemy.execute_building_plan()
	check(U.alive(held) and enemy.nextBuilding == held and enemy.cannons.is_empty(),
			"with no plan to wall it, the AI keeps the drawn gun in hand")
	# no plan and no search running: the piece is dropped, and the drop is an action
	check(enemy.nextWall == null and U.comp(piece, "FlyAndVanish").fly,
			"with no plan and no search, the AI drops its piece")
	check(enemy.nextAction >= U.time + enemy.secondsBetweenActions,
			"the drop waits the reaction time like any action")
	U.destroy(held)
	enemy.nextBuilding = null

	# while a plan search runs, the AI keeps the redrawn piece (a search that yields at once
	# stands in for the first search of a game, which spans several frames)
	await seconds(3.2)
	piece = enemy.nextWall
	check(U.alive(piece), "the dropped piece is redrawn")
	var budget: int = enemy.sliceBudgetUsec
	enemy.sliceBudgetUsec = 0
	enemy.update_plans()
	enemy.execute_building_plan()
	enemy.sliceBudgetUsec = budget
	check(enemy.activePlans.is_empty() and enemy.nextWall == piece and not U.comp(piece, "FlyAndVanish").fly,
			"while the plans are still being searched, the AI keeps its piece")
	U.destroy(enemy.nextBuilding)
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

	# live build phase: the AI churns through draws, no building ever flies, and it takes its
	# reaction time (set to a value of the test's own) after every action
	check(enemy.secondsBetweenActions > 0.0, "the AI pauses between actions by default")
	enemy.secondsBetweenActions = 0.8
	enemy.dormant = false
	enemy.nextAction = 0.0
	var built := await action_times(5.0)
	check(flying_buildings().is_empty(),
			"five seconds of building phase fly no building away")
	check_pace(built, 0.8, "build")

	# battle: the six loaded guns fire one shot per action, never two at once
	game.buildingAllowed = false
	game.shootingAllowed = true
	game.timeLeftInRound = 1e6
	check_pace(await action_times(6.0), 0.8, "battle", 0.1)
	await frames(2)
