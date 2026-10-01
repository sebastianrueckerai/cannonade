extends "res://scripts/components/Component.gd"
## Port of Map.cs: creates the tile grid, water, colours and decorations.

const StatesMap = preload("res://scripts/StatesMap.gd")

@export var sizeX := 20
@export var sizeZ := 20
@export var tileSize := 1.0
@export var tilePrefab: PackedScene = preload("res://prefabs/Slab.tscn")
@export var wallPrefabs: Array = [
	preload("res://prefabs/BlockCorner.tscn"), preload("res://prefabs/BlockCross.tscn"),
	preload("res://prefabs/BlockLine.tscn"), preload("res://prefabs/BlockThree.tscn")]
@export var maxEnclosedColors: Array = [Color(0.26415092, 0.26415092, 0.26415092)]
@export var minEnclosedColors: Array = [Color(0.4339623, 0.43191528, 0.43191528)]
@export var maxOpenColors: Array = [Color(0.41509432, 0.29819083, 0.064613745), Color(0.095318615, 0.3207547, 0.11725227)]
@export var minOpenColors: Array = [Color(0.5849056, 0.46994776, 0.24003203), Color(0.2763439, 0.509434, 0.30045664)]
@export var waterColorMin := Color(0.0729797, 0.3115482, 0.3773585)
@export var waterColorMax := Color(0.22160912, 0.5287073, 0.5660378)
@export var wallColor := Color(0.1509434, 0.1502314, 0.1502314)
@export var customModelMakerPrefabs: Array = [
	preload("res://prefabs/Maker_BigLeafTree.tscn"), preload("res://prefabs/Maker_Boulder.tscn"),
	preload("res://prefabs/Maker_Bush.tscn"), preload("res://prefabs/Maker_Evergreen.tscn"),
	preload("res://prefabs/Maker_Grass.tscn"), preload("res://prefabs/Maker_LeafTree.tscn"),
	preload("res://prefabs/Maker_Mushroom.tscn"), preload("res://prefabs/Maker_Stones.tscn"),
	preload("res://prefabs/Maker_Twiggy.tscn")]
@export var buildingRange := 2
@export var maxModelTypes := 4
## Set to false to skip decorations (faster headless simulations).
@export var decorate := true

var game = null
var enclosedColorMin: Color
var enclosedColorMax: Color
var openColorMin: Color
var openColorMax: Color
## tiles[x][z] -> BuildingPlace component
var tiles: Array = []
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


func _tile_to_water(x: int, z: int) -> void:
	var c := waterColorMin.lerp(waterColorMax, U.value())
	var t = tiles[x][z]
	t.go.position.y = -0.1
	t.water = true
	t.enclosedColor = c
	t.openColor = c


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
	make_land_map()
	_set_water_areas(players.size())
	if decorate:
		_add_decorations()
	statesMap.reset(self)
	statesMap.update_open_closed_spaces()


## World position of the centre of tile (x, z). Unity's z axis is mirrored.
func tile_position(xi: int, zi: int, y := 0.0) -> Vector3:
	var xpos := tileSize * xi - (float(sizeX) * tileSize + tileSize) / 2.0
	var zpos := tileSize * zi - (float(sizeZ) * tileSize + tileSize) / 2.0
	return Vector3(xpos, y, -zpos)


## Inverse of tile_position(); returns Vector2i(-1, -1) outside of the map.
func tile_index_at(p: Vector3) -> Vector2i:
	var xi := int(roundf((p.x + (float(sizeX) * tileSize + tileSize) / 2.0) / tileSize))
	var zi := int(roundf((-p.z + (float(sizeZ) * tileSize + tileSize) / 2.0) / tileSize))
	if xi < 0 or zi < 0 or xi >= sizeX or zi >= sizeZ:
		return Vector2i(-1, -1)
	return Vector2i(xi, zi)


func make_land_map() -> void:
	_randomize_colors()
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
	_smooth_colors()
	statesMap.reset(self)


func _add_decorations() -> void:
	for xi in sizeX:
		for zi in sizeZ:
			if not tiles[xi][zi].water:
				tiles[xi][zi].place_decorations()


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
