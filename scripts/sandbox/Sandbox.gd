extends Node
## Sandbox: set up two castles (blue and red) with walls and buildings, then
## press Play to watch a battle (no building phase) and compare setups.
##
## The editor and each battle run in their own game world (a Main node built
## from a config). The layout lives in the world; snapshot() turns it into a
## list of items (ScenarioDef.items) for undo, saving and starting battles.

const Main = preload("res://scripts/Main.gd")
const SandboxUI = preload("res://scripts/sandbox/SandboxUI.gd")

const SIDE_COLORS := ["#2a4fbf", "#b8322a"]
const SIDE_NAMES := ["Blue", "Red"]
const MATCHES := ["AI vs AI", "Player vs AI", "Player vs dormant AI", "AI vs dormant AI"]
const TARGETS := ["walls", "guns", "castles", "supply", "random"]
const SPEEDS := [0.0, 1.0, 2.0, 4.0, 8.0]
const USER_DIR := "user://scenarios"
const EXAMPLE_DIR := "res://data/scenarios"
const LAB_DIR := "user://lab"

enum Mode { EDIT, BATTLE, ENDED }

signal battle_ended(winner: int)

var world: Node = null
var game = null
var map = null
var mode := Mode.EDIT
## the layout being edited (also what Reset returns to)
var scenario := ScenarioDef.new()
var side := 0
## "wall", "erase", the base def's id ("castle") or a building id
var tool := "wall"
var rot := 0
var match_index := 0
var targets := ["walls", "walls"]
var time_limit := 180.0
## the side that never fires in the "dormant" match setups
var dormant_side := 1
var speed := 1.0
var undo_stack: Array = []
var redo_stack: Array = []
var battle_start := 0.0
## -1 = running, 0 / 1 = winner side, 2 = draw / time up
var winner := -1
var ui: SandboxUI
## grass and trees on the map (the battle lab turns them off)
var decorate := true

## background battle lab run (Run button): process id, or -1
var lab_pid := -1
var lab_result := ""

var _hover := Vector2i(-1, -1)
var _stroke_before = null
var _drag_button := 0
var _ghost: Node3D = null
var _ghost_tool := ""
var _footprint: MeshInstance3D = null
var _poll_timer := 0.0


func _ready() -> void:
	ui = SandboxUI.new()
	ui.sandbox = self
	add_child(ui)
	new_scenario(30)


# ------------------------------------------------------------------ worlds
func _make_world(kinds: Array) -> void:
	if world != null:
		remove_child(world)
		world.queue_free()
	_ghost = null
	_ghost_tool = ""
	_footprint = null
	Engine.time_scale = 1.0
	world = Main.new()
	world.name = "World"
	world.config = {
		"players": kinds, "size": scenario.map_size, "walls": 1e9, "guns": 1e9, "battle": 1e9, "ready": 0.0,
		"pitch": 60.0, "fov": 30.0, "ships": 0, "seed": scenario.seed, "decorate": false, "colors": SIDE_COLORS,
		"hud": false, "castles": false, "band": ui.bands()}
	add_child(world)
	world.ui.visible = false  # the sandbox panels show the same information
	game = world.game
	map = game.map
	game.started = false


func player(s: int):
	return game.players[s]


## A fresh layout: both castles walled in at the usual places.
func new_scenario(size: int) -> void:
	scenario = ScenarioDef.new()
	scenario.map_size = size
	scenario.seed = randi() % 100000
	var items: Array = []
	var n: int = Catalog.base_def().size
	for s in 2:
		var x0 := size / 2 - n / 2
		var z0 := (size / 4 if s == 0 else size - size / 4 - 1) - n / 2
		items.append({"side": s, "id": "castle", "x": x0, "z": z0, "rot": 0})
		for x in range(x0 - 1, x0 + n + 1):
			for z in range(z0 - 1, z0 + n + 1):
				if x == x0 - 1 or x == x0 + n or z == z0 - 1 or z == z0 + n:
					items.append({"side": s, "id": "wall", "x": x, "z": z, "rot": 0})
	scenario.items.assign(items)
	undo_stack = []
	redo_stack = []
	_enter_edit()


