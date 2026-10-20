extends "res://scripts/components/Component.gd"
## Port of GameController.cs: rounds alternate between building and shooting.

@export var roundDuration := 10.0
@export var battleDuration := 10.0
@export var roundsPerGame := 6
@export var randomSeed := 41
@export var useRandomSeed := false
@export var initialShips := 7

var wallSpawns: Array = []
var buildingSpawns: Array = []
## HUD labels per player: [parts, castles]
var partsLabels: Array = []
var castlesLabels: Array = []
var roundTimer: Label = null
var shootingAllowed := false
var buildingAllowed := false
## PlayerController / AI components
var players: Array = []
var map = null
var fleet = null
var timeLeftInRound := 0.0
var roundNumber := 0
var started := false
## false: no castles on the map (the sandbox places its own)
var castles := true

signal round_changed(round_number: int, building: bool)
## rules v3 end: the winning player, or null on a draw
signal game_over(winner)


func start_game() -> void:
	if useRandomSeed:
		seed(randomSeed)
	buildingAllowed = true
	shootingAllowed = not buildingAllowed
	timeLeftInRound = roundDuration
	map.game = self
	await map.make_map(players)
	fleet.game = self
	fleet.initilize_spawns()
	fleet.spawn_ships(initialShips)
	_initialize_players()
	for p in players:
		p.get_next_wall()
		p.next_wall_to_gui()
	position_camera()
	started = true


func position_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var fov := cam.fov
	var fov_half := fov / 2.0
	var view_plane: float = map.sizeX * 1.1
	var forward := -cam.global_transform.basis.z
	var cam_angle := 90.0 - rad_to_deg(forward.angle_to(Vector3.FORWARD))
	var projection_plane := view_plane * cos(deg_to_rad(fov))
	var projection_side := view_plane / sin(deg_to_rad(fov))
	var cam_height := projection_side * cos(deg_to_rad(cam_angle + fov_half))
	var offset := cam_height * tan(deg_to_rad(cam_angle - fov_half))
	var far_part := (projection_plane / 2.0) / cos(deg_to_rad(fov))
	var near_part := view_plane - far_part
	cam.global_position = Vector3(0.0, cam_height, offset + near_part)


func random_shuffle_index(length: int) -> Array:
	return U.shuffle_index(length)


func _initialize_players() -> void:
	for i in players.size():
		var p = players[i]
		p.playerID = i + 1
		p.game = self
		p.map = map
		p.wallSpawn = wallSpawns[i] if i < wallSpawns.size() else null
		p.buildingSpawn = buildingSpawns[i] if i < buildingSpawns.size() else null
		p.partsLabel = partsLabels[i] if i < partsLabels.size() else null
		p.castlesLabel = castlesLabels[i] if i < castlesLabels.size() else null
		p.setup()
	if castles:
		_place_castles()
		for p in players:
			p.recompute_parts_cap()


## Free rows between any castle and the map edge: room to wall it in.
const CASTLE_MARGIN := 3
## Where the four neutral castles of a side try to sit on the 34-tile map, before jitter.
const CASTLE_ANCHORS: Array[Vector2i] = [Vector2i(8, 13), Vector2i(25, 13), Vector2i(6, 6), Vector2i(27, 6)]


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
	for anchor in CASTLE_ANCHORS:
		var c := _neutral_castle_spot(anchor, placed)
		map.place_neutral(castle, c.x - 1, c.y - 1)
		var m := Vector2i(c.x, map.sizeZ - 1 - c.y)
		map.place_neutral(castle, m.x - 1, m.y - 1)
		placed.append(c)
		placed.append(m)


## A jittered castle centre: up to 2 tiles off the anchor from the game's
## random numbers, inside the bottom half and off the margin, at Chebyshev
## distance at least 5 from every castle already placed. The exact mirror has
## to keep its distance too. Falls back to the anchor itself.
func _neutral_castle_spot(anchor: Vector2i, placed: Array) -> Vector2i:
	var lo := CASTLE_MARGIN + 1  # the centre of a 3x3 whose edge sits on the margin
	var max_z: int = map.sizeZ / 2 - 3  # keeps the exact mirror 5 tiles away too
	for i in 25:
		var c := anchor + Vector2i(U.rint(-2, 3), U.rint(-2, 3))
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
	if roundTimer:
		roundTimer.modulate = Color.RED if shootingAllowed else Color.GREEN
		roundTimer.text = "%d" % int(ceilf(timeLeftInRound))


## Ends the current phase: build turns into battle (through the rules check)
## and back. The hand follows the phase: held pieces fly away when the battle
## starts, a fresh wall is drawn when building returns.
func next_phase() -> void:
	roundNumber += 1
	buildingAllowed = not buildingAllowed
	shootingAllowed = not buildingAllowed
	timeLeftInRound = roundDuration if buildingAllowed else battleDuration
	if not buildingAllowed and castles and started:
		run_check()
	for p in players:
		if buildingAllowed:
			p.get_next_wall()
		else:
			p.drop(p.nextWall, true)
			p.drop(p.nextBuilding, false)
	round_changed.emit(roundNumber, buildingAllowed)


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
	var holders: Array = []
	for p in players:
		if p.castle_count() > 0:
			holders.append(p)
	if players.size() > 1 and holders.size() < 2:
		started = false
		game_over.emit(holders[0] if holders.size() == 1 else null)


func _process(delta: float) -> void:
	if not started:
		return
	_update_round_time(delta)
	for p in players:
		p.refresh_active_cannons()
		p.try_get_next_building()
		p.update_point_and_tile_selected()
		p.manage_player_actions()
