extends Node
## Checks that StatesMap.waterflow_blocks() gives exactly the same open / closed
## grids as the original algorithm (waterflow_reference) for random edits.
##   godot --headless res://tests/flood_test.tscn

const Main = preload("res://scripts/Main.gd")
const StatesMap = preload("res://scripts/StatesMap.gd")
const WALLS := [preload("res://prefabs/BlockCorner.tscn"), preload("res://prefabs/BlockCross.tscn"),
	preload("res://prefabs/BlockLine.tscn"), preload("res://prefabs/BlockThree.tscn"),
	preload("res://prefabs/Cannon.tscn")]


const RING := {
	Vector2i(-1, 1): [false, true, false, true], Vector2i(1, 1): [false, true, true, false],
	Vector2i(-1, -1): [true, false, false, true], Vector2i(1, -1): [true, false, true, false],
	Vector2i(0, -1): [false, false, true, true], Vector2i(0, 1): [false, false, true, true],
	Vector2i(-1, 0): [true, true, false, false], Vector2i(1, 0): [true, true, false, false]}
var _mismatches := 0
var _t_ref := 0


func _check(ref, cur, tile) -> void:
	var p0: int = StatesMap.profile_usec
	StatesMap.use_reference = true
	ref.update_tile(tile)
	StatesMap.use_reference = false
	_t_ref += StatesMap.profile_usec - p0
	StatesMap.profile_usec = p0
	if ref.open != cur.open or ref.closed != cur.closed:
		_mismatches += 1
		if _mismatches < 5:
			printerr("mismatch at %d,%d" % [tile.idxX, tile.idxZ])
		ref.open = cur.open.duplicate()
		ref.closed = cur.closed.duplicate()


func _ready() -> void:
	Main.requested_mode = "ai2"
	Main.requested_args = {"seed": "11", "no-decorations": "true"}
	var main := Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	var game = main.game
	for p in game.players:
		p.nextAction = 1e9
	var map = game.map
	var player = game.players[0]
	var cur = map.statesMap
	var ref := StatesMap.new()
	ref.reset(map)
	ref.open = cur.open.duplicate()
	ref.closed = cur.closed.duplicate()
	var mismatches := 0
	var ops := 600
	var t_blocks := 0
	var t_ref := 0
	seed(5)
	for i in ops:
		var x := randi_range(1, map.sizeX - 2)
		var z := randi_range(1, map.sizeZ - 2)
		var tile = map.tiles[x][z]
		var p0: int = StatesMap.profile_usec
		if i % 3 == 0 and x > 1 and z > 1 and x < map.sizeX - 2 and z < map.sizeZ - 2:
			# build a ring around (x, z) with matching wall pieces
			var free_ring := true
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					if U.alive(map.tiles[x + dx][z + dz].structure) or map.tiles[x + dx][z + dz].water:
						free_ring = false
			if free_ring:
				for k in RING:
					var t = map.tiles[x + k.x][z + k.y]
					player._build_from_random_prefabs(t, RING[k])
					_check(ref, cur, t)
				continue
		if U.alive(tile.structure):
			if tile.upgradeCluster == null:
				tile.un_build()
		elif not tile.water:
			var w: Node3D = WALLS[randi() % WALLS.size()].instantiate()
			for r in randi() % 4:
				U.comp(w, "BuildingBlock").rotate_clockwise()
			player.build_building(tile, w)
		t_blocks += StatesMap.profile_usec - p0
		_check(ref, cur, tile)
	mismatches = _mismatches
	t_ref = _t_ref
	var enclosed := 0
	for c in cur.closed:
		enclosed += c
	print("ops=%d mismatches=%d closed_cells=%d blocks=%.1fms reference=%.1fms" % [ops, mismatches, enclosed,
			t_blocks / 1000.0, t_ref / 1000.0])
	print("FLOOD TEST PASSED" if mismatches == 0 else "FLOOD TEST FAILED")
	get_tree().quit(0 if mismatches == 0 else 1)
