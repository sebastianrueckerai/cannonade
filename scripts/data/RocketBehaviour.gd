@tool
class_name RocketBehaviour
extends BuildingBehaviour
## A rocket launcher (component RocketLauncher).

@export var projectile: ProjectileDef
@export var damage := 0.0
@export var min_range := 2.0
@export var max_range := 30.0
@export var reload := 5.0
## Seconds after placing until the first rocket is ready
@export var initial_delay := 3.0
