extends Node
## The castle looks (C20): every healthy look on disk owns its four damage states and its d3
## rubble, and every placed castle keeps the look it was dealt through its whole damage chain,
## the ruin included. The flag (I115) flies over every state, re-docked a little lower each hit, in
## the owner colour until the fall takes it down; a randomly placed castle faces a random quarter. The shipped castle model carries the sharp
## pass's creases, the organic trees and bushes stay smooth.
##   godot --headless --fixed-fps 30 res://tests/castle_test.tscn

const Main = preload("res://scripts/Main.gd")

var main: Node
var game
var map
var failures: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
	print(("  - " if cond else "! FAIL ") + msg)


## Look `v`, state `n` (0 healthy to 4 ruin) as the model id on disk.
func state_id(v: int, n: int) -> String:
	var base: String = ["castle", "castle_d1", "castle_d2", "castle_d3", "castle_d4"][n]
	return base if v == 1 else "%s.%d" % [base, v]


func _ready() -> void:
	Art._rng.seed = 7
	Main.requested_mode = "ai2"
	Main.requested_args = {"seed": "21", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	game = main.game
	map = game.map
	await _run()
	print("CASTLE TEST PASSED" if failures.is_empty() else "CASTLE TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)


## The look number a castle's art wears.
func worn_look(c) -> int:
	var id: String = c.go.get_node("Art").get_meta("art_look", "castle")
	return 1 if not id.begins_with("castle.") else id.get_slice(".", 1).to_int()


func _run() -> void:
	await get_tree().process_frame
	# the set ships whole: every healthy look owns its four damage states and its d3 rubble
	var looks := Art.variants("castle")
	check(looks == ["castle", "castle.3", "castle.6"],
			"the game ships the three keeper looks, rejected ones parked (C21): %s" % [looks])
	check(not Art.has_model("base") and Art.variants("base").is_empty(),
			"the parked base ships no model, the castle is the start building (C24)")
	for id in looks:
		var v: int = 1 if id == "castle" else id.get_slice(".", 1).to_int()
		for n in 4:
			check(Art.has_model(state_id(v, n + 1)), "%s owns damage state %d" % [id, n + 1])
		check(Art.has_model(state_id(v, 3) + "_rubble"), "%s owns its d3 rubble for the fall" % id)

	# every placed castle keeps its dealt look through the whole chain
	var dealt := {}
	for c in map.castles:
		dealt[c] = worn_look(c)
		var v: int = dealt[c]
		var flg0: Node3D = c.go.get_node_or_null("Flag")
		var dock0: Node3D = c.go.get_node_or_null("Art").find_child("flag_dock", true, false)
		check(flg0 != null and dock0 != null and flg0.global_position.distance_to(dock0.global_position) < 0.02,
				"the flag of look %d starts on the healthy castle's dock point (I115)" % v)
		for n in [1, 2, 3]:
			c.set_state(n)
			var art: Node3D = c.go.get_node_or_null("Art")
			var worn: String = art.get_meta("art_look", "no art") if art != null else "no art"
			check(worn == state_id(v, n), "the castle in look %d swaps to %s, not %s" % [v, state_id(v, n), worn])
			var flg: Node3D = c.go.get_node_or_null("Flag")
			var dock: Node3D = art.find_child("flag_dock", true, false)
			check(flg != null and dock != null and flg.global_position.distance_to(dock.global_position) < 0.02,
					"the flag of look %d sits on state %d's dock point (I115)" % [v, n])
	# the severe ruin still flies its flag, in the owner colour (a neutral castle's brown) (I115)
	for c in map.castles:
		var p = c.owner()
		var want: Color = p.mainColor if p != null else c.NEUTRAL_COLOR
		var flg2: Node3D = c.go.get_node_or_null("Flag")
		var cloth = flg2.get_node_or_null("flag_cloth") if flg2 != null else null
		var sm: ShaderMaterial = cloth.material_override if cloth is MeshInstance3D else null
		check(sm != null and (sm.get_shader_parameter("albedo") as Color).is_equal_approx(want),
				"the severe ruin of look %d still flies its flag in %s (I115)" % [dealt[c], want])
	# a randomly placed castle faces a random quarter (I115), never a tilted odd angle
	for c in map.castles:
		if c.owner() == null:
			var q: float = absf(fmod(c.go.rotation.y, PI / 2.0))
			check(q < 0.001 or q > PI / 2.0 - 0.001,
					"the neutral castle stands at a quarter turn: %f rad (I115)" % c.go.rotation.y)
	# the fall: the ruin art is the same look's
	var victim = map.castles[0]
	var v0: int = dealt[victim]
	victim.become_ruin()
	var ruin_art: Node3D = victim.go.get_node_or_null("Art")
	var ruin: String = ruin_art.get_meta("art_look", "no art") if ruin_art != null else "no art"
	check(victim.is_ruin() and ruin == state_id(v0, 4),
			"the castle in look %d falls to its own ruin %s (wore %s)" % [v0, state_id(v0, 4), ruin])
	check(victim.go.get_node_or_null("Flag") != null, "the fall keeps the flag up while the castle breaks (I115)")
	await get_tree().create_timer(1.6).timeout
	check(victim.go.get_node_or_null("Flag") == null, "the flag goes down with the crumbled castle (I115)")
	# the sharp pass (kit.py sharpen): creases where the surface bends over 35 deg, the
	# organic trees and bushes exempt
	_check_creases()


## The sharp pass of kit.py (Sebastian, 2026-10-23): everything smooth shaded, edges over
## 35 deg creased, the organic trees and bushes exempt. Read on the shipped glbs as model
## positions whose vertex normals split 30 deg or more.
func _check_creases() -> void:
	var creases := _splits("castle")
	check(creases >= 800,
			"the castle ships creased at its hard bends, not blob-smooth: %d split positions" % creases)
	check(_splits("nature_leaf_tree") == 0 and _splits("nature_bush") == 0,
			"the organic trees and bushes stay fully smooth")


## Positions of shipped model `id` whose vertex normals split 30 degrees or more: the hard
## edges of the shipped shading. A fully smooth model has none; its UV seams copy one normal.
func _splits(id: String) -> int:
	var normals := {}
	var inst := Art.instance(id, true)
	for mi in U.meshes(inst):
		var mesh: ArrayMesh = mi.mesh
		for s in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in vs.size():
				if not normals.has(vs[i]):
					normals[vs[i]] = []
				normals[vs[i]].append(ns[i])
	inst.free()   # unparented instances leak into the runner's ERROR-at-exit gate
	var hard := 0
	for group in normals.values():
		var split := false
		for a in group.size():
			for b in range(a + 1, group.size()):
				if (group[a] as Vector3).dot(group[b]) as float < cos(deg_to_rad(30.0)):
					split = true
					break
			if split:
				break
		if split:
			hard += 1
	return hard
