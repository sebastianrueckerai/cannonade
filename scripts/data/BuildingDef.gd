@tool
class_name BuildingDef
extends Resource
## One building type: model, stats, how it is obtained and what it does.
## Files live in res://data/buildings/<id>.tres; the file name is the id.

enum Category { BUILDING, WALL, BASE, HIDDEN }

@export var display_name := ""
@export_multiline var description := ""
## BUILDING: placed with the right mouse button; WALL: offered as next wall;
## BASE: a player's start base; HIDDEN: only used by other things (e.g. ships)
@export var category := Category.BUILDING
## Scene with the visuals. Behaviours find their parts by node name
## (Barrel, ProjectileSpawn, Progress Bar, Guns, Shield, RocketSpawn).
@export var model: PackedScene
## Side length in tiles (1, 2 or 3)
@export_range(1, 3) var size := 1
@export var health := 10.0
## Walkability of the 3x3 sub cells of a tile, column by column from the lower
## left (x, then z). Empty = everything walkable (no wall).
@export var access: Array[bool] = []
## Resources produced / needed while the building is inside closed walls,
## e.g. {"supply": 4}
@export var produces: Dictionary[String, float] = {}
@export var consumes: Dictionary[String, float] = {}
## Relative chance to be offered as the next building / wall (0 = never)
@export var draw_weight := 0.0

@export_group("Recipe")
## Upgrade pattern: building ids of a size x size square of single tile
## buildings, column by column from the lower left (x, then z); "*" = any.
## Also matches turned by 90 / 180 / 270 degrees (the unturned match wins).
@export var recipe_pattern: PackedStringArray = []
## Used for any square of this size that matches no pattern
@export var recipe_default_for_size := false
## Combination: placing building recipe_combine[0] onto recipe_combine[1]
@export var recipe_combine: PackedStringArray = []

@export_group("Behaviour")
@export var behaviours: Array[BuildingBehaviour] = []

## Set by the catalog: the file name without extension
var id := ""


func label() -> String:
	return display_name if display_name != "" else id


func supply_needed() -> float:
	return consumes.get("supply", 0.0)


func behaviour(type: Script) -> BuildingBehaviour:
	for b in behaviours:
		if b != null and b.get_script() == type:
			return b
	return null
