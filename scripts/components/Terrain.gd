extends "res://scripts/components/Component.gd"
## Port note: no Unity original. One terrain feature (I90): the mass standing on `tiles`,
## set as the structure of every tile it covers, so every placement rule refuses those
## tiles until its columns fall. The mass is one merged mesh, a blanket draped over the
## standing columns (I100): hills wear the board's grass green with gentle slopes, rocks
## the warm greys of the boulder family with jagged crests and steep skirts. A shell
## shatters the top block of the tile it hits, the column steps down and the drape is
## re-cut for the shorter stack with the wound's lip crumbled, the tile frees when its
## last block goes - the killing
## blow also scarring the ground it frees (I74) - and the feature dies with its last
## column. Each family carries its break flag; a flag-off family absorbs every hit.

## What one block of feature mass costs to clear, the same a wall costs a shell.
const HEALTH_PER_TILE := 10.0
## One level's height: 0.75 plus the 0.1 a shore tile can sit below its feature stays
## under the 0.866 the 60-degree play camera can just see over, so a one-level drape
## never hides the tile behind it (I97's rule, kept for the blanket).
const LEVEL := 0.75
## Each family's break switch (Sebastian, 2026-10-22: "I want both to be destructible for
## now, but I might change it later, so keep a flag for each"): a flag-off family absorbs
## every hit the way the old stone did.
const HILL_BREAKS := true
const ROCK_BREAKS := true

## The families' colours (D21's palette, the boulder greys of the paint family D49): hills
## the grass green of open ground, rocks grey low to high with a dark grounding band.
const HILL_GREEN := Color("8fbf3c")
const ROCK_LOW := Color("7d7364")
const ROCK_HIGH := Color("a89d8b")
const ROCK_FOOT := Color("6b6357")

var map = null
var sort := "rock"
var tiles: Array = []
## One tile's standing blocks, ground up; the number steps down as blocks shatter.
var columns := {}
var destructible := true
var health := 0.0
var _hp := {}  # tile -> Array, block health parallel to its column
var _mass: MeshInstance3D
## The drape the mesh was cut from: corner (x, z) sits at board position (x - 0.5, z - 0.5),
## so a tile's four corners are itself and its north, east and north-east neighbours.
var _corners := {}
## A hill's rim rounding: corner lattice point -> board-space offset, relaxed over the
## feature's outline so corners pull in and straight runs stay.
var _disp := {}
## The cells a shell has bitten (I113): a re-cut sags every corner pooling a wounded cell,
## so the hole's lip crumbles instead of reading as a carved cube.
var _wounds := {}


## Registers one tile's column of blocks and their health.
func set_column(tile, height: int) -> void:
	columns[tile] = height
	_hp[tile] = []
	for i in height:
		_hp[tile].append(HEALTH_PER_TILE)
		health += HEALTH_PER_TILE


## Steps a column down to `to` blocks without a shell's noise, for the generator's sight
## pass; the caller re-cuts the drape once the feature settles.
func lower(tile, to: int) -> void:
	var hps: Array = _hp[tile]
	while columns[tile] > to:
		hps.pop_back()
		columns[tile] -= 1
		health -= HEALTH_PER_TILE


