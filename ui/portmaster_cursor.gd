extends CanvasLayer
## Draws a temporary pointer for PortMaster's right-stick mouse emulation.

const HIDE_DELAY_SECONDS := 2.25
const TOP_CANVAS_LAYER := 100

var _cursor_visual: Control
var _hide_timer: Timer


func _ready() -> void:
	if not OS.has_feature("portmaster"):
		return

	layer = TOP_CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	_cursor_visual = preload("res://ui/portmaster_cursor_visual.gd").new()
	_cursor_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cursor_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_visual.process_mode = Node.PROCESS_MODE_ALWAYS
	_cursor_visual.visible = false
	add_child(_cursor_visual)

	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.wait_time = HIDE_DELAY_SECONDS
	_hide_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_hide_timer.timeout.connect(_hide_cursor)
	add_child(_hide_timer)


func _input(event: InputEvent) -> void:
	if not OS.has_feature("portmaster") or not is_instance_valid(_cursor_visual):
		return

	if event is InputEventMouseMotion:
		_show_at((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		_show_at((event as InputEventMouseButton).position)


func _show_at(viewport_position: Vector2) -> void:
	_cursor_visual.call("set_cursor_position", viewport_position)
	_cursor_visual.visible = true
	_hide_timer.start()


func _hide_cursor() -> void:
	if is_instance_valid(_cursor_visual):
		_cursor_visual.visible = false
