extends "res://scripts/components/Component.gd"
## Port of Shooter.cs: ballistic cannon (implements IShooter).

@export var projectileSpawn: NodePath
@export var arcPrefab: PackedScene
@export var projectile: ProjectileDef
@export var barrel: NodePath
@export var cooldown: NodePath
@export var supplyNeeded := 0.0
@export var minRange := 2.0
@export var maxDesiredRange := 20.0
@export var gravity := 5.0
@export var ascendingPart := 0.6
@export var secondsBetweenShots := 1.0
@export var damage := 10.0
@export var turns := true
@export var nextBulletTime := 0.0

var player = null
var vOpt := 0.0
var angleRads := 0.0
var angleDegrees := 0.0
var flyTime := 0.0
var distance := 0.0
var stunned := false
var stunnedUntil := 0.0
var renderArc = null
var arc: Node3D
var _barrel_rot_y := 0.0
var _barrel_rot_z := 0.0


func _ready() -> void:
	nextBulletTime = U.time
	refresh()
	var b := _barrel()
	if b:
		_barrel_rot_y = b.rotation.y
		_barrel_rot_z = b.rotation.z
	sleep()


## The arc renderer is created lazily: the owning node is still busy adding
## children while _ready() runs.
func _arc():
	if renderArc == null:
		arc = U.instantiate(arcPrefab, go)
		renderArc = U.comp(arc, "RenderArc")
	return renderArc


func _barrel() -> Node3D:
	return get_node_or_null(barrel) as Node3D


func _spawn() -> Node3D:
	return get_node_or_null(projectileSpawn) as Node3D


## Recomputes derived values after the parameters changed (catalog reload).
func refresh() -> void:
	vOpt = sqrt(maxDesiredRange * gravity)


func get_supply_needed() -> float:
	return supplyNeeded


## Unity: barrel.localEulerAngles.x = deg. The x axis is mirrored in this port.
func _set_barrel_x(deg: float) -> void:
	var b := _barrel()
	if b:
		b.rotation = Vector3(deg_to_rad(-deg), _barrel_rot_y, _barrel_rot_z)


func sleep() -> void:
	if renderArc and U.alive(arc):
		renderArc.switch_on_or_off(false)
	_set_barrel_x(-10.0)


## Round 27 candidates: under the own-guns arc styles only the own player's guns draw.
func _draws_arc() -> bool:
	if Indicators.arc_style == "none":
		return false
	if Indicators.arc_style == "wire" or Indicators.own_player == null:
		return true
	return player == Indicators.own_player


func try_aim(destination: Vector3) -> bool:
	_arc().line.color = Color.GRAY if player == null else player.mainColor
	distance = go.global_position.distance_to(destination)
	var reachable := can_reach(distance)
	if reachable and not stunned:
		var angle1 := asin(clampf(distance * gravity / pow(vOpt, 2.0), -1.0, 1.0)) / 2.0
		var deg1 := rad_to_deg(angle1)
		var deg2 := 90.0 - deg1
		if deg1 >= deg2:
			angleDegrees = deg1
			angleRads = angle1
		else:
			angleDegrees = deg2
			angleRads = deg_to_rad(deg2)
		flyTime = 2.0 * vOpt * sin(angleRads) / gravity
		if turns:
			U.look_at(go, destination)
			var s := go.scale
			go.rotation = Vector3(0.0, go.rotation.y, 0.0)
			go.scale = s
		if Indicators.reload_style == "slump" and U.time < nextBulletTime:
			# the barrel rests low after a shot and rises to the firing angle as the reload completes
			var k := 1.0 - (nextBulletTime - U.time) / maxf(secondsBetweenShots, 0.0001)
			_set_barrel_x(lerpf(-10.0, angleDegrees, clampf(k, 0.0, 1.0)))
		else:
			_set_barrel_x(angleDegrees)
		if _draws_arc():
			renderArc.draw_arc(10, _spawn().global_position, destination, distance, angleRads, ascendingPart)
		else:
			renderArc.switch_on_or_off(false)
	else:
		sleep()
	return reachable


func can_reach(d: float) -> bool:
	return d >= minRange and d <= maxDesiredRange


func stun(for_seconds: float) -> void:
	stunned = true
	sleep()
	stunnedUntil = U.time + for_seconds


func _process(_delta: float) -> void:
	if stunned and U.time >= stunnedUntil:
		stunned = false


func try_shoot(destination: Vector3, destination_tile) -> bool:
	var shot := false
	if not stunned and try_aim(destination) and U.time >= nextBulletTime:
		shot = true
		if player != null:
			player.count("shots")
		nextBulletTime = U.time + secondsBetweenShots
		var cd := get_node_or_null(cooldown)
		if cd:
			cd.run(secondsBetweenShots)
		if Indicators.arc_style != "wire":  # the preview arc goes when the shell is the line
			_arc().switch_on_or_off(false)
		var rot := Basis(Vector3.UP, go.global_rotation.y)
		var shell := Catalog.spawn_projectile(projectile, U.world(), _spawn().global_position, rot)
		shell.player = player
		shell.fly_towards(destination, destination_tile, distance, vOpt, angleRads, flyTime, gravity,
				ascendingPart, damage)
	return shot
