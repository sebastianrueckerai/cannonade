extends Node
## Headless: checks every model in res://assets/art/ against manifest.json. Exit code 1 on a problem.
# godot --headless res://tools/check_art.tscn


func _ready() -> void:
	var problems := Art.validate()
	for p in problems:
		printerr(p)
	print("art: %d models checked, %d problems" % [Art.checked_count(), problems.size()])
	get_tree().quit(1 if problems.size() > 0 else 0)
