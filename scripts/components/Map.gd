extends "res://scripts/components/Component.gd"
## Port of Map.cs: creates the tile grid, water, colours and decorations.

const StatesMap = preload("res://scripts/StatesMap.gd")

@export var sizeX := 20
@export var sizeZ := 20
@export var tileSize := 1.0
@export var tilePrefab: PackedScene = preload("res://prefabs/Slab.tscn")
# The ground colours of the art kit, palette.json (D21, D70): open ground is grass on every map,
# enclosed ground and the ground under a wall are stamped mud, well darker than the light walls, water is the
# sea. Each tile lerps from the lighter min colour (a high tile) to the darker max colour (a low tile).
@export var maxEnclosedColors: Array = [Color("#b2915f")]
@export var minEnclosedColors: Array = [Color("#dcc399")]
# one family (I118): the family draw below keeps the seeded map stream put
@export var maxOpenColors: Array = [Color("#8fbf3c").darkened(0.08)]
@export var minOpenColors: Array = [Color("#8fbf3c").lightened(0.06)]
@export var waterColorMin := Color("#2f9fc9").lightened(0.04)
@export var waterColorMax := Color("#2f9fc9").darkened(0.06)
@export var wallColor := Color("#b2915f")
# The approved painted kinds only (D50); the other six kinds wait on blender-ai C5 and
# stay out of the draw so no old FBX prop appears in a first game.
@export var customModelMakerPrefabs: Array = [
	preload("res://prefabs/Maker_Boulder.tscn"), preload("res://prefabs/Maker_Bush.tscn"),
	preload("res://prefabs/Maker_LeafTree.tscn")]
@export var buildingRange := 2
@export var maxModelTypes := 4
## Set to false to skip decorations (faster headless simulations).
@export var decorate := true
## Set while a loading screen is up: make_map then gives the screen a frame every 50 ms.
var staged := false
## Share of make_map done, 0..1
var progress := 0.0
var _frame_start := 0

var game = null
var enclosedColorMin: Color
var enclosedColorMax: Color
var openColorMin: Color
var openColorMax: Color
## tiles[x][z] -> BuildingPlace component
var tiles: Array = []
## every Castle component on the map, in build order
var castles: Array = []
## every terrain feature's GameObject (Node3D with a Terrain component), in build order (I90)
var terrain_features: Array = []
## CustomModelMaker components
var customModelMakers: Array = []
## miniMap[x * sizeZ + z]: player id owning the tile (0 = free)
var miniMap := PackedByteArray()
var statesMap = StatesMap.new()


func get_mini(x: int, z: int) -> int:
	return miniMap[x * sizeZ + z]


func set_mini(x: int, z: int, v: int) -> void:
	miniMap[x * sizeZ + z] = v


func _randomize_model_makers() -> void:
	var makers: Array = []
	for scene in customModelMakerPrefabs:
		var n := U.instantiate(scene, go)
		n.visible = false
		makers.append(U.comp(n, "CustomModelMaker"))
	var order: Array = game.random_shuffle_index(makers.size())
	customModelMakers = []
	for i in mini(maxModelTypes, order.size()):
		customModelMakers.append(makers[order[i]])


func _randomize_colors() -> void:
	var idx_open := U.rint(0, maxOpenColors.size())
	var idx_enclosed := U.rint(0, maxEnclosedColors.size())
	openColorMin = minOpenColors[idx_open]
	openColorMax = maxOpenColors[idx_open]
	enclosedColorMin = minEnclosedColors[idx_enclosed]
	enclosedColorMax = maxEnclosedColors[idx_enclosed]


func _set_water_areas(n_players: int) -> void:
	if n_players == 1:
		var z_water := int(float(sizeZ) * 0.75)
		add_water(true, z_water, 2, 2, true)


func _tile_to_water(x: int, z: int, shade := -1.0) -> void:
	var c := waterColorMin.lerp(waterColorMax, U.value() if shade < 0.0 else shade)
	var t = tiles[x][z]
	t.go.position.y = -0.1
	t.water = true
	t.enclosedColor = c
	t.openColor = c


## Turns the built tile (x, z) into river (I104): water a wall bridges, cleared of its decorations. `shade` comes
## from the river's own generator, so the game's random numbers stay put.
func make_river(x: int, z: int, shade: float) -> void:
	_tile_to_water(x, z, shade)
	var t = tiles[x][z]
	t.river = true
	t.destroy_decorations()
	t.reset_color(false)


