extends RefCounted
## Port of StatesMap (Map.cs): every tile is split into 3x3 fine cells. A flood
## fill ("water flow") from the map border finds the cells that are enclosed
## by walls.

var open := PackedByteArray()
var closed := PackedByteArray()
var accessible := PackedByteArray()
var initialOpen := PackedByteArray()
var visited := PackedByteArray()
var willVisit := PackedByteArray()
var sizeFineX := 0
var sizeFineZ := 0
var map = null


func idx(x: int, z: int) -> int:
	return x * sizeFineZ + z


func is_open(x: int, z: int) -> bool:
	return open[x * sizeFineZ + z] != 0


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
	willVisit = _new_grid()


func _reset_accessible_grid() -> void:
	accessible = _new_grid()
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
	_update_tile_in_accessible_grid(bp)
	_reset_visited_will_visit()
	var x: int = bp.idxX * 3
	var z: int = bp.idxZ * 3
	var x_to := mini(x + 3, sizeFineX - 1)
	var x_from := maxi(x - 1, 0)
	var z_to := mini(z + 3, sizeFineZ - 1)
	var z_from := maxi(z - 1, 0)
	_set_subgrid_false(open, x_from, z_from, x_to, z_to)
	_set_subgrid_false(closed, x_from, z_from, x_to, z_to)
	update_open_closed_spaces_in(x_from, z_from, x_to, z_to, true)


func _set_subgrid_false(grid: PackedByteArray, x_from: int, z_from: int, x_to: int, z_to: int) -> void:
	for xi in range(x_from, x_to + 1):
		for zi in range(z_from, z_to + 1):
			grid[idx(xi, zi)] = 0


func _update_tile_in_accessible_grid(bp) -> void:
	var x: int = bp.idxX * 3
	var z: int = bp.idxZ * 3
	if U.alive(bp.structure):
		var grid: Array = U.comp(bp.structure, "BuildingBlock").accessGrid
		for dx in 3:
			for dz in 3:
				accessible[idx(x + dx, z + dz)] = 1 if grid[dx][dz] else 0
	else:
		for dx in 3:
			for dz in 3:
				accessible[idx(x + dx, z + dz)] = 1


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


func waterflow(start_x: int, start_z: int, use_initial_open := false) -> void:
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
