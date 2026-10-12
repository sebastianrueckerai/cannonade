extends "res://scripts/components/PlayerController.gd"
## Port of AI.cs: computer player. Plans rectangles of walls, builds guns and
## upgrades inside them and shoots at the walls of its enemies.

const BuildingPlan = preload("res://scripts/BuildingPlan.gd")

var secondsBetweenBuilds := 0.5
var secondsBetweenShotSalvos := 0.1
## When nothing could be done, wait this long before planning again (the Unity
## version re-planned every frame, which is too expensive in GDScript).
var secondsIdleRetry := 0.15
var nextAction := 0.0
var nActivePlans := 3
var nFinishedPlans := 12
var consecutiveShots := 1
## catalog ids of the structures the AI builds from upgrade blocks
var preferredUpgrade := "cannon22c"
var supplyUpgrade := "supply22"
var activePlans: Array = []
var finishedPlans: Array = []
var upgradePlan = null
var doubleStackPlan = null
var enemyPlayers = null
var maxUp := 3
var maxDown := 2
var maxLeft := 3
var maxRight := 2
var maxPlanRange := 3
var inPlanRange := PackedByteArray()
var lastHighlight = null
## A dormant AI never acts (sandbox: test a build against a stationary enemy).
var dormant := false
## What the AI shoots at: "walls" (the original behaviour), "guns", "supply" or "random"
var targetMode := "walls"
## Segment memo used by BuildingPlan during one plan search (null otherwise)
var connectionMemo = null
var searchStamp := 0
var sliceBudgetUsec := 4000
var _searching := false
## set when the game was left while a search was running
var _abort_search := false
var _slice_start := 0


func setup() -> void:
	super.setup()
	activePlans = []
	maxPlanRange = maxi(maxi(maxUp, maxDown), maxi(maxLeft, maxRight))
	inPlanRange = PackedByteArray()
	inPlanRange.resize(map.sizeX * map.sizeZ)


func update_point_and_tile_selected() -> void:
	pass


func manage_player_actions() -> void:
	if dormant:
		return
	if U.time > nextAction:
		if game.shootingAllowed:
			search_and_fire_at_targets()
		else:
			update_plans()
			execute_building_plan()


func update_plans() -> void:
	for p in activePlans:
		if p.finished():
			finishedPlans.append(p)
	var kept: Array = []
	for p in finishedPlans:
		if p.walls_in_something_valuable() and p.fits_with_existing_buildings() and p.finished():
			kept.append(p)
			if kept.size() >= nFinishedPlans:
				break
	finishedPlans = kept
	var active: Array = []
	for p in activePlans:
		if p.can_be_finished() and not p.finished():
			active.append(p)
	activePlans = active
	if activePlans.size() < nActivePlans and not _searching:
		_run_search()


## The plan search is expensive in GDScript; it runs as a coroutine spread over
## several frames (at most sliceBudgetUsec per frame) so the game stays smooth.
func _run_search() -> void:
	_searching = true
	var result: Array = await search_best_building_plans(activePlans.duplicate(), nActivePlans)
	if _abort_search or not is_instance_valid(self):
		return
	activePlans = result
	_searching = false


func _yield_if_needed() -> void:
	if Time.get_ticks_usec() - _slice_start > sliceBudgetUsec:
		# caches are only valid while the map cannot change, i.e. within one slice
		connectionMemo = null
		await (Engine.get_main_loop() as SceneTree).process_frame
		if not is_instance_valid(self) or not is_inside_tree():
			_abort_search = true
			return
		_begin_slice()


func _begin_slice() -> void:
	_slice_start = Time.get_ticks_usec()
	connectionMemo = {}
	searchStamp += 1


func _update_double_stack_plan() -> void:
	if doubleStackPlan == null or doubleStackPlan.is_fully_stacked():
		doubleStackPlan = null
		for plan in finishedPlans + activePlans:
			if not plan.is_fully_stacked():
				doubleStackPlan = plan
				break


