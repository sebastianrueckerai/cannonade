extends "res://scripts/components/Component.gd"
## Port of FlyAndVanish.cs: discarded walls / buildings fly up and disappear.

var player = null
var endPosition: Vector3
var startPosition: Vector3
var flySeconds := 1.0
var startSeconds := 0.0
var fly := false
var isWall := true


func fly_away(seconds: float, p, is_wall := true) -> void:
	if fly:
		return
	isWall = is_wall
	player = p
	if isWall:
		player.nextWall = null
	else:
		player.nextBuilding = null
		player.secondsLastBuilding = U.time
	startPosition = go.global_position
	endPosition = go.global_position + go.global_transform.basis.y.normalized() * 20.0
	flySeconds = seconds
	startSeconds = U.time
	fly = true


func _process(_delta: float) -> void:
	if fly:
		var percent := (U.time - startSeconds) / flySeconds
		go.global_position = startPosition.lerp(endPosition, minf(percent, 1.0))
		if percent >= 1.0:
			fly = false
			if isWall and U.alive(player) and player.game.phase == player.game.Phase.WALLS \
					and not U.alive(player.nextWall):
				player.get_next_wall()
			U.destroy(go)
