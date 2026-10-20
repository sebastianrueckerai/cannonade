extends Node
## The targeting marker is a cube of additive light on the aimed-at tile, a
## wall block's size on the slab, so the ground and whatever stands there turn
## lighter; no material changes (playtest round 4: emission on the castle blew
## its team surface out to white). Only the human's shots light a tile while a
## human plays; with no human (AI against AI) every side's do (I64).
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


func seconds(t: float) -> void:
	var end: float = U.time + t
	while U.time < end:
		await get_tree().process_frame


## A free tile between lo and hi from `tile`.
func spot(tile, lo: float, hi: float):
	for x in map.sizeX:
		for z in map.sizeZ:
			var t = map.tiles[x][z]
			var d: float = t.go.global_position.distance_to(tile.go.global_position)
			if t.is_free() and d >= lo and d <= hi:
				return t
	return null


func shells_of(p) -> Array:
	return U.projectiles.filter(func(s): return s.player == p)


## Waits until none of p's shells is in flight (the ships keep firing their own).
func landed(p) -> void:
	for i in 300:
		if shells_of(p).is_empty():
			return
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


func slab_clean(tile) -> bool:
	var m: Material = tile.model().get_surface_override_material(0)
	return not (m is StandardMaterial3D and m.emission_enabled)


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
	check(tile.go.get_node_or_null("TargetLight") == null, "an untargeted tile carries no light")

	# the aim path (TileImpactor.aim_tile calls target_on with the shooter colour)
	tile.target_on(Color.RED)
	var light := tile.go.get_node_or_null("TargetLight") as MeshInstance3D
	check(light != null and light.visible, "the aimed-at tile carries a visible light cube")
	if light == null:
		return
	var box: AABB = light.global_transform * light.get_aabb()
	check(box.size.is_equal_approx(Vector3.ONE),
			"the cube is a tile wide and a wall block tall (%s)" % box.size)
	check(box.position.is_equal_approx(tile.go.global_position + Vector3(-0.5, Art.SLAB_TOP, -0.5)),
			"it stands on the slab top over the whole tile (%s)" % box.position)
	var m := light.material_override as StandardMaterial3D
	check(m != null and m.blend_mode == BaseMaterial3D.BLEND_MODE_ADD
			and m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "the cube adds light")
	check(m != null and m.albedo_color.a > 0.0 and m.albedo_color.a <= 0.4,
			"the light stays subtle (alpha %s)" % (m.albedo_color.a if m != null else -1.0))
	check(m != null and Color(m.albedo_color, 1.0).is_equal_approx(Color.WHITE.lerp(Color.RED, 0.3)),
			"the light is tinted in the shooter's colour (%s)" % (m.albedo_color if m != null else null))
	check(slab_clean(tile), "the slab's material carries no glow")
	check(castle_clean(c), "the castle on the aimed-at tile keeps its colours")

	# a second shot in flight keeps the light until both have landed
	# (TileImpactor.impact and _exit_tree call target_off)
	tile.target_on(Color.BLUE)
	tile.target_off()
	check(light.visible, "the light stays while a second shot is in flight")
	tile.target_off()
	check(not light.visible, "the light clears when the last shot lands")
	check(castle_clean(c) and slab_clean(tile), "the castle and the slab still carry no emission")

	# whose shots light a tile: with a human in the game only the human's (Indicators.own_player,
	# set by Main), with none (AI against AI) everyone's. Real shots, the AI's from farther out, so
	# its flatter shell lands first.
	var human = game.players[0]
	var ai = game.players[1]
	check(Indicators.own_player == human, "Main hands the aim to the human")
	var far = spot(tile, 14.0, 18.0)
	var near = spot(tile, 4.0, 7.0)
	var ai_gun: Node3D = ai.place(Catalog.get_def("cannon"), far.idxX, far.idxZ)
	var own_gun: Node3D = human.place(Catalog.get_def("cannon"), near.idxX, near.idxZ)
	check(U.shooter(ai_gun).try_shoot(tile.go.global_position, tile), "the AI's gun fires at the tile")
	check(tile._target_tints == 0 and not light.visible, "the AI's shot lights nothing while a human plays")
	check(U.shooter(own_gun).try_shoot(tile.go.global_position, tile), "the human's gun fires at the tile")
	check(tile._target_tints == 1 and light.visible, "the human's shot lights the tile")
	await landed(ai)
	check(not shells_of(human).is_empty() and light.visible and tile._target_tints == 1,
			"the AI's shell lands first and leaves the human's light")
	await landed(human)
	check(not light.visible and tile._target_tints == 0, "the light goes when the human's shell lands")
	Indicators.own_player = null  # watch mode: no human in the game
	await seconds(U.shooter(ai_gun).secondsBetweenShots + 0.1)
	check(U.shooter(ai_gun).try_shoot(tile.go.global_position, tile), "with no human the AI's gun fires again")
	check(tile._target_tints == 1 and light.visible
			and Color(m.albedo_color, 1.0).is_equal_approx(Color.WHITE.lerp(ai.mainColor, 0.3)),
			"and lights the tile in its colour")
