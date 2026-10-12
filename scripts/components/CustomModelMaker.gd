extends "res://scripts/components/Component.gd"
## Port of CustomModelMaker.cs: random decoration models (trees, stones...).

@export var modelVariants: Array = []
@export var fromColors: Array = []
@export var toColors: Array = []
@export var sizeFrom := 1.0
@export var sizeTo := 1.0
@export var rarityModifier := 1.0
## Art-layer id after "nature_", e.g. "leaf_tree" for 3d/nature_leaf_tree.glb and its looks.
## Art models keep their palette colours, the FBX recolouring only runs on the fallback.
@export var kind := ""


func get_randomized_model(parent: Node3D) -> Node3D:
	var variant: Node3D = Art.instance("nature_" + kind) if kind != "" else null
	if variant == null:
		variant = U.instantiate(modelVariants[U.rint(0, modelVariants.size())], parent)
		var mis := U.meshes(variant)
		if not mis.is_empty():
			var mi: MeshInstance3D = mis[0]
			for i in mini(mi.mesh.get_surface_count(), fromColors.size()):
				U.set_surface_color(mi, i, (fromColors[i] as Color).lerp(toColors[i], U.value()))
	else:
		parent.add_child(variant)
	var scale_modifier := lerpf(sizeFrom, sizeTo, U.value())
	variant.scale *= scale_modifier
	variant.rotate_y(deg_to_rad(U.rfloat(0.0, 360.0)))
	return variant
