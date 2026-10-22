extends "res://tests/human.gd"
## The banner counts every phase in, through real input on the versus map: it names the phase over its seconds in
## the window's centre, nobody acts while it shows, the AI neither, and the phase clock stands; when it runs out the
## phase's horn blows, and the left mouse button places the wall piece, places the cannon and fires.
##   godot --headless --fixed-fps 30 res://tests/phase_test.tscn


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	Main.requested_mode = "versus"
	Main.requested_args = {"seed": "7", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	game = main.game
	human = game.players[0]
	map = game.map
	await _run()
	print("PHASE TEST PASSED" if failures.is_empty() else "PHASE TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)


func _banner() -> Control:
	return main.ui.get_node("Banner")


func _says(word: String, seconds: String) -> bool:
	return _banner().visible and _banner().find_child("Word", true, false).text == word \
			and _banner().find_child("Seconds", true, false).text == seconds


## Waits until the banner shows `left` seconds or fewer.
func _until_left(left: float) -> void:
	while game.readyLeft > left:
		await frames(1)


func _wheel(button: MouseButton, at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.position = at
		ev.pressed = pressed
		Input.parse_input_event(ev)
	await frames(2)


func _middle_drag(from: Vector2, to: Vector2) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_MIDDLE
	b.position = from
	b.pressed = true
	Input.parse_input_event(b)
	await frames(1)
	var m := InputEventMouseMotion.new()
	m.position = to
	m.relative = to - from
	m.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	Input.parse_input_event(m)
	await frames(1)
	b = b.duplicate()
	b.position = to
	b.pressed = false
	Input.parse_input_event(b)
	await frames(1)


func _run() -> void:
	var ai = game.players[1]
	var ai_walls: int = ai.wallTiles.size()
	await frames(2)
	check(_says("BUILD WALLS", "2"), "the game opens on the banner: BUILD WALLS, 2")
	var view := Rect2(Vector2.ZERO, Vector2(get_tree().root.size))
	var r := _banner().get_global_rect()
	check(view.encloses(r) and r.get_center().distance_to(view.get_center()) < 2.0,
			"the banner sits in the window's centre (%s)" % [r])
	for n in ["Timer", "Help", "Hud1", "Hud2"]:
		check(not r.intersects(main.ui.get_node(n).get_global_rect()), "the banner leaves %s free" % n)
	check(r.size.x < view.size.x / 4.0 and r.size.y < view.size.y / 4.0, "the banner is small (%s)" % [r.size])
	for i in 3:
		await _wheel(MOUSE_BUTTON_WHEEL_UP, r.get_center())
	var cam_before: Vector3 = main.camera.global_position
	await _middle_drag(r.get_center(), r.get_center() + Vector2(80, 0))
	check(main.camera.global_position.distance_to(cam_before) > 0.5,
			"a middle drag that starts on the banner pans the board under it")
	for i in 3:
		await _wheel(MOUSE_BUTTON_WHEEL_DOWN, r.get_center())

	_hold("wall_1")
	var spot := free_tile_in_range()
	await point_at_tile(spot)
	check(human.canPlaceWall and human.nextWall.get_parent() == map.tiles[spot.x][spot.y].go,
			"the held piece previews on the board while the banner counts")
	await press("act")
	check(map.tiles[spot.x][spot.y].is_free(), "a left click under the banner places nothing")
	check(game.timeLeftInRound == game.wallDuration, "the wall phase's clock stands under the banner")
	await _until_left(0.9)
	check(_says("BUILD WALLS", "1"), "the banner counts down: 1")
	check(not Sound.playing("horn_build"), "the wall phase's horn waits for the banner")
	await _until_left(0.05)
	check(ai.wallTiles.size() == ai_walls, "the AI places nothing under the banner")

	await _until_left(0.0)
	await frames(2)
	check(not _banner().visible, "the banner goes when its count runs out")
	check(Sound.playing("horn_build"), "the wall phase starts with horn_build")
	check(game.timeLeftInRound < game.wallDuration, "the wall phase's clock runs")
	await point_at_tile(spot)
	await press("act")
	check(U.alive(map.tiles[spot.x][spot.y].structure), "a left click places the wall piece")
	await seconds(2.5)
	check(ai.wallTiles.size() > ai_walls, "the AI builds once the banner is gone")

	game.next_phase()
	await frames(2)
	check(_says("PLACE CANNONS", "2"), "the cannon phase opens on the banner: PLACE CANNONS, 2")
	_pocket()
	var gun_spot := base_xz() + Vector2i(3, 0)
	await seconds(0.5)
	await point_at_tile(gun_spot)
	check(U.alive(human.nextBuilding), "the cannon is dealt under the banner")
	await press("act")
	check(map.tiles[gun_spot.x][gun_spot.y].is_free(), "a left click under the banner places no cannon")
	check(game.timeLeftInRound == 6.0, "the cannon phase lasts a second per placeable cannon: 6 parts, 6 s")
	check(not Sound.playing("horn_guns"), "the cannon phase's horn waits for the banner")
	await _until_left(0.0)
	await frames(2)
	check(Sound.playing("horn_guns"), "the cannon phase starts with horn_guns")
	await point_at_tile(gun_spot)
	await press("act")
	var gun = map.tiles[gun_spot.x][gun_spot.y].structure
	check(U.alive(gun) and Catalog.def_of(gun).id == "cannon", "a left click places the cannon")

	game.next_phase()
	await frames(2)
	check(_says("BATTLE", "2"), "the battle opens on the banner: BATTLE, 2")
	check(human.activeCannons.size() == 1, "the walled cannon survives the check")
	var enemy = null
	for c in map.castles:
		if c.owner() == ai:
			enemy = c
	var ec: Vector2i = map.tile_index_at(enemy.go.global_position)
	await point_at_tile(Vector2i(ec.x, ec.y - 2))
	await press("act")
	check(human.stats.get("shots", 0) == 0, "a left click under the banner fires nothing")
	check(game.timeLeftInRound == game.battleDuration, "the battle's clock stands under the banner")
	check(Sound.music_cue() == "build" and not Sound.playing("horn_battle"), "the battle's horn and music wait")
	await _until_left(0.0)
	await frames(2)
	check(Sound.playing("horn_battle") and Sound.music_cue() == "battle", "the battle starts with its horn and music")
	await press("act")
	check(human.stats.get("shots", 0) == 1, "a left click fires")
	check(not U.projectiles.is_empty(), "the fired shell is airborne")
	var flying := U.projectiles.duplicate()
	game.next_phase()  # the battle's clock runs out under it
	await frames(2)
	check(flying.all(func(s): return not U.alive(s)), "the round's end shoots down every shell still in flight")
	check(_says("BUILD WALLS", "2"), "the next round opens on its banner")

	# the battle ends once neither side holds a cannon: after the grace, not abrupt, and the last
	# shell lands first
	game.next_phase()  # walls -> guns
	await frames(2)
	game.next_phase()  # guns -> battle, through the check
	await frames(2)
	check(_says("BATTLE", "2"), "the second battle opens on its banner")
	await _until_left(0.0)
	await seconds(2.2)
	check(game.phase == game.Phase.BATTLE, "the battle holds while a cannon stands, its quiet grace never starting")
	await point_at_tile(Vector2i(ec.x, ec.y - 2))
	await press("act")
	var shell = null
	for s in U.projectiles:
		if s.player != null:
			shell = s
	check(shell != null, "the human's gun puts the last shell in the air")
	for p in game.players:
		for key in p.cannons.keys():
			map.tiles[key.x][key.y].un_build()
	await frames(2)
	check(game.phase == game.Phase.BATTLE, "a shell in the air holds the disarmed battle")
	var waited := 0
	while U.alive(shell) and waited < 300:
		await frames(1)
		waited += 1
	check(not U.alive(shell) and game.phase == game.Phase.BATTLE,
			"the last shell lands and the battle still waits out its grace")
	await seconds(1.0)
	check(game.phase == game.Phase.BATTLE, "the disarmed battle holds through its grace")
	while game.phase == game.Phase.BATTLE and waited < 300:
		await frames(1)
		waited += 1
	check(game.phase == game.Phase.WALLS and game.roundNumber == 6,
			"the battle ends once neither side holds a cannon and no shell is in the air")
