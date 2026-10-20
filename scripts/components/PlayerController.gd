extends "res://scripts/components/Component.gd"
const WallComp = preload("res://scripts/components/Wall.gd")
## Port of PlayerController.cs: a human player (mouse + keyboard). AI.gd
## extends this class.

const UpgradeCluster = preload("res://scripts/UpgradeCluster.gd")

@export var mainColorHexCode := "#1f1f5e"
@export var highlightPosColorHexCode := "#aaaadd"
@export var highlightNegColorHexCode := "#ad3030"
@export var discardFlySeconds := 1.0
@export var secondsBetweenBuildings := 0.3

## Parts cap per castles held: 1 castle 6 parts, 2 castles 10, then 13, 15, 17.
const PARTS_CAP := [0, 6, 10, 13, 15, 17]
## Standing limit on gun parts; a cap below the placed guns blocks new placement only.
var partsCap := 0
## HUD labels, one pair a player (parts, castles)
var partsLabel: Label = null
var castlesLabel: Label = null
var mainColor := Color.WHITE
var highlightPosColor := Color.WHITE
var highlightNegColor := Color.RED
## GameObject (Node3D) of the next wall / building to place
var nextWall: Node3D = null
var nextBuilding: Node3D = null
## BuildingPlace component of the tile under the cursor
var buildableTileSelected = null
## tiles whose trees and stones are hidden under the placement preview
var decorHiddenTiles: Array = []
## tiles carrying the placement highlight
var litTiles: Array = []
var canPlaceWall := false
var canPlaceBuilding := false
var freeTileSelected := false
var canStackWall := false
var canCombine := false
var aimPoint := Vector3.ZERO
var wallSpawn: Node3D = null
var buildingSpawn: Node3D = null
## Vector2i -> component
var cannons := {}
var supports := {}
var supplies := {}
var upgrades := {}
var wallTiles: Array = []
var activeCannons: Array = []
var playerID := 0
var map = null
## reach[x * map.sizeZ + z] = 1 where a placement may touch: within map.buildingRange (Chebyshev) of an own
## wall tile or of a tile of an own castle that is not a ruin
var reach := PackedByteArray()
## set by reach_changed(); the next read rebuilds `reach`
var _reachStale := true
var secondsLastBuilding := 0.0
var game = null
var voidSelected := false
## battle statistics (shots, hits, intercepted, absorbed, walls_lost, guns_lost, buildings_lost)
var stats := {}
## last mouse position in viewport coordinates
var mousePosition := Vector2.ZERO
## castles currently faded for blocking the cursor piece
var fadedCastles: Array = []


func setup() -> void:
	mainColor = Color.html(mainColorHexCode)
	highlightPosColor = Color.html(highlightPosColorHexCode)
	highlightNegColor = Color.html(highlightNegColorHexCode)
	reach_changed()


func in_reach(x: int, z: int) -> bool:
	_fresh_reach()
	return reach[x * map.sizeZ + z] != 0


## The anchors moved: every own placement and loss and every castle changing hands call it. The next read
## rebuilds the reach once, however many blocks a piece stamped or a splash took.
func reach_changed() -> void:
	_reachStale = true


func _fresh_reach() -> void:
	if _reachStale:
		_reachStale = false
		_rebuild_reach()


func _rebuild_reach() -> void:
	reach = _anchor_mask(map.buildingRange)


## 1 within r tiles (Chebyshev) of an own wall tile or of a tile of an own castle that is not a ruin.
func _anchor_mask(r: int) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(map.sizeX * map.sizeZ)
	var anchors: Array = wallTiles.duplicate()
	for c in map.castles:
		if U.alive(c) and not c.is_ruin() and c.owner() == self:
			anchors.append_array(c.my_tiles())
	for t in anchors:
		for x in range(maxi(t.idxX - r, 0), mini(t.idxX + r, map.sizeX - 1) + 1):
			for z in range(maxi(t.idxZ - r, 0), mini(t.idxZ + r, map.sizeZ - 1) + 1):
				m[x * map.sizeZ + z] = 1
	return m


# --------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		mousePosition = event.position


func button_down(action: String) -> bool:
	return Input.is_action_just_pressed(action)