## Cuts the blanket for the standing columns: one merged, flat-shaded mesh. Corner heights
## pool the cells they touch - hills average them into gentle slopes, rocks take the
## tallest for a crag - and deterministic roughness keys on board position, so a re-cut
## after a block shatters keeps every other crest it had. A hill's pooled corners then
## dome (Sebastian, 2026-10-23: "less box more hill"): the rim eases toward the ground and
## a smoothstep rounds the climb, so the foot rises from the board and the crest shoulder
## curves while the steep plane stays in the middle. The outline leaves the grid as
## it rises (Sebastian, 2026-10-23: "the very ground layer of vertices can still follow
## the grid layout, the first floor should already have variation"): feet stand on the
## tile grid, a rock's first story bulges off it in smooth swells and a hill's rim rounds
## its corners - and every wall runs through the rim's own lattice points, so the higher
## stories sit tight on the walls with no gaps between them.
func drape() -> void:
	var cells := {}
	for t in columns:
		cells[Vector2i(t.idxX, t.idxZ)] = columns[t]
	if cells.is_empty():
		return
	_corners.clear()
	var lo := Vector2i(map.sizeX, map.sizeZ)
	var hi := Vector2i.ZERO
	var peak_cells := 0
	for c in cells:
		lo = lo.min(c)
		hi = hi.max(c)
		peak_cells = maxi(peak_cells, cells[c])
	for i in range(lo.x, hi.x + 2):
		for j in range(lo.y, hi.y + 2):
			var touched := 0
			var pooled := 0.0
			var tallest := 0.0
			var wounded := false
			for c in [Vector2i(i - 1, j - 1), Vector2i(i, j - 1), Vector2i(i - 1, j), Vector2i(i, j)]:
				if cells.has(c):
					touched += 1
					pooled += cells[c]
					tallest = maxf(tallest, cells[c])
				# a cell bitten to nothing still wounds: its corner is the hole's rim
				if _wounds.has(c):
					wounded = true
			if touched > 0:
				var h: float = tallest if sort == "rock" else pooled / touched
				if sort != "rock":
					# a hill domes (Sebastian, 2026-10-23: "less box more hill"): the rim
					# eases toward the ground so the foot rises from the board instead of
					# jumping to the first story, and the smoothstep rounds the climb -
					# gentle ends, the steep plane he allows kept in the middle. A single
					# story eases less: the mass has no climb above it and a blocked tile
					# must still read as standing ground
					var rim := 0.75 if peak_cells == 1 else 0.3
					h *= rim if touched < 4 else 1.0
					var t: float = clampf(h / peak_cells, 0.0, 1.0)
					h = peak_cells * (t * t * (3.0 - 2.0 * t))
				if wounded:
					# the lip of a shot-out block crumbles: the corner sags by a bite keyed
					# on its place, deterministic as the roughness, so the re-cut reads as
					# broken ground and every later re-cut keeps the same bite
					h = maxf(0.0, h - absf(_noise(Vector2(i, j) + Vector2(go.position.x, go.position.z) + Vector2(97.3, 45.1))) * 0.28)
				_corners[Vector2i(i, j)] = h * LEVEL
	if sort == "hill":
		_outline_disp(cells)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hill := sort == "hill"
	var peak := peak_cells * LEVEL
	for c in cells:
		var p: Vector3 = map.tile_position(c.x, c.y) - go.position
		var top := [_corn(c), _corn(Vector2i(c.x + 1, c.y)), _corn(Vector2i(c.x, c.y + 1)), _corn(Vector2i(c.x + 1, c.y + 1))]
		var steps := 2 if not hill else 3
		for u in steps:
			for v in steps:
				var a := _lattice(p, top, Vector2(u, v) / steps, hill, peak, Vector2(c.x, c.y) + Vector2(u, v) / steps)
				var b := _lattice(p, top, Vector2(u + 1, v) / steps, hill, peak, Vector2(c.x, c.y) + Vector2(u + 1, v) / steps)
				var c2 := _lattice(p, top, Vector2(u + 1, v + 1) / steps, hill, peak, Vector2(c.x, c.y) + Vector2(u + 1, v + 1) / steps)
				var d := _lattice(p, top, Vector2(u, v + 1) / steps, hill, peak, Vector2(c.x, c.y) + Vector2(u, v + 1) / steps)
				_face(st, a, b, c2, peak)
				_face(st, a, c2, d, peak)
		# each side: the neighbour that hides the wall between the cells - the offset must
		# match the edge (S, E, N, W), a rotated pairing skips real outer walls and drapes
		# phantom ones inside the mass
		for side in [[Vector2(0, 0), Vector2(1, 0), Vector2(0, -1)], [Vector2(1, 0), Vector2(1, 1), Vector2(1, 0)], [Vector2(1, 1), Vector2(0, 1), Vector2(0, 1)], [Vector2(0, 1), Vector2(0, 0), Vector2(-1, 0)]]:
			if cells.has(c + Vector2i(side[2])):
				continue  # a neighbour stands here, no wall between them
			# the wall runs through the rim's own lattice points, feet on the grid: the
			# skirt is sewn to the top edge at every fraction, the ground ring keeps the
			# tile layout, and the battered strip between them already swells off the grid
			var foot_tint := _tint(0.0, peak)
			var rim := []
			var feet := []
			for k in steps + 1:
				var f: Vector2 = side[0].lerp(side[1], float(k) / steps)
				rim.append(_lattice(p, top, f, hill, peak, Vector2(c.x, c.y) + f))
				var g := Vector2(p.x + f.x - 0.5, p.z - f.y + 0.5)  # the undisplaced grid point
				feet.append({"pos": Vector3(g.x, -0.25, g.y), "tint": foot_tint})
			for k in steps:
				_face(st, rim[k], feet[k + 1], rim[k + 1], peak)
				_face(st, rim[k], feet[k], feet[k + 1], peak)
	st.generate_normals()
	var mesh := st.commit()
	if _mass == null:
		_mass = MeshInstance3D.new()
		_mass.name = "Mass"
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 1.0
		_mass.material_override = mat
		go.add_child(_mass)
	_mass.mesh = mesh


