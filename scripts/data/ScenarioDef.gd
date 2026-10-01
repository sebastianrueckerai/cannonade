@tool
class_name ScenarioDef
extends Resource
## A sandbox setup: map size and what each side has placed. Saved in
## user://scenarios/ (own) or res://data/scenarios/ (examples).

@export var map_size := 30
## Seed for the map (terrain colours, decorations) and the battle
@export var seed := 1
@export_multiline var description := ""
## Placed things, in placement order:
## {"side": 0 (blue) / 1 (red), "id": building id, "x": int, "z": int, "rot": int}
## (x, z) is the lower left tile; rot = quarter turns (buildings only; walls get
## their shape from their neighbours).
@export var items: Array[Dictionary] = []