func _enter_edit() -> void:
	mode = Mode.EDIT
	winner = -1
	_make_world(["ai", "ai"])
	apply_items(scenario.items)
	ui.refresh()


# ----------------------------------------------------------------- layout
func snapshot() -> Array:
	var items: Array = []
	var seen := {}
	for x in map.sizeX:
		for z in map.sizeZ:
			var t = map.tiles[x][z]
			var s = t.structure
			if not U.alive(s) or seen.has(s):
				continue
			seen[s] = true
			var def := Catalog.def_of(s)
			var owner_side: int = game.players.find(t.player)
			if def == null or owner_side < 0:
				continue
			items.append({"side": owner_side, "id": def.id, "x": x, "z": z, "rot": int(s.get_meta("rot", 0))})
	return items


func apply_items(items: Array) -> void:
	map.statesMap.begin_batch()
	for it in items:
		if it["id"] == "wall":
			_place_wall(it["side"], Vector2i(it["x"], it["z"]))
		else:
			place_building(it["side"], Catalog.get_def(it["id"]), it["x"], it["z"], it.get("rot", 0))
	map.statesMap.end_batch()


func _key(it: Dictionary) -> String:
	return "%d|%s|%d|%d|%d" % [it["side"], it["id"], it["x"], it["z"], it.get("rot", 0)]


## Changes the world to `items` with as few edits as possible (undo / redo).
func restore(items: Array) -> void:
	map.statesMap.begin_batch()
	var want := {}
	for it in items:
		want[_key(it)] = it
	var have := {}
	for it in snapshot():
		have[_key(it)] = it
	for k in have:
		if not want.has(k):
			_erase_tile(Vector2i(have[k]["x"], have[k]["z"]))
	for k in want:
		if not have.has(k):
			var it: Dictionary = want[k]
			if it["id"] == "wall":
				_place_wall(it["side"], Vector2i(it["x"], it["z"]))
			else:
				place_building(it["side"], Catalog.get_def(it["id"]), it["x"], it["z"], it.get("rot", 0))
	map.statesMap.end_batch()


func _place_wall(s: int, xz: Vector2i) -> bool:
	return player(s).place(Catalog.get_def("wall"), xz.x, xz.y) != null


func place_building(s: int, def: BuildingDef, x: int, z: int, r := 0) -> Node3D:
	if def == null:
		return null
	if def.category == BuildingDef.Category.BASE:
		for it in snapshot():
			if it["side"] == s and Catalog.get_def(it["id"]) != null \
					and Catalog.get_def(it["id"]).category == BuildingDef.Category.BASE:
				_erase_tile(Vector2i(it["x"], it["z"]))
	var go: Node3D = player(s).place(def, x, z)
	if go != null and r != 0:
		go.set_meta("rot", r)
		go.rotate_y(-PI / 2.0 * r)
	return go


func _erase_tile(xz: Vector2i) -> bool:
	var t = map.tiles[xz.x][xz.y]
	if not U.alive(t.structure):
		return false
	if t.upgradeCluster != null:
		t.upgradeCluster.un_build_upgrade()
	else:
		t.un_build()
	return true


# ------------------------------------------------------------- editing API
## One edit = one undo step. Used by the mouse handling and the tests' tools.
func begin_edit() -> void:
	if _stroke_before == null:
		_stroke_before = snapshot()


func end_edit() -> void:
	if _stroke_before == null:
		return
	if snapshot() != _stroke_before:
		undo_stack.append(_stroke_before)
		redo_stack = []
	_stroke_before = null
	ui.refresh()


