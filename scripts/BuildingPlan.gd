extends RefCounted
## Port of BuildingPlan (AI.cs): a rectangle of walls the AI wants to build to
## enclose an area. Coordinates are Vector2i(x, z), plan values are
## [up, down, left, right] connector requirements.


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
## Vector2i -> Array[bool] (4)
var xz2upDownLeftRight := {}
var xz2upDownLeftRightFinished := {}
## Vector2i -> int (upgrade type)
var xz2UpgradeTilesType := {}
var desiredSignature: Array = []
## Array of Vector2i
var xzWalledInTiles: Array = []
var bonusForWallingInBuildings := 15
var bonusPerUnoccupiedTile := 3
var minX = null
var minZ = null
var maxX = null
var maxZ = null


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
	for xz in xz2upDownLeftRight:
		if not U.alive(map.tiles[xz.x][xz.y].wallStacked):
			return false
	return true


func upgrade_tiles_contain(x: int, z: int) -> bool:
	return xz2UpgradeTilesType.has(Vector2i(x, z))


## Lays out the upgrade blocks for structure_name inside the walled-in area.
func try_initialize_xz_upgrade_tiles(structure_id: String) -> bool:
	var target := Catalog.get_def(structure_id)
	if target == null or target.recipe_pattern.is_empty():
		return false
	desiredSignature = Array(target.recipe_pattern)
	if xzWalledInTiles.size() < desiredSignature.size():
		return false
	xz2UpgradeTilesType = {}
	var side := near_int_sqrt(desiredSignature.size())
	if minX == null or minZ == null:
		minX = 1 << 30
		minZ = 1 << 30
		maxX = -1
		maxZ = -1
		for t in xzWalledInTiles:
			minX = mini(minX, t.x)
			minZ = mini(minZ, t.y)
			maxX = maxi(maxX, t.x)
			maxZ = maxi(maxZ, t.y)
	var offset_x: int = (maxX - minX + 1) - side
	var offset_z: int = (maxZ - minZ + 1) - side
	if offset_x < 0 or offset_z < 0:
		return false
	# The original loops over all start positions but always checks the square
	# at (minX, minZ); the result is the same for every iteration.
	var potential = get_square_of_upgradeable_tiles(side)
	if potential == null:
		return false
	var sorted: Array = potential.duplicate()
	sorted.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	var current: Array = []
	for xz in sorted:
		current.append(_get_current_upgrade_type_for_tile(xz))
	if desiredSignature.size() != current.size():
		return false
	# an orientation of the desired layout that fits the blocks already placed
	# and still merges into the desired structure
	var rotated = null
	for r in [0, 2, 1, 3]:
		var candidate: Array = Catalog.rotations(desiredSignature, side)[r]
		if Catalog.fits(candidate, current) and Catalog.pick_for_pattern(candidate) == target:
			rotated = candidate
			break
	if rotated == null:
		return false
	for i in rotated.size():
		xz2UpgradeTilesType[potential[i]] = rotated[i]
	return true


func _get_current_upgrade_type_for_tile(xz: Vector2i) -> String:
	var s = map.tiles[xz.x][xz.y].structure
	if not U.alive(s) or U.comp(s, "Upgrade") == null:
		return "*"  # wildcard
	return U.comp(s, "Upgrade").upgradeType


func get_square_of_upgradeable_tiles(side: int):
	var mid_x := side / 2
	var mid_z := side / 2
	var mid: Array = []
	var potential: Array = []
	for ix in range(minX, minX + side):
		for iz in range(minZ, minZ + side):
			var is_empty: bool = map.get_mini(ix, iz) == 0
			var is_buildable: bool = player.ibr(ix, iz)
			var s = map.tiles[ix][iz].structure
			var is_upgrade: bool = U.alive(s) and U.comp(s, "Upgrade") != null
			if is_buildable and (is_upgrade or is_empty):
				if ix == mid_x and iz == mid_z:
					mid.append(Vector2i(ix, iz))
				else:
					potential.append(Vector2i(ix, iz))
			else:
				return null
	potential.append_array(mid)
	return potential


