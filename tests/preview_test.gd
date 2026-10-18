extends Node
## The next-piece previews: every slot renders centered in its own orthogonal viewport
## shown in a corner panel, and the pieces still move between the slot and the map.
##   godot --headless --fixed-fps 30 res://tests/preview_test.tscn

const Main = preload("res://scripts/Main.gd")

var main: Node
var game
var human
var map
var failures: Array = []


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)  # headless windows are 64 x 64
	await _build("versus", "7")
	for i in game.players.size():
		for kind in ["wall", "building"]:
			_check_slot(kind, i)
	await _check_hovers()
	_check_wall_shapes()
	await _check_corners()
	main.free()
	await get_tree().process_frame
	await _build("ai4", "3")
	await _check_corners()
	_finish()


func _build(mode: String, the_seed: String) -> void:
	Main.requested_mode = mode
	Main.requested_args = {"seed": the_seed, "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	game = main.game
	human = game.players[0]
	map = game.map
	if game.players.size() > 1 and "nextAction" in game.players[1]:
		game.players[1].nextAction = 1e9  # keep the AI idle during the scripted checks


## One preview slot: its own orthogonal viewport, a corner panel showing it, on screen.
func _check_slot(kind: String, i: int) -> void:
	var n := i + 1
	var spawn: Node3D = game.wallSpawns[i] if kind == "wall" else game.buildingSpawns[i]
	var vp := spawn.get_viewport()
	check(vp is SubViewport and vp != main.get_viewport(), "%s slot %d renders in its own viewport" % [kind, n])
	var cam := vp.get_camera_3d() if vp is SubViewport else null
	check(cam != null and cam.projection == Camera3D.PROJECTION_ORTHOGONAL,
			"%s slot %d has an orthogonal camera" % [kind, n])
	check(spawn.position == Vector3.ZERO, "%s slot %d is centred in its viewport" % [kind, n])
	var panel: Control = main.ui.get_node_or_null("%sPanel%d" % [kind, n])
	check(panel is PanelContainer and panel.visible == spawn.visible,
			"%s slot %d has a panel on the UI layer that is shown with it" % [kind, n])
	if not panel is PanelContainer:
		return
	var rect: TextureRect = panel.get_node("%sRect%d" % [kind, n])
	check(rect.texture == vp.get_texture() and rect.custom_minimum_size == Vector2(vp.size),
			"%s slot %d panel shows the viewport at its own resolution" % [kind, n])
	spawn.visible = false
	check(not panel.visible and vp.render_target_update_mode == SubViewport.UPDATE_DISABLED,
			"hiding the %s slot %d hides the panel and stops the viewport" % [kind, n])
	spawn.visible = true
	check(panel.visible and vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
			"showing the %s slot %d restores panel and viewport" % [kind, n])


## The next wall rests centred in the slot over void and follows the cursor onto a
## free tile (across the viewport boundary), like in the game.
func _check_hovers() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	check(human.nextWall.get_parent() == human.wallSpawn and human.nextWall.position == Vector3.ZERO,
			"the offered wall rests centred in the gui slot")
	var base := Vector2i(map.sizeX / 2, map.sizeZ / 4)
	var free := Vector2i(-1, -1)
	for r in range(2, 6):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var t = map.tiles[base.x + dx][base.y + dz]
				if human.ibr(t.idxX, t.idxZ) and not U.alive(t.structure) and t.buildable():
					free = Vector2i(t.idxX, t.idxZ)
	check(free.x >= 0, "a free tile in range exists")
	if free.x < 0:
		return
	var ev := InputEventMouseMotion.new()
	ev.position = main.camera.unproject_position(map.tile_position(free.x, free.y, 0.1))
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	check(human.nextWall.get_parent() == map.tiles[free.x][free.y].go,
			"the wall moves onto the hovered tile as the placement preview")


## A wall piece's placeholder model spans the footprint its access grid blocks, so the
## slot icon and the placement preview read as the piece's shape.
func _check_wall_shapes() -> void:
	for def in Catalog.drawable(BuildingDef.Category.WALL):
		var xs: Array = []
		var zs: Array = []
		for z in 3:
			for x in 3:
				if not def.access[3 * z + x]:
					xs.append(x)
					zs.append(z)
		if xs.is_empty():
			continue
		var want := float(xs.max() - xs.min() + 1) / float(zs.max() - zs.min() + 1)
		var corners: Array = []
		var piece := def.model.instantiate()
		_piece_extents(piece, Transform3D(), corners)
		piece.free()
		var box := AABB(corners[0], Vector3.ZERO)
		for p in corners:
			box = box.expand(p)
		var aspect := box.size.x / box.size.z
		var ok := (aspect < 0.9) if want < 0.75 else ((aspect > 1.05) if want > 1.33 else (aspect >= 0.7 and aspect <= 1.4))
		check(ok, "%s placeholder spans its footprint (aspect %.2f, want %.2f)" % [def.id, aspect, want])


func _piece_extents(node: Node3D, xform: Transform3D, corners: Array) -> void:
	var world := xform * node.transform
	if node is MeshInstance3D:
		var part: AABB = node.get_aabb()
		for cx in [part.position.x, part.end.x]:
			for cy in [part.position.y, part.end.y]:
				for cz in [part.position.z, part.end.z]:
					corners.append(world * Vector3(cx, cy, cz))
	for c in node.get_children():
		_piece_extents(c, world, corners)


## Every supply bar and preview panel is fully on screen and clear of the others.
func _check_corners() -> void:
	await get_tree().process_frame
	var screen := main.get_viewport().get_visible_rect()
	var bits: Array = []
	for c in main.ui.get_children():
		if c is Control and (c.name.begins_with("Supply") or c.name.find("Panel") >= 0):
			bits.append([c.name, c.get_global_rect()])
	for a in bits.size():
		check(screen.encloses(bits[a][1]), "%s is fully on screen" % bits[a][0])
		for b in range(a + 1, bits.size()):
			check(not bits[a][1].intersects(bits[b][1]), "%s and %s do not overlap" % [bits[a][0], bits[b][0]])


func check(cond: bool, msg: String) -> void:
	print(("ok: " if cond else "FAIL: ") + msg)
	if not cond:
		failures.append(msg)


func _finish() -> void:
	print("PREVIEW TEST PASSED" if failures.is_empty() else "PREVIEW TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)