func execute_building_plan() -> void:
	var did := try_build_upgrade()
	if U.alive(nextBuilding) and U.comp(nextBuilding, "Upgrade") != null:
		drop(nextBuilding, false)
	if not did:
		did = try_build_walled_in_gun()
	if not did:
		var n_for_max := 25
		var n := _count_walled_in_tiles_in_finished_plans()
		var p := 0.05 + 0.75 * (float(n) / float(n_for_max) if n < n_for_max else 1.0)
		if U.rfloat(0.0, 1.0) < p:
			did = try_stack_next_wall()
	if not did:
		did = try_build_next_wall()
	if not did:
		did = try_stack_next_wall()
	if not did:
		did = try_build_gun_in_plan()
	if not did:
		drop(nextWall, true)
	if did:
		nextAction = U.time + secondsBetweenBuilds
	else:
		nextAction = U.time + secondsIdleRetry


func _count_walled_in_tiles_in_finished_plans() -> int:
	var count := 0
	for bp in finishedPlans:
		count += bp.count_unoccupied_free_tiles()
	return count


func search_and_fire_at_targets() -> void:
	if enemyPlayers == null:
		enemyPlayers = []
		for p in game.players:
			if p.playerID != playerID:
				enemyPlayers.append(p)
	if enemyPlayers.is_empty():
		return
	_random_shuffle(activeCannons)
	var enemy = enemyPlayers[U.rint(0, enemyPlayers.size())]
	var targets := aquire_targets(enemy, activeCannons.size())
	_random_shuffle(targets)
	if targets.size() > 0:
		var shots := 0
		var next_cannon := 0
		var next_target := 0
		while next_cannon < activeCannons.size() and shots < consecutiveShots:
			var t = targets[next_target]
			if activeCannons[next_cannon].try_shoot(t.go.global_position, t):
				shots += 1
			next_cannon += 1
			next_target += 1
			if next_target >= targets.size():
				next_target = 0
		nextAction = U.time + secondsBetweenShotSalvos


func _random_shuffle(arr: Array) -> void:
	var length := arr.size()
	for i in range(0, length - 1):
		var hold = arr[i]
		var r := U.rint(i, length)
		arr[i] = arr[r]
		arr[r] = hold


func aquire_targets(enemy, n: int) -> Array:
	if targetMode != "walls":
		var pool := _target_pool(enemy)
		if not pool.is_empty():
			_random_shuffle(pool)
			return pool.slice(0, n)
	var tiles: Array = []
	for t in enemy.wallTiles:
		if U.alive(t):
			tiles.append([t.count_neighbouring_walls(), t])
	tiles.sort_custom(func(a, b): return a[0] > b[0])
	var out: Array = []
	for i in mini(n, tiles.size()):
		out.append(tiles[i][1])
	return out


func _get_plans_for_spot(x: int, z: int, m_up: int, m_down: int, m_left: int, m_right: int) -> Array:
	var out: Array = []
	var max_ix: int = map.sizeX - 1
	var max_iz: int = map.sizeZ - 1
	m_right = mini(x + m_right, max_ix) - x
	m_up = mini(z + m_up, max_iz) - z
	m_left = x if x - m_left < 0 else m_left
	m_down = z if z - m_down < 0 else m_down
	# Cheap pre-check shared by all plan sizes (see BuildingPlan.construct_building_place)
	if x <= 0 or z <= 0 or x >= max_ix or z >= max_iz or map.get_mini(x, z) != 0 \
			or not map.statesMap.is_open(x * 3 + 1, z * 3 + 1):
		return out
	for mu in range(1, m_up + 1):
		for md in range(1, m_down + 1):
			for ml in range(1, m_left + 1):
				for mr in range(1, m_right + 1):
					var bp = BuildingPlan.new(x, z, self, mu, md, ml, mr)
					if bp.possible:
						out.append(bp)
	return out


