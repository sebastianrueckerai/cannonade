extends Node
## The AI's building: a ring plan per castle and per yard, the held piece placed where it covers
## the most gap tiles, guns only inside own closed ground, a neutral castle ringed and claimed, a
## breach patched, a shooter over the parts cap kept in hand while the walls keep coming, and the
## reaction time after every action.
##   godot --headless --fixed-fps 30 res://tests/ai_test.tscn

const Main = preload("res://scripts/Main.gd")
const RingPlan = preload("res://scripts/RingPlan.gd")

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


func centre(c) -> Vector2i:
	return map.tile_index_at(c.go.global_position)


func castle_of(p):
	for c in map.castles:
		if U.alive(c) and not c.is_ruin() and c.owner() == p:
			return c
	return null


func neutrals() -> Array:
	var out: Array = []
	for c in map.castles:
		if U.alive(c) and not c.is_ruin() and c.owner() == null:
			out.append(c)
	return out


## The tile sits in a closed ring whose owner is p.
func enclosed_by(xz: Vector2i, p) -> bool:
	return map.is_tile_enclosed(xz.x, xz.y) and map.tiles[xz.x][xz.y].ringOwner == p


## A neutral castle with nothing but free dry ground within Chebyshev 3 of its centre.
func free_neutral():
	for c in neutrals():
		var cc := centre(c)
		var ok := true
		for x in range(cc.x - 3, cc.x + 4):
			for z in range(cc.y - 3, cc.y + 4):
				if absi(x - cc.x) < 2 and absi(z - cc.y) < 2:
					continue
				var t = map.tiles[x][z]
				if U.alive(t.structure) or t.water or t.disabled:
					ok = false
		if ok:
			return c
	return null


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


func hold_wall(id: String) -> void:
	U.destroy(enemy.nextWall)
	enemy.nextWall = Catalog.spawn(id, enemy.wallSpawn, enemy)