func _corn(c: Vector2i) -> float:
	return _corners.get(c, 0.0)


## One lattice point of a cell's top, at fraction f of its span and corner-space position
## b: the blanket between its corners, roughened - a little for a hill, jagged for a rock -
## its outline loosened off the grid as it rises, and its colour.
func _lattice(p: Vector3, top: Array, f: Vector2, hill: bool, peak: float, b: Vector2) -> Dictionary:
	var y0: float = top[0] + (top[1] - top[0]) * f.x + (top[2] - top[0]) * f.y + (top[0] - top[1] - top[2] + top[3]) * f.x * f.y
	var q := Vector2(p.x + f.x - 0.5, p.z - f.y + 0.5)  # board z mirrors tile z
	var rough := _noise(q + Vector2(go.position.x, go.position.z))
	var y: float = y0 + rough * (0.03 if hill else 0.12)
	var off := Vector2.ZERO
	if hill:
		var d: Vector2 = _disp_at(b)  # board z mirrors: world z runs against board z
		# the rounding cuts in as the mass rises: the foot stays wide on the grid, the
		# crest narrows (Sebastian, 2026-10-23: "cut into the pieces and narrow them down")
		off = Vector2(d.x, -d.y) * clampf(y0 / peak, 0.0, 1.0)
	else:
		# a rock's outline swells off the grid through the first story - smooth swells, the
		# per-point crag only above it, the ground ring untouched
		var swell := clampf(y0 / LEVEL, 0.0, 1.0)
		off = Vector2(_noise(q * 0.33 + Vector2(11.3, 7.7)), _noise(q * 0.33 + Vector2(-5.1, 3.9))) * 0.10 * swell
		off += Vector2(rough, _noise(Vector2(q.y, q.x))) * 0.05 * clampf((y0 - LEVEL) / LEVEL, 0.0, 1.0)
	var pos := Vector3(q.x + off.x, y, q.y + off.y)
	return {"pos": pos, "tint": _tint(y, peak)}


## A hill's rim rounds its outline (Sebastian, 2026-10-23: "use a method that produces
## rounder edges") by relaxing the boundary lattice points toward their boundary
## neighbours: corners pull in, straight runs stay put. No extra vertices - the walls sew
## to the same points.
func _outline_disp(cells: Dictionary) -> void:
	_disp.clear()
	var outline := {}
	for i in _corners:
		var inside := 0
		for c in [Vector2i(i.x - 1, i.y - 1), Vector2i(i.x, i.y - 1), Vector2i(i.x - 1, i.y), Vector2i(i.x, i.y)]:
			if cells.has(c):
				inside += 1
		if inside > 0 and inside < 4:
			outline[i] = true
	for relax in 2:
		var next := {}
		for k in outline:
			var sum := Vector2.ZERO
			var n := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = k + d
				if outline.has(nb):
					sum += Vector2(nb) + _disp.get(nb, Vector2.ZERO)
					n += 1
			if n > 0:
				var own: Vector2 = Vector2(k) + _disp.get(k, Vector2.ZERO)
				next[k] = _disp.get(k, Vector2.ZERO) + (sum / n - own) * 0.2
		for k in next:
			_disp[k] = next[k]


