extends Node
## The faction walls of D78 and D81: every game deals each player another look and a player's blocks wear it, a
## block's walkway runs from its
## centre toward the own walls beside it and no further, it follows the neighbours as they come and go, a storey
## wears the look's upper model, and a hand piece's cells show the walkways between them whichever way it turns.
##   godot --headless --fixed-fps 30 res://tests/walls_test.tscn

const Main = preload("res://scripts/Main.gd")
const WallComp = preload("res://scripts/components/Wall.gd")
const Ring = preload("res://tests/ring.gd")

var main: Node
var game
var map
var p1
var p2
var failures: Array = []


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	Main.requested_mode = "versus"
	Main.requested_args = {"seed": "7", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	game = main.game
	map = game.map
	p1 = game.players[0]
	p2 = game.players[1]
	p2.nextAction = 1e9
	_check_looks()
	_check_walkways()
	_check_storey()
	_check_piece()
	_check_ground()
	await _check_crumble()
	_check_connect()
	await _check_deal()
	print("WALLS TEST PASSED" if failures.is_empty() else "WALLS TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)


func seconds(t: float) -> void:
	var end: float = U.time + t
	while U.time < end:
		await get_tree().process_frame


func check(cond: bool, msg: String) -> void:
	print(("ok: " if cond else "FAIL: ") + msg)
	if not cond:
		failures.append(msg)


## I105: a held piece stands only edge on an own wall, a bridge or an own castle tile, never apart with
## a gap. The held piece is the single block, so the anchor tile is the piece.
func _check_connect() -> void:
	U.destroy(p1.nextWall)
	p1.nextWall = Catalog.spawn(Catalog.get_def("wall_1"), p1.hand)
	var own_beside := func(t) -> bool:
		for q in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n = map.tiles[t.idxX + q.x][t.idxZ + q.y]
			if n.isWall and map.get_mini(n.idxX, n.idxZ) == p1.playerID:
				return true
		return false
	var c = map.castles.filter(func(k): return U.alive(k) and k.owner() == p1)[0]
	var cc: Vector2i = map.tile_index_at(c.go.global_position)
	var near_tile = null
	var far_tile = null
	var diag_tile = null
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var t1 = map.tiles[cc.x + 3 * d.x][cc.y + 3 * d.y]
		var t2 = map.tiles[cc.x + 4 * d.x][cc.y + 4 * d.y]
		var p := Vector2i(d.y, d.x)
		var t3 = map.tiles[cc.x + 3 * d.x + 3 * p.x][cc.y + 3 * d.y + 3 * p.y]
		if t1.is_free() and own_beside.call(t1) and t2.is_free() and not own_beside.call(t2) \
				and t3.is_free() and not own_beside.call(t3):
			near_tile = t1
			far_tile = t2
			diag_tile = t3
			break
	check(near_tile != null, "a clear line runs out from the start ring for the connect check")
	if near_tile == null:
		return
	check(p1.can_place_piece(near_tile), "a wall stands on a tile edge on an own wall")
	check(not p1.can_place_piece(far_tile), "two tiles out with no wall beside it is a gap and stands no wall")
	check(not p1.can_place_piece(diag_tile), "a corner touch connects nothing")
	near_tile.water = true
	near_tile.river = true
	check(p1.can_place_piece(near_tile), "a river tile edge on an own wall takes a bridge")
	near_tile.river = false
	near_tile.water = false
	var e = map.castles.filter(func(k): return U.alive(k) and k.owner() == p2)[0]
	var ec: Vector2i = map.tile_index_at(e.go.global_position)
	var enemy_side = null
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var t1 = map.tiles[ec.x + 3 * d.x][ec.y + 3 * d.y]
		if t1.is_free() and not own_beside.call(t1):
			enemy_side = t1
			break
	check(enemy_side != null and not p1.can_place_piece(enemy_side), "a tile edge on the enemy's wall alone stands no own wall")
	_build(p1, near_tile.idxX, near_tile.idxZ)
	check(p1.can_place_piece(far_tile), "a wall on the gap tile lets the line go on")


## A free, dry, decoration-free tile well away from both castles' rings: the human's rows go at z 2, the AI's at z 5.
func _tile(x: int, z: int):
	return map.tiles[x][z]


func _build(p, x: int, z: int) -> Node3D:
	var go := Catalog.spawn("wall", null, p)
	p.build_wall(_tile(x, z), go)
	return go


func _look(go: Node3D) -> String:
	return go.get_node("Art").get_meta("art_id")


func _colors(go: Node3D) -> PackedColorArray:
	return WallComp.material(go.get_node_or_null("Art")).get_shader_parameter("colors")


func _walk(p) -> Color:
	return WallComp.STONE.lerp(p.mainColor, WallComp.walk_tint)


## Which of the four corridors (px, nx, py, ny) wear the walkway colour, their cap with them and their mid-side
## stud dropped (alpha 0); a closed corridor keeps its stud.
func _open(go: Node3D, p) -> Array:
	var c := _colors(go)
	var w := _walk(p)
	var out: Array = []
	for r in [2, 3, 4, 5]:
		var is_open := c[r].is_equal_approx(w) and c[r + WallComp.CAP].is_equal_approx(w)
		var stud_gone: bool = c[r + WallComp.STUD].a < 0.5
		out.append(is_open)
		if is_open != stud_gone:
			check(false, "corridor %d open %s but its stud gone %s" % [r, is_open, stud_gone])
	return out


func _check_looks() -> void:
	var a := _build(p1, 10, 2)
	var b := _build(p2, 10, 5)
	check(p1.wallLook in Catalog.WALL_LOOKS and p2.wallLook in Catalog.WALL_LOOKS and p1.wallLook != p2.wallLook,
			"the game dealt both players a look of the four, not the same one (%s, %s)" % [p1.wallLook, p2.wallLook])
	check(_look(a) == p1.wallLook, "player 1's block wears player 1's look (got %s)" % _look(a))
	check(_look(b) == p2.wallLook, "player 2's block wears player 2's look (got %s)" % _look(b))
	var bare := Catalog.spawn("wall")
	check(_look(bare) == "wall", "a block spawned without an owner wears the first look")
	var bare_spot := _dry_near(12, 5, [])  # on a river tile it would wear the bridge look instead
	p2.build_wall(_tile(bare_spot.x, bare_spot.y), bare)
	check(_look(bare) == p2.wallLook, "built by player 2, the ownerless block changes into player 2's look")
	check(Catalog.WALL_LOOKS.size() == 4, "four looks")
	for go in [a, b, bare]:
		var c := _colors(go)
		var p = U.comp(go, "BuildingBlock").player
		check(c[0] == Color.WHITE and c[10] == WallComp.STONE and c[WallComp.BAND] == Color.WHITE,
				"the body, the merlons, the deck corners and the band stay stone on %s" % _look(go))
		check(c[WallComp.RIM] == WallComp.STONE, "the rim round the deck stays stone on %s (D79)" % _look(go))


func _check_walkways() -> void:
	var lone := _build(p1, 20, 2)
	check(_colors(lone)[WallComp.CENTRE].is_equal_approx(_walk(p1)) and _open(lone, p1) == [false, false, false, false],
			"a lone block colours only its centre square (%s)" % [_open(lone, p1)])
	var left := _build(p1, 14, 2)
	var mid := _build(p1, 15, 2)
	var right := _build(p1, 16, 2)
	check(_open(mid, p1) == [true, true, false, false], "the middle of a row opens its +x and -x corridors (%s)" % [_open(mid, p1)])
	check(_open(left, p1) == [true, false, false, false] and _open(right, p1) == [false, true, false, false],
			"the ends of the row open the one corridor toward the middle (%s %s)" % [_open(left, p1), _open(right, p1)])
	var up := _build(p1, 15, 3)
	check(_open(mid, p1) == [true, true, true, false] and _open(up, p1) == [false, false, false, true],
			"a block on tile z + 1 opens the middle's py corridor and its own ny (%s %s)" % [_open(mid, p1), _open(up, p1)])
	var enemy := _build(p2, 17, 2)
	check(_open(right, p1) == [false, true, false, false] and _open(enemy, p2) == [false, false, false, false],
			"an enemy block beside the row opens no corridor on either side (%s %s)" % [_open(right, p1), _open(enemy, p2)])
	_tile(15, 2).un_build()
	check(_open(left, p1) == [false, false, false, false] and _open(right, p1) == [false, false, false, false]
			and _open(up, p1) == [false, false, false, false],
			"with the middle gone its three neighbours close their corridors (%s %s %s)" % [_open(left, p1), _open(right, p1), _open(up, p1)])
	var again := _build(p1, 15, 2)
	check(_open(again, p1) == [true, true, true, false] and _open(left, p1) == [true, false, false, false],
			"a block built back into the gap opens the corridors again (%s %s)" % [_open(again, p1), _open(left, p1)])


func _check_storey() -> void:
	var tile = _tile(15, 2)
	var storey := Catalog.spawn("wall", null, p1)
	U.comp(storey, "BuildingBlock").player = p1
	tile.stack_wall(storey)
	check(_look(storey) == p1.wallLook + "_upper", "a stacked block wears the look's storey (got %s)" % _look(storey))
	check(_open(storey, p1) == [true, true, true, false], "the storey's walkway follows the tile's neighbours (%s)" % [_open(storey, p1)])
	_tile(14, 2).un_build()
	check(_open(storey, p1) == [true, false, true, false], "the storey closes its -x corridor when that neighbour goes (%s)" % [_open(storey, p1)])
	var tile2 = _tile(10, 5)
	var storey2 := Catalog.spawn("wall", null, p2)
	U.comp(storey2, "BuildingBlock").player = p2
	tile2.stack_wall(storey2)
	check(_look(storey2) == p2.wallLook + "_upper", "player 2's storey is player 2's look's storey (got %s)" % _look(storey2))


func _check_piece() -> void:
	var piece := Catalog.spawn("wall_3", p1.hand, p1)
	var cells: Array = piece.get_children().filter(func(n): return n is Node3D)
	check(cells.size() == 3, "the three-in-a-row piece shows three blocks")
	var want := [[true, false, false, false], [true, true, false, false], [false, true, false, false]]
	var got: Array = cells.map(func(c): return _open(c, p1))
	check(got == want, "the piece's cells show the walkway running through them (%s)" % [got])
	U.comp(piece, "BuildingBlock").rotate_clockwise()
	got = cells.map(func(c): return _open(c, p1))
	check(got == want, "turned, the cells keep their corridors in the piece's own frame (%s)" % [got])
	WallComp.paint_piece(piece, p1, U.comp(piece, "Structure").def.piece, 0.7)
	var shade: float = WallComp.material(cells[1].get_node("Art")).get_shader_parameter("shade")
	check(shade == 0.7 and cells.map(func(c): return _open(c, p1)) == want,
			"shading the piece keeps its corridors (shade %s)" % shade)
	check(_look(cells[0]) == p1.wallLook, "the cells wear the owner's look")
	var piece2 := Catalog.spawn("wall_3", p2.hand, p2)
	check(_look(piece2.get_children().filter(func(n): return n is Node3D)[0]) == p2.wallLook,
			"player 2's piece shows player 2's look")
	piece.free()
	piece2.free()


## A closed ring tints the ground it encloses toward its owner's colour; a ring two factions
## share encircles nothing (I73), and opened the mud comes back.
func _check_ground() -> void:
	var inside = _tile(23, 3)
	var mud: Color = inside.enclosedColor
	check(inside.ringOwner == null and U.get_color(inside.model()) == inside.openColor, "open ground wears the open colour")
	for c in [[22, 2], [23, 2], [24, 2], [25, 2], [22, 3], [25, 3], [22, 4], [23, 4], [24, 4], [25, 4]]:
		_build(p1, c[0], c[1])
	check(inside.ringOwner == p1 and map.is_tile_enclosed(23, 3), "the 4 x 2 ring's inside belongs to player 1's ring")
	check(U.get_color(inside.model()).is_equal_approx(mud.lerp(p1.mainColor, 0.25)),
			"the enclosed ground is the mud lerped 0.25 toward player 1's colour")
	_tile(23, 2).un_build()
	check(inside.ringOwner == null and U.get_color(inside.model()) == inside.openColor,
			"with the ring opened the ground is open mud again")
	_build(p2, 23, 2)
	check(inside.ringOwner == null and not map.is_tile_enclosed(23, 3) and U.get_color(inside.model()) == inside.openColor,
			"a ring one block of which is the enemy's encircles nothing: the room stays open")
	_tile(23, 2).un_build()
	_build(p1, 23, 2)
	check(inside.ringOwner == p1 and map.is_tile_enclosed(23, 3) \
			and U.get_color(inside.model()).is_equal_approx(mud.lerp(p1.mainColor, 0.25)),
			"the ring all player 1's once more: the ground and its colour return")
	_check_nested_rings()


## An outer ring of one faction round a smaller ring of another still holds the ground between
## the two: that faction's walls encircle it alone. One swapped outer block and exactly the
## annulus opens; the inner ring's heart stays the inner faction's.
func _check_nested_rings() -> void:
	var q: Vector2i = Ring.free_rect(map, 6, 5)
	check(q.x >= 0, "a free 6 x 5 rectangle exists for the nested rings")
	for x in range(q.x, q.x + 6):
		for z in range(q.y, q.y + 5):
			if x != q.x and x != q.x + 5 and z != q.y and z != q.y + 4:
				continue
			_build(p1, x, z)
	for x in range(q.x + 1, q.x + 4):
		for z in range(q.y + 1, q.y + 4):
			if x == q.x + 2 and z == q.y + 2:
				continue
			_build(p2, x, z)
	var between = _tile(q.x + 4, q.y + 2)
	var heart = _tile(q.x + 2, q.y + 2)
	check(between.ringOwner == p1 and map.is_tile_enclosed(q.x + 4, q.y + 2),
			"the outer ring round the inner one holds the ground between for its own faction")
	check(heart.ringOwner == p2 and map.is_tile_enclosed(q.x + 2, q.y + 2),
			"the inner ring's heart is the inner faction's")
	_tile(q.x + 5, q.y + 2).un_build()
	_build(p2, q.x + 5, q.y + 2)
	check(between.ringOwner == null and not map.is_tile_enclosed(q.x + 4, q.y + 2),
			"one outer block now the enemy's: no faction encircles the annulus alone, it is open")
	check(heart.ringOwner == p2 and map.is_tile_enclosed(q.x + 2, q.y + 2),
			"the inner ring still pure: its heart stays the inner faction's")


## The deal: five art seeds give five permutations of the four looks, not all alike, and a four-player game hands
## them out, every player another. The versus game's AI is idle, so freeing it resumes no coroutine.
## A wall shot down crumbles (I62): a storey alone, leaving its block, then the block; the pieces wear the block's
## material, fly away from the shot, lie on the walls and not in them, stay on the slab and are gone after Crumble.LIFE.
## A cannon, the castle falling to ruins and the decorations of a tile shot or built on crumble too (I69); the castle's
## pieces lie on its ruin and not fallen through it (I66).
func _check_crumble() -> void:
	Art._rng.seed = 11
	var gun_spot := _dry_near(17, 0, [])
	var shot_spot := _dry_near(31, 2, [[33, 2]])
	var used := [[19, 0], [20, 0], [gun_spot.x, gun_spot.y], [shot_spot.x, shot_spot.y], [33, 2],
			[44, 1], [45, 1], [46, 1], [44, 2], [45, 2], [46, 2], [44, 3], [45, 3], [46, 3]]
	var free: Array = used.filter(func(c): return not _tile(c[0], c[1]).water and not U.alive(_tile(c[0], c[1]).structure))
	check(free.size() == used.size(), "the crumble checks' %d tiles are free and dry (taken or wet: %s)"
			% [used.size(), used.filter(func(c): return not free.has(c))])
	var tile = _tile(19, 0)
	var east_tile = _tile(20, 0)
	var block := Catalog.spawn("wall", null, p1)
	p1.build_wall(tile, block)
	p1.build_wall(east_tile, Catalog.spawn("wall", null, p1))
	var storey := Catalog.spawn("wall", null, p1)
	tile.stack_wall(storey)
	var m := WallComp.material(storey.get_node("Art"))
	var from: Vector3 = tile.go.global_position + Vector3(-6, 0.5, 0)
	tile.damage_building_place(100.0, from)
	var heaps: Array = tile.go.get_children().filter(func(n): return n is Crumble)
	check(heaps.size() == 1 and U.alive(tile.structure) and not U.alive(tile.wallStacked),
			"a shot storey crumbles and leaves its block (%d heaps)" % heaps.size())
	var pieces: Array = heaps[0].get_children().filter(func(n): return n is RigidBody3D) if not heaps.is_empty() else []
	check(pieces.size() >= 10, "the storey breaks into %d pieces (want 10 or more)" % pieces.size())
	check(not pieces.is_empty() and pieces.all(func(b): return b.get_child(0).material_override == m),
			"the pieces wear the storey's material")
	await seconds(1.5)
	var east: int = pieces.filter(func(b): return b.global_position.x > tile.go.global_position.x).size()
	check(east > pieces.size() / 2, "the pieces fly away from the shot (%d of %d east of the tile)" % [east, pieces.size()])
	var inside := 0
	for t in [tile, east_tile]:
		var box := AABB(t.go.global_position + Vector3(-0.5, Art.SLAB_TOP, -0.5), Vector3(1, 1, 1))
		inside += pieces.filter(func(b): return box.has_point(b.global_position)).size()
	check(inside == 0, "the pieces lie on the walls, none inside one (%d inside)" % inside)
	tile.damage_building_place(100.0, from)
	heaps = tile.go.get_children().filter(func(n): return n is Crumble)
	check(heaps.size() == 2 and not U.alive(tile.structure), "the shot block crumbles too (%d heaps)" % heaps.size())
	await seconds(1.5)
	var slab: float = tile.go.global_position.y + Art.SLAB_TOP
	for heap in heaps:
		var low := INF  # the lowest vertex of any piece; the collision is the mesh shrunk 0.95 about its origin
		for b in heap.get_children():
			if b is RigidBody3D:
				var mi: MeshInstance3D = b.get_child(0)
				for v in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					low = minf(low, mi.to_global(v).y - slab)
		check(low > -0.1, "no piece of the heap sinks through the slab (lowest vertex %.2f m over it)" % low)
	# a cannon: its mount's pieces in the mount's material, its barrel's where the barrel stands
	var gun_tile = _tile(gun_spot.x, gun_spot.y)
	var gun := Catalog.spawn("cannon")
	var gun_look: String = gun.get_node("Art").get_meta("art_look", "cannon")
	p1.build_building(gun_tile, gun)
	var mount_mat: Material = (gun.find_child("mount", true, false) as MeshInstance3D).get_active_material(0)
	var barrel_pos: Vector3 = (gun.find_child("barrel", true, false) as Node3D).global_position
	gun_tile.damage_building_place(1e6, from)
	var gun_heaps: Array = gun_tile.go.get_children().filter(func(n): return n is Crumble)
	check(gun_heaps.size() == 1 and not U.alive(gun_tile.structure), "a shot cannon crumbles (%d heaps)" % gun_heaps.size())
	check(Crumble.rubble_id(gun_look) == "cannon_rubble" and Crumble.rubble_id("castle_d3.3") == "castle_d3.3_rubble",
			"a look without its own rubble wears its base look's (%s), a castle its own" % gun_look)
	var mount_pieces: Array = gun_heaps[0].get_children().filter(func(n): return n.name.begins_with("mount")) if gun_heaps else []
	var barrel_pieces: Array = gun_heaps[0].get_children().filter(func(n): return n.name.begins_with("barrel")) if gun_heaps else []
	check(mount_pieces.size() >= 5 and barrel_pieces.size() >= 3,
			"its mount and barrel break into %d and %d pieces" % [mount_pieces.size(), barrel_pieces.size()])
	check(not mount_pieces.is_empty() and mount_pieces.all(func(b): return b.get_child(0).material_override == mount_mat),
			"the mount's pieces wear the mount's material")
	var far: float = barrel_pieces.map(func(b): return b.global_position.distance_to(barrel_pos)).max() if barrel_pieces else INF
	check(far < 0.4, "the barrel's pieces start at the barrel (the farthest %.2f m from it)" % far)
	# a neutral castle falls to ruins in pieces; a side's last castle would end the game (I65)
	var castle = map.castles.filter(func(c): return not c.is_ruin() and c.owner() == null)[0]
	var ci: Vector2i = map.tile_index_at(castle.go.global_position)
	var ctile = map.tiles[ci.x][ci.y]
	ctile.damage_building_place(1e6, from)
	var castle_heaps: Array = ctile.go.get_children().filter(func(n): return n is Crumble)
	var stones: Array = castle_heaps[0].get_children().filter(func(n): return n is RigidBody3D) if castle_heaps else []
	check(castle.is_ruin() and castle_heaps.size() == 1 and stones.size() >= 20,
			"the castle falls to ruins in %d pieces (%d heaps)" % [stones.size(), castle_heaps.size()])
	var d3 := load(Art.model_path(castle.state_model(3))).instantiate() as Node3D
	var d3_mats: Array = []
	for mi in d3.find_children("*", "MeshInstance3D", true, false):
		var mm: Material = (mi as MeshInstance3D).get_active_material(0)
		if mm != null and not d3_mats.has(mm):
			d3_mats.append(mm)
	var stone := 0
	for b in stones:
		stone += 1 if d3_mats.has(b.get_child(0).material_override) else 0
	check(not stones.is_empty() and stone == stones.size(),
			"the castle's pieces wear the severe look's materials (%d of %d)" % [stone, stones.size()])
	d3.free()
	# the ruin catches the pieces from above on its slab (I66); the pieces born under the slab
	# fall to the floor, hidden in the ruin
	var rb: Array = castle.go.find_children("RuinBody", "", true, false)
	var body: StaticBody3D = rb[0] if rb.size() == 1 else null
	check(body != null, "the ruin carries its catch body (I66)")
	var top := 0.0
	if body != null:
		var box := (body.get_child(0) as CollisionShape3D).shape as BoxShape3D
		top = body.global_position.y + box.size.y * 0.5
	var start := stones.map(func(b): return b.global_position.y)
	var rbb: AABB = castle.bounds()
	await seconds(1.5)
	var deep := 0
	for i in stones.size():
		var p: Vector3 = stones[i].global_position
		if start[i] > top and p.y < top - 0.1 and rbb.position.x < p.x and p.x < rbb.end.x and rbb.position.z < p.z and p.z < rbb.end.z:
			deep += 1
	check(deep == 0, "the pieces from above lie on the ruin, none fallen through it (%d deep)" % deep)
	# a shot clears a decorated tile, and a wall placed on decorations clears another, each decoration in pieces
	var shot_tile = _tile(shot_spot.x, shot_spot.y)
	var walled_tile = _tile(33, 2)
	var ringed_tile = _tile(45, 2)
	for t in [shot_tile, walled_tile, ringed_tile]:
		_decorate(t)
	check([shot_tile, walled_tile, ringed_tile].all(func(t): return t.decorations.size() == 2), "three tiles got two leaf trees each")
	shot_tile.damage_building_place(1.0, from)
	heaps = shot_tile.go.get_children().filter(func(n): return n is Crumble)
	check(shot_tile.decorations.is_empty() and heaps.size() == 2,
			"a shot clears the tile's 2 trees, each in pieces (%d heaps)" % heaps.size())
	p1.build_wall(walled_tile, Catalog.spawn("wall", null, p1))
	heaps = walled_tile.go.get_children().filter(func(n): return n is Crumble)
	check(walled_tile.decorations.is_empty() and heaps.size() == 2 and U.alive(walled_tile.structure),
			"a wall placed on 2 trees crumbles them (%d heaps)" % heaps.size())
	for c in [[44, 1], [45, 1], [46, 1], [44, 2], [46, 2], [44, 3], [45, 3], [46, 3]]:
		_build(p1, c[0], c[1])
	heaps = ringed_tile.go.get_children().filter(func(n): return n is Crumble)
	check(map.is_tile_enclosed(45, 2) and ringed_tile.decorations.is_empty() and heaps.is_empty(),
			"a ring closing round 2 trees clears them quietly (%d heaps)" % heaps.size())
	await seconds(Crumble.LIFE + 0.3)
	var left := 0
	for t in [tile, gun_tile, ctile, shot_tile, walled_tile]:
		left += t.go.get_children().filter(func(n): return n is Crumble).size()
	check(left == 0, "the rubble is gone after %.0f s (%d heaps left)" % [Crumble.LIFE, left])


## The first free dry tile east of (x, z) in its row, skipping `avoid`: the river and the
## terrain seated round it move with the board, so these crumble spots cannot stay fixed.
func _dry_near(x: int, z: int, avoid: Array) -> Vector2i:
	for e in range(x, map.sizeX):
		var t = map.tiles[e][z]
		if not t.water and not U.alive(t.structure) and not t.disabled and not avoid.has([e, z]):
			return Vector2i(e, z)
	return Vector2i(x, z)


## Two leaf trees of the art layer on `t`, by hand: the test's game has no decorations.
func _decorate(t) -> void:
	var maker: Node3D = U.instantiate(preload("res://prefabs/Maker_LeafTree.tscn"), main)
	for i in 2:
		var deco: Node3D = U.comp(maker, "CustomModelMaker").get_randomized_model(t.go)
		deco.position = Vector3(0.25 * i - 0.125, Art.SLAB_TOP, 0.0)
		t.decorations.append(deco)


func _check_deal() -> void:
	var deals: Array = []
	for seed in [1, 2, 3, 4, 5]:
		Art._rng.seed = seed
		var looks: Array = Catalog.deal_wall_looks()
		var distinct := {}
		for l in looks:
			distinct[l] = true
		check(distinct.size() == 4 and looks.size() == 4 and looks.all(func(l): return l in Catalog.WALL_LOOKS),
				"a deal is the four looks in some order (%s)" % [looks])
		deals.append(looks)
	check(deals.any(func(d): return d != deals[0]), "the deal differs between games (%s)" % [deals])
	main.free()
	await get_tree().process_frame
	Main.requested_mode = "ai4"
	Main.requested_args = {"seed": "3", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	var dealt: Array = main.game.players.map(func(p): return p.wallLook)
	var seen := {}
	for l in dealt:
		seen[l] = true
	check(seen.size() == 4 and dealt.all(func(l): return l in Catalog.WALL_LOOKS),
			"four players, four different looks of the four (%s)" % [dealt])
