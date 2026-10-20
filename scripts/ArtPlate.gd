extends Node3D
## The plate under a gun model: the gun turns to aim, the plate stays square to the tile grid.
## The plate stays the gun's child, so it goes wherever the gun goes: from its slot onto the board, onto a 2x2
## square's centre, up with a discard. It takes back the gun's turn when the engine reports the change, after every
## node's process and before the frame is drawn, so no frame shows it swung (session 11 gate fault: a plate turned
## back in its own process lagged a frame behind every re-aim).

var _square: Basis


func _ready() -> void:
	_square = global_basis
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and not global_basis.is_equal_approx(_square):
		global_basis = _square
