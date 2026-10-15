extends RefCounted
## Port of UpgradeCluster (PlayerController.cs): a square of upgrade blocks
## that merges into one bigger structure (e.g. a 2x2 or 3x3 cannon).

var tile = null
var map = null
var player = null
## BuildingPlace components
var upgradedTiles = null
var sideLength := 0
## The structure the square merges into
var def: BuildingDef = null


## With `tiles` the cluster is made of exactly these tiles (a structure placed
## directly, e.g. in the sandbox); otherwise it looks for complete patterns.
func _init(t, p, tiles = null) -> void:
	tile = t
	map = p.map
	player = p
	upgradedTiles = tiles
	if tiles != null:
		sideLength = int(sqrt(tiles.size()))
	else:
		check_for_complete_upgrades()


func can_be_built() -> bool:
	return upgradedTiles != null


static func _signature(tiles: Array) -> Array:
	var sorted: Array = tiles.duplicate()
	sorted.sort_custom(func(a, b): return a.idxX < b.idxX or (a.idxX == b.idxX and a.idxZ < b.idxZ))
	var sig: Array = []
	for t in sorted:
		sig.append(U.comp(t.structure, "Upgrade").upgradeType)
	return sig


func check_for_complete_upgrades() -> void:
	var x: int = tile.idxX
	var z: int = tile.idxZ
	if upgradedTiles == null:
		upgradedTiles = _check_tile_for_upgrade(x, z, 1, 1, 1, 1)  # 3x3
	if upgradedTiles == null:
		upgradedTiles = _check_tile_for_upgrade(x - 1, z + 1, 0, 1, 0, 1)  # 2x2
	if upgradedTiles == null:
		upgradedTiles = _check_tile_for_upgrade(x - 1, z, 0, 1, 0, 1)
	if upgradedTiles == null:
		upgradedTiles = _check_tile_for_upgrade(x, z + 1, 0, 1, 0, 1)
	if upgradedTiles == null:
		upgradedTiles = _check_tile_for_upgrade(x, z, 0, 1, 0, 1)


func _check_tile_for_upgrade(x: int, z: int, up := 1, down := 1, left := 1, right := 1):
	var parts: Array = []
	if x - left < 0 or x + right >= map.sizeX or z - down < 0 or z + up >= map.sizeZ:
		return null
	var sx := x - left
	var ex := x + right
	var sz := z - down
	var ez := z + up
	for ix in range(sx, ex + 1):
		for iz in range(sz, ez + 1):
			if ix != 0 or iz != 0:
				var t = map.tiles[ix][iz]
				var ok: bool = U.alive(t.structure) and U.comp(t.structure, "Upgrade") != null \
						and t.upgradeCluster == null and t.player == player
				if not ok:
					return null
				parts.append(t)
	def = Catalog.pick_for_pattern(_signature(parts))
	if def == null:
		return null
	sideLength = ex - sx + 1
	return parts


func build_multifield_upgrade() -> void:
	var ix := 0.0
	var iz := 0.0
	for t in upgradedTiles:
		ix += t.go.global_position.x
		iz += t.go.global_position.z
	ix /= upgradedTiles.size()
	iz /= upgradedTiles.size()
	var upgrade_position := Vector3(ix, 0.0, iz)
	var new_structure := Catalog.spawn(def)
	tile.un_build()
	for bp in upgradedTiles:
		bp.upgradeCluster = self
		player.upgrades.erase(Vector2i(bp.idxX, bp.idxZ))
		if U.alive(bp.structure) and bp.structure != new_structure:
			U.destroy(bp.structure)
		bp.structure = new_structure
	player.build_building(tile, new_structure)
	tile.structure.global_position = upgrade_position


func damage_structure(damage: float) -> void:
	var bb := U.comp(tile.structure, "BuildingBlock")
	if bb != null:
		bb.health -= damage
		if bb.health <= 0:
			un_build_upgrade()


func un_build_upgrade() -> void:
	for bp in upgradedTiles:
		if U.alive(bp.structure):
			bp.un_build()
		else:
			bp.structure = null
			bp.player = null
			map.set_mini(bp.idxX, bp.idxZ, 0)
			map.statesMap.update_tile(bp)
		bp.upgradeCluster = null