func _run() -> void:
	await frames(3)

	# 1: the plans at the start
	enemy.update_plans()
	var own = castle_of(enemy)
	var own_plan = enemy.castlePlans[own]
	check(own_plan.closed() and own_plan.ring.size() == 16,
			"the start castle's plan is closed by its 16 ring blocks (cost %d, ring %d)" % [own_plan.cost, own_plan.ring.size()])
	var ring_own := true
	for k in own_plan.ring:
		ring_own = ring_own and map.tiles[k.x][k.y].isWall and map.get_mini(k.x, k.y) == enemy.playerID
	check(ring_own, "every ring tile of the start plan is an own wall")
	check(own_plan.inside.size() == 9, "nothing but the castle sits inside the start ring")
	check(enemy.tiers[0] == [own_plan], "tier 0 holds the own castle's plan")
	check(enemy.yards.size() == 1 and not enemy.yards[0].closed() and enemy.yards[0].possible(),
			"a yard is planned: the start ring leaves no room for a gun (%d yards, closed %s, cost %d, gaps %d)" % [
				enemy.yards.size(), enemy.yards[0].closed() if not enemy.yards.is_empty() else "-",
				enemy.yards[0].cost if not enemy.yards.is_empty() else -1, enemy.yards[0].gaps.size() if not enemy.yards.is_empty() else -1])
	check(enemy.yards[0].cost < 16, "the yard's ring shares the start ring (cost %d)" % enemy.yards[0].cost)
	check(enemy.tiers[2].size() == enemy.claimsAtOnce and enemy.tiers[2].all(func(p): return p.possible()),
			"two claim plans with a finite ring")
	var free = free_neutral()
	check(free != null, "a neutral castle stands on free ground")
	if free != null:
		var plan = RingPlan.new(enemy, free)
		plan.refresh()
		check(plan.cost == 24 and plan.gaps.size() == 24 and plan.inside.size() == 25,
				"a free castle's ring is the 24 tiles two out, 25 inside (cost %d, gaps %d, inside %d)" % [plan.cost, plan.gaps.size(), plan.inside.size()])
		# the human walls in one tile of that ring: the AI may not build there, so its ring goes round it
		var hole: Vector2i = centre(free) + Vector2i(3, 0)
		var walls: Array = []
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				if dx != 0 or dz != 0:
					walls.append(map.tiles[hole.x + dx][hole.y + dz])
		check(walls.all(func(t): return t.is_free()), "the 3 x 3 round the ring tile east of the free castle is free")
		game.players[0]._wall_in(hole.x, hole.y, hole.x, hole.y)
		plan.refresh()
		check(map.tiles[hole.x][hole.y].ringOwner == game.players[0] and plan.possible() and not plan.ring.has(hole),
				"a ring never runs through ground the human's ring closes (possible %s, through it %s)" % [plan.possible(), plan.ring.has(hole)])
		for t in walls:
			t.un_build()

	# a breach of one block: the plan's gap is that block, cost 1
	var breach: Vector2i = own_plan.ring.keys()[0]
	map.tiles[breach.x][breach.y].un_build()
	enemy.update_plans()
	check(own_plan.cost == 1 and own_plan.gaps.keys() == [breach],
			"one ring block gone: the plan's gap is that block (cost %d, gaps %s)" % [own_plan.cost, own_plan.gaps.keys()])
	enemy.build_wall(map.tiles[breach.x][breach.y], Catalog.spawn("wall", null, enemy))
	enemy.update_plans()
	check(own_plan.closed(), "the block back, the plan is closed")

	# 2: a gun waits in hand while no own closed ground has a free tile
	U.destroy(enemy.nextBuilding)
	enemy.nextBuilding = Catalog.spawn("cannon", enemy.buildingSpawn)
	var held = enemy.nextBuilding
	check(enemy.gun_room() == 0, "the start ring has no gun room")
	enemy.execute_building_plan()
	check(U.alive(held) and enemy.nextBuilding == held and enemy.cannons.is_empty(),
			"with no room, the AI keeps the drawn gun in hand")
	check(flying_buildings().is_empty(), "the kept gun never flies")

	# 3: an S piece goes where it covers the yard's gaps, no cell on own ground or inside a plan
	hold_wall("wall_s")
	var yard = enemy.yards[0]
	var gaps: Dictionary = yard.gaps.duplicate()
	var before: int = enemy.wallTiles.size()
	check(enemy.try_build_next_wall(), "the S piece is placed")
	var placed: Array = enemy.wallTiles.slice(before)
	var covered := 0
	var on_own := false
	for t in placed:
		var k := Vector2i(t.idxX, t.idxZ)
		if gaps.has(k):
			covered += 1
		if own_plan.inside.has(k) or yard.inside.has(k):
			on_own = true
	check(placed.size() == 4 and covered >= 2 and not on_own,
			"its four blocks cover %d yard gaps and none sits inside a plan" % covered)
	U.destroy(enemy.nextBuilding)
	enemy.nextBuilding = null

	# 4: live: the yard closes, guns go inside own closed ground, a neutral castle is ringed
	enemy.dormant = false
	enemy.nextAction = 0.0
	check(enemy.secondsBetweenShots > 0.0 and enemy.secondsBetweenBuilds >= 2.0 * enemy.secondsBetweenShots,
			"the AI pauses after every action and builds at most half as fast as it shoots by default")
	enemy.secondsBetweenBuilds = 0.5  # a pace of the test's own: 25 s give the plan 50 actions
	game.timeLeftInRound = 1e6
	await seconds(25.0)
	check(yard.closed() and enclosed_by(yard.yard, enemy), "the yard is closed and the AI's")
	var guns_inside := true
	for k in enemy.cannons:
		guns_inside = guns_inside and enclosed_by(k, enemy)
	check(enemy.cannons.size() >= 3 and guns_inside,
			"%d guns placed, all inside own closed ground" % enemy.cannons.size())
	var ringed: Array = []
	for c in neutrals():
		if enclosed_by(centre(c), enemy):
			ringed.append(c)
	check(not ringed.is_empty(), "in 25 s of building the AI rings a neutral castle (%d)" % ringed.size())
	check(flying_buildings().is_empty(), "no building ever flies away from the AI's hand")
	var castles_before: int = enemy.castle_count()
	var guns_before: int = enemy.cannons.size()
	game.next_phase()
	check(enemy.castle_count() == castles_before + ringed.size(),
			"the check claims the ringed castles: %d held" % enemy.castle_count())
	check(enemy.cannons.size() == guns_before, "no gun burns at the check")
	game.next_phase()
	game.timeLeftInRound = 1e6

	# 5: a breach two blocks wide in the start ring is patched
	enemy.dormant = true
	var oc := centre(own)
	for dz in 2:
		map.tiles[oc.x + 2][oc.y + dz].un_build()
	check(not enclosed_by(oc, enemy), "two blocks gone, the castle stands open")
	enemy.dormant = false
	enemy.nextAction = 0.0
	await seconds(6.0)
	check(enclosed_by(oc, enemy), "within 6 s the AI closes its castle again")

	# 6: at the parts cap a drawn shooter waits in hand, and the walls keep coming
	enemy.dormant = true
	var spots: Array = []
	for x in map.sizeX:
		for z in map.sizeZ:
			if enemy._gun_spot(map.tiles[x][z]):
				spots.append(map.tiles[x][z])
	while enemy.parts_used() < enemy.partsCap and not spots.is_empty():
		enemy.build_building(spots.pop_back(), Catalog.spawn("cannon"))
	check(enemy.parts_used() == enemy.partsCap, "the guns fill the parts cap (%d)" % enemy.partsCap)
	U.destroy(enemy.nextBuilding)
	enemy.nextBuilding = Catalog.spawn("cannon", enemy.buildingSpawn)
	held = enemy.nextBuilding
	check(enemy.over_parts_cap(held), "the drawn cannon is over the cap")
	hold_wall("wall_2")
	before = enemy.wallTiles.size()
	enemy.execute_building_plan()
	check(enemy.nextBuilding == held and U.alive(held), "the over-cap shooter stays in hand")
	check(enemy.wallTiles.size() == before + 2, "the action places the wall piece instead")
	check(flying_buildings().is_empty(), "nothing flies away")

	# 7: the reaction times (set to values of the test's own, apart) after every build action and shot
	enemy.secondsBetweenBuilds = 1.1
	enemy.secondsBetweenShots = 0.8
	enemy.dormant = false
	enemy.nextAction = 0.0
	var built := await action_times(5.0)
	check(flying_buildings().is_empty(), "five seconds of building phase fly no building away")
	check_pace(built, 1.1, "build")

	# battle: the loaded guns fire one shot per action, never two at once
	game.buildingAllowed = false
	game.shootingAllowed = true
	game.timeLeftInRound = 1e6
	check_pace(await action_times(6.0), 0.8, "battle", 0.1)
	await frames(2)
