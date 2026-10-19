extends Node
## The battle lab command line (tools/lab.tscn), run as a real subprocess:
## sweeps and --set change the catalog values the battles use, targets apply,
## CSV rows are complete, bad input fails with a message.
##   godot --headless res://tests/lab_test.tscn

const MapScript = preload("res://scripts/components/Map.gd")
const GameController = preload("res://scripts/components/GameController.gd")

var failures: Array = []


func check(cond: bool, msg: String) -> void:
	print(("ok: " if cond else "FAIL: ") + msg)
	if not cond:
		failures.append(msg)


func _ready() -> void:
	_run()
	print("LAB TEST PASSED" if failures.is_empty() else "LAB TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)


## Runs the lab; returns [exit code, output].
func lab(args: Array) -> Array:
	var out: Array = []
	var cmd := ["--headless", "--fixed-fps", "30", "--path", ProjectSettings.globalize_path("res://"),
		"res://tools/lab.tscn", "--"] + args
	var code := OS.execute(OS.get_executable_path(), cmd, out, true)
	var text := "".join(out)
	check(not text.contains("SCRIPT ERROR") and not text.contains("\nERROR:"), "no engine errors in: lab %s" % " ".join(args))
	return [code, text]


func csv(path: String) -> Array:
	var rows: Array = []
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	var head := lines[0].split(",")
	for i in range(1, lines.size()):
		var cells := lines[i].split(",")
		var row := {}
		for c in head.size():
			row[head[c]] = cells[c]
		rows.append(row)
	return rows


func mean(rows: Array, key: String) -> float:
	return rows.reduce(func(a, r): return a + float(r[key]), 0.0) / rows.size()


## The game's next random number after building an undecorated map whose decorations would come from `makers`.
func draw_after_map(makers: Array) -> int:
	seed(5)
	var go := Node3D.new()
	add_child(go)
	var game := Node.new()
	game.set_script(GameController)
	go.add_child(game)
	var map := Node.new()
	map.set_script(MapScript)
	go.add_child(map)
	map.decorate = false
	map.customModelMakerPrefabs = makers
	map.game = game
	map.make_map([])
	var r := randi()
	go.free()
	return r


func _run() -> void:
	# battles are played without decorations: a change to the decoration set must not change them
	var boulder := preload("res://prefabs/Maker_Boulder.tscn")
	check(draw_after_map([boulder]) == draw_after_map([boulder, preload("res://prefabs/Maker_Bush.tscn"),
			preload("res://prefabs/Maker_LeafTree.tscn")]), "an undecorated map leaves the random numbers alone")
	var dir := OS.get_user_data_dir()
	var sweep_csv := dir.path_join("lab_test_sweep.csv")
	var r := lab(["--scenario=flak_vs_cannons", "--runs=2", "--sweep=flak22.salvo_interval=0.25,3",
		"--targets=walls,guns", "--csv=" + sweep_csv])
	check(r[0] == 0 and r[1].contains("Battle lab: flak_vs_cannons"), "a sweep runs")
	var rows := csv(sweep_csv)
	check(rows.size() == 8 and rows[0].has("flak22.salvo_interval") and rows[0].has("r_intercepted"),
		"one CSV row per battle, named after the swept value")
	var fast := rows.filter(func(x): return float(x["flak22.salvo_interval"]) == 0.25)
	var slow := rows.filter(func(x): return float(x["flak22.salvo_interval"]) == 3.0)
	check(fast.size() == 4 and slow.size() == 4 and fast.map(func(x): return x["seed"] + x["swapped"])
		== ["1false", "1true", "2false", "2true"], "each value is played with seeds 1 and 2, each also swapped")
	# swapped battles report per layout: blue's layout has no flak, red's has one
	check(rows.all(func(x): return x["b_intercepted"] == "0") and fast.all(func(x): return int(x["r_intercepted"]) > 0),
		"results follow the layout when the sides are swapped")
	check(mean(fast, "r_intercepted") > mean(slow, "r_intercepted") + 1.0,
		"a faster flak salvo intercepts more (%.1f vs %.1f)" % [mean(fast, "r_intercepted"), mean(slow, "r_intercepted")])
	check(rows.all(func(x): return int(x["b_guns_lost"]) == 4),
		"red, set to shoot at guns, destroys all four guns (then falls back to walls)")
	check(rows.all(func(x): return int(x["r_guns_lost"]) == 0),
		"the flak side keeps its guns under return fire (hit guns fire slower), also when played as red")
	check(rows.all(func(x): return x["winner"] in ["blue", "red", "draw"] and float(x["time"]) > 0), "every battle has a result")

	# everything but the swept value and the seed
	var key := func(x): return ",".join(PackedStringArray(x.keys().slice(2).map(func(k): return x[k])))
	check(key.call(fast[0]) != key.call(fast[1]) or key.call(slow[0]) != key.call(slow[1]),
		"different seeds give different battles")
	var again_csv := dir.path_join("lab_test_again.csv")
	lab(["--scenario=flak_vs_cannons", "--runs=1", "--seed=2", "--sweep=flak22.salvo_interval=0.25",
		"--targets=walls,guns", "--csv=" + again_csv])
	var again := csv(again_csv)
	check(again.size() == 2 and key.call(again[0]) == key.call(fast[2]) and key.call(again[1]) == key.call(fast[3]),
		"a battle replays exactly with the same seed, also as the first battle of a run")

	# castles decide the game now: with both sides set on them, the battle ends
	# by conquest, not by the time limit
	var siege_csv := dir.path_join("lab_test_siege.csv")
	r = lab(["--scenario=flak_vs_cannons", "--runs=2", "--seed=3", "--targets=castles,castles",
		"--csv=" + siege_csv])
	var sieges := csv(siege_csv)
	var conquered := func(x): return x["winner"] != "draw" and int(x["b_castles_lost"]) + int(x["r_castles_lost"]) > 0
	check(r[0] == 0 and sieges.size() == 4 and sieges.all(conquered),
		"both sides set on castles: the winner comes from castle attrition, not the clock")

	var set_csv := dir.path_join("lab_test_set.csv")
	r = lab(["--scenario=res://data/scenarios/flak_vs_cannons.tres", "--runs=1", "--seed=2",
		"--set=cannon.reload=0.5;flak22.salvo_interval=3", "--swap=false", "--csv=" + set_csv])
	var fast_guns := csv(set_csv)
	check(r[0] == 0 and fast_guns.size() == 1 and fast_guns[0]["seed"] == "2", "--set, --seed and --swap=false run")
	check(float(fast_guns[0]["b_shots"]) > 2.0 * float(slow[2]["b_shots"]),
		"--set changes the value: cannons with a shorter reload fire more (%s vs %s)" % [fast_guns[0]["b_shots"], slow[2]["b_shots"]])

	r = lab(["--scenario=no_such_layout"])
	check(r[0] == 2 and r[1].contains("no scenario"), "an unknown scenario fails with a message")
	r = lab(["--scenario=flak_vs_cannons", "--set=flak22.no_such_field=1"])
	check(r[0] == 2 and r[1].contains("unknown value"), "an unknown value fails with a message")
	DirAccess.remove_absolute(sweep_csv)
	DirAccess.remove_absolute(set_csv)
	DirAccess.remove_absolute(again_csv)
	DirAccess.remove_absolute(siege_csv)
