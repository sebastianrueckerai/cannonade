extends CanvasLayer
## Sandbox user interface: top bar (scenario, match setup, play / speed),
## bottom toolbar (side, tools, buildings), hint line and stats panel.

var sandbox: Node
var _tool_buttons := {}
var _side_buttons: Array = []
var _speed_buttons: Array = []
var _edit_controls: Array = []
var _play: Button
var _run: Button
var _runs: SpinBox
var _lab: Label
var _undo: Button
var _redo: Button
var _scenarios: OptionButton
var _save_name: LineEdit
var _stats: Label
var _status: Label
var _hint: Label
var _message: Label
var _message_until := 0.0


func _ready() -> void:
	layer = 2
	_build_top()
	_build_bottom()
	_build_side_panel()


func _panel(preset: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(preset)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.85)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	# grow into the screen from the anchored edge
	if preset in [Control.PRESET_BOTTOM_WIDE, Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT]:
		p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT]:
		p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	return p


func _button(parent: Node, name: String, text: String, tip: String, cb: Callable, toggle := false) -> Button:
	var b := Button.new()
	b.name = name
	b.text = text
	b.tooltip_text = tip
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _option(parent: Node, name: String, items: Array, tip: String, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.name = name
	o.tooltip_text = tip
	o.focus_mode = Control.FOCUS_NONE
	for it in items:
		o.add_item(str(it))
	o.item_selected.connect(cb)
	parent.add_child(o)
	return o


func _label(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	parent.add_child(l)
	return l


func _build_top() -> void:
	var rows := VBoxContainer.new()
	rows.name = "Top"
	_panel(Control.PRESET_TOP_WIDE).add_child(rows)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	rows.add_child(bar)
	var sizes := _option(bar, "MapSize", ["20 x 20", "30 x 30", "40 x 40"], "Map size for a new layout", func(_i): pass)
	sizes.select(1)
	_edit_controls.append(sizes)
	_edit_controls.append(_button(bar, "New", "New", "Start a new layout with the chosen map size",
			func(): sandbox.new_scenario([20, 30, 40][sizes.selected])))
	_scenarios = _option(bar, "Scenarios", [], "Saved layouts (yours and examples)", func(_i): pass)
	_edit_controls.append(_scenarios)
	_edit_controls.append(_button(bar, "Load", "Load", "Load the selected layout", _on_load))
	_save_name = LineEdit.new()
	_save_name.name = "SaveName"
	_save_name.placeholder_text = "name"
	_save_name.custom_minimum_size = Vector2(110, 0)
	bar.add_child(_save_name)
	_edit_controls.append(_save_name)
	_edit_controls.append(_button(bar, "Save", "Save", "Save the layout under this name", _on_save))
	bar.add_child(VSeparator.new())
	_undo = _button(bar, "Undo", "Undo", "Undo (Ctrl+Z)", func(): sandbox.undo())
	_redo = _button(bar, "Redo", "Redo", "Redo (Ctrl+Y)", func(): sandbox.redo())
	bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	rows.add_child(bar)
	var m := _option(bar, "Match", sandbox.MATCHES, "Who fights: you always play blue",
			func(i): sandbox.match_index = i)
	_edit_controls.append(m)
	for s in 2:
		_label(bar, "%s shoots at" % sandbox.SIDE_NAMES[s])
		var t := _option(bar, "Target%s" % sandbox.SIDE_NAMES[s], sandbox.TARGETS,
				"What the %s AI aims at" % sandbox.SIDE_NAMES[s], func(i): sandbox.targets[s] = sandbox.TARGETS[i])
		_edit_controls.append(t)
	_label(bar, "Max s")
	var tl := SpinBox.new()
	tl.name = "TimeLimit"
	tl.min_value = 10
	tl.max_value = 3600
	tl.step = 10
	tl.value = sandbox.time_limit
	tl.tooltip_text = "Time limit of a battle in seconds"
	tl.value_changed.connect(func(v): sandbox.time_limit = v)
	bar.add_child(tl)
	_edit_controls.append(tl)
	bar.add_child(VSeparator.new())
	_play = _button(bar, "Play", "Play", "Start the battle / back to editing", _on_play)
	for i in sandbox.SPEEDS.size():
		var v: float = sandbox.SPEEDS[i]
		var b := _button(bar, "Speed%d" % i, "Pause" if v == 0 else "%dx" % v, "Battle speed",
				func(): sandbox.set_speed(v); refresh(), true)
		_speed_buttons.append(b)
	bar.add_child(VSeparator.new())
	_runs = SpinBox.new()
	_runs.name = "Runs"
	_runs.min_value = 1
	_runs.max_value = 500
	_runs.value = 20
	_runs.tooltip_text = "How many seeds the Run button plays"
	bar.add_child(_runs)
	_run = _button(bar, "Run", "Run", "Play this layout in the background with seeds 1, 2, 3, ... and the " +
			"match settings, at normal speed, and show win rates. Each seed is played twice, the second time " +
			"with the two layouts swapped, so the side that happens to act first gets no edge; " +
			"results are per layout", _on_run)
	_runs.value_changed.connect(func(_v): refresh())


func _build_bottom() -> void:
	var p := _panel(Control.PRESET_BOTTOM_WIDE)
	var v := VBoxContainer.new()
	p.add_child(v)
	_hint = Label.new()
	_hint.name = "Hint"
	v.add_child(_hint)
	var bar := HFlowContainer.new()
	bar.name = "Tools"
	v.add_child(bar)
	for s in 2:
		var b := _button(bar, "Side%s" % sandbox.SIDE_NAMES[s], sandbox.SIDE_NAMES[s],
				"Place for %s (key %d)" % [sandbox.SIDE_NAMES[s], s + 1], func(): sandbox.side = s; refresh(), true)
		b.add_theme_color_override("font_color", Color.html(sandbox.SIDE_COLORS[s]).lightened(0.35))
		b.add_theme_color_override("font_pressed_color", Color.html(sandbox.SIDE_COLORS[s]).lightened(0.6))
		_side_buttons.append(b)
	_tool("wall", "Wall", "Click and drag to draw walls", bar)
	_tool("erase", "Erase", "Remove what is under the cursor (right mouse button erases too)", bar)
	_edit_controls.append(_button(bar, "Mirror", "Mirror", "Copy this side's layout to the other side, " +
			"mirrored top to bottom (replaces the other side; Ctrl+Z undoes)", func(): sandbox.mirror(sandbox.side)))
	var base: BuildingDef = Catalog.base_def()
	if base != null:
		_tool(base.id, "Castle", "Move this side's castle", bar)
	for id in Catalog.ids:
		var d: BuildingDef = Catalog.defs[id]
		if d.category != BuildingDef.Category.BUILDING:
			continue
		var tip := d.label()
		if d.description != "":
			tip += "\n" + d.description
		tip += "\n%dx%d, health %d" % [d.size, d.size, d.health]
		if d.supply_needed() > 0:
			tip += ", needs %d supply" % d.supply_needed()
		if d.produces.get("supply", 0.0) > 0:
			tip += ", gives %d supply" % d.produces["supply"]
		_tool(id, d.label(), tip, bar)


func _tool(id: String, text: String, tip: String, bar: Node) -> void:
	var b := _button(bar, "Tool_" + id, text, tip, func(): sandbox.tool = id; refresh(), true)
	_tool_buttons[id] = b
	_edit_controls.append(b)


func _build_side_panel() -> void:
	var p := _panel(Control.PRESET_TOP_RIGHT)
	p.offset_top = 92
	var v := VBoxContainer.new()
	p.add_child(v)
	_status = Label.new()
	_status.name = "Status"
	_status.add_theme_font_size_override("font_size", 18)
	v.add_child(_status)
	_stats = Label.new()
	_stats.name = "Stats"
	v.add_child(_stats)
	_lab = Label.new()
	_lab.name = "Lab"
	_lab.add_theme_font_override("font", _mono())
	_lab.add_theme_font_size_override("font_size", 13)
	v.add_child(_lab)
	_message = Label.new()
	_message.name = "Message"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(280, 0)
	v.add_child(_message)


func _mono() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["monospace", "DejaVu Sans Mono", "Consolas", "Menlo"])
	return f


func show_message(text: String, seconds := 4.0) -> void:
	_message.text = text
	_message_until = Time.get_ticks_msec() / 1000.0 + seconds


func _on_play() -> void:
	if sandbox.mode == sandbox.Mode.EDIT:
		sandbox.play()
	else:
		sandbox.reset()


func _on_run() -> void:
	if sandbox.lab_pid > 0:
		sandbox.stop_lab()
	else:
		sandbox.run_lab(int(_runs.value))
	refresh()


func _on_save() -> void:
	var path: String = sandbox.save(_save_name.text)
	show_message("Saved to %s" % path if path != "" else "Type a name first")
	refresh()


func _on_load() -> void:
	if _scenarios.selected < 0:
		return
	var path: String = _scenarios.get_item_metadata(_scenarios.selected)
	if not sandbox.load_scenario(path):
		show_message("Could not read %s" % path)


## Syncs buttons with the sandbox state.
func refresh() -> void:
	var editing: bool = sandbox.mode == sandbox.Mode.EDIT
	for c in _edit_controls:
		if c is BaseButton:
			c.disabled = not editing
		elif c is LineEdit:
			c.editable = editing
		elif c is SpinBox:
			c.editable = editing
	for id in _tool_buttons:
		_tool_buttons[id].set_pressed_no_signal(sandbox.tool == id)
	for s in 2:
		_side_buttons[s].set_pressed_no_signal(sandbox.side == s)
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(not editing and sandbox.speed == sandbox.SPEEDS[i])
		_speed_buttons[i].disabled = editing
	_undo.disabled = not editing or sandbox.undo_stack.is_empty()
	_redo.disabled = not editing or sandbox.redo_stack.is_empty()
	_play.text = "Play" if editing else "Back to editing"
	_run.text = "Stop" if sandbox.lab_pid > 0 else "Run %d seeds" % int(_runs.value)
	_run.disabled = not editing and sandbox.lab_pid <= 0
	var current := ""
	if _scenarios.selected >= 0:
		current = _scenarios.get_item_metadata(_scenarios.selected)
	_scenarios.clear()
	for path in sandbox.saved_scenarios():
		var label: String = path.get_file().get_basename()
		if path.begins_with(sandbox.EXAMPLE_DIR):
			label = "example: " + label
		_scenarios.add_item(label)
		_scenarios.set_item_metadata(_scenarios.item_count - 1, path)
		if path == current:
			_scenarios.select(_scenarios.item_count - 1)
	var tool_text := "Wall: click and drag to draw walls" if sandbox.tool == "wall" else \
			"Erase: click or drag over things to remove them" if sandbox.tool == "erase" else \
			"Click to place %s (R rotates)" % Catalog.get_def(sandbox.tool).label()
	_hint.text = ("Placing for %s – %s · right mouse button erases · Ctrl+Z undo · keys 1 / 2 switch side · wheel zoom, middle mouse pans" % [sandbox.SIDE_NAMES[sandbox.side], tool_text]) if editing else \
			"Battle – watch, or play blue: aim with the mouse, Space fires · Back to editing restores the layout"


## Per frame: status line and stats.
func update_live() -> void:
	if Time.get_ticks_msec() / 1000.0 > _message_until:
		_message.text = "" if Catalog.errors.is_empty() else "Building data problems:\n" + "\n".join(Catalog.errors)
	_lab.text = sandbox.lab_result
	var g = sandbox.game
	if g == null:
		return
	match sandbox.mode:
		sandbox.Mode.EDIT:
			_status.text = "Editing"
		sandbox.Mode.BATTLE:
			_status.text = "Battle  %d s" % int(sandbox.battle_time())
		sandbox.Mode.ENDED:
			_status.text = ("%s wins after %d s" % [sandbox.SIDE_NAMES[sandbox.winner], int(sandbox.battle_time())]) \
					if sandbox.winner < 2 else ("Time up after %d s" if sandbox.battle_time() >= sandbox.time_limit
					else "Draw: no side has a working gun (%d s)") % int(sandbox.battle_time())
	var lines: Array[String] = []
	for s in 2:
		var p = g.players[s]
		var st: Dictionary = p.stats
		lines.append("%s%s" % [sandbox.SIDE_NAMES[s], "  (you)" if not p.has_method("search_best_building_plans") else ""])
		lines.append("  guns %d   walls %d" % [p.cannons.size(), p.wallTiles.size()])
		lines.append("  parts %d / %d   castles %d" % [p.parts_used(), p.partsCap, p.castle_count()])
		if sandbox.mode != sandbox.Mode.EDIT:
			lines.append("  shots %d   hits %d" % [st.get("shots", 0), st.get("hits", 0)])
			lines.append("  intercepted %d   absorbed %d" % [st.get("intercepted", 0), st.get("absorbed", 0)])
			lines.append("  lost: walls %d  guns %d  castles %d  other %d" % [st.get("walls_lost", 0), st.get("guns_lost", 0), st.get("castles_lost", 0), st.get("buildings_lost", 0)])
	_stats.text = "\n".join(lines)
