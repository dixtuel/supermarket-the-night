extends Control
class_name MobileTouchControls

## A dynamic movement stick for phones. It only claims touches in the lower
## left area so the HUD and the game's regular controls keep their own input.

const MAX_RADIUS := 104.0
const INNER_DEADZONE := 0.14
const MOVE_ZONE_RIGHT_EDGE := 0.46
const MOVE_ZONE_TOP_EDGE := 0.44
const MOVE_ZONE_BOTTOM_EDGE := 0.95

var _enabled := false
var _touch_index := -1
var _mouse_stick_active := false
var _stick_origin := Vector2.ZERO
var _move_direction := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("mobile_controls")
	_enabled = _are_touch_controls_enabled()
	visible = _enabled
	if DisplayManager != null and DisplayManager.has_signal("touch_controls_changed"):
		DisplayManager.touch_controls_changed.connect(_on_touch_controls_changed)


func _input(event: InputEvent) -> void:
	if not _enabled:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1 and not get_tree().paused and _is_move_zone(touch.position):
				_begin_stick(touch.index, touch.position)
				get_viewport().set_input_as_handled()
		elif touch.index == _touch_index:
			_end_stick()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_stick(drag.position)
			get_viewport().set_input_as_handled()
		return

	if not (DisplayManager != null and DisplayManager.touch_controls_enabled):
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed:
			if not _mouse_stick_active and _touch_index == -1 and not get_tree().paused and _is_move_zone(mouse_button.position):
				_mouse_stick_active = true
				_begin_stick(-2, mouse_button.position)
				get_viewport().set_input_as_handled()
		elif _mouse_stick_active:
			_mouse_stick_active = false
			_end_stick()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse_stick_active:
		_update_stick((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_mouse_stick_active = false
		_end_stick()


func get_move_direction() -> Vector2:
	return _move_direction


func _is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func _are_touch_controls_enabled() -> bool:
	return _is_mobile_platform() or (DisplayManager != null and DisplayManager.touch_controls_enabled)


func _on_touch_controls_changed(enabled: bool) -> void:
	_enabled = _is_mobile_platform() or enabled
	visible = _enabled
	if not _enabled:
		_mouse_stick_active = false
		_end_stick()


func _is_move_zone(position: Vector2) -> bool:
	var viewport_size := get_viewport_rect().size
	return (
		position.x <= viewport_size.x * MOVE_ZONE_RIGHT_EDGE
		and position.y >= viewport_size.y * MOVE_ZONE_TOP_EDGE
		and position.y <= viewport_size.y * MOVE_ZONE_BOTTOM_EDGE
	)


func _begin_stick(index: int, position: Vector2) -> void:
	_touch_index = index
	_stick_origin = position
	_move_direction = Vector2.ZERO
	queue_redraw()


func _update_stick(position: Vector2) -> void:
	var offset := (position - _stick_origin).limit_length(MAX_RADIUS)
	var magnitude := offset.length() / MAX_RADIUS
	if magnitude <= INNER_DEADZONE:
		_move_direction = Vector2.ZERO
	else:
		var scaled_magnitude := inverse_lerp(INNER_DEADZONE, 1.0, magnitude)
		_move_direction = offset.normalized() * clampf(scaled_magnitude, 0.0, 1.0)
	queue_redraw()


func _end_stick() -> void:
	_touch_index = -1
	_move_direction = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if _touch_index == -1:
		return
	draw_circle(_stick_origin, MAX_RADIUS, Color(0.035, 0.07, 0.065, 0.52))
	draw_arc(_stick_origin, MAX_RADIUS, 0.0, TAU, 56, Color(0.91, 0.78, 0.43, 0.82), 4.0, true)
	draw_circle(_stick_origin, MAX_RADIUS * INNER_DEADZONE, Color(0.91, 0.78, 0.43, 0.18))
	var handle_position := _stick_origin + _move_direction * MAX_RADIUS
	draw_circle(handle_position, MAX_RADIUS * 0.34, Color(0.91, 0.78, 0.43, 0.84))
