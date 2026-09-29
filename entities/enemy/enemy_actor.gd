class_name EnemyActor
extends CharacterBody2D
## One runtime actor for the authored enemy roster. Its Resource input is read-only;
## mutable health, timers, and attack state live on this instance.

signal defeated(definition: EnemyDefinition, world_position: Vector2)
signal health_changed(current: int, maximum: int)
signal stagger_changed(current: int, maximum: int, stunned: bool)
## Compatibility signal for arena code that consumes an XP amount directly.
signal died(xp_reward: int, world_position: Vector2)

enum Phase { APPROACH, TELEGRAPH, CHARGING, ATTACKING, RECOVERING, DEFEATED }
enum PendingAttack { NONE, CHARGE, CONTACT, PROJECTILE, ZONE, SCATTER, FLAME, TETHER }

const ENEMY_PROJECTILE_SCENE: PackedScene = preload("res://combat/enemy_projectile/enemy_projectile.tscn")
const SLOW_PATCH_SCENE: PackedScene = preload("res://entities/enemy/slow_patch.tscn")
const PLAYER_GROUP: StringName = &"player"
const ENEMY_GROUP: StringName = &"enemies"
const WALK_COLUMNS := 4
const WALK_ROWS := 4
const WALK_FRAMES_PER_DIRECTION := 4
const WALK_ANIMATION_SPEED := 7.0
const NORMAL_HIT_MAX_HEALTH_FRACTION := 0.24
const BOSS_HIT_MAX_HEALTH_FRACTION := 0.38
const NAVIGATION_PROBE_INTERVAL := 0.12
const NAVIGATION_LOOKAHEAD := 88.0
const NAVIGATION_BODY_RADIUS := 18.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _fallback_shape: Polygon2D = $FallbackShape
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _charge_telegraph: Line2D = $ChargeTelegraph
@onready var _ring_telegraph: Line2D = $RingTelegraph
@onready var _attack_area: Area2D = $AttackArea
@onready var _attack_area_shape: CollisionShape2D = $AttackArea/CollisionShape2D

var _definition: EnemyDefinition
var _target: Node2D
var _health: int = 1
var _health_multiplier: float = 1.0
var _damage_multiplier: float = 1.0
var _difficulty_speed_multiplier: float = 1.0
var _round_number: int = 1
var _attack_cooldown: float = 0.8
var _phase: Phase = Phase.APPROACH
var _pending_attack: PendingAttack = PendingAttack.NONE
var _phase_timer: float = 0.0
var _charge_direction: Vector2 = Vector2.RIGHT
var _charge_distance: float = 0.0
var _boss_next_charge: bool = true
var _target_refresh_timer: float = 0.0
var _slow_effects: Dictionary = {}
var _next_slow_id: int = 1
var _facing: StringName = &"down"
var _steering_direction: Vector2 = Vector2.ZERO
var _steering_probe_timer: float = 0.0
var _stuck_check_timer: float = 0.0
var _stuck_time: float = 0.0
var _stuck_check_position: Vector2 = Vector2.ZERO
var _contact_hit_applied: bool = false
var _manager_poise: float = 0.0
var _manager_stagger_timer: float = 0.0
var _manager_slow_timer: float = 0.0
var _manager_stagger_cooldown: float = 0.0
var _manager_attack_index: int = 0
var _manager_dash_active: bool = false
var _active_attack_radius: float = 0.0


func configure(
		definition: EnemyDefinition,
		health_multiplier: float,
		target: Node2D,
		damage_multiplier: float = 1.0,
		round_number: int = 1,
		difficulty_speed_multiplier: float = 1.0) -> void:
	_definition = definition
	_health_multiplier = maxf(0.1, health_multiplier)
	_damage_multiplier = maxf(0.0, damage_multiplier)
	_difficulty_speed_multiplier = maxf(0.1, difficulty_speed_multiplier)
	_round_number = maxi(1, round_number)
	_target = target
	if _definition != null:
		_health = _scaled_max_health()
		_attack_cooldown = minf(0.7, _contact_attack_interval() * 0.25)
	if is_inside_tree():
		_apply_definition()


func get_definition() -> EnemyDefinition:
	return _definition


func get_health() -> int:
	return _health


func is_immortal_boss() -> bool:
	return _is_manager_boss()


func get_stagger_value() -> float:
	return _manager_poise


func get_stagger_maximum() -> float:
	return _manager_stagger_threshold()


func take_damage(amount: int) -> void:
	if _phase == Phase.DEFEATED or amount <= 0:
		return
	if _is_manager_boss():
		if _manager_stagger_timer <= 0.0 and _manager_stagger_cooldown <= 0.0:
			_manager_poise += float(amount)
			var threshold := _manager_stagger_threshold()
			if _manager_poise >= threshold:
				_manager_poise = 0.0
				_begin_manager_stagger(false)
			stagger_changed.emit(roundi(_manager_poise), roundi(threshold), _manager_stagger_timer > 0.0)
		_flash_hit()
		return
	_health = maxi(0, _health - amount)
	if _definition != null:
		health_changed.emit(_health, _scaled_max_health())
	if _health <= 0:
		_defeat()
	else:
		_flash_hit()


