extends "res://scripts/components/Component.gd"
## Port of GameController.cs: a round is a wall phase, a cannon phase and a battle.

## The round: walls, then cannons, then the battle. The check runs where the build ends, at GUNS to BATTLE.
enum Phase { WALLS, GUNS, BATTLE }

@export var wallDuration := 45.0
@export var gunDuration := 15.0
@export var battleDuration := 30.0
## The banner counts every phase in for this long: nobody acts and the phase clock stands.
@export var readyDuration := 3.0
@export var randomSeed := 41
@export var useRandomSeed := false
@export var initialShips := 7

var phase := Phase.WALLS
## PlayerController / AI components
var players: Array = []
var map = null
var fleet = null
var timeLeftInRound := 0.0
## Seconds left on the banner, 0 once the phase runs
var readyLeft := 0.0
## Phase flips so far
var roundNumber := 0
var started := false
## false: no castles on the map (the sandbox places its own)
var castles := true

signal phase_changed(phase: Phase)
## rules v3 end: the winning player, or null on a draw
signal game_over(winner)

## The last seconds of a phase tick, once a second.
const COUNTDOWN := 5
var _ticked := 0
const HORNS := ["horn_build", "horn_guns", "horn_battle"]


func start_game() -> void:
	if useRandomSeed:
		seed(randomSeed)
	phase = Phase.WALLS
	timeLeftInRound = wallDuration
	map.game = self
	await map.make_map(players)
	fleet.game = self
	fleet.initilize_spawns()
	fleet.spawn_ships(initialShips)
	_initialize_players()
	for p in players:
		p.get_next_wall()
	position_camera()
	started = true
	readyLeft = readyDuration
	Sound.music("build")


## How long the current phase lasts.
func duration() -> float:
	return [wallDuration, gunDuration, battleDuration][phase]


## The share of the view's height kept clear of the board at the top and at the bottom, for the HUD.
var hudBand := Vector2.ZERO


## The camera keeps its pitch and moves back until the board, ground and a block's top, fills the view's width
## or the height between the HUD bands, centred in that space, so a board of any shape fills the window.
func position_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var tv := tan(deg_to_rad(cam.fov / 2.0))
	var th: float = tv * cam.get_viewport().get_visible_rect().size.aspect()
	var b := cam.global_basis
	var half: float = map.tileSize / 2.0
	var p0: Vector3 = map.tile_position(0, 0)
	var p1: Vector3 = map.tile_position(map.sizeX - 1, map.sizeZ - 1)
	var corners: Array[Vector3] = []
	for x in [minf(p0.x, p1.x) - half, maxf(p0.x, p1.x) + half]:
		for z in [minf(p0.z, p1.z) - half, maxf(p0.z, p1.z) + half]:
			for y in [0.0, 1.1]:
				corners.append(Vector3(x, y, z))
	var top := 1.0 - 2.0 * hudBand.x
	var bottom := -1.0 + 2.0 * hudBand.y
	var target := (p0 + p1) / 2.0
	var d: float = 3.0 * maxf(map.sizeX, map.sizeZ) * map.tileSize
	for i in 12:
		var lo := Vector2(INF, INF)
		var hi := -lo
		for c in corners:
			var q: Vector3 = (c - target) * b  # camera space, +z toward the camera
			var n := Vector2(q.x / ((d - q.z) * th), q.y / ((d - q.z) * tv))
			lo = lo.min(n)
			hi = hi.max(n)
		target += b.x * (lo.x + hi.x) / 2.0 * d * th + b.y * ((lo.y + hi.y) - (top + bottom)) / 2.0 * d * tv
		d *= maxf((hi.x - lo.x) / 2.0, (hi.y - lo.y) / (top - bottom))
	cam.global_position = target + b.z * d


func random_shuffle_index(length: int) -> Array:
	return U.shuffle_index(length)


func _initialize_players() -> void:
	for i in players.size():
		var p = players[i]
		p.playerID = i + 1
		p.game = self
		p.map = map
		p.setup()
	if castles:
		_place_castles()
		for p in players:
			p.recompute_parts_cap()


## Free rows between any castle and the map edge: room to wall it in.
const CASTLE_MARGIN := 3
## Rows the two sides keep between their deepest castles, so neither side's castles crowd the middle.
const SIDE_GAP := 5
## Castle centre jitter off its anchor: sideways and deep.
const JITTER := Vector2i(3, 2)