static func near_int_sqrt(x: int) -> int:
	if x == 0:
		return 0
	var y := 1
	while y * y < x:
		y *= 2
	return y


func get_upgrade_location_for_upgrade_type(upgrade_type: String):
	for xz in xz2UpgradeTilesType:
		if xz2UpgradeTilesType[xz] == upgrade_type and player.ibr(xz.x, xz.y) and map.get_mini(xz.x, xz.y) == 0:
			return xz
	return null


func upgrade_can_be_finished() -> bool:
	if xz2UpgradeTilesType.is_empty():
		return false
	for xz in xz2UpgradeTilesType:
		var s = map.tiles[xz.x][xz.y].structure
		if not U.alive(s):
			break
		elif U.comp(s, "Upgrade") == null or U.comp(s, "Upgrade").upgradeType != xz2UpgradeTilesType[xz]:
			return false
	return true


func can_be_combined(bp) -> bool:
	var this_in_bp := false
	var bp_in_this := false
	if may_overlap(bp):
		for xz in bp.xzWalledInTiles:
			if xz2upDownLeftRight.has(xz):
				this_in_bp = true
				break
		for xz in xzWalledInTiles:
			if bp.xz2upDownLeftRight.has(xz):
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
	for k in xz2upDownLeftRight:
		if not bp.xzWalledInTiles.has(k):
			combined.xz2upDownLeftRight[k] = xz2upDownLeftRight[k]
	for xz in xzWalledInTiles:
		combined.xzWalledInTiles.append(xz)
	for xz in bp.xzWalledInTiles:
		combined.xzWalledInTiles.append(xz)
	for k in bp.xz2upDownLeftRight:
		if xz2upDownLeftRight.has(k):
			combined.xz2upDownLeftRight[k] = _combine_keys(xz2upDownLeftRight[k], bp.xz2upDownLeftRight[k])
		elif not xzWalledInTiles.has(k):
			combined.xz2upDownLeftRight[k] = bp.xz2upDownLeftRight[k]
	return combined


func fits_with_existing_buildings() -> bool:
	for k in xz2upDownLeftRight:
		if not _free(k.x, k.y):
			var plan: Array = xz2upDownLeftRight[k]
			for i in 4:
				if plan[i] and not _c(k.x, k.y, i):
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
	for xz in xz2upDownLeftRight:
		if player.ibr(xz.x, xz.y):
			return true
	return false


func finished() -> bool:
	for xz in xz2upDownLeftRight:
		if map.get_mini(xz.x, xz.y) == 0:
			return false
	return true


func _reset() -> void:
	xz2upDownLeftRight = {}
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
		if xz2upDownLeftRight.has(xz) or xzWalledInTiles.has(xz):
			return true
	return false


func update_plan_tile(k: Vector2i, v: Array) -> void:
	xz2upDownLeftRight[k] = v


func ensure_compatibility(bp) -> void:
	if may_overlap(bp):
		for k in xz2upDownLeftRight.keys():
			if bp.xz2upDownLeftRight.has(k):
				_synchronize_key(bp, k)


func _combine_keys(a: Array, b: Array) -> Array:
	return [a[0] or b[0], a[1] or b[1], a[2] or b[2], a[3] or b[3]]


func _synchronize_key(bp, k: Vector2i) -> void:
	var v := _combine_keys(xz2upDownLeftRight[k], bp.xz2upDownLeftRight[k])
	update_plan_tile(k, v)
	bp.update_plan_tile(k, v)


func ensure_compatibility_all(plans: Array) -> void:
	for bp in plans:
		ensure_compatibility(bp)


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
		if possible:
			for xi in range(off_x_neg, off_x_pos):
				var up := _score_connection(originX + xi, originZ + off_z_pos, true, true)
				var lo := _score_connection(originX + xi, originZ + off_z_neg, true, false)
				possible = possible and up and lo
				if not possible:
					break
		if possible:
			for zi in range(off_z_neg, off_z_pos):
				var le := _score_connection(originX + off_x_pos, originZ + zi, false, true)
				var ri := _score_connection(originX + off_x_neg, originZ + zi, false, false)
				possible = possible and le and ri
				if not possible:
					break


