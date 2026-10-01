@tool
class_name CannonBehaviour
extends BuildingBehaviour
## A gun firing ballistic projectiles (component Shooter).

@export var projectile: ProjectileDef
@export var damage := 10.0
@export var min_range := 1.0
@export var max_range := 40.0
## Seconds between shots
@export var reload := 2.0
@export var gravity := 5.0
## Part of the flight spent going up (0..1)
@export_range(0.05, 0.95) var ascending_part := 0.6
## Turns towards the target
@export var turns := true
