extends Node
## Tests the special structures directly: cluster bomb cannon, rocket station,
## flak and shield generator, plus ships being sunk.
##   godot --headless --fixed-fps 30 res://tests/weapons.tscn

const Main = preload("res://scripts/Main.gd")

var main: Node
var game
var map
var p1
var p2
var failures: Array = []
var checks := 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("ok: ", msg)
	else:
		failures.append(msg)
		printerr("FAIL: ", msg)


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
		p.nextAction = 1e9  # scripted test: AIs stay idle
	await _run()
	print("checks=%d failures=%d" % [checks, failures.size()])
	print("WEAPONS TEST PASSED" if failures.is_empty() else "WEAPONS TEST FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)


## Builds an upgrade structure for player p covering the square at (x, z).
func place_structure(p, scene: PackedScene, x: int, z: int, side: int) -> Node3D:
	var tiles: Array = []
	for dx in side:
		for dz in side:
			var t = map.tiles[x + dx][z + dz]
			if U.alive(t.structure):
				t.un_build()
			tiles.append(t)
	var s := U.instantiate(scene)
	var main_tile = tiles[tiles.size() / 2]
	for t in tiles:
		if t != main_tile:
			t.structure = s
			t.player = p
			map.set_mini(t.idxX, t.idxZ, p.playerID)
	p.build_building(main_tile, s)
	var cx := 0.0
	var cz := 0.0
	for t in tiles:
		cx += t.go.global_position.x
		cz += t.go.global_position.z
	s.global_position = Vector3(cx / tiles.size(), 0, cz / tiles.size())
	return s


func target_wall(_p):
	return map.tiles[b2_xz.x][b2_xz.y - 1]


var b1_xz: Vector2i
var b2_xz: Vector2i


func _run() -> void:
	b1_xz = Vector2i(p1.startBase.buildingPlace.idxX, p1.startBase.buildingPlace.idxZ)
	b2_xz = Vector2i(p2.startBase.buildingPlace.idxX, p2.startBase.buildingPlace.idxZ)
	await seconds(0.2)
	game.buildingAllowed = false
	game.shootingAllowed = true
	game.timeLeftInRound = 1e6

	# --- cluster bomb (Cannon22b) releases burning, stunning sub munitions
	var b1 = map.tiles[b1_xz.x][b1_xz.y]
	var cb := place_structure(p1, preload("res://prefabs/Cannon22b.tscn"), b1.idxX + 3, b1.idxZ, 2)
	var shooter := U.comp(cb, "Shooter")
	check(shooter != null and shooter.projectilePrefab.resource_path.ends_with("ClusterBomb.tscn"), "Cannon22b shoots cluster bombs")
	var tgt = target_wall(p2)
	check(shooter.try_shoot(tgt.go.global_position, tgt), "cluster bomb fired")
	var saw_sub := false
	var saw_fire := false
	var end: float = U.time + 15.0
	while U.time < end:
		await get_tree().process_frame
		for pr in U.projectiles:
			if pr.get_script().resource_path.ends_with("ProjectileStraightFlight.gd"):
				saw_sub = true
		for t in tgt.get_surrounding_tiles(3):
			if t.burning:
				saw_fire = true
		if saw_fire:
			break
	check(saw_sub, "cluster bomb released sub munitions")
	check(saw_fire, "sub munitions set tiles on fire")

	# --- rocket station disables the target tile
	var rs := place_structure(p1, preload("res://prefabs/RocketStation.tscn"), b1.idxX - 4, b1.idxZ - 1, 3)
	var launcher := U.comp(rs, "RocketLauncher")
	check(launcher != null, "rocket station has a launcher")
	var rt = map.tiles[b2_xz.x + 1][b2_xz.y]
	launcher.nextBulletTime = 0.0
	var fired: bool = launcher.try_shoot(rt.go.global_position, rt)
	check(fired, "rocket launched (distance %.1f)" % rs.global_position.distance_to(rt.go.global_position))
	end = U.time + 30.0
	while U.time < end and not rt.disabled:
		await get_tree().process_frame
	check(rt.disabled, "rocket hit disabled the target tile")
	check(not rt.buildable(), "disabled tile is not buildable")

	# --- flak shoots down enemy projectiles
	var b2 = map.tiles[b2_xz.x][b2_xz.y]
	var flak := place_structure(p2, preload("res://prefabs/Flak22.tscn"), b2.idxX - 1, b2.idxZ - 4, 2)
	var flak_c := U.comp(flak, "Flak")
	flak_c.switch_on_off(true)
	var gun := place_structure(p1, preload("res://prefabs/Cannon22a.tscn"), b1.idxX - 1, b1.idxZ + 3, 2)
	var gun_s := U.comp(gun, "Shooter")
	var ft = map.tiles[b2.idxX][b2.idxZ - 4]
	var shot_ids := {}
	var downed := 0
	for i in 4:
		gun_s.nextBulletTime = 0.0
		gun_s.try_shoot(ft.go.global_position, ft)
		for pr in U.projectiles:
			shot_ids[pr] = pr.player
		var e: float = U.time + 4.0
		while U.time < e:
			await get_tree().process_frame
	check(flak_c.secondsLastShot > 0.0, "flak fired at incoming projectiles (last shot at %.1f)" % flak_c.secondsLastShot)

	# --- shield generator absorbs enemy projectiles
	var sg := place_structure(p2, preload("res://prefabs/ShieldGen22.tscn"), b2.idxX + 3, b2.idxZ - 1, 2)
	var shield := U.comp(sg, "ShieldGenerator")
	shield.on = false
	shield.switch_on_off(true)
	var absorb_before: float = shield.currentDamageAbsorb
	var st = map.tiles[b2.idxX + 3][b2.idxZ]
	gun_s.nextBulletTime = 0.0
	gun_s.try_shoot(st.go.global_position, st)
	await seconds(1.0)
	var e2: float = U.time + 8.0
	var absorbed := false
	while U.time < e2:
		await get_tree().process_frame
		if shield.currentDamageAbsorb < absorb_before - 1.0 or shield.resetting:
			absorbed = true
			break
		absorb_before = maxf(absorb_before, shield.currentDamageAbsorb)
	check(absorbed, "shield absorbed an enemy projectile")

	# --- a ship can be sunk
	var water_tile = map.tiles[0][map.sizeZ - 1]
	water_tile.water = true
	var ship_go := U.instantiate(preload("res://prefabs/Ship.tscn"), game.fleet.go)
	ship_go.global_position = water_tile.go.global_position
	var ship := U.comp(ship_go, "Ship")
	game.fleet.ships.append(ship)
	ship.set_sail(game.fleet, map, water_tile)
	water_tile.damage_building_place(5.0)
	check(U.alive(ship_go) and ship.health == 5.0, "ship damaged")
	water_tile.damage_building_place(10.0)
	check(not U.alive(ship_go) and not game.fleet.ships.has(ship), "ship sunk")
