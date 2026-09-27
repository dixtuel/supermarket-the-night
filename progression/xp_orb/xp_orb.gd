extends Area2D
class_name SurvivorXpOrb

@export var xp_amount: int = 1
@export var magnet_range: float = 110.0
@export var magnet_speed: float = 260.0

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
	if _is_collected or not body.is_in_group("player"):
		return
	_collect_for_player(body)


func collect_for_player(player: Node2D) -> void:
	if _is_collected or not is_instance_valid(player):
		return
	_collect_for_player(player)


func _collect_for_player(player: Node2D) -> void:

	_is_collected = true
	BakkalAudio.play_sfx(&"xp_collect")
	if player.has_method("gain_xp"):
		player.call("gain_xp", maxi(1, xp_amount))
	queue_free()
