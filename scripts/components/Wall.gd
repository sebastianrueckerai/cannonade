extends "res://scripts/components/Component.gd"
## A wall block (D78). It wears its owner's look (Catalog.wall_look), shows its walkway from the centre square
## toward every side where an own wall stands (alone, only the centre), and turns into the upper storey when
## stacked. The block is one mesh under materials/wall.gdshader; its faces carry a region id in UV2, written by
## art/game/assets/3d/wall_block.py, and every block has its own material with one colour per region.

const SHADER := preload("res://materials/wall.gdshader")
const STONE := Color("#e8d6b0")
const WHITE := Color.WHITE
## The corridor regions and the tile step each leads to: +x, -x, tile z + 1 (Godot -z) and tile z - 1.
const DIRS := {2: Vector2i(1, 0), 3: Vector2i(-1, 0), 4: Vector2i(0, 1), 5: Vector2i(0, -1)}
const CENTRE := 1
const CAP := 4  # a corridor's cap region is its own plus 4
const RIM := 11
const BAND := 12
const REGIONS := 13
## How far the walkway goes from the stone toward the owner's colour (session 26's call).
static var walk_tint := 0.6
## The rim line round the deck and the band round the body's top, both unpicked (D79), 0 = stone. Tool knobs.
static var rim_tint := 0.0
static var band_tint := 0.0


## The owner's look on the block; the art is only replaced when the block wears another.
func wear(owner) -> void:
	var id: String = Catalog.wall_look(owner)
	var art: Node = go.get_node_or_null("Art")
	if art != null and art.get_meta("art_id", "") == id:
		return
	if art != null:
		go.remove_child(art)
		art.free()
	Art.attach(go, id)
	dress(go.get_node_or_null("Art"))


## Stacked on another block, the art turns into the storey of the same look.
func show_upper() -> void:
	var art: Node = go.get_node_or_null("Art")
	var look: String = art.get_meta("art_id", "wall") if art != null else Catalog.wall_look(null)
	if art != null:
		go.remove_child(art)
		art.free()
	Art.attach(go, look.trim_suffix("_upper") + "_upper")
	dress(go.get_node_or_null("Art"))
	repaint()


## The block's colours from its tile's neighbours; `shade` darkens the whole block (the placement preview).
func repaint(shade := 1.0) -> void:
	var bb = U.comp(go, "BuildingBlock")
	var open := {}
	for r in DIRS:
		open[r] = bb.buildingPlace != null and own_wall_beside(bb.buildingPlace, DIRS[r], bb.player)
	paint_art(go.get_node_or_null("Art"), bb.player, open, shade)


static func own_wall_beside(tile, d: Vector2i, owner) -> bool:
	var map = tile.map
	var x: int = tile.idxX + d.x
	var z: int = tile.idxZ + d.y
	if x < 0 or z < 0 or x >= map.sizeX or z >= map.sizeZ:
		return false
	var t = map.tiles[x][z]
	return t.isWall and U.alive(t.structure) and U.comp(t.structure, "BuildingBlock").player == owner


## The block's shader material over its painted texture, in the stone colours until it is painted for an owner.
static func dress(art: Node3D) -> void:
	var mi := _mesh(art)
	if mi == null:
		return
	var base: Material = mi.mesh.surface_get_material(0)
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tex", base.albedo_texture if base is BaseMaterial3D else null)
	mi.material_override = m
	paint_art(art, null, {})


## One colour per region: the walkway (the centre and every open corridor with its cap) in the owner's tint, the
## deck's corners and the rim stone, the body and merlons their painted stone (factor white).
static func paint_art(art: Node3D, owner, open: Dictionary, shade := 1.0) -> void:
	var m := material(art)
	if m == null:
		return
	var team: Color = owner.mainColor if owner != null else STONE
	var walk := STONE.lerp(team, walk_tint)
	var colors := PackedColorArray()
	colors.resize(REGIONS)
	colors.fill(STONE)
	colors[0] = WHITE
	colors[CENTRE] = walk
	for r in DIRS:
		if open.get(r, false):
			colors[r] = walk
			colors[r + CAP] = walk
	colors[RIM] = STONE.lerp(team, rim_tint)
	var band := STONE.lerp(team, band_tint)  # over the stone texture: the factor that reaches the band colour
	colors[BAND] = Color(band.r / STONE.r, band.g / STONE.g, band.b / STONE.b)
	m.set_shader_parameter("colors", colors)
	m.set_shader_parameter("shade", shade)


## A hand piece: each cell's walkway runs toward the piece's other cells, in the piece's own frame, which turns
## with it. `cells` are the def's, in the order of the cell nodes.
static func paint_piece(piece: Node3D, owner, cells: Array, shade := 1.0) -> void:
	var nodes := piece.get_children().filter(func(n): return n is Node3D)
	for i in mini(cells.size(), nodes.size()):
		var open := {}
		for r in DIRS:
			open[r] = cells.has(cells[i] + DIRS[r])
		paint_art(nodes[i].get_node_or_null("Art"), owner, open, shade)


static func material(art: Node3D) -> ShaderMaterial:
	var mi := _mesh(art)
	return mi.material_override as ShaderMaterial if mi != null else null


static func _mesh(art: Node3D) -> MeshInstance3D:
	return art.find_child("wall", true, false) as MeshInstance3D if art != null else null