## Where the four neutral castles of a side try to sit, before jitter: the inner pair forward at 0.3 of the
## depth, the outer pair back at 0.18, spread over the width.
func _castle_anchors() -> Array[Vector2i]:
	var w: int = map.sizeX
	var inner := int(map.sizeZ * 0.3)
	var outer := int(map.sizeZ * 0.18)
	return [Vector2i(int(w * 0.35), inner), Vector2i(int(w * 0.65), inner), Vector2i(int(w * 0.15), outer),
			Vector2i(int(w * 0.85), outer)]


## Each player starts with a walled-in castle; with two players, four neutral
## castles a side (mirrored exactly) wait to be ringed and claimed.
func _place_castles() -> void:
	var n := players.size()
	var t: Array = map.tiles
	# a start castle at a quarter of the map keeps the margin
	if map.sizeX < 4 * (CASTLE_MARGIN + 1) or map.sizeZ < 4 * (CASTLE_MARGIN + 1):
		push_error("Map too small for %d players!" % n)
		return
	var dx: int = map.sizeX / 4
	var dz: int = map.sizeZ / 4
	match n:
		1:
			players[0].build_start_castle(t[map.sizeX / 2][map.sizeZ / 2])
		2:
			players[0].build_start_castle(t[map.sizeX / 2][dz])
			players[1].build_start_castle(t[map.sizeX / 2][map.sizeZ - 1 - dz])
		_:
			players[0].build_start_castle(t[dx][dz])
			players[1].build_start_castle(t[dx][map.sizeZ - 1 - dz])
			players[2].build_start_castle(t[map.sizeX - 1 - dx][dz])
			if n == 4:
				players[3].build_start_castle(t[map.sizeX - 1 - dx][map.sizeZ - 1 - dz])
	if n != 2:
		return
	var castle := Catalog.get_def("castle")
	var placed: Array = [Vector2i(map.sizeX / 2, dz), Vector2i(map.sizeX / 2, map.sizeZ - 1 - dz)]
	for anchor in _castle_anchors():
		var c := _neutral_castle_spot(anchor, placed)
		map.place_neutral(castle, c.x - 1, c.y - 1)
		var m := Vector2i(c.x, map.sizeZ - 1 - c.y)
		map.place_neutral(castle, m.x - 1, m.y - 1)
		placed.append(c)
		placed.append(m)


## A jittered castle centre: up to JITTER off the anchor from the game's random numbers, inside the
## side's band and off the margin, at Chebyshev distance at least 5 from every castle already placed. The
## exact mirror has to keep its distance too. Falls back to the anchor itself.
func _neutral_castle_spot(anchor: Vector2i, placed: Array) -> Vector2i:
	var lo := CASTLE_MARGIN + 1  # the centre of a 3x3 whose edge sits on the margin
	var max_z: int = map.sizeZ / 2 - SIDE_GAP
	for i in 25:
		var c := anchor + Vector2i(U.rint(-JITTER.x, JITTER.x + 1), U.rint(-JITTER.y, JITTER.y + 1))
		if c.x < lo or c.y < lo or c.x > map.sizeX - 1 - lo or c.y > max_z:
			continue
		var m := Vector2i(c.x, map.sizeZ - 1 - c.y)
		if _castle_far(c, placed) and _castle_far(m, placed):
			return c
	return anchor


func _castle_far(c: Vector2i, placed: Array) -> bool:
	for q in placed:
		if max(absi(c.x - q.x), absi(c.y - q.y)) < 5:
			return false
	return true


func _update_round_time(delta: float) -> void:
	timeLeftInRound -= delta
	if timeLeftInRound < -1:
		next_phase()
	var s := int(ceilf(timeLeftInRound))
	if s != _ticked and s >= 1 and s <= COUNTDOWN:
		_ticked = s
		Sound.play("countdown")


## Ends the current phase: walls turn into cannons, cannons into the battle (through the rules check), the
## battle into walls. The hand follows the phase: the wall piece flies away when the cannons come, the gun
## when the battle starts, and a fresh wall is drawn when the walls return. Then the banner counts the new phase in.
func next_phase() -> void:
	roundNumber += 1
	phase = ((phase + 1) % Phase.size()) as Phase
	timeLeftInRound = duration()
	readyLeft = readyDuration
	if phase == Phase.BATTLE and castles and started:
		run_check()
	for p in players:
		match phase:
			Phase.WALLS:
				p.get_next_wall()
			Phase.GUNS:
				p.drop(p.nextWall, true)
			Phase.BATTLE:
				p.drop(p.nextBuilding, false)
	phase_changed.emit(phase)
	if started and readyLeft <= 0.0:
		_begin()


