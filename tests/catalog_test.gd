extends Node
## Building catalog: the shipped data is valid, problems in data files are
## reported (not crashed on), and the workflow "duplicate a file, change it,
## press F5" works in a running game, including recipes made of buildings.
##   godot --headless --fixed-fps 30 res://tests/catalog_test.tscn

const Main = preload("res://scripts/Main.gd")
const TMP := "user://catalog_test"

var failures: Array = []


func check(cond: bool, msg: String) -> void:
	print(("ok: " if cond else "FAIL: ") + msg)
	if not cond:
		failures.append(msg)


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func seconds(t: float) -> void:
	var end: float = U.time + t
	while U.time < end:
		await get_tree().process_frame


func _ready() -> void:
	check(Catalog.errors.is_empty(), "shipped building data has no problems %s" % [Catalog.errors])
	var castle := Catalog.get_def("castle")
	check(castle != null and castle.size == 3 and castle.health == 120.0
			and castle.category == BuildingDef.Category.BASE and castle.draw_weight == 0.0,
			"the castle is a 3x3 base of 120 health that never draws")
	check(Catalog.get_def("base") == null and Catalog.get_def("upgrade_a") == null
			and Catalog.get_def("upgrade_b") == null and Catalog.parked.has("upgrade_a"),
			"the old base and the upgrade blocks are parked out of the game")
	check(Catalog.ids.has("upgrade_a") == false and Catalog.is_ingredient("cannon"),
			"parked defs never draw; the cannon is the ingredient of the fusion")
	_prepare_tmp_catalog()
	_check_problem_reports()
	await _check_workflow_in_game()
	Catalog.load_dir(Catalog.BUILDINGS_DIR)
	print("CATALOG TEST PASSED" if failures.is_empty() else "CATALOG TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)


## A copy of the shipped catalog to edit freely.
func _prepare_tmp_catalog() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	for f in DirAccess.get_files_at(TMP):
		DirAccess.remove_absolute(TMP.path_join(f))
	for f in DirAccess.get_files_at(Catalog.BUILDINGS_DIR):
		if f.ends_with(".tres"):
			DirAccess.copy_absolute(Catalog.BUILDINGS_DIR.path_join(f), TMP.path_join(f))


## A copy of a shipped definition, saved under a new id ("duplicate the file").
func _duplicate(from_id: String, new_id: String) -> BuildingDef:
	var d: BuildingDef = load(Catalog.BUILDINGS_DIR.path_join(from_id + ".tres")).duplicate(true)
	ResourceSaver.save(d, TMP.path_join(new_id + ".tres"))
	return load(TMP.path_join(new_id + ".tres"))


func _check_problem_reports() -> void:
	var bad := _duplicate("cannon22b", "bad_size")
	bad.recipe_pattern = PackedStringArray(["upgrade_a", "upgrade_b"])
	ResourceSaver.save(bad, TMP.path_join("bad_size.tres"))
	var clash := _duplicate("cannon22b", "clash")
	clash.recipe_pattern = PackedStringArray(["upgrade_b", "upgrade_b", "upgrade_b", "upgrade_b"])
	ResourceSaver.save(clash, TMP.path_join("clash.tres"))
	var unknown := _duplicate("supply", "unknown_part")
	unknown.recipe_combine = PackedStringArray(["upgrade_a", "no_such_building"])
	ResourceSaver.save(unknown, TMP.path_join("unknown_part.tres"))
	var no_model := _duplicate("cannon", "no_model")
	no_model.model = null
	ResourceSaver.save(no_model, TMP.path_join("no_model.tres"))
	ResourceSaver.save(load("res://data/projectiles/shell.tres"), TMP.path_join("not_a_building.tres"))
	Catalog.load_dir(TMP, true)
	var all := "\n".join(Catalog.errors)
	check(all.contains("bad_size.tres: recipe_pattern needs 4 entries"), "wrong pattern size is reported")
	check(all.contains("cannon22b and clash have the same recipe_pattern"), "clashing recipes are reported")
	check(all.contains("unknown building 'no_such_building'"), "unknown ids are reported")
	check(all.contains("no_model.tres: no model scene"), "a missing model is reported")
	check(all.contains("not_a_building.tres: not a building definition"), "a file of another type is reported")
	check(Catalog.get_def("bad_size") == null and Catalog.get_def("cannon") != null,
			"broken files are skipped, the rest still loads")
	for f in ["bad_size", "clash", "unknown_part", "no_model", "not_a_building"]:
		DirAccess.remove_absolute(TMP.path_join(f + ".tres"))


func _press_f5() -> void:
	for pressed in [true, false]:
		var k := InputEventKey.new()
		k.keycode = KEY_F5
		k.physical_keycode = KEY_F5
		k.pressed = pressed
		Input.parse_input_event(k)
		await frames(1)


func _check_workflow_in_game() -> void:
	Catalog.load_dir(TMP, true)
	Main.requested_mode = "ai2"
	Main.requested_args = {"seed": "5", "no-decorations": "true"}
	var main := Main.new()
	get_tree().root.add_child.call_deferred(main)
	await frames(1)
	get_tree().current_scene = main
	var game = main.game
	for p in game.players:
		p.nextAction = 1e9
	var map = game.map
	var p1 = game.players[0]

	# change a number and press F5: placed buildings use it at once
	var tile = map.tiles[9][14]
	p1.build_building(tile, Catalog.spawn("cannon"))
	var gun := U.shooter(tile.structure)
	var target = map.tiles[9][3]
	check(gun.try_shoot(target.go.global_position, target), "a placed cannon fires")
	await seconds(0.5)
	check(not gun.try_shoot(target.go.global_position, target), "it is still reloading after 0.5 s")
	var cannon: BuildingDef = load(TMP.path_join("cannon.tres"))
	cannon.behaviour(CannonBehaviour).reload = 0.2
	ResourceSaver.save(cannon, TMP.path_join("cannon.tres"))

	# a new type: duplicate the 2x2 flak, made from cannons and a supply depot
	var battery := _duplicate("flak22", "flak_battery")
	battery.display_name = "Flak battery"
	battery.recipe_pattern = PackedStringArray(["cannon", "cannon", "cannon", "supply"])
	battery.behaviour(FlakBehaviour).shoot_range = 6.0
	ResourceSaver.save(battery, TMP.path_join("flak_battery.tres"))
	await _press_f5()
	await seconds(1.6)  # the shot fired before F5 finishes its old 2 s reload
	check(gun.try_shoot(target.go.global_position, target), "fires again once the old reload is over")
	await seconds(0.3)
	check(gun.try_shoot(target.go.global_position, target), "after F5 the placed cannon reloads in 0.2 s")
	check(Catalog.get_def("flak_battery") != null, "the new building type is in the catalog after F5")

	for k in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var part := "supply" if k == Vector2i(1, 1) else "cannon"
		p1.build_building(map.tiles[10 + k.x][4 + k.y], Catalog.spawn(part))
	var merged = map.tiles[11][5].structure
	var merged_def := Catalog.def_of(merged)
	check(merged_def != null and merged_def.id == "flak_battery", "three cannons and a depot merge into the new flak battery")
	var flak := U.comp(merged, "Flak")
	check(flak != null and flak.shootRange == 6.0, "it got its own flak numbers")
	main.queue_free()
	await frames(2)
