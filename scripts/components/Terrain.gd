extends "res://scripts/components/Component.gd"
## Port note: no Unity original. One terrain feature (I90): the mass standing on `tiles`,
## set as the structure of every tile it covers, so every placement rule refuses those
## tiles until its columns fall. The mass is one merged mesh, a blanket draped over the
## standing columns (I100): hills wear the board's grass green with gentle slopes, rocks
## the warm greys of the boulder family with jagged crests and steep skirts. A shell
## shatters the top block of the tile it hits, the column steps down and the drape is
## re-cut for the shorter stack, the tile frees when its last block goes - the killing
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


## Registers one tile's column of blocks and their health.
func set_column(tile, height: int) -> void:
	columns[tile] = height
	_hp[tile] = []
	for i in height:
		_hp[tile].append(HEALTH_PER_TILE)
		health += HEALTH_PER_TILE


## Cuts the blanket for the standing columns: one merged, flat-shaded mesh. Corner heights
## pool the cells they touch - hills average them into gentle slopes, rocks take the
## tallest for a crag - and deterministic roughness keys on board position, so a re-cut
## after a block shatters keeps every other crest it had.
func drape() -> void:
	var cells := {}
	for t in columns:
		cells[Vector2i(t.idxX, t.idxZ)] = columns[t]
	if cells.is_empty():
		return
	_corners.clear()
	var lo := Vector2i(map.sizeX, map.sizeZ)
	var hi := Vector2i.ZERO
	for c in cells:
		lo = lo.min(c)
		hi = hi.max(c)
	for i in range(lo.x, hi.x + 2):
		for j in range(lo.y, hi.y + 2):
			var touched := 0
			var pooled := 0.0
			var tallest := 0.0
			for c in [Vector2i(i - 1, j - 1), Vector2i(i, j - 1), Vector2i(i - 1, j), Vector2i(i, j)]:
				if cells.has(c):
					touched += 1
					pooled += cells[c]
					tallest = maxf(tallest, cells[c])
			if touched > 0:
				_corners[Vector2i(i, j)] = (pooled / touched if sort != "rock" else tallest) * LEVEL
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hill := sort == "hill"
	var peak := 0.0
	for c in cells:
		peak = maxf(peak, cells[c])
	peak *= LEVEL
	for c in cells:
		var p: Vector3 = map.tile_position(c.x, c.y) - go.position
		var top := [_corn(c), _corn(Vector2i(c.x + 1, c.y)), _corn(Vector2i(c.x, c.y + 1)), _corn(Vector2i(c.x + 1, c.y + 1))]
		var steps := 2 if not hill else 3
		for u in steps:
			for v in steps:
				var a := _lattice(p, top, Vector2(u, v) / steps, hill, peak)
				var b := _lattice(p, top, Vector2(u + 1, v) / steps, hill, peak)
				var c2 := _lattice(p, top, Vector2(u + 1, v + 1) / steps, hill, peak)
				var d := _lattice(p, top, Vector2(u, v + 1) / steps, hill, peak)
				_face(st, a, b, c2, peak)
				_face(st, a, c2, d, peak)
		for side in [[Vector2(0, 0), Vector2(1, 0), Vector2(1, 0)], [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], [Vector2(1, 1), Vector2(0, 1), Vector2(-1, 0)], [Vector2(0, 1), Vector2(0, 0), Vector2(0, -1)]]:
			if cells.has(c + Vector2i(side[2])):
				continue  # a neighbour stands here, no wall between them
			var near := _lattice(p, top, side[0], hill, peak)
			var far := _lattice(p, top, side[1], hill, peak)
			var foot := _tint(0.0, peak)
			var wall: Array = [near, far,
				{"pos": far["pos"] - Vector3(0, far["pos"].y + 0.25, 0), "tint": foot},
				{"pos": near["pos"] - Vector3(0, near["pos"].y + 0.25, 0), "tint": foot}]
			# two triangles down to the ground, matching the top edge's roughness, wound so
			# the wall faces outward - the other way round, culling hides every skirt and the
			# blanket floats (Sebastian saw it in play, 2026-10-23)
			_face(st, wall[0], wall[2], wall[1], peak)
			_face(st, wall[0], wall[3], wall[2], peak)
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


## One lattice point of a cell's top, at fraction f of its span: the blanket between its
## corners, roughened - a little for a hill, jagged for a rock - and its colour.
func _lattice(p: Vector3, top: Array, f: Vector2, hill: bool, peak: float) -> Dictionary:
	var y0: float = top[0] + (top[1] - top[0]) * f.x + (top[2] - top[0]) * f.y + (top[0] - top[1] - top[2] + top[3]) * f.x * f.y
	var q := Vector2(p.x + f.x - 0.5, p.z - f.y + 0.5)  # board z mirrors tile z
	var rough := _noise(q + Vector2(go.position.x, go.position.z))
	var y: float = y0 + rough * (0.03 if hill else 0.12)
	var pos := Vector3(q.x + (0.0 if hill else rough * 0.05), y, q.y + (0.0 if hill else _noise(Vector2(q.y, q.x)) * 0.05))
	return {"pos": pos, "tint": _tint(y, peak)}


## Triangle of the drape: position, a flat normal placeholder (generate_normals fills it)
## and the vertex colour.
func _face(st: SurfaceTool, a, b, c, peak: float) -> void:
	for v in [a, b, c]:
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
## a debris cube flies from its spot and the drape is re-cut without it.
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
		_debris(tile, columns[tile], from)
		if columns[tile] == 0:
			_free_tile(tile, hit)
	if fell:
		drape()
	Sound.play("crumble" if fell else "hit_wall")


## The block that just left column `tile`'s step `over` flies apart: a family-coloured
## cube crumbles in its place, the drape's re-cut does the rest.
func _debris(tile, over: int, from: Vector3) -> void:
	var cube := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.94, LEVEL, 0.94)
	cube.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _tint((over + 0.5) * LEVEL, 3 * LEVEL)
	cube.material_override = mat
	map.go.add_child(cube)
	cube.position = Vector3(tile.go.position.x, go.position.y + (over + 0.5) * LEVEL - 0.05, tile.go.position.z)
	Crumble.crumble(cube, from)


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
		if kill_damage > 0.0:
			t.damage_ground(kill_damage)
		for i in columns.get(t, 0):
			_debris(t, i, from)
	U.destroy(go)
	if map.game != null:
		for q in map.game.players:
			q.reach_changed()
