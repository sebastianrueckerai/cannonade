extends Node
## The faction walls of D78: every player's blocks wear the look of their number, a block's walkway runs from its
## centre toward the own walls beside it and no further, it follows the neighbours as they come and go, a storey
## wears the look's upper model, and a hand piece's cells show the walkways between them whichever way it turns.
##   godot --headless --fixed-fps 30 res://tests/walls_test.tscn

const Main = preload("res://scripts/Main.gd")
const WallComp = preload("res://scripts/components/Wall.gd")

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
	print("WALLS TEST PASSED" if failures.is_empty() else "WALLS TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)


func check(cond: bool, msg: String) -> void:
	print(("ok: " if cond else "FAIL: ") + msg)
	if not cond:
		failures.append(msg)


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
	check(_look(a) == "wall", "player 1's block wears the plain look (got %s)" % _look(a))
	check(_look(b) == "wall_corbel", "player 2's block wears the corbel look (got %s)" % _look(b))
	var bare := Catalog.spawn("wall")
	check(_look(bare) == "wall", "a block spawned without an owner wears the first look")
	p2.build_wall(_tile(12, 5), bare)
	check(_look(bare) == "wall_corbel", "built by player 2, the ownerless block changes into the corbel look")
	check(Catalog.wall_look(game.players[0]) == "wall" and Catalog.WALL_LOOKS.size() == 4,
			"four looks, one per player number")
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
	check(_look(storey) == "wall_upper", "a stacked block wears the look's storey (got %s)" % _look(storey))
	check(_open(storey, p1) == [true, true, true, false], "the storey's walkway follows the tile's neighbours (%s)" % [_open(storey, p1)])
	_tile(14, 2).un_build()
	check(_open(storey, p1) == [true, false, true, false], "the storey closes its -x corridor when that neighbour goes (%s)" % [_open(storey, p1)])
	var tile2 = _tile(10, 5)
	var storey2 := Catalog.spawn("wall", null, p2)
	U.comp(storey2, "BuildingBlock").player = p2
	tile2.stack_wall(storey2)
	check(_look(storey2) == "wall_corbel_upper", "player 2's storey is the corbel storey (got %s)" % _look(storey2))


func _check_piece() -> void:
	var piece := Catalog.spawn("wall_3", p1.wallSpawn, p1)
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
	check(_look(cells[0]) == "wall", "the cells wear the owner's look")
	var piece2 := Catalog.spawn("wall_3", p2.wallSpawn, p2)
	check(_look(piece2.get_children().filter(func(n): return n is Node3D)[0]) == "wall_corbel",
			"player 2's piece shows the corbel look")
	piece.free()
	piece2.free()


## A closed ring tints the ground it encloses toward its owner's colour; open it and the mud comes back.
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
	check(inside.ringOwner == p1 and U.get_color(inside.model()).is_equal_approx(mud.lerp(p1.mainColor, 0.25)),
			"one enemy block in the ring: the ground still follows the majority, player 1")
	# the corners border no inside tile: six blocks count, and three more of player 2's make four of six
	for c in [[24, 2], [22, 3], [25, 3]]:
		_tile(c[0], c[1]).un_build()
		_build(p2, c[0], c[1])
	check(inside.ringOwner == p2 and U.get_color(inside.model()).is_equal_approx(mud.lerp(p2.mainColor, 0.25)),
			"with most of the bordering blocks player 2's, the ground turns to player 2's colour")
	inside.reset_color()
	check(U.get_color(inside.model()).is_equal_approx(mud.lerp(p2.mainColor, 0.25)),
			"a plain recolour of the tile keeps its ring owner's tint")
	_tile(25, 3).un_build()
	_build(p1, 25, 3)
	check(inside.ringOwner == p1, "three blocks each: the tie goes to the lower player number")
