extends Node
## Upgrade patterns and the special structures they produce, built from upgrade
## blocks through the real merge path (UpgradeCluster + UpgradeSelection):
## patterns -> structure, cluster bombs, rockets, shield, flak, ships.
##   godot --headless --fixed-fps 30 res://tests/weapons.tscn

const Main = preload("res://scripts/Main.gd")
const BuildingPlan = preload("res://scripts/BuildingPlan.gd")
const BLOCKS := {0: "upgrade_a", 1: "upgrade_b"}

var main: Node
var game
var map
var p1
var p2
var failures: Array = []


func check(cond: bool, msg: String) -> void:
	print(("ok: " if cond else "FAIL: ") + msg)
	if not cond:
		failures.append(msg)


func seconds(t: float) -> void:
	var end: float = U.time + t
	while U.time < end:
		await get_tree().process_frame


func _ready() -> void:
	Main.requested_mode = "ai2"
	Main.requested_args = {"seed": "21", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	game = main.game
	map = game.map
	p1 = game.players[0]
	p2 = game.players[1]
	for p in game.players:
		p.nextAction = 1e9  # AIs stay idle
	await _run()
	print("WEAPONS TEST PASSED" if failures.is_empty() else "WEAPONS TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)


## Places upgrade blocks (types in x-major, z-minor order) with the square's
## lower corner at (x, z); the centre of a 3x3 last, like a player would to
## avoid a 2x2 merging first. Returns the merged structure.
func build_pattern(p, x: int, z: int, types: Array) -> Node3D:
	var side := 2 if types.size() == 4 else 3
	var order: Array = []
	for i in types.size():
		if not (side == 3 and i == 4):
			order.append(i)
	if side == 3:
		order.append(4)
	for i in order:
		var t = map.tiles[x + i / side][z + i % side]
		p.build_building(t, Catalog.spawn(BLOCKS[types[i]]))
	return map.tiles[x + 1][z + 1].structure


func _run() -> void:
	await seconds(0.2)
	game.buildingAllowed = false
	game.shootingAllowed = true
	game.timeLeftInRound = 1e6

	# upgrade patterns -> structures (a = 0, b = 1); flak and shield patterns are rotated.
	# A 3x3 square without a 3x3 recipe merges one of its 2x2 corners instead, also the pattern
	# of the parked rocket station.
	var cases := [
		[[1, 1, 1, 1, 1, 1, 1, 1, 1], "cannon22b"], [[1, 1, 1, 1, 1, 1, 0, 0, 0], "cannon22b"],
		[[0, 0, 0, 0], "cannon22a"], [[1, 1, 1, 1], "cannon22b"], [[0, 1, 1, 1], "flak22"],
		[[1, 0, 0, 0], "shield22"],
		# an adjacent pair of b blocks: along x a supply depot, along z a cannon22d
		[[1, 0, 1, 0], "supply22"], [[0, 1, 0, 1], "supply22"],
		[[1, 1, 0, 0], "cannon22d"], [[0, 0, 1, 1], "cannon22d"]]
	var spots := [Vector2i(25, 24), Vector2i(3, 8), Vector2i(13, 10), Vector2i(24, 9), Vector2i(23, 19), Vector2i(5, 19),
		Vector2i(8, 13), Vector2i(20, 13), Vector2i(8, 26), Vector2i(20, 27)]
	var owners := [p2, p1, p1, p1, p2, p2, p1, p1, p1, p1]
	var built := {}
	for i in cases.size():
		var s := build_pattern(owners[i], spots[i].x, spots[i].y, cases[i][0])
		var name: String = Catalog.def_of(s).id if U.alive(s) else "nothing"
		check(name == cases[i][1], "pattern %s merges into %s (got %s)" % [cases[i][0], cases[i][1], name])
		built[cases[i][1]] = s

	# cluster bomb: sub munitions set the tiles around the target on fire
	var target = map.tiles[15][22]
	var cluster := U.shooter(built["cannon22b"])
	check(cluster.try_shoot(target.go.global_position, target), "cannon22b fires")
	var burning := false
	var end: float = U.time + 15.0
	while U.time < end and not burning:
		await get_tree().process_frame
		for t in target.get_surrounding_tiles(3):
			burning = burning or (t.burning and not t.buildable())
	check(burning, "cluster bomb sets tiles on fire (not buildable while burning)")

	# rocket, from the parked rocket station placed from its file: the hit tile is destroyed for good
	var station: Node3D = p1.place(load("res://data/buildings/rocket_station.tres"), 9, 2)
	var rt = map.tiles[15][26]  # out of reach of the flak and the shield
	var launcher := U.shooter(station)
	launcher.nextBulletTime = 0.0  # skip the initial reload delay
	check(launcher.try_shoot(rt.go.global_position, rt), "rocket station fires")
	end = U.time + 30.0
	while U.time < end and rt.buildable():
		await get_tree().process_frame
	check(not rt.buildable(), "rocket hit makes the tile unbuildable")

	# shield and flak protect their own structure against an enemy shell
	var gun := U.shooter(built["cannon22a"])
	for name in ["shield22", "flak22"]:
		var s: Node3D = built[name]
		var tile = U.comp(s, "BuildingBlock").buildingPlace
		gun.nextBulletTime = 0.0
		check(gun.try_shoot(tile.go.global_position, tile), "shell fired at the %s" % name)
		await seconds(10.0)
		check(U.alive(s) and U.projectiles.is_empty(), "%s survives a direct hit (shell intercepted)" % name)

	# the same shell destroys an unprotected structure (control for the two checks above)
	var plain = map.tiles[15][17]
	p2.build_building(plain, Catalog.spawn("cannon"))
	gun.nextBulletTime = 0.0
	gun.try_shoot(plain.go.global_position, plain)
	await seconds(10.0)
	check(not U.alive(plain.structure), "an unprotected structure is destroyed by the same shell")

	# the AI lays out a supply depot so that it really becomes one, even when a
	# block already placed forces a turned layout
	var origin := Vector2i(24, 14)
	# a b block in this corner also fits the turned (cannon22d) layout
	p2.build_building(map.tiles[origin.x + 1][origin.y + 1], Catalog.spawn("upgrade_b"))
	for dx in 2:
		for dz in 2:
			p2.mark_buildable_area_line_of_sight(origin.x + dx, origin.y + dz)
	var plan := BuildingPlan.new(origin.x, origin.y, p2, 1, 1, 2, 2)
	check(plan.try_initialize_xz_upgrade_tiles("supply22"), "AI finds a supply depot layout")
	for xz in plan.xz2UpgradeTilesType:
		if not U.alive(map.tiles[xz.x][xz.y].structure):
			p2.build_building(map.tiles[xz.x][xz.y], Catalog.spawn(plan.xz2UpgradeTilesType[xz]))
	var depot = map.tiles[origin.x + 1][origin.y + 1].structure
	check(U.alive(depot) and Catalog.def_of(depot).id == "supply22",
			"the AI's layout merges into a supply depot (got %s)" % [Catalog.def_of(depot).id if U.alive(depot) else "nothing"])

	# ships take damage and sink
	var water = map.tiles[0][map.sizeZ - 1]
	water.water = true
	var ship_go := U.instantiate(preload("res://prefabs/Ship.tscn"), game.fleet.go)
	ship_go.global_position = water.go.global_position
	var ship := U.comp(ship_go, "Ship")
	game.fleet.ships.append(ship)
	ship.set_sail(game.fleet, map, water)
	water.damage_building_place(5.0)
	check(U.alive(ship_go), "a ship survives a light hit")
	water.damage_building_place(10.0)
	check(not U.alive(ship_go) and not game.fleet.ships.has(ship), "a ship sinks when its health is used up")
