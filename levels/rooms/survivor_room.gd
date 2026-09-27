extends Node2D
class_name SurvivorRoom

signal portal_requested(from_room_id: StringName, target_room_id: StringName, arrival_position: Vector2)

@export var room_id: StringName = &""
@export var art_prefix: String = "market"
@export var initial_state: StringName = &"clean_shift_start"

@onready var _art: Sprite2D = $RoomArt
@onready var _walls: StaticBody2D = $Walls
@onready var _fixtures: StaticBody2D = $Fixtures

var _is_active: bool = false


func _ready() -> void:
	for portal_node: Node in find_children("*", "RoomPortal", true, false):
		var portal := portal_node as RoomPortal
		portal.portal_requested.connect(_on_portal_requested)
	set_visual_state(initial_state)
	set_active(false)


func set_active(active: bool) -> void:
	_is_active = active
	visible = active
	if _walls == null:
		_walls = get_node_or_null("Walls") as StaticBody2D
	if _fixtures == null:
		_fixtures = get_node_or_null("Fixtures") as StaticBody2D
	if _walls != null:
		_walls.set_deferred("collision_layer", 1 if active else 0)
	if _fixtures != null:
		_fixtures.set_deferred("collision_layer", 1 if active else 0)
	for area_node: Node in find_children("*", "Area2D", true, false):
		var area := area_node as Area2D
		area.set_deferred("monitoring", active)
		area.set_deferred("monitorable", active)
	for portal_node: Node in find_children("*", "RoomPortal", true, false):
		var portal := portal_node as RoomPortal
		portal.set_deferred("monitoring", active)
		portal.set_deferred("monitorable", active)


func set_visual_state(state: StringName) -> void:
	var texture_path := "res://assets/generated/rooms/%s_%s.png" % [art_prefix, String(state)]
	if ResourceLoader.exists(texture_path):
		_art.texture = load(texture_path) as Texture2D
	else:
		push_warning("Missing room background state: " + texture_path)


func _on_portal_requested(target_room_id: StringName, arrival_position: Vector2) -> void:
	if _is_active:
		portal_requested.emit(room_id, target_room_id, arrival_position)
