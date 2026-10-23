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
		if players.size() == 2:
			_place_rivers()
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


# ------------------------------------------------------------- rivers (I104)
## River tiles keep this Chebyshev distance from every castle centre: a free tile between the castle's 3x3 and the
## water, so its build ring stays land.
const RIVER_CASTLE_CLEAR := 3
## A river stamps the 3x3 round every tile of its course: three wide, past the reach of 2, so crossing takes a bridge.
const RIVER_HALF := 1
## The most castles of their own half a layout may cut off from each start castle: half of the four.
const RIVER_CUT_MAX := 2
## Layouts drawn before the board goes without a river.
const RIVER_ATTEMPTS := 60
## The noise cell in tiles: a river bends about this often.
const RIVER_BEND := 6
const DIRS8: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


## Rivers between the castles and the terrain (I104): one from the north edge to the south edge, or one a side
## cutting a corner off from its back edge to its west or east edge, each course the cheapest way over a noise
## field (rivers follow valleys) that keeps clear of every castle. A layout stands only when it is fair (_river_fair);
## the river draws from its own generator, so the game's random numbers stay put.
func _place_rivers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("river%d" % (mapSeed if mapSeed != 0 else randomSeed))
	var h: int = map.sizeZ
	var allowed := PackedByteArray()
	allowed.resize(map.sizeX * h)
	allowed.fill(1)
	for c in map.castles:
		var q: Vector2i = map.tile_index_at(c.go.global_position)
		var r := RIVER_CASTLE_CLEAR + RIVER_HALF
		for x in range(maxi(q.x - r + 1, 0), mini(q.x + r, map.sizeX)):
			for z in range(maxi(q.y - r + 1, 0), mini(q.y + r, h)):
				allowed[x * h + z] = 0
	for attempt in RIVER_ATTEMPTS:
		var water := _river_layout(rng, allowed)
		if not water.is_empty() and _river_fair(water):
			for c: Vector2i in water:
				map.make_river(c.x, c.y, rng.randf())
			return


## The river tiles of one drawn layout, empty when a course finds no way.
func _river_layout(rng: RandomNumberGenerator, allowed: PackedByteArray) -> Dictionary:
	var w: int = map.sizeX
	var h: int = map.sizeZ
	var ends: Array = []
	var north := Vector2i(rng.randi_range(0, w - 1), 0)
	if rng.randf() < 0.5:
		ends.append([north, Vector2i(rng.randi_range(0, w - 1), h - 1)])
	else:  # each side's corner is drawn on its own, so the board is no mirror
		var south := Vector2i(rng.randi_range(0, w - 1), h - 1)
		ends.append([north, Vector2i(w - 1 if north.x >= w / 2 else 0, rng.randi_range(0, h / 2 - 1))])
		ends.append([south, Vector2i(w - 1 if south.x >= w / 2 else 0, rng.randi_range(h / 2, h - 1))])
	var cost := _river_noise(rng)
	var water := {}
	for e in ends:
		var course := _river_course(e[0], e[1], cost, allowed)
		if course.is_empty():
			return {}
		for p: Vector2i in course:
			for dx in range(-RIVER_HALF, RIVER_HALF + 1):
				for dz in range(-RIVER_HALF, RIVER_HALF + 1):
					var q := p + Vector2i(dx, dz)
					if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
						water[q] = true
	return water


