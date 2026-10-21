extends "res://scripts/components/PlayerController.gd"
## Port of AI.cs: computer player. Rings castles and yards with whatever piece it holds, builds
## guns inside its closed ground and shoots at what the rules make worth shooting. Once nothing
## is left to ring or claim it walls the largest room it can toward the castles it does not
## hold: territory for its guns, staging for a claim once the walls before it fall (I76).

const RingPlan = preload("res://scripts/RingPlan.gd")

## Reaction time: the pause after every shot, the aim move and the click. Must stay above 0.
var secondsBetweenShots := 0.5
## The pause after every build action (a placed piece or gun, a stacked block, a dropped piece):
## a human turns and places a piece slower than it fires a loaded gun. Must stay above 0.
var secondsBetweenBuilds := 1.0
## When nothing could be done, wait this long before trying again
var secondsIdleRetry := 0.15
var nextAction := 0.0
## Castles the AI rings to claim at once
var claimsAtOnce := 3
## RingPlan per live castle, the AI's and the others'
var castlePlans := {}
## RingPlans of the 3x3 yards the AI walls for its guns
var yards: Array = []
## RingPlans of the free rooms the AI walls for territory once castles, yards and claims are
## done: the largest site that fits, sited toward a castle it does not hold. A ring that stands
## but does not seal is replaced (I76)
var rooms: Array = []
## The plans the held piece serves, in order: own castles, yards, claims
var activePlans: Array = []
## activePlans split by tier: [own castles, yards, claims]
var tiers: Array = [[], [], []]
var _plansStale := true
var _plansTime := -1.0
var enemyPlayers = null
## A dormant AI never acts (sandbox: test a build against a stationary enemy).
var dormant := false
## What the AI shoots at: "auto" (enemy guns, then castles, then walls),
## "walls", "guns", "castles", "supply" or "random"; the explicit modes fall
## back to walls when their pool is empty
var targetMode := "auto"


func is_ai() -> bool:
	return true


func update_point_and_tile_selected() -> void:
	pass


func manage_player_actions() -> void:
	if dormant:
		return
	if U.time > nextAction:
		if game.phase == game.Phase.BATTLE:
			search_and_fire_at_targets()
		else:
			execute_building_plan()


func reach_changed() -> void:
	super.reach_changed()
	_plansStale = true


# ------------------------------------------------------------------ plans
## Refreshes the plans when the board changed under the AI or two seconds passed (the enemy builds too).
func update_plans() -> void:
	if not _plansStale and U.time - _plansTime < 2.0:
		return
	_plansStale = false
	_plansTime = U.time
	var own: Array = []
	var ranked: Array = []
	for c in castlePlans.keys():
		if not U.alive(c) or c.is_ruin():
			castlePlans.erase(c)
	for c in map.castles:
		if not U.alive(c) or c.is_ruin():
			continue
		if not castlePlans.has(c):
			castlePlans[c] = RingPlan.new(self, c)
		var plan = castlePlans[c]
		if c.owner() == self:
			own.append(plan)
		elif _claimable(c):
			ranked.append([_anchor_distance(plan.centre()), plan])
	for plan in own + yards + rooms:
		plan.refresh()
	yards = yards.filter(func(y): return y.possible())
	rooms = rooms.filter(func(r): return r.possible() and (r.done or not r.gaps.is_empty()))
	ranked.sort_custom(func(a, b): return a[0] < b[0])
	var claims: Array = []
	var open := 0
	for r in ranked:
		r[1].refresh()
		if r[1].possible():
			claims.append(r[1])
			if not r[1].closed():
				open += 1
			if open >= claimsAtOnce:
				break
	var need: int = partsCap - parts_used()
	if need > 0 and not yards.any(func(y): return not y.closed()) and gun_room() < need:
		var avoid := {}
		for plan in own + yards + claims + rooms:
			avoid.merge(plan.inside)
		var y = _pick_yard(avoid)
		if y != null:
			yards.append(y)
	# nothing left to ring or claim: the largest room that fits, sited toward a castle not the
	# AI's — ground for the guns a bigger cap will pay for, and a step toward a later claim (I76)
	if (own + yards + claims).all(func(p): return p.closed()) and rooms.all(func(r): return r.closed()):
		var avoid := {}
		for plan in own + yards + claims + rooms:
			avoid.merge(plan.inside)
		for s in [5, 3]:
			var room = _pick_room(avoid, s, true)
			if room != null:
				rooms.append(room)
				break
	tiers = [own, yards, claims, rooms]
	activePlans = own + yards + claims + rooms


