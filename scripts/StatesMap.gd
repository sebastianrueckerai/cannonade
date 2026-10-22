extends RefCounted
## Port of StatesMap (Map.cs): every tile is split into 3x3 fine cells. A flood
## fill ("water flow") from the map border finds the cells that are enclosed
## by walls.

var open := PackedByteArray()
var closed := PackedByteArray()
var accessible := PackedByteArray()
var initialOpen := PackedByteArray()
var visited := PackedByteArray()
var sizeFineX := 0
var sizeFineZ := 0
var map = null
## While true, update_tile only records the tile; end_batch() recomputes all
## areas once (much faster when a whole layout is placed at once).
var batching := false
## tileFull[x * sizeZ + z] = 1 when all 9 fine cells of the tile are accessible
var tileFull := PackedByteArray()


func idx(x: int, z: int) -> int:
	return x * sizeFineZ + z


func is_closed(x: int, z: int) -> bool:
	return closed[x * sizeFineZ + z] != 0


func _new_grid() -> PackedByteArray:
	var a := PackedByteArray()
	a.resize(sizeFineX * sizeFineZ)
	return a


func reset(m) -> void:
	map = m
	sizeFineX = map.sizeX * 3
	sizeFineZ = map.sizeZ * 3
	_reset_accessible_grid()
	_reset_open_closed()
	_reset_visited_will_visit()
	initialOpen = _generate_open()


func _reset_visited_will_visit() -> void:
	visited = _new_grid()
	for ix in sizeFineX:
		visited[idx(ix, 0)] = 1
		visited[idx(ix, sizeFineZ - 1)] = 1
	for iz in sizeFineZ:
		visited[idx(0, iz)] = 1
		visited[idx(sizeFineX - 1, iz)] = 1


func _reset_accessible_grid() -> void:
	accessible = _new_grid()
	tileFull = PackedByteArray()
	tileFull.resize(map.sizeX * map.sizeZ)
	for xc in map.sizeX:
		for zc in map.sizeZ:
			_update_tile_in_accessible_grid(map.tiles[xc][zc])


func _generate_open() -> PackedByteArray:
	var g := _new_grid()
	for ix in sizeFineX:
		g[idx(ix, sizeFineZ - 1)] = accessible[idx(ix, sizeFineZ - 1)]
		g[idx(ix, 0)] = accessible[idx(ix, 0)]
	for iz in sizeFineZ:
		g[idx(sizeFineX - 1, iz)] = accessible[idx(sizeFineX - 1, iz)]
		g[idx(0, iz)] = accessible[idx(0, iz)]
	return g


func _reset_open_closed() -> void:
	open = _generate_open()
	closed = _new_grid()


func update_tile(bp) -> void:
	if batching:
		return
	update_tiles([bp])


## update_tile for several tiles at once: one flood over the area around all of them (a wall piece).
func update_tiles(tiles: Array) -> void:
	_reset_visited_will_visit()
	var x_from := sizeFineX
	var z_from := sizeFineZ
	var x_to := 0
	var z_to := 0
	for bp in tiles:
		_update_tile_in_accessible_grid(bp)
		var x: int = bp.idxX * 3
		var z: int = bp.idxZ * 3
		var xa := maxi(x - 1, 0)
		var za := maxi(z - 1, 0)
		var xb := mini(x + 3, sizeFineX - 1)
		var zb := mini(z + 3, sizeFineZ - 1)
		_set_subgrid_false(open, xa, za, xb, zb)
		_set_subgrid_false(closed, xa, za, xb, zb)
		x_from = mini(x_from, xa)
		z_from = mini(z_from, za)
		x_to = maxi(x_to, xb)
		z_to = maxi(z_to, zb)
	update_open_closed_spaces_in(x_from, z_from, x_to, z_to, true)


func begin_batch() -> void:
	batching = true