## The hill rim's rounding at corner-space point b, bilinear between the corners.
func _disp_at(b: Vector2) -> Vector2:
	var i := Vector2i(floori(b.x), floori(b.y))
	var f := b - Vector2(i)
	var d00: Vector2 = _disp.get(i, Vector2.ZERO)
	var d10: Vector2 = _disp.get(i + Vector2i(1, 0), Vector2.ZERO)
	var d01: Vector2 = _disp.get(i + Vector2i(0, 1), Vector2.ZERO)
	var d11: Vector2 = _disp.get(i + Vector2i(1, 1), Vector2.ZERO)
	return d00.lerp(d10, f.x).lerp(d01.lerp(d11, f.x), f.y)


## Triangle of the drape: position, a flat normal placeholder (generate_normals fills it)
## and the vertex colour. Godot's front faces wind clockwise on screen - a face whose
## cross product (b-a)x(c-a) points at the viewer is culled - so every triangle emits
## reversed: tops and walls wound inward by cross-math, visible from outside.
func _face(st: SurfaceTool, a, b, c, peak: float) -> void:
	for v in [a, c, b]:
		st.set_color(v["tint"])
		st.add_vertex(v["pos"])


## Height colour: hills green with a light crown, rocks grey low to high with the dark
## grounding band at the foot.
func _tint(y: float, peak: float) -> Color:
	if sort == "hill":
		return HILL_GREEN.lerp(Color.WHITE, 0.04 + 0.10 * (y / peak if peak > 0.0 else 0.0))
	if y < LEVEL * 0.35:
		return ROCK_FOOT
	var t := clampf(y / peak, 0.0, 1.0) if peak > 0.0 else 0.0
	return ROCK_LOW.lerp(ROCK_HIGH, t)


## Deterministic roughness, -1 to 1: the same board position draws the same crest every
## re-cut, so the blanket only changes where a block went.
func _noise(q: Vector2) -> float:
	return fmod(absf(sin(q.x * 127.1 + q.y * 311.7 + 43758.5453)), 2.0) - 1.0


## The drape's height at any board position, world metres: the corners are feature-local,
## the feature stands on the ground it covers.
func surface_at(x: float, z: float) -> float:
	var i := floori(x + 0.5)
	var j := floori(z + 0.5)
	var fx := x + 0.5 - i
	var fz := z + 0.5 - j
	var a := _corn(Vector2i(i, j))
	var b := _corn(Vector2i(i + 1, j))
	var c := _corn(Vector2i(i, j + 1))
	var d := _corn(Vector2i(i + 1, j + 1))
	return go.position.y + a + (b - a) * fx + (c - a) * fz + (a - b - c + d) * fx * fz


## World height of the tile's drape, of its ground once the column is gone.
func top_of(tile) -> float:
	if not columns.has(tile):
		return tile.go.position.y
	var c := Vector2i(tile.idxX, tile.idxZ)
	var top := maxf(_corn(c), maxf(_corn(c + Vector2i(1, 0)), maxf(_corn(c + Vector2i(0, 1)), _corn(c + Vector2i(1, 1)))))
	return tile.go.position.y + top + (0.15 if sort == "rock" else 0.02)


