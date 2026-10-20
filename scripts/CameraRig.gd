extends Camera3D
## Main camera: mouse wheel zooms towards the cursor, the middle mouse button
## drags the view while zoomed in. Fully zoomed out is the view that shows the
## whole map (set by GameController.position_camera()).

## Closest the camera gets to the ground point it looks at (world units).
@export var minDistance := 7.0
## Distance change per wheel notch.
@export var zoomStep := 1.2

var _home: Vector3  # fully zoomed out position
var _home_target: Vector3  # ground point in the screen centre when zoomed out
var _target: Vector3  # ground point in the screen centre
var _zoom := 1.0  # 1 = fully zoomed out, smaller = closer
var _min_zoom := 1.0
var _panning := false
var _half_extent := Vector2(10.0, 10.0)  # half the map size, x and z: how far the view centre may move


## Remember the current transform as the fully zoomed out view of a map that
## extends half_extent (x, z) around its centre.
func capture_home_view(half_extent: Vector2) -> void:
	_half_extent = half_extent
	_home = global_position
	_home_target = _ground_point(get_viewport().get_visible_rect().size / 2.0)
	_target = _home_target
	_zoom = 1.0
	_min_zoom = minf(1.0, minDistance / _home.distance_to(_home_target))


func zoom_level() -> float:
	return _zoom


## Point on the ground (y = 0) under a screen position.
func _ground_point(screen: Vector2) -> Vector3:
	var origin := project_ray_origin(screen)
	var dir := project_ray_normal(screen)
	if absf(dir.y) < 1e-5:
		return origin
	return origin + dir * (-origin.y / dir.y)


func _apply() -> void:
	# the further out, the less room to pan: fully zoomed out the view is fixed
	var room := (1.0 - _zoom) / (1.0 - _min_zoom) if _min_zoom < 1.0 else 0.0
	var half := Vector3(_half_extent.x, 0, _half_extent.y)
	var off := (_target - _home_target).clamp(-half * room, half * room)
	_target = _home_target + off
	global_position = _target + (_home - _home_target) * _zoom


func _zoom_at(screen: Vector2, factor: float) -> void:
	var before := _ground_point(screen)
	_zoom = clampf(_zoom * factor, _min_zoom, 1.0)
	global_position = _target + (_home - _home_target) * _zoom
	# keep the ground point under the cursor where it was
	_target += before - _ground_point(screen)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, 1.0 / zoomStep)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, zoomStep)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed and _zoom < 1.0
	elif event is InputEventMouseMotion and _panning:
		var prev: Vector2 = event.position - event.relative
		_target += _ground_point(prev) - _ground_point(event.position)
		_apply()