## A step's cost per tile, 1 in the valleys to 5 on the ridges of a smooth random field.
func _river_noise(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var gw: int = map.sizeX / RIVER_BEND + 2
	var gh: int = map.sizeZ / RIVER_BEND + 2
	var grid := PackedFloat32Array()
	for i in gw * gh:
		grid.append(rng.randf())
	var out := PackedFloat32Array()
	for x in map.sizeX:
		for z in map.sizeZ:
			var fx := float(x) / RIVER_BEND
			var fz := float(z) / RIVER_BEND
			var ix := int(fx)
			var iz := int(fz)
			var top := lerpf(grid[ix * gh + iz], grid[(ix + 1) * gh + iz], fx - ix)
			var bottom := lerpf(grid[ix * gh + iz + 1], grid[(ix + 1) * gh + iz + 1], fx - ix)
			out.append(1.0 + 4.0 * lerpf(top, bottom, fz - iz))
	return out


## The cheapest 8-connected course from `a` to `b` over the allowed tiles, both ends included; empty when none.
func _river_course(a: Vector2i, b: Vector2i, cost: PackedFloat32Array, allowed: PackedByteArray) -> Array[Vector2i]:
	var h: int = map.sizeZ
	var start: int = a.x * h + a.y
	var goal: int = b.x * h + b.y
	if allowed[start] == 0 or allowed[goal] == 0:
		return []
	var dist := PackedFloat32Array()
	dist.resize(map.sizeX * h)
	dist.fill(INF)
	var from := PackedInt32Array()
	from.resize(map.sizeX * h)
	from.fill(-1)
	var keys := PackedFloat32Array([0.0])  # negated distances, ascending: the nearest pops off the end
	var open := PackedInt32Array([start])
	dist[start] = 0.0
	while not open.is_empty():
		var i: int = open[open.size() - 1]
		var d: float = -keys[keys.size() - 1]
		open.resize(open.size() - 1)
		keys.resize(keys.size() - 1)
		if i == goal:
			break
		if d > dist[i]:
			continue
		for v in DIRS8:
			var q := Vector2i(i / h, i % h) + v
			if q.x < 0 or q.y < 0 or q.x >= map.sizeX or q.y >= h:
				continue
			var j: int = q.x * h + q.y
			var nd: float = d + (1.0 if v.x == 0 or v.y == 0 else 1.4142) * cost[j]
			if allowed[j] == 0 or nd >= dist[j]:
				continue
			dist[j] = nd
			from[j] = i
			var at := keys.bsearch(-nd)
			keys.insert(at, -nd)
			open.insert(at, j)
	if from[goal] < 0:
		return []
	var course: Array[Vector2i] = []
	var k := goal
	while k >= 0:
		course.append(Vector2i(k / h, k % h))
		k = from[k]
	return course


## A layout is fair when the river cuts the same castles off from both start castles over land: 1 to RIVER_CUT_MAX of
## each player's own half, and the same count of castles stays on each start castle's land. Every land region holds
## a castle, so no strip of ground lies dead.
func _river_fair(water: Dictionary) -> bool:
	var h: int = map.sizeZ
	var region := PackedInt32Array()
	region.resize(map.sizeX * h)
	region.fill(-1)
	var regions := 0
	for x in map.sizeX:
		for z in h:
			if region[x * h + z] >= 0 or water.has(Vector2i(x, z)):
				continue
			region[x * h + z] = regions
			var queue: Array[Vector2i] = [Vector2i(x, z)]
			var head := 0
			while head < queue.size():
				var p: Vector2i = queue[head]
				head += 1
				for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = p + v
					if n.x < 0 or n.y < 0 or n.x >= map.sizeX or n.y >= h or region[n.x * h + n.y] >= 0 \
							or water.has(n):
						continue
					region[n.x * h + n.y] = regions
					queue.append(n)
			regions += 1
	var held := PackedByteArray()
	held.resize(regions)
	var home := [-1, -1]
	for c in map.castles:
		var q: Vector2i = map.tile_index_at(c.go.global_position)
		held[region[q.x * h + q.y]] = 1
		for i in 2:
			if c.owner() == players[i]:
				home[i] = region[q.x * h + q.y]
	if held.has(0):
		return false
	var cut := [0, 0]
	var kept := [0, 0]
	for c in map.castles:
		var q: Vector2i = map.tile_index_at(c.go.global_position)
		for i in 2:
			if region[q.x * h + q.y] == home[i]:
				kept[i] += 1
			elif (q.y < h / 2) == (i == 0):
				cut[i] += 1
	return cut[0] == cut[1] and cut[0] >= 1 and cut[0] <= RIVER_CUT_MAX and kept[0] == kept[1]


# ------------------------------------------------------------- terrain (I90, I91, I93, I96, I100, I116)
## Units a side (two players) or a quadrant (four) grows (I116): the first of every three a
## rock, the rest hills, so every board holds both sorts. --terrain=N overrides.
const TERRAIN_DEFAULT := 3
@export var terrainCount := TERRAIN_DEFAULT
## Spot draws a unit takes before this map goes without it.
const TERRAIN_DRAWS := 24
## Terrain keeps this Chebyshev distance from a castle centre, so its 5x5 ring stays buildable.
const TERRAIN_CASTLE_CLEAR := 3
## Free tiles between two units (Chebyshev), so masses stand as the units they were grown as,
## never two shapes dropped flush by accident (I116).
const TERRAIN_GAP := 2
## A family's caps: tiles in a unit and its bounding box. Rocks stand up to four stories,
## hills three (Sebastian, 2026-10-23).
const HILL_CAP := 30
const HILL_SPAN := 9
const ROCK_CAP := 44
const ROCK_SPAN := 11
## All units together hold at most this share of the board's free tiles.
const TERRAIN_SHARE := 0.30
## How far the sides may drift apart: the poorer keeps at least 1 - this of the richer
## (Sebastian, 2026-10-23: "The point is not to mayorly give a benefit just to one side").
const TERRAIN_BAND := 0.10
const DIRS4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Terrain as grown units (I116): each unit picks its spots (the best of TERRAIN_DRAWS
## scored draws) and eats the open ground around them until a cap or a wall of constraints
## stops it, so every shape is an organic blob as big as the board allows - no shape table
## draws these. Rocks seed a short line of spots, one ridge as one unit. The ground ways
## between castle rings are reserved before anything grows and a candidate that would strand
## free ground is thrown away whole, so every castle stays reachable and its build ring
## placeable; the sides end within TERRAIN_BAND of each other. Hills climb one level a tile
## in every direction, rocks only toward the player, so nothing hides the ground behind it
## from the camera in the placing round. Hills grow trees once the drapes settle.
func _place_terrain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = mapSeed if mapSeed != 0 else randomSeed
	var half := Vector2i(map.sizeX / 2, map.sizeZ / 2)
	var seats: Array = [[Vector2i.ZERO, Vector2i(map.sizeX, half.y)], [Vector2i(0, half.y), Vector2i(map.sizeX, map.sizeZ)]]
	if players.size() == 4:
		seats = [[Vector2i.ZERO, half], [Vector2i(half.x, 0), Vector2i(map.sizeX, half.y)],
			[Vector2i(0, half.y), Vector2i(half.x, map.sizeZ)], [half, Vector2i(map.sizeX, map.sizeZ)]]
	var centres: Array = []
	for c in map.castles:
		if U.alive(c.go):
			centres.append(map.tile_index_at(c.go.global_position))
	var keep_out := {}  # the castles' clear zones, then every landed unit's gap ring
	for q in centres:
		for dx in range(-(TERRAIN_CASTLE_CLEAR - 1), TERRAIN_CASTLE_CLEAR):
			for dz in range(-(TERRAIN_CASTLE_CLEAR - 1), TERRAIN_CASTLE_CLEAR):
				keep_out[Vector2i(q.x + dx, q.y + dz)] = true
	var reach := _terrain_reach({})
	var ways := _terrain_ways(centres)
	var units: Array = []  # [sort, cells Dictionary]
	var blocked := {}  # every landed unit's cells
	var budget := int(reach.size() * TERRAIN_SHARE)
	for i in terrainCount:
		var sort := "rock" if i % 3 == 0 else "hill"
		for seat in seats:
			var cells := _grow_unit(rng, sort, seat, centres, ways, blocked, keep_out, budget, reach)
			if cells.is_empty():
				continue
			units.append([sort, cells])
			for c in cells:
				blocked[c] = true
				for dx in range(-(TERRAIN_GAP - 1), TERRAIN_GAP):
					for dz in range(-(TERRAIN_GAP - 1), TERRAIN_GAP):
						keep_out[c + Vector2i(dx, dz)] = true
			budget -= cells.size()
	_terrain_balance(units)
	for u in units:
		var go := _terrain_go(u[0], u[1].keys(), _unit_heights(u[0], u[1]))
		map.claim_terrain(go, u[1].keys())
	_terrain_sight()
	_terrain_ease()
	_terrain_decorations()


## Grows one unit for `seat` (I116): the best of TERRAIN_DRAWS scored spots seeds a growth
## that eats open ground until the family's caps, the seat's edge, a castle clear, a reserved
## way or another unit's gap stops it; then pinholes fill, slivers drop and the largest
## connected part stays - one mass, one unit. A candidate the board cannot take (it would
## strand free ground) is thrown away whole and the next draw grows. Rocks seed a short line
## of spots, a ridge born as one unit.
func _grow_unit(rng: RandomNumberGenerator, sort: String, seat: Array, centres: Array,
		ways: Dictionary, blocked: Dictionary, keep_out: Dictionary, budget: int, reach: Dictionary) -> Dictionary:
	var cap := ROCK_CAP if sort == "rock" else HILL_CAP
	var span := ROCK_SPAN if sort == "rock" else HILL_SPAN
	var room := mini(cap, budget)
	if room < 2:
		return {}
	var best := Vector2i(-1, -1)
	var best_score := -1.0
	for i in TERRAIN_DRAWS:
		var spot := Vector2i(rng.randi_range(seat[0].x, seat[1].x - 1), rng.randi_range(seat[0].y, seat[1].y - 1))
		if not _unit_open(spot, seat, ways, keep_out):
			continue
		var score := _seed_score(spot, centres, blocked) + rng.randf() * 0.1
		if score > best_score:
			best_score = score
			best = spot
	if best.x < 0:
		return {}
	var seeds: Array = [best]
	if sort == "rock":
		var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
		var dir: Vector2i = dirs[rng.randi_range(0, dirs.size() - 1)]
		for k in range(rng.randi_range(2, 4) - 1):
			var s := best + dir * (k + 1)
			if _unit_open(s, seat, ways, keep_out):
				seeds.append(s)
	var cells := {}
	var dist := {}
	var dead := {}  # popped and rejected: never re-offered
	var frontier: Array = []  # [cost, cell], lowest cost first
	var lo := Vector2i(map.sizeX, map.sizeZ)
	var hi := Vector2i.ZERO
	for s in seeds:
		dist[s] = 0.0
		frontier.append([0.0, s])
	while cells.size() < room:
		frontier.sort_custom(func(a, b): return a[0] < b[0])
		var pick = null
		while pick == null and not frontier.is_empty():
			var e: Array = frontier.pop_front()
			if not cells.has(e[1]) and not dead.has(e[1]):
				pick = e[1]
		if pick == null:
			break
		var c: Vector2i = pick
		if not _unit_open(c, seat, ways, keep_out) or not _fits_span(c, cells, lo, hi, span):
			dead[c] = true
			continue
		cells[c] = true
		lo = lo.min(c)
		hi = hi.max(c)
		for d in DIRS4:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= map.sizeX or n.y >= map.sizeZ or dist.has(n):
				continue
			dist[n] = dist[c] + 1.0 + 0.4 * _grow_noise(n)
			frontier.append([dist[n], n])
	var slim := true
	while slim:
		slim = false
		for c in cells.keys():
			var alone := true
			for d in DIRS4:
				if cells.has(c + d):
					alone = false
			if alone:
				cells.erase(c)
				slim = true
	for x in range(lo.x, hi.x + 1):
		for z in range(lo.y, hi.y + 1):
			var c := Vector2i(x, z)
			if cells.has(c):
				continue
			var hole := true
			for d in DIRS4:
				if not cells.has(c + d):
					hole = false
			if hole and _unit_open(c, seat, ways, keep_out):
				cells[c] = true
	cells = _largest_part(cells)
	var taken := blocked.duplicate()
	for c in cells:
		taken[c] = true
	if cells.size() < 2 or not _terrain_open(taken, reach):
		return {}
	return cells


## What makes a good spot (I116): room from the castles (a ringed castle needs the ground
## around it) and spread from every landed unit, both in tiles past their margins, clamped
## so far ground stops mattering.
func _seed_score(spot: Vector2i, centres: Array, blocked: Dictionary) -> float:
	var room := 1e9
	for q in centres:
		room = minf(room, max(absi(spot.x - q.x), absi(spot.y - q.y)) - TERRAIN_CASTLE_CLEAR)
	var spread := 1e9
	for c in blocked:
		spread = minf(spread, max(absi(spot.x - c.x), absi(spot.y - c.y)) - TERRAIN_GAP)
	return minf(room, 8.0) + (0.5 * minf(spread, 8.0) if spread < 1e9 else 0.0)


## A tile this unit may eat: inside its seat (a side's or quadrant's units stay its own), on
## free ground no ship sits on, off the castle clears and the reserved ways, and outside
## every other unit's gap.
func _unit_open(c: Vector2i, seat: Array, ways: Dictionary, keep_out: Dictionary) -> bool:
	if c.x < seat[0].x or c.y < seat[0].y or c.x >= seat[1].x or c.y >= seat[1].y:
		return false
	var t = map.tiles[c.x][c.y]
	if not t.is_free() or U.alive(t.ship) or keep_out.has(c) or ways.has(c):
		return false
	return true


## The unit with `c` added still fits its family's bounding box cap.
func _fits_span(c: Vector2i, cells: Dictionary, lo: Vector2i, hi: Vector2i, span: int) -> bool:
	if cells.is_empty():
		return true
	var nlo: Vector2i = lo.min(c)
	var nhi: Vector2i = hi.max(c)
	return nhi.x - nlo.x < span and nhi.y - nlo.y < span


## Deterministic growth wobble, -1 to 1, keyed on board position like the drape's roughness:
## same board, same blobs, and the layout's rng stream draws only the spot picks.
func _grow_noise(c: Vector2i) -> float:
	return fmod(absf(sin(c.x * 91.7 + c.y * 263.3)), 2.0) - 1.0


## The largest 4-connected part of a unit's cells: one mass, one unit (I116).
func _largest_part(cells: Dictionary) -> Dictionary:
	var seen := {}
	var best := {}
	for c in cells:
		if seen.has(c):
			continue
		var part := {}
		var queue := [c]
		seen[c] = true
		part[c] = true
		var head := 0
		while head < queue.size():
			var p: Vector2i = queue[head]
			head += 1
			for d in DIRS4:
				var n: Vector2i = p + d
				if cells.has(n) and not seen.has(n):
					seen[n] = true
					part[n] = true
					queue.append(n)
		if part.size() > best.size():
			best = part
	return best


## The border flood over ground no unit and no sea blocks (rivers cross): the free tiles
## that reach the board's edge.
func _terrain_reach(blocked: Dictionary) -> Dictionary:
	var seen := {}
	var queue: Array = []
	for x in map.sizeX:
		for z in [0, map.sizeZ - 1]:
			_terrain_seed(Vector2i(x, z), blocked, seen, queue)
	for z in map.sizeZ:
		for x in [0, map.sizeX - 1]:
			_terrain_seed(Vector2i(x, z), blocked, seen, queue)
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for d in DIRS4:
			var n: Vector2i = p + d
			if n.x < 0 or n.y < 0 or n.x >= map.sizeX or n.y >= map.sizeZ or seen.has(n):
				continue
			var t = map.tiles[n.x][n.y]
			if blocked.has(n) or (t.water and not t.river):
				continue
			seen[n] = true
			queue.append(n)
	return seen


func _terrain_seed(p: Vector2i, blocked: Dictionary, seen: Dictionary, queue: Array) -> void:
	if seen.has(p) or blocked.has(p):
		return
	var t = map.tiles[p.x][p.y]
	if t.water and not t.river:
		return
	seen[p] = true
	queue.append(p)


## A candidate unit keeps every free tile's border reach (I116): the flood with the unit's
## cells blocked reaches everything the empty board's flood did. The castle rings are free
## ground the castle clears already protect, so they stay reachable through it.
func _terrain_open(blocked: Dictionary, reach: Dictionary) -> bool:
	var now := _terrain_reach(blocked)
	for p in reach:
		if not blocked.has(p) and not now.has(p):
			return false
	return true


## The ground ways between castle rings, reserved against growth (I116): a BFS tree from the
## first castle's ring over ground no sea blocks (rivers cross), and for every other castle
## the tree path from its ring back to the root. What stays reserved keeps every ring
## reachable from every other by construction.
func _terrain_ways(centres: Array) -> Dictionary:
	var ways := {}
	if centres.size() < 2:
		return ways
	var parent := {}
	var depth := {}
	var queue: Array = []
	for p in _ring_cells(centres[0]):
		depth[p] = 0
		queue.append(p)
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for d in DIRS4:
			var n: Vector2i = p + d
			if n.x < 0 or n.y < 0 or n.x >= map.sizeX or n.y >= map.sizeZ or depth.has(n):
				continue
			var t = map.tiles[n.x][n.y]
			if t.water and not t.river:
				continue
			depth[n] = depth[p] + 1
			parent[n] = p
			queue.append(n)
	for i in range(1, centres.size()):
		var best := Vector2i(-1, -1)
		for p in _ring_cells(centres[i]):
			if depth.has(p) and (best.x < 0 or depth[p] < depth[best]):
				best = p
		if best.x < 0:
			continue  # the base board already cuts this ring off; no way growth can keep
		while parent.has(best) and not ways.has(best):
			ways[best] = true
			best = parent[best]
	return ways


## The build ring's tiles (Chebyshev 2) of the castle at `centre`, on the map.
func _ring_cells(centre: Vector2i) -> Array:
	var out: Array = []
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var p := Vector2i(centre.x + dx, centre.y + dz)
			if p.x >= 0 and p.y >= 0 and p.x < map.sizeX and p.y < map.sizeZ:
				out.append(p)
	return out


## A unit's column heights (I116): a hill domes - BFS depth from its rim, one level a tile
## in every direction, capped at three - so it reads as his
## 00000/01110/01210/01110/00000 hill, always overlooked from the player. A rock stands
## sheer toward the player and eases one level a tile from its far rim, its crest pulled to
## the player-facing side; the sight passes then trim whatever pooled corners still break a
## line in either direction, and `_terrain_ease` holds the east and west faces.
func _unit_heights(sort: String, cells: Dictionary) -> Dictionary:
	var out := {}
	if sort == "hill":
		var depth := {}
		var queue: Array = []
		for c in cells:
			for d in DIRS4:
				if not cells.has(c + d):
					depth[c] = 1
					queue.append(c)
					break
		var head := 0
		while head < queue.size():
			var p: Vector2i = queue[head]
			head += 1
			for d in DIRS4:
				var n: Vector2i = p + d
				if cells.has(n) and not depth.has(n):
					depth[n] = depth[p] + 1
					queue.append(n)
		for c in cells:
			out[c] = mini(3, depth.get(c, 3))
		return out
	var top := {}  # a column's far rim: where its north slope starts
	for c in cells:
		top[c.x] = maxi(top.get(c.x, c.y), c.y)
	for c in cells:
		out[c] = mini(4, 1 + top[c.x] - c.y)
	return out


## The sides' share (I116): each region's tile count stays within TERRAIN_BAND of the
## richest - roughly equal, not matched exactly. The richer region's largest unit sheds rim
## cells (one block high, a side neighbour outside) until the band holds; a cell whose loss
## would split the unit is not taken.
func _terrain_balance(units: Array) -> void:
	var four := players.size() == 4
	var half := Vector2i(map.sizeX / 2, map.sizeZ / 2)
	for _guard in 400:
		var counts := {}
		for u in units:
			for c in u[1]:
				var r := _region_of(c, half, four)
				counts[r] = counts.get(r, 0) + 1
		var regions := 4 if four else 2
		var richest := -1
		var poorest := -1
		for r in regions:
			if not counts.has(r):
				continue
			if richest < 0 or counts[r] > counts[richest]:
				richest = r
			if poorest < 0 or counts[r] < counts[poorest]:
				poorest = r
		if richest < 0 or poorest < 0:
			return
		if float(counts[poorest]) >= (1.0 - TERRAIN_BAND) * counts[richest]:
			return
		var pick = null
		for u in units:
			for c in u[1]:
				if _region_of(c, half, four) == richest:
					if pick == null or u[1].size() > pick[1].size():
						pick = u
					break
		if pick == null or pick[1].size() <= 3:
			return
		var gone = null
		for c in pick[1]:
			var rim := false
			for d in DIRS4:
				if not pick[1].has(c + d):
					rim = true
			if not rim:
				continue
			var rest: Dictionary = pick[1].duplicate()
			rest.erase(c)
			if _largest_part(rest).size() == rest.size():
				gone = c
				break
		if gone == null:
			return
		pick[1].erase(gone)


func _region_of(c: Vector2i, half: Vector2i, four: bool) -> int:
	if four:
		return (1 if c.y >= half.y else 0) * 2 + (1 if c.x >= half.x else 0)
	return 1 if c.y >= half.y else 0


## After the whole board stands, any column pooled into a broken sight line steps down, the
## one closest to the free ground first, so a deep feature keeps its crest and the front
## yields. Both directions (I116): the play camera's 60-degree line to the free ground
## south of every column (I97's rule), and its mirror north - the sheer face is the
## player's alone, the far slope keeps its one-level-a-tile ease even where corners pool
## tall.
func _terrain_sight() -> void:
	_sight_pass(false)
	_sight_pass(true)


## After the sight trims, a rock's east and west faces ease one level a tile as well: no
## cell stands more than one above its row neighbours in x, free ground at ground level,
## so the sheer face stays the player's alone (I116). Lowering never breaks a sight line.
func _terrain_ease() -> void:
	for go in map.terrain_features:
		var terr := U.comp(go, "Terrain")
		if terr.sort != "rock":
			continue
		var settling := true
		while settling:
			settling = false
			for t in terr.tiles:
				var side: int = 1 << 30
				for d in [-1, 1]:
					var nx: int = t.idxX + d
					if nx < 0 or nx >= map.sizeX:
						side = 0
					else:
						var tt = map.tiles[nx][t.idxZ]
						side = mini(side, terr.columns[tt] if tt.structure == go else 0)
				if terr.columns[t] > side + 1:
					terr.lower(t, side + 1)
					settling = true
		terr.drape()


func _sight_pass(from_high: bool) -> void:
	var rise := tan(deg_to_rad(60.0))
	var s := 1 if from_high else -1
	var near_free := []  # per x: the z of the nearest free tile on this pass's side, -1 when none
	for x in map.sizeX:
		var col: Array = []
		col.resize(map.sizeZ)
		var seen := -1
		for i in map.sizeZ:
			var z: int = map.sizeZ - 1 - i if from_high else i
			col[z] = seen
			var t = map.tiles[x][z]
			if t.structure == null and not t.water and not t.disabled:
				seen = z
		near_free.append(col)
	for go in map.terrain_features:
		var terr := U.comp(go, "Terrain")
		var changed := true
		while changed:
			changed = false
			for t in terr.tiles:
				var zf: int = near_free[t.idxX][t.idxZ]
				if zf < 0 or terr.surface_at(t.idxX, t.idxZ + 0.5 * s) - t.go.position.y <= (absi(zf - t.idxZ) - 0.5) * rise:
					continue
				var victim = null
				var best := 1 << 30
				for d in [Vector2i(-1, s), Vector2i(0, s), Vector2i(1, s), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)]:
					var c: Vector2i = Vector2i(t.idxX, t.idxZ) + d
					if c.x < 0 or c.x >= map.sizeX or c.y < 0 or c.y >= map.sizeZ:
						continue
					var tt = map.tiles[c.x][c.y]
					if tt.structure != go or terr.columns.get(tt, 0) < 2:
						continue
					var z3: int = near_free[c.x][c.y]
					var dist := 1 << 20 if z3 < 0 else absi(c.y - z3)  # deep columns yield last
					if dist < best:
						best = dist
						victim = tt
				if victim != null:
					terr.lower(victim, terr.columns[victim] - 1)
					changed = true
		terr.drape()


## The feature's GameObject at the centre of its cells: the Terrain component holding the
## standing column heights, and one merged mesh draped over them (I100) - a hill's gentle
## green blanket or a rock's craggy grey one. `heights` maps cell to column height (I116);
## a cell without one stands a single block.
func _terrain_go(sort: String, all: Array, heights := {}) -> Node3D:
	var go := Node3D.new()
	go.name = sort.capitalize()
	map.go.add_child(go)
	var terr := Node.new()
	terr.name = "Terrain"
	terr.set_script(TerrainScript)
	go.add_child(terr)
	terr.map = map
	terr.sort = sort
	terr.tiles = all.map(func(c): return map.tiles[c.x][c.y])
	terr.destructible = TerrainScript.HILL_BREAKS if sort == "hill" else TerrainScript.ROCK_BREAKS
	var centre := Vector3.ZERO
	var ground := 0.0
	for c in all:
		centre += map.tile_position(c.x, c.y)
		ground += map.tiles[c.x][c.y].go.position.y
	# the drape's feet stand on the ground it covers; the tiles under it flatten to the
	# same height (the blanket hides them), so its rim never floats over a low neighbour
	go.position = centre / all.size()
	go.position.y = ground / all.size()
	for c in all:
		map.tiles[c.x][c.y].go.position.y = go.position.y
		terr.set_column(map.tiles[c.x][c.y], heights.get(c, 1))
	terr.drape()
	return go


## After the sight pass settles the drapes, every standing terrain column sprouts
## its family's decorations on the drape's own surface, and a shot block takes them with it.
func _terrain_decorations() -> void:
	for go in map.terrain_features:
		var terr := U.comp(go, "Terrain")
		for t in terr.tiles:
			if terr.columns.get(t, 0) > 0:
				t.place_decorations(terr)


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
