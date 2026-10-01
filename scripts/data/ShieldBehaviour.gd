@tool
class_name ShieldBehaviour
extends BuildingBehaviour
## Absorbs enemy projectiles in a radius (component ShieldGenerator).

@export var radius := 7.0
## Damage absorbed before the shield breaks
@export var max_absorb := 31.0
## Seconds a broken shield needs to come back; also the time to regenerate fully
@export var reset_time := 4.0
