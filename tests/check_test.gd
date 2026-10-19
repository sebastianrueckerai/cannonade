extends Node
## The rules-v3 check on a real versus map (seed fixed, enemy idle): the castle layout, the burn,
## the claim, the parts gate, castle damage states, the ruin and the game end.
##   godot --headless --fixed-fps 30 res://tests/check_test.tscn

const Main = preload("res://scripts/Main.gd")

var main: Node
var game
var map
var human
var enemy
var failures: Array = []


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)  # headless windows are 64 x 64
	Main.requested_mode = "versus"
	Main.requested_args = {"seed": "4", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	game = main.game
	map = game.map
	human = game.players[0]
	enemy = game.players[1]
	enemy.dormant = true  # keep the map static; the rules are under test, not the AI
	await _run()
	print("CHECK TEST PASSED" if failures.is_empty() else "CHECK TEST FAILED: %s" % [failures])
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


func _find_label(node, text: String) -> bool:
	if node is Label and node.text == text:
		return true
	for child in node.get_children():
		if _find_label(child, text):
			return true
	return false


func centre(c) -> Vector2i:
	return map.tile_index_at(c.go.global_position)


func neutrals() -> Array:
	var out: Array = []
	for c in map.castles:
		if U.alive(c) and not c.is_ruin() and c.owner() == null:
			out.append(c)
	return out


func ruins() -> int:
	var n := 0
	for c in map.castles:
		if U.alive(c) and c.is_ruin():
			n += 1
	return n


## Runs one check: to battle (the check fires there) and straight back to building.
func run_check() -> void:
	if not game.buildingAllowed:
		game.next_phase()
	game.next_phase()
	game.next_phase()


## Free, open (never enclosed) tiles at Chebyshev distance at least 8 from both start castles.
func open_tiles() -> Array:
	var starts := [Vector2i(15, 7), Vector2i(15, 23)]
	var out: Array = []
	for x in map.sizeX:
		for z in map.sizeZ:
			var t = map.tiles[x][z]
			if U.alive(t.structure) or t.water or t.disabled or map.is_tile_enclosed(x, z):
				continue
			var far := true
			for s in starts:
				if max(absi(x - s.x), absi(z - s.y)) < 8:
					far = false
			if far:
				out.append(Vector2i(x, z))
	return out


## A neutral castle whose whole ring (Chebyshev 2) is free and dry.
func ringable_neutral() -> Vector2i:
	for c in neutrals():
		var cc := centre(c)
		var ok := true
		for x in range(cc.x - 2, cc.x + 3):
			for z in range(cc.y - 2, cc.y + 3):
				if absi(x - cc.x) < 2 and absi(z - cc.y) < 2:
					continue
				var t = map.tiles[x][z]
				if U.alive(t.structure) or t.water or t.disabled:
					ok = false
		if ok:
			return cc
	return Vector2i(-1, -1)


func _run() -> void:
	await frames(3)
	var open := open_tiles()

	# 1: the layout
	var owned: Array = []
	for c in map.castles:
		if U.alive(c) and c.owner() != null:
			owned.append(c)
	check(map.castles.size() == 10 and owned.size() == 2 and neutrals().size() == 8,
			"ten castles: two owned, eight neutral")
	for c in owned:
		var cc := centre(c)
		check(map.is_tile_enclosed(cc.x, cc.y), "the start castle at %s is walled in" % [cc])
	for c in neutrals():
		check(map.get_mini(centre(c).x, centre(c).y) == 255, "the neutral castle at %s reads 255" % [centre(c)])
	var all: Array = map.castles.map(func(c): return centre(c))
	var min_dist := 999
	for i in all.size():
		for j in range(i + 1, all.size()):
			min_dist = mini(min_dist, max(absi(all[i].x - all[j].x), absi(all[i].y - all[j].y)))
	check(min_dist >= 5, "castle centres keep Chebyshev distance 5 (closest %d)" % [min_dist])
	check(human.partsCap == 6 and enemy.partsCap == 6, "one castle caps both players at 6 parts")

	# 2: the burn (an open gun goes, an open wall stays)
	var gun_spot: Vector2i = open[0]
	var wall_spot: Vector2i = open[1]
	human.build_building(map.tiles[gun_spot.x][gun_spot.y], Catalog.spawn("cannon"))
	human._build_from_random_prefabs(map.tiles[wall_spot.x][wall_spot.y], [true, true, false, false])
	check(human.parts_used() == 1, "the open gun costs a part")
	run_check()
	await frames(2)
	check(not U.alive(map.tiles[gun_spot.x][gun_spot.y].structure) and human.parts_used() == 0,
			"the gun outside the walls burns at the check")
	check(map.tiles[wall_spot.x][wall_spot.y].isWall, "an open wall never burns")
	check(neutrals().size() == 8 and ruins() == 0, "no neutral burns or ruins")

	# 2b: the hand follows the phase (there is nothing to place while the guns fire)
	game.next_phase()  # to battle
	check(not U.alive(human.nextWall) and not U.alive(human.nextBuilding),
			"the held pieces fly away when the battle starts")
	await frames(95)  # the fly-away (3 s) ends without drawing a new wall
	check(not U.alive(human.nextWall) and not U.alive(human.nextBuilding),
			"nothing returns to the hand while the battle runs")
	game.next_phase()  # back to building
	check(U.alive(human.nextWall), "a fresh wall is drawn when building returns")

	# 2c: a neutral castle wears brown, and it fades only while a piece previews behind it
	var neutral0 = neutrals()[0]
	var pc := centre(neutral0)
	var body_mat = U.meshes(neutral0.go)[0].get_surface_override_material(0)
	check(body_mat != null and body_mat.albedo_color.is_equal_approx(Color("#9c7a4f")),
			"an uncaptured castle wears the brown neutral, not near-white")
	var cam := get_viewport().get_camera_3d()
	var cdir: Vector3 = (neutral0.go.global_position - cam.global_position).normalized()
	var ground_t := (0.1 - cam.global_position.y) / cdir.y
	var behind: Vector3 = cam.global_position + cdir * ground_t
	check(neutral0.bounds().intersects_segment(cam.global_position, behind) != null,
			"the picked ray really passes through the castle")
	# a free tile at or past the ground point whose ray still pierces the castle
	var bpos: Vector2i = map.tile_index_at(behind)
	var hide := Vector2i(-1, -1)
	for d in range(0, 6):
		for dx in range(-d, d + 1):
			for dz in range(-d, d + 1):
				if hide.x >= 0 or maxi(absi(dx), absi(dz)) != d:
					continue
				var q := bpos + Vector2i(dx, dz)
				if q.x < 1 or q.y < 1 or q.x > map.sizeX - 2 or q.y > map.sizeZ - 2:
					continue
				var t = map.tiles[q.x][q.y]
				if U.alive(t.structure) or t.water or t.disabled:
					continue
				if neutral0.bounds().intersects_segment(cam.global_position,
						map.tile_position(q.x, q.y) + Vector3.UP * 0.1) != null:
					hide = q
	check(hide.x >= 0, "a free tile behind the castle exists")
	if hide.x >= 0:
		await seconds(0.4)  # the wall is drawn at once, the gun after its cooldown
		human.mousePosition = cam.unproject_position(
				map.tile_position(hide.x, hide.y) + Vector3.UP * 0.1)
		human.update_point_and_tile_selected()
		body_mat = U.meshes(neutral0.go)[0].get_surface_override_material(0)
		check(body_mat != null and is_equal_approx(body_mat.albedo_color.a, 0.35),
				"the castle behind the cursor piece fades out")
		check(human.nextWall.get_parent() == map.tiles[hide.x][hide.y].go
				and human.nextBuilding.get_parent() == human.buildingSpawn,
				"the wall previews on the hidden tile, the gun stays in its gui slot")
	# on the castle itself nothing previews, so nothing fades
	human.mousePosition = cam.unproject_position(
			map.tile_position(pc.x, pc.y) + Vector3.UP * 0.1)
	human.update_point_and_tile_selected()
	body_mat = U.meshes(neutral0.go)[0].get_surface_override_material(0)
	check(body_mat != null and body_mat.albedo_color.a == 1.0
			and body_mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,
			"hovering the castle itself keeps it solid")
	var clear := pc  # the farthest tile whose ray misses the castle
	for x in range(2, map.sizeX - 2):
		for z in range(2, map.sizeZ - 2):
			var q := Vector2i(x, z)
			var d: int = maxi(absi(q.x - pc.x), absi(q.y - pc.y))
			var qd: int = maxi(absi(clear.x - pc.x), absi(clear.y - pc.y))
			if d > qd and neutral0.bounds().intersects_segment(cam.global_position,
					map.tile_position(q.x, q.y) + Vector3.UP * 0.1) == null:
				clear = q
	check(maxi(absi(clear.x - pc.x), absi(clear.y - pc.y)) >= 10,
			"a far tile with a clear ray exists")
	human.mousePosition = cam.unproject_position(
			map.tile_position(clear.x, clear.y) + Vector3.UP * 0.1)
	human.update_point_and_tile_selected()
	body_mat = U.meshes(neutral0.go)[0].get_surface_override_material(0)
	check(body_mat != null and body_mat.albedo_color.a == 1.0
			and body_mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,
			"the castle turns solid again once nothing blocks")

	# 3: the claim (ring a neutral)
	var target := ringable_neutral()
	check(target.x > 0, "a neutral with room for a ring exists")
	human._wall_in(target.x - 1, target.y - 1, target.x + 1, target.y + 1)
	check(map.is_tile_enclosed(target.x, target.y), "the ring encloses the neutral castle")
	run_check()
	await frames(2)
	var claimed = null
	for c in map.castles:
		if centre(c) == target:
			claimed = c
	check(claimed != null and claimed.owner() == human, "the ringed neutral castle changes owner")
	check(map.get_mini(target.x, target.y) == human.playerID, "the mini map follows the claim")
	check(human.partsCap == 10, "two castles raise the cap to 10")

	# 4: the parts gate
	var spots: Array = open.slice(2, 14)
	var placed: Array = []
	for i in 11:
		human.nextBuilding = Catalog.spawn("cannon")
		human.build_next_building(map.tiles[spots[i].x][spots[i].y])
		if U.alive(map.tiles[spots[i].x][spots[i].y].structure):
			placed.append(spots[i])
	check(placed.size() == 10 and human.parts_used() == 10, "ten one-part guns fill the cap of 10")
	check(not U.alive(map.tiles[spots[10].x][spots[10].y].structure) and U.alive(human.nextBuilding),
			"the eleventh gun is not placed and the draw is kept")
	for i in 4:
		map.tiles[spots[0].x][spots[0].y].damage_building_place(10.0)
	check(human.parts_used() == 9, "a destroyed gun frees its part")
	human.build_next_building(map.tiles[spots[10].x][spots[10].y])
	check(U.alive(map.tiles[spots[10].x][spots[10].y].structure), "with a part free the gun is placed")
	for s in spots:
		if U.alive(map.tiles[s.x][s.y].structure):
			map.tiles[s.x][s.y].un_build()
	check(human.parts_used() == 0, "the fixture guns are cleared")

	# 8: a hit gun reloads slower
	var gun := Catalog.spawn("cannon")
	human.build_building(map.tiles[spots[0].x][spots[0].y], gun)
	var shooter := U.shooter(gun)
	check(is_equal_approx(shooter._interval(), 2.0), "a fresh gun reloads in its base interval")
	map.tiles[spots[0].x][spots[0].y].damage_building_place(10.0)
	check(is_equal_approx(shooter._interval(), 3.0), "a gun that survived a shell reloads half again slower")
	map.tiles[spots[0].x][spots[0].y].un_build()

	# 9: castle damage states on a third neutral
	var victim := ringable_neutral()
	var vc = null
	for c in map.castles:
		if centre(c) == victim:
			vc = c
	for hits in [3, 6, 9]:
		for i in 3:
			map.tiles[victim.x][victim.y].damage_building_place(10.0)
		check(vc.state == hits / 3, "%d shells show damage state d%d" % [hits, hits / 3])
	check(neutrals().size() == 7 and ruins() == 0, "a damaged neutral is neither claimed nor ruined")

	# 5: the ruin
	for i in 3:
		map.tiles[victim.x][victim.y].damage_building_place(10.0)
	check(vc.is_ruin() and U.alive(vc.go) and vc.state == 4, "twelve shells leave the d4 ruin")
	check(map.get_mini(victim.x, victim.y) == 255, "the ruin reads 255")
	check(not human.can_place(Catalog.get_def("castle"), victim.x - 1, victim.y - 1),
			"nothing can be placed on the ruin")
	human._wall_in(victim.x - 1, victim.y - 1, victim.x + 1, victim.y + 1)
	run_check()
	await frames(2)
	check(vc.is_ruin() and vc.owner() == null, "the ruin is never claimed, walled in or not")
	check(ruins() == 1 and neutrals().size() == 6, "only the shelled castle is a ruin")

	# 6: the end
	for i in 12:
		map.tiles[15][23].damage_building_place(10.0)
	check(enemy.castle_count() == 0, "the enemy holds no castle any more")
	game.next_phase()
	check(not game.started, "a player without a castle is out at the check")
	var overlay := main.get_node_or_null("GameOver")
	check(overlay != null and _find_label(overlay, "VICTORY"), "the overlay shows the victory")
