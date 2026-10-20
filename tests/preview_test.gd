extends Node
## The hand and the placement preview: the held piece lives in an invisible hand, never on the UI layer, and
## shows only on the board. In the wall phase the piece previews on a hovered free tile (darker, the tile's
## trees and stones hidden) and returns to the hand off the board; in the cannon phase the dealt gun previews
## on the tile instead, and no piece is held. Every drawn piece's ghost covers its anchor plus cells at every
## turn. The HUD plaques lie on screen and clear of each other, in versus and with four players.
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
	_check_quiet_build()
	_check_hand()
	await _check_hovers()
	await _check_gun_hover()
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


## The hand is an invisible node of the player's; nothing of it renders on the UI layer.
func _check_hand() -> void:
	for p in game.players:
		check(p.hand is Node3D and not p.hand.visible and p.hand.get_parent() == p.go,
				"player %d keeps its hand in an invisible node of its own" % p.playerID)
	check(human.nextWall.get_parent() == human.hand, "the dealt piece rests in the hand")
	check(main.find_children("*", "SubViewport", true, false).is_empty()
			and main.ui.find_children("*", "TextureRect", true, false).is_empty(),
			"no next-piece viewport and no icon panel exist")


## The map build and the start castles clear decorated ground without rubble (I69): only a shot or a build in play
## crumbles a tree.
func _check_quiet_build() -> void:
	var decorated := 0
	for col in map.tiles:
		for t in col:
			decorated += 1 if not t.decorations.is_empty() else 0
	var heaps: int = main.find_children("*", "Node3D", true, false).filter(func(n): return n is Crumble).size()
	check(decorated > 0 and heaps == 0,
			"the map build and the start castles leave no rubble (%d decorated tiles, %d heaps)" % [decorated, heaps])


## A free tile in reach of the start castle with trees or stones on it.
func _decorated_free_tile() -> Vector2i:
	var base := Vector2i(map.sizeX / 2, map.sizeZ / 4)
	var free := Vector2i(-1, -1)
	for r in range(2, 6):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var t = map.tiles[base.x + dx][base.y + dz]
				if human.in_reach(t.idxX, t.idxZ) and not U.alive(t.structure) and t.buildable() \
						and not t.decorations.is_empty():
					free = Vector2i(t.idxX, t.idxZ)
	return free


func _hover(xz: Vector2i) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = main.camera.unproject_position(map.tile_position(xz.x, xz.y, 0.1))
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame


func _hover_off() -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = Vector2(2, 2)  # a viewport corner, off the board like the start
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame


func _deco_meshes(xz: Vector2i) -> Array:
	var out: Array = []
	for d in map.tiles[xz.x][xz.y].decorations:
		out.append_array(U.meshes(d))
	return out


## The wall piece follows the cursor onto a free tile and back to the hand off the board; no gun is held in
## the wall phase.
func _check_hovers() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	check(_shade(human.nextWall) == 1.0, "the piece in the hand wears the placed block's colour, unshaded")
	await seconds(0.5)
	check(not U.alive(human.nextBuilding), "no gun is dealt in the wall phase")
	var free := _decorated_free_tile()
	check(free.x >= 0, "a free tile with trees or stones on it exists in range")
	if free.x < 0:
		return
	var deco := _deco_meshes(free)
	check(deco.all(func(m): return m.visible), "the tile's trees and stones show before the preview lands")
	await _hover(free)
	check(human.nextWall.get_parent() == map.tiles[free.x][free.y].go,
			"the piece moves onto the hovered tile as the placement preview")
	check(_shade(human.nextWall) < 1.0, "the preview on the board is darker than a placed block")
	check(deco.all(func(m): return not m.visible), "the tile's trees and stones hide under the placement preview")
	await _hover_off()
	check(human.nextWall.get_parent() == human.hand, "the wall returns to the hand off the board")
	check(_shade(human.nextWall) == 1.0, "back in the hand the piece wears the placed block's colour again")
	check(deco.all(func(m): return m.visible), "the tile's trees and stones come back when the preview leaves")


## In the cannon phase the dealt gun previews on the hovered free tile and goes back to the hand off the board.
func _check_gun_hover() -> void:
	game.next_phase()
	game.timeLeftInRound = 1e6
	await seconds(0.5)
	check(not U.alive(human.nextWall) and U.alive(human.nextBuilding) and U.shooter(human.nextBuilding) != null,
			"the cannon phase deals a gun and no piece")
	check(human.nextBuilding.get_parent() == human.hand, "the gun rests in the hand")
	var free := _decorated_free_tile()
	if free.x < 0:
		return
	var deco := _deco_meshes(free)
	await _hover(free)
	check(human.nextBuilding.get_parent() == map.tiles[free.x][free.y].go
			and human.nextBuilding.global_position.distance_to(map.tiles[free.x][free.y].go.global_position) < 0.01,
			"the gun previews on the hovered tile, where it would stand")
	check(deco.all(func(m): return not m.visible), "the tile's trees and stones hide under the gun")
	await _hover_off()
	check(human.nextBuilding.get_parent() == human.hand, "the gun returns to the hand off the board")
	check(deco.all(func(m): return m.visible), "the trees and stones come back when the gun leaves")


