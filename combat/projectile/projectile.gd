extends Area2D
class_name SurvivorProjectile

enum FlightMode { STRAIGHT, RETURNING, ORBITING, ZONE }

@export var speed: float = 560.0
@export var lifetime: float = 1.5

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Polygon2D = $Visual

var _direction: Vector2 = Vector2.RIGHT
var _damage: int = 1
var _remaining_lifetime: float = 0.0
var _has_launched: bool = false
var _has_hit: bool = false
var _flight_mode: FlightMode = FlightMode.STRAIGHT
var _remaining_pierce: int = 0
var _travelled_distance: float = 0.0
var _return_distance: float = INF
var _return_target: Node2D
var _orbit_anchor: Node2D
var _life_steal_source: Node2D
var _orbit_radius: float = 0.0
var _orbit_speed: float = 0.0
var _orbit_angle: float = 0.0
var _zone_slow_multiplier: float = 1.0
var _zone_hit_ids: Dictionary = {}
var _weapon_sprite: Sprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_remaining_lifetime = maxf(0.05, lifetime)
	_weapon_sprite = Sprite2D.new()
	_weapon_sprite.name = "WeaponSprite"
	_weapon_sprite.z_index = 1
	add_child(_weapon_sprite)


## Legacy API retained for callers that only provide direction and damage.
func launch(direction: Vector2, damage: int) -> void:
	_direction = direction.normalized()
	if _direction.is_zero_approx():
		_direction = Vector2.RIGHT
	_damage = maxi(1, damage)
	_remaining_pierce = 0
	_flight_mode = FlightMode.STRAIGHT
	_has_launched = true


func launch_with_stats(direction: Vector2, damage: int, projectile_speed: float, projectile_lifetime: float, pierce_count: int) -> void:
	speed = maxf(1.0, projectile_speed)
	lifetime = maxf(0.05, projectile_lifetime)
	_remaining_lifetime = lifetime
	launch(direction, damage)
	_remaining_pierce = maxi(0, pierce_count)


func set_life_steal_source(source: Node2D) -> void:
	_life_steal_source = source


func launch_returning(
		direction: Vector2,
		damage: int,
		projectile_speed: float,
		projectile_lifetime: float,
		pierce_count: int,
		return_distance: float,
		return_target: Node2D
	) -> void:
	launch_with_stats(direction, damage, projectile_speed, projectile_lifetime, pierce_count)
	_flight_mode = FlightMode.RETURNING
	_return_target = return_target
	_return_distance = maxf(24.0, return_distance)
	_travelled_distance = 0.0
	_visual.color = Color("d99bff")


func launch_orbit(anchor: Node2D, radius: float, angular_speed: float, damage: int, start_angle: float) -> void:
	_flight_mode = FlightMode.ORBITING
	_orbit_anchor = anchor
	_orbit_radius = maxf(8.0, radius)
	_orbit_speed = angular_speed
	_orbit_angle = start_angle
	_damage = maxi(1, damage)
	_has_launched = true
	_visual.color = Color("7ee5d0")
	_remaining_lifetime = INF


func update_orbit(radius: float, angular_speed: float, damage: int) -> void:
	if _flight_mode != FlightMode.ORBITING:
		return
	_orbit_radius = maxf(8.0, radius)
	_orbit_speed = angular_speed
	_damage = maxi(1, damage)


func launch_zone(damage: int, radius: float, duration: float, slow_multiplier: float) -> void:
	_flight_mode = FlightMode.ZONE
	_damage = maxi(0, damage)
	_remaining_lifetime = maxf(0.1, duration)
	_zone_slow_multiplier = clampf(slow_multiplier, 0.05, 1.0)
	_has_launched = true
	_has_hit = false
	_resize_zone(maxf(12.0, radius))
	_visual.color = Color(0.35, 0.88, 0.77, 0.34)
	_visual.z_index = -1


func set_weapon_visual(texture: Texture2D, target_size: float = 28.0, keep_area_fill: bool = false) -> void:
	if _weapon_sprite == null:
		return
	if texture == null:
		_weapon_sprite.visible = false
		_visual.visible = true
		return
	_weapon_sprite.texture = texture
	var texture_size: Vector2 = texture.get_size()
	var longest_side: float = maxf(texture_size.x, texture_size.y)
	var uniform_scale: float = target_size / maxf(1.0, longest_side)
	_weapon_sprite.scale = Vector2.ONE * uniform_scale
	_weapon_sprite.visible = true
	_visual.visible = keep_area_fill


func _physics_process(delta: float) -> void:
	if not _has_launched or _has_hit:
		return
	if _flight_mode == FlightMode.ZONE:
		_remaining_lifetime -= delta
		if _remaining_lifetime <= 0.0:
			queue_free()
		return
	if _flight_mode == FlightMode.ORBITING:
		if not is_instance_valid(_orbit_anchor):
			queue_free()
			return
		_orbit_angle += _orbit_speed * delta
		global_position = _orbit_anchor.global_position + Vector2.RIGHT.rotated(_orbit_angle) * _orbit_radius
		return
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		queue_free()
		return
	if _flight_mode == FlightMode.RETURNING and _travelled_distance >= _return_distance:
		if not is_instance_valid(_return_target):
			queue_free()
			return
		_direction = global_position.direction_to(_return_target.global_position)
		if global_position.distance_squared_to(_return_target.global_position) <= 20.0 * 20.0:
			queue_free()
			return
	var step_distance: float = speed * delta
	global_position += _direction * step_distance
	_travelled_distance += step_distance
	rotation = _direction.angle()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		if _flight_mode in [FlightMode.STRAIGHT, FlightMode.RETURNING] and (body.collision_layer & 1) != 0:
			_has_hit = true
			queue_free()
		return
	if _flight_mode == FlightMode.ZONE:
		var id: int = body.get_instance_id()
		if _zone_hit_ids.has(id):
			return
		_zone_hit_ids[id] = true
		_deal_damage(body)
		if body.has_method("apply_slow"):
			body.call("apply_slow", _zone_slow_multiplier, maxf(0.1, _remaining_lifetime))
		return
	_deal_damage(body)
	if _flight_mode == FlightMode.ORBITING:
		return
	if _remaining_pierce > 0:
		_remaining_pierce -= 1
	else:
		_has_hit = true
		queue_free()


func _deal_damage(body: Node2D) -> void:
	if _damage > 0 and body.has_method("take_damage"):
		var health_before: int = int(body.call("get_health")) if body.has_method("get_health") else _damage
		body.call("take_damage", _damage)
		var health_after: int = int(body.call("get_health")) if body.has_method("get_health") else maxi(0, health_before - _damage)
		var dealt_damage := maxi(0, health_before - health_after)
		if dealt_damage > 0 and is_instance_valid(_life_steal_source) and _life_steal_source.has_method("recover_from_damage_dealt"):
			_life_steal_source.call("recover_from_damage_dealt", dealt_damage)


func _resize_zone(radius: float) -> void:
	var circle := _collision_shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		_collision_shape.shape = circle
	else:
		circle = circle.duplicate() as CircleShape2D
		_collision_shape.shape = circle
	circle.radius = radius
	var points := PackedVector2Array()
	for index: int in range(33):
		var angle: float = TAU * float(index) / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	_visual.polygon = points
