@tool
class_name WallBehaviour
extends BuildingBehaviour
## Wall piece models (component Wall): one random model is shown when built
## on the ground (lower) or stacked on another wall (upper).

@export var lower_models: Array[PackedScene] = []
@export var upper_models: Array[PackedScene] = []
