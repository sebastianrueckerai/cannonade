extends "res://scripts/components/Component.gd"
## Port of UpgradeSelection.cs: picks the structure prefab matching the
## signature of an upgrade cluster.

@export var upgradePrefabs: Array = [
	preload("res://prefabs/Cannon22a.tscn"), preload("res://prefabs/Cannon22b.tscn"),
	preload("res://prefabs/Cannon22c.tscn"), preload("res://prefabs/Cannon22d.tscn"),
	preload("res://prefabs/Cannon33a.tscn"), preload("res://prefabs/Cannon33b.tscn"),
	preload("res://prefabs/Cannon33c.tscn"), preload("res://prefabs/RocketStation.tscn"),
	preload("res://prefabs/Flak22.tscn"), preload("res://prefabs/ShieldGen22.tscn"),
	preload("res://prefabs/Supply22.tscn")]

var upgradeName2signature := {}
## prefab -> [signature: Array, defaultForSize: bool]
var _info := {}


func initialize() -> void:
	for prefab in upgradePrefabs:
		var n: Node = prefab.instantiate()
		var us := n.get_node("UpgradedStructure")
		var sig: Array = Array(us.signature)
		_info[prefab] = [sig, us.defaultForSize]
		upgradeName2signature[prefab.resource_path.get_file().get_basename()] = sig
		n.free()


func pick_new_structure_prefab(cluster) -> PackedScene:
	return pick_for_signature(cluster.get_upgrade_signature())


## The structure built from upgrade blocks laid out as `sig` (block types in
## x-major order, -1 = wildcard in a structure signature). A layout matching a
## structure as is wins over a 180 degree match, which wins over a 90 / 270
## degree one: an adjacent pair of b blocks is a supply depot along one axis
## and a Cannon22d along the other (Unity accepted any rotation, so the depot,
## listed after Cannon22d, could never be built).
func pick_for_signature(sig: Array) -> PackedScene:
	var standard: PackedScene = null
	var side := int(sqrt(sig.size()))
	for pass_rotations in [[0], [2], [1, 3]]:
		for prefab in upgradePrefabs:
			var compare: Array = _info[prefab][0]
			if _info[prefab][1] or compare.size() != sig.size():
				continue
			var rots := rotations(compare, side)
			for k in pass_rotations:
				if _fits(rots[k], sig):
					return prefab
	for prefab in upgradePrefabs:
		if _info[prefab][1] and _info[prefab][0].size() == sig.size():
			standard = prefab
	if standard == null:
		push_error("No matching upgrade prefab found for signature!")
	return standard


func prefab_name(prefab: PackedScene) -> String:
	return prefab.resource_path.get_file().get_basename() if prefab else ""


## A layout fits a pattern when every non-wildcard entry is equal.
static func _fits(pattern: Array, layout: Array) -> bool:
	for i in pattern.size():
		if pattern[i] != -1 and layout[i] != -1 and pattern[i] != layout[i]:
			return false
	return true


## sig turned by 0, 90, 180 and 270 degrees (same index maps as the Unity code).
static func rotations(sig: Array, side: int) -> Array:
	var out := [sig.duplicate(), sig.duplicate(), sig.duplicate(), sig.duplicate()]
	for row in side:
		for col in side:
			var i000 := row * side + col
			out[1][i000] = sig[(side - 1 - row) + side * col]
			out[2][i000] = sig[side * side - 1 - i000]
			out[3][i000] = sig[(side - 1 - col) * side + row]
	return out
