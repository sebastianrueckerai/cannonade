extends Node3D
## The plate under a gun model: the gun turns to aim, the plate stays square to the tile grid.
## The plate detaches from the turning subtree (top level): its world transform is fixed once,
## so a re-aim can never swing it, not even for one frame (session 11 gate fault: the plate
## lagged a frame behind every re-aim and visibly rotated with the gun).


func _ready() -> void:
	top_level = true
