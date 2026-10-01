extends "res://scripts/components/Component.gd"
## Port of RocketLauncher.cs (implements IShooter).

@export var projectile: ProjectileDef
@export var destroyOnFirstShot: NodePath
@export var rocketSpawn: NodePath
@export var damage := 0.0
@export var minRange := 2.0
@export var maxDesiredRange := 30.0
@export var secondsBetweenShots := 3.0
## seconds after placing until the first rocket is ready
@export var initialDelay := 3.0
@export var supplyNeeded := 9.0

var nextBulletTime := 0.0

var player = null
var stunned := false
var stunnedUntil := 0.0


func _ready() -> void:
	nextBulletTime = U.time + initialDelay


func sleep() -> void:
	pass


func get_supply_needed() -> float:
	return supplyNeeded


func stun(for_seconds: float) -> void:
	stunned = true
	sleep()
	stunnedUntil = U.time + for_seconds


func _process(_delta: float) -> void:
	if stunned and U.time >= stunnedUntil:
		stunned = false


func try_aim(destination: Vector3) -> bool:
	return can_reach(go.global_position.distance_to(destination))


func can_reach(d: float) -> bool:
	return d >= minRange and d <= maxDesiredRange


func try_shoot(destination: Vector3, destination_tile) -> bool:
	var shot := false
	if not stunned and try_aim(destination) and U.time >= nextBulletTime:
		shot = true
		nextBulletTime = U.time + secondsBetweenShots
		var cd := go.get_node_or_null("Progress Bar")
		if cd:
			cd.run(secondsBetweenShots)
		var once := get_node_or_null(destroyOnFirstShot)
		if once != null:
			U.destroy(once)
			destroyOnFirstShot = NodePath()
		var spawn := get_node(rocketSpawn) as Node3D
		var rocket := Catalog.spawn_projectile(projectile, U.world(), spawn.global_position, spawn.global_transform.basis.orthonormalized())
		rocket.player = player
		rocket.damage = damage
		rocket.fly_towards(destination, destination_tile)
	return shot
