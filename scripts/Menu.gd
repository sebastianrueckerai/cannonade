extends Control
## Main menu: pick one of the original game modes. Background and title come from the art layer when present.

const Main = preload("res://scripts/Main.gd")
const Loading = preload("res://scripts/Loading.gd")


func _ready() -> void:
	theme = Art.theme()
	var bg := Art.texture("menu_background.png")
	if bg != null:
		var tr := TextureRect.new()
		tr.texture = bg
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		add_child(tr)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.grow_horizontal = GROW_DIRECTION_BOTH
	panel.grow_vertical = GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var logo := Art.texture("logo.png")
	if logo != null:
		var tr := TextureRect.new()
		tr.texture = logo
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(360, 120)
		box.add_child(tr)
	else:
		var title := Label.new()
		title.text = "CANNONADE"
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
	var sandbox := Button.new()
	sandbox.text = "Sandbox (build & test battles)"
	sandbox.custom_minimum_size = Vector2(0, 44)
	sandbox.pressed.connect(func(): Loading.go("res://scenes/sandbox.tscn"))
	box.add_child(sandbox)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(0, 36)
	quit.pressed.connect(get_tree().quit)
	box.add_child(quit)
	var errors: Array[String] = []
	errors.append_array(Catalog.errors)
	errors.append_array(Art.validate())
	if not errors.is_empty():
		var problems := Label.new()
		problems.text = "Problems in data/buildings or assets/art:\n" + "\n".join(errors)
		problems.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
		problems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(problems)


func _start(mode: String) -> void:
	Main.requested_mode = mode
	Loading.go("res://scenes/game.tscn")
