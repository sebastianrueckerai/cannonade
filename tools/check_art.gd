extends Node
## Headless: checks every model in res://assets/art/ against manifest.json. Exit code 1 on a problem.
# godot --headless res://tools/check_art.tscn


func _ready() -> void:
	var problems := Art.validate()
	problems.append_array(flat_problems())
	for p in problems:
		printerr(p)
	print("art: %d models checked, %d problems" % [Art.checked_count(), problems.size()])
	get_tree().quit(1 if problems.size() > 0 else 0)


## Flat everywhere (C22): no shipped model carries a baked texture, embedded in its glb or as a
## file beside them.
func flat_problems() -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open("res://assets/art/3d")
	if dir == null:
		return ["no art layer at res://assets/art/3d"]
	for f in dir.get_files():
		var ext := f.get_extension()
		if ext in ["png", "jpg", "jpeg", "webp"]:
			found.append("assets/art/3d/%s: a baked texture beside the models (C22)" % f)
		elif ext == "glb":
			var bytes := FileAccess.get_file_as_bytes("res://assets/art/3d/" + f)
			var meta := bytes.slice(20, 20 + bytes.decode_u32(12)).get_string_from_utf8()
			if meta.contains("mimeType"):
				found.append("assets/art/3d/%s: a baked texture inside the model (C22)" % f)
	return found