## Applies the current tool to tile xz (left mouse button).
func use_tool(xz: Vector2i) -> void:
	if mode != Mode.EDIT or xz.x < 0:
		return
	match tool:
		"erase":
			erase(xz)
		"wall":
			var t = map.tiles[xz.x][xz.y]
			if not U.alive(t.structure) and not t.water:
				_place_wall(side, xz)
		_:
			var def := Catalog.get_def(tool)
			if def != null:
				var a := anchor_for(def, xz)
				place_building(side, def, a.x, a.y, rot)


func erase(xz: Vector2i) -> void:
	if mode != Mode.EDIT or xz.x < 0:
		return
	_erase_tile(xz)


## Lower left tile of a building of `def` centred on the cursor tile.
func anchor_for(def: BuildingDef, xz: Vector2i) -> Vector2i:
	var off := (def.size - 1) / 2
	return xz - Vector2i(off, off)


## Replaces the other side's layout with this side's, mirrored top to bottom.
func mirror(from_side: int) -> void:
	if mode != Mode.EDIT:
		return
	begin_edit()
	var items: Array = []
	for it in snapshot():
		if it["side"] == from_side:
			items.append(it)
			items.append(mirrored(it, 1 - from_side, map.sizeZ))
	restore(items)
	end_edit()


## `it` mirrored top to bottom on a map `size_z` tiles high, owned by `new_side`.
static func mirrored(it: Dictionary, new_side: int, size_z: int) -> Dictionary:
	var def := Catalog.get_def(it["id"])
	var n: int = def.size if def != null else 1
	return {"side": new_side, "id": it["id"], "x": it["x"], "z": size_z - it["z"] - n,
		"rot": (it.get("rot", 0) + 2) % 4}


func undo() -> void:
	if mode != Mode.EDIT or undo_stack.is_empty():
		return
	redo_stack.append(snapshot())
	restore(undo_stack.pop_back())
	ui.refresh()


func redo() -> void:
	if mode != Mode.EDIT or redo_stack.is_empty():
		return
	undo_stack.append(snapshot())
	restore(redo_stack.pop_back())
	ui.refresh()


# ------------------------------------------------------------ save / load
func save(name: String) -> String:
	var clean := name.strip_edges().validate_filename()
	if clean == "":
		return ""
	if mode == Mode.EDIT:
		scenario.items.assign(snapshot())
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	var path := USER_DIR.path_join(clean + ".tres")
	ResourceSaver.save(scenario, path)
	return path


## Saved scenarios: user ones first, then the examples.
func saved_scenarios() -> Array[String]:
	var out: Array[String] = []
	for dir in [USER_DIR, EXAMPLE_DIR]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in DirAccess.get_files_at(dir):
			f = f.trim_suffix(".remap")
			if f.ends_with(".tres"):
				out.append(dir.path_join(f))
	return out


func load_scenario(path: String) -> bool:
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not res is ScenarioDef:
		return false
	scenario = res
	undo_stack = []
	redo_stack = []
	_enter_edit()
	return true


# ------------------------------------------------------------------ battle
func play() -> void:
	if mode != Mode.EDIT:
		return
	end_edit()
	scenario.items.assign(snapshot())
	var kinds := ["human", "ai"] if match_index in [1, 2] else ["ai", "ai"]
	_make_world(kinds)
	apply_items(scenario.items)
	for s in 2:
		var p = player(s)
		p.stats = {}
		if p.is_ai():
			p.targetMode = targets[s]
			p.dormant = match_index in [2, 3] and s == dormant_side
	game.phase = game.Phase.BATTLE
	game.timeLeftInRound = 1e9
	game.started = true
	for p in game.players:
		p.refresh_active_cannons()
		p.partsCap = 999  # the sandbox places freely: the parts cap does not apply
	mode = Mode.BATTLE
	winner = -1
	battle_start = U.time
	set_speed(speed if speed > 0 else 1.0)
	ui.refresh()


func reset() -> void:
	if mode == Mode.EDIT:
		return
	_enter_edit()


