extends CanvasLayer
## Loading screen. Loading.go(path) from anywhere: loads the scene in the background, adds it underneath and, when
## the scene builds in steps (Main: `staged`, `progress`, `built`), shows its progress until it is built. Behind the
## bar one piece of concept art from the art layer, ui/loading.png and its numbered looks, a new pick every time.

static var next_scene := ""
var _bar: ProgressBar
var _scene: Node = null


static func go(path: String) -> void:
	next_scene = path
	(Engine.get_main_loop() as SceneTree).change_scene_to_file("res://scenes/loading.tscn")


func _ready() -> void:
	var screen := Control.new()
	screen.theme = Art.theme()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.16, 0.22)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(bg)
	var art := Art.texture_look("loading")
	if art != null:
		var tr := TextureRect.new()
		tr.texture = art
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen.add_child(tr)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM if art != null else Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN if art != null else Control.GROW_DIRECTION_BOTH
	if art != null:
		panel.position.y -= 48
	screen.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var label := Label.new()
	label.text = "Loading"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(360, 24)
	_bar.show_percentage = false
	box.add_child(_bar)
	if next_scene.is_empty():
		push_error("Loading: no next_scene set, use Loading.go(path)")
		set_process(false)
		return
	ResourceLoader.load_threaded_request(next_scene)


## Nothing reaches the scene being built underneath.
func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _scene != null:
		_bar.value = _scene.progress * 100.0
		return
	var status := ResourceLoader.load_threaded_get_status(next_scene)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_scene = (ResourceLoader.load_threaded_get(next_scene) as PackedScene).instantiate()
		var staged := "staged" in _scene
		if staged:
			_scene.staged = true
			_scene.built.connect(queue_free)
		get_tree().root.add_child(_scene)
		get_tree().current_scene = _scene
		if not staged:
			queue_free()
	elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		push_error("Loading: %s failed with status %d" % [next_scene, status])
		set_process(false)