## Replaces Physics.Raycast from the mouse: intersect the view ray with the
## ground plane. Returns [hit, point, tile (BuildingPlace or null)].
func _pick() -> Array:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return [false, Vector3.ZERO, null]
	var origin := cam.project_ray_origin(mousePosition)
	var dir := cam.project_ray_normal(mousePosition)
	if absf(dir.y) < 1e-5:
		return [false, Vector3.ZERO, null]
	var t := (0.1 - origin.y) / dir.y
	if t < 0:
		return [false, Vector3.ZERO, null]
	var point := origin + dir * t
	var xz: Vector2i = map.tile_index_at(point)
	if xz.x < 0:
		return [true, point, null]
	var tile = map.tiles[xz.x][xz.y]
	if tile.disabled:
		return [true, point, null]
	point.y = tile.go.global_position.y + 0.1
	return [true, point, tile]


func update_point_and_tile_selected() -> void:
	_restore_decorations()
	for t in litTiles:
		if U.alive(t):
			t.highlight_off()
	litTiles = []
	canStackWall = false
	canPlaceWall = false
	canPlaceBuilding = false
	freeTileSelected = false
	voidSelected = false
	buildableTileSelected = null
	canCombine = false
	var hit := _pick()
	if hit[0]:
		aimPoint = hit[1]
		buildableTileSelected = hit[2]
		voidSelected = hit[2] == null
	if voidSelected:
		next_wall_to_gui()
		next_building_to_gui()
	if buildableTileSelected != null:
		var x: int = buildableTileSelected.idxX
		var z: int = buildableTileSelected.idxZ
		freeTileSelected = buildableTileSelected.is_free()
		if freeTileSelected:
			next_wall_to_map()
			next_building_to_gui()
			canPlaceBuilding = in_reach(x, z)
			canPlaceWall = can_place_piece(buildableTileSelected)
			var lit: Array = piece_tiles(buildableTileSelected) if U.alive(nextWall) else []
			if lit.is_empty():
				lit = [buildableTileSelected]
			_light(lit, canPlaceWall if U.alive(nextWall) else canPlaceBuilding)
		else:
			if U.alive(buildableTileSelected.structure) and U.alive(nextBuilding):
				canCombine = can_combine_next_building_with_tile(buildableTileSelected)
			canStackWall = can_stack_on(buildableTileSelected)
			if canStackWall:
				next_wall_to_wall()
			else:
				next_wall_to_gui()
			next_building_to_gui()
	_fade_blocking_castles()


## Castles between the camera and the cursor fade out while a piece previews
## behind them; everything turns solid again once nothing blocks.
func _fade_blocking_castles() -> void:
	if (not U.alive(nextWall) and not U.alive(nextBuilding)) \
			or (not freeTileSelected and not canStackWall):
		for c in fadedCastles:
			U.set_alpha(c.go, 1.0)
		fadedCastles.clear()
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or map == null:
		return
	var blocking: Array = []
	for c in map.castles:
		if U.alive(c) and c.bounds().intersects_segment(cam.global_position, aimPoint) != null:
			blocking.append(c)
	for c in fadedCastles:
		if not blocking.has(c):
			U.set_alpha(c.go, 1.0)
	for c in blocking:
		if not fadedCastles.has(c):
			U.set_alpha(c.go, 0.35)
	fadedCastles = blocking


func _light(tiles: Array, ok: bool) -> void:
	for t in tiles:
		t.highlight_on(highlightPosColor if ok else highlightNegColor)
	litTiles = tiles


## The tiles under the held piece with its anchor cell on `tile`, the cells on the map only.
func piece_tiles(tile) -> Array:
	var out: Array = []
	for c in U.comp(nextWall, "BuildingBlock").cells:
		var x: int = tile.idxX + c.x
		var z: int = tile.idxZ + c.y
		if x >= 0 and z >= 0 and x < map.sizeX and z < map.sizeZ:
			out.append(map.tiles[x][z])
	return out


## The held piece fits with its anchor on `tile`: every cell on the map and free, one of them in reach.
func can_place_piece(tile) -> bool:
	if not U.alive(nextWall):
		return false
	var tiles := piece_tiles(tile)
	if tiles.size() != U.comp(nextWall, "BuildingBlock").cells.size():
		return false
	var reached := false
	for t in tiles:
		if not t.is_free():
			return false
		reached = reached or in_reach(t.idxX, t.idxZ)
	return reached


## The held piece is a single block and `tile` an own wall with room on top.
func can_stack_on(tile) -> bool:
	return U.alive(nextWall) and U.comp(nextWall, "BuildingBlock").cells.size() == 1 \
			and tile.isWall and map.get_mini(tile.idxX, tile.idxZ) == playerID \
			and not U.alive(tile.wallStacked) and not tile.burning


