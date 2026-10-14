extends "res://scripts/components/Component.gd"
## Port of RenderArc.cs: shows the predicted flight path of a cannon ball. Indicators.arc_style
## (round 27 candidates) picks the drawing: the shipped wire, a thin tapered wire, a flat band
## on the ground, a ring on the target tile, or round puffs along the path.

@export var lr: NodePath

var line:
	get:
		return get_node(lr)


func switch_on_or_off(on: bool) -> void:
	line.enabled = on


func _path(n_points: int, start: Vector3, end: Vector3, distance_xz: float, angle_rads: float, ascending_part: float, flat: bool) -> PackedVector3Array:
	var points := PackedVector3Array()
	points.resize(n_points)
	var max_y := distance_xz * tan(angle_rads) / 4.0 + start.y
	var delta := 1.0 / float(n_points - 1)
	for i in range(1, n_points - 1):
		var pf := float(i) * delta
		var point := start.lerp(end, pf)
		var q: float
		if pf < ascending_part:
			q = pow(pf / ascending_part - 1.0, 2.0)
		else:
			q = pow((pf - ascending_part) / (1.0 - ascending_part), 2.0)
		point.y = end.y + 0.02 if flat else (1.0 - q) * max_y
		points[i] = point
	points[0] = start
	points[n_points - 1] = end
	if flat:
		points[0].y = end.y + 0.02
	return points


func draw_arc(n_points: int, start: Vector3, end: Vector3, distance_xz: float, angle_rads: float, ascending_part: float) -> void:
	switch_on_or_off(true)
	match Indicators.arc_style:
		"taper":
			line.taper = true
			line.width = 0.045
			line.set_positions(_path(n_points, start, end, distance_xz, angle_rads, ascending_part, false))
		"band":
			line.taper = true
			line.width = 0.16
			line.set_positions(_path(n_points, start, end, distance_xz, angle_rads, ascending_part, true))
		"marker":
			line.taper = false
			line.width = 0.07
			line.loop = true
			var ring := PackedVector3Array()
			for i in 16:
				var a := float(i) / 16.0 * TAU
				ring.append(end + Vector3(cos(a) * 0.42, 0.03, sin(a) * 0.42))
			line.set_positions(ring)
		"puffs":
			line.puffs = true
			line.width = 0.12
			line.set_positions(_path(14, start, end, distance_xz, angle_rads, ascending_part, false))
		_:
			line.taper = false
			line.width = 0.068436
			line.set_positions(_path(n_points, start, end, distance_xz, angle_rads, ascending_part, false))
