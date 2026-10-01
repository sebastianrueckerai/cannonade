extends "res://scripts/components/Projectile.gd"
## Port of ClusterBomb.cs: releases sub munitions on the descending part.

@export var subMunitionPrefab: PackedScene
@export var numSubmunitions := 5
@export var clusterRange := 2


func fly_and_check_progress(delta: float) -> void:
	fly(delta)
	var release_at := ascendingPartPercent + (1.0 - ascendingPartPercent) * 0.25
	if percentFinished >= release_at:
		release_cluster()


func release_cluster() -> void:
	if not U.alive(go):
		return
	started = false
	if U.alive(destinationTile):
		var tiles: Array = destinationTile.get_surrounding_tiles(clusterRange)
		var idx := U.shuffle_index(tiles.size())
		var n := mini(numSubmunitions, tiles.size())
		for i in n:
			var sub := U.instantiate_at(subMunitionPrefab, go.get_parent(), go.global_position, go.global_transform.basis.orthonormalized())
			var flight = U.comp(sub, "ProjectileStraightFlight")
			flight.player = player
			flight.fly_towards(tiles[idx[i]], damage)
	U.destroy(go)
