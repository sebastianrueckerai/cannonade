extends "res://scripts/components/Component.gd"
## Port of Flak.cs: shoots down enemy projectiles in range (ISupportBuilding).

@export var supplyNeeded := 4.0
@export var guns: NodePath
@export var shootRange := 4.0
@export var lookRange := 10.0
@export var secondsBtwSalvos := 1.0
@export var maxTargetVelocity := 150.0

var player = null
var target = null
var secondsLastShot := 0.0
var on := true
var _recoil := 0.0


func _ready() -> void:
	var bb := U.comp(go, "BuildingBlock")
	if bb:
		player = bb.player


func get_supply_needed() -> float:
	return supplyNeeded


func switch_on_off(value := true) -> void:
	on = value


func _guns() -> Node3D:
	return get_node_or_null(guns) as Node3D


func _process(delta: float) -> void:
	if player == null:
		var bb := U.comp(go, "BuildingBlock")
		if bb:
			player = bb.player
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 4.0)
		var g := _guns()
		if g:
			g.scale = Vector3.ONE * 0.7 * (1.0 - 0.15 * sin(_recoil * PI))
	if not on:
		return
	if U.alive(target) and target.go.global_position.distance_to(go.global_position) > lookRange:
		target = null
	if not U.alive(target):
		target = _search(lookRange)
	elif _guns():
		U.look_at(_guns(), target.go.global_position)
	if U.time >= secondsBtwSalvos + secondsLastShot:
		var p = _search(shootRange)
		if p != null:
			_fire_at(p)


## Physics.OverlapBox(center=(x, 2, z), halfExtents=range) on the projectile layer.
func _search(r: float):
	var c := Vector3(go.global_position.x, 2.0, go.global_position.z)
	for p in U.projectiles:
		if not U.alive(p) or p.player == player:
			continue
		var d: Vector3 = (p.go.global_position - c).abs()
		if d.x <= r and d.y <= r and d.z <= r:
			return p
	return null


func _fire_at(projectile) -> void:
	if _guns():
		U.look_at(_guns(), projectile.go.global_position)
	_recoil = 1.0  # replaces the "fireFlak" animation
	projectile.shoot_down()
	secondsLastShot = U.time
	target = null
