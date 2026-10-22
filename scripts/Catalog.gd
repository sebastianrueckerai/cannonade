extends Node
## Building catalog (autoload "Catalog"): loads the BuildingDef files in
## res://data/buildings, validates them, spawns configured buildings and
## projectiles, and answers recipe questions (upgrade patterns, combinations).
##
## A spawned building is the def's model scene; its behaviour components
## (scripts/components) are created here from the def, replacing any that the
## model scene brings along, so the data always wins.

const BUILDINGS_DIR := "res://data/buildings"
const C := "res://scripts/components/"
const ARC := preload("res://prefabs/ArcRenderer.tscn")
const TrailLine := preload("res://scripts/TrailLine.gd")
## components a model scene may carry that are replaced by the def's
const BUILDING_COMPONENTS := ["BuildingBlock", "Wall", "FlyAndVanish", "Upgrade", "Combinable",
	"UpgradedStructure", "Shooter", "RocketLauncher", "Flak", "ShieldGenerator", "SupplyBuilding",
	"Castle", "Structure"]
const PROJECTILE_COMPONENTS := ["Projectile", "ClusterBomb", "ProjectileStraightFlight", "S2SRocket"]

signal reloaded

## id -> BuildingDef (only valid ones)
var defs := {}
## valid defs parked out of the game (D64): never spawned, drawn or listed,
## but recipes may still name them
var parked := {}
## ids in a stable (sorted) order
var ids: Array[String] = []
## readable problems found while loading ("<file>: <problem>")
var errors: Array[String] = []
var _dir := BUILDINGS_DIR


func _ready() -> void:
	load_dir(BUILDINGS_DIR)


# ----------------------------------------------------------------- loading
## Loads every .tres in dir (replacing the current catalog). Broken files are
## skipped and reported in `errors`; this never throws.
func load_dir(dir: String, replace_cache := false) -> void:
	_dir = dir
	defs = {}
	parked = {}
	ids = []
	errors = []
	var files := DirAccess.get_files_at(dir)
	if files.is_empty():
		errors.append("%s: no building files found" % dir)
	for f in files:
		f = f.trim_suffix(".remap")
		if not f.ends_with(".tres"):
			continue
		var path := dir.path_join(f)
		var res: Resource = ResourceLoader.load(path, "",
				ResourceLoader.CACHE_MODE_REPLACE_DEEP if replace_cache else ResourceLoader.CACHE_MODE_REUSE)
		if not res is BuildingDef:
			errors.append("%s: not a building definition (could not be read)" % f)
			continue
		var def: BuildingDef = res
		def.id = f.get_basename()
		var problems := _check_def(def)
		for p in problems:
			errors.append("%s: %s" % [f, p])
		if problems.is_empty():
			if def.parked:
				parked[def.id] = def
			else:
				defs[def.id] = def
	ids.assign(defs.keys())
	ids.sort()
	_check_catalog()
	for e in errors:
		push_warning("Catalog: " + e)


## Re-reads the files and applies the new numbers to placed buildings.
func reload() -> void:
	load_dir(_dir, true)
	for go in get_tree().get_nodes_in_group("structures"):
		var s := U.comp(go, "Structure")
		if s != null and defs.has(s.def.id):
			s.def = defs[s.def.id]
			_apply_params(go, s.def)
	reloaded.emit()


func _check_def(d: BuildingDef) -> Array[String]:
	var p: Array[String] = []
	if d.model == null:
		p.append("no model scene")
	if d.size < 1 or d.size > 3:
		p.append("size must be 1, 2 or 3")
	if not (d.access.is_empty() or d.access.size() == 9):
		p.append("access needs 9 entries (or none)")
	if not (d.recipe_pattern.is_empty() or d.recipe_pattern.size() == d.size * d.size):
		p.append("recipe_pattern needs %d entries for size %d" % [d.size * d.size, d.size])
	if d.category == BuildingDef.Category.WALL and d.draw_weight > 0 and d.piece.is_empty() and not d.parked:
		p.append("a drawn wall needs piece cells")
	if not (d.recipe_combine.is_empty() or d.recipe_combine.size() == 2):
		p.append("recipe_combine needs 2 entries: [placed building, building it is placed on]")
	for b in d.behaviours:
		if b == null:
			p.append("empty behaviour entry")
		elif (b is CannonBehaviour or b is RocketBehaviour) and b.projectile == null:
			p.append("%s has no projectile" % b.get_script().get_global_name())
		elif (b is CannonBehaviour or b is RocketBehaviour) and b.projectile.model == null:
			p.append("projectile %s has no model" % b.projectile.resource_path.get_file())
	return p


