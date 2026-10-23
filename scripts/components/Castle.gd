extends "res://scripts/components/Component.gd"
## The rules-v3 win object: a 3x3 building that holds its ground through four
## damage states, changes owner when another player's walls enclose it, and
## leaves a ruin that nobody claims or builds on.

const RUIN := 4
const NEUTRAL_COLOR := Color("#9c7a4f")
const BASE_STATES := ["castle", "castle_d1", "castle_d2", "castle_d3", "castle_d4"]
const FLAG_SHADER := preload("res://materials/flag.gdshader")

var state := 0
## The art look the placement drew (castle, castle.2, ...), pinned for the castle's life so its
## damage states stay its own (C20).
var look := 0
var map = null
var _bounds := AABB()
var _bounds_known := false


func _ready() -> void:
	# deferred: _ready fires inside BuildingPlace's add_child propagation, where an
	# add_child on the parent is silently dropped
	_fly_flag.call_deferred()


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


func take_damage(damage: float, from := Vector3.INF) -> void:
	if state == RUIN:
		return
	var bb = U.comp(go, "BuildingBlock")
	bb.health -= damage
	if bb.health <= 0:
		become_ruin(from)
		map.game.decide()
	else:
		var full: float = Catalog.def_of(go).health
		var gone: float = 1.0 - bb.health / full
		set_state(clampi(int(gone * 4.0), 0, 3))


## The castle falls to ruins: its severe look crumbles away from the shot, whatever look it wore (I69), and the ruin
## stands.
func become_ruin(from := Vector3.INF) -> void:
	var holder = owner()
	if holder != null:
		holder.count("castles_lost")
	Sound.play("castle_ruin")
	_pin_look()
	Crumble.crumble(go, from, state_model(RUIN - 1))
	set_state(RUIN)
	_ruin_body()
	_topple_flag(from)
	hold_tiles(null)


## The ruin catches its own shatter (I66): a slab over its bounds like a standing wall's box
## (BuildingPlace._wall_body), 0.3 m thick with its top at 0.8 of the ruin's height, where the broken
## walls end (castle_d4's surface stands 0.77 to 0.92 of it), so the pieces from above lie on the rubble.
## A thin slab, not a full box: the dying castle's pieces are born inside the ruin's bounds - a wall's
## own box goes away with the wall, so it never meets its pieces - and a solid box of the whole bounds
## shoves the low ones under the ground. Born under the slab they fall to the floor, hidden in the ruin.
## Gone with the castle.
func _ruin_body() -> void:
	var bb := bounds()
	var body := StaticBody3D.new()
	body.name = "RuinBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var top := maxf(0.3, bb.size.y * 0.8)
	box.size = Vector3(bb.size.x, 0.3, bb.size.z)
	shape.shape = box
	go.add_child(body)
	body.add_child(shape)
	body.global_position = Vector3(bb.get_center().x, bb.position.y + top - 0.15, bb.get_center().z)

## Flies the castle's flag (I115): a separate model, not part of the state meshes, docked on a point
## the state model carries. The cloth waves in flag.gdshader and takes the player colour like the
## body's team slot; the pole wears the flat `team` material, so set_color carries it too.
func _fly_flag() -> void:
	var scene: PackedScene = load("res://assets/art/3d/flag.glb")
	if scene == null:
		return
	var flag := scene.instantiate()
	flag.name = "Flag"
	go.add_child(flag)
	var cloth := flag.find_child("flag_cloth", true, false)
	if cloth is MeshInstance3D:
		var m := ShaderMaterial.new()
		m.shader = FLAG_SHADER
		m.set_shader_parameter("albedo", NEUTRAL_COLOR)
		m.set_shader_parameter("alpha", 1.0)
		cloth.material_override = m
	_dock_flag()
	repaint()


## Seats the flag on the dock point the current state's model carries: the pole rides the surviving
## geometry, so the flag stands a little lower with every damage state and never moves sideways.
func _dock_flag() -> void:
	var flag := go.get_node_or_null("Flag")
	var art := go.get_node_or_null("Art")
	if flag == null or art == null:
		return
	var dock := art.find_child("flag_dock", true, false)
	if dock is Node3D:
		flag.transform = Art._rel(dock, go)


## The castle crumbles: the flag tips away from the shot and fades out with the fall (I115).
func _topple_flag(from: Vector3) -> void:
	var flag: Node3D = go.get_node_or_null("Flag")
	if flag == null:
		return
	var away := (flag.global_position - from) * Vector3(1, 0, 1)
	if away.length_squared() < 0.01 or not away.is_finite():
		away = Vector3(0, 0, 1)
	flag.rotation.y = atan2(away.x, away.z)
	var tw := flag.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(flag, "rotation:x", 1.9, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(k: float): U.set_alpha(flag, 1.0 - k), 0.0, 1.0, 0.9)
	tw.tween_callback(flag.queue_free)



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


## The model of state `n` in this castle's own look.
func state_model(n: int) -> String:
	return BASE_STATES[n] if look <= 1 else "%s.%d" % [BASE_STATES[n], look]


## Reads the look the placement drew off the art, once; every state resolves through it.
## The art wears the drawn look until the first swap, so the pin must happen before it goes.
func _pin_look() -> void:
	if look != 0:
		return
	var art := go.get_node_or_null("Art")
	var worn: String = art.get_meta("art_look", "") if art != null else ""
	look = worn.get_slice(".", 1).to_int() if worn.begins_with("castle.") else 1


func set_state(n: int) -> void:
	_pin_look()
	state = n
	for child in go.get_children():
		if child.has_meta("art_id"):
			U.destroy(child)
	Art.attach(go, state_model(n), Art.SLAB_TOP, true)
	_dock_flag()
	_bounds = AABB()
	_bounds_known = false
	repaint()


func repaint() -> void:
	var p = owner()
	var flag := go.get_node_or_null("Flag")
	if flag != null:
		# the flag flies the colour in every state: even a late ruin is still alive (I115)
		U.set_color(flag, p.mainColor if p != null else NEUTRAL_COLOR)
	# d3 and d4 carry no team material, and the placeholder is one grey box
	if state >= 3 or go.get_node_or_null("Art") == null:
		return
	U.set_color(go, p.mainColor if p != null else NEUTRAL_COLOR)