var _count_cache = null  # [free, own] while an AI plan search runs


func _count_free_tiles_by_player_id(id: int) -> int:
	var searching: bool = player.get("connectionMemo") != null
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


func get_unfinished_buildable_walls() -> Dictionary:
	var out := {}
	for k in xz2upDownLeftRight:
		if map.get_mini(k.x, k.y) == 0:
			out[k] = xz2upDownLeftRight[k]
	return out


func get_stackable_walls() -> Dictionary:
	var out := {}
	for k in xz2upDownLeftRight:
		var t = map.tiles[k.x][k.y]
		if U.alive(t.structure) and not U.alive(t.wallStacked):
			out[k] = xz2upDownLeftRight[k]
	return out


func calculate_score(start_exp_wall_costs: int) -> int:
	score = score_benefit() - _score_cost(start_exp_wall_costs)
	return score


func score_benefit() -> int:
	return count_unoccupied_free_tiles() * bonusPerUnoccupiedTile + _count_walled_in_buildings() * bonusForWallingInBuildings


func _score_cost(start_exp_wall_costs: int) -> int:
	return xz2upDownLeftRight.size() + _expotential_wall_score(xz2upDownLeftRight.size(), start_exp_wall_costs)


func _expotential_wall_score(n_walls: int, start_exp_wall_costs: int) -> int:
	return int(pow(maxi(0, n_walls - start_exp_wall_costs), 2))


func calculate_compatibility_score(plans: Array, start_exp_wall_costs: int) -> int:
	var saved := 0
	if not plans.is_empty():
		for k in xz2upDownLeftRight:
			for bp in plans:
				if bp.xz2upDownLeftRight.has(k):
					saved += 1
					break
	var bonus := _expotential_wall_score(saved, start_exp_wall_costs)
	score = score_benefit() - _score_cost(start_exp_wall_costs) + bonus
	return score


func _update_direction_dict(x: int, z: int, i: int, record := true) -> void:
	if record:
		_recorded.append_array([x, z, i])
	var k := Vector2i(x, z)
	var v: Array = xz2upDownLeftRight[k] if xz2upDownLeftRight.has(k) else [false, false, false, false]
	v[i] = true
	xz2upDownLeftRight[k] = v


# Fine grid offsets of the connector cells for up, down, left, right.
const OX := [1, 1, 0, 2]
const OZ := [2, 0, 1, 1]


## Does the block on tile (x, z) connect towards side? Reads the accessibility
## grid of the flood fill (a connector is a blocked cell at the tile border),
## which is equivalent to BuildingPlace.ConnectsUpDownLeftRight() but much faster.
func _c(x: int, z: int, side: int) -> bool:
	var sm = map.statesMap
	return sm.accessible[(3 * x + OX[side]) * sm.sizeFineZ + 3 * z + OZ[side]] == 0


func _free(x: int, z: int) -> bool:
	return map.miniMap[x * map.sizeZ + z] == 0


## Memoised _score_connection: the result for one wall segment only depends on
## the map state, which does not change during one AI plan search.
## player.connectionMemo maps a segment key to [result, PackedInt32Array of
## (x, z, side) updates].
func _score_connection(x: int, z: int, step_x_axis: bool, detour_positive: bool) -> bool:
	var memo = player.get("connectionMemo")
	if memo == null:
		_recorded = PackedInt32Array()
		return _score_connection_impl(x, z, step_x_axis, detour_positive)
	var key := ((x * 4096 + z) * 2 + (1 if step_x_axis else 0)) * 2 + (1 if detour_positive else 0)
	var entry = memo.get(key)
	if entry == null:
		_recorded = PackedInt32Array()
		var ok := _score_connection_impl(x, z, step_x_axis, detour_positive)
		entry = [ok, _recorded]
		memo[key] = entry
		return ok
	var rec: PackedInt32Array = entry[1]
	for i in range(0, rec.size(), 3):
		_update_direction_dict(rec[i], rec[i + 1], rec[i + 2], false)
	return entry[0]


