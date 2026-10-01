@tool
class_name FlakBehaviour
extends BuildingBehaviour
## Shoots down enemy projectiles (component Flak).

## Projectiles inside this box half size are shot down
@export var shoot_range := 4.0
## Turns towards projectiles inside this distance
@export var look_range := 10.0
## Seconds between two shots
@export var salvo_interval := 2.0
