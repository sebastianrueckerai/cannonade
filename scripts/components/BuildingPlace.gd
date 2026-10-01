extends "res://scripts/components/Component.gd"
## Port of BuildingPlace.cs: one tile of the map.

@export var customModelMakers: Array = []
@export var tileModel: NodePath
@export var lineRenderer: NodePath

## GameObject (Node3D) of the building / wall built here
var structure: Node3D = null
var wallStacked: Node3D = null
var ship = null
var commingShip = null
var upgradeCluster = null
var idxX := 0
var idxZ := 0
var player = null
var map = null
var burning := false
var shaking := false
var water := false
var isWall := false
## hit by a tile destroying rocket (Unity disabled renderers and colliders)
var disabled := false
var enclosedColor := Color.WHITE
var openColor := Color.WHITE
var wallColor := Color.WHITE

var shakeSecondsPassed := 0.0
var shakeDuration := 4.0
var shakeMagnitude := 1.0
var shakeDirection := false
var shakeUntil := 0.0
var burnUntil := 0.0
var decorations: Array = []


func _ready() -> void:
	line().enabled = false
	make_highlight_shape()


func line():
	return get_node(lineRenderer)


func model() -> MeshInstance3D:
	return get_node(tileModel) as MeshInstance3D


func block():
	return U.comp(structure, "BuildingBlock")


func buildable() -> bool:
	return not burning and not water and not shaking and not disabled


func connects_up_down_left_right(direction: int) -> bool:
	if not U.alive(structure):
		return false
	return block().connects(direction)


func damage_building_place(damage: float) -> void:
	if U.alive(ship):
		ship.damage(damage)
	elif U.alive(wallStacked):
		damage_stacked_wall(damage)
	elif upgradeCluster != null:
		upgradeCluster.damage_structure(damage)
	elif U.alive(structure):
		damage_structure(damage)


func destroy_decorations() -> void:
	for d in decorations:
		U.destroy(d)
	decorations = []


func damage_structure(damage: float) -> void:
	var bb = block()
	if bb != null:
		bb.health -= damage
		if bb.health <= 0:
			un_build()


func damage_stacked_wall(damage: float) -> void:
	var bb = U.comp(wallStacked, "BuildingBlock")
	if bb != null:
		bb.health -= damage
		if bb.health <= 0:
			_destroy_stacked_wall()


func _destroy_stacked_wall() -> void:
	U.destroy(wallStacked)
	wallStacked = null


func un_build() -> void:
	map.set_mini(idxX, idxZ, 0)
	var bb = block()
	if bb != null and U.alive(bb.player):
		bb.player.remove_building_from_player(bb)
	U.destroy(structure)
	if U.alive(wallStacked):
		_destroy_stacked_wall()
	structure = null
	player = null
	isWall = false
	map.statesMap.update_tile(self)



func build(building: Node3D, p) -> void:
	var bb = U.comp(building, "BuildingBlock")
	var wall := U.comp(building, "Wall")
	isWall = wall != null
	if isWall:
		wall.show_lower()
	bb.player = p
	bb.buildingPlace = self
	U.set_parent(building, go)
	player = p
	structure = building
	map.set_mini(idxX, idxZ, p.playerID)
	map.statesMap.update_tile(self)
	destroy_decorations()


func stack_wall(wall_go: Node3D) -> void:
	U.set_parent(wall_go, go)
	wall_go.position = Vector3.ZERO
	var bb = U.comp(wall_go, "BuildingBlock")
	bb.buildingPlace = self
	wallStacked = wall_go
	U.comp(wall_go, "Wall").show_upper()


func highlight_off() -> void:
	line().enabled = false


func highlight_on(color: Color) -> void:
	line().color = color
	line().enabled = true


func make_highlight_shape() -> void:
	var e := Vector3(0.5, 0.1, 0.5)  # extents of the tile collider
	var y := e.y / 2.0 + 0.1
	line().set_positions(PackedVector3Array([
		Vector3(-e.x, y, -e.z), Vector3(e.x, y, -e.z), Vector3(e.x, y, e.z), Vector3(-e.x, y, e.z)]))