## Checks across files: unknown ids, ambiguous recipes, missing essentials.
func _check_catalog() -> void:
	var defaults := {}
	for id in ids:
		var d: BuildingDef = defs[id]
		for part in d.recipe_pattern:
			# recipes may name parked buildings (the upgrade blocks live on in
			# data but out of the game)
			var pd: BuildingDef = defs.get(part, parked.get(part))
			if part != "*" and pd == null:
				errors.append("%s: recipe_pattern uses unknown building '%s'" % [id, part])
			elif part != "*" and pd.size != 1:
				errors.append("%s: recipe_pattern part '%s' is not a single tile building" % [id, part])
		for part in d.recipe_combine:
			if not defs.has(part) and not parked.has(part):
				errors.append("%s: recipe_combine uses unknown building '%s'" % [id, part])
		if d.recipe_default_for_size:
			if defaults.has(d.size):
				errors.append("%s: %s is already the default for size %d" % [id, defaults[d.size], d.size])
			defaults[d.size] = id
	# two patterns that are equal as laid out (or turned by 180 degrees) can
	# never both be built
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: BuildingDef = defs[ids[i]]
			var b: BuildingDef = defs[ids[j]]
			if a.recipe_pattern.is_empty() or a.recipe_pattern.size() != b.recipe_pattern.size():
				continue
			var ra := rotations(Array(a.recipe_pattern), a.size)
			var pb := Array(b.recipe_pattern)
			if ra[0] == pb or ra[2] == pb:
				errors.append("%s and %s have the same recipe_pattern" % [ids[i], ids[j]])
			if a.recipe_combine == b.recipe_combine and not a.recipe_combine.is_empty():
				errors.append("%s and %s have the same recipe_combine" % [ids[i], ids[j]])
	if of_category(BuildingDef.Category.BASE).is_empty():
		errors.append("no building with category BASE (start base)")
	if drawable(BuildingDef.Category.WALL).is_empty():
		errors.append("no WALL with a draw_weight above 0")
	if not defs.has("wall"):
		errors.append("no wall block: data/buildings/wall.tres")


# ------------------------------------------------------------------ queries
func get_def(id: String) -> BuildingDef:
	return defs.get(id)


## The def a spawned building was made from (null for anything else)
func def_of(go) -> BuildingDef:
	var s := U.comp(go, "Structure")
	return s.def if s != null else null


func of_category(cat: int) -> Array[BuildingDef]:
	var out: Array[BuildingDef] = []
	for id in ids:
		if defs[id].category == cat:
			out.append(defs[id])
	return out


func drawable(cat: int) -> Array[BuildingDef]:
	var out: Array[BuildingDef] = []
	for d in of_category(cat):
		if d.draw_weight > 0:
			out.append(d)
	return out


## Random pick weighted by draw_weight (one random number).
func draw(cat: int) -> BuildingDef:
	var pool := drawable(cat)
	if pool.is_empty():
		return null
	var total := 0.0
	for d in pool:
		total += d.draw_weight
	var r := U.rfloat(0.0, 1.0) * total
	for d in pool:
		r -= d.draw_weight
		if r < 0:
			return d
	return pool[-1]


func base_def() -> BuildingDef:
	var bases := of_category(BuildingDef.Category.BASE)
	return bases[0] if not bases.is_empty() else null


## Ids used in upgrade patterns or as placed part of a combination: such
## buildings are "upgrade blocks" that can merge into bigger structures.
func is_ingredient(id: String) -> bool:
	for d in defs.values():
		if d.recipe_pattern.has(id) or (not d.recipe_combine.is_empty() and d.recipe_combine[0] == id):
			return true
	return false


## The building made by placing `placed` onto `onto` (null if none).
func combination(placed: String, onto: String) -> BuildingDef:
	for id in ids:
		var d: BuildingDef = defs[id]
		if d.recipe_combine.size() == 2 and d.recipe_combine[0] == placed and d.recipe_combine[1] == onto:
			return d
	return null


## The structure built from a square of ingredients (ids column by column from
## the lower left, "*" = empty). A pattern matching as laid out wins over one
## turned by 180 degrees, which wins over 90 / 270 degrees. Falls back to the
## size's default.
func pick_for_pattern(layout: Array) -> BuildingDef:
	var side := int(sqrt(layout.size()))
	for pass_rotations in [[0], [2], [1, 3]]:
		for id in ids:
			var d: BuildingDef = defs[id]
			if d.recipe_pattern.size() != layout.size():
				continue
			var rots := rotations(Array(d.recipe_pattern), side)
			for k in pass_rotations:
				if fits(rots[k], layout):
					return d
	for id in ids:
		if defs[id].recipe_default_for_size and defs[id].size == side:
			return defs[id]
	return null


## A layout fits a pattern when every entry is equal or a wildcard ("*").
static func fits(pattern: Array, layout: Array) -> bool:
	for i in pattern.size():
		if pattern[i] != "*" and layout[i] != "*" and pattern[i] != layout[i]:
			return false
	return true