func can_combine_next_building_with_tile(tile) -> bool:
	return tile.buildable() and _combination(nextBuilding, tile) != null


## The building made by placing `placed` onto the building on `tile` (or null).
func _combination(placed: Node3D, tile) -> BuildingDef:
	var a := Catalog.def_of(placed)
	var b := Catalog.def_of(tile.structure)
	if a == null or b == null:
		return null
	return Catalog.combination(a.id, b.id)


func try_get_next_building() -> void:
	if game != null and not game.buildingAllowed:
		return
	if not U.alive(nextBuilding) and secondsLastBuilding + secondsBetweenBuildings < U.time:
		secondsLastBuilding = 0.0
		var def := Catalog.draw(BuildingDef.Category.BUILDING)
		if def == null:
			return
		nextBuilding = Catalog.spawn(def, buildingSpawn)
		switch_casting_shadows(nextBuilding, false)


func next_wall_to_gui() -> void:
	if U.alive(nextWall) and wallSpawn != null:
		U.set_parent(nextWall, wallSpawn)
		nextWall.position = -_piece_centre()
		switch_casting_shadows(nextWall, false)
		_restore_wall_color()


func next_wall_to_map() -> void:
	if U.alive(nextWall):
		U.set_parent(nextWall, buildableTileSelected.go)
		nextWall.position = Vector3.ZERO
		_settle_cells()
		switch_casting_shadows(nextWall, true)
		_darken_wall()
		_hide_decorations()


## Centre of the held piece's cell box in its parent's space; a cell (x, z) sits at (x, 0, -z).
func _piece_centre() -> Vector3:
	var cells: Array[Vector2i] = U.comp(nextWall, "BuildingBlock").cells
	var lo := cells[0]
	var hi := cells[0]
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return Vector3((lo.x + hi.x) / 2.0, 0.0, -(lo.y + hi.y) / 2.0)


## Each cell of the held piece sits on its own tile's slab, as the block it places will.
func _settle_cells() -> void:
	var cells: Array[Vector2i] = U.comp(nextWall, "BuildingBlock").cells
	var nodes := nextWall.get_children().filter(func(n): return n is Node3D)
	for i in cells.size():
		var x: int = buildableTileSelected.idxX + cells[i].x
		var z: int = buildableTileSelected.idxZ + cells[i].y
		if x >= 0 and z >= 0 and x < map.sizeX and z < map.sizeZ:
			nodes[i].global_position.y = map.tiles[x][z].go.global_position.y


func next_building_to_gui() -> void:
	if U.alive(nextBuilding) and buildingSpawn != null:
		U.set_parent(nextBuilding, buildingSpawn)
		nextBuilding.position = Vector3.ZERO
		switch_casting_shadows(nextBuilding, false)


func _restore_wall_color() -> void:
	_shade_wall(1.0)


## The held piece on the board reads darker than the placed blocks round it.
func _darken_wall() -> void:
	_shade_wall(0.7)


func _shade_wall(shade: float) -> void:
	if U.alive(nextWall):
		WallComp.paint_piece(nextWall, self, U.comp(nextWall, "Structure").def.piece, shade)


func switch_casting_shadows(n: Node3D, on := true) -> void:
	U.set_shadows(n, on)


func next_wall_to_wall() -> void:
	U.set_parent(nextWall, buildableTileSelected.go)
	switch_casting_shadows(nextWall, true)
	nextWall.position = Vector3(0, 0.75, 0)  # the upper storey's body starts on the block's top
	_darken_wall()


func _hide_decorations() -> void:
	for t in piece_tiles(buildableTileSelected):
		t.hide_decorations()
		decorHiddenTiles.append(t)


func _restore_decorations() -> void:
	for t in decorHiddenTiles:
		if U.alive(t):
			t.show_decorations()
	decorHiddenTiles = []


func count(stat: String, n := 1) -> void:
	stats[stat] = stats.get(stat, 0) + n


# ------------------------------------------------------------------ parts
## Gun parts in play: the square of each live gun's footprint (a fused 2x2
## cannon costs the same 4 parts as the four singles it replaced).
func parts_used() -> int:
	var total := 0
	for key in cannons:
		var c = cannons[key]
		if U.alive(c):
			var s: int = Catalog.def_of(c.go).size
			total += s * s
	return total


func castle_count() -> int:
	var n := 0
	for castle in map.castles:
		if U.alive(castle) and not castle.is_ruin() and castle.owner() == self:
			n += 1
	return n


