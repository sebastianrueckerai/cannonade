extends RefCounted
## Port of BuildingPlan (AI.cs): a rectangle of wall blocks the AI wants to build to
## enclose an area. Coordinates are Vector2i(x, z).


var map = null
var possible := false
var player = null
var score := 0
var originX := 0
var originZ := 0
var radiusUp := 2
var radiusDown := 2
var radiusLeft := 2
var radiusRight := 2
var maxFreeTiles := 20
## Vector2i -> true: the border tiles of the rectangle, each free dry ground or an own wall
var ring := {}
## Array of Vector2i
var xzWalledInTiles: Array = []
var bonusForWallingInBuildings := 15
## Claiming a castle is the point of the game: worth several free tiles
var bonusForWallingInCastles := 40
var bonusPerUnoccupiedTile := 3


func _init(x: int, z: int, p, r_up := 2, r_down := 2, r_left := 2, r_right := 2, max_free := 20) -> void:
	map = p.map
	radiusUp = r_up
	radiusDown = r_down
	radiusLeft = r_left
	radiusRight = r_right
	originX = x
	originZ = z
	player = p
	maxFreeTiles = max_free
	construct_building_place()


func is_fully_stacked() -> bool:
	for xz in ring:
		if not U.alive(map.tiles[xz.x][xz.y].wallStacked):
			return false
	return true


func can_be_combined(bp) -> bool:
	var this_in_bp := false
	var bp_in_this := false
	if may_overlap(bp):
		for xz in bp.xzWalledInTiles:
			if ring.has(xz):
				this_in_bp = true
				break
		for xz in xzWalledInTiles:
			if bp.ring.has(xz):
				bp_in_this = true
				break
	return this_in_bp and bp_in_this


func combine(bp):
	var combined = get_script().new(originX, originZ, player)
	combined._reset()
	radiusUp = maxi(radiusUp, bp.originZ + bp.radiusUp - originZ)
	radiusDown = maxi(radiusDown, originZ - bp.originZ - bp.radiusDown)
	radiusLeft = maxi(radiusLeft, bp.originX + bp.radiusLeft - originX)
	radiusRight = maxi(radiusRight, originX - bp.originX + bp.radiusRight)
	for k in ring:
		if not bp.xzWalledInTiles.has(k):
			combined.ring[k] = true
	for xz in xzWalledInTiles:
		combined.xzWalledInTiles.append(xz)
	for xz in bp.xzWalledInTiles:
		combined.xzWalledInTiles.append(xz)
	for k in bp.ring:
		if ring.has(k) or not xzWalledInTiles.has(k):
			combined.ring[k] = true
	return combined


func fits_with_existing_buildings() -> bool:
	for k in ring:
		if not _free(k.x, k.y):
			if not _own_wall(k):
				return false
		elif not map.statesMap.is_open(k.x * 3 + 1, k.y * 3 + 1):
			return false
	return true


func walls_in_something_valuable() -> bool:
	return count_unoccupied_free_tiles() + _count_walled_in_buildings() > 0


func contains_only_friendly_open_tiles() -> bool:
	for xz in xzWalledInTiles:
		var m: int = map.get_mini(xz.x, xz.y)
		if not (map.statesMap.is_open(xz.x * 3, xz.y * 3) and (m == 0 or m == player.playerID)):
			return false
	return true


func can_be_finished() -> bool:
	return walls_in_something_valuable() and contains_only_friendly_open_tiles() \
			and fits_with_existing_buildings() and reachable()


func reachable() -> bool:
	for xz in ring:
		if player.ibr(xz.x, xz.y):
			return true
	return false


func finished() -> bool:
	for xz in ring:
		if map.get_mini(xz.x, xz.y) == 0:
			return false
	return true


func _reset() -> void:
	ring = {}
	xzWalledInTiles = []


func may_overlap(bp) -> bool:
	var puffer := 1
	var x_max1: int = bp.originX + bp.radiusRight + puffer
	var x_max2: int = originX + radiusRight + puffer
	var x_min1: int = bp.originX - bp.radiusLeft - puffer
	var x_min2: int = originX - radiusLeft - puffer
	var z_max1: int = bp.originZ + bp.radiusUp + puffer
	var z_max2: int = originZ + radiusUp + puffer
	var z_min1: int = bp.originZ - bp.radiusDown - puffer
	var z_min2: int = originZ - radiusDown - puffer
	return (x_min1 <= x_max2 and x_max1 >= x_min2) and (z_min1 <= z_max2 and z_max1 >= z_min2)


func can_be_compatible(bp) -> bool:
	if may_overlap(bp):
		return not prevents(bp) and not bp.prevents(self)
	return true


func can_be_compatible_all(plans: Array) -> bool:
	for bp in plans:
		if not can_be_compatible(bp):
			return false
	return true


func prevents(bp) -> bool:
	for xz in bp.xzWalledInTiles:
		if ring.has(xz) or xzWalledInTiles.has(xz):
			return true
	return false