func set_speed(v: float) -> void:
	speed = v
	Engine.time_scale = v if mode != Mode.EDIT else 1.0


func battle_time() -> float:
	return U.time - battle_start if mode != Mode.EDIT else 0.0


func _check_battle_end() -> void:
	if battle_time() < 1.0:
		return
	# a side lives while it holds a non-ruin castle, its guns notwithstanding
	var alive := [player(0).castle_count() > 0, player(1).castle_count() > 0]
	if alive[0] and alive[1] and battle_time() < time_limit:
		return
	if alive[0] and not alive[1]:
		winner = 0
	elif alive[1] and not alive[0]:
		winner = 1
	else:
		winner = 2
	mode = Mode.ENDED
	game.started = false
	battle_ended.emit(winner)
	ui.refresh()


# ------------------------------------------------------------- battle lab
## Plays the current layout with seeds 1..runs in a headless background
## process (tools/lab.tscn: normal speed, each seed also with the layouts
## swapped) with the current match setup. Progress and the result end up in
## lab_result.
func run_lab(runs: int) -> bool:
	if mode != Mode.EDIT or lab_pid > 0:
		return false
	end_edit()
	scenario.items.assign(snapshot())
	DirAccess.make_dir_recursive_absolute(LAB_DIR)
	var layout := LAB_DIR.path_join("layout.tres")
	var out := ProjectSettings.globalize_path(LAB_DIR.path_join("result.txt"))
	ResourceSaver.save(scenario, layout)
	DirAccess.remove_absolute(out)
	var cmd := ["--headless", "--fixed-fps", "30"]
	if FileAccess.file_exists("res://project.godot") and not OS.has_feature("template"):
		cmd += ["--path", ProjectSettings.globalize_path("res://")]
	cmd += ["res://tools/lab.tscn", "--", "--scenario=" + layout, "--runs=%d" % runs,
		"--match=" + ("dormant" if match_index in [2, 3] else "ai"),
		"--targets=%s,%s" % targets, "--limit=%d" % time_limit, "--out=" + out,
		"--csv=" + ProjectSettings.globalize_path(LAB_DIR.path_join("last_run.csv"))]
	lab_pid = OS.create_process(OS.get_executable_path(), cmd)
	lab_result = "Starting %d battles ..." % (2 * runs) if lab_pid > 0 else "Could not start the battle lab"
	return lab_pid > 0


func stop_lab() -> void:
	if lab_pid > 0:
		OS.kill(lab_pid)
		lab_pid = -1
		lab_result = "Stopped"


func _poll_lab() -> void:
	if lab_pid <= 0:
		return
	var running := OS.is_process_running(lab_pid)
	var path := ProjectSettings.globalize_path(LAB_DIR.path_join("result.txt"))
	var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var progress := text.begins_with("running ")
	if progress:
		var k := text.trim_prefix("running ")
		lab_result = "Running battle %d of %d ..." % [int(k.get_slice("/", 0)) + 1, int(k.get_slice("/", 1))]
	elif text != "":
		lab_result = text
	if not running:
		lab_pid = -1
		if text == "" or progress:
			lab_result = "The battle lab stopped without a result"
		ui.refresh()


func _exit_tree() -> void:
	stop_lab()


