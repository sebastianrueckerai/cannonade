extends Control
## Loading screen. Loading.go(path) from anywhere: shows a bar while the scene loads in the background.

static var next_scene := ""
var _bar: ProgressBar


static func go(path: String) -> void:
	next_scene = path
	(Engine.get_main_loop() as SceneTree).change_scene_to_file("res://scenes/loading.tscn")


func _ready() -> void:
	theme = Art.theme()
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.16, 0.22)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.set_anchors_preset(PRESET_CENTER)
	box.grow_horizontal = GROW_DIRECTION_BOTH
	box.grow_vertical = GROW_DIRECTION_BOTH
	var label := Label.new()
	label.text = "Loading"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(360, 24)
	_bar.show_percentage = false
	box.add_child(_bar)
	add_child(box)
	if next_scene.is_empty():
		push_error("Loading: no next_scene set, use Loading.go(path)")
		set_process(false)
		return
	ResourceLoader.load_threaded_request(next_scene)


func _process(_delta: float) -> void:
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(next_scene, progress)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_bar.value = progress[0] * 100.0
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		_bar.value = 100.0
		set_process(false)
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(next_scene))
	else:
		push_error("Loading: %s failed with status %d" % [next_scene, status])
		set_process(false)
