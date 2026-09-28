extends Area2D
class_name SupplyRequestConsole
## Depot interaction point. The room scene injects its event director explicitly.

@export var required_room_id: StringName = &"depot"

@onready var _prompt: Label = $Prompt

var _event_director: RoomEventDirector
var _player_nearby: bool = false


func set_event_director(director: RoomEventDirector) -> void:
	_event_director = director
	if is_instance_valid(_event_director) and not _event_director.objective_changed.is_connected(_on_objective_changed):
		_event_director.objective_changed.connect(_on_objective_changed)
	_refresh_prompt()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or not _is_interaction_pressed(event):
		return
	if not is_instance_valid(_event_director):
		return
	if _event_director.claim_supply_request():
		_prompt.text = "HELP IS ON THE WAY"
		_prompt.visible = true
		get_viewport().set_input_as_handled()


func _is_interaction_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	# PortMaster maps A to Enter so it activates focused UI controls. Treat the
	# same confirm input as interaction only while the player is beside a console.
	# Desktop and mobile keep using the existing E / touch paths.
	return OS.has_feature("portmaster") and event.is_action_pressed("ui_accept")


func _draw() -> void:
	# Wall-mounted request keypad silhouette; art can be replaced without
	# changing the interaction or event-state logic.
	draw_rect(Rect2(Vector2(-20, -23), Vector2(40, 46)), Color("15332f"), true)
	draw_rect(Rect2(Vector2(-17, -20), Vector2(34, 40)), Color("346b5f"), true)
	draw_rect(Rect2(Vector2(-12, -15), Vector2(24, 9)), Color("e1c56e"), true)
	for row in range(2):
		for column in range(3):
			draw_circle(Vector2(-8 + column * 8, 2 + row * 8), 2.0, Color("b8d8ae"))


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_nearby = true
	_refresh_prompt()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_nearby = false
	_prompt.visible = false


func _refresh_prompt() -> void:
	if not _player_nearby or not is_instance_valid(_event_director):
		_prompt.visible = false
		return
	var status := _event_director.get_objective_status(required_room_id)
	if status.is_empty() or bool(status.get("resolved", false)):
		_prompt.visible = false
		return
	var supply_name := String(status.get("supply_id", "stock" )).replace("_", " ")
	var current := int(status.get("collected", 0))
	var required := int(status.get("required", 0))
	var interact_label := "A" if OS.has_feature("portmaster") else "E"
	_prompt.text = "%s  REQUEST HELP  %s %d/%d" % [interact_label, supply_name, current, required]
	_prompt.visible = true


func _on_objective_changed(_supply_id: StringName, _collected: int, _required: int) -> void:
	_refresh_prompt()
