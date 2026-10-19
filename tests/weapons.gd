extends Node
## The special structures and what they do: the four-cannon fusion, cluster
## bombs, rockets, shield and flak interception, gun damage, ships. The 2x2
## specials are placed from their files; their upgrade-block recipes are parked
## out of the game.
##   godot --headless --fixed-fps 30 res://tests/weapons.tscn

const Main = preload("res://scripts/Main.gd")

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


func _run() -> void:
	await seconds(0.2)
	game.buildingAllowed = false
	game.shootingAllowed = true
	game.timeLeftInRound = 1e6

	# the 2x2 specials placed directly from their files (their upgrade-block
	# recipes are parked out of the game)
	var built := {}
	built["cannon22b"] = p2.place(load("res://data/buildings/cannon22b.tres"), 25, 24)
	built["flak22"] = p2.place(load("res://data/buildings/flak22.tres"), 23, 17)
	# the shield stands away from the gun's firing lines: its 7-tile radius would
	# swallow every shell the checks below fire, and the volley must land
	built["shield22"] = p2.place(load("res://data/buildings/shield22.tres"), 23, 3)
	check(built.values().all(func(s): return U.alive(s)), "the specials stand on the map")

	# four basic cannons in a square fuse into the heavy cannon
	var fspot := Vector2i(3, 22)
	for i in 4:
		p1.build_building(map.tiles[fspot.x + i / 2][fspot.y + i % 2], Catalog.spawn("cannon"))
	var fused = map.tiles[fspot.x + 1][fspot.y + 1].structure
	var fused_def := Catalog.def_of(fused) if U.alive(fused) else null
	check(fused_def != null and fused_def.id == "cannon22a",
			"four cannons in a square fuse into the heavy cannon (got %s)" % [fused_def.id if fused_def else "nothing"])
	built["cannon22a"] = fused

	# cluster bomb: sub munitions set the tiles around the target on fire
	var target = map.tiles[15][17]
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

	# the same shells destroy an unprotected structure (control for the two checks above)
	var plain = map.tiles[15][17]
	p2.build_building(plain, Catalog.spawn("cannon"))
	for i in 4:
		gun.nextBulletTime = 0.0
		gun.try_shoot(plain.go.global_position, plain)
	await seconds(10.0)
	check(not U.alive(plain.structure), "an unprotected structure is destroyed by the same shells")

	# gun health: a basic gun dies on the fourth shell, the fused gun on the eighth
	var single = map.tiles[12][20]
	p1.build_building(single, Catalog.spawn("cannon"))
	for i in 3:
		single.damage_building_place(10.0)
	check(U.alive(single.structure), "a basic gun survives three shells")
	single.damage_building_place(10.0)
	check(not U.alive(single.structure), "the fourth shell destroys a basic gun")
	var ftile = map.tiles[fspot.x + 1][fspot.y + 1]
	for i in 7:
		ftile.damage_building_place(10.0)
	check(U.alive(ftile.structure), "the fused gun survives seven shells")
	ftile.damage_building_place(10.0)
	check(not U.alive(ftile.structure), "the eighth shell destroys the fused gun")

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