## A gun's plate goes wherever the gun goes and stays square to the grid while the gun turns: the gun rests in the
## hand, previews on one hovered tile, then on the next, and a right click places it.
func _check_plates() -> void:
	var gun: Node3D = human.nextBuilding
	var plate := gun.find_child("plate", true, false) as Node3D
	var rest := plate.global_position - gun.global_position
	var square := plate.global_basis
	var free := _free_tiles()
	check(free.size() >= 2, "two free tiles exist in range")
	if free.size() < 2:
		return
	await _hover(free[0])
	_check_plate(gun, plate, rest, "previewed on a tile")
	await _hover(free[1])
	_check_plate(gun, plate, rest, "previewed on the next tile")
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_RIGHT
		mb.position = main.camera.unproject_position(map.tile_position(free[1].x, free[1].y, 0.1))
		mb.pressed = pressed
		Input.parse_input_event(mb)
		await get_tree().process_frame
	check(gun.get_parent() == map.tiles[free[1].x][free[1].y].go and human.nextBuilding != gun,
			"a right click places the gun on the hovered tile")
	_check_plate(gun, plate, rest, "placed")
	var gun_basis := gun.global_basis
	U.shooter(gun).try_aim(map.tile_position(free[1].x + 3, free[1].y + 5))
	await get_tree().process_frame
	check(not gun.global_basis.is_equal_approx(gun_basis), "aiming turns the placed gun")
	check(plate.global_basis.is_equal_approx(square), "the plate stays square to the grid while the gun turns")
	_check_plate(gun, plate, rest, "turned to aim")


## The free tiles in reach of the start castle.
func _free_tiles() -> Array[Vector2i]:
	var base := Vector2i(map.sizeX / 2, map.sizeZ / 4)
	var out: Array[Vector2i] = []
	for dx in range(-5, 6):
		for dz in range(-5, 6):
			var t = map.tiles[base.x + dx][base.y + dz]
			if human.in_reach(t.idxX, t.idxZ) and t.is_free():
				out.append(Vector2i(t.idxX, t.idxZ))
	return out


func _check_plate(gun: Node3D, plate: Node3D, rest: Vector3, when: String) -> void:
	var off := plate.global_position - gun.global_position
	check(off.is_equal_approx(rest), "%s, the gun keeps its plate under it (plate %s off the gun, %s in the hand)"
			% [when, off, rest])


## Every drawn piece at every rotation: its ghost cells land on the anchor tile plus its cells.
func _check_pieces() -> void:
	var anchor := Vector2i(map.sizeX / 2, map.sizeZ / 2)
	for def in Catalog.drawable(BuildingDef.Category.WALL):
		U.destroy(human.nextWall)
		human.nextWall = Catalog.spawn(def, human.hand)
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
			human.next_wall_to_hand()
			check(human.nextWall.get_parent() == human.hand, "%s turned %d goes back to the hand" % [def.id, r])
			bb.rotate_clockwise()
		human._restore_decorations()


## The wall shader's shade of the first block under node, 1 placed, under 1 as the ghost.
func _shade(node: Node) -> float:
	var mi := node.find_child("wall", true, false) as MeshInstance3D
	return mi.material_override.get_shader_parameter("shade") if mi != null else -1.0


## Every HUD plaque is fully on screen and clear of the others, and none covers a tile of the board at the home
## view; the 52 x 34 board fills the window's width.
func _check_corners() -> void:
	await get_tree().process_frame
	var screen := main.get_viewport().get_visible_rect()
	var edge: Array[Vector2] = []
	for x in map.sizeX:
		for z in [0, map.sizeZ - 1]:
			edge.append(main.camera.unproject_position(map.tile_position(x, z, 0.1)))
	for z in map.sizeZ:
		for x in [0, map.sizeX - 1]:
			edge.append(main.camera.unproject_position(map.tile_position(x, z, 0.1)))
	for c in main.ui.get_children():
		if c is Control and c.visible:
			var r: Rect2 = c.get_global_rect()
			check(not edge.any(func(e): return r.has_point(e)), "%s covers no tile of the board's edge" % c.name)
	if map.sizeX > map.sizeZ:
		var front := absf(edge[0].x - edge[2 * (map.sizeX - 1)].x)  # z = 0 is the row nearest the camera
		check(front >= 0.93 * screen.size.x, "the front row spans %d of %d px" % [front, screen.size.x])
	var bits: Array = []
	for c in main.ui.get_children():
		if c is Control and c.visible:
			bits.append([c.name, c.get_global_rect()])
	check(bits.size() == 2 + game.players.size(), "the HUD is the timer, the help line and a plaque a player (%s)"
			% [bits.map(func(b): return b[0])])
	for a in bits.size():
		check(screen.encloses(bits[a][1]), "%s is fully on screen" % bits[a][0])
		for b in range(a + 1, bits.size()):
			check(not bits[a][1].intersects(bits[b][1]), "%s and %s do not overlap" % [bits[a][0], bits[b][0]])


func seconds(t: float) -> void:
	var end: float = U.time + t
	while U.time < end:
		await get_tree().process_frame


func check(cond: bool, msg: String) -> void:
	print(("ok: " if cond else "FAIL: ") + msg)
	if not cond:
		failures.append(msg)


func _finish() -> void:
	print("PREVIEW TEST PASSED" if failures.is_empty() else "PREVIEW TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)