## The banner ran out: the phase's horn blows and its music plays.
func _begin() -> void:
	readyLeft = 0.0
	Sound.play(HORNS[phase])
	Sound.music("battle" if phase == Phase.BATTLE else "build")


# ------------------------------------------------------------- the check
## Regions of enclosed, non-wall tiles. Each region maps to the player number of its ring owner
## (Map.ring_owner), 0 to none.
func _ring_regions() -> Dictionary:
	var seen := PackedByteArray()
	seen.resize(map.sizeX * map.sizeZ)
	var regions := {}
	for x in map.sizeX:
		for z in map.sizeZ:
			var i: int = x * map.sizeZ + z
			if seen[i] != 0:
				continue
			var t = map.tiles[x][z]
			if t.isWall or not map.is_tile_enclosed(x, z):
				seen[i] = 1
				continue
			var queue: Array[Vector2i] = [Vector2i(x, z)]
			var head := 0
			var tiles: Array = []
			seen[i] = 1
			while head < queue.size():
				var c: Vector2i = queue[head]
				head += 1
				tiles.append(map.tiles[c.x][c.y])
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if n.x < 0 or n.y < 0 or n.x >= map.sizeX or n.y >= map.sizeZ:
						continue
					if not map.tiles[n.x][n.y].isWall and seen[n.x * map.sizeZ + n.y] == 0 and map.is_tile_enclosed(n.x, n.y):
						seen[n.x * map.sizeZ + n.y] = 1
						queue.append(n)
			var owner = map.ring_owner(tiles)
			for t2 in tiles:
				regions[t2] = owner.playerID if owner != null else 0
	return regions


## The rules-v3 check, at the end of every build phase: owned buildings
## outside their owner's ring burn (castles become ruins), a castle inside
## another player's ring changes owner, caps follow the castles held, and a
## player holding no castle is out.
func run_check() -> void:
	var regions := _ring_regions()
	for p in players:
		var burn: Array = []
		for group in [p.cannons, p.supports, p.supplies]:
			for key in group:
				burn.append(map.tiles[key.x][key.y])
		for t in burn:
			if not U.alive(t.structure) or regions.get(t, 0) == p.playerID:
				continue
			if t.upgradeCluster != null:
				t.upgradeCluster.un_build_upgrade()
			else:
				t.un_build()
	for castle in map.castles.duplicate():
		if not U.alive(castle) or castle.is_ruin():
			continue
		var c: Vector2i = map.tile_index_at(castle.go.global_position)
		var region: int = regions.get(map.tiles[c.x][c.y], 0)
		var holder = castle.owner()
		if region == 0:
			if holder != null:
				castle.become_ruin()
			continue
		var holder_id: int = holder.playerID if holder != null else -1
		if region == holder_id:
			continue
		var claimant = null
		for p in players:
			if p.playerID == region:
				claimant = p
		if claimant != null:
			castle.claim(claimant)
	for p in players:
		p.recompute_parts_cap()
	decide()


## Rules v3 end: once fewer than two players hold a castle, the last holder wins, nobody a draw.
## Runs at the check and the moment a shell leaves a castle a ruin.
func decide() -> void:
	if not (castles and started) or players.size() < 2:
		return
	var holders: Array = players.filter(func(p): return p.castle_count() > 0)
	if holders.size() < 2:
		end(holders[0] if holders.size() == 1 else null)


## The game stops and the game-over screen names `winner`, null for a draw.
func end(winner) -> void:
	started = false
	game_over.emit(winner)


func _process(delta: float) -> void:
	if not started:
		return
	if readyLeft > 0.0:
		readyLeft -= delta
		if readyLeft <= 0.0:
			_begin()
	else:
		_update_round_time(delta)
	for p in players:
		p.refresh_active_cannons()
		p.try_get_next_building()
		p.update_point_and_tile_selected()
		if readyLeft <= 0.0:
			p.manage_player_actions()
