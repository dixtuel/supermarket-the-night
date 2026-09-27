class_name EnemySlowPatch
extends Area2D
## A short-lived, readable ground hazard. Current players can be slowed through
## their move_speed property; actors that add apply_slow() use that API instead.

const SLOW_META: StringName = &"_enemy_slow_sources"
const BASE_SPEED_META: StringName = &"_enemy_slow_base_speed"

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _fill: Polygon2D = $Fill
@onready var _outline: Line2D = $Outline

var _radius: float = 58.0
var _lifetime: float = 3.0
var _speed_multiplier: float = 0.72
var _damage: int = 0
var _elapsed: float = 0.0
var _affected_players: Dictionary = {}


func configure(radius: float, duration: float, speed_multiplier: float, damage: int = 0) -> void:
	_radius = maxf(12.0, radius)
	_lifetime = maxf(0.1, duration)
	_speed_multiplier = clampf(speed_multiplier, 0.05, 1.0)
	_damage = maxi(0, damage)
	if is_inside_tree():
		_apply_shape_and_visuals()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_shape_and_visuals()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime:
		_release_all_players()
		queue_free()


func _exit_tree() -> void:
	_release_all_players()


func _apply_shape_and_visuals() -> void:
	if _collision == null:
		return
	var circle := _collision.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		_collision.shape = circle
	else:
		circle = circle.duplicate() as CircleShape2D
		_collision.shape = circle
	circle.radius = _radius
	var points := PackedVector2Array()
	for index: int in range(41):
		var angle: float = TAU * float(index) / 40.0
		points.append(Vector2(cos(angle), sin(angle)) * _radius)
	_fill.polygon = points
	_fill.color = Color(0.28, 0.72, 0.9, 0.18)
	_outline.points = points
	_outline.default_color = Color(0.54, 0.87, 0.96, 0.82)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	var id: int = body.get_instance_id()
	if _affected_players.has(id):
		return
	_affected_players[id] = weakref(body)
	if _damage > 0 and body.has_method("take_damage"):
		body.call("take_damage", _damage)
	if body.has_method("apply_slow"):
		body.call("apply_slow", _speed_multiplier, maxf(0.15, _lifetime - _elapsed))
	else:
		_add_speed_lease(body)


func _on_body_exited(body: Node2D) -> void:
	if not _affected_players.has(body.get_instance_id()):
		return
	_affected_players.erase(body.get_instance_id())
	if not body.has_method("apply_slow"):
		_remove_speed_lease(body)


func _add_speed_lease(player: Node2D) -> void:
	if not _has_property(player, &"move_speed"):
		return
	var sources: Dictionary = player.get_meta(SLOW_META, {})
	if sources.is_empty():
		player.set_meta(BASE_SPEED_META, float(player.get("move_speed")))
	sources[get_instance_id()] = _speed_multiplier
	player.set_meta(SLOW_META, sources)
	_apply_speed_lease(player, sources)


func _remove_speed_lease(player: Node2D) -> void:
	if not is_instance_valid(player) or not player.has_meta(SLOW_META):
		return
	var sources: Dictionary = player.get_meta(SLOW_META)
	sources.erase(get_instance_id())
	if sources.is_empty():
		if player.has_meta(BASE_SPEED_META) and _has_property(player, &"move_speed"):
			player.set("move_speed", float(player.get_meta(BASE_SPEED_META)))
		player.remove_meta(SLOW_META)
		if player.has_meta(BASE_SPEED_META):
			player.remove_meta(BASE_SPEED_META)
	else:
		player.set_meta(SLOW_META, sources)
		_apply_speed_lease(player, sources)


func _apply_speed_lease(player: Node2D, sources: Dictionary) -> void:
	if not player.has_meta(BASE_SPEED_META) or not _has_property(player, &"move_speed"):
		return
	var strongest_slow: float = 1.0
	for multiplier: Variant in sources.values():
		strongest_slow = minf(strongest_slow, float(multiplier))
	player.set("move_speed", float(player.get_meta(BASE_SPEED_META)) * strongest_slow)


func _release_all_players() -> void:
	for reference: Variant in _affected_players.values():
		var player := reference.get_ref() as Node2D
		if is_instance_valid(player) and not player.has_method("apply_slow"):
			_remove_speed_lease(player)
	_affected_players.clear()


func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false
