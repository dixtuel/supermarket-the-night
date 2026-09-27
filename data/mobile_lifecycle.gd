extends Node
## Mobile-only foreground/background power handling. Run state persistence is
## owned by SurvivorArena so this singleton never reaches into gameplay data.

var _is_suspended := false
var _previous_max_fps := 0
var _previous_master_mute := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_enter_background()
		NOTIFICATION_APPLICATION_RESUMED:
			_return_to_foreground()


func _enter_background() -> void:
	if _is_suspended:
		return
	_is_suspended = true
	_previous_max_fps = Engine.max_fps
	Engine.max_fps = 1
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		_previous_master_mute = AudioServer.is_bus_mute(master_bus)
		AudioServer.set_bus_mute(master_bus, true)


func _return_to_foreground() -> void:
	if not _is_suspended:
		return
	_is_suspended = false
	Engine.max_fps = _previous_max_fps
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, _previous_master_mute)
