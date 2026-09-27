class_name EnemyProjectile
extends Area2D
## Visible hostile shot used by ranged enemies and the boss scatter attack.

@export_range(0.1, 20.0, 0.1) var lifetime: float = 5.0

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 180.0
var _damage: int = 8
var _age: float = 0.0
var _spent: bool = false


func configure(direction: Vector2, speed: float, damage: int) -> void:
	_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	_speed = maxf(1.0, speed)
	_damage = maxi(0, damage)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	rotation = _direction.angle()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	global_position += _direction * _speed * delta


func _on_body_entered(body: Node2D) -> void:
	if _spent:
		return
	if body.is_in_group(&"player"):
		_spent = true
		if body.has_method("take_damage"):
			body.call("take_damage", _damage)
		queue_free()
	elif (body.collision_layer & 1) != 0:
		_spent = true
		queue_free()