func recompute_parts_cap() -> void:
	partsCap = PARTS_CAP[mini(castle_count(), PARTS_CAP.size() - 1)]


## A drawn shooter that would pass the parts cap is not placed; the draw is kept.
func over_parts_cap(go: Node3D) -> bool:
	var def := Catalog.def_of(go)
	return def != null and U.shooter(go) != null and parts_used() + def.size * def.size > partsCap


func remove_building_from_player(bb) -> void:
	var bgo: Node3D = bb.go
	var key := Vector2i(bb.buildingPlace.idxX, bb.buildingPlace.idxZ)
	if U.comp(bgo, "Wall") != null:
		if wallTiles.has(bb.buildingPlace):
			count("walls_lost")
		wallTiles.erase(bb.buildingPlace)
	elif U.shooter(bgo) != null:
		if cannons.has(key):
			count("guns_lost")
		cannons.erase(key)
	elif U.support(bgo) != null:
		if supports.has(key):
			count("buildings_lost")
		supports.erase(key)
	elif U.comp(bgo, "SupplyBuilding") != null:
		if supplies.has(key):
			count("buildings_lost")
		supplies.erase(key)
	var castle = U.comp(bgo, "Castle")
	if castle != null:
		map.castles.erase(castle)
	reach_changed()


func manage_player_actions() -> void:
	if buildableTileSelected != null:
		if button_down("debug_shake"):
			buildableTileSelected.shake(2.0)
		if game.buildingAllowed:
			if button_down("build_wall") and U.alive(nextWall):
				if canPlaceWall:
					build_next_wall(buildableTileSelected)
				elif canStackWall:
					stack_wall(buildableTileSelected)
			elif button_down("build_building") and U.alive(nextBuilding):
				if canPlaceBuilding:
					build_next_building()
				elif canCombine:
					_combine_next_building_with_selected_tile()
		if game.shootingAllowed:
			if button_down("fire"):
				for cannon in activeCannons:
					if cannon.try_shoot(aimPoint, buildableTileSelected):
						break
			else:
				for cannon in activeCannons:
					cannon.try_aim(aimPoint)
		if U.alive(nextWall):
			if button_down("rotate_cw"):
				U.comp(nextWall, "BuildingBlock").rotate_clockwise()
			if button_down("rotate_ccw"):
				U.comp(nextWall, "BuildingBlock").rotate_counter_clockwise()
	elif voidSelected:
		if button_down("build_wall") and U.alive(nextWall):
			drop(nextWall, true)
		elif button_down("build_building") and U.alive(nextBuilding):
			drop(nextBuilding, false)


func _build(tile, n: Node3D) -> Node3D:
	tile.build(n, self)
	reach_changed()
	return n


func _combine_next_building_with_selected_tile() -> Node3D:
	return combine_building(buildableTileSelected)


## Places the next building onto the building on `tile`, replacing both with
## their combination. (Unity kept the placed piece, so it could be used again.)
func combine_building(tile) -> Node3D:
	var def := _combination(nextBuilding, tile)
	var combined := Catalog.spawn(def)
	U.destroy(nextBuilding)
	nextBuilding = null
	secondsLastBuilding += U.time
	tile.un_build()
	build_building(tile, combined)
	return combined


func build_next_building(tile = null) -> void:
	if tile == null:
		tile = buildableTileSelected
	if over_parts_cap(nextBuilding):
		return
	build_building(tile, nextBuilding)
	nextBuilding = null
	secondsLastBuilding += U.time


func build_building(tile, building: Node3D) -> void:
	_build(tile, building)
	switch_casting_shadows(building, true)
	var key := Vector2i(tile.idxX, tile.idxZ)
	var shooter := U.shooter(building)
	var support := U.support(building)
	var supply := U.comp(building, "SupplyBuilding")
	var upgrade := U.comp(building, "Upgrade")
	if shooter != null:
		shooter.player = self
		cannons[key] = shooter
	elif support != null:
		support.player = self
		supports[key] = support
	elif supply != null:
		supplies[key] = supply
	# any building can be part of an upgrade pattern (not only upgrade blocks)
	if upgrade != null:
		build_upgrade(tile)


func build_upgrade(tile) -> void:
	upgrades[Vector2i(tile.idxX, tile.idxZ)] = U.comp(tile.structure, "Upgrade")
	var cluster = UpgradeCluster.new(tile, self)
	if cluster.can_be_built():
		cluster.build_multifield_upgrade()


