extends Area2D
class_name RoomPortal

signal portal_requested(target_room_id: StringName, arrival_position: Vector2)

@export var target_room_id: StringName = &""
@export var arrival_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("room_portal")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and target_room_id != &"":
		portal_requested.emit(target_room_id, arrival_position)
