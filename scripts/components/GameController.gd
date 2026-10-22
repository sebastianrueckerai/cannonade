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


# ------------------------------------------------------------- terrain (I90, I91, I93, I95, I96, I97)
## The shapes a feature can take, rows from its north-west cell ("up" the map is low z):
## "#" a blocked cell. Solid masses with bitten, irregular outlines (I97) - no rings or
## discs, no plain rectangles; the first seven sit inside 4x4, the rest reach 7x7. Features
## that cluster can still enclose free ground between them, which the placement rolls back.
const TERRAIN_PATTERNS := [
	"####/####/##../##..",
	"####/.##./####",
	"#.../####/...#/...#",
	"##../##../.#..",
	"#../###/..#",
	"##./##./.##",
	"##/##",
	"..##../.####./######/#####./.###../..#...",
	"..####./.#####./#######/#####../###..../#......",
	"####../#####./.####./.#####/..####",
	"##...../##...../##...../##...../##...../#######/#######",
	"###.###/###.###/#######/###.###",
	"#######/#######/..###../..###../..###..",
]
## Shapes the game draws, stone and crates alternating by shape: one seat a side with two
## players, one a quadrant with four, the same shape at every seat so the sides hold the
## same amount of blocked tiles (I96). --terrain=N overrides.
const TERRAIN_DEFAULT := 6
@export var terrainCount := TERRAIN_DEFAULT
## Spots tried per feature before this map goes without it.
const TERRAIN_ATTEMPTS := 60
## A feature joins an earlier one instead of scattering this often, so masses stand in
## clusters rather than spreading evenly (I95). Overlaps fail _terrain_fits; touching stands.
const TERRAIN_CLUSTER := 0.5
## Terrain keeps this Chebyshev distance from a castle centre, so its 5x5 ring stays buildable.
const TERRAIN_CASTLE_CLEAR := 3
## The tallest box one level may stand: half a tile's climb at the shallowest play camera
## (60 degrees, versus), the height from which a block starts hiding the tile behind it.
const TERRAIN_LEVEL_MAX := 0.866


## Terrain features over the battlefield (I90, I91, I93, I96): each drawn shape takes one
## seat a side, its own anchor and rotation, so the sides hold the same amount of blocked
## tiles in different arrangements - no mirrored board. A seat is anywhere on the
## battlefield, across the midline too: with two players the shape's second seat must split
## its tiles above and below the line the opposite of the first's, which keeps the sides
## level; with four the shape lands once in each quadrant and stays off the quadrant lines.
## A feature never touches a castle's build ring, water or another structure, and a
## placement that would cut the last way between castle rings is rolled back.
func _place_terrain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = mapSeed if mapSeed != 0 else randomSeed
	var shapes: Array = []
	for pat in TERRAIN_PATTERNS:
		var cells: Array = []
		var z := 0
		for row: String in pat.split("/"):
			for x in row.length():
				if row[x] == "#":
					cells.append(Vector2i(x, z))
			z += 1
		shapes.append(cells)
	var half := Vector2i(map.sizeX / 2, map.sizeZ / 2)
	var seats: Array = [[Vector2i.ZERO, Vector2i(map.sizeX, map.sizeZ)], null] if players.size() != 4 else [
			[Vector2i.ZERO, half], [Vector2i(half.x, 0), Vector2i(map.sizeX, half.y)],
			[Vector2i(0, half.y), Vector2i(half.x, map.sizeZ)], [half, Vector2i(map.sizeX, map.sizeZ)]]
	var clusters: Array = []
	for i in terrainCount:
		var shape: Array = _terrain_rotated(shapes[rng.randi_range(0, shapes.size() - 1)], rng.randi_range(0, 3))
		var open_set := _border_reach()
		var size := Vector2i.ONE
		for c in shape:
			size.x = maxi(size.x, c.x + 1)
			size.y = maxi(size.y, c.y + 1)
		var sort := "stone" if i % 2 == 0 else "crate"  # alternating, so a board always holds both sorts
		for attempt in TERRAIN_ATTEMPTS:
			var landed: Array = []
			for seat in seats:
				var cells: Array = []
				if seat == null:
					cells = _terrain_partner(rng, shape, landed[0][1], clusters)
				else:
					var anchor := _terrain_anchor(rng, size, seat[0], seat[1], clusters)
					if anchor.x < 0:
						break
					for c in shape:
						cells.append(anchor + c)
					if not _terrain_fits(cells):
						break
				if cells.is_empty():
					break
				var go := _terrain_go(sort, cells, rng)
				map.claim_terrain(go, cells)
				landed.append([go, cells])
				if not _rings_connected():
					break
			if landed.size() == seats.size() and _ground_open(open_set):
				for l in landed:
					clusters.append(l[1])
				break
			for l in landed:
				map.release_terrain(l[0], l[1])