var _recorded := PackedInt32Array()


func _score_connection_impl(x: int, z: int, step_x_axis: bool, detour_positive: bool) -> bool:
	var sx: int
	var sz: int
	var s1: int
	var s2: int
	var dx: int
	var dz: int
	var d1: int
	var d2: int
	if step_x_axis:
		sx = 1
		sz = 0
		s1 = 3
		s2 = 2
		if detour_positive:
			dx = 0
			dz = 1
			d1 = 0
			d2 = 1
		else:
			dx = 0
			dz = -1
			d1 = 1
			d2 = 0
	else:
		sx = 0
		sz = 1
		s1 = 0
		s2 = 1
		if detour_positive:
			dx = 1
			dz = 0
			d1 = 3
			d2 = 2
		else:
			dx = -1
			dz = 0
			d1 = 2
			d2 = 3
	var mm: PackedByteArray = map.miniMap
	var zs: int = map.sizeZ
	var acc: PackedByteArray = map.statesMap.accessible
	var fz: int = map.statesMap.sizeFineZ
	var f0 := mm[x * zs + z] == 0
	var f1 := mm[(x + sx) * zs + z + sz] == 0
	# connectors of tile 0 (x, z) and tile 1 (x + sx, z + sz)
	var c0_s1 := acc[(3 * x + OX[s1]) * fz + 3 * z + OZ[s1]] == 0
	var c0_d1 := acc[(3 * x + OX[d1]) * fz + 3 * z + OZ[d1]] == 0
	var x1 := x + sx
	var z1 := z + sz
	var c1_s2 := acc[(3 * x1 + OX[s2]) * fz + 3 * z1 + OZ[s2]] == 0
	var c1_d1 := acc[(3 * x1 + OX[d1]) * fz + 3 * z1 + OZ[d1]] == 0
	var c1_d2 := acc[(3 * x1 + OX[d2]) * fz + 3 * z1 + OZ[d2]] == 0
	# direct connection
	var c00 := f0 and f1
	var c01 := f0 and c1_s2
	var c10 := c0_s1 and f1
	var c11 := c0_s1 and c1_s2
	var direct_impossible := not c00 and not c10 and not c01 and not c11
	# detour
	var space: bool = x + dx + sx < map.sizeX and z + dz + sz < map.sizeZ and x + dx + sx > 0 and z + dz + sz > 0
	var d1_01 := f0 and c1_d1
	var d1_10 := c0_d1 and f1
	var d1_11 := c0_d1 and c1_d1
	var detour_possible := false
	var d2_00 := false
	var d2_01 := false
	var d2_10 := false
	var d2_11 := false
	if space:
		var fd0 := _free(x + dx, z + dz)
		var fd1 := _free(x + dx + sx, z + dz + sz)
		d2_00 = fd0 and fd1
		d2_01 = fd0 and _c(x + dx + sx, z + dz + sz, d2) and _c(x + dx + sx, z + dz + sz, s2)
		d2_10 = _c(x + dx, z + dz, d2) and _c(x + dx, z + dz, s1) and fd1
		d2_11 = _c(x + dx, z + dz, d2) and _c(x + dx, z + dz, s1) and c1_d2 and c1_s2
		detour_possible = (d1_01 or d1_10 or d1_11) and (d2_00 or d2_01 or d2_10 or d2_11)
	if c00 or c01:
		_update_direction_dict(x, z, s1)
	if c00 or c10:
		_update_direction_dict(x + sx, z + sz, s2)
	if detour_possible and direct_impossible:
		if d1_01:
			_update_direction_dict(x, z, d1)
			_update_direction_dict(x + dx, z + dz, d2)
		elif d1_10:
			_update_direction_dict(x + sx, z + sz, d1)
			_update_direction_dict(x + sx + dx, z + sz + dz, d2)
		if d2_00 or d2_01:
			_update_direction_dict(x + dx, z + dz, s1)
		if d2_00 or d2_10:
			_update_direction_dict(x + sx + dx, z + sz + dz, s2)
	return (not direct_impossible) or detour_possible