## A castle worth ringing: not the AI's, and not sitting in another player's closed ring.
func _claimable(c) -> bool:
	var cc: Vector2i = map.tile_index_at(c.go.global_position)
	var t = map.tiles[cc.x][cc.y]
	return not (map.is_tile_enclosed(cc.x, cc.y) and t.ringOwner != null and t.ringOwner != self)


## Chebyshev distance from k to the nearest own wall or own castle tile.
func _anchor_distance(k: Vector2i) -> int:
	var d := RingPlan.INF
	for t in wallTiles:
		d = mini(d, maxi(absi(t.idxX - k.x), absi(t.idxZ - k.y)))
	for c in map.castles:
		if U.alive(c) and not c.is_ruin() and c.owner() == self:
			for t in c.my_tiles():
				d = mini(d, maxi(absi(t.idxX - k.x), absi(t.idxZ - k.y)))
	return d


func _castle_distance(k: Vector2i) -> int:
	var d := RingPlan.INF
	for c in map.castles:
		if U.alive(c) and not c.is_ruin() and c.owner() == self:
			var cc: Vector2i = map.tile_index_at(c.go.global_position)
			d = mini(d, maxi(absi(cc.x - k.x), absi(cc.y - k.y)))
	return d


## Chebyshev distance from k to the nearest live castle the player does not hold.
func _enemy_castle_distance(k: Vector2i) -> int:
	var d := RingPlan.INF
	for c in map.castles:
		if U.alive(c) and not c.is_ruin() and c.owner() != self:
			var cc: Vector2i = map.tile_index_at(c.go.global_position)
			d = mini(d, maxi(absi(cc.x - k.x), absi(cc.y - k.y)))
	return d


## A free tile in reach inside the AI's closed ground.
func _gun_spot(t) -> bool:
	return t.is_free() and in_reach(t.idxX, t.idxZ) and map.is_tile_enclosed(t.idxX, t.idxZ) \
			and t.ringOwner == self


func gun_room() -> int:
	var n := 0
	for x in map.sizeX:
		for z in map.sizeZ:
			if _gun_spot(map.tiles[x][z]):
				n += 1
	return n


## The gun yard: a 3x3 of free open ground.
func _pick_yard(avoid: Dictionary):
	return _pick_room(avoid, RingPlan.YARD)


## The s x s of free open ground outside every plan whose ring shares the most own walls, nearest
## an own castle on ties; the four best by that proxy are costed for real. A territory room
## (`enemy_first`) instead takes the site nearest a castle the player does not hold, so its
## walls walk toward the castles a later claim may take (I76).
func _pick_room(avoid: Dictionary, s: int, enemy_first := false):
	var cands: Array = []
	for x in range(1, map.sizeX - s):
		for z in range(1, map.sizeZ - s):
			if not _yard_free(x, z, avoid, s):
				continue
			var shared := 0
			var reached := false
			for bx in range(x - 1, x + s + 1):
				for bz in range(z - 1, z + s + 1):
					if bx != x - 1 and bx != x + s and bz != z - 1 and bz != z + s:
						continue
					var t = map.tiles[bx][bz]
					if t.isWall and map.get_mini(bx, bz) == playerID:
						shared += 1
					reached = reached or in_reach(bx, bz)
			if reached:
				var k := Vector2i(x + s / 2, z + s / 2)
				cands.append([shared, _castle_distance(k), _enemy_castle_distance(k), Vector2i(x, z)])
	if enemy_first:
		cands.sort_custom(func(a, b): return a[2] < b[2] if a[2] != b[2] else a[0] > b[0])
	else:
		cands.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
	var best = null
	var costed := 0
	for c in cands:
		var plan = RingPlan.new(self, null, c[3], s)
		plan.refresh()
		costed += 1
		if not plan.possible():
			continue
		if enemy_first:
			return plan  # the first buildable site down the ranking is the closest one to the enemy
		if best == null or plan.cost < best.cost:
			best = plan
		if costed >= 4:
			break
	return best


