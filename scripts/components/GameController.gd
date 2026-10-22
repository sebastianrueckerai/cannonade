extends "res://scripts/components/Component.gd"
const TerrainScript = preload("res://scripts/components/Terrain.gd")
## Port of GameController.cs: a round is a wall phase, a cannon phase and a battle.

## The round: walls, then cannons, then the battle. The check runs where the build ends, at GUNS to BATTLE.
enum Phase { WALLS, GUNS, BATTLE }

@export var wallDuration := 45.0
## The gun phase in seconds; 0 derives it: a second per part of the widest hand (its parts cap).
## Single player pins 50; practice and the sandbox pin huge values to run untimed.
@export var gunDuration := 0.0
@export var battleDuration := 30.0
## The banner counts every phase in for this long: nobody acts and the phase clock stands.
@export var readyDuration := 2.0
@export var randomSeed := 41
@export var useRandomSeed := false
@export var initialShips := 7
## The seed the map was built from (Main sets it), so the terrain layout draws from its own
## stream and moves no other seeded expectation (I90).
@export var mapSeed := 0

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
## Once no side holds a cannon, the battle waits this long for the last exchange to settle, so its
## end is not abrupt.
const DISARM_GRACE := 2.0
## U.time the battle went quiet, -1 while a side's cannon or shell is up
var _quietSince := -1.0
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


## How long the current phase lasts: the gun phase a second per cannon the widest hand can place.
func duration() -> float:
	if phase == Phase.GUNS and gunDuration <= 0.0:
		var parts := 0
		for p in players:
			parts = maxi(parts, p.partsCap)
		return float(parts)
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
		if players.size() > 1:
			_place_terrain()
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


# ------------------------------------------------------------- terrain (I90, I91)
## The shapes a feature can take, offsets from its north-west cell ("up" the map is low z):
## a few that make sense to 4x4 and not just rectangles. Rocks and houses fall to shells
## (10 health a tile), hills and mountains absorb every hit.
const TERRAIN_SHAPES := {
	"rocks": [[Vector2i(0, 0)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]],
	"house": [[Vector2i(0, 0)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
			Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]],
	"hill": [[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
			Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]],
	"mountain": [[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
			Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]],
}
## Features drawn per side's generation zone: one half with two players, one quadrant with
## four (the mirrors fill the rest, so every side holds the same blocked tiles).
const TERRAIN_COUNTS := {2: {"mountain": 3, "hill": 2, "rocks": 3, "house": 2},
	4: {"mountain": 2, "hill": 1, "rocks": 2, "house": 1}}
## Spots tried per feature before this map goes without it.
const TERRAIN_ATTEMPTS := 40
## Terrain keeps this Chebyshev distance from a castle centre, so its 5x5 ring stays buildable.
const TERRAIN_CASTLE_CLEAR := 3


## Terrain features over the battlefield (I90, I91): each drawn on one half (one quadrant,
## four players) and mirrored exactly by the castles' flips, so both sides hold the same
## blocked tiles. A feature never touches a castle's build ring, water or another structure,
## and a placement that would cut the last way between castle rings is rolled back.
func _place_terrain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = mapSeed if mapSeed != 0 else randomSeed
	var counts: Dictionary = TERRAIN_COUNTS.get(players.size(), {})
	var zone := Vector2i(map.sizeX, map.sizeZ / 2)
	if players.size() == 4:
		zone.x = map.sizeX / 2
	for kind in ["mountain", "hill", "rocks", "house"]:
		for i in counts.get(kind, 0):
			var shapes: Array = TERRAIN_SHAPES[kind]
			var shape: Array = shapes[rng.randi_range(0, shapes.size() - 1)]
			for attempt in TERRAIN_ATTEMPTS:
				var anchor := Vector2i(rng.randi_range(0, zone.x - 1), rng.randi_range(0, zone.y - 1))
				var cells: Array = []
				for c in shape:
					cells.append(anchor + c)
				var all := _terrain_mirrors(cells)
				if not _terrain_fits(all):
					continue
				var go := _terrain_go(kind, all)
				map.claim_terrain(go, all)
				if _rings_connected():
					break
				map.release_terrain(go, all)


## The cells plus every mirror copy: the castles' z-flip, and with four players the x-flip
## and both, so all sides hold the same blocked tiles (a shape crossing a flip line merges
## with its mirror; the union stays symmetric).
func _terrain_mirrors(cells: Array) -> Array:
	var out: Array = cells.duplicate()
	var flips: Array = [[false, true]] if players.size() != 4 else [[false, true], [true, false], [true, true]]
	for f in flips:
		for c in cells:
			var m := Vector2i(map.sizeX - 1 - c.x if f[0] else c.x, map.sizeZ - 1 - c.y if f[1] else c.y)
			if not out.has(m):
				out.append(m)
	return out


## On the map, on free ground no ship sits on, and clear of every castle's build ring.
func _terrain_fits(cells: Array) -> bool:
	var centres: Array = []
	for c in map.castles:
		if U.alive(c.go):
			centres.append(map.tile_index_at(c.go.global_position))
	for c in cells:
		if c.x < 0 or c.y < 0 or c.x >= map.sizeX or c.y >= map.sizeZ:
			return false
		var t = map.tiles[c.x][c.y]
		if not t.is_free() or U.alive(t.ship):
			return false
		for q in centres:
			if max(absi(c.x - q.x), absi(c.y - q.y)) < TERRAIN_CASTLE_CLEAR:
				return false
	return true


