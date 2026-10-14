extends Node3D
## The plate under a gun model: the gun turns to aim, the plate stays square to the tile grid.
## The plate detaches from the turning subtree (top level) so a re-aim can never swing it, not
## even for one frame (session 11 gate fault: the plate lagged a frame behind every re-aim).
##
## It detaches on every tree entry, not once on ready: a building is spawned, then reparented
## into its tile by BuildingPlace.build(), which moves the root. Freezing the plate on ready left
## it at the spawn spot while the gun moved on, half a tile off on the 2x2 gun (session 11b).
## Re-entering the tree after the reparent re-reads the plate's world transform from the gun
## and freezes it there.


func _enter_tree() -> void:
	top_level = false
	await get_tree().process_frame
	if is_inside_tree():
		top_level = true
