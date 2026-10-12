extends "res://scripts/components/Component.gd"
## Port of PlayerController.cs: a human player (mouse + keyboard). AI.gd
## extends this class.

const UpgradeCluster = preload("res://scripts/UpgradeCluster.gd")

@export var mainColorHexCode := "#1f1f5e"
@export var highlightPosColorHexCode := "#aaaadd"
@export var highlightNegColorHexCode := "#ad3030"
@export var discardFlySeconds := 1.0
@export var secondsBetweenBuildings := 0.3
@export var maxSupply := 100.0

## ProgressBar controls (0..1)
var supplyBar: Range = null
var supplyNeededBar: Range = null
var mainColor := Color.WHITE
var highlightPosColor := Color.WHITE
var highlightNegColor := Color.RED
## GameObject (Node3D) of the next wall / building to place
var nextWall: Node3D = null
var nextBuilding: Node3D = null
## BuildingPlace component of the tile under the cursor
var buildableTileSelected = null
var canBuildOnTile := false
var freeTileSelected := false
var canStackWall := false
var canCombine := false
var aimPoint := Vector3.ZERO
var wallSpawn: Node3D = null
var buildingSpawn: Node3D = null
var startBase = null
## Vector2i -> component
var cannons := {}
var supports := {}
var supplies := {}
var upgrades := {}
var wallTiles: Array = []
var activeCannons: Array = []
var playerID := 0
var map = null
## inBuildRange[x * map.sizeZ + z]
var inBuildRange := PackedByteArray()
var secondsLastBuilding := 0.0
var game = null
var availableSupply := 0.0
var supplyNeed := 0.0
var voidSelected := false
var wallColor := Color.WHITE
## battle statistics (shots, hits, intercepted, absorbed, walls_lost, guns_lost, buildings_lost)
var stats := {}
## last mouse position in viewport coordinates
var mousePosition := Vector2.ZERO


func setup() -> void:
	mainColor = Color.html(mainColorHexCode)
	highlightPosColor = Color.html(highlightPosColorHexCode)
	highlightNegColor = Color.html(highlightNegColorHexCode)


func ibr(x: int, z: int) -> bool:
	return inBuildRange[x * map.sizeZ + z] != 0


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
	if U.alive(buildableTileSelected):
		buildableTileSelected.highlight_off()
	canStackWall = false
	canBuildOnTile = false
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
	if buildableTileSelected != null:
		var x: int = buildableTileSelected.idxX
		var z: int = buildableTileSelected.idxZ
		freeTileSelected = not U.alive(buildableTileSelected.structure) and buildableTileSelected.buildable()
		if freeTileSelected:
			next_wall_to_map()
			if ibr(x, z):
				buildableTileSelected.highlight_on(highlightPosColor)
				canBuildOnTile = true
			else:
				buildableTileSelected.highlight_on(highlightNegColor)
		else:
			if U.alive(buildableTileSelected.structure) and U.alive(nextBuilding):
				canCombine = can_combine_next_building_with_tile(buildableTileSelected)
			canStackWall = U.alive(nextWall) and map.get_mini(x, z) == playerID \
					and buildableTileSelected.isWall and not U.alive(buildableTileSelected.wallStacked) \
					and not buildableTileSelected.burning \
					and _stackable_wall_fits(buildableTileSelected.structure, nextWall)
			if canStackWall:
				next_wall_to_wall()
			else:
				next_wall_to_gui()


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
		nextWall.position = Vector3.ZERO
		switch_casting_shadows(nextWall, false)
		_restore_wall_color()


func next_wall_to_map() -> void:
	if U.alive(nextWall):
		U.set_parent(nextWall, buildableTileSelected.go)
		nextWall.position = Vector3.ZERO
		switch_casting_shadows(nextWall, true)
		_lighten_wall()


func _restore_wall_color() -> void:
	if U.alive(nextWall):
		U.set_color(nextWall, wallColor)


func _lighten_wall() -> void:
	if U.alive(nextWall):
		U.set_color(nextWall, Color.WHITE.lerp(wallColor, 0.5))


func switch_casting_shadows(n: Node3D, on := true) -> void:
	U.set_shadows(n, on)