## sig turned by 0, 90, 180 and 270 degrees.
static func rotations(sig: Array, side: int) -> Array:
	var out := [sig.duplicate(), sig.duplicate(), sig.duplicate(), sig.duplicate()]
	for row in side:
		for col in side:
			var i000 := row * side + col
			out[1][i000] = sig[(side - 1 - row) + side * col]
			out[2][i000] = sig[side * side - 1 - i000]
			out[3][i000] = sig[(side - 1 - col) * side + row]
	return out


# ----------------------------------------------------------------- spawning
const WallComp = preload("res://scripts/components/Wall.gd")
## The wall looks of D78. Every game deals each player a different one (D81, Main.build); a block with no owner
## wears the first.
const WALL_LOOKS := ["wall", "wall_corbel", "wall_pilaster", "wall_course"]


static func wall_look(owner) -> String:
	return owner.wallLook if owner != null and owner.wallLook != "" else WALL_LOOKS[0]


## The looks in a random order, drawn from the art's own generator so the game's random sequence stays.
static func deal_wall_looks() -> Array:
	var looks: Array = WALL_LOOKS.duplicate()
	for i in range(looks.size() - 1, 0, -1):
		var j: int = Art._rng.randi_range(0, i)
		var t = looks[i]
		looks[i] = looks[j]
		looks[j] = t
	return looks


## Instantiates a building (by id or def), not yet added to the tree when parent is null. A wall block or piece
## wears `owner`'s look from the start (BuildingPlace.build corrects a block spawned without one).
func spawn(def_or_id, parent: Node = null, owner = null) -> Node3D:
	var def: BuildingDef = def_or_id if def_or_id is BuildingDef else get_def(def_or_id)
	if def == null:
		push_error("Catalog: unknown building %s" % [def_or_id])
		return null
	var go: Node3D = def.model.instantiate()
	if def.id == "wall":
		WallComp.put_on(go, wall_look(owner))
	else:
		Art.attach(go, def.id)
	if not def.piece.is_empty():
		_add_piece_cells(go, def, owner)
	configure(go, def)
	if parent != null:
		parent.add_child(go)
	return go


## Replaces the behaviour components of `go` by the ones `def` describes.
func configure(go: Node3D, def: BuildingDef) -> void:
	for n in BUILDING_COMPONENTS:
		var old := go.get_node_or_null(NodePath(n))
		if old != null:
			go.remove_child(old)
			old.free()
	go.add_to_group("structures")
	var structure := _add(go, "Structure")
	structure.def = def
	var bb := _add(go, "BuildingBlock")
	bb.accessColFromDownLeft = def.access.duplicate() if def.access.size() == 9 else [true, true, true, true, true, true, true, true, true]
	bb.health = def.health
	bb.cells = def.piece.duplicate()
	if def.category == BuildingDef.Category.BASE:
		_add(go, "Castle")
	if def.category == BuildingDef.Category.WALL or def.draw_weight > 0:
		_add(go, "FlyAndVanish")
	if is_ingredient(def.id):
		_add(go, "Upgrade").upgradeType = def.id
	if def.produces.get("supply", 0.0) > 0:
		_add(go, "SupplyBuilding").supply = def.produces["supply"]
	for b in def.behaviours:
		if b is CannonBehaviour:
			var s := _add(go, "Shooter")
			s.arcPrefab = ARC
			s.projectileSpawn = _anchor_path(go, s, "ProjectileSpawn", Vector3(0, 1, 0))
			s.barrel = _anchor_path(go, s, "Barrel", Vector3(0, 0.3, 0))
			s.cooldown = _anchor_path(go, s, "Progress Bar")
		elif b is RocketBehaviour:
			var r := _add(go, "RocketLauncher")
			r.rocketSpawn = _anchor_path(go, r, "RocketSpawn", Vector3(0, 1.5, 0))
			r.destroyOnFirstShot = _anchor_path(go, r, "RocketModel")
		elif b is FlakBehaviour:
			var f := _add(go, "Flak")
			f.guns = _anchor_path(go, f, "Guns")
		elif b is ShieldBehaviour:
			var sh := _add(go, "ShieldGenerator")
			sh.shieldMeshRenderer = _anchor_path(go, sh, "Shield")
		elif b is WallBehaviour:
			_add(go, "Wall")
	_apply_params(go, def)


