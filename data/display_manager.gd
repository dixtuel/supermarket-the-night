extends Node
## Central Display and Resolution Management Singleton.
## Manages 1920x1080, 1600x900, 1366x768, and 1280x720 resolutions,
## Window modes (Fullscreen, Borderless, Windowed), and settings persistence.

signal display_settings_changed
signal touch_controls_changed(enabled: bool)

const SETTINGS_PATH := "user://settings.cfg"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1366, 768),
	Vector2i(1280, 720),
]

const RESOLUTION_LABELS: Array[String] = [
	"1920 x 1080 (FHD)",
	"1600 x 900 (HD+)",
	"1366 x 768 (WXGA)",
	"1280 x 720 (HD)",
]

enum WindowMode {
	FULLSCREEN = 0,
	BORDERLESS = 1,
	WINDOWED = 2,
}

var current_resolution_index: int = 0 # Default 1920x1080
var current_window_mode: int = WindowMode.WINDOWED
var touch_controls_enabled: bool = false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	load_settings()
	apply_display()


func get_resolution_label(index: int) -> String:
	if index >= 0 and index < RESOLUTION_LABELS.size():
		return RESOLUTION_LABELS[index]
	return "1920 x 1080"


func get_target_size() -> Vector2i:
	if current_resolution_index >= 0 and current_resolution_index < RESOLUTIONS.size():
		return RESOLUTIONS[current_resolution_index]
	return Vector2i(1920, 1080)


func set_resolution_index(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		return
	current_resolution_index = index
	apply_display()
	save_settings()
	display_settings_changed.emit()


func set_window_mode(mode: int) -> void:
	current_window_mode = clampi(mode, 0, 2)
	apply_display()
	save_settings()
	display_settings_changed.emit()


func set_touch_controls_enabled(enabled: bool) -> void:
	if touch_controls_enabled == enabled:
		return
	touch_controls_enabled = enabled
	save_settings()
	touch_controls_changed.emit(touch_controls_enabled)


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return

	var target_size := get_target_size()

	match current_window_mode:
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_size(target_size)
			_center_window(target_size)
		WindowMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_size(target_size)
			_center_window(target_size)


func _center_window(target_size: Vector2i) -> void:
	var screen_id := DisplayServer.window_get_current_screen()
	var screen_rect := DisplayServer.screen_get_usable_rect(screen_id)
	var pos_x := screen_rect.position.x + maxi(0, (screen_rect.size.x - target_size.x) / 2)
	var pos_y := screen_rect.position.y + maxi(0, (screen_rect.size.y - target_size.y) / 2)
	DisplayServer.window_set_position(Vector2i(pos_x, pos_y))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("display", "resolution_index", current_resolution_index)
	config.set_value("display", "window_mode", current_window_mode)
	config.set_value("input", "touch_controls_enabled", touch_controls_enabled)
	config.save(SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		current_resolution_index = clampi(int(config.get_value("display", "resolution_index", 0)), 0, RESOLUTIONS.size() - 1)
		current_window_mode = clampi(int(config.get_value("display", "window_mode", int(WindowMode.WINDOWED))), 0, 2)
		touch_controls_enabled = bool(config.get_value("input", "touch_controls_enabled", false))
	else:
		# Check screen resolution to pick optimal default
		var screen_size := DisplayServer.screen_get_size()
		if screen_size.x >= 1920 and screen_size.y >= 1080:
			current_resolution_index = 0 # 1920x1080
		elif screen_size.x >= 1600:
			current_resolution_index = 1 # 1600x900
		elif screen_size.x >= 1366:
			current_resolution_index = 2 # 1366x768
		else:
			current_resolution_index = 3 # 1280x720
		current_window_mode = WindowMode.WINDOWED