func add_water(along_x: bool, from_index: int, margin_up := 2, margin_down := 2, fill_up := false, fill_down := false) -> void:
	var i2 := from_index
	var max1 := sizeX if along_x else sizeZ
	var max2 := sizeZ if along_x else sizeX
	var max_uptick := mini(max2 - 1, from_index + margin_up)
	var max_downtick := maxi(0, from_index - margin_down)
	for i1 in max1:
		if along_x:
			_tile_to_water(i1, i2)
		else:
			_tile_to_water(i2, i1)
		if fill_up:
			for j in range(i2 + 1, max2):
				if along_x:
					_tile_to_water(i1, j)
				else:
					_tile_to_water(j, i1)
		if fill_down:
			for j in range(i2 - 1, -1, -1):
				if along_x:
					_tile_to_water(i1, j)
				else:
					_tile_to_water(j, i1)
		if U.value() > 0.5:
			var delta := 0
			if i2 == max_uptick:
				delta = -1
			elif i2 == max_downtick:
				delta = 1
			else:
				delta = U.rint(-1, 2)
			i2 += delta
			if along_x:
				_tile_to_water(i1, i2)
			else:
				_tile_to_water(i2, i1)


func make_map(players: Array) -> void:
	_frame_start = Time.get_ticks_msec()
	await make_land_map()
	_set_water_areas(players.size())
	if decorate:
		await _add_decorations()
	statesMap.reset(self)
	statesMap.update_open_closed_spaces()


## World position of the centre of tile (x, z). Unity's z axis is mirrored.
func tile_position(xi: int, zi: int, y := 0.0) -> Vector3:
	var xpos := tileSize * xi - (float(sizeX) * tileSize + tileSize) / 2.0
	var zpos := tileSize * zi - (float(sizeZ) * tileSize + tileSize) / 2.0
	return Vector3(xpos, y, -zpos)


## Places a building no player owns (a neutral castle) with its lower left
## corner on tile (x, z), the sandbox place() without a player: the square's
## tiles belong to nobody (mini 255) and share one structure. Returns null
## when a tile is not free.
func place_neutral(def: BuildingDef, x: int, z: int) -> Node3D:
	var square: Array = []
	for dx in def.size:
		for dz in def.size:
			var t = tiles[x + dx][z + dz]
			if U.alive(t.structure) or t.water or t.disabled or U.alive(t.ship):
				return null
			square.append(t)
	var go: Node3D = Catalog.spawn(def)
	var main = tiles[x + 1][z + 1]
	var centre := Vector3.ZERO
	for t in square:
		centre += t.go.global_position
		if t != main:
			t.structure = go
			t.player = null
			set_mini(t.idxX, t.idxZ, 255)
			t.destroy_decorations()
	main.build(go, null)
	go.global_position = Vector3(centre.x / square.size(), 0.0, centre.z / square.size())
	# I115: a randomly placed castle faces a random quarter; the look-only random stream keeps
	# battles and seeded tests unchanged
	go.rotate_y(PI / 2.0 * Art._rng.randi_range(0, 3))
	return go


## Stands one terrain feature (I90) as the structure of every tile of `cells` and the art
## under `go`: nobody owns that ground (mini 255) and every placement rule refuses it until
## the feature falls. The caller sized, positioned and parented `go` and filled its Terrain
## component's tiles; this claims the tiles.
func claim_terrain(go: Node3D, cells: Array) -> void:
	terrain_features.append(go)
	for c in cells:
		var t = tiles[c.x][c.y]
		t.structure = go
		t.player = null
		set_mini(c.x, c.y, 255)
		t.destroy_decorations()


## Frees what claim_terrain took, for a placement rolled back before it stands (I91).
func release_terrain(go: Node3D, cells: Array) -> void:
	terrain_features.erase(go)
	for c in cells:
		var t = tiles[c.x][c.y]
		if t.structure == go:
			t.structure = null
		set_mini(c.x, c.y, 0)
	U.destroy(go)


## Inverse of tile_position(); returns Vector2i(-1, -1) outside of the map.
func tile_index_at(p: Vector3) -> Vector2i:
	var xi := int(roundf((p.x + (float(sizeX) * tileSize + tileSize) / 2.0) / tileSize))
	var zi := int(roundf((-p.z + (float(sizeZ) * tileSize + tileSize) / 2.0) / tileSize))
	if xi < 0 or zi < 0 or xi >= sizeX or zi >= sizeZ:
		return Vector2i(-1, -1)
	return Vector2i(xi, zi)


