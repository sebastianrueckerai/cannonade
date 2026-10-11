extends Control
## First scene: the splash image from the art layer, or a plain mark and the title, then the menu.

const SECONDS := 1.5
var _left := false


func _ready() -> void:
	theme = Art.theme()
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.16, 0.22)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var tex := Art.texture("splash.png")
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		add_child(tr)
	else:
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 24)
		box.set_anchors_preset(PRESET_CENTER)
		box.grow_horizontal = GROW_DIRECTION_BOTH
		box.grow_vertical = GROW_DIRECTION_BOTH
		var mark := ColorRect.new()
		mark.color = Color(0.89, 0.68, 0.46)
		mark.custom_minimum_size = Vector2(96, 96)
		mark.size_flags_horizontal = SIZE_SHRINK_CENTER
		box.add_child(mark)
		var title := Label.new()
		title.text = "GRID CANNONS"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 44)
		box.add_child(title)
		add_child(box)
	get_tree().create_timer(SECONDS).timeout.connect(_done)


func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		_done()


func _done() -> void:
	if _left:
		return
	_left = true
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
