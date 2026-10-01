extends "res://scripts/components/Component.gd"
## Port of Ship.cs: enemy ship sailing on water tiles and shooting at walls.
## The MEC coroutines (_Pause, _Travel, _TurnTowards) are a small state machine.

@export var cannon: NodePath
@export var health := 10.0
@export var fireProbability := 0.6
@export var waitProbability := 0.1
@export var reloadSeconds := 1.5
@export var lastShotTime := 0.0
@export var secondsToTurn180 := 1.5
@export var travelTimePerTile := 2.5
@export var minPause := 0.5
@export var maxPause := 2.0

var currentTile = null
var targetTile = null
var fleet = null
var map = null
var canAcceptOrders := false

enum State { IDLE, PAUSE, TURN, TRAVEL }
var _state := State.IDLE
var _until := 0.0
var _turn_start := 0.0
var _turn_time := 0.0
var _q0: Quaternion
var _q1: Quaternion
var _travel_start: Vector3
var _travel_target = null
var _halfway_done := false
var _time_start := 0.0


func shooter():
	return get_node(cannon)


func _ready() -> void:
	# the ship's gun is the catalog building "ship_cannon"
	var gun := go.get_node_or_null("Cannon") as Node3D
	var def := Catalog.get_def("ship_cannon")
	if gun != null and def != null:
		Catalog.configure(gun, def)


func set_sail(f, m, start_tile) -> void:
	fleet = f
	map = m
	currentTile = start_tile
	currentTile.ship = self
	_pause(U.rfloat(minPause, maxPause))


func _process(_delta: float) -> void:
	match _state:
		State.PAUSE:
			if U.time >= _until:
				_state = State.IDLE
				canAcceptOrders = true
		State.TURN:
			var pf := (U.time - _turn_start) / _turn_time if _turn_time > 0 else 1.0
			_set_rotation(_q0.slerp(_q1, clampf(pf, 0.0, 1.0)))
			if pf >= 1.0:
				_begin_travel()
		State.TRAVEL:
			_travel_step()
	if canAcceptOrders:
		_next_move()


func _set_rotation(q: Quaternion) -> void:
	var s := go.scale
	go.global_transform.basis = Basis(q).scaled(s)


func _try_shoot(target) -> bool:
	var c = shooter()
	if target != null and c.try_aim(target.go.global_position):
		return c.try_shoot(target.go.global_position, target)
	return false


func _next_move() -> void:
	if U.value() < fireProbability and U.time > shooter().nextBulletTime:
		if _try_shoot(_get_next_shooting_target()):
			_pause(U.rfloat(minPause, maxPause))
	else:
		if U.value() * (1.0 - fireProbability) < waitProbability:
			_pause(U.rfloat(minPause, maxPause))
		else:
			targetTile = _get_next_travel_target()
			if targetTile != null:
				_travel(targetTile)


func _pause(seconds: float) -> void:
	canAcceptOrders = false
	_state = State.PAUSE
	_until = U.time + seconds


func _get_next_shooting_target():
	if fleet.enemyPlayers.is_empty():
		return null
	var enemy = fleet.enemyPlayers[U.rint(0, fleet.enemyPlayers.size())]
	if enemy.wallTiles.size() > 0:
		return enemy.wallTiles[U.rint(0, enemy.wallTiles.size())]
	return null


func _get_next_travel_target():
	var t: Array = map.tiles
	var cx: int = currentTile.idxX
	var cz: int = currentTile.idxZ
	var possible: Array = []
	if cx < map.sizeX - 1:
		possible.append(t[cx + 1][cz])
	if cx > 0:
		possible.append(t[cx - 1][cz])
	if cz < map.sizeZ - 1:
		possible.append(t[cx][cz + 1])
	if cz > 0:
		possible.append(t[cx][cz - 1])
	if possible.is_empty():
		return null
	for i in fleet.game.random_shuffle_index(possible.size()):
		var p = possible[i]
		if p.water and not U.alive(p.ship) and not U.alive(p.commingShip):
			return p
	return null


func _travel(target) -> void:
	canAcceptOrders = false
	targetTile = target
	targetTile.commingShip = self
	_travel_target = target
	# turn towards the target first
	var to: Vector3 = target.go.global_position
	var dir := Vector3(to.x, go.global_position.y, to.z) - go.global_position
	_q0 = go.global_transform.basis.get_rotation_quaternion()
	_q1 = U.look_basis(dir).get_rotation_quaternion()
	_turn_time = rad_to_deg(_q0.angle_to(_q1)) / 180.0 * secondsToTurn180
	_turn_start = U.time
	_state = State.TURN


func _begin_travel() -> void:
	_state = State.TRAVEL
	_travel_start = go.global_position
	_halfway_done = false
	_time_start = U.time


func _travel_step() -> void:
	if U.time >= _time_start + travelTimePerTile:
		_finish_halfway()
		_state = State.IDLE
		canAcceptOrders = true
		return
	var pf := (U.time - _time_start) / travelTimePerTile
	var dest: Vector3 = _travel_target.go.global_position
	go.global_position = _travel_start.lerp(Vector3(dest.x, _travel_start.y, dest.z), pf)
	if pf >= 0.5:
		_finish_halfway()


func _finish_halfway() -> void:
	if _halfway_done:
		return
	_halfway_done = true
	currentTile.ship = null
	targetTile.commingShip = null
	currentTile = targetTile
	currentTile.ship = self
	targetTile = null


func damage(amount: float) -> void:
	if amount >= health:
		_sink()
	else:
		health -= amount


func _sink() -> void:
	if targetTile != null:
		targetTile.commingShip = null
	if currentTile != null and currentTile.ship == self:
		currentTile.ship = null
	fleet.ships.erase(self)
	U.destroy(go)
