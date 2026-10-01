extends "res://scripts/components/Component.gd"
## Port of TileImpactor (Projectile.cs): base class of everything that flies
## towards a tile and damages it. Implements the IProjectile interface.

@export var velocity := 0.0
@export var burnTime := 0.0
@export var stunTime := 0.0
@export var splashRange := 0
@export var tileDestroyer := false

var player = null
var damage := 0.0
## BuildingPlace component of the target tile
var destinationTile = null


func _enter_tree() -> void:
	U.projectiles.append(self)


func _exit_tree() -> void:
	U.projectiles.erase(self)



func shoot_down() -> void:
	U.destroy(go)


## Counts a hit for the shooter when the target tile belongs to someone else.
func count_hit() -> void:
	var owner_player = destinationTile.player if U.alive(destinationTile) else null
	if player != null and owner_player != null and owner_player != player:
		player.count("hits")


func impact() -> void:
	count_hit()
	if U.alive(destinationTile):
		for tile in destinationTile.get_surrounding_tiles(splashRange):
			_effect_tile(tile)
		if tileDestroyer:
			disable_tile(destinationTile)
	U.destroy(go)


func _effect_tile(tile) -> void:
	# The Unity version damaged destinationTile once per splash tile; damage the
	# splash tile itself instead.
	tile.damage_building_place(damage)
	if burnTime > 0:
		tile.set_on_fire(burnTime)
	if stunTime > 0:
		tile.shake(stunTime)
		if U.alive(tile.structure):
			var shooter := U.shooter(tile.structure)
			if shooter != null:
				shooter.stun(stunTime)


static func disable_tile(tile) -> void:
	tile.disabled = true
	U.set_visible_meshes(tile.go, false)
