extends "res://scripts/components/Component.gd"
## Port of Wall.cs: swaps the placeholder for a random lower or upper wall model.

@export var lowerPrefabs: Array = []
@export var upperPrefabs: Array = []
@export var placeholderModel: NodePath

var modelUpper: Node3D
var modelLower: Node3D


func _remove_placeholder() -> void:
	var p := get_node_or_null(placeholderModel)
	if p != null and p != go:
		U.destroy(p)


func show_upper() -> void:
	_remove_placeholder()
	modelUpper = U.instantiate(upperPrefabs[U.rint(0, upperPrefabs.size())], go)


func show_lower() -> void:
	_remove_placeholder()
	modelLower = U.instantiate(lowerPrefabs[U.rint(0, lowerPrefabs.size())], go)
