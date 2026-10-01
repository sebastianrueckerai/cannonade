extends "res://scripts/components/Component.gd"
## Port of ShipFleet.cs: spawns enemy ships on water at the map border.

@export var shipPrefab: PackedScene = preload("res://prefabs/Ship.tscn")

var spawns: Array = []
var map = null
var enemyPlayers: Array = []
var ships: Array = []
var game = null


func initilize_spawns() -> void:
	map = game.map
	for xi in map.sizeX:
		if map.tiles[xi][0].water:
			spawns.append(map.tiles[xi][0])
		if map.tiles[xi][map.sizeZ - 1].water:
			spawns.append(map.tiles[xi][map.sizeZ - 1])


func spawn_ships(n_ships := 1) -> void:
	if spawns.size() < n_ships:
		return
	var spawned := 0
	for i in game.random_shuffle_index(spawns.size()):
		var tile = spawns[i]
		if not U.alive(tile.ship) and not U.alive(tile.commingShip):
			var sgo := U.instantiate(shipPrefab, go)
			sgo.global_position = tile.go.global_position + sgo.position
			var ship := U.comp(sgo, "Ship")
			ship.set_sail(self, map, tile)
			ships.append(ship)
			spawned += 1
			if spawned == n_ships:
				break
