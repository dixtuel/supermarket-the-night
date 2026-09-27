extends Area2D
class_name ConsumablePickup

enum Reward { HEALTH, ENERGY }

@export var reward: Reward = Reward.HEALTH
@export_range(1, 100, 1) var amount: int = 20
@export_range(0.05, 20.0, 0.05) var duration: float = 6.0
@export_range(1.0, 3.0, 0.05) var speed_multiplier: float = 1.3

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_refresh_look()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var consumed := false
	if reward == Reward.HEALTH and body.has_method("heal"):
		consumed = int(body.call("heal", amount)) > 0
	elif reward == Reward.ENERGY and body.has_method("apply_speed_boost"):
		consumed = int(body.call("apply_speed_boost", speed_multiplier, duration)) >= 0
	else:
		return
	if consumed:
		queue_free()


func _refresh_look() -> void:
	if not is_instance_valid(_sprite):
		return
	if reward == Reward.HEALTH:
		_sprite.texture = load("res://assets/generated/pickups/pickup_health_bag.png")
	else:
		_sprite.texture = load("res://assets/generated/pickups/pickup_energy_can.png")
	_sprite.scale = Vector2(0.034, 0.034)
	_collision.shape = CircleShape2D.new()
	(_collision.shape as CircleShape2D).radius = 17.0
