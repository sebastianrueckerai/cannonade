@tool
class_name WallBehaviour
extends BuildingBehaviour
## Marks a def as a wall block (component Wall). The model arrays hold the per-tile looks of the
## parked connector walls; the live block wears its art by id (Art.attach).

@export var lower_models: Array[PackedScene] = []
@export var upper_models: Array[PackedScene] = []
