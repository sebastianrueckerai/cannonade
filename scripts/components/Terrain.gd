extends "res://scripts/components/Component.gd"
## Port note: no Unity original. One terrain feature (I90): the mass standing on `tiles`,
## set as the structure of every tile it covers, so every placement rule refuses those
## tiles until its columns fall. A feature is columns of boxes, one a level (I97): a shell
## shatters the top block of the tile it hits, the column steps down, and the tile frees
## when its last block goes — the killing blow also scarring the ground it frees (I74) —
## and the feature dies with its last column. Indestructible features absorb every hit.

## What one block of feature mass costs to clear, the same a wall costs a shell.
const HEALTH_PER_TILE := 10.0

var map = null
var tiles: Array = []
## One tile's column of art blocks, bottom first; it shrinks as blocks shatter (I97).
var columns := {}
var destructible := true
var health := 0.0
var _hp := {}  # tile -> Array, block health parallel to its column


## Registers one tile's column and its blocks' health.
func set_column(tile, blocks: Array) -> void:
	columns[tile] = blocks
	_hp[tile] = []
	for b in blocks:
		_hp[tile].append(HEALTH_PER_TILE)
		health += HEALTH_PER_TILE


## World height of the tile's column top, of its ground once the column is gone.
func top_of(tile) -> float:
	var col: Array = columns.get(tile, [])
	if col.is_empty():
		return tile.go.position.y
	return col.back().global_position.y + Art.bounds(col.back()).end.y


## A shell breaks blocks from the top of the hit tile's column; damage left over falls to
## the block below. A block that survives cracks (the wall hit), one that dies shatters.
func take_damage(damage: float, from := Vector3.INF, tile = null) -> void:
	if not destructible or tile == null or not columns.has(tile):
		Sound.play("hit_wall")
		return
	var col: Array = columns[tile]
	var hps: Array = _hp[tile]
	var fell := false
	while damage > 0.0 and not col.is_empty():
		var top: int = col.size() - 1
		var hit: float = minf(damage, hps[top])
		hps[top] -= hit
		damage -= hit
		if hps[top] > 0.0:
			break
		Crumble.crumble(col.pop_back(), from)
		hps.pop_back()
		health -= HEALTH_PER_TILE
		fell = true
		if col.is_empty():
			_free_tile(tile, hit)
	Sound.play("crumble" if fell else "hit_wall")


func _free_tile(tile, scar: float) -> void:
	columns.erase(tile)
	_hp.erase(tile)
	tiles.erase(tile)
	map.set_mini(tile.idxX, tile.idxZ, 0)
	tile.structure = null
	tile.player = null
	map.statesMap.update_tile(tile)
	if scar > 0.0:
		tile.damage_ground(scar)
	if tiles.is_empty():
		map.terrain_features.erase(go)
		U.destroy(go)
	if map.game != null:
		for q in map.game.players:
			q.reach_changed()


## Frees every tile, crumbles every block away from the shot, then the feature goes.
func die(from := Vector3.INF, kill_damage := 0.0) -> void:
	Sound.play("crumble")
	map.terrain_features.erase(go)
	for t in tiles:
		map.set_mini(t.idxX, t.idxZ, 0)
		t.structure = null
		t.player = null
		map.statesMap.update_tile(t)
		if kill_damage > 0.0:
			t.damage_ground(kill_damage)
	for tile in columns:
		for block in columns[tile]:
			Crumble.crumble(block, from)
	U.destroy(go)
	if map.game != null:
		for q in map.game.players:
			q.reach_changed()
