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
	await _check_plates()
	_check_pieces()
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


## The next wall rests centred in its slot over void and follows the cursor onto
## a free tile (across the viewport boundary); the held building stays in its
## slot, only the wall previews. The tile's trees and stones hide under the
## preview, so the piece's orientation reads, and they come back when the
## preview leaves the tile.
func _check_hovers() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	check(_shade(human.nextWall) == 1.0, "the piece in the gui slot wears the placed block's colour, unshaded")
	var rest := _slot_box(human.nextWall)
	check(human.nextWall.get_parent() == human.wallSpawn and absf(rest.get_center().x) < 0.01
			and absf(rest.get_center().z) < 0.01, "the offered piece rests centred in the gui slot")
	var wait := 0.0
	while not U.alive(human.nextBuilding) and wait < 2.0:
		await get_tree().process_frame
		wait += 1.0 / 30.0
	check(U.alive(human.nextBuilding), "a building is offered beside the wall")
	var free := _free_tile(true)
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
			"the piece moves onto the hovered tile as the placement preview")
	check(human.nextBuilding.get_parent() == human.buildingSpawn,
			"the building stays in its slot; only the wall previews on the tile")
	check(_shade(human.nextWall) < 1.0, "the preview on the board is darker than a placed block")
	check(deco_meshes.all(func(m): return not m.visible),
			"the tile's trees and stones hide under the placement preview")
	ev = InputEventMouseMotion.new()
	ev.position = Vector2(2, 2)  # a viewport corner, off the board like the start
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	check(human.nextWall.get_parent() == human.wallSpawn,
			"the wall returns to the gui slot off the board")
	check(_shade(human.nextWall) == 1.0, "back in the gui slot the piece wears the placed block's colour again")
	check(human.nextBuilding.get_parent() == human.buildingSpawn,
			"the building returns to its slot off the board")
	check(deco_meshes.all(func(m): return m.visible),
			"the tile's trees and stones come back when the preview leaves")


## A free tile in the human's build range, with trees or stones on it when `decorated`; (-1, -1) when none.
func _free_tile(decorated: bool) -> Vector2i:
	var base := Vector2i(map.sizeX / 2, map.sizeZ / 4)
	var free := Vector2i(-1, -1)
	for r in range(2, 6):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var t = map.tiles[base.x + dx][base.y + dz]
				if human.in_reach(t.idxX, t.idxZ) and not U.alive(t.structure) and t.buildable() \
						and (not decorated or not t.decorations.is_empty()):
					free = Vector2i(t.idxX, t.idxZ)
	return free


## A gun's plate stays square to the grid while the gun turns, and goes wherever the gun goes: from its slot onto
## the board, and up with it when a discard flies out of the slot. The gun waits in its slot first, as a player's does.
func _check_plates() -> void:
	var gun: Node3D = await _offered_gun()
	var plate := gun.find_child("plate", true, false) as Node3D
	var rest := plate.global_position - gun.global_position
	var square := plate.global_basis
	var xz := _free_tile(false)
	await _right_click(main.camera.unproject_position(map.tile_position(xz.x, xz.y, 0.1)))
	check(gun.get_parent() == map.tiles[xz.x][xz.y].go, "a right click places the held gun on the hovered tile")
	_check_plate(gun, plate, rest, "placed from its slot")
	var gun_basis := gun.global_basis
	U.shooter(gun).try_aim(map.tile_position(xz.x + 3, xz.y + 5))
	await get_tree().process_frame
	check(not gun.global_basis.is_equal_approx(gun_basis), "aiming turns the placed gun")
	check(plate.global_basis.is_equal_approx(square), "the plate stays square to the grid while the gun turns")
	_check_plate(gun, plate, rest, "turned to aim")
	gun = await _offered_gun()
	plate = gun.find_child("plate", true, false) as Node3D
	var start := gun.global_position
	await _right_click(Vector2(2, 2))
	for i in 10:
		await get_tree().process_frame
	check(gun.global_position.y > start.y + 0.5, "a right click off the board sends the held gun flying")
	_check_plate(gun, plate, rest, "flying off as a discard")


## The next gun the human is offered, once it has rested a few frames in its slot.
func _offered_gun() -> Node3D:
	var wait := 0.0
	while not (U.alive(human.nextBuilding) and U.shooter(human.nextBuilding) != null) and wait < 5.0:
		if U.alive(human.nextBuilding):
			U.destroy(human.nextBuilding)
			human.nextBuilding = null
		await get_tree().process_frame
		wait += 1.0 / 30.0
	for i in 5:
		await get_tree().process_frame
	return human.nextBuilding


func _right_click(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_RIGHT
		mb.position = at
		mb.pressed = pressed
		Input.parse_input_event(mb)
		await get_tree().process_frame


func _check_plate(gun: Node3D, plate: Node3D, rest: Vector3, when: String) -> void:
	var off := plate.global_position - gun.global_position
	check(off.is_equal_approx(rest), "%s, the gun keeps its plate under it (plate %s off the gun, %s in the slot)"
			% [when, off, rest])


## Every drawn piece at every rotation: its ghost cells land on the anchor tile plus its cells, and in
## the gui slot the piece sits centred and inside the slot camera's view.
func _check_pieces() -> void:
	var anchor := Vector2i(map.sizeX / 2, map.sizeZ / 2)
	var cam: Camera3D = human.wallSpawn.get_viewport().get_camera_3d()
	for def in Catalog.drawable(BuildingDef.Category.WALL):
		U.destroy(human.nextWall)
		human.nextWall = Catalog.spawn(def, human.wallSpawn)
		var bb = U.comp(human.nextWall, "BuildingBlock")
		for r in 4:
			human.buildableTileSelected = map.tiles[anchor.x][anchor.y]
			human.next_wall_to_map()
			var got: Array = []
			for n in human.nextWall.get_children():
				if n is Node3D:
					got.append(map.tile_index_at(n.global_position))
			var want: Array = []
			for c in bb.cells:
				want.append(anchor + c)
			check(got == want, "%s turned %d: the ghost covers anchor + cells %s (got %s)" % [def.id, r, want, got])
			human.next_wall_to_gui()
			var box := _slot_box(human.nextWall)
			check(absf(box.get_center().x) < 0.01 and absf(box.get_center().z) < 0.01,
					"%s turned %d sits centred in the gui slot" % [def.id, r])
			check(maxf(box.size.x, box.size.z) <= cam.size,
					"%s turned %d fits the slot camera's view (%.2f m in %.2f m)" % [def.id, r, maxf(box.size.x, box.size.z), cam.size])
			bb.rotate_clockwise()
		human._restore_decorations()


## The wall shader's shade of the first block under node, 1 placed, under 1 as the ghost.
func _shade(node: Node) -> float:
	var mi := node.find_child("wall", true, false) as MeshInstance3D
	return mi.material_override.get_shader_parameter("shade") if mi != null else -1.0


## Bounds of the piece's meshes in its slot's space.
func _slot_box(piece: Node3D) -> AABB:
	var corners: Array = []
	_piece_extents(piece, Transform3D(), corners)
	var box := AABB(corners[0], Vector3.ZERO)
	for p in corners:
		box = box.expand(p)
	return box


func _piece_extents(node: Node3D, xform: Transform3D, corners: Array) -> void:
	var world := xform * node.transform
	if node is MeshInstance3D:
		var part: AABB = node.get_aabb()
		for cx in [part.position.x, part.end.x]:
			for cy in [part.position.y, part.end.y]:
				for cz in [part.position.z, part.end.z]:
					corners.append(world * Vector3(cx, cy, cz))
	for c in node.get_children():
		if c is Node3D:
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
