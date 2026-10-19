extends "res://scripts/components/Component.gd"
## A wall block. Stacked on another block, its art turns into the upper storey.


func show_upper() -> void:
	var art := go.get_node_or_null("Art")
	if art != null:
		go.remove_child(art)
		art.free()
	Art.attach(go, "wall_upper")
