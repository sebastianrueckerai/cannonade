@tool
class_name ProjectileDef
extends Resource
## A projectile type. Files live in res://data/projectiles/.

enum Kind { SHELL, CLUSTER, STRAIGHT, ROCKET }

## SHELL: ballistic arc; CLUSTER: shell that releases sub munitions;
## STRAIGHT: flies straight to its tile; ROCKET: up, over and down
@export var kind := Kind.SHELL
@export var model: PackedScene
## Flight speed (SHELL / CLUSTER use the gun's ballistics instead)
@export var velocity := 3.0
## Tiles around the target that are hit too
@export var splash_range := 0
## The landing smokes over every splash tile (the heavy shell's 3x3)
@export var smoke_puff := false
## Seconds hit tiles burn (cannot be built on)
@export var burn_time := 0.0
## Seconds hit guns are stunned and tiles shake
@export var stun_time := 0.0
## The hit tile is destroyed for good
@export var tile_destroyer := false
## Spins while flying
@export var rotates := true

@export_group("Cluster")
@export var cluster_count := 5
## Sub munitions land within this many tiles of the target
@export var cluster_range := 2
@export var submunition: ProjectileDef
