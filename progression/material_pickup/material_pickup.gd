extends Area2D
class_name SurvivorMaterialPickup

signal collected(amount: int)

@export_range(1, 10000, 1) var amount: int = 1
@export_range(1.0, 1000.0, 1.0) var magnet_range: float = 115.0
@export_range(1.0, 2000.0, 1.0) var magnet_speed: float = 300.0

var _player: Node2D
var _is_collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	if _is_collected:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		return
	var offset := _player.global_position - global_position
	if offset.length_squared() <= magnet_range * magnet_range:
		global_position += offset.normalized() * magnet_speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collect_for_player(body)


func collect_for_player(player: Node2D) -> void:
	if _is_collected or not is_instance_valid(player):
		return
	_is_collected = true
	collected.emit(maxi(1, amount))
	queue_free()
