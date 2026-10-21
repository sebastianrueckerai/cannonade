extends Node
## Enclosure detection (StatesMap): walls around an area enclose it, a broken
## wall opens it again, and the optimised flood fill gives exactly the open /
## closed grids of the original algorithm for random edits.
##   godot --headless res://tests/flood_test.tscn

const Main = preload("res://scripts/Main.gd")
const StatesMap = preload("res://scripts/StatesMap.gd")
const Ring = preload("res://tests/ring.gd")
const OTHER := ["wall", "cannon"]


## The original cell by cell flood fill (Unity StatesMap.Waterflow), as reference.
class ReferenceStatesMap extends StatesMap:
	var willVisit := PackedByteArray()

	func _reset_visited_will_visit() -> void:
		super._reset_visited_will_visit()
		willVisit = _new_grid()

	func waterflow(start_x: int, start_z: int, use_initial_open := false) -> void:
		waterflow_reference(start_x, start_z, use_initial_open)

	func waterflow_reference(start_x: int, start_z: int, use_initial_open := false) -> void:
		var found_edge := false
		var queue: Array[Vector2i] = [Vector2i(start_x, start_z)]
		var head := 0
		var edge_grid := initialOpen if use_initial_open else open
		while head < queue.size():
			var xz: Vector2i = queue[head]
			head += 1
			var x := xz.x
			var z := xz.y
			visited[idx(x, z)] = 1
			for nx in range(maxi(0, x - 1), mini(sizeFineX - 1, x + 1) + 1):
				for nz in range(maxi(0, z - 1), mini(sizeFineZ - 1, z + 1) + 1):
					var ni := nx * sizeFineZ + nz
					if not found_edge and edge_grid[ni] != 0:
						found_edge = true
					if willVisit[ni] == 0 and visited[ni] == 0 and accessible[ni] != 0:
						willVisit[ni] = 1
						queue.append(Vector2i(nx, nz))
		var touched := {}
		for xz in queue:
			var i := idx(xz.x, xz.y)
			open[i] = 1 if found_edge else 0
			closed[i] = 0 if found_edge else 1
			var tile = map.tiles[xz.x / 3][xz.y / 3]
			if not touched.has(tile):
				touched[tile] = true
				tile.reset_color(not found_edge)
				if not found_edge:
					tile.destroy_decorations()

var ok := true
var mismatches := 0
var ref: ReferenceStatesMap
var cur


func _check(cond: bool, msg: String) -> void:
	print(("ok: " if cond else "FAIL: ") + msg)
	ok = ok and cond


## Feed the same tile change to the reference and compare the grids.
func _compare(tile) -> void:
	ref.update_tile(tile)
	if ref.open != cur.open or ref.closed != cur.closed:
		mismatches += 1
		printerr("mismatch at %d,%d" % [tile.idxX, tile.idxZ])
		ref.open = cur.open.duplicate()
		ref.closed = cur.closed.duplicate()


func _closed_cells() -> int:
	var n := 0
	for v in cur.closed:
		n += v
	return n


func _ready() -> void:
	Main.requested_mode = "ai2"
	Main.requested_args = {"seed": "11", "no-decorations": "true"}
	var main := Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	var game = main.game
	for p in game.players:
		p.nextAction = 1e9
	var map = game.map
	var player = game.players[0]
	cur = map.statesMap
	ref = ReferenceStatesMap.new()
	ref.reset(map)
	ref.open = cur.open.duplicate()
	ref.closed = cur.closed.duplicate()

	# behaviour: a ring encloses its centre, breaking one wall opens it again
	var c := Vector2i(5, 5)
	Ring.build(player, map, c.x, c.y, _compare)
	_check(map.is_tile_enclosed(c.x, c.y), "ring of walls encloses the centre tile")
	_check(not map.is_tile_enclosed(c.x + 3, c.y), "tile outside the ring stays open")
	var gap = map.tiles[c.x][c.y + 1]
	gap.un_build()
	_compare(gap)
	_check(not map.is_tile_enclosed(c.x, c.y), "breaking one wall opens the area")
	# a larger area: every inner tile is enclosed, a gap in the side opens all of them
	var q := _free_rect(map, 6, 5)
	_check(q.x >= 0, "a free 6x5 rectangle exists for the larger ring")
	Ring.build_rect(player, map, q.x, q.y, q.x + 5, q.y + 4, _compare)
	_check(_inner(map, q.x, q.y, q.x + 5, q.y + 4).all(func(t): return map.is_tile_enclosed(t.x, t.y)), "4x3 area inside a wall rectangle is enclosed")
	gap = map.tiles[q.x][q.y + 2]
	gap.un_build()
	_compare(gap)
	_check(_inner(map, q.x, q.y, q.x + 5, q.y + 4).all(func(t): return not map.is_tile_enclosed(t.x, t.y)), "a gap in the side opens the whole area")
	# full blocks: side contact closes a ring, a corner contact alone never joins
	var r0 := _free_rect(map, 5, 5)
	_check(r0.x >= 0, "a free 5x5 square exists for the block ring")
	Ring.build_rect(player, map, r0.x, r0.y, r0.x + 4, r0.y + 4, _compare)
	_check(map.is_tile_enclosed(r0.x + 2, r0.y + 2), "a ring of full blocks encloses its inside")
	var corner = map.tiles[r0.x][r0.y]
	corner.un_build()
	_compare(corner)
	_check(not map.is_tile_enclosed(r0.x + 2, r0.y + 2),
			"a ring missing one corner block stays open: diagonal blocks do not join")

	# equivalence with the original algorithm over random edits
	seed(5)
	var peak := 0
	for i in 600:
		if i > 0:
			peak = maxi(peak, _closed_cells())
		var x := randi_range(1, map.sizeX - 3)
		var z := randi_range(1, map.sizeZ - 3)
		var tile = map.tiles[x][z]
		if i % 3 == 0:
			var x1 := mini(x + randi_range(2, 5), map.sizeX - 2)
			var z1 := mini(z + randi_range(2, 5), map.sizeZ - 2)
			if _rect_free(map, x, z, x1, z1):
				Ring.build_rect(player, map, x, z, x1, z1, _compare)
				continue
		if U.alive(tile.structure):
			tile.un_build()
		elif not tile.water:
			player.build_building(tile, Catalog.spawn(OTHER[randi() % OTHER.size()]))
		_compare(tile)
	_check(peak > 0, "random edits produced enclosed areas (%d closed cells at the peak)" % peak)
	_check(mismatches == 0, "optimised flood fill equals the original (%d mismatches)" % mismatches)
	print("FLOOD TEST PASSED" if ok else "FLOOD TEST FAILED")
	get_tree().quit(0 if ok else 1)


func _rect_free(map, x0: int, z0: int, x1: int, z1: int) -> bool:
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var t = map.tiles[x][z]
			if U.alive(t.structure) or t.water:
				return false
	return true


## Lower left tile of the first free w x h rectangle, scanning from (1, 1); (-1, -1) when none.
func _free_rect(map, w: int, h: int) -> Vector2i:
	return Ring.free_rect(map, w, h)


func _inner(_map, x0: int, z0: int, x1: int, z1: int) -> Array:
	var out: Array = []
	for x in range(x0 + 1, x1):
		for z in range(z0 + 1, z1):
			out.append(Vector2i(x, z))
	return out
