extends "res://scripts/components/Component.gd"
## Port note: no Unity original. One terrain feature (I90): the mass standing on `tiles`,
## set as the structure of every tile it covers, so every placement rule refuses those
## tiles until the feature falls. Destructible features soak shells like a wall, 10 health
## a tile; indestructible ones absorb every hit.

## What a tile of feature mass costs to clear, the same a wall costs a shell.
const HEALTH_PER_TILE := 10.0

var map = null
var tiles: Array = []
var destructible := true
var health := 0.0


func take_damage(damage: float, from := Vector3.INF) -> void:
	if not destructible:
		Sound.play("hit_wall")
		return
	health -= damage
	if health > 0.0:
		Sound.play("hit_wall")
	else:
		die(from, damage)


## Frees every tile (the killing blow also scarring the ground it frees, I74), crumbles
## each art child away from the shot, then the feature goes.
func die(from := Vector3.INF, kill_damage := 0.0) -> void:
	Sound.play("crumble")
	map.terrain_features.erase(go)
	for t in tiles:
		if t.structure != go:
			continue
		map.set_mini(t.idxX, t.idxZ, 0)
		t.structure = null
		t.player = null
		map.statesMap.update_tile(t)
		if kill_damage > 0.0:
			t.damage_ground(kill_damage)
	for child in go.get_children():
		if child.has_meta("art_look"):
			Crumble.crumble(child, from)
	U.destroy(go)
	if map.game != null:
		for q in map.game.players:
			q.reach_changed()
