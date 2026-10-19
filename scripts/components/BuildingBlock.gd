extends "res://scripts/components/Component.gd"
## Port of BuildingBlock.cs: a placeable block (wall, gun, building) with a
## 3x3 walkability grid used for the enclosed area flood fill.

@export var connectorsUpDownLeftRight: Array = [false, false, false, false]
@export var accessColFromDownLeft: Array = [true, true, true, true, true, true, true, true, true]
@export var probabilityModifier := 1.0
@export var health := 10.0
## Shells survived; each one slows the gun's reload (nothing repairs)
var hits_taken := 0

var buildingPlace = null
var player = null
## accessGrid[x][z], x and z in 0..2
var accessGrid: Array = []:
	get:
		if accessGrid.is_empty():
			setup()
		return accessGrid


func setup() -> void:
	_make_accessable_grid()
	connectorsUpDownLeftRight = connects_up_down_left_right()


func connects(i: int) -> bool:
	var grid := accessGrid
	match i:
		0:
			return grid[1][2] == false
		1:
			return grid[1][0] == false
		2:
			return grid[0][1] == false
		3:
			return grid[2][1] == false
	push_error("BuildingBlock.connects: index out of range")
	return false


func connects_up_down_left_right() -> Array:
	var grid := accessGrid
	return [grid[1][2] == false, grid[1][0] == false, grid[0][1] == false, grid[2][1] == false]


func fits_plan_with_clockwise_rotations_of_input(plan: Array) -> int:
	for i in 4:
		if fits_plan(plan):
			return i
		plan = rotate_plan_clockwise(plan)
	return -1


func rotate_plan_clockwise(plan: Array) -> Array:
	return [plan[2], plan[3], plan[1], plan[0]]


func fits_plan(plan: Array) -> bool:
	var mine := connects_up_down_left_right()
	for i in 4:
		if not (plan[i] == false or mine[i]):
			return false
	return true


func _make_accessable_grid() -> void:
	var a := accessColFromDownLeft
	accessGrid = [[a[0], a[1], a[2]], [a[3], a[4], a[5]], [a[6], a[7], a[8]]]


func _new_grid() -> Array:
	return [[false, false, false], [false, false, false], [false, false, false]]


## Unity: transform.Rotate(0, 90, 0). The z axis is mirrored in this port, so a
## clockwise turn (seen from above) is a negative rotation around Godot's y.
func rotate_clockwise() -> void:
	go.rotate_object_local(Vector3.UP, -PI / 2.0)
	var g := accessGrid
	var n := _new_grid()
	n[0][0] = g[2][0]
	n[1][0] = g[2][1]
	n[2][0] = g[2][2]
	n[0][1] = g[1][0]
	n[1][1] = g[1][1]
	n[2][1] = g[1][2]
	n[0][2] = g[0][0]
	n[1][2] = g[0][1]
	n[2][2] = g[0][2]
	accessGrid = n
	connectorsUpDownLeftRight = connects_up_down_left_right()


func rotate_counter_clockwise() -> void:
	go.rotate_object_local(Vector3.UP, PI / 2.0)
	var g := accessGrid
	var n := _new_grid()
	n[0][0] = g[0][2]
	n[1][0] = g[0][1]
	n[2][0] = g[0][0]
	n[0][1] = g[1][2]
	n[1][1] = g[1][1]
	n[2][1] = g[1][0]
	n[0][2] = g[2][2]
	n[1][2] = g[2][1]
	n[2][2] = g[2][0]
	accessGrid = n
	connectorsUpDownLeftRight = connects_up_down_left_right()