## Ends a batch: recomputes the areas around `tiles` in one flood, or the whole map when none are given.
func end_batch(tiles: Array = []) -> void:
	batching = false
	if tiles.is_empty():
		update_open_closed_spaces()
	else:
		update_tiles(tiles)


func _set_subgrid_false(grid: PackedByteArray, x_from: int, z_from: int, x_to: int, z_to: int) -> void:
	for xi in range(x_from, x_to + 1):
		for zi in range(z_from, z_to + 1):
			grid[idx(xi, zi)] = 0


func _update_tile_in_accessible_grid(bp) -> void:
	var x: int = bp.idxX * 3
	var z: int = bp.idxZ * 3
	var full := 1
	var bb = U.comp(bp.structure, "BuildingBlock") if U.alive(bp.structure) and not bp.river else null  # the flood runs under a bridge
	if bb != null:
		var grid: Array = bb.accessGrid
		for dx in 3:
			for dz in 3:
				accessible[idx(x + dx, z + dz)] = 1 if grid[dx][dz] else 0
				if not grid[dx][dz]:
					full = 0
	else:
		for dx in 3:
			for dz in 3:
				accessible[idx(x + dx, z + dz)] = 1
	tileFull[bp.idxX * map.sizeZ + bp.idxZ] = full


func update_open_closed_spaces() -> void:
	reset(map)
	update_open_closed_spaces_in(1, 1, sizeFineX - 2, sizeFineZ - 2, false)


func update_open_closed_spaces_in(x_from: int, z_from: int, x_to: int, z_to: int, use_initial_open := true) -> void:
	for ix in range(x_from, x_to + 1):
		for iz in range(z_from, z_to + 1):
			var i := idx(ix, iz)
			if visited[i] == 0 and accessible[i] != 0 and (open[i] == 0 or use_initial_open) \
					and (closed[i] == 0 or use_initial_open):
				waterflow(ix, iz, use_initial_open)


## Flood fill from (start_x, start_z): marks the reached cells open when the
## area touches the map border, otherwise closed. Same result as the original
## cell by cell fill (tests/flood_test.gd keeps it as reference), but tiles whose 9 cells are all
## accessible are handled as one 3x3 block (they are always reached completely).
## `visited` also marks queued cells (the original kept a separate willVisit grid).
func waterflow(start_x: int, start_z: int, use_initial_open := false) -> void:
	var fz := sizeFineZ
	var fx := sizeFineX
	var zs: int = map.sizeZ
	var edge := initialOpen if use_initial_open else open
	var found_edge := false
	var cells := PackedInt32Array()  # visited fine cells
	var queue := PackedInt32Array()  # fine cell index, or -(tile + 1) for a block
	# enqueue the start cell
	_enqueue(start_x * fz + start_z, cells, queue, zs, true)
	var head := 0
	while head < queue.size():
		var q := queue[head]
		head += 1
		if q >= 0:
			var x := q / fz
			var z := q % fz
			for nx in range(x - 1, x + 2):
				var row := nx * fz
				for nz in range(z - 1, z + 2):
					var ni := row + nz
					if not found_edge and edge[ni] != 0:
						found_edge = true
					if visited[ni] == 0 and accessible[ni] != 0:
						_enqueue(ni, cells, queue, zs, false)
		else:
			var t := -q - 1
			var bx := (t / zs) * 3
			var bz := (t % zs) * 3
			var x0 := maxi(bx - 1, 0)
			var x1 := mini(bx + 3, fx - 1)
			var z0 := maxi(bz - 1, 0)
			var z1 := mini(bz + 3, fz - 1)
			for nx in range(x0, x1 + 1):
				var row := nx * fz
				var ring_x := nx == bx - 1 or nx == bx + 3
				for nz in range(z0, z1 + 1):
					var ni := row + nz
					if not found_edge and edge[ni] != 0:
						found_edge = true
					if (ring_x or nz == bz - 1 or nz == bz + 3) and visited[ni] == 0 and accessible[ni] != 0:
						_enqueue(ni, cells, queue, zs, false)
	_finish_flood(cells, found_edge)