## A shell breaks blocks from the top of the hit tile's column; damage left over falls to
## the block below. A block that survives cracks (the wall hit), one that dies shatters:
## chunks burst from its spot and the drape is re-cut without it, the wound's lip sagging
## as it crumbles.
func take_damage(damage: float, from := Vector3.INF, tile = null) -> void:
	if not destructible or tile == null or not columns.has(tile):
		Sound.play("hit_wall")
		return
	var hps: Array = _hp[tile]
	var fell := false
	while damage > 0.0 and columns[tile] > 0:
		var top: int = columns[tile] - 1
		var hit: float = minf(damage, hps[top])
		hps[top] -= hit
		damage -= hit
		if hps[top] > 0.0:
			break
		hps.pop_back()
		columns[tile] -= 1
		health -= HEALTH_PER_TILE
		fell = true
		_wounds[Vector2i(tile.idxX, tile.idxZ)] = true
		_debris(tile, columns[tile], from)
		if columns[tile] == 0:
			_free_tile(tile, hit)
			break   # the freed tile is gone from columns; the loop condition must not read it again
	if fell:
		drape()
	Sound.play("crumble" if fell else "hit_wall")


## The block that just left column `tile`'s step `over` breaks up the walls' way (I113):
## family-tinted chunks burst from the hole on a Crumble heap, land and sink. The mass has
## no rubble art, so the pieces are cut boxes, not fracture.py parts.
func _debris(tile, over: int, from: Vector3) -> void:
	var heap := Crumble.new()
	map.go.add_child(heap)
	heap.global_position = Vector3(tile.go.position.x, go.position.y + (over + 0.5) * LEVEL - 0.05, tile.go.position.z)
	Crumble._ground(get_tree(), go.position.y)
	var dir := (heap.global_position - from) * Vector3(1, 0, 1) if from.is_finite() else Vector3.ZERO
	if dir.length() < 0.1:
		dir = Vector3(Art._rng.randf() - 0.5, 0.0, Art._rng.randf() - 0.5)
	dir = dir.normalized()
	for i in 6:
		var body := RigidBody3D.new()
		body.physics_material_override = Crumble._stone_material()
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		var s := 0.14 + 0.20 * Art._rng.randf()
		box.size = Vector3(s * (0.7 + 0.6 * Art._rng.randf()), s, s * (0.7 + 0.6 * Art._rng.randf()))
		mi.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _tint((over + 0.5) * LEVEL, 3 * LEVEL)
		mi.material_override = mat
		body.add_child(mi)
		var shape := CollisionShape3D.new()
		shape.shape = Crumble._shape(box)
		shape.scale = Vector3.ONE * Crumble.SHRINK
		body.add_child(shape)
		heap.add_child(body)
		body.position = Vector3(Art._rng.randf() - 0.5, Art._rng.randf() - 0.5, Art._rng.randf() - 0.5) * Vector3(0.7, 0.5, 0.7)
		body.linear_velocity = dir * (1.5 + 2.5 * Art._rng.randf()) + Vector3.UP * (1.0 + 3.0 * Art._rng.randf()) + Crumble._scatter(0.8)
		body.angular_velocity = Crumble._scatter(8.0)
	heap._fade()


func _free_tile(tile, scar: float) -> void:
	columns.erase(tile)
	_hp.erase(tile)
	tiles.erase(tile)
	map.set_mini(tile.idxX, tile.idxZ, 0)
	tile.structure = null
	tile.player = null
	map.statesMap.update_tile(tile)
	if scar > 0.0:
		tile.damage_ground(scar)
	if tiles.is_empty():
		map.terrain_features.erase(go)
		U.destroy(go)
		return
	if map.game != null:
		for q in map.game.players:
			q.reach_changed()


## Frees every tile, crumbles a cube for every standing block away from the shot, then
## the feature goes.
func die(from := Vector3.INF, kill_damage := 0.0) -> void:
	Sound.play("crumble")
	map.terrain_features.erase(go)
	for t in tiles:
		map.set_mini(t.idxX, t.idxZ, 0)
		t.structure = null
		t.player = null
		map.statesMap.update_tile(t)
		t.destroy_decorations(from, true)
		if kill_damage > 0.0:
			t.damage_ground(kill_damage)
		for i in columns.get(t, 0):
			_debris(t, i, from)
	U.destroy(go)
	if map.game != null:
		for q in map.game.players:
			q.reach_changed()