func _start_expotential_wall_costs() -> int:
	var n := activeCannons.size()
	if n == 0:
		return 0
	elif n == 1:
		return 5
	elif n < 5:
		return 10
	elif n < 7:
		return 15
	return 20


func mark_buildable_area_waterflow(x: int, z: int, buildable := true) -> void:
	super.mark_buildable_area_waterflow(x, z, buildable)
	mark_square_on_array(x, z, inPlanRange, maxPlanRange, buildable)


func search_best_building_plans(plans = null, max_plans := 3) -> Array:
	if plans == null:
		plans = []
	_begin_slice()
	var potential: Array = []
	for ix in map.sizeX:
		for iz in map.sizeZ:
			if inPlanRange[ix * map.sizeZ + iz] != 0:
				potential.append_array(_get_plans_for_spot(ix, iz, maxUp, maxDown, maxLeft, maxRight))
				await _yield_if_needed()
				if _abort_search:
					return plans
	var standalone: Array = []
	var additions: Array = []
	for pi in potential.size():
		var p = potential[pi]
		var compatible: bool = p.can_be_compatible_all(plans)
		if compatible and p.can_be_finished():
			standalone.append(p)
		if not compatible:
			additions.append(p)
		if pi % 64 == 0:
			await _yield_if_needed()
			if _abort_search:
				return plans
	var costs := _start_expotential_wall_costs()
	while standalone.size() > 0 and plans.size() < max_plans:
		var scored: Array = []
		for si in standalone.size():
			var p = standalone[si]
			scored.append([p.calculate_compatibility_score(plans, costs), p])
			if si % 64 == 0:
				await _yield_if_needed()
				if _abort_search:
					return plans
		scored.sort_custom(func(a, b): return a[0] > b[0])
		var best = scored[0][1]
		best.ensure_compatibility_all(plans)
		plans.append(best)
		var rest: Array = []
		for i in range(1, scored.size()):
			var p = scored[i][1]
			if p.can_be_compatible_all(plans):
				rest.append(p)
		standalone = rest
	for i in plans.size():
		var candidate = null
		var candidate_score := 0
		var candidate_idx := 0
		var plan_score: int = plans[i].calculate_score(costs)
		var others: Array = plans.slice(0, i) + plans.slice(i + 1)
		for j in additions.size():
			if j % 64 == 0:
				await _yield_if_needed()
				if _abort_search:
					return plans
			if plans[i].can_be_combined(additions[j]):
				var new_candidate = plans[i].combine(additions[j])
				var new_score: int = new_candidate.calculate_score(costs)
				if candidate != null or new_score > candidate_score:
					if new_candidate.can_be_compatible_all(others) and new_candidate.can_be_finished():
						candidate_score = new_score
						candidate = new_candidate
						candidate_idx = j
		if candidate != null and candidate_score > plan_score:
			plans[i] = candidate
			additions.remove_at(candidate_idx)
	connectionMemo = null
	return plans


func try_stack_next_wall() -> bool:
	_update_double_stack_plan()
	if not U.alive(nextWall):
		return false
	var nbb := U.comp(nextWall, "BuildingBlock")
	if doubleStackPlan == null or nbb == null:
		return false
	var rots := -1
	var stackable: Dictionary = doubleStackPlan.get_stackable_walls()
	for k in stackable:
		var old_bb := U.comp(map.tiles[k.x][k.y].structure, "BuildingBlock")
		rots = old_bb.fits_plan_with_clockwise_rotations_of_input(nbb.connects_up_down_left_right())
		if rots > -1:
			for r in rots:
				nbb.rotate_clockwise()
			stack_wall(map.tiles[k.x][k.y])
			highlight_building_place(map.tiles[k.x][k.y])
			break
	return rots > -1


func _try_set_upgrade_plan(upgrade_name: String) -> void:
	upgradePlan = null
	for bp in finishedPlans + activePlans:
		if bp.try_initialize_xz_upgrade_tiles(upgrade_name):
			upgradePlan = bp
			break