## Writes a flooded region's open / closed state: closed only for the one faction whose walls
## encircle it alone, so a ring two factions share keeps the room open (D88).
func _finish_flood(cells: PackedInt32Array, found_edge: bool) -> void:
	var zs: int = map.sizeZ
	var touched := PackedByteArray()
	touched.resize(tileFull.size())
	var tiles: Array = []
	for ci in cells:
		var t := (ci / sizeFineZ / 3) * zs + (ci % sizeFineZ) / 3
		if touched[t] == 0:
			touched[t] = 1
			tiles.append(map.tiles[t / zs][t % zs])
	var owner = null
	var sealed := false
	if not found_edge:
		var border: Dictionary = map.ring_border(tiles)
		if border.size() == 1:
			sealed = true
			owner = border.keys()[0]
		elif border.size() > 1:
			owner = _sealing_faction(border, cells)
			sealed = owner != null
	var v_open := 0 if sealed else 1
	var v_closed := 1 if sealed else 0
	for ci in cells:
		open[ci] = v_open
		closed[ci] = v_closed
	for tile in tiles:
		tile.ringOwner = owner
		tile.reset_color(sealed)
		if sealed:
			tile.destroy_decorations(Vector3.INF, false)


## A region whose border carries several factions' walls belongs to the one whose walls
## encircle it alone (D88: a ring two factions share closes for neither); null keeps it open.
func _sealing_faction(border: Dictionary, cells: PackedInt32Array):
	var factions: Array = border.keys().filter(func(p): return p != null)
	factions.sort_custom(func(a, b): return a.playerID < b.playerID)
	for p in factions:
		if _seals(cells, p.playerID):
			return p
	return null


## Whether a flood from the region's fine cells that may cross any wall but this player's is
## stopped short of the map rim: it is not, when another faction's walls lend the seal.
func _seals(cells: PackedInt32Array, player_id: int) -> bool:
	var seen := PackedByteArray()
	seen.resize(sizeFineX * sizeFineZ)
	var queue := PackedInt32Array()
	for ci in cells:
		seen[ci] = 1
		queue.append(ci)
	var head := 0
	while head < queue.size():
		var q := queue[head]
		head += 1
		var x := q / sizeFineZ
		var z := q % sizeFineZ
		if x == 0 or z == 0 or x == sizeFineX - 1 or z == sizeFineZ - 1:
			return false
		for nx in range(x - 1, x + 2):
			var row := nx * sizeFineZ
			for nz in range(z - 1, z + 2):
				var ni := row + nz
				if seen[ni] != 0:
					continue
				seen[ni] = 1
				if accessible[ni] != 0:
					queue.append(ni)
					continue
				var ti: int = (ni / sizeFineZ / 3) * map.sizeZ + (ni % sizeFineZ) / 3
				var tile = map.tiles[ti / map.sizeZ][ti % map.sizeZ]
				if tile.isWall and map.get_mini(tile.idxX, tile.idxZ) != player_id:
					queue.append(ni)
	return true


func _enqueue(ci: int, cells: PackedInt32Array, queue: PackedInt32Array, zs: int, start: bool) -> void:
	var fz := sizeFineZ
	var tx := ci / fz / 3
	var tz := (ci % fz) / 3
	var t := tx * zs + tz
	if tileFull[t] != 0:
		# the whole block (except preset border cells) is reached
		for dx in 3:
			var row := (tx * 3 + dx) * fz + tz * 3
			for dz in 3:
				var c := row + dz
				if visited[c] == 0 or (start and c == ci):
					visited[c] = 1
					cells.append(c)
		queue.append(-t - 1)
	else:
		visited[ci] = 1
		cells.append(ci)
		queue.append(ci)