## The feature's GameObject at the centre of its cells: the Terrain component and the art.
## Rocks carry a boulder a tile; a house is one depot of its footprint; hills and mountains
## are one stretched boulder each, placeholders until their own round builds them (C18).
func _terrain_go(kind: String, all: Array) -> Node3D:
	var go := Node3D.new()
	go.name = kind.capitalize()
	map.go.add_child(go)
	var terr := Node.new()
	terr.name = "Terrain"
	terr.set_script(TerrainScript)
	go.add_child(terr)
	terr.map = map
	terr.tiles = all.map(func(c): return map.tiles[c.x][c.y])
	terr.destructible = kind == "rocks" or kind == "house"
	terr.health = terr.HEALTH_PER_TILE * all.size()
	var centre := Vector3.ZERO
	var lo := Vector2i(map.sizeX, map.sizeZ)
	var hi := Vector2i.ZERO
	for c in all:
		centre += map.tile_position(c.x, c.y)
		lo = lo.min(c)
		hi = hi.max(c)
	go.position = centre / all.size()
	var span := Vector2(hi.x - lo.x + 1, hi.y - lo.y + 1)
	match kind:
		"rocks":
			for c in all:
				var b := Art.instance("nature_boulder")
				if b == null:
					continue
				go.add_child(b)
				b.position = map.tile_position(c.x, c.y) - go.position
				b.position.y = map.tiles[c.x][c.y].go.position.y
				b.rotation.y = Art._rng.randf_range(0.0, TAU)
				b.scale = Vector3.ONE * Art._rng.randf_range(1.05, 1.2)
		"house":
			var h := Art.instance("supply" if span.x == 1.0 else ("supply22" if span.x == 2.0 else "supply33"))
			if h != null:
				go.add_child(h)
		"hill":
			_stretched_art(go, "nature_boulder", Vector3(span.x + 0.4, 0.55, span.y + 0.4))
		"mountain":
			_stretched_art(go, "nature_boulder", Vector3(span.x + 0.2, 2.1, span.y + 0.2))
	return go


## One model stretched to `size` (the placeholder mass of a hill or mountain, C18).
func _stretched_art(parent: Node3D, id: String, size: Vector3) -> void:
	var n := Art.instance(id)
	if n == null:
		return
	var b := Art.bounds(n).size
	n.scale = Vector3(size.x / b.x, size.y / b.y, size.z / b.z)
	parent.add_child(n)


## The encirclement guarantee (I91): every castle's build ring (Chebyshev 2 of its centre)
## still reaches every other's over ground no terrain and no water blocks. Walls and other
## buildings are the way itself, so they never block it.
func _rings_connected() -> bool:
	var centres: Array = []
	for c in map.castles:
		if U.alive(c.go):
			centres.append(map.tile_index_at(c.go.global_position))
	if centres.size() < 2:
		return true
	var seen := PackedByteArray()
	seen.resize(map.sizeX * map.sizeZ)
	var queue: Array[Vector2i] = []
	_ring_seeds(centres[0], seen, queue)
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if n.x < 0 or n.y < 0 or n.x >= map.sizeX or n.y >= map.sizeZ:
				continue
			var i: int = n.x * map.sizeZ + n.y
			if seen[i] != 0:
				continue
			var t = map.tiles[n.x][n.y]
			if t.water or (U.alive(t.structure) and U.comp(t.structure, "Terrain") != null):
				continue
			seen[i] = 1
			queue.append(n)
	for q in centres:
		var shell: Array[Vector2i] = []
		_ring_seeds(q, PackedByteArray(), shell)
		var reached := false
		for p in shell:
			if seen[p.x * map.sizeZ + p.y] != 0:
				reached = true
				break
		if not reached:
			return false
	return true


## The build ring's tiles of the castle at `centre`, into `queue` marked in `seen`.
func _ring_seeds(centre: Vector2i, seen: PackedByteArray, queue: Array[Vector2i]) -> void:
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var p := Vector2i(centre.x + dx, centre.y + dz)
			if p.x < 0 or p.y < 0 or p.x >= map.sizeX or p.y >= map.sizeZ:
				continue
			if not seen.is_empty():
				seen[p.x * map.sizeZ + p.y] = 1
			queue.append(p)


func _castle_far(c: Vector2i, placed: Array) -> bool:
	for q in placed:
		if max(absi(c.x - q.x), absi(c.y - q.y)) < 5:
			return false
	return true


## No side holds a cannon and no side's shell is in the air — a ship's shell does not hold the
## round: the battle has nothing left to wait for.
func _disarmed() -> bool:
	for p in players:
		if not p.activeCannons.is_empty():
			return false
	for s in U.projectiles:
		if s.player != null:
			return false
	return true


func _update_round_time(delta: float) -> void:
	if phase == Phase.BATTLE and castles:
		if _disarmed():
			if _quietSince < 0.0:
				_quietSince = U.time
			elif U.time - _quietSince >= DISARM_GRACE:
				next_phase()
				return
		else:
			_quietSince = -1.0
	timeLeftInRound -= delta
	if timeLeftInRound < -1:
		next_phase()
	var s := int(ceilf(timeLeftInRound))
	if s != _ticked and s >= 1 and s <= COUNTDOWN:
		_ticked = s
		Sound.play("countdown")


## Ends the current phase: walls turn into cannons, cannons into the battle (through the rules check), the
## battle into walls, shooting down every shell still in flight so none lands in the build round. The hand
## follows the phase: the wall piece flies away when the cannons come, the gun
## when the battle starts, and a fresh wall is drawn when the walls return. Then the banner counts the new phase in.
func next_phase() -> void:
	if phase == Phase.BATTLE:
		for projectile in U.projectiles.duplicate():
			projectile.shoot_down()
	roundNumber += 1
	phase = ((phase + 1) % Phase.size()) as Phase
	timeLeftInRound = duration()
	readyLeft = readyDuration
	_quietSince = -1.0
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