func next_wall_to_wall() -> void:
	U.set_parent(nextWall, buildableTileSelected.go)
	switch_casting_shadows(nextWall, true)
	nextWall.position = Vector3(0, 1, 0)
	_lighten_wall()


func _stackable_wall_fits(old_wall: Node3D, _new_wall: Node3D) -> bool:
	var old_bb := U.comp(old_wall, "BuildingBlock")
	if old_bb.player != self:
		return false
	var old_c: Array = old_bb.connects_up_down_left_right()
	var new_c: Array = U.comp(nextWall, "BuildingBlock").connects_up_down_left_right()
	for i in 4:
		if new_c[i] and not old_c[i]:
			return false
	return true


func count(stat: String, n := 1) -> void:
	stats[stat] = stats.get(stat, 0) + n


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
	remove_buildable_area(key.x, key.y)


func remove_buildable_area(x: int, z: int) -> void:
	mark_buildable_area_line_of_sight(x, z, false)
	var from_x := maxi(x - 2 * map.buildingRange, 0)
	var to_x := mini(x + 2 * map.buildingRange, map.sizeX - 1)
	var from_z := maxi(z - 2 * map.buildingRange, 0)
	var to_z := mini(z + 2 * map.buildingRange, map.sizeZ - 1)
	for xi in range(from_x, to_x + 1):
		for zi in range(from_z, to_z + 1):
			if map.get_mini(xi, zi) == playerID:
				mark_buildable_area_waterflow(xi, zi, true)


func mark_buildable_area_waterflow(x: int, z: int, buildable := true) -> void:
	var max_x: int = map.sizeX
	var max_z: int = map.sizeZ
	var newly := {Vector2i(x, z): true}
	var queue: Array[Vector2i] = [Vector2i(x, z)]
	var head := 0
	var r: int = map.buildingRange
	while head < queue.size():
		var xz := queue[head]
		head += 1
		for xi in range(maxi(xz.x - 1, 0), mini(xz.x + 1, max_x - 1) + 1):
			for zi in range(maxi(xz.y - 1, 0), mini(xz.y + 1, max_z - 1) + 1):
				var k := Vector2i(xi, zi)
				if absi(x - xi) <= r and absi(z - zi) <= r and not newly.has(k) and not map.tiles[xi][zi].water:
					newly[k] = true
					queue.append(k)
	var v := 1 if buildable else 0
	for k in newly:
		inBuildRange[k.x * max_z + k.y] = v


func mark_buildable_area_line_of_sight(x: int, z: int, buildable := true) -> void:
	mark_square_on_array(x, z, inBuildRange, map.buildingRange, buildable)


func mark_square_on_array(x: int, z: int, arr: PackedByteArray, r: int, value := true) -> void:
	var v := 1 if value else 0
	for xi in range(maxi(x - r, 0), mini(x + r, map.sizeX - 1) + 1):
		for zi in range(maxi(z - r, 0), mini(z + r, map.sizeZ - 1) + 1):
			arr[xi * map.sizeZ + zi] = v


func manage_player_actions() -> void:
	if buildableTileSelected != null:
		if button_down("debug_shake"):
			buildableTileSelected.shake(2.0)
		if game.buildingAllowed:
			if canBuildOnTile:
				if button_down("build_wall") and U.alive(nextWall):
					build_next_wall(buildableTileSelected)
				elif button_down("build_building") and U.alive(nextBuilding):
					build_next_building()
			elif canStackWall and button_down("build_wall") and U.alive(nextWall):
				stack_wall(buildableTileSelected)
			elif canCombine and button_down("build_building"):
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
	mark_buildable_area_waterflow(tile.idxX, tile.idxZ)
	tile.build(n, self)
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


func stack_wall(tile) -> void:
	_restore_wall_color()
	U.comp(nextWall, "BuildingBlock").player = self
	tile.stack_wall(nextWall)
	get_next_wall()


func build_next_wall(tile) -> void:
	_restore_wall_color()
	build_wall(tile, nextWall)
	get_next_wall()


func build_wall(tile, wall: Node3D) -> void:
	_build(tile, wall)
	wallTiles.append(tile)


## The base covers the square of its size that has `tile` at its centre, or for an even size, `tile` as the
## corner square with the highest x and z, with a ring of walls round it.
func build_start_base(tile) -> void:
	var size: int = Catalog.base_def().size
	var x0: int = tile.idxX - size / 2
	var z0: int = tile.idxZ - size / 2
	place(Catalog.base_def(), x0, z0)
	_wall_in(x0, z0, x0 + size - 1, z0 + size - 1)


