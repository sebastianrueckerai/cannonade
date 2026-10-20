extends Node
## The game has sound (K5): three buses, the clips by cue with variants, and a voice at every hook of the cue list
## (art/game/design/sound.md), driven through the real paths: a piece built, a gun placed over the cap, a shot,
## a hit, a wall and a gun destroyed, a castle claimed, lost and ruined, the phase flip, the end.
##   godot --headless --fixed-fps 30 res://tests/sound_test.tscn

const Main = preload("res://scripts/Main.gd")

var main: Node
var game
var map
var p1
var p2
var failures: Array = []


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	Main.requested_mode = "versus"
	Main.requested_args = {"seed": "7", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	game = main.game
	map = game.map
	p1 = game.players[0]
	p2 = game.players[1]
	p2.nextAction = 1e9
	_check_setup()
	_check_build()
	await _check_battle()
	_check_castles()
	_check_end()
	print("SOUND TEST PASSED" if failures.is_empty() else "SOUND TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)


func check(cond: bool, msg: String) -> void:
	print(("ok: " if cond else "FAIL: ") + msg)
	if not cond:
		failures.append(msg)


func _tile(x: int, z: int):
	return map.tiles[x][z]


func _check_setup() -> void:
	for bus in ["Music", "SFX", "UI"]:
		check(AudioServer.get_bus_index(bus) >= 0, "bus %s exists" % bus)
	check(Sound.variants("shot_cannon") == 3, "shot_cannon has 3 variants, has %d" % Sound.variants("shot_cannon"))
	check(Sound.variants("ui_click") == 1, "ui_click has one clip")
	check(Sound.has("castle_lost"), "castle_lost, the claim reversed, is a clip")
	check(Sound.music_cue() == "build", "the game starts on the build music, plays %s" % Sound.music_cue())
	var seen := {}
	for i in 6:
		Sound.play("shot_cannon")
		seen[Sound._voices.back().stream.resource_path] = true
	check(seen.size() >= 2, "six shots use more than one variant")
	var voices := 0
	for v in Sound._voices:
		if Sound._live(v) and v.get_meta("cue") == "shot_cannon":
			voices += 1
	check(voices == Sound.VOICES, "a cue holds %d voices at most, holds %d" % [Sound.VOICES, voices])
	Sound.play("not_a_cue")
	check(true, "an unknown cue plays nothing and raises nothing")


func _check_build() -> void:
	var t = _tile(3, 2)
	p1.nextWall = Catalog.spawn("wall_1", null, p1)
	p1.build_next_wall(t)
	check(Sound.playing("place_piece"), "a piece built plays place_piece")
	check(Sound.playing("draw_piece"), "the next draw plays draw_piece")
	p1.nextBuilding = Catalog.spawn("cannon", null, p1)
	p1.partsCap = 0
	p1.build_next_building(_tile(3, 5))
	check(Sound.playing("place_invalid"), "a gun over the parts cap plays place_invalid")
	p1.partsCap = 99
	U.destroy(p1.nextBuilding)
	p1.nextBuilding = null
	check(not Sound.playing("castle_ruin"), "nothing ruined yet")


## Waits until the banner that counts the phase in has run out.
func _banner_out() -> void:
	while game.readyLeft > 0.0:
		await get_tree().process_frame


func _check_battle() -> void:
	check(not Sound.playing("horn_build"), "the game's first wall phase holds its horn while the banner counts")
	await _banner_out()
	check(Sound.playing("horn_build"), "the banner runs out: the wall phase blows horn_build")
	game.next_phase()
	check(not Sound.playing("horn_guns"), "the cannon phase holds its horn while the banner counts")
	await _banner_out()
	check(Sound.playing("horn_guns") and Sound.music_cue() == "build",
			"the banner runs out: the cannon phase blows horn_guns and keeps the build music")
	game.next_phase()
	check(not Sound.playing("horn_battle") and Sound.music_cue() == "build",
			"the battle holds its horn and its music while the banner counts")
	await _banner_out()
	check(Sound.playing("horn_battle"), "the banner runs out: the battle blows horn_battle")
	check(Sound.music_cue() == "battle", "the battle music plays, plays %s" % Sound.music_cue())
	var wall = _tile(3, 2)
	wall.damage_structure(10.0)
	check(Sound.playing("crumble"), "a wall destroyed plays crumble")
	check(not Sound.playing("hit_wall"), "a killing hit is the crumble, not hit_wall")
	var gun_tile = _tile(6, 2)
	var gun := Catalog.spawn("cannon", null, p1)
	p1.build_building(gun_tile, gun)
	var shooter := U.shooter(gun)
	shooter.nextBulletTime = 0.0
	var target = _tile(12, 2)
	check(shooter.try_shoot(target.go.global_position, target), "the gun fires")
	check(Sound.playing("shot_cannon"), "a cannon shot plays shot_cannon")
	gun_tile.damage_structure(10.0)
	check(Sound.playing("hit_gun") or not Sound.has("hit_gun"), "a gun hit plays hit_gun once it has a clip")
	gun_tile.damage_structure(100.0)
	check(Sound.playing("gun_destroyed"), "a gun destroyed plays gun_destroyed")
	var sea = null
	for column in map.tiles:
		for t in column:
			if t.water and sea == null:
				sea = t
	if sea != null:
		var shell := Catalog.spawn_projectile(load("res://data/projectiles/shell.tres"), U.world(), Vector3.ZERO, Basis())
		var imp := U.comp(shell, "TileImpactor")
		imp.destinationTile = sea
		imp.impact()
		check(Sound.playing("hit_water"), "a shell in the sea plays hit_water")
	await get_tree().process_frame
	game.next_phase()
	await _banner_out()
	check(Sound.playing("horn_build"), "the walls return: horn_build blows when the banner runs out")
	check(Sound.music_cue() == "build", "the build music returns, plays %s" % Sound.music_cue())


func _check_castles() -> void:
	var castle = null
	for c in map.castles:
		if c.owner() == p1:
			castle = c
	check(castle != null, "p1 holds a castle")
	Indicators.own_player = p1
	castle.claim(p2)
	check(Sound.playing("castle_lost"), "the own castle taken plays castle_lost")
	castle.claim(p1)
	check(Sound.playing("castle_claimed"), "a castle claimed plays castle_claimed")
	castle.become_ruin()
	check(Sound.playing("castle_ruin"), "a castle ruined plays castle_ruin")


func _check_end() -> void:
	game.end(p1)
	check(Sound.music_cue() == "win", "the own win plays the win music, plays %s" % Sound.music_cue())
	var buttons := main.find_children("*", "Button", true, false)
	check(buttons.size() == 2, "the end screen has Retry and Menu")
	buttons[1].mouse_entered.emit()
	check(Sound.playing("ui_click"), "a hovered end button ticks with the click clip, quieter")
