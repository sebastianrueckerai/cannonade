extends "res://scripts/components/Component.gd"
## The rules-v3 win object: a 3x3 building that holds its ground through four
## damage states, changes owner when another player's walls enclose it, and
## leaves a ruin that nobody claims or builds on.

const RUIN := 4
const NEUTRAL_COLOR := Color("#9c7a4f")
const STATES := ["castle", "castle_d1", "castle_d2", "castle_d3", "castle_d4"]

var state := 0
var map = null
var _bounds := AABB()
var _bounds_known := false


## World-space bounds of the attached art, for occlusion tests against the
## cursor. Recomputed after a state swap.
func bounds() -> AABB:
	if _bounds_known:
		return _bounds
	_bounds_known = true
	var art := go.get_node_or_null("Art")
	if art != null:
		for mi in U.meshes(art):
			if mi.mesh == null:
				continue
			var b: AABB = mi.global_transform * mi.get_aabb()
			_bounds = b if not _bounds.has_volume() else _bounds.merge(b)
	return _bounds


func take_damage(damage: float) -> void:
	if state == RUIN:
		return
	var bb = U.comp(go, "BuildingBlock")
	bb.health -= damage
	if bb.health <= 0:
		become_ruin()
	else:
		var full: float = Catalog.def_of(go).health
		var gone: float = 1.0 - bb.health / full
		set_state(clampi(int(gone * 4.0), 0, 3))


func become_ruin() -> void:
	var holder = owner()
	if holder != null:
		holder.count("castles_lost")
	Sound.play("castle_ruin")
	set_state(RUIN)
	hold_tiles(null)


## The own player hears a claim as a chime up, a loss as the chime down; others' claims are quieter.
func claim(p) -> void:
	var own = Indicators.own_player
	var lost: bool = own != null and owner() == own
	hold_tiles(p)
	repaint()
	Sound.play("castle_lost" if lost else "castle_claimed", 0.0 if lost or own == null or p == own else Sound.OTHER_DB)


func is_ruin() -> bool:
	return state == RUIN


func owner():
	var bb = U.comp(go, "BuildingBlock")
	return bb.player if bb != null else null


## Writes the holder of the 3x3 square: every tile, the mini map (255 = no
## player) and the block itself.
func hold_tiles(p) -> void:
	var before = owner()
	U.comp(go, "BuildingBlock").player = p
	for t in my_tiles():
		t.player = p
		map.set_mini(t.idxX, t.idxZ, 255 if p == null else p.playerID)
	for q in [before, p]:
		if U.alive(q):
			q.reach_changed()


func my_tiles() -> Array:
	var c: Vector2i = map.tile_index_at(go.global_position)
	var out: Array = []
	for dx in 3:
		for dz in 3:
			out.append(map.tiles[c.x - 1 + dx][c.y - 1 + dz])
	return out


func set_state(n: int) -> void:
	state = n
	for child in go.get_children():
		if child.has_meta("art_id"):
			U.destroy(child)
	Art.attach(go, STATES[n])
	_bounds = AABB()
	_bounds_known = false
	repaint()


func repaint() -> void:
	# d3 and d4 carry no team material, and the placeholder is one grey box
	if state >= 3 or go.get_node_or_null("Art") == null:
		return
	var p = owner()
	U.set_color(go, p.mainColor if p != null else NEUTRAL_COLOR)
