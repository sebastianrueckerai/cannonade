extends "res://scripts/components/Component.gd"
## Port of BuildingBlock.cs: a placeable block (wall, gun, building) with a
## 3x3 walkability grid used for the enclosed area flood fill.

@export var accessColFromDownLeft: Array = [true, true, true, true, true, true, true, true, true]
@export var probabilityModifier := 1.0
@export var health := 10.0
## Shells survived; each one slows the gun's reload (nothing repairs)
var hits_taken := 0
## A hand piece's cells, turned with the piece (BuildingDef.piece)
var cells: Array[Vector2i] = []

var buildingPlace = null
var player = null
## accessGrid[x][z], x and z in 0..2
var accessGrid: Array = []:
	get:
		if accessGrid.is_empty():
			setup()
		return accessGrid


func setup() -> void:
	var a := accessColFromDownLeft
	accessGrid = [[a[0], a[1], a[2]], [a[3], a[4], a[5]], [a[6], a[7], a[8]]]


## Unity: transform.Rotate(0, 90, 0). The z axis is mirrored in this port, so a
## clockwise turn (seen from above) is a negative rotation around Godot's y; a
## cell (x, z) goes to (z, -x).
func rotate_clockwise() -> void:
	go.rotate_object_local(Vector3.UP, -PI / 2.0)
	for i in cells.size():
		cells[i] = Vector2i(cells[i].y, -cells[i].x)


func rotate_counter_clockwise() -> void:
	go.rotate_object_local(Vector3.UP, PI / 2.0)
	for i in cells.size():
		cells[i] = Vector2i(-cells[i].y, cells[i].x)