func _yard_free(x: int, z: int, avoid: Dictionary, s: int) -> bool:
	for dx in s:
		for dz in s:
			var t = map.tiles[x + dx][z + dz]
			if U.alive(t.structure) or t.water or t.disabled or map.is_tile_enclosed(x + dx, z + dz) \
					or avoid.has(Vector2i(x + dx, z + dz)):
				return false
	return true


# --------------------------------------------------------------- building
func execute_building_plan() -> void:
	var did := try_build_gun()
	if not did:
		did = try_build_next_wall()
	if not did:
		did = try_stack_next_wall()
	if not did and U.alive(nextWall):
		drop(nextWall, true)
		did = true
	nextAction = U.time + (secondsBetweenBuilds if did else secondsIdleRetry)


## The held building goes inside the AI's closed ground, an own castle's first, then a yard's, then
## any; it waits in hand until a free tile is there, so the check never burns it, and over the parts
## cap it waits for a gun to die.
func try_build_gun() -> bool:
	if not U.alive(nextBuilding) or over_parts_cap(nextBuilding):
		return false
	update_plans()
	for plan in activePlans:
		for k in plan.inside:
			if _gun_spot(map.tiles[k.x][k.y]):
				build_next_building(map.tiles[k.x][k.y])
				return true
	for x in map.sizeX:
		for z in map.sizeZ:
			if _gun_spot(map.tiles[x][z]):
				build_next_building(map.tiles[x][z])
				return true
	return false


## Places the held piece where it covers the most gap tiles of a plan, own castles first, then
## yards, then claims; with no gap in reach the piece walks towards the nearest one.
func try_build_next_wall() -> bool:
	if not U.alive(nextWall):
		return false
	update_plans()
	var bb := U.comp(nextWall, "BuildingBlock")
	for tier in tiers:
		var fit = _best_cover(bb, tier)
		if fit != null:
			_place(bb, fit)
			return true
	for plan in activePlans:
		if not plan.gaps.is_empty():
			var fit = _best_approach(bb, plan)
			if fit != null:
				_place(bb, fit)
				return true
	return false


func _place(bb, fit: Array) -> void:
	for i in fit[0]:
		bb.rotate_clockwise()
	build_next_wall(fit[1])


## A cell may not land off the map or inside the plan it serves.
func _forbidden(t: Vector2i, plan) -> bool:
	return t.x < 0 or t.y < 0 or t.x >= map.sizeX or t.y >= map.sizeZ or plan.inside.has(t)


## [turns, anchor tile] covering the most gaps of one of `plans`, the fewest cells off the ring on
## ties; null when no placement covers a gap. Leaves the piece turned as it was.
func _best_cover(bb, plans: Array):
	var best = null
	var best_cover := 0
	var best_spill := 0
	for turns in 4:
		for plan in plans:
			for g in plan.gaps:
				for c in bb.cells:
					var a: Vector2i = g - c
					var cover := 0
					var spill := 0
					var ok := true
					for c2 in bb.cells:
						var t: Vector2i = a + c2
						if _forbidden(t, plan):
							ok = false
							break
						if plan.gaps.has(t):
							cover += 1
						elif not plan.ring.has(t):
							spill += 1
					if not ok or cover < best_cover or (cover == best_cover and spill >= best_spill):
						continue
					if can_place_piece(map.tiles[a.x][a.y]):
						best = [turns, map.tiles[a.x][a.y]]
						best_cover = cover
						best_spill = spill
		bb.rotate_clockwise()
	return best


## [turns, anchor tile] in reach with a cell nearer the plan's nearest gap than any own anchor is;
## null when the piece cannot get nearer. Leaves the piece turned as it was.
func _best_approach(bb, plan):
	var d0: int = RingPlan.INF
	var near := Vector2i.ZERO
	for g in plan.gaps:
		var d := _anchor_distance(g)
		if d < d0:
			d0 = d
			near = g
	if d0 == RingPlan.INF:
		return null
	var best = null
	var best_d := d0
	for turns in 4:
		for x in range(maxi(near.x - d0, 0), mini(near.x + d0, map.sizeX - 1) + 1):
			for z in range(maxi(near.y - d0, 0), mini(near.y + d0, map.sizeZ - 1) + 1):
				var a := Vector2i(x, z)
				var d: int = RingPlan.INF
				var ok := true
				for c in bb.cells:
					var t: Vector2i = a + c
					if _forbidden(t, plan):
						ok = false
						break
					d = mini(d, maxi(absi(t.x - near.x), absi(t.y - near.y)))
				if ok and d < best_d and can_place_piece(map.tiles[x][z]):
					best = [turns, map.tiles[x][z]]
					best_d = d
		bb.rotate_clockwise()
	return best


