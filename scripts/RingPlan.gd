extends RefCounted
## A region the AI wants inside a closed wall ring: a castle with the free ground one tile round
## it, or a yard of free ground of an odd size, for guns or as a territory room. The ring is the cheapest 4-connected closed loop round
## the target on the board as it stands (own walls free, free ground 1, own enclosed ground 3;
## a wall of another faction cannot carry the ring, for a ring two factions share closes for
## neither (I75), and neither can water, castles, guns or ground another player's ring closes). A
## target already inside own closed ground is done whatever its loop says. Coordinates are
## Vector2i(x, z).

const INF := 1 << 30
const WINDOW := 4
const YARD := 3
const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var player = null
var map = null
## The castle to ring, or null for a yard
var castle = null
## A yard's lower left tile
var yard := Vector2i.ZERO
## The yard's size in tiles, odd; 3 is the gun yard
var yardSize := YARD
## Set by refresh when the game itself has the target in the player's closed ground: the plan is
## done however its loop looks, and a ring that stands but does not seal (a diagonal pinch round
## existing walls) is a dud the caller replaces.
var done := false
## Vector2i -> true
var target := {}
var ring := {}
var gaps := {}
var inside := {}
var cost := INF


## A castle plan, or with `c` null the yard of size `s` whose lower left tile is `lower_left`.
func _init(p, c = null, lower_left := Vector2i.ZERO, s := YARD) -> void:
	player = p
	map = p.map
	castle = c
	yard = lower_left
	yardSize = s


## Nothing left to build: the castle sits in own closed ground already, or the loop stands.
func closed() -> bool:
	return possible() and gaps.is_empty()


func possible() -> bool:
	return cost < INF


func centre() -> Vector2i:
	if castle != null:
		return map.tile_index_at(castle.go.global_position)
	return yard + Vector2i(yardSize / 2, yardSize / 2)


## The target as it stands: a castle's 3x3 and the tiles one round it that are not walls (a claim
## brings gun room), only own ground and own guns among them once the castle is the player's (a
## breach is patched, not walled round); or the yard's 3x3.
func _find_target() -> void:
	target = {}
	var c := centre()
	var r := 2 if castle != null else yardSize / 2
	var mine: bool = castle != null and castle.owner() == player
	for x in range(c.x - r, c.x + r + 1):
		for z in range(c.y - r, c.y + r + 1):
			if x < 0 or z < 0 or x >= map.sizeX or z >= map.sizeZ:
				continue
			if castle != null and (absi(x - c.x) == 2 or absi(z - c.y) == 2):
				var t = map.tiles[x][z]
				if t.isWall:
					continue
				if mine and not (map.is_tile_enclosed(x, z) and t.ringOwner == player) \
						and not (U.alive(t.structure) and map.get_mini(x, z) == player.playerID):
					continue
			target[Vector2i(x, z)] = true


## What a wall on the tile costs the loop; -1 when the loop may not pass there.
func _tile_cost(x: int, z: int) -> int:
	var t = map.tiles[x][z]
	if t.isWall:
		return 0 if map.get_mini(x, z) == player.playerID else -1
	if U.alive(t.structure) or t.water or t.disabled or player.enemy_ground(t):
		return -1
	if map.is_tile_enclosed(x, z) and t.ringOwner == player:
		return 3
	return 1


