extends "res://scripts/components/TileImpactor.gd"
## Port of S2SRocket.cs: surface to surface rocket, flies up, over and down.

@export var body: NodePath

var start: Vector3
var destination: Vector3
var point1: Vector3
var point2: Vector3
var point3: Vector3
var bodyHorizontalX := 0.0
var bodyUpX := -90.0
var bodyDownX := 90.0
var curveDist := 1.0
var segmentLength := 10.0
var expiredTime := 0.0
var percentFinished := 0.0
var flyTime := 4.0
var phase := -1


func _body() -> Node3D:
	return get_node_or_null(body) as Node3D


## Unity Euler(x, 0, 0) around the mirrored x axis
func _set_body_x(deg: float) -> void:
	var b := _body()
	if b:
		b.rotation = Vector3(deg_to_rad(-deg), 0.0, 0.0)


func fly_towards(dest: Vector3, dest_tile) -> void:
	destination = dest
	U.look_at(go, Vector3(dest.x, go.global_position.y, dest.z))
	start = go.global_position
	var start_floor := Vector3(start.x, 0.0, start.z)
	var dest_floor := Vector3(dest.x, 0.0, dest.z)
	point1 = start_floor
	point2 = start_floor.lerp(dest_floor, 0.5)
	point3 = dest_floor
	point1.y = segmentLength
	point2.y = 2.0 * segmentLength
	point3.y = segmentLength
	flyTime = maxf(go.global_position.distance_to(point1) / velocity, 0.0001)
	aim_tile(dest_tile)
	_set_body_x(bodyUpX)
	curveDist = point1.distance_to(point2)
	phase = 0


func _process(delta: float) -> void:
	if phase < 0:
		return
	expiredTime += delta
	percentFinished = expiredTime / flyTime
	if phase == 0:
		go.global_position = start.lerp(point1, minf(percentFinished * percentFinished, 1.0))
		if percentFinished >= 1.0:
			phase = 1
			expiredTime = 0.0
			flyTime = maxf(curveDist / velocity, 0.0001)
	elif phase == 1:
		var pos := point1.lerp(point2, minf(percentFinished, 1.0))
		var rising := 1.0 - (1.0 - percentFinished) * (1.0 - percentFinished)
		go.global_position = Vector3(pos.x, rising * segmentLength + segmentLength, pos.z)
		_set_body_x(lerpf(bodyUpX, bodyHorizontalX, minf(percentFinished, 1.0)))
		if percentFinished >= 1.0:
			phase = 2
			expiredTime = 0.0
	elif phase == 2:
		var pos := point2.lerp(point3, minf(percentFinished, 1.0))
		var falling := 1.0 - percentFinished * percentFinished
		go.global_position = Vector3(pos.x, falling * segmentLength + segmentLength, pos.z)
		_set_body_x(lerpf(bodyHorizontalX, bodyDownX, minf(percentFinished, 1.0)))
		if percentFinished >= 1.0:
			phase = 3
			expiredTime = 0.0
			flyTime = maxf(segmentLength / velocity, 0.0001)
	elif phase == 3:
		go.global_position = point3.lerp(destination, minf(percentFinished, 1.0))
		if percentFinished >= 1.0:
			phase = -1
			if U.alive(destinationTile):
				count_hit()
				destinationTile.damage_building_place(damage)
				if tileDestroyer:
					disable_tile(destinationTile)
			U.destroy(go)
