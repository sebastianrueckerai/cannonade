extends Node3D
## The plate under a gun model: the gun turns to aim, the plate stays square to the tile grid.


func _process(_delta: float) -> void:
	global_basis = Basis.IDENTITY