## A random anchor for the shape inside the box [lo, hi), flush against an earlier
## feature's bounding box TERRAIN_CLUSTER of the time (I95); (-1, -1) when it cannot fit.
func _terrain_anchor(rng: RandomNumberGenerator, size: Vector2i, lo: Vector2i, hi: Vector2i, clusters: Array) -> Vector2i:
	if hi.x - lo.x < size.x or hi.y - lo.y < size.y:
		return Vector2i(-1, -1)
	var anchor := Vector2i(rng.randi_range(lo.x, hi.x - size.x), rng.randi_range(lo.y, hi.y - size.y))
	if rng.randf() < TERRAIN_CLUSTER and not clusters.is_empty():
		var near: Array = clusters[rng.randi_range(0, clusters.size() - 1)]
		var nlo: Vector2i = near[0]
		var nhi: Vector2i = near[0]
		for c in near:
			nlo = Vector2i(mini(nlo.x, c.x), mini(nlo.y, c.y))
			nhi = Vector2i(maxi(nhi.x, c.x), maxi(nhi.y, c.y))
		match rng.randi_range(0, 3):  # flush against a side of the placed feature's bounding box
			0: anchor = Vector2i(nhi.x + 1, rng.randi_range(nlo.y - size.y + 1, nhi.y))
			1: anchor = Vector2i(nlo.x - size.x, rng.randi_range(nlo.y - size.y + 1, nhi.y))
			2: anchor = Vector2i(rng.randi_range(nlo.x - size.x + 1, nhi.x), nhi.y + 1)
			_: anchor = Vector2i(rng.randi_range(nlo.x - size.x + 1, nhi.x), nlo.y - size.y)
		anchor = anchor.clamp(lo, hi - size)
	return anchor


## The shape's other seat, anywhere its tiles above the midline number what the first
## placed below it, so both sides keep the same amount of blocked tiles (I96). Seats flush
## against a placed feature come first TERRAIN_CLUSTER of the time.
func _terrain_partner(rng: RandomNumberGenerator, shape: Array, first: Array, clusters: Array) -> Array:
	var mid: int = map.sizeZ / 2
	var below := 0
	for c: Vector2i in first:
		if c.y >= mid:
			below += 1
	var cands: Array = []
	for rot in 4:
		var pat: Array = _terrain_rotated(shape, rot)
		var size := Vector2i.ONE
		var rows := {}
		for c: Vector2i in pat:
			size.x = maxi(size.x, c.x + 1)
			size.y = maxi(size.y, c.y + 1)
			rows[c.y] = rows.get(c.y, 0) + 1
		for az in range(map.sizeZ - size.y + 1):
			var above := 0
			for r in rows:
				if az + r < mid:
					above += rows[r]
			if above != below:
				continue
			for ax in range(map.sizeX - size.x + 1):
				cands.append([Vector2i(ax, az), pat, size])
	while cands.size() > 120:  # a bounded draw keeps the rng stream short
		cands.remove_at(rng.randi_range(0, cands.size() - 1))
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = cands[i]
		cands[i] = cands[j]
		cands[j] = t
	if rng.randf() < TERRAIN_CLUSTER and not clusters.is_empty():
		var pri: Array = []
		var sec: Array = []
		for cand in cands:
			if _terrain_flush(cand[0], cand[2], clusters):
				pri.append(cand)
			else:
				sec.append(cand)
		cands = pri + sec
	for cand in cands:
		var cells: Array = []
		for c: Vector2i in cand[1]:
			cells.append(cand[0] + c)
		if _terrain_fits(cells):
			return cells
	return []


## True when the shape's box at anchor stands flush against a placed feature's box.
func _terrain_flush(anchor: Vector2i, size: Vector2i, clusters: Array) -> bool:
	var hi := anchor + size - Vector2i.ONE
	for near: Array in clusters:
		var nlo: Vector2i = near[0]
		var nhi: Vector2i = near[0]
		for c in near:
			nlo = Vector2i(mini(nlo.x, c.x), mini(nlo.y, c.y))
			nhi = Vector2i(maxi(nhi.x, c.x), maxi(nhi.y, c.y))
		if anchor.x <= nhi.x + 1 and hi.x + 1 >= nlo.x and anchor.y <= nhi.y + 1 and hi.y + 1 >= nlo.y:
			return true
	return false


## The shape turned a quarter turn, this many times.
func _terrain_rotated(cells: Array, turns: int) -> Array:
	var out: Array = cells.duplicate()
	for t in turns:
		var size := Vector2i.ONE
		for c in out:
			size.x = maxi(size.x, c.x + 1)
			size.y = maxi(size.y, c.y + 1)
		var nxt: Array = []
		for c in out:
			nxt.append(Vector2i(size.y - 1 - c.y, c.x))
		out = nxt
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