func make_land_map() -> void:
	_randomize_colors()
	if decorate:
		_randomize_model_makers()
	tiles = []
	miniMap = PackedByteArray()
	miniMap.resize(sizeX * sizeZ)
	for xi in sizeX:
		var col: Array = []
		for zi in sizeZ:
			var rand := U.value()
			var y := lerpf(0.1, -0.1, rand)
			var tgo := U.instantiate(tilePrefab, go)
			Art.swap_mesh(tgo.get_node("Model"), "tile_mud")
			tgo.name = "Tile_%d_%d" % [xi, zi]
			tgo.position = tile_position(xi, zi, y)
			var t := U.comp(tgo, "BuildingPlace")
			t.idxX = xi
			t.idxZ = zi
			t.map = self
			t.enclosedColor = enclosedColorMin.lerp(enclosedColorMax, rand)
			t.openColor = openColorMin.lerp(openColorMax, rand)
			t.wallColor = wallColor
			t.customModelMakers = customModelMakers
			col.append(t)
		tiles.append(col)
		await _step((0.2 if decorate else 1.0) * (xi + 1) / sizeX)
	_smooth_colors()
	statesMap.reset(self)


func _add_decorations() -> void:
	for xi in sizeX:
		for zi in sizeZ:
			if not tiles[xi][zi].water:
				tiles[xi][zi].place_decorations()
		await _step(0.2 + 0.8 * (xi + 1) / sizeX)


## Records the share of the map done; while `staged`, lets a frame through every 50 ms.
func _step(done: float) -> void:
	progress = done
	if staged and Time.get_ticks_msec() - _frame_start > 50:
		await get_tree().process_frame
		_frame_start = Time.get_ticks_msec()


func _smooth_colors() -> void:
	for xi in sizeX:
		for zi in sizeZ:
			var both_odd := (xi & 1) == 1 and (zi & 1) == 1
			if not both_odd:
				_average_tile_color_from_neighbours(xi, zi)


func _sq(c: Color) -> Vector3:
	return Vector3(c.r * c.r, c.g * c.g, c.b * c.b)


func _average_tile_color_from_neighbours(x: int, z: int) -> void:
	var sum_enclosed := Vector3.ZERO
	var sum_open := Vector3.ZERO
	var sum_y := 0.0
	var n := 0
	for xi in range(maxi(0, x - 1), mini(x + 2, sizeX)):
		for zi in range(maxi(0, z - 1), mini(z + 2, sizeZ)):
			if (xi & 1) == 1 and (zi & 1) == 1:
				var t = tiles[xi][zi]
				sum_enclosed += _sq(t.enclosedColor)
				sum_open += _sq(t.openColor)
				sum_y += t.go.position.y
				n += 1
	if n > 1:
		var me := sum_enclosed / n
		var mo := sum_open / n
		var t = tiles[x][z]
		t.enclosedColor = Color(sqrt(me.x), sqrt(me.y), sqrt(me.z))
		t.openColor = Color(sqrt(mo.x), sqrt(mo.y), sqrt(mo.z))
		t.go.position.y = sum_y / n


func is_tile_enclosed(x: int, z: int) -> bool:
	return statesMap.is_closed(x * 3, z * 3)


## For every player, how many of their walls border the enclosed region `tiles`.
func ring_border(tiles: Array) -> Dictionary:
	var border := {}
	for t in tiles:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var x: int = t.idxX + d.x
			var z: int = t.idxZ + d.y
			if x < 0 or z < 0 or x >= sizeX or z >= sizeZ:
				continue
			var n = tiles_at(x, z)
			if n.isWall:
				var bb := U.comp(n.structure, "BuildingBlock")
				if bb != null and U.alive(bb.player):
					border[bb.player] = border.get(bb.player, 0) + 1
	return border


## The one player whose walls border the enclosed region `tiles`; null when none or several do,
## for a ring two factions share closes for neither by itself (D88). StatesMap asks whose walls
## encircle the region alone before it opens a mixed-border region. The check gives the
## region's castles to this player and the ground wears their colour (D79).
func ring_owner(tiles: Array):
	var border := ring_border(tiles)
	return null if border.size() != 1 else border.keys()[0]


func tiles_at(x: int, z: int):
	return tiles[x][z]