## A single block with nothing to cover stacks on a ring wall of an own castle, then of a yard,
## then anywhere own.
func try_stack_next_wall() -> bool:
	if not U.alive(nextWall) or U.comp(nextWall, "BuildingBlock").cells.size() != 1:
		return false
	update_plans()
	for tier in tiers.slice(0, 2):
		var spots: Array = []
		for plan in tier:
			for k in plan.ring:
				if can_stack_on(map.tiles[k.x][k.y]):
					spots.append(map.tiles[k.x][k.y])
		if not spots.is_empty():
			stack_wall(spots[U.rint(0, spots.size())])
			return true
	for t in wallTiles:
		if can_stack_on(t):
			stack_wall(t)
			return true
	return false


# --------------------------------------------------------------- shooting
## One shot per action: the guns in random order, each at the first target in its reach, and the
## first loaded one fires. A gun still reloading stays aimed at its target.
func search_and_fire_at_targets() -> void:
	nextAction = U.time + secondsIdleRetry
	if enemyPlayers == null:
		enemyPlayers = []
		for p in game.players:
			if p.playerID != playerID:
				enemyPlayers.append(p)
	if enemyPlayers.is_empty():
		return
	_random_shuffle(activeCannons)
	var targets := aquire_targets(enemyPlayers[U.rint(0, enemyPlayers.size())])
	for gun in activeCannons:
		for t in targets:
			if not gun.can_reach(gun.go.global_position.distance_to(t.go.global_position)):
				continue
			if gun.try_shoot(t.go.global_position, t):
				nextAction = U.time + secondsBetweenShots
				return
			break


func _random_shuffle(arr: Array) -> void:
	var length := arr.size()
	for i in range(0, length - 1):
		var hold = arr[i]
		var r := U.rint(i, length)
		arr[i] = arr[r]
		arr[r] = hold


## The tiles to shoot at, best first. "auto": the enemy's guns (they shoot back), then the castles
## the enemy holds, the nearest to ruin first (they decide the game), then its walls, the most
## walled-in first. An explicit mode leads with its own pool, and the walls follow it.
func aquire_targets(enemy) -> Array:
	var out: Array = []
	for mode in (["guns", "castles"] if targetMode == "auto" else [targetMode]):
		var pool := _target_pool_for(mode, enemy)
		if mode != "castles":
			_random_shuffle(pool)
		out.append_array(pool)
	var walls: Array = []
	for t in enemy.wallTiles:
		if U.alive(t):
			walls.append([t.count_neighbouring_walls(), t])
	walls.sort_custom(func(a, b): return a[0] > b[0])
	for w in walls:
		out.append(w[1])
	return out


## The tiles of one target mode; "walls" has none here, the walls follow every list.
func _target_pool_for(mode: String, enemy) -> Array:
	var keys: Array = []
	match mode:
		"guns":
			keys = enemy.cannons.keys() + enemy.supports.keys()
		"castles":
			# the castles the enemy holds, the nearest to ruin first: the AI finishes what it started.
			# A neutral castle is one to ring and claim, not to shoot; a ruin decides nothing any more.
			var held: Array = []
			for c in map.castles:
				if U.alive(c.go) and not c.is_ruin() and c.owner() == enemy:
					held.append(c)
			held.sort_custom(func(a, b): return U.comp(a.go, "BuildingBlock").health < U.comp(b.go, "BuildingBlock").health)
			var seats: Array = []
			for c in held:
				var centre: Vector2i = map.tile_index_at(c.go.global_position)
				seats.append(map.tiles[centre.x][centre.y])
			return seats
		"supply":
			keys = enemy.supplies.keys()
		"random":
			var out: Array = []
			for x in map.sizeX:
				for z in map.sizeZ:
					if map.get_mini(x, z) == enemy.playerID:
						out.append(map.tiles[x][z])
			return out
	var tiles: Array = []
	for k in keys:
		tiles.append(map.tiles[k.x][k.y])
	return tiles
