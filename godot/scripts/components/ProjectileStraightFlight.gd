extends "res://scripts/components/TileImpactor.gd"
## Port of ProjectileStraightFlight.cs: cluster sub munition flying straight to a tile.

var expiredTime := 0.0
var flyTime := 1.0
var percentFinished := 0.0
var started := false
var start: Vector3


func fly_towards(dest_tile, dmg: float) -> void:
	expiredTime = 0.0
	damage = dmg
	start = go.global_position
	destinationTile = dest_tile
	var distance := start.distance_to(dest_tile.go.global_position)
	flyTime = maxf(distance / maxf(velocity, 0.001), 0.0001)
	U.look_at(go, dest_tile.go.global_position)
	started = true


func _process(delta: float) -> void:
	if started:
		if not U.alive(destinationTile):
			U.destroy(go)
			return
		expiredTime += delta
		percentFinished = expiredTime / flyTime
		go.global_position = start.lerp(destinationTile.go.global_position, minf(percentFinished, 1.0))
		if expiredTime >= flyTime:
			started = false
			impact()
