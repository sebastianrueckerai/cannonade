extends "res://scripts/components/Component.gd"
## Port of GameController.cs: rounds alternate between building and shooting.

@export var roundDuration := 10.0
@export var roundsPerGame := 6
@export var randomSeed := 41
@export var useRandomSeed := false
@export var initialShips := 7

var wallSpawns: Array = []
var buildingSpawns: Array = []
var supplyBars: Array = []
var supplyNeededBars: Array = []
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
## false: no start bases (the sandbox places its own)
var startBases := true

signal round_changed(round_number: int, building: bool)


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
		p.inBuildRange = PackedByteArray()
		p.inBuildRange.resize(map.sizeX * map.sizeZ)
		p.supplyBar = supplyBars[i] if i < supplyBars.size() else null
		p.supplyNeededBar = supplyNeededBars[i] if i < supplyNeededBars.size() else null
		p.setup()
	if startBases:
		_set_player_start_bases()


func _set_player_start_bases() -> void:
	var n := players.size()
	var t: Array = map.tiles
	if n == 1:
		players[0].build_start_base(t[map.sizeX / 2][map.sizeZ / 2])
	elif n == 2:
		if map.sizeX < 12 or map.sizeZ < 12:
			push_error("Map too small for %d players!" % n)
			return
		var x: int = map.sizeX / 2
		var dz: int = map.sizeZ / 4
		players[0].build_start_base(t[x][dz])
		players[1].build_start_base(t[x][map.sizeZ - dz])
	else:
		if map.sizeX < 12 or map.sizeZ < 12:
			push_error("Map too small for %d players!" % n)
			return
		var dx: int = map.sizeX / 4
		var dz: int = map.sizeZ / 4
		players[0].build_start_base(t[dx][dz])
		players[1].build_start_base(t[dx][map.sizeZ - dz])
		players[2].build_start_base(t[map.sizeX - dx][dz])
		if n == 4:
			players[3].build_start_base(t[map.sizeX - dx][map.sizeZ - dz])


func _update_round_time(delta: float) -> void:
	timeLeftInRound -= delta
	if timeLeftInRound < -1:
		next_phase()
	if roundTimer:
		roundTimer.modulate = Color.RED if shootingAllowed else Color.GREEN
		roundTimer.text = "%d" % int(ceilf(timeLeftInRound))


## Ends the current phase: build turns into battle and back.
func next_phase() -> void:
	roundNumber += 1
	timeLeftInRound = roundDuration
	buildingAllowed = not buildingAllowed
	shootingAllowed = not shootingAllowed
	round_changed.emit(roundNumber, buildingAllowed)


func _process(delta: float) -> void:
	if not started:
		return
	_update_round_time(delta)
	for p in players:
		p.manage_supply_and_active_buildings()
		p.try_get_next_building()
		p.update_point_and_tile_selected()
		p.manage_player_actions()
