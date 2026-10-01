extends "res://scripts/components/Component.gd"
## Port of Combinable.cs: which upgrade types can be combined into which prefab.

@export var upgradeTypes := PackedInt32Array()
@export var CombinationPrefabs: Array = []

var upgradeType2CombinationPrefabs := {}


func _ready() -> void:
	if upgradeTypes.size() != CombinationPrefabs.size():
		push_error("For each upgrade type, a prefab needed!")
	for i in mini(upgradeTypes.size(), CombinationPrefabs.size()):
		upgradeType2CombinationPrefabs[upgradeTypes[i]] = CombinationPrefabs[i]