# ------------------------------------------------------------------ input
func tile_under(screen: Vector2) -> Vector2i:
	var cam := get_viewport().get_camera_3d()
	if cam == null or map == null:
		return Vector2i(-1, -1)
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 1e-5:
		return Vector2i(-1, -1)
	return map.tile_index_at(o + d * ((0.1 - o.y) / d.y))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if mode == Mode.EDIT and event.ctrl_pressed and k == KEY_Z:
			if event.shift_pressed:
				redo()
			else:
				undo()
		elif mode == Mode.EDIT and event.ctrl_pressed and k == KEY_Y:
			redo()
		elif k == KEY_R and mode == Mode.EDIT:
			rot = (rot + 1) % 4
		elif k == KEY_1 or k == KEY_2:
			side = 0 if k == KEY_1 else 1
			ui.refresh()
	if mode != Mode.EDIT:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			var xz := tile_under(event.position)
			if event.pressed:
				_drag_button = event.button_index
				begin_edit()
				if _drag_button == MOUSE_BUTTON_LEFT:
					use_tool(xz)
				else:
					erase(xz)
			elif event.button_index == _drag_button:
				_drag_button = 0
				end_edit()
	elif event is InputEventMouseMotion:
		var xz := tile_under(event.position)
		if xz != _hover:
			_hover = xz
			if _drag_button == MOUSE_BUTTON_LEFT and (tool == "wall" or tool == "erase"):
				use_tool(xz)
			elif _drag_button == MOUSE_BUTTON_RIGHT:
				erase(xz)


func _process(delta: float) -> void:
	if map == null:
		return
	if mode == Mode.BATTLE:
		_check_battle_end()
	_poll_timer -= delta
	if _poll_timer <= 0:
		_poll_timer = 0.25
		if mode == Mode.EDIT:
			for p in game.players:
				p.refresh_active_cannons()
		_poll_lab()
	_update_ghost()
	ui.update_live()


# ------------------------------------------------------------- visuals
func _update_ghost() -> void:
	if mode != Mode.EDIT or _hover.x < 0 or _drag_button == MOUSE_BUTTON_RIGHT:
		if _footprint:
			_footprint.visible = false
		if _ghost:
			_ghost.visible = false
		return
	var def := Catalog.get_def(tool)
	var size := def.size if def != null else 1
	var a := anchor_for(def, _hover) if def != null else _hover
	var ok: bool
	if tool == "erase":
		ok = U.alive(map.tiles[_hover.x][_hover.y].structure)
	elif tool == "wall":
		ok = player(side).can_place(Catalog.get_def("wall"), _hover.x, _hover.y)
	else:
		ok = def != null and player(side).can_place(def, a.x, a.y)
	if _footprint == null:
		_footprint = MeshInstance3D.new()
		_footprint.mesh = BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_footprint.material_override = m
		_footprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(_footprint)
	var p0: Vector3 = map.tile_position(clampi(a.x, 0, map.sizeX - 1), clampi(a.y, 0, map.sizeZ - 1))
	var p1: Vector3 = map.tile_position(clampi(a.x + size - 1, 0, map.sizeX - 1), clampi(a.y + size - 1, 0, map.sizeZ - 1))
	_footprint.visible = true
	_footprint.global_position = (p0 + p1) / 2.0 + Vector3(0, 0.2, 0)
	_footprint.scale = Vector3(size * 0.98, 0.06, size * 0.98)
	var c := Color(0.3, 1.0, 0.4, 0.35) if ok else Color(1.0, 0.25, 0.2, 0.45)
	if tool == "erase":
		c = Color(1.0, 0.6, 0.1, 0.45) if ok else Color(1, 1, 1, 0.15)
	(_footprint.material_override as StandardMaterial3D).albedo_color = c
	# model preview for buildings
	if _ghost_tool != tool:
		if _ghost:
			_ghost.queue_free()
		_ghost = null
		_ghost_tool = tool
		if def != null and def.model != null:
			_ghost = def.model.instantiate()
			world.add_child(_ghost)
			for mi in U.meshes(_ghost):
				if mi.get_script() != null:  # reload ring and similar helpers
					mi.set_script(null)
					mi.visible = false
					continue
				var m := StandardMaterial3D.new()
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.albedo_color = Color(1, 1, 1, 0.45)
				mi.material_override = m
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _ghost:
		_ghost.visible = true
		_ghost.global_position = (p0 + p1) / 2.0
		_ghost.rotation = Vector3(0, -PI / 2.0 * rot, 0)