## Copies the def's numbers onto the components (also used by reload()).
func _apply_params(go: Node3D, def: BuildingDef) -> void:
	for b in def.behaviours:
		if b is CannonBehaviour:
			var s := U.comp(go, "Shooter")
			if s == null:
				continue
			s.projectile = b.projectile
			s.damage = b.damage
			s.minRange = b.min_range
			s.maxDesiredRange = b.max_range
			s.secondsBetweenShots = b.reload * Indicators.reload_scale
			s.gravity = b.gravity
			s.ascendingPart = b.ascending_part
			s.turns = b.turns
			s.supplyNeeded = def.supply_needed()
			s.refresh()
		elif b is RocketBehaviour:
			var r := U.comp(go, "RocketLauncher")
			if r == null:
				continue
			r.projectile = b.projectile
			r.damage = b.damage
			r.minRange = b.min_range
			r.maxDesiredRange = b.max_range
			r.secondsBetweenShots = b.reload
			r.initialDelay = b.initial_delay
			r.supplyNeeded = def.supply_needed()
		elif b is FlakBehaviour:
			var f := U.comp(go, "Flak")
			if f == null:
				continue
			f.shootRange = b.shoot_range
			f.lookRange = b.look_range
			f.secondsBtwSalvos = b.salvo_interval
			f.supplyNeeded = def.supply_needed()
		elif b is ShieldBehaviour:
			var sh := U.comp(go, "ShieldGenerator")
			if sh == null:
				continue
			sh.range = b.radius
			sh.maxDamageAbsorb = b.max_absorb
			sh.secondsToReset = b.reset_time
			sh.supplyNeeded = def.supply_needed()
			sh.refresh()
	var sup := U.comp(go, "SupplyBuilding")
	if sup != null:
		sup.supply = def.produces.get("supply", 0.0)


## Spawns a projectile of `pdef` under parent at pos; returns its component.
func spawn_projectile(pdef: ProjectileDef, parent: Node, pos: Vector3, basis: Basis) -> Node:
	var go: Node3D = pdef.model.instantiate()
	Art.attach(go, pdef.resource_path.get_file().get_basename(), 0.0)
	for n in PROJECTILE_COMPONENTS:
		var old := go.get_node_or_null(NodePath(n))
		if old != null:
			go.remove_child(old)
			old.free()
	var script_name: String = ["Projectile", "ClusterBomb", "ProjectileStraightFlight", "S2SRocket"][pdef.kind]
	var c := _add(go, script_name)
	c.velocity = pdef.velocity
	c.burnTime = pdef.burn_time
	c.stunTime = pdef.stun_time
	c.splashRange = pdef.splash_range
	c.smokePuff = pdef.smoke_puff
	c.tileDestroyer = pdef.tile_destroyer
	if pdef.kind != ProjectileDef.Kind.STRAIGHT:
		var body := _first_model_child(go)
		c.body = NodePath("../" + str(go.get_path_to(body))) if body else NodePath()
	if pdef.kind == ProjectileDef.Kind.SHELL or pdef.kind == ProjectileDef.Kind.CLUSTER:
		c.rotates = pdef.rotates
	if pdef.kind == ProjectileDef.Kind.CLUSTER:
		c.submunition = pdef.submunition
		c.numSubmunitions = pdef.cluster_count
		c.clusterRange = pdef.cluster_range
	parent.add_child(go)
	go.global_transform = Transform3D(basis * go.transform.basis, pos)
	_add_trail(go)
	return c


## The white ribbon trailing every projectile (I77): the flight path as a fading LineRenderer
## ribbon (the compatibility renderer has no particle trails).
func _add_trail(go: Node3D) -> void:
	var t: TrailLine = TrailLine.new()
	t.name = "Trail"
	go.add_child(t)


func _add(go: Node3D, script_name: String) -> Node:
	var n := Node.new()
	n.name = script_name
	n.set_script(load(C + script_name + ".gd"))
	go.add_child(n)
	return n


## Path from component c to the model node called `anchor_name`. When the
## model has none and `fallback` is given, an empty node is created there.
func _anchor_path(go: Node3D, c: Node, anchor_name: String, fallback = null) -> NodePath:
	var a := go.find_child(anchor_name, true, false)
	if a == null and fallback != null:
		var n := Node3D.new()
		n.name = anchor_name
		go.add_child(n)
		n.position = fallback
		a = n
	if a == null:
		return NodePath()
	return NodePath(str(c.get_path_to(a)))


## A hand piece shows the owner's wall block at each of its cells, walkways running between them, so the piece
## looks like what it places.
func _add_piece_cells(go: Node3D, def: BuildingDef, owner) -> void:
	var block: BuildingDef = get_def("wall")
	for c in def.piece:
		var cell: Node3D = block.model.instantiate()
		cell.position = Vector3(c.x, 0.0, -c.y)
		go.add_child(cell)
	WallComp.paint_piece(go, owner, def.piece)


func _first_model_child(go: Node3D) -> Node3D:
	for ch in go.get_children():
		if ch is Node3D:
			return ch
	return null