func count_neighbouring_walls() -> int:
	var count := 0
	for xi in range(maxi(0, idxX - 1), mini(map.sizeX, idxX + 1)):
		for zi in range(maxi(0, idxZ - 1), mini(map.sizeZ, idxZ + 1)):
			if map.tiles[xi][zi].isWall:
				count += 1
	return count


func get_surrounding_tiles(r: int) -> Array:
	var out: Array = []
	for xi in range(maxi(0, idxX - r), mini(idxX + r, map.sizeX - 1) + 1):
		for zi in range(maxi(0, idxZ - r), mini(idxZ + r, map.sizeZ - 1) + 1):
			out.append(map.tiles[xi][zi])
	return out


func set_on_fire(burn_for_seconds: float) -> void:
	burning = true
	burnUntil = U.time + burn_for_seconds
	set_tile_color(Color.RED)


func reset_color(enclosed = null) -> void:
	if enclosed == null:
		enclosed = map.is_tile_enclosed(idxX, idxZ)
	var c := wallColor
	if not isWall:
		c = enclosedColor if enclosed else openColor
	set_tile_color(c)


var _applied_color = null


## Colour of the tile slab (skips the material write when nothing changes).
func set_tile_color(c: Color) -> void:
	if _applied_color == c:
		return
	_applied_color = c
	U.set_color(model(), c)


func shake(duration: float) -> void:
	shakeDuration = duration
	shakeSecondsPassed = 0.0
	shaking = true
	shakeDirection = U.rint(0, 2) <= 0
	shakeMagnitude = U.rfloat(0.5, 1.5)
	shakeUntil = U.time + duration


func _process(delta: float) -> void:
	if burning and U.time >= burnUntil:
		reset_color()
		burning = false
	if shaking:
		if U.time >= shakeUntil:
			shaking = false
			go.position.y = 0.0
			return
		shakeSecondsPassed += delta
		var sgn := -1.0 if shakeDirection else 1.0
		var rads := PI * shakeSecondsPassed * 2.0
		var scale := (shakeSecondsPassed - shakeDuration / 2.0) / (shakeDuration / 2.0)
		go.position.y = sin(rads) * (1.0 - scale * scale) * shakeMagnitude * sgn


func place_decorations() -> void:
	var min_dist := 0.1
	var max_step_dist := 0.3
	var max_deco := 6
	var max_tries := 1000
	if customModelMakers.is_empty():
		return
	var rand_indices := U.shuffle_index(customModelMakers.size())
	var n_tries := 0
	var n_placed := 0
	var n_batch := 0
	var n_place_here := 0 if U.value() < 0.35 else U.rint(1, max_deco)
	var max_batch := U.rint(0, n_place_here)
	var maker = customModelMakers[rand_indices[n_batch]]
	while n_tries < max_tries and n_placed < n_place_here:
		n_tries += 1
		if n_batch == max_batch:
			n_batch = 0
			maker = customModelMakers[rand_indices[n_batch]]
			max_batch = U.rint(0, n_place_here - n_placed)
		var next_try: Vector3
		if n_batch == 0 or decorations.is_empty():
			next_try = Vector3(U.rfloat(-0.5 + min_dist / 2.0, 0.5 - min_dist / 2.0), 0.1,
					U.rfloat(-0.5 + min_dist / 2.0, 0.5 - min_dist / 2.0))
		else:
			var last_pos: Vector3 = decorations[-1].position
			var dir := Vector3(U.rfloat(-1.0, 1.0), 0.1, U.rfloat(-1.0, 1.0))
			dir = dir.normalized() * U.rfloat(min_dist, max_step_dist)
			next_try = last_pos + dir
			next_try.y = 0.1
		if _can_deco_be_placed(next_try):
			var deco: Node3D = maker.get_randomized_model(go)
			deco.position = next_try
			U.set_shadows(deco, false)
			decorations.append(deco)
			n_placed += 1
			n_batch += 1


func _can_deco_be_placed(p: Vector3, border := 0.05, min_dist := 0.1) -> bool:
	if p.x > 0.5 - border or p.z > 0.5 - border or p.x < -0.5 + border or p.z < -0.5 + border:
		return false
	for d in decorations:
		if d.position.distance_to(p) < min_dist:
			return false
	return true
