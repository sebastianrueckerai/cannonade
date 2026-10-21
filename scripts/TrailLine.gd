class_name TrailLine
extends "res://scripts/components/LineRenderer.gd"
## The white ribbon trailing a projectile (I77): a window of past flight positions rebuilt
## each frame, fading toward the tail; the compatibility renderer has no particle trails.

const SEGMENTS := 20
## Seconds of flight between two ribbon points.
const SPACING := 0.04

var _timer := 0.0


func _ready() -> void:
	width = 0.12
	taper = true
	super._ready()
	positions.resize(SEGMENTS)
	positions.fill(get_parent().global_position)
	set_positions(positions)


func _process(delta: float) -> void:
	_timer += delta
	while _timer >= SPACING:
		_timer -= SPACING
		positions.insert(0, get_parent().global_position)
		positions.remove_at(SEGMENTS)
	set_positions(positions)
