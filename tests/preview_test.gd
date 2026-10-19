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
	await _check_wall_shapes()
	await _check_corners()
	main.free()
	await get_tree().process_frame
	await _build("ai4", "3")
	await _check_corners()
	_finish()


func _build(mode: String, the_seed: String) -> void:
	Main.requested_mode = mode
	Main.requested_args = {"seed": the_seed}
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
## free tile (across the viewport boundary), like in the game. The tile's trees and
## stones hide under the preview, so the piece's orientation reads, and they come
## back when the preview leaves the tile.
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
				if human.ibr(t.idxX, t.idxZ) and not U.alive(t.structure) and t.buildable() \
						and not t.decorations.is_empty():
					free = Vector2i(t.idxX, t.idxZ)
	check(free.x >= 0, "a free tile with trees or stones on it exists in range")
	if free.x < 0:
		return
	var deco_meshes: Array = []
	for d in map.tiles[free.x][free.y].decorations:
		deco_meshes.append_array(U.meshes(d))
	check(deco_meshes.all(func(m): return m.visible),
			"the tile's trees and stones show before the preview lands")
	var ev := InputEventMouseMotion.new()
	ev.position = main.camera.unproject_position(map.tile_position(free.x, free.y, 0.1))
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	check(human.nextWall.get_parent() == map.tiles[free.x][free.y].go,
			"the wall moves onto the hovered tile as the placement preview")
	check(deco_meshes.all(func(m): return not m.visible),
			"the tile's trees and stones hide under the placement preview")
	ev = InputEventMouseMotion.new()
	ev.position = Vector2(2, 2)  # a viewport corner, off the board like the start
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	check(human.nextWall.get_parent() == human.wallSpawn,
			"the wall returns to the gui slot off the board")
	check(deco_meshes.all(func(m): return m.visible),
			"the tile's trees and stones come back when the preview leaves")


## A wall piece's placeholder model spans the footprint its access grid blocks, so the
## slot icon and the placement preview read as the piece's shape. Every model the placed
## wall can show instead — the wrapper's FBX, the art layer's glb files, the model the
## swap actually installs — must span that footprint and reach the tile edges its access
## grid connects, or the wall lands rotated (K4).
func _check_wall_shapes() -> void:
	for def in Catalog.drawable(BuildingDef.Category.WALL):
		var want := _footprint_aspect(def)
		var conn := _connectors(def)
		_check_model(def.model.instantiate(), want, conn, "%s placeholder" % def.id)
		for b in def.behaviours:
			for key in ["lower_models", "upper_models"]:
				var models: Array = b.get(key)
				for i in models.size():
					_check_model(models[i].instantiate(), want, conn, "%s %s[%d]" % [def.id, key, i])
		await _check_wall_art(def, want, conn)


## The art files the game loads for this def (the FBX names of its wrappers are the art ids)
## and one swap through a live wrapper, as WallModel does it when a wall is placed.
func _check_wall_art(def, want: float, conn: Array) -> void:
	var ids := {}
	for b in def.behaviours:
		for key in ["lower_models", "upper_models"]:
			for ps in b.get(key):
				var wrapper: Node3D = (ps as PackedScene).instantiate()
				var model := wrapper.get_node("Model") as Node3D
				ids["wall_" + model.scene_file_path.get_file().get_basename().rstrip("0123456789")] = key
				wrapper.free()
	for id in ids:
		var n := 1
		while true:
			var path := "res://assets/art/3d/%s.glb" % id if n == 1 else "res://assets/art/3d/%s.%d.glb" % [id, n]
			if not ResourceLoader.exists(path):
				break
			_check_model((load(path) as PackedScene).instantiate(), want, conn, "%s art %s" % [def.id, id])
			n += 1
	var live: Node3D = (def.behaviours[0].get("lower_models")[0] as PackedScene).instantiate()
	get_tree().root.add_child(live)
	await get_tree().process_frame
	_check_model(live.get_node("Model"), want, conn, "%s swapped-in model" % def.id, false)
	live.free()


## The sides the def's access grid blocks, [up, down, left, right]; up is -z, right is +x.
func _connectors(def) -> Array:
	var a: Array = def.access
	return [not a[5], not a[3], not a[1], not a[7]]


## The aspect (x over z) of the 3x3 area of cells the piece blocks: below 0.75 a bar
## along z, above 1.33 a bar along x, else roughly square. The access array is
## column-major, so cell (x, z) sits at 3 * x + z.
func _footprint_aspect(def) -> float:
	var xs: Array = []
	var zs: Array = []
	for z in 3:
		for x in 3:
			if not def.access[3 * x + z]:
				xs.append(x)
				zs.append(z)
	if xs.is_empty():
		return 1.0
	return float(xs.max() - xs.min() + 1) / float(zs.max() - zs.min() + 1)


const EDGE_REACH := 0.4
const SIDES := ["up", "down", "left", "right"]


func _check_model(piece: Node3D, want: float, conn: Array, what: String, free_after := true) -> void:
	var corners: Array = []
	_piece_extents(piece, Transform3D(), corners)
	if free_after:
		piece.free()
	var box := AABB(corners[0], Vector3.ZERO)
	for p in corners:
		box = box.expand(p)
	var aspect := box.size.x / box.size.z
	# A turned piece inverts its aspect (1 / aspect), so the bands only have to sit on the
	# right side of 1 with room for the modelled variance of the FBX variants (tee uppers
	# run to 0.93); the edge checks below are the exact discriminator.
	var ok := (aspect < 0.95) if want < 0.75 else ((aspect > 1.05) if want > 1.33 else (aspect >= 0.7 and aspect <= 1.4))
	check(ok, "%s spans its footprint (aspect %.2f, want %.2f)" % [what, aspect, want])
	# How far the geometry stays inside the 0.4 m line per side; negative means it reaches the edge.
	var inside := [box.position.z + EDGE_REACH, EDGE_REACH - box.end.z,
			box.position.x + EDGE_REACH, EDGE_REACH - box.end.x]
	for i in 4:
		check((inside[i] < 0.0) == conn[i], "%s reaches the %s edge exactly when the piece connects it" % [what, SIDES[i]])


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


## Every HUD panel and preview panel is fully on screen and clear of the others.
func _check_corners() -> void:
	await get_tree().process_frame
	var screen := main.get_viewport().get_visible_rect()
	var bits: Array = []
	for c in main.ui.get_children():
		if c is Control and (c.name.begins_with("Hud") or c.name.find("Panel") >= 0):
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
