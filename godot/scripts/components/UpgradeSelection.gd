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
	var standard: PackedScene = null
	var n_tiles: int = cluster.upgradedTiles.size()
	for prefab in upgradePrefabs:
		var sig: Array = _info[prefab][0]
		var default_for_size: bool = _info[prefab][1]
		if not default_for_size and sig.size() == n_tiles \
				and matches_signature(cluster.get_upgrade_signature(), sig, cluster.sideLength):
			return prefab
		elif default_for_size and sig.size() == n_tiles:
			standard = prefab
	if standard != null:
		return standard
	push_error("No matching upgrade prefab found for signature!")
	return null


static func matches_signature(desired: Array, compare: Array, side: int) -> bool:
	var e0 := true
	var e90 := true
	var e180 := true
	var e270 := true
	for row in side:
		for col in side:
			var i000 := row * side + col
			var i090 := (side - 1 - row) + side * col
			var i180 := side * side - 1 - i000
			var i270 := (side - 1 - col) * side + row
			var wild: bool = compare[i000] == -1
			e0 = e0 and (wild or desired[i000] == compare[i000])
			e90 = e90 and (wild or desired[i000] == compare[i090])
			e180 = e180 and (wild or desired[i000] == compare[i180])
			e270 = e270 and (wild or desired[i000] == compare[i270])
	return e0 or e90 or e180 or e270


static func return_matching_rotated_signature(desired: Array, compare: Array, side: int):
	var n := side * side
	var s090: Array = []
	var s180: Array = []
	var s270: Array = []
	s090.resize(n)
	s180.resize(n)
	s270.resize(n)
	var e0 := true
	var e90 := true
	var e180 := true
	var e270 := true
	for row in side:
		for col in side:
			var i000 := row * side + col
			var i090 := (side - 1 - row) + side * col
			var i180 := side * side - 1 - i000
			var i270 := (side - 1 - col) * side + row
			var wild: bool = compare[i000] == -1
			e0 = e0 and (wild or desired[i000] == compare[i000])
			e90 = e90 and (wild or desired[i000] == compare[i090])
			e180 = e180 and (wild or desired[i000] == compare[i180])
			e270 = e270 and (wild or desired[i000] == compare[i270])
			s090[i000] = desired[i090]
			s180[i000] = desired[i180]
			s270[i000] = desired[i270]
	if e0:
		return desired
	elif e90:
		return s090
	elif e180:
		return s180
	elif e270:
		return s270
	return null
