extends "res://scripts/components/Component.gd"
## Port of RenderArc.cs: shows the predicted flight path of a cannon ball.

@export var lr: NodePath

var line:
	get:
		return get_node(lr)


func switch_on_or_off(on: bool) -> void:
	line.enabled = on


func draw_arc(n_points: int, start: Vector3, end: Vector3, distance_xz: float, angle_rads: float, ascending_part: float) -> void:
	switch_on_or_off(true)
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
		point.y = (1.0 - q) * max_y
		points[i] = point
	points[0] = start
	points[n_points - 1] = end
	line.set_positions(points)
