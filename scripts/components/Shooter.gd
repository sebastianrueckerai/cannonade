extends "res://scripts/components/Component.gd"

const FX = preload("res://scripts/FX.gd")
## Port of Shooter.cs: ballistic cannon (implements IShooter).

@export var projectileSpawn: NodePath
@export var arcPrefab: PackedScene
@export var projectile: ProjectileDef
@export var barrel: NodePath
@export var cooldown: NodePath
@export var supplyNeeded := 0.0
@export var minRange := 2.0
@export var maxDesiredRange := 20.0
@export var gravity := 7.5
@export var ascendingPart := 0.6
@export var secondsBetweenShots := 1.0
@export var damage := 10.0
@export var turns := true
@export var nextBulletTime := 0.0

var player = null
var vOpt := 0.0
var angleRads := 0.0
var angleDegrees := 0.0
var flyTime := 0.0
var distance := 0.0
var stunned := false
var stunnedUntil := 0.0
## The predicted flight path drawn ahead of the shot (RenderArc): kept but switched off, the
## shell's trail shows where it flew (I77).
const ARC_ENABLED := false
var renderArc = null
var arc: Node3D
var _barrel_rot_y := 0.0
var _barrel_rot_z := 0.0


func _ready() -> void:
	nextBulletTime = U.time
	refresh()
	var b := _barrel()
	if b:
		_barrel_rot_y = b.rotation.y
		_barrel_rot_z = b.rotation.z
	sleep()


## The arc renderer is created lazily: the owning node is still busy adding
## children while _ready() runs.
func _arc():
	if renderArc == null:
		arc = U.instantiate(arcPrefab, go)
		renderArc = U.comp(arc, "RenderArc")
	return renderArc


func _barrel() -> Node3D:
	return get_node_or_null(barrel) as Node3D


func _spawn() -> Node3D:
	return get_node_or_null(projectileSpawn) as Node3D


## Recomputes derived values after the parameters changed (catalog reload).
func refresh() -> void:
	vOpt = sqrt(maxDesiredRange * gravity)


func get_supply_needed() -> float:
	return supplyNeeded


## Unity: barrel.localEulerAngles.x = deg. The x axis is mirrored in this port.
func _set_barrel_x(deg: float) -> void:
	var b := _barrel()
	if b:
		b.rotation = Vector3(deg_to_rad(-deg), _barrel_rot_y, _barrel_rot_z)


func sleep() -> void:
	if renderArc and U.alive(arc):
		renderArc.switch_on_or_off(false)
	_set_barrel_x(-10.0)


func try_aim(destination: Vector3) -> bool:
	_arc().line.color = Color.GRAY if player == null else player.mainColor
	distance = go.global_position.distance_to(destination)
	var reachable := can_reach(distance)
	if reachable and not stunned:
		# the flat (low) solution, never the steep one: the arc rises just high
		# enough to reach the farthest tile (J6)
		angleRads = asin(clampf(distance * gravity / pow(vOpt, 2.0), -1.0, 1.0)) / 2.0
		angleDegrees = rad_to_deg(angleRads)
		flyTime = 2.0 * vOpt * sin(angleRads) / gravity
		if turns:
			U.look_at(go, destination)
			var s := go.scale
			go.rotation = Vector3(0.0, go.rotation.y, 0.0)
			go.scale = s
		_set_barrel_x(angleDegrees)
		if Indicators.shows(player) and ARC_ENABLED:
			renderArc.draw_arc(10, _spawn().global_position, destination, distance, angleRads, ascendingPart)
		else:
			renderArc.switch_on_or_off(false)
	else:
		sleep()
	return reachable


func can_reach(d: float) -> bool:
	return d >= minRange and d <= maxDesiredRange


func stun(for_seconds: float) -> void:
	stunned = true
	sleep()
	stunnedUntil = U.time + for_seconds


func _process(_delta: float) -> void:
	if stunned and U.time >= stunnedUntil:
		stunned = false


## Damaged guns fire slower: every shell survived adds half the reload again.
## The shot's cue: the heavy shell has its own boom, a ship's gun is further away.
func shot_cue() -> String:
	if go.get_parent() != null and U.comp(go.get_parent(), "Ship") != null:
		return "shot_ship"
	return "shot_heavy" if projectile.resource_path.get_file().get_basename() == "heavy_shell" else "shot_cannon"


func _interval() -> float:
	var bb := U.comp(go, "BuildingBlock")
	return secondsBetweenShots * (1.0 + 0.5 * (bb.hits_taken if bb != null else 0))


func try_shoot(destination: Vector3, destination_tile) -> bool:
	var shot := false
	if not stunned and try_aim(destination) and U.time >= nextBulletTime:
		shot = true
		if player != null:
			player.count("shots")
		var wait := _interval()
		nextBulletTime = U.time + wait
		var cd := get_node_or_null(cooldown)
		if cd:
			cd.run(wait)
		_arc().switch_on_or_off(false)  # the shell is the line now; the next aim draws the arc again
		var rot := Basis(Vector3.UP, go.global_rotation.y)
		var shell := Catalog.spawn_projectile(projectile, U.world(), _spawn().global_position, rot)
		shell.player = player
		Sound.play(shot_cue(), 0.0 if player == null or not player.is_ai() else Sound.OTHER_DB)
		var spawn_pos := _spawn().global_position
		var flat := destination - spawn_pos
		flat.y = 0.0
		flat = -go.global_transform.basis.z if flat.length_squared() < 0.0001 else flat.normalized()
		FX.muzzle(spawn_pos, (flat * cos(angleRads) + Vector3.UP * sin(angleRads)).normalized())
		shell.fly_towards(destination, destination_tile, distance, vOpt, angleRads, flyTime, gravity,
				ascendingPart, damage)
	return shot