## Finds the cheapest loop round the target and its gaps and inside. A target already in own
## closed ground needs no loop: its inside is the ground round it and its ring the own walls
## bounding that.
func refresh() -> void:
	_find_target()
	ring = {}
	gaps = {}
	inside = {}
	cost = INF
	done = false
	if target.is_empty():
		return
	var lo := Vector2i(map.sizeX, map.sizeZ)
	var hi := Vector2i(-1, -1)
	for k in target:
		lo = Vector2i(mini(lo.x, k.x), mini(lo.y, k.y))
		hi = Vector2i(maxi(hi.x, k.x), maxi(hi.y, k.y))
	var x0: int = maxi(lo.x - WINDOW, 0)
	var z0: int = maxi(lo.y - WINDOW, 0)
	var x1: int = mini(hi.x + WINDOW, map.sizeX - 1)
	var z1: int = mini(hi.y + WINDOW, map.sizeZ - 1)
	var cc := centre()
	if map.is_tile_enclosed(cc.x, cc.y) and map.tiles[cc.x][cc.y].ringOwner == player:
		cost = 0
		done = true
		_flood_inside(x0, z0, x1, z1, true)
		return
	var w: int = x1 - x0 + 1
	var h: int = z1 - z0 + 1
	var costs := PackedInt32Array()
	costs.resize(w * h)
	for lx in w:
		for lz in h:
			var k := Vector2i(x0 + lx, z0 + lz)
			costs[lx * h + lz] = -1 if target.has(k) else _tile_cost(k.x, k.y)
	# the loop crosses the ray east of the target once; every ray tile is tried as that crossing
	var cz: int = (lo.y + hi.y) / 2
	var best_total := INF
	var best_path: Array = []
	var best_ray := Vector2i.ZERO
	for rx in range(hi.x + 1, x1 + 1):
		var li: int = (rx - x0) * h + (cz - z0)
		if costs[li] < 0 or cz - 1 < z0 or cz + 1 > z1:
			continue
		var blocked := costs.duplicate()
		for bx in range(hi.x + 1, x1 + 1):
			blocked[(bx - x0) * h + (cz - z0)] = -1
		var path := _shortest_path(blocked, w, h, Vector2i(rx - x0, cz - 1 - z0), Vector2i(rx - x0, cz + 1 - z0))
		if path.is_empty():
			continue
		var total: int = costs[li]
		for li2 in path:
			total += costs[li2]
		if total < best_total:
			best_total = total
			best_path = path
			best_ray = Vector2i(rx, cz)
	if best_path.is_empty():
		return
	cost = best_total
	ring[best_ray] = true
	for li in best_path:
		ring[Vector2i(x0 + li / h, z0 + li % h)] = true
	for k in ring:
		if not map.tiles[k.x][k.y].isWall:
			gaps[k] = true
	_flood_inside(x0, z0, x1, z1, false)


## The inside: the 8-flood from the target within the window, stopped by the ring, or with
## `by_walls` by any wall, the own ones then forming the ring.
func _flood_inside(x0: int, z0: int, x1: int, z1: int, by_walls: bool) -> void:
	var queue: Array = target.keys()
	for k in queue:
		inside[k] = true
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var n := Vector2i(c.x + dx, c.y + dz)
				if n.x < x0 or n.y < z0 or n.x > x1 or n.y > z1 or inside.has(n):
					continue
				if by_walls:
					if map.tiles[n.x][n.y].isWall:
						if map.get_mini(n.x, n.y) == player.playerID:
							ring[n] = true
						continue
				elif ring.has(n):
					continue
				inside[n] = true
				queue.append(n)


## Dijkstra over the window with tile costs 0 to 3 (bucket queue), from a to b, both inclusive;
## the local indices of the path, empty when none.
func _shortest_path(costs: PackedInt32Array, w: int, h: int, a: Vector2i, b: Vector2i) -> Array:
	var ia: int = a.x * h + a.y
	var ib: int = b.x * h + b.y
	if costs[ia] < 0 or costs[ib] < 0:
		return []
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(w * h)
	prev.fill(-1)
	var buckets: Array = []
	dist[ia] = costs[ia]
	_push(buckets, dist[ia], ia)
	var d := 0
	while d < buckets.size():
		var bucket: Array = buckets[d]
		var bi := 0
		while bi < bucket.size():
			var i: int = bucket[bi]
			bi += 1
			if dist[i] != d:
				continue
			if i == ib:
				var path: Array = []
				var at := ib
				while at != -1:
					path.append(at)
					at = prev[at]
				return path
			var x: int = i / h
			var z: int = i % h
			for dir in DIRS4:
				var nx: int = x + dir.x
				var nz: int = z + dir.y
				if nx < 0 or nz < 0 or nx >= w or nz >= h:
					continue
				var ni: int = nx * h + nz
				if costs[ni] < 0:
					continue
				var nd: int = d + costs[ni]
				if nd < dist[ni]:
					dist[ni] = nd
					prev[ni] = i
					_push(buckets, nd, ni)
		d += 1
	return []


func _push(buckets: Array, d: int, i: int) -> void:
	while buckets.size() <= d:
		buckets.append([])
	buckets[d].append(i)