## Column heights for a feature's cells (I97): one box a level, up to three. A level stacks
## only where the feature itself, another feature or the board's north edge backs it: the
## play camera (60 degrees up) sees over one level, but a two-level column hides the centre
## of the tile directly behind it, so that tile must be terrain too. Profiles: flat,
## terraces rising away from the camera, a peak with its shoulder.
func _terrain_heights(rng: RandomNumberGenerator, all: Array) -> Dictionary:
	var own := {}
	var near := 0
	var mid := Vector2i.ZERO
	for c: Vector2i in all:
		own[c] = true
		near = maxi(near, c.y)
		mid += c
	mid /= all.size()
	var peak: Vector2i = all[0]
	for c: Vector2i in all:
		if max(absi(c.x - mid.x), absi(c.y - mid.y)) < max(absi(peak.x - mid.x), absi(peak.y - mid.y)):
			peak = c
	var kind := rng.randi_range(0, 2)
	var out := {}
	for c: Vector2i in all:
		var h := 1
		if kind == 1:
			h = 1 + mini(2, near - c.y)
		elif kind == 2:
			h = maxi(1, 3 - max(absi(c.x - peak.x), absi(c.y - peak.y)))
		var behind := Vector2i(c.x, c.y - 1)
		var backed: bool = c.y == 0 or own.has(behind)
		if not backed:
			var t = map.tiles[behind.x][behind.y]
			backed = U.alive(t.structure) and U.comp(t.structure, "Terrain") != null
		out[c] = mini(3, h) if backed else 1
	return out


## The feature's GameObject at the centre of its cells: the Terrain component and, per
## tile, a column of level boxes of the sort's family (I93, I97) — a look each, so a mass
## reads as piled steps. `rng` draws the column profile; without it every column is flat.
func _terrain_go(sort: String, all: Array, rng: RandomNumberGenerator = null) -> Node3D:
	var heights := _terrain_heights(rng, all) if rng != null else {}
	var go := Node3D.new()
	go.name = sort.capitalize()
	map.go.add_child(go)
	var terr := Node.new()
	terr.name = "Terrain"
	terr.set_script(TerrainScript)
	go.add_child(terr)
	terr.map = map
	terr.tiles = all.map(func(c): return map.tiles[c.x][c.y])
	terr.destructible = sort == "crate"
	var centre := Vector3.ZERO
	for c in all:
		centre += map.tile_position(c.x, c.y)
	go.position = centre / all.size()
	for c in all:
		var t = map.tiles[c.x][c.y]
		var col: Array = []
		var top: float = t.go.position.y
		for i in heights.get(c, 1):
			var b: Node3D = null
			for draw in 8:  # a look this tall is not a level (I97); redraw for a fitting one
				var cand := Art.instance("terrain_stone" if sort == "stone" else "terrain_crate")
				if cand == null or Art.bounds(cand).size.y <= TERRAIN_LEVEL_MAX:
					b = cand
					break
				U.destroy(cand)
			if b == null:
				break
			go.add_child(b)
			b.position = map.tile_position(c.x, c.y) - go.position
			b.position.y = top - 0.01  # each box sinks into the one below, as the art kit unions
			top += Art.bounds(b).size.y
			col.append(b)
		terr.set_column(t, col)
	return go


## The free, dry tiles that reach the board's border over ground no terrain and no water
## blocks (I97): a pair may not strand free ground behind it.
func _border_reach() -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(map.sizeX * map.sizeZ)
	var queue: Array[Vector2i] = []
	for x in map.sizeX:
		for z in [0, map.sizeZ - 1]:
			_reach_seed(Vector2i(x, z), seen, queue)
	for z in map.sizeZ:
		for x in [0, map.sizeX - 1]:
			_reach_seed(Vector2i(x, z), seen, queue)
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + v
			if n.x < 0 or n.y < 0 or n.x >= map.sizeX or n.y >= map.sizeZ or seen[n.x * map.sizeZ + n.y]:
				continue
			var t = map.tiles[n.x][n.y]
			if t.water or (U.alive(t.structure) and U.comp(t.structure, "Terrain") != null):
				continue
			seen[n.x * map.sizeZ + n.y] = 1
			queue.append(n)
	return seen


func _reach_seed(p: Vector2i, seen: PackedByteArray, queue: Array[Vector2i]) -> void:
	var t = map.tiles[p.x][p.y]
	if t.water or (U.alive(t.structure) and U.comp(t.structure, "Terrain") != null):
		return
	seen[p.x * map.sizeZ + p.y] = 1
	queue.append(p)


## True when no free tile the board reached before this pair lost that reach (I97).
func _ground_open(before: PackedByteArray) -> bool:
	var now := _border_reach()
	for x in map.sizeX:
		for z in map.sizeZ:
			if before[x * map.sizeZ + z] and not now[x * map.sizeZ + z]:
				var t = map.tiles[x][z]
				if t.structure == null and not t.water and not t.disabled:
					return false
	return true


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