func apply_slow(multiplier: float, duration: float) -> void:
	if duration <= 0.0:
		return
	var effect_id := _next_slow_id
	_next_slow_id += 1
	_slow_effects[effect_id] = {"multiplier": clampf(multiplier, 0.05, 1.0), "remaining": duration}


func migrate_to_room(room_id: StringName, spawn_position: Vector2) -> void:
	set_meta("room_id", room_id)
	global_position = spawn_position
	_phase = Phase.APPROACH
	_pending_attack = PendingAttack.NONE
	_phase_timer = 0.0
	_attack_cooldown = maxf(_attack_cooldown, 0.45)
	_contact_hit_applied = false
	_target_refresh_timer = 0.0
	_steering_direction = Vector2.ZERO
	_steering_probe_timer = randf_range(0.0, NAVIGATION_PROBE_INTERVAL)
	_stuck_time = 0.0
	_stuck_check_timer = 0.0
	velocity = Vector2.ZERO
	_hide_telegraphs()
	_restore_actor_color()
	_attack_area.monitoring = false


func _ready() -> void:
	add_to_group(ENEMY_GROUP)
	if _definition == null:
		push_warning("EnemyActor needs configure(definition, health_multiplier, target) before use.")
		return
	if not is_instance_valid(_target):
		_target = _find_player()
	_apply_definition()


