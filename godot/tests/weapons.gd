extends Node
## Upgrade patterns and the special structures they produce, built from upgrade
## blocks through the real merge path (UpgradeCluster + UpgradeSelection):
## patterns -> structure, cluster bombs, rockets, shield, flak, ships.
##   godot --headless --fixed-fps 30 res://tests/weapons.tscn

const Main = preload("res://scripts/Main.gd")
const BLOCKS := [preload("res://prefabs/Upgrade_a.tscn"), preload("res://prefabs/Upgrade_b.tscn")]

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
		p.build_building(t, BLOCKS[types[i]].instantiate())
	return map.tiles[x + 1][z + 1].structure


func _run() -> void:
	await seconds(0.2)
	game.buildingAllowed = false
	game.shootingAllowed = true
	game.timeLeftInRound = 1e6

	# upgrade patterns -> structures (a = 0, b = 1); flak and shield patterns are rotated
	var cases := [
		[[0, 0, 0, 0], "Cannon22a"], [[1, 1, 1, 1], "Cannon22b"], [[0, 1, 1, 1], "Flak22"],
		[[1, 0, 0, 0], "ShieldGen22"], [[1, 1, 1, 1, 1, 1, 0, 0, 0], "RocketStation"]]
	var spots := [Vector2i(13, 10), Vector2i(24, 9), Vector2i(23, 19), Vector2i(5, 19), Vector2i(3, 8)]
	var owners := [p1, p1, p2, p2, p1]
	var built := {}
	for i in cases.size():
		var s := build_pattern(owners[i], spots[i].x, spots[i].y, cases[i][0])
		var name: String = s.scene_file_path.get_file().get_basename() if U.alive(s) else "nothing"
		check(name == cases[i][1], "pattern %s merges into %s (got %s)" % [cases[i][0], cases[i][1], name])
		built[cases[i][1]] = s

	# cluster bomb: sub munitions set the tiles around the target on fire
	var target = map.tiles[15][22]
	var cluster := U.shooter(built["Cannon22b"])
	check(cluster.try_shoot(target.go.global_position, target), "Cannon22b fires")
	var burning := false
	var end: float = U.time + 15.0
	while U.time < end and not burning:
		await get_tree().process_frame
		for t in target.get_surrounding_tiles(3):
			burning = burning or (t.burning and not t.buildable())
	check(burning, "cluster bomb sets tiles on fire (not buildable while burning)")

	# rocket: the hit tile is destroyed for good
	var rt = map.tiles[15][26]  # out of reach of the flak and the shield
	var launcher := U.shooter(built["RocketStation"])
	launcher.nextBulletTime = 0.0  # skip the initial reload delay
	check(launcher.try_shoot(rt.go.global_position, rt), "rocket station fires")
	end = U.time + 30.0
	while U.time < end and rt.buildable():
		await get_tree().process_frame
	check(not rt.buildable(), "rocket hit makes the tile unbuildable")

	# shield and flak protect their own structure against an enemy shell
	var gun := U.shooter(built["Cannon22a"])
	for name in ["ShieldGen22", "Flak22"]:
		var s: Node3D = built[name]
		var tile = U.comp(s, "BuildingBlock").buildingPlace
		gun.nextBulletTime = 0.0
		check(gun.try_shoot(tile.go.global_position, tile), "shell fired at the %s" % name)
		await seconds(10.0)
		check(U.alive(s) and U.projectiles.is_empty(), "%s survives a direct hit (shell intercepted)" % name)

	# the same shell destroys an unprotected structure (control for the two checks above)
	var plain = map.tiles[15][17]
	p2.build_building(plain, preload("res://prefabs/Cannon.tscn").instantiate())
	gun.nextBulletTime = 0.0
	gun.try_shoot(plain.go.global_position, plain)
	await seconds(10.0)
	check(not U.alive(plain.structure), "an unprotected structure is destroyed by the same shell")

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