func try_build_upgrade() -> bool:
	var available := U.alive(nextBuilding) and U.comp(nextBuilding, "Upgrade") != null
	if not available:
		return false
	if availableSupply * 0.85 < supplyNeed:
		return true if _try_build_supply_on_existing_unbuildable_update() else try_build_upgrade_in_plan(supplyUpgrade)
	return try_build_upgrade_in_plan(preferredUpgrade)


func _try_build_supply_on_existing_unbuildable_update() -> bool:
	for coords in upgrades.keys():
		var tile = map.tiles[coords.x][coords.y]
		if not U.alive(tile.structure):
			continue
		var can_build: bool = ibr(coords.x, coords.y) and tile.buildable()
		var cluster = UpgradeCluster.new(tile, self)
		if can_build and can_combine_next_building_with_tile(tile) and not cluster.can_be_built():
			combine_building(tile)
			highlight_building_place(tile)
			return true
	return false


func try_build_upgrade_in_plan(upgrade_name: String) -> bool:
	if upgradePlan != null and not upgradePlan.upgrade_can_be_finished():
		upgradePlan = null
	if upgradePlan == null:
		_try_set_upgrade_plan(upgrade_name)
	if upgradePlan == null:
		return false
	var xz = upgradePlan.get_upgrade_location_for_upgrade_type(U.comp(nextBuilding, "Upgrade").upgradeType)
	if xz == null:
		return false
	build_next_building(map.tiles[xz.x][xz.y])
	return true


func try_build_next_wall() -> bool:
	if not U.alive(nextWall):
		return false
	var bb := U.comp(nextWall, "BuildingBlock")
	var rots := -1
	for plan in activePlans:
		var walls: Dictionary = plan.get_unfinished_buildable_walls()
		for k in walls:
			if ibr(k.x, k.y):
				rots = bb.fits_plan_with_clockwise_rotations_of_input(walls[k])
				if rots > -1:
					for r in rots:
						bb.rotate_counter_clockwise()
					var tile = map.tiles[k.x][k.y]
					build_next_wall(tile)
					highlight_building_place(tile)
					break
		if rots > -1:
			break
	return rots > -1


func highlight_building_place(tile) -> void:
	if U.alive(lastHighlight):
		lastHighlight.reset_color()
	lastHighlight = tile
	tile.set_tile_color(Color.BLACK)


func try_build_walled_in_gun() -> bool:
	if not U.alive(nextBuilding) or U.comp(nextBuilding, "Shooter") == null:
		return false
	for ix in map.sizeX:
		for iz in map.sizeZ:
			var in_upgrade_plan: bool = upgradePlan != null and upgradePlan.upgrade_tiles_contain(ix, iz)
			if map.statesMap.is_closed(ix * 3, iz * 3) and ibr(ix, iz) and map.get_mini(ix, iz) == 0 \
					and not in_upgrade_plan:
				build_next_building(map.tiles[ix][iz])
				highlight_building_place(map.tiles[ix][iz])
				return true
	return false


func try_build_gun_in_plan() -> bool:
	if not U.alive(nextBuilding) or U.comp(nextBuilding, "Shooter") == null:
		return false
	for plan in activePlans:
		for xz in plan.xzWalledInTiles:
			# (sic) the original checks (x, x)
			var in_upgrade_plan: bool = upgradePlan != null and upgradePlan.upgrade_tiles_contain(xz.x, xz.x)
			if ibr(xz.x, xz.y) and map.get_mini(xz.x, xz.y) == 0 and not in_upgrade_plan:
				build_next_building(map.tiles[xz.x][xz.y])
				highlight_building_place(map.tiles[xz.x][xz.y])
				return true
	return false


## Tiles to shoot at for the target modes other than "walls" (empty = fall
## back to walls).
func _target_pool(enemy) -> Array:
	var keys: Array = []
	match targetMode:
		"guns":
			keys = enemy.cannons.keys() + enemy.supports.keys()
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
