extends Node
## The castle looks (C20): every healthy look on disk owns its four damage states and its d3
## rubble, and every placed castle keeps the look it was dealt through its whole damage chain,
## the ruin included.
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
	check(looks.size() >= 2, "alternative castle looks ship (%d on disk)" % looks.size())
	for id in looks:
		var v: int = 1 if id == "castle" else id.get_slice(".", 1).to_int()
		for n in 4:
			check(Art.has_model(state_id(v, n + 1)), "%s owns damage state %d" % [id, n + 1])
		check(Art.has_model(state_id(v, 3) + "_rubble"), "%s owns its d3 rubble for the fall" % id)

	# every placed castle keeps its dealt look through the whole chain
	for c in map.castles:
		var v := worn_look(c)
		for n in [1, 2, 3]:
			c.set_state(n)
			var art: Node3D = c.go.get_node_or_null("Art")
			var worn: String = art.get_meta("art_look", "no art") if art != null else "no art"
			check(worn == state_id(v, n), "the castle in look %d swaps to %s, not %s" % [v, state_id(v, n), worn])
	# the fall: the ruin art is the same look's
	var victim = map.castles[0]
	var v0 := worn_look(victim)
	victim.become_ruin()
	var ruin_art: Node3D = victim.go.get_node_or_null("Art")
	var ruin: String = ruin_art.get_meta("art_look", "no art") if ruin_art != null else "no art"
	check(victim.is_ruin() and ruin == state_id(v0, 4),
			"the castle in look %d falls to its own ruin %s (wore %s)" % [v0, state_id(v0, 4), ruin])
