extends "res://scripts/components/TileImpactor.gd"
## Port of Projectile.cs: ballistic cannon ball.

@export var body: NodePath
@export var rotates := true
@export var ascendingPartPercent := 0.0

var percentFinished := 0.0
var gravity := 0.0
var distanceXZ := 0.0
var flyTime := 1.0
var expiredTime := 0.0
var angleRads := 0.0
var angleDegrees := 0.0
var maxY := 0.0
var destination: Vector3
var started := false


func fly_towards(dest: Vector3, dest_tile, distance_xz: float, v: float, angle: float, fly_time: float,
		g: float, ascending_part: float, dmg: float) -> void:
	start = go.global_position
	expiredTime = 0.0
	destination = dest
	aim_tile(dest_tile)
	distanceXZ = maxf(distance_xz, 0.0001)
	velocity = v
	angleRads = angle
	flyTime = maxf(fly_time, 0.0001)
	gravity = g
	angleDegrees = rad_to_deg(angle)
	ascendingPartPercent = ascending_part
	damage = dmg
	maxY = distanceXZ * tan(angleRads) / 4.0
	started = true


func fly(delta: float) -> void:
	expiredTime += delta
	percentFinished = expiredTime / flyTime
	var q_valley: float
	var q_bounce: float
	var angle_sign: float
	if percentFinished < ascendingPartPercent:
		q_valley = pow(percentFinished / ascendingPartPercent - 1.0, 2.0)
		q_bounce = 1.0 - pow(percentFinished / ascendingPartPercent, 2.0)
		angle_sign = 1.0
	else:
		q_valley = pow((percentFinished - ascendingPartPercent) / (1.0 - ascendingPartPercent), 2.0)
		q_bounce = 1.0 - pow(1.0 - (percentFinished - ascendingPartPercent) / (1.0 - ascendingPartPercent), 2.0)
		angle_sign = -1.0
	var rotation_deg := pow(1.0 - percentFinished, 3.0) * velocity * 360.0 if rotates else 0.0
	var slope_deg := angle_sign * angleDegrees * q_bounce
	var b := get_node_or_null(body) as Node3D
	if b != null:
		# Unity localEulerAngles (-slope, 0, rot); x is mirrored in this port
		b.rotation = Vector3(deg_to_rad(slope_deg), 0.0, deg_to_rad(rotation_deg))
	var x := percentFinished * distanceXZ
	var y := (1.0 - q_valley) * maxY + start.y
	var p := start.lerp(destination, x / distanceXZ)
	p.y = y
	go.global_position = p


func fly_and_check_progress(delta: float) -> void:
	fly(delta)
	if expiredTime >= flyTime:
		impact()


func _process(delta: float) -> void:
	if started:
		fly_and_check_progress(delta)
