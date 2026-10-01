extends "res://scripts/components/Component.gd"
## Port of ShieldGenerator.cs (ISupportBuilding): absorbs enemy projectiles in range.

@export var secondsToReset := 4.0
@export var supplyNeeded := 4.0
@export var maxDamageAbsorb := 31.0
@export var currentDamageAbsorb := 31.0
@export var range := 7.0
@export var on := true
@export var shieldMeshRenderer: NodePath

var player = null
var resetting := false
var resetUntil := 0.0
var regenPerSecond := 0.0


func _ready() -> void:
	var bb := U.comp(go, "BuildingBlock")
	if bb:
		player = bb.player
	currentDamageAbsorb = maxDamageAbsorb
	refresh()


## Recomputes derived values after the parameters changed (catalog reload).
func refresh() -> void:
	regenPerSecond = maxDamageAbsorb / secondsToReset
	currentDamageAbsorb = minf(currentDamageAbsorb, maxDamageAbsorb)


func get_supply_needed() -> float:
	return supplyNeeded


func switch_on_off(value := true) -> void:
	if value == on:
		return
	on = value
	if on:
		_activate()
	else:
		_deactivate()


func _shield() -> Node3D:
	return get_node_or_null(shieldMeshRenderer) as Node3D


func _activate() -> void:
	if _shield():
		_shield().visible = true
	currentDamageAbsorb = 1.0


func _deactivate() -> void:
	if _shield():
		_shield().visible = false
	currentDamageAbsorb = 0.0


func _colliding_enemy_projectiles(r: float) -> Array:
	var out: Array = []
	for p in U.projectiles:
		if U.alive(p) and p.player != player and p.go.global_position.distance_to(go.global_position) <= r:
			out.append(p)
	return out


func _reset_if_depleted() -> void:
	if currentDamageAbsorb <= 0 and not resetting:
		resetting = true
		_deactivate()
		resetUntil = U.time + secondsToReset


func _process(delta: float) -> void:
	if player == null:
		var bb := U.comp(go, "BuildingBlock")
		if bb:
			player = bb.player
	if resetting and U.time >= resetUntil:
		resetting = false
		if on:
			_activate()
	if on and not resetting:
		for p in _colliding_enemy_projectiles(range):
			_reset_if_depleted()
			if resetting:
				break
			currentDamageAbsorb -= p.damage
			p.shoot_down()
		_reset_if_depleted()
		if not resetting and currentDamageAbsorb < maxDamageAbsorb:
			# Unity used Time.time here (a bug); regenerate per second instead.
			currentDamageAbsorb = minf(maxDamageAbsorb, currentDamageAbsorb + regenPerSecond * delta)
