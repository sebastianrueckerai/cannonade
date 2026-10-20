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
## Where the shot was fired from; a wall it kills crumbles away from it.
var start := Vector3.INF
## BuildingPlace component of the target tile
var destinationTile = null


func _enter_tree() -> void:
	U.projectiles.append(self)


func _exit_tree() -> void:
	U.projectiles.erase(self)
	if U.alive(destinationTile):
		destinationTile.target_off()


func shoot_down() -> void:
	U.destroy(go)


## Sets the tile this shot flies at and puts the shooter's targeting marker on it.
func aim_tile(dest_tile) -> void:
	destinationTile = dest_tile
	if U.alive(dest_tile) and player != null:
		dest_tile.target_on(player.mainColor)


## Counts a hit for the shooter when the target tile belongs to someone else.
func count_hit() -> void:
	var owner_player = destinationTile.player if U.alive(destinationTile) else null
	if player != null and owner_player != null and owner_player != player:
		player.count("hits")


func impact() -> void:
	count_hit()
	if U.alive(destinationTile):
		if destinationTile.water:
			Sound.play("hit_water")
		elif not U.alive(destinationTile.structure) and not U.alive(destinationTile.ship):
			Sound.play("hit_ground")
		for tile in destinationTile.get_surrounding_tiles(splashRange):
			_effect_tile(tile)
		if tileDestroyer:
			disable_tile(destinationTile)
	U.destroy(go)


func _effect_tile(tile) -> void:
	# The Unity version damaged destinationTile once per splash tile; damage the
	# splash tile itself instead.
	tile.damage_building_place(damage, start)
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
