extends Control
## High-contrast, asset-free pointer sized for the 640x480 PortMaster display.

const OUTLINE := Color("101b1a")
const PAPER := Color("fff4d5")
const CORAL := Color("e66f50")

var _cursor_position := Vector2.ZERO


func set_cursor_position(viewport_position: Vector2) -> void:
	_cursor_position = viewport_position
	queue_redraw()


func _draw() -> void:
	var outer := PackedVector2Array([
		_cursor_position + Vector2(0.0, 0.0),
		_cursor_position + Vector2(0.0, 23.0),
		_cursor_position + Vector2(6.0, 17.0),
		_cursor_position + Vector2(10.0, 26.0),
		_cursor_position + Vector2(16.0, 23.0),
		_cursor_position + Vector2(12.0, 14.0),
		_cursor_position + Vector2(22.0, 14.0),
	])
	draw_colored_polygon(outer, OUTLINE)

	var inner := PackedVector2Array([
		_cursor_position + Vector2(2.0, 4.0),
		_cursor_position + Vector2(2.0, 18.0),
		_cursor_position + Vector2(7.0, 13.0),
		_cursor_position + Vector2(11.0, 22.0),
		_cursor_position + Vector2(13.0, 21.0),
		_cursor_position + Vector2(9.0, 12.0),
		_cursor_position + Vector2(17.0, 12.0),
	])
	draw_colored_polygon(inner, PAPER)
	draw_colored_polygon(PackedVector2Array([
		_cursor_position + Vector2(4.0, 7.0),
		_cursor_position + Vector2(4.0, 12.0),
		_cursor_position + Vector2(7.0, 10.0),
	]), CORAL)