func construct_building_place() -> void:
	_reset()
	var within_bounds: bool = originX > 0 and originZ > 0 and originX < map.sizeX - 1 and originZ < map.sizeZ - 1
	if not within_bounds:
		return
	var currently_open: bool = map.statesMap.is_open(originX * 3 + 1, originZ * 3 + 1)
	if map.get_mini(originX, originZ) == 0 and currently_open:
		var off_x_pos: int = mini(originX + radiusLeft, map.sizeX - 1) - originX
		var off_z_pos: int = mini(originZ + radiusRight, map.sizeZ - 1) - originZ
		var off_x_neg: int = maxi(originX - radiusDown, 0) - originX
		var off_z_neg: int = maxi(originZ - radiusUp, 0) - originZ
		for xi in range(originX + mini(off_x_neg + 1, 0), originX + off_x_pos):
			for zi in range(originZ + mini(off_z_neg + 1, 0), originZ + off_z_pos):
				xzWalledInTiles.append(Vector2i(xi, zi))
		possible = off_x_pos != 0 and off_z_pos != 0 and off_x_neg != 0 and off_z_neg != 0
		if not possible:
			return
		for xi in range(off_x_neg, off_x_pos + 1):
			for zi in range(off_z_neg, off_z_pos + 1):
				if xi != off_x_neg and xi != off_x_pos and zi != off_z_neg and zi != off_z_pos:
					continue
				var k := Vector2i(originX + xi, originZ + zi)
				if not _ring_tile_ok(k):
					possible = false
					return
				ring[k] = true


## A ring tile is free dry ground or already an own wall.
func _ring_tile_ok(k: Vector2i) -> bool:
	if _free(k.x, k.y):
		var t = map.tiles[k.x][k.y]
		return not t.water and not t.disabled
	return _own_wall(k)


func _own_wall(k: Vector2i) -> bool:
	return map.tiles[k.x][k.y].isWall and map.get_mini(k.x, k.y) == player.playerID


var _count_cache = null  # [free, own] while an AI plan search runs


func _count_free_tiles_by_player_id(id: int) -> int:
	var searching: bool = player.get("slicing") == true
	if searching and _count_cache != null and _count_cache[2] == player.searchStamp:
		if id == 0:
			return _count_cache[0]
		if id == player.playerID:
			return _count_cache[1]
	var free := 0
	var own := 0
	var other := 0
	var mm: PackedByteArray = map.miniMap
	var zs: int = map.sizeZ
	var pid: int = player.playerID
	for xz in xzWalledInTiles:
		var v := mm[xz.x * zs + xz.y]
		if v == 0:
			free += 1
		elif v == pid:
			own += 1
		if v == id:
			other += 1
	if searching:
		_count_cache = [free, own, player.searchStamp]
	return other


func count_unoccupied_free_tiles() -> int:
	return _count_free_tiles_by_player_id(0)


func _count_walled_in_buildings() -> int:
	return _count_free_tiles_by_player_id(player.playerID)


## Enemy and neutral castles the ring would enclose (a ruin claims nothing).
func _count_walled_in_castles() -> int:
	var n := 0
	for c in map.castles:
		if not (U.alive(c.go) and not c.is_ruin() and c.owner() != player):
			continue
		for t in c.my_tiles():
			if xzWalledInTiles.has(Vector2i(t.idxX, t.idxZ)):
				n += 1
				break
	return n


## Ring tiles no wall stands on yet.
func unfinished_ring() -> Dictionary:
	var out := {}
	for k in ring:
		if map.get_mini(k.x, k.y) == 0:
			out[k] = true
	return out


## Own ring walls with room for an upper storey.
func stackable_walls() -> Array:
	var out: Array = []
	for k in ring:
		if _own_wall(k) and not U.alive(map.tiles[k.x][k.y].wallStacked):
			out.append(k)
	return out


func calculate_score(start_exp_wall_costs: int) -> int:
	score = score_benefit() - _score_cost(start_exp_wall_costs)
	return score


func score_benefit() -> int:
	return count_unoccupied_free_tiles() * bonusPerUnoccupiedTile \
			+ _count_walled_in_buildings() * bonusForWallingInBuildings \
			+ _count_walled_in_castles() * bonusForWallingInCastles


func _score_cost(start_exp_wall_costs: int) -> int:
	return ring.size() + _expotential_wall_score(ring.size(), start_exp_wall_costs)


func _expotential_wall_score(n_walls: int, start_exp_wall_costs: int) -> int:
	return int(pow(maxi(0, n_walls - start_exp_wall_costs), 2))


func calculate_compatibility_score(plans: Array, start_exp_wall_costs: int) -> int:
	var saved := 0
	if not plans.is_empty():
		for k in ring:
			for bp in plans:
				if bp.ring.has(k):
					saved += 1
					break
	var bonus := _expotential_wall_score(saved, start_exp_wall_costs)
	score = score_benefit() - _score_cost(start_exp_wall_costs) + bonus
	return score


func _free(x: int, z: int) -> bool:
	return map.miniMap[x * map.sizeZ + z] == 0
