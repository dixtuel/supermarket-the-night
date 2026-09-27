extends Area2D
class_name RoomSupplyPickup
## A task token dropped into the world. The event director owns how it counts;
## this pickup only reports collection and never mutates the request resource.

signal collected(supply_id: StringName, amount: int)

@export var supply_id: StringName = &""
@export_range(1, 20, 1) var amount: int = 1

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if _sprite.texture != null:
		var size: Vector2 = _sprite.texture.get_size()
		_sprite.scale = Vector2.ONE * (26.0 / maxf(size.x, size.y))


func _draw() -> void:
	if is_instance_valid(_sprite) and _sprite.texture != null:
		return
	draw_circle(Vector2(0.0, 4.0), 12.0, Color(0.03, 0.05, 0.04, 0.45))
	draw_colored_polygon(
		PackedVector2Array([Vector2(-9, -8), Vector2(0, -12), Vector2(9, -8), Vector2(9, 5), Vector2(0, 10), Vector2(-9, 5)]),
		Color("dfb95a")
	)
	draw_line(Vector2(-9, -5), Vector2(9, -5), Color("795833"), 2.0, true)
	draw_line(Vector2(0, -11), Vector2(0, 7), Color("f1dfa0"), 1.5, true)
	draw_rect(Rect2(Vector2(-2, -3), Vector2(4, 5)), Color("faf1cf"), true)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if supply_id == &"":
		return
	collected.emit(supply_id, maxi(1, amount))
	queue_free()