func _build_from_random_prefabs(tile, plan: Array) -> void:
	var walls := Catalog.drawable(BuildingDef.Category.WALL)
	for i in U.shuffle_index(walls.size()):
		var new_go := Catalog.spawn(walls[i])
		var bb := U.comp(new_go, "BuildingBlock")
		bb.setup()
		var rotations: int = bb.fits_plan_with_clockwise_rotations_of_input(plan)
		if rotations >= 0:
			for r in rotations:
				bb.rotate_counter_clockwise()
			build_building(tile, new_go)
			return
		new_go.free()


## A closed ring of walls round the square x0..x1, z0..z1.
func _wall_in(x0: int, z0: int, x1: int, z1: int) -> void:
	var upper_left := [false, true, false, true]
	var upper_right := [false, true, true, false]
	var lower_left := [true, false, false, true]
	var lower_right := [true, false, true, false]
	var horizontals := [false, false, true, true]
	var verticals := [true, true, false, false]
	var t: Array = map.tiles
	_build_from_random_prefabs(t[x0 - 1][z1 + 1], upper_left)
	_build_from_random_prefabs(t[x1 + 1][z1 + 1], upper_right)
	_build_from_random_prefabs(t[x0 - 1][z0 - 1], lower_left)
	_build_from_random_prefabs(t[x1 + 1][z0 - 1], lower_right)
	for x in range(x0, x1 + 1):
		_build_from_random_prefabs(t[x][z0 - 1], horizontals)
		_build_from_random_prefabs(t[x][z1 + 1], horizontals)
	for z in range(z0, z1 + 1):
		_build_from_random_prefabs(t[x0 - 1][z], verticals)
		_build_from_random_prefabs(t[x1 + 1][z], verticals)


func _get_available_supply() -> float:
	var total := 0.0
	for key in supplies:
		if map.is_tile_enclosed(key.x, key.y):
			total += supplies[key].supply
	return total


func manage_supply_and_active_buildings() -> void:
	availableSupply = _get_available_supply()
	var running := availableSupply
	supplyNeed = 0.0
	activeCannons = []
	for key in cannons:
		var cannon = cannons[key]
		if not U.alive(cannon):
			continue
		if map.is_tile_enclosed(key.x, key.y):
			var need: float = cannon.get_supply_needed()
			supplyNeed += need
			if need == 0 or running > need:
				activeCannons.append(cannon)
				running -= need
	for key in supports:
		var support = supports[key]
		if not U.alive(support):
			continue
		if map.is_tile_enclosed(key.x, key.y):
			var need: float = support.get_supply_needed()
			supplyNeed += need
			var supplied: bool = need == 0 or running > need
			support.switch_on_off(supplied)
			if supplied:
				running -= need
	if supplyNeededBar:
		supplyNeededBar.value = minf(maxSupply, supplyNeed) / maxSupply
	if supplyBar:
		supplyBar.value = minf(maxSupply, availableSupply) / maxSupply


func drop(droppable: Node3D, is_wall := true) -> void:
	if U.alive(droppable):
		U.comp(droppable, "FlyAndVanish").fly_away(3.0, self, is_wall)


func get_next_wall() -> void:
	var wall := Catalog.spawn(Catalog.draw(BuildingDef.Category.WALL), wallSpawn)
	var rotations := U.rint(0, 4)
	for i in rotations:
		U.comp(wall, "BuildingBlock").rotate_counter_clockwise()
	nextWall = wall
	wallColor = U.get_color(nextWall)
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
	var go: Node3D = node if node != null else Catalog.spawn(def)
	if def.size == 1:
		var tile = map.tiles[x][z]
		if def.category == BuildingDef.Category.WALL:
			build_wall(tile, go)
		else:
			build_building(tile, go)
		_mark_base(go, def)
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
	_mark_base(go, def)
	return go


func _mark_base(go: Node3D, def: BuildingDef) -> void:
	if def.category == BuildingDef.Category.BASE:
		startBase = U.comp(go, "BuildingBlock")
		U.set_color(go, mainColor)


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