func _physics_process(delta: float) -> void:
	if _definition == null or _phase == Phase.DEFEATED:
		return
	_tick_slow_effects(delta)
	_manager_stagger_cooldown = maxf(0.0, _manager_stagger_cooldown - delta)
	if _manager_stagger_timer > 0.0:
		_manager_stagger_timer = maxf(0.0, _manager_stagger_timer - delta)
		velocity = Vector2.ZERO
		move_and_slide()
		if _manager_stagger_timer <= 0.0:
			_manager_slow_timer = 2.0
			_manager_stagger_cooldown = 4.0
			_restore_actor_color()
			stagger_changed.emit(roundi(_manager_poise), roundi(_manager_stagger_threshold()), false)
		return
	if _manager_slow_timer > 0.0:
		_manager_slow_timer = maxf(0.0, _manager_slow_timer - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_target_refresh_timer -= delta
	if _target_refresh_timer <= 0.0 or not is_instance_valid(_target):
		_target = _find_player()
		_target_refresh_timer = 0.5
	if not is_instance_valid(_target):
		velocity = Vector2.ZERO
		move_and_slide()
		_update_walk_animation(velocity)
		return

	match _definition.role:
		EnemyDefinition.Role.CHASER:
			_tick_chaser(delta)
		EnemyDefinition.Role.CHARGER:
			_tick_charger(delta)
		EnemyDefinition.Role.RANGED:
			_tick_ranged(delta)
		EnemyDefinition.Role.AREA_DENIAL:
			_tick_area_denial(delta)
		EnemyDefinition.Role.BOSS:
			if _is_manager_boss():
				_tick_manager_boss(delta)
			else:
				_tick_boss(delta)
			
	if _phase != Phase.DEFEATED:
		if _phase == Phase.APPROACH:
			velocity = _steer_around_obstacles(velocity, delta)
		move_and_slide()
		if _manager_dash_active and get_slide_collision_count() > 0:
			_manager_dash_active = false
			_begin_manager_stagger(true)
		_update_walk_animation(velocity)
		_update_attack_area()
		_apply_contact_damage()


func _steer_around_obstacles(desired_velocity: Vector2, delta: float) -> Vector2:
	if desired_velocity.is_zero_approx():
		_steering_direction = Vector2.ZERO
		return desired_velocity
	_steering_probe_timer -= delta
	_stuck_check_timer -= delta
	if _stuck_check_timer <= 0.0:
		if _stuck_check_position != Vector2.ZERO and global_position.distance_to(_stuck_check_position) < 2.0 and velocity.length() > 24.0:
			_stuck_time += 0.35
		else:
			_stuck_time = 0.0
		_stuck_check_position = global_position
		_stuck_check_timer = 0.35
	if _steering_probe_timer > 0.0:
		return _steering_direction * desired_velocity.length() if not _steering_direction.is_zero_approx() else desired_velocity
	_steering_probe_timer = NAVIGATION_PROBE_INTERVAL
	var target_direction := _direction_to_target()
	var target_distance := _distance_to_target()
	if _corridor_is_clear(global_position, _target.global_position, target_direction):
		_steering_direction = Vector2.ZERO
		return desired_velocity
	var lookahead := minf(NAVIGATION_LOOKAHEAD, maxf(32.0, target_distance))
	var offsets := [-105.0, 105.0, -75.0, 75.0, -48.0, 48.0, -28.0, 28.0, -145.0, 145.0]
	var best_score := -INF
	var best_direction := Vector2.ZERO
	for offset_degrees: float in offsets:
		var candidate := target_direction.rotated(deg_to_rad(offset_degrees)).normalized()
		var end_point := global_position + candidate * lookahead
		if not _corridor_is_clear(global_position, end_point, candidate):
			continue
		var score := candidate.dot(target_direction) * 2.0 - absf(offset_degrees) * 0.002
		if not _steering_direction.is_zero_approx() and candidate.dot(_steering_direction) > 0.85:
			score += 0.20
		if _stuck_time >= 0.7:
			score += candidate.dot(target_direction) * 0.25
		if score > best_score:
			best_score = score
			best_direction = candidate
	if best_direction.is_zero_approx():
		var hit := _raycast_world(global_position, _target.global_position)
		if not hit.is_empty():
			var normal: Vector2 = hit.get("normal", Vector2.ZERO)
			var tangent_a := Vector2(-normal.y, normal.x).normalized()
			var tangent_b := -tangent_a
			best_direction = tangent_a if tangent_a.dot(target_direction) >= tangent_b.dot(target_direction) else tangent_b
	_steering_direction = best_direction
	return _steering_direction * desired_velocity.length() if not _steering_direction.is_zero_approx() else desired_velocity


func _corridor_is_clear(origin: Vector2, destination: Vector2, direction: Vector2) -> bool:
	var span := destination - origin
	if span.length_squared() <= 1.0:
		return true
	var side := Vector2(-direction.y, direction.x) * NAVIGATION_BODY_RADIUS * 0.72
	return _raycast_world(origin, destination).is_empty() \
		and _raycast_world(origin + side, destination + side).is_empty() \
		and _raycast_world(origin - side, destination - side).is_empty()


func _raycast_world(origin: Vector2, destination: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(origin, destination, collision_mask)
	query.exclude = [get_rid()]
	if is_instance_valid(_target) and _target is CollisionObject2D:
		query.exclude.append((_target as CollisionObject2D).get_rid())
	return get_world_2d().direct_space_state.intersect_ray(query)


func _has_clear_path_to_target() -> bool:
	if not is_instance_valid(_target):
		return false
	return _raycast_world(global_position, _target.global_position).is_empty()


func _tick_chaser(delta: float) -> void:
	match _phase:
		Phase.APPROACH:
			_pending_attack = PendingAttack.NONE
			_hide_telegraphs()
			velocity = _direction_to_target() * _movement_speed()
			if _distance_to_target() <= _definition.contact_range and _attack_cooldown <= 0.0:
				_pending_attack = PendingAttack.CONTACT
				_begin_telegraph(_definition.contact_range, false)
		Phase.TELEGRAPH:
			velocity = Vector2.ZERO
			_tick_telegraph(delta)
		Phase.ATTACKING:
			velocity = Vector2.ZERO
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_begin_recovery()
		Phase.RECOVERING:
			velocity = Vector2.ZERO
			_tick_recovery(delta)
		_:
			velocity = Vector2.ZERO


func _tick_charger(delta: float) -> void:
	match _phase:
		Phase.APPROACH:
			_hide_telegraphs()
			velocity = _direction_to_target() * _movement_speed()
			if _distance_to_target() <= _definition.attack_range and _attack_cooldown <= 0.0:
				_begin_charge(PendingAttack.CHARGE)
		Phase.TELEGRAPH:
			velocity = Vector2.ZERO
			_tick_telegraph(delta)
		Phase.CHARGING:
			velocity = _charge_direction * _charge_speed()
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_begin_recovery()
		Phase.RECOVERING:
			velocity = Vector2.ZERO
			_tick_recovery(delta)
		_:
			velocity = Vector2.ZERO


func _tick_area_denial(delta: float) -> void:
	match _phase:
		Phase.APPROACH:
			_hide_telegraphs()
			velocity = _direction_to_target() * _movement_speed()
			var effective_range: float = maxf(_definition.attack_range, _definition.zone_radius * 1.5)
			if _distance_to_target() <= effective_range and _attack_cooldown <= 0.0:
				_pending_attack = PendingAttack.ZONE
				_begin_telegraph(_definition.zone_radius, false)
		Phase.TELEGRAPH:
			velocity = Vector2.ZERO
			_tick_telegraph(delta)
		Phase.RECOVERING:
			velocity = Vector2.ZERO
			_tick_recovery(delta)
		_:
			velocity = Vector2.ZERO


func _tick_ranged(delta: float) -> void:
	match _phase:
		Phase.APPROACH:
			_hide_telegraphs()
			var direction: Vector2 = _direction_to_target()
			var distance: float = _distance_to_target()
			var preferred_range: float = maxf(32.0, _definition.attack_range * 0.72)
			if distance > _definition.attack_range * 0.9:
				velocity = direction * _movement_speed()
			elif distance < preferred_range * 0.72:
				velocity = -direction * _movement_speed()
			else:
				velocity = Vector2.ZERO
			if distance <= _definition.attack_range and _attack_cooldown <= 0.0:
				_charge_direction = direction
				_pending_attack = PendingAttack.PROJECTILE
				_begin_telegraph(maxf(32.0, distance), true)
		Phase.TELEGRAPH:
			velocity = Vector2.ZERO
			_tick_telegraph(delta)
		Phase.RECOVERING:
			velocity = Vector2.ZERO
			_tick_recovery(delta)
		_:
			velocity = Vector2.ZERO


func _tick_boss(delta: float) -> void:
	match _phase:
		Phase.APPROACH:
			_hide_telegraphs()
			var direction: Vector2 = _direction_to_target()
			var distance: float = _distance_to_target()
			if distance > _definition.attack_range * 0.72:
				velocity = direction * _movement_speed()
			else:
				velocity = Vector2.ZERO
			if distance <= _definition.attack_range and _attack_cooldown <= 0.0:
				_pending_attack = _next_boss_attack()
				_charge_direction = direction
				if _pending_attack == PendingAttack.CHARGE:
					_charge_distance = minf(maxf(48.0, _definition.attack_range), distance)
					_begin_telegraph(_charge_distance, true)
				elif _pending_attack == PendingAttack.PROJECTILE:
					_begin_telegraph(maxf(32.0, distance), true)
				else:
					var radius: float = _definition.zone_radius if _pending_attack == PendingAttack.ZONE else maxf(52.0, _definition.attack_range * 0.35)
					_begin_telegraph(radius, false)
		Phase.TELEGRAPH:
			velocity = Vector2.ZERO
			_tick_telegraph(delta)
		Phase.CHARGING:
			velocity = _charge_direction * _charge_speed()
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_begin_recovery()
		Phase.RECOVERING:
			velocity = Vector2.ZERO
			_tick_recovery(delta)
		_:
			velocity = Vector2.ZERO


func _tick_manager_boss(delta: float) -> void:
	match _phase:
		Phase.APPROACH:
			_hide_telegraphs()
			var direction := _direction_to_target()
			var distance := _distance_to_target()
			var target_range := _definition.attack_range * 0.66
			velocity = direction * _manager_move_speed() if distance > target_range else Vector2.ZERO
			if distance <= _definition.attack_range and _attack_cooldown <= 0.0:
				var attack := _manager_next_attack(distance)
				_pending_attack = attack
				_charge_direction = direction
				match attack:
					PendingAttack.CHARGE:
						_charge_distance = minf(maxf(72.0, distance), _definition.attack_range)
						_begin_telegraph(_charge_distance, true)
					PendingAttack.FLAME:
						_begin_telegraph(_definition.zone_radius, false)
					PendingAttack.TETHER:
						_charge_direction = direction
						_begin_telegraph(maxf(80.0, distance), true)
					PendingAttack.SCATTER:
						_begin_telegraph(maxf(88.0, distance), true)
					_:
						_begin_telegraph(_definition.contact_range, false)
		Phase.TELEGRAPH:
			velocity = Vector2.ZERO
			_tick_telegraph(delta)
		Phase.CHARGING:
			_manager_dash_active = true
			velocity = _charge_direction * _charge_speed()
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_manager_dash_active = false
				_begin_recovery()
		Phase.ATTACKING:
			velocity = Vector2.ZERO
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_begin_recovery()
		Phase.RECOVERING:
			velocity = Vector2.ZERO
			_tick_recovery(delta)
		_:
			velocity = Vector2.ZERO


func _manager_next_attack(distance: float) -> PendingAttack:
	# Rotate through a readable cycle. The flame burst is close-range; if the
	# player keeps their distance, the boss dashes instead of firing it early.
	var cycle := _manager_attack_index % 4
	_manager_attack_index += 1
	match cycle:
		0:
			return PendingAttack.CHARGE
		1:
			return PendingAttack.FLAME if distance <= _definition.zone_radius * 1.18 else PendingAttack.CHARGE
		2:
			return PendingAttack.TETHER
		_:
			return PendingAttack.SCATTER


func _next_boss_attack() -> PendingAttack:
	match _definition.attack_type:
		EnemyDefinition.AttackType.CHARGE:
			return PendingAttack.CHARGE
		EnemyDefinition.AttackType.RANGED_PROJECTILE:
			return PendingAttack.PROJECTILE
		EnemyDefinition.AttackType.DROP_ZONE:
			return PendingAttack.ZONE if _boss_next_charge else PendingAttack.SCATTER
		_:
			return PendingAttack.CHARGE if _boss_next_charge else PendingAttack.SCATTER


func _begin_charge(attack: PendingAttack) -> void:
	_pending_attack = attack
	_charge_direction = _direction_to_target()
	_charge_distance = minf(maxf(48.0, _definition.attack_range), _distance_to_target())
	_begin_telegraph(_charge_distance, true)


func _begin_telegraph(radius: float, directional: bool) -> void:
	_phase = Phase.TELEGRAPH
	_phase_timer = maxf(0.12, _definition.telegraph_duration)
	_charge_telegraph.visible = directional
	if directional:
		var telegraph_length: float = maxf(48.0, radius)
		if _pending_attack == PendingAttack.PROJECTILE and _definition.projectile_count > 1:
			var half_spread: float = deg_to_rad(18.0)
			_charge_telegraph.points = PackedVector2Array([
				Vector2.ZERO,
				_charge_direction.rotated(-half_spread) * telegraph_length,
				_charge_direction.rotated(half_spread) * telegraph_length,
				Vector2.ZERO,
			])
		else:
			_charge_telegraph.points = PackedVector2Array([Vector2.ZERO, _charge_direction * telegraph_length])
	_ring_telegraph.visible = not directional
	if not directional:
		_set_ring(_ring_telegraph, radius)
	if _sprite.visible:
		_sprite.modulate = Color(1.0, 0.45, 0.3, 1.0)
	else:
		_fallback_shape.color = Color(1.0, 0.45, 0.3, 1.0)


func _tick_telegraph(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer > 0.0:
		return
	_hide_telegraphs()
	_restore_actor_color()
	match _pending_attack:
		PendingAttack.CHARGE:
			_phase = Phase.CHARGING
			_phase_timer = clampf(_charge_distance / _charge_speed(), 0.22, 0.9)
			_contact_hit_applied = false
			_manager_dash_active = _is_manager_boss()
		PendingAttack.CONTACT:
			_phase = Phase.ATTACKING
			_phase_timer = 0.1
			_contact_hit_applied = false
			if _definition.role == EnemyDefinition.Role.BOSS and _definition.attack_type == EnemyDefinition.AttackType.CHARGE_AND_SCATTER:
				_boss_next_charge = false
		PendingAttack.PROJECTILE:
			_spawn_projectile(_charge_direction)
			if _definition.role == EnemyDefinition.Role.BOSS and _definition.attack_type == EnemyDefinition.AttackType.CHARGE_AND_SCATTER:
				_boss_next_charge = false
			_begin_recovery()
		PendingAttack.ZONE:
			_spawn_slow_patch(global_position, _definition.zone_radius)
			if _definition.role == EnemyDefinition.Role.BOSS and _definition.attack_type == EnemyDefinition.AttackType.DROP_ZONE:
				_boss_next_charge = false
			_begin_recovery()
		PendingAttack.SCATTER:
			if _is_manager_boss():
				_spawn_manager_scatter()
			else:
				_spawn_scatter()
			if _definition.role == EnemyDefinition.Role.BOSS:
				_boss_next_charge = true
			_begin_recovery()
		PendingAttack.FLAME:
			_phase = Phase.ATTACKING
			_phase_timer = 0.42
			_contact_hit_applied = false
			_active_attack_radius = _definition.zone_radius
			_set_attack_radius(_active_attack_radius)
			_ring_telegraph.default_color = Color(1.0, 0.42, 0.08, 0.92)
			_ring_telegraph.visible = true
			stagger_changed.emit(roundi(_manager_poise), roundi(_manager_stagger_threshold()), false)
		PendingAttack.TETHER:
			_spawn_manager_tether()
			_begin_recovery()
		_:
			_phase = Phase.APPROACH


func _begin_recovery() -> void:
	_phase = Phase.RECOVERING
	_phase_timer = maxf(0.15, _definition.recovery_duration)
	_attack_cooldown = maxf(0.2, _contact_attack_interval())
	_pending_attack = PendingAttack.NONE
	_manager_dash_active = false
	if _is_manager_boss():
		_active_attack_radius = 0.0
		_set_attack_radius(_definition.contact_range)
		_hide_telegraphs()


func _tick_recovery(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_phase = Phase.APPROACH
		_restore_actor_color()


func _spawn_projectile(direction: Vector2) -> void:
	var count: int = maxi(1, _definition.projectile_count)
	if count == 1:
		_spawn_projectile_deferred(global_position, direction, _definition.projectile_speed, _scaled_damage(_definition.attack_damage))
		return
	var center_angle: float = direction.angle() if direction.length_squared() > 0.001 else 0.0
	var half_spread: float = deg_to_rad(18.0)
	for index: int in range(count):
		var interpolation: float = float(index) / float(count - 1)
		var angle: float = center_angle + lerpf(-half_spread, half_spread, interpolation)
		_spawn_projectile_deferred(global_position, Vector2.RIGHT.rotated(angle), _definition.projectile_speed, _scaled_damage(_definition.attack_damage, count))


func _spawn_scatter() -> void:
	_spawn_scatter_deferred.call_deferred(global_position, _direction_to_target())


func _spawn_manager_scatter() -> void:
	var aim := _direction_to_target()
	var angle := aim.angle() if aim.length_squared() > 0.001 else 0.0
	var half_spread := deg_to_rad(24.0)
	for index: int in range(3):
		var t := float(index) / 2.0
		var direction := Vector2.RIGHT.rotated(angle + lerpf(-half_spread, half_spread, t))
		_spawn_projectile_deferred(global_position, direction, _definition.projectile_speed, _scaled_damage(_definition.attack_damage, 3))


func _spawn_manager_tether() -> void:
	var projectile := ENEMY_PROJECTILE_SCENE.instantiate() as EnemyProjectile
	if projectile == null:
		return
	projectile.configure(_charge_direction, _definition.projectile_speed, _scaled_damage(_definition.attack_damage), 0.70, 1.2)
	projectile.position = global_position
	var parent: Node = get_tree().current_scene
	if is_instance_valid(parent):
		parent.call_deferred("add_child", projectile)


func _spawn_scatter_deferred(origin: Vector2, aim_direction: Vector2) -> void:
	var count: int = maxi(1, _definition.projectile_count)
	var offset: float = aim_direction.angle() if aim_direction.length_squared() > 0.001 else 0.0
	for index: int in range(count):
		var direction: Vector2 = Vector2.RIGHT.rotated(offset + TAU * float(index) / float(count))
		_spawn_projectile_deferred(origin, direction, _definition.projectile_speed, _scaled_damage(_definition.attack_damage, count))


func _spawn_projectile_deferred(origin: Vector2, direction: Vector2, speed: float, damage: int) -> void:
	var projectile := ENEMY_PROJECTILE_SCENE.instantiate() as EnemyProjectile
	if projectile == null:
		push_error("Enemy projectile scene root must use EnemyProjectile.")
		return
	projectile.configure(direction, speed, damage)
	projectile.position = origin
	var parent: Node = get_tree().current_scene
	if is_instance_valid(parent):
		parent.call_deferred("add_child", projectile)


func _spawn_slow_patch(origin: Vector2, radius: float) -> void:
	_spawn_slow_patch_deferred.call_deferred(origin, radius)


func _spawn_slow_patch_deferred(origin: Vector2, radius: float) -> void:
	var patch := SLOW_PATCH_SCENE.instantiate() as EnemySlowPatch
	if patch == null:
		push_error("Slow patch scene root must use EnemySlowPatch.")
		return
	patch.configure(radius, _definition.zone_duration, _definition.zone_speed_multiplier, _scaled_damage(_definition.attack_damage))
	patch.position = origin
	var parent: Node = get_tree().current_scene
	if is_instance_valid(parent):
		parent.call_deferred("add_child", patch)


func _apply_contact_damage() -> void:
	if not _attack_area.monitoring or _contact_hit_applied or not is_instance_valid(_target):
		return
	var hit_radius := _active_attack_radius if _active_attack_radius > 0.0 else _definition.contact_range
	if global_position.distance_squared_to(_target.global_position) > pow(hit_radius, 2.0):
		return
	if not _attack_area.get_overlapping_bodies().has(_target):
		return
	var damage: int = _scaled_damage(_definition.contact_damage)
	if _phase == Phase.CHARGING and _definition.attack_damage > 0:
		damage = _scaled_damage(_definition.attack_damage)
	if damage > 0 and _target.has_method("take_damage"):
		_target.call("take_damage", damage)
	_contact_hit_applied = true


func _update_attack_area() -> void:
	var attack_is_active := _phase in [Phase.ATTACKING, Phase.CHARGING]
	if _attack_area.monitoring != attack_is_active:
		_attack_area.monitoring = attack_is_active
	if not attack_is_active:
		_contact_hit_applied = false


func _scaled_damage(base_damage: int, simultaneous_projectiles: int = 1) -> int:
	if base_damage <= 0:
		return 0
	var wave_damage := float(base_damage)
	if _definition != null:
		wave_damage += _definition.damage_growth_per_wave * float(maxi(0, mini(_round_number, 20) - 1))
	var scaled_damage: int = maxi(1, roundi(wave_damage * _damage_multiplier))
	if not (_target is SurvivorPlayer):
		return scaled_damage
	var player := _target as SurvivorPlayer
	var hit_fraction: float = BOSS_HIT_MAX_HEALTH_FRACTION if _definition.role == EnemyDefinition.Role.BOSS else NORMAL_HIT_MAX_HEALTH_FRACTION
	if simultaneous_projectiles > 1:
		hit_fraction /= sqrt(float(simultaneous_projectiles))
	var per_hit_limit: int = maxi(1, floori(float(player.max_health) * hit_fraction))
	return mini(scaled_damage, per_hit_limit)


func _scaled_max_health() -> int:
	if _definition == null:
		return 1
	var wave_health := float(_definition.max_health)
	wave_health += _definition.health_growth_per_wave * float(maxi(0, mini(_round_number, 20) - 1))
	return maxi(1, roundi(wave_health * _health_multiplier))


func _defeat() -> void:
	if _phase == Phase.DEFEATED:
		return
	_phase = Phase.DEFEATED
	velocity = Vector2.ZERO
	var death_position: Vector2 = global_position
	defeated.emit(_definition, death_position)
	died.emit(_definition.xp_reward, death_position)
	queue_free()


func _apply_definition() -> void:
	if _definition == null:
		return
	_health = _scaled_max_health()
	health_changed.emit(_health, _health)
	if _definition.directional_walk_atlas:
		_build_walk_animations(_definition.sprite)
	else:
		var still_frames := SpriteFrames.new()
		if still_frames.has_animation("default"):
			still_frames.remove_animation("default")
		still_frames.add_animation("idle_down")
		still_frames.add_frame("idle_down", _definition.sprite)
		_sprite.sprite_frames = still_frames
		_sprite.offset = Vector2.ZERO
	var actor_scale := _definition.sprite_scale
	if _definition.role == EnemyDefinition.Role.BOSS and not _definition.directional_walk_atlas:
		actor_scale = maxf(actor_scale, 0.23)
	_sprite.scale = Vector2.ONE * actor_scale
	_sprite.visible = _definition.sprite != null
	_fallback_shape.visible = _definition.sprite == null
	_apply_fallback_look()
	_set_collision_radius(_body_radius())
	_set_attack_radius(_definition.contact_range)
	_attack_cooldown = minf(_attack_cooldown, _contact_attack_interval())
	if _definition.directional_walk_atlas and _definition.sprite != null:
		_sprite.play("idle_down")
	if _is_manager_boss():
		stagger_changed.emit(0, roundi(_manager_stagger_threshold()), false)


func _build_walk_animations(atlas: Texture2D) -> void:
	if atlas == null:
		return
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var cell_size := Vector2(atlas.get_size()) / Vector2(WALK_COLUMNS, WALK_ROWS)
	var direction_rows: Dictionary = {&"up": 0, &"left": 1, &"right": 2, &"down": 3}
	for direction: StringName in direction_rows:
		var row: int = direction_rows[direction]
		var walk_name := StringName("walk_" + String(direction))
		var idle_name := StringName("idle_" + String(direction))
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, WALK_ANIMATION_SPEED)
		frames.set_animation_loop(walk_name, true)
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 1.0)
		frames.set_animation_loop(idle_name, true)
		for column: int in WALK_FRAMES_PER_DIRECTION:
			var atlas_frame := AtlasTexture.new()
			atlas_frame.atlas = atlas
			atlas_frame.region = Rect2(Vector2(column, row) * cell_size, cell_size)
			frames.add_frame(walk_name, atlas_frame)
			if column == 0:
				frames.add_frame(idle_name, atlas_frame)
	_sprite.sprite_frames = frames
	_sprite.offset = Vector2(0.0, -149.0)


func _update_walk_animation(movement: Vector2) -> void:
	if _sprite.sprite_frames == null or not _definition.directional_walk_atlas:
		return
	if movement.length_squared() > 0.01:
		if absf(movement.x) > absf(movement.y):
			_facing = &"right" if movement.x > 0.0 else &"left"
		else:
			_facing = &"down" if movement.y > 0.0 else &"up"
		_sprite.play(StringName("walk_" + String(_facing)))
	else:
		_sprite.play(StringName("idle_" + String(_facing)))


func _apply_fallback_look() -> void:
	var points := PackedVector2Array()
	var color := Color("b97852")
	match _definition.role:
		EnemyDefinition.Role.CHARGER:
			points = PackedVector2Array([Vector2(-17, -11), Vector2(13, -15), Vector2(20, 0), Vector2(13, 15), Vector2(-17, 11)])
			color = Color("db9c42")
		EnemyDefinition.Role.AREA_DENIAL:
			points = PackedVector2Array([Vector2(-14, -18), Vector2(14, -18), Vector2(18, -13), Vector2(18, 13), Vector2(14, 18), Vector2(-14, 18), Vector2(-18, 13), Vector2(-18, -13)])
			color = Color("7ac6dc")
		EnemyDefinition.Role.RANGED:
			points = PackedVector2Array([Vector2(0, -20), Vector2(17, -10), Vector2(17, 10), Vector2(0, 20), Vector2(-17, 10), Vector2(-17, -10)])
			color = Color("b36ace")
		EnemyDefinition.Role.BOSS:
			points = PackedVector2Array([Vector2(-26, -22), Vector2(16, -22), Vector2(28, -12), Vector2(28, 12), Vector2(16, 22), Vector2(-26, 22)])
			color = Color("d5483c")
	_fallback_shape.polygon = points
	_fallback_shape.color = color
	_charge_telegraph.default_color = Color(1.0, 0.2, 0.12, 0.85)
	_ring_telegraph.default_color = Color(1.0, 0.5, 0.16, 0.72)


func _set_collision_radius(radius: float) -> void:
	var shape := _collision.shape as CircleShape2D
	if shape == null:
		shape = CircleShape2D.new()
		_collision.shape = shape
	else:
		shape = shape.duplicate() as CircleShape2D
		_collision.shape = shape
	shape.radius = radius


func _set_attack_radius(radius: float) -> void:
	var shape := _attack_area_shape.shape as CircleShape2D
	if shape == null:
		shape = CircleShape2D.new()
		_attack_area_shape.shape = shape
	else:
		shape = shape.duplicate() as CircleShape2D
		_attack_area_shape.shape = shape
	shape.radius = maxf(1.0, radius)


func _body_radius() -> float:
	match _definition.role:
		EnemyDefinition.Role.AREA_DENIAL:
			return 22.0
		EnemyDefinition.Role.BOSS:
			return 30.0
		_:
			return 18.0


func _charge_speed() -> float:
	return maxf(90.0, _definition.charge_speed)


func _contact_attack_interval() -> float:
	if _definition != null and _definition.role == EnemyDefinition.Role.CHASER:
		return _definition.contact_interval
	return _definition.attack_interval if _definition != null else 1.0


func _direction_to_target() -> Vector2:
	if not is_instance_valid(_target):
		return Vector2.RIGHT
	return global_position.direction_to(_target.global_position)


func _distance_to_target() -> float:
	if not is_instance_valid(_target):
		return INF
	return global_position.distance_to(_target.global_position)


func _tick_slow_effects(delta: float) -> void:
	for effect_id: Variant in _slow_effects.keys():
		var effect: Dictionary = _slow_effects[effect_id]
		effect["remaining"] = float(effect["remaining"]) - delta
		if float(effect["remaining"]) <= 0.0:
			_slow_effects.erase(effect_id)
		else:
			_slow_effects[effect_id] = effect


func _movement_speed() -> float:
	if _definition == null:
		return 0.0
	var multiplier := 1.0
	for effect: Dictionary in _slow_effects.values():
		multiplier = minf(multiplier, float(effect.get("multiplier", 1.0)))
	if _is_manager_boss() and _manager_slow_timer > 0.0:
		multiplier = minf(multiplier, 0.55)
	return _definition.move_speed * multiplier * _difficulty_speed_multiplier


func _manager_move_speed() -> float:
	return _movement_speed()


func _is_manager_boss() -> bool:
	return _definition != null and _definition.role == EnemyDefinition.Role.BOSS \
		and _definition.attack_type == EnemyDefinition.AttackType.MANAGER_CYCLE and _definition.immortal


func _manager_stagger_threshold() -> float:
	var threshold := 120.0
	if not is_instance_valid(_target):
		return threshold
	if _target is SurvivorPlayer:
		var player := _target as SurvivorPlayer
		threshold += float(player.current_level) * 6.0
		threshold += float(player.get_melee_damage() + player.get_ranged_damage()) * 3.0
		threshold += float(player.get_elemental_damage()) * 8.0
		threshold += maxf(0.0, player.get_attack_damage_multiplier() - 1.0) * 55.0
		for weapon_state: Dictionary in player.get_level_choice_weapon_targets():
			threshold += float(maxi(0, int(weapon_state.get("tier", 1)) - 1)) * 12.0
			threshold += float(maxi(0, int(weapon_state.get("level_damage_add", 0)))) * 2.0
	return clampf(threshold, 120.0, 360.0)


func _begin_manager_stagger(from_wall: bool) -> void:
	if not _is_manager_boss():
		return
	_manager_dash_active = false
	_phase = Phase.RECOVERING
	_phase_timer = 1.35 if from_wall else 1.1
	_manager_stagger_timer = _phase_timer
	_manager_slow_timer = 0.0
	_attack_cooldown = maxf(_attack_cooldown, 1.1)
	_pending_attack = PendingAttack.NONE
	velocity = Vector2.ZERO
	_hide_telegraphs()
	if _sprite.visible:
		_sprite.modulate = Color(1.0, 0.78, 0.48, 1.0)
	else:
		_fallback_shape.color = Color(1.0, 0.78, 0.48, 1.0)
	stagger_changed.emit(roundi(_manager_poise), roundi(_manager_stagger_threshold()), true)


func _find_player() -> Node2D:
	for candidate: Node in get_tree().get_nodes_in_group(PLAYER_GROUP):
		if candidate is Node2D:
			return candidate as Node2D
	return null


func _set_ring(line: Line2D, radius: float) -> void:
	var points := PackedVector2Array()
	for index: int in range(33):
		var angle: float = TAU * float(index) / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * maxf(12.0, radius))
	line.points = points


func _hide_telegraphs() -> void:
	_charge_telegraph.visible = false
	_ring_telegraph.visible = false


func _flash_hit() -> void:
	if _sprite.visible:
		_sprite.modulate = Color(1.8, 1.8, 1.8, 1.0)
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	else:
		_fallback_shape.color = Color.WHITE
		var tween := create_tween()
		tween.tween_property(_fallback_shape, "color", Color("b97852"), 0.12)


func _restore_actor_color() -> void:
	if _sprite.visible:
		_sprite.modulate = Color.WHITE
	else:
		_apply_fallback_look()
