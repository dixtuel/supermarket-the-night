extends Node
## RunSaveManager Singleton.
## Manages persisting active runs on "Save & Quit" and resuming them from the Title Screen.

const SAVE_PATH := "user://saved_run.json"

signal run_saved
signal run_cleared


func has_saved_run() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func get_saved_run_summary() -> Dictionary:
	if not has_saved_run():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json_str := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(json_str)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func save_run_state(state: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open %s for writing run save." % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(state, "  "))
	file.close()
	run_saved.emit()
	return true


func load_and_clear_saved_run() -> Dictionary:
	var data := get_saved_run_summary()
	clear_saved_run()
	return data


func clear_saved_run() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		run_cleared.emit()
