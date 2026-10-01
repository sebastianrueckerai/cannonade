extends Node
## Loads every script and scene to surface parse errors.
func _walk(dir: String, ext: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_walk(dir.path_join(d), ext, out)
func _ready() -> void:
	var files: Array = []
	_walk("res://scripts", ".gd", files)
	_walk("res://prefabs", ".tscn", files)
	_walk("res://scenes", ".tscn", files)
	var bad := 0
	for f in files:
		var r = load(f)
		if r == null:
			bad += 1
			print("FAILED: ", f)
		elif r is PackedScene:
			var n = r.instantiate()
			if n == null:
				bad += 1
				print("FAILED instantiate: ", f)
			else:
				n.free()
	print("checked %d files, %d failed" % [files.size(), bad])
	get_tree().quit(1 if bad else 0)
