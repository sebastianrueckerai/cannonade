extends Control
## Main menu: pick one of the original game modes.

const Main = preload("res://scripts/Main.gd")


func _ready() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(360, 0)
	box.offset_left = -180
	box.offset_right = 180
	box.offset_top = -170
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title := Label.new()
	title.text = "GRID CANNONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)
	for entry in [["single", "Single player (vs. ships)"], ["versus", "Player vs. AI"],
			["ai2", "Watch: AI vs. AI"], ["ai4", "Watch: 4 AIs"]]:
		var b := Button.new()
		b.text = entry[1]
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(_start.bind(entry[0]))
		box.add_child(b)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(0, 36)
	quit.pressed.connect(get_tree().quit)
	box.add_child(quit)


func _start(mode: String) -> void:
	Main.requested_mode = mode
	get_tree().change_scene_to_file("res://scenes/game.tscn")
