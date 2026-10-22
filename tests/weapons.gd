extends Node
## The special structures and what they do: the four-cannon fusion, cluster
## bombs, rockets, shield and flak interception, gun damage, ships. The 2x2
## specials are placed from their files; their upgrade-block recipes are parked
## out of the game.
##   godot --headless --fixed-fps 30 res://tests/weapons.tscn

const Main = preload("res://scripts/Main.gd")
const FX = preload("res://scripts/FX.gd")

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


## The first tile in a 4x4 box from (x0, z0) that is free, open and not water, with all eight
## neighbours the same, so a wall ring can close round it.
func open_patch(x0: int, z0: int):
	var ring := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	for x in range(x0, x0 + 4):
		for z in range(z0, z0 + 4):
			var t = map.tiles[x][z]
			var ok: bool = t.is_free() and not t.water and not map.is_tile_enclosed(t.idxX, t.idxZ)
			for d in ring:
				var n = map.tiles[x + d.x][z + d.y]
				ok = ok and n.is_free() and not n.water
			if ok:
				return t
	return null


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
	game.phase = game.Phase.BATTLE
	game.timeLeftInRound = 1e6
	# the scripted spots below were derived on bare ground: the generated terrain (I90) goes
	for go in map.terrain_features.duplicate():
		U.comp(go, "Terrain").die(Vector3.INF, 0.0)

	# the 2x2 specials placed directly from their files (their upgrade-block
	# recipes are parked out of the game)
	var built := {}
	# the spots are off every castle whatever the jitter: the rows between the two sides (14 to 19 on the 52 x 34
	# map) and the three rows under the castles' margin
	built["cannon22b"] = p2.place(load("res://data/buildings/cannon22b.tres"), 31, 15)
	built["flak22"] = p2.place(load("res://data/buildings/flak22.tres"), 20, 15)
	# the shield stands away from the gun's firing lines: its 7-tile radius would
	# swallow every shell the checks below fire, and the volley must land
	built["shield22"] = p2.place(load("res://data/buildings/shield22.tres"), 20, 2)
	check(built.values().all(func(s): return U.alive(s)), "the specials stand on the map")

	# four basic cannons in a square fuse into the heavy cannon
	var fspot := Vector2i(3, 18)
	for i in 4:
		p1.build_building(map.tiles[fspot.x + i / 2][fspot.y + i % 2], Catalog.spawn("cannon"))
	var fused = map.tiles[fspot.x + 1][fspot.y + 1].structure
	var fused_def := Catalog.def_of(fused) if U.alive(fused) else null
	check(fused_def != null and fused_def.id == "cannon22a",
			"four cannons in a square fuse into the heavy cannon (got %s)" % [fused_def.id if fused_def else "nothing"])
	built["cannon22a"] = fused

	# cluster bomb: sub munitions set the tiles around the target on fire; their
	# splash carries none of the heavy shell's 3x3 smoke (I101)
	var target = map.tiles[15][17]
	var cluster := U.shooter(built["cannon22b"])
	check(cluster.try_shoot(target.go.global_position, target), "cannon22b fires")
	var burning := false
	var shard_plumes := 0
	var smoked_shards := 0
	var seen := {}
	var end: float = U.time + 15.0
	while U.time < end and not (burning and shard_plumes >= 5):
		await get_tree().process_frame
		for c in U.world().get_children():
			if c.has_meta("fx") and c.get_meta("fx") == "impact" and not seen.has(c):
				seen[c] = true
				shard_plumes += 1
				smoked_shards += _smoke_tiles(c)
		for t in target.get_surrounding_tiles(3):
			burning = burning or (t.burning and not t.buildable())
	check(burning, "cluster bomb sets tiles on fire (not buildable while burning)")
	check(shard_plumes >= 5 and smoked_shards == 0,
			"the cluster's %d shard plumes stay without the 3x3 smoke" % shard_plumes)

	# rocket, from the parked rocket station placed from its file: the hit tile is destroyed for good
	var station: Node3D = p1.place(load("res://data/buildings/rocket_station.tres"), 12, 2)
	var rt = map.tiles[map.sizeX / 2][map.sizeZ - 1 - map.sizeZ / 4 + 3]  # north of the enemy ring, out of reach of the flak and the shield
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

	# the heavy shell splashes a 3x3 at twice a small shell's damage a tile, the
	# shooter's own side, enemy walls and bare ground included (I84)
	var sc = map.tiles[26][15]
	var own = map.tiles[25][15]
	var foe_wall = map.tiles[27][16]
	p1.build_building(own, Catalog.spawn("cannon"))
	p2.build_building(sc, Catalog.spawn("cannon"))
	p2.build_wall(foe_wall, Catalog.spawn("wall"))
	check(U.alive(own.structure) and U.alive(sc.structure) and U.alive(foe_wall.structure),
			"the splash patch stands: own gun, enemy gun, enemy wall")
	gun.nextBulletTime = 0.0
	check(gun.try_shoot(sc.go.global_position, sc), "the fused gun fires at the splash patch")
	var smoke_plume: Node = null
	var smoke_end: float = U.time + 15.0
	while U.time < smoke_end and smoke_plume == null:
		await get_tree().process_frame
		smoke_plume = _fx_at("impact")
	var smoked := _smoke_tiles(smoke_plume) if smoke_plume != null else -1
	check(smoked == 8, "the heavy shell's landing puffs smoke on every tile of its 3x3 (got %d of 8)" % smoked)
	await seconds(10.0)
	check(U.alive(own.structure) and U.comp(own.structure, "BuildingBlock").health == 20.0,
			"the shooter's own gun on a splash tile keeps 20 of its 40 health")
	check(U.alive(sc.structure) and U.comp(sc.structure, "BuildingBlock").health == 20.0,
			"the enemy gun on the hit tile keeps 20 of its 40 health")
	check(not U.alive(foe_wall.structure), "the 10-health wall on a splash tile dies")
	check(map.tiles[25][14].groundDamage == 20.0 and map.tiles[28][15].groundDamage == 0.0,
			"bare splash tiles scar by 20, the tile outside the 3x3 stays clean")

	# the fused gun's heavy shell hits each tile like two small cannon shells, and
	# the pointed shell flies nose first: up while it climbs, down while it falls
	p2.build_building(plain, Catalog.spawn("cannon"))
	gun.nextBulletTime = 0.0
	check(gun.try_shoot(plain.go.global_position, plain), "the fused gun fires at a basic gun")
	var heavy = U.projectiles.back()
	var meshes: Array = (heavy.get_node(heavy.body) as Node3D).find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1 and meshes[0].visible and meshes[0].mesh != null,
			"the heavy shell's model rides on the body that pitches with the arc")
	var nose_up := -1.0
	var nose_down := 1.0
	var heading := 1.0
	var last: Vector3 = heavy.go.global_position
	while U.alive(heavy):
		await get_tree().process_frame
		if not U.alive(heavy) or meshes.is_empty():
			break
		var step: Vector3 = heavy.go.global_position - last
		last = heavy.go.global_position
		var nose: Vector3 = -(meshes[0] as Node3D).global_basis.z.normalized()
		if step.y > 0.0:
			nose_up = maxf(nose_up, nose.y)
		elif step.y < 0.0:
			nose_down = minf(nose_down, nose.y)
		var flat := Vector2(step.x, step.z).normalized()
		heading = minf(heading, flat.dot(Vector2(nose.x, nose.z).normalized()))
	check(nose_up > 0.3 and nose_down < -0.3, "the nose climbs and dips with the arc (up %.2f, down %.2f)" % [nose_up, nose_down])
	check(heading > 0.9, "the nose points along the flight, not back (%.2f)" % heading)
	await seconds(0.5)
	check(U.alive(plain.structure) and U.comp(plain.structure, "BuildingBlock").health == 20.0,
			"one heavy shell halves a basic gun, a small cannon shell's worth twice")
	gun.nextBulletTime = 0.0
	check(gun.try_shoot(plain.go.global_position, plain), "the fused gun fires the second shell")
	await seconds(10.0)
	check(not U.alive(plain.structure), "two heavy shells destroy a basic gun")

	# gun health: a basic gun dies on the fourth shell, the fused gun on the eighth
	var single = map.tiles[12][14]
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
	var quad_tiles: Array = [map.tiles[fspot.x][fspot.y], map.tiles[fspot.x + 1][fspot.y],
			map.tiles[fspot.x][fspot.y + 1], map.tiles[fspot.x + 1][fspot.y + 1]]
	check(quad_tiles.all(func(t): return not U.alive(t.structure) and t.ground_stage() == 1),
			"the fused gun's killing blow scars all four freed tiles (I74)")

	# ground damage: a building soaks every hit while it stands, the killing blow then
	# scars the freed ground, bare ground takes the hits in three stages, the family
	# follows the tile's enclosure (I73, I74)
	var gt = open_patch(9, 9)
	check(gt != null, "a patch of free open ground with all its neighbours exists")
	gt.damage_building_place(10.0)
	check(gt.ground_stage() == 1 and gt._ground_look == "tile_dirt_d1",
			"the first hit on bare ground dents it (stage 1, the open family)")
	p1.build_building(gt, Catalog.spawn("cannon"))
	for i in 3:
		gt.damage_building_place(10.0)
	check(U.alive(gt.structure) and gt.ground_stage() == 0,
			"a building on the tile heals its scar and soaks the hits")
	gt.damage_building_place(10.0)
	check(not U.alive(gt.structure) and gt.ground_stage() == 1 and gt._ground_look == "tile_dirt_d1",
			"the killing blow scars the freed ground at once")
	gt.damage_building_place(15.0)
	check(gt.ground_stage() == 2 and gt._ground_look == "tile_dirt_d2", "25 damage reaches stage 2")
	gt.damage_building_place(25.0)
	check(gt.ground_stage() == 3 and gt._ground_look == "tile_dirt_d3", "50 damage reaches stage 3")
	gt.damage_building_place(30.0)
	check(gt.ground_stage() == 3, "past 50 the ground cannot look worse")
	p1.build_wall(gt, Catalog.spawn("wall"))
	check(gt.ground_stage() == 0 and gt._ground_look == "tile_mud", "building on the tile heals the ground")
	gt.un_build(true)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var n = map.tiles[gt.idxX + d.x][gt.idxZ + d.y]
		p1.build_wall(n, Catalog.spawn("wall"))
	check(map.is_tile_enclosed(gt.idxX, gt.idxZ), "the wall ring closes round the patch")
	gt.damage_building_place(10.0)
	check(gt._ground_look == "tile_mud_d1",
			"a hit on enclosed ground scars it with the enclosed family")

	# a real shell that lands on bare ground scars it
	var bare = open_patch(13, 8)
	var shooter_tile = open_patch(14, 12)
	check(bare != null and shooter_tile != null, "two more free open patches exist")
	p1.build_building(shooter_tile, Catalog.spawn("cannon"))
	var sh := U.shooter(shooter_tile.structure)
	sh.nextBulletTime = 0.0
	check(sh.try_shoot(bare.go.global_position, bare), "the shell fires at bare ground")
	var shell = U.projectiles.back()
	check(U.alive(shell) and shell.destinationTile == bare, "the shell flies at the bare tile")
	var trail = shell.go.find_child("Trail", true, false)
	check(trail is TrailLine and trail.color == Color.WHITE,
			"the shell trails its flight path behind it in white")
	for i in 6:
		await get_tree().process_frame
	if is_instance_valid(shell) and trail != null:
		check(trail.positions[0].distance_to(shell.go.global_position) < 1.0
				and trail.positions[0].distance_to(trail.positions[19]) > 1.5,
				"the trail ribbon follows the shell along its flight")
	end = U.time + 15.0
	while U.time < end and bare.ground_stage() == 0:
		await get_tree().process_frame
	check(bare.ground_stage() == 1 and bare._ground_look == "tile_dirt_d1",
			"a shell that lands on bare ground scars it")

	# water takes no ground damage
	var wtile = null
	for col in map.tiles:
		for t in col:
			if t.water and wtile == null:
				wtile = t
	if wtile != null:
		wtile.damage_building_place(30.0)
		check(wtile.ground_stage() == 0, "water takes no ground damage")

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

	# fire and impact effects: firing pops a muzzle effect at the barrel, the
	# landing raises a plume on bare ground and a splash on water, both clean
	# themselves up (I74)
	var fx_bare = open_patch(9, 14)
	check(fx_bare != null, "an fx patch of bare ground exists in the gun's reach")
	var fx_water = map.tiles[fx_bare.idxX + 1][fx_bare.idxZ]
	fx_water.water = true
	var fx_gun := U.shooter(shooter_tile.structure)
	fx_gun.nextBulletTime = 0.0
	check(fx_gun.try_shoot(fx_bare.go.global_position, fx_bare), "the fx gun fires at bare ground")
	check(_fx_at("muzzle") != null, "firing pops a muzzle effect at the barrel")
	var fx_end: float = U.time + 15.0
	var plume = null
	while U.time < fx_end and plume == null:
		await get_tree().process_frame
		plume = _fx_at("impact")
	check(plume != null, "the landing raises a plume on bare ground")
	await seconds(3.0)
	check(_fx_count() == 0, "the effects clean themselves up")
	fx_gun.nextBulletTime = 0.0
	check(fx_gun.try_shoot(fx_water.go.global_position, fx_water), "the fx gun fires at water")
	var splash = null
	fx_end = U.time + 15.0
	while U.time < fx_end and splash == null:
		await get_tree().process_frame
		splash = _fx_at("impact")
	check(splash != null, "a water landing raises a splash")
	await seconds(3.0)
	check(_fx_count() == 0, "the splash cleans itself up")


func _fx_at(kind: String) -> Node:
	for c in U.world().get_children():
		if c.has_meta("fx") and c.get_meta("fx") == kind:
			return c
	return null


func _fx_count() -> int:
	var n := 0
	for c in U.world().get_children():
		if c.has_meta("fx"):
			n += 1
	return n


## The impact point an FX root stands at: its ground ring, raised 0.06 m.
func _fx_centre(root: Node) -> Vector3:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		return (mi as Node3D).global_position - Vector3.UP * 0.06
	return Vector3.INF


## How many of the eight splash tiles round an impact hold a smoke puff.
func _smoke_tiles(root: Node) -> int:
	var centre := _fx_centre(root)
	var n := 0
	for o in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
			Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(-1, 0, -1)]:
		for p in root.find_children("*", "CPUParticles3D", true, false):
			var pp := p as CPUParticles3D
			var m := (pp.mesh as QuadMesh).material as StandardMaterial3D
			if m != null and m.albedo_texture == FX.SMOKE_DARK \
					and pp.global_position.distance_to(centre + o) < 0.4:
				n += 1
				break
	return n
