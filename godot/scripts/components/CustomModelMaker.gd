extends "res://scripts/components/Component.gd"
## Port of CustomModelMaker.cs: random decoration models (trees, stones...).

@export var modelVariants: Array = []
@export var fromColors: Array = []
@export var toColors: Array = []
@export var sizeFrom := 1.0
@export var sizeTo := 1.0
@export var rarityModifier := 1.0


func get_randomized_model(parent: Node3D) -> Node3D:
	var variant := U.instantiate(modelVariants[U.rint(0, modelVariants.size())], parent)
	var scale_modifier := lerpf(sizeFrom, sizeTo, U.value())
	variant.scale *= scale_modifier
	variant.rotate_y(deg_to_rad(U.rfloat(0.0, 360.0)))
	var mis := U.meshes(variant)
	if not mis.is_empty():
		var mi: MeshInstance3D = mis[0]
		for i in mini(mi.mesh.get_surface_count(), fromColors.size()):
			U.set_surface_color(mi, i, (fromColors[i] as Color).lerp(toColors[i], U.value()))
	return variant
