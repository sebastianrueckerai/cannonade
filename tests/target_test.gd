extends Node
## The targeting marker glows the tile slab only: a castle on the aimed-at
## tile keeps its colours (playtest round 4: castles flashed white and player
## colours for every shot in flight aimed at them).
##   godot --headless --fixed-fps 30 res://tests/target_test.tscn

const Main = preload("res://scripts/Main.gd")

var main: Node
var game
var map
var failures: Array = []


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)  # headless windows are 64 x 64
	Main.requested_mode = "versus"
	Main.requested_args = {"seed": "4", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	game = main.game
	map = game.map
	game.players[1].dormant = true  # keep the map static; the marker is under test
	await _run()
	print("TARGET TEST PASSED" if failures.is_empty() else "TARGET TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


## No unscripted mesh of the castle's art carries a surface-0 override with
## emission on (the glow is what blew the team surface out to stark white).
func castle_clean(c) -> bool:
	for mi in U.meshes(c.go.get_node("Art")):
		if mi.get_script() != null:
			continue
		var m: Material = mi.get_surface_override_material(0)
		if m is StandardMaterial3D and m.emission_enabled:
			return false
	return true


func _run() -> void:
	var c = null
	for k in map.castles:
		if U.alive(k) and not k.is_ruin() and k.owner() == null:
			c = k
			break
	check(c != null, "a neutral castle exists")
	if c == null:
		return
	await frames(2)
	check(castle_clean(c), "the untouched castle carries no emission")
	var cc: Vector2i = map.tile_index_at(c.go.global_position)
	var tile = map.tiles[cc.x][cc.y]
	check(U.alive(tile.structure) and tile.structure == c.go,
			"the castle stands on its centre tile")

	# the aim path (TileImpactor.aim_tile calls target_on with the shooter colour)
	tile.target_on(Color.RED)
	var slab = tile.model()
	var sm: Material = slab.get_surface_override_material(0)
	check(sm is StandardMaterial3D and sm.emission_enabled,
			"the aimed-at tile's slab carries the targeting glow")
	check(castle_clean(c),
			"the castle on the aimed-at tile carries no emission and keeps its colours")

	# the landing (TileImpactor.impact and _exit_tree call target_off)
	tile.target_off()
	sm = slab.get_surface_override_material(0)
	check(sm is StandardMaterial3D and not sm.emission_enabled,
			"the targeting glow clears when the shot lands")
	check(castle_clean(c), "the castle still carries no emission")