## A fresh block stacks on the own wall on `tile`; the held single block is used up.
func stack_wall(tile) -> void:
	var block := Catalog.spawn("wall", null, self)
	U.comp(block, "BuildingBlock").player = self
	tile.stack_wall(block)
	U.destroy(nextWall)
	nextWall = null
	get_next_wall()


## Stamps a wall block on every tile of the held piece anchored on `tile`; the piece is used up.
func build_next_wall(tile) -> void:
	var tiles := piece_tiles(tile)
	map.statesMap.begin_batch()
	for t in tiles:
		build_wall(t, Catalog.spawn("wall", null, self))
	map.statesMap.end_batch(tiles)
	U.destroy(nextWall)
	nextWall = null
	get_next_wall()


func build_wall(tile, wall: Node3D) -> void:
	wallTiles.append(tile)
	_build(tile, wall)


## The start castle covers the square of its size with `tile` at its centre,
## walled in by a closed ring.
func build_start_castle(tile) -> void:
	var def := Catalog.get_def("castle")
	var x0: int = tile.idxX - def.size / 2
	var z0: int = tile.idxZ - def.size / 2
	place(def, x0, z0)
	_wall_in(x0, z0, x0 + def.size - 1, z0 + def.size - 1)


## A closed ring of wall blocks round the square x0..x1, z0..z1.
func _wall_in(x0: int, z0: int, x1: int, z1: int) -> void:
	for x in range(x0 - 1, x1 + 2):
		for z in range(z0 - 1, z1 + 2):
			if x < x0 or x > x1 or z < z0 or z > z1:
				build_wall(map.tiles[x][z], Catalog.spawn("wall", null, self))


## Rules v3: every live gun fires, walled in or not; nothing is ever unsupplied.
func refresh_active_cannons() -> void:
	activeCannons = []
	for key in cannons:
		if U.alive(cannons[key]):
			activeCannons.append(cannons[key])
	for key in supports:
		var support = supports[key]
		if U.alive(support):
			support.switch_on_off(true)


func drop(droppable: Node3D, is_wall := true) -> void:
	if U.alive(droppable):
		U.comp(droppable, "FlyAndVanish").fly_away(3.0, self, is_wall)


func get_next_wall() -> void:
	var wall := Catalog.spawn(Catalog.draw(BuildingDef.Category.WALL), wallSpawn, self)
	var rotations := U.rint(0, 4)
	for i in rotations:
		U.comp(wall, "BuildingBlock").rotate_counter_clockwise()
	nextWall = wall
	switch_casting_shadows(nextWall, false)


## Places a building of `def` with its lower left corner on tile (x, z), as the
## sandbox editor does: walls count as walls, a base becomes the start base,
## and bigger structures occupy their whole square (like a merged upgrade).
## Returns the building, or null when a tile is not free.
func place(def: BuildingDef, x: int, z: int, node: Node3D = null) -> Node3D:
	if not can_place(def, x, z):
		if node != null:
			node.free()
		return null
	var go: Node3D = node if node != null else Catalog.spawn(def, null, self)
	if def.size == 1:
		var tile = map.tiles[x][z]
		if def.category == BuildingDef.Category.WALL:
			build_wall(tile, go)
		else:
			build_building(tile, go)
		return go
	var tiles: Array = []
	for dx in def.size:
		for dz in def.size:
			tiles.append(map.tiles[x + dx][z + dz])
	var main = map.tiles[x + 1][z + 1]
	var centre := Vector3.ZERO
	for t in tiles:
		centre += t.go.global_position
		if t != main:
			t.structure = go
			t.player = self
			map.set_mini(t.idxX, t.idxZ, playerID)
			t.destroy_decorations()
	build_building(main, go)
	go.global_position = Vector3(centre.x / tiles.size(), 0.0, centre.z / tiles.size())
	var cluster = UpgradeCluster.new(main, self, tiles)
	for t in tiles:
		t.upgradeCluster = cluster
	return go


## Every tile of the square is on the map, dry, free and usable.
func can_place(def: BuildingDef, x: int, z: int) -> bool:
	if x < 0 or z < 0 or x + def.size > map.sizeX or z + def.size > map.sizeZ:
		return false
	for dx in def.size:
		for dz in def.size:
			var t = map.tiles[x + dx][z + dz]
			if U.alive(t.structure) or t.water or t.disabled or U.alive(t.ship):
				return false
	return true
