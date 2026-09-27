class_name EnemyActor
extends CharacterBody2D
## One runtime actor for the authored enemy roster. Its Resource input is read-only;
## mutable health, timers, and attack state live on this instance.

signal defeated(definition: EnemyDefinition, world_position: Vector2)
signal health_changed(current: int, maximum: int)
## Compatibility signal for arena code that consumes an XP amount directly.
signal died(xp_reward: int, world_position: Vector2)

enum Phase { APPROACH, TELEGRAPH, CHARGING, RECOVERING, DEFEATED }
enum PendingAttack { NONE, CHARGE, PROJECTILE, ZONE, SCATTER }

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

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _fallback_shape: Polygon2D = $FallbackShape
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _charge_telegraph: Line2D = $ChargeTelegraph
@onready var _ring_telegraph: Line2D = $RingTelegraph

var _definition: EnemyDefinition
var _target: Node2D
var _health: int = 1
var _health_multiplier: float = 1.0
var _damage_multiplier: float = 1.0
var _contact_cooldown: float = 0.0
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


func configure(definition: EnemyDefinition, health_multiplier: float, target: Node2D, damage_multiplier: float = 1.0) -> void:
	_definition = definition
	_health_multiplier = maxf(0.1, health_multiplier)
	_damage_multiplier = maxf(0.0, damage_multiplier)
	_target = target
	if _definition != null:
		_health = maxi(1, roundi(float(_definition.max_health) * _health_multiplier))
		_attack_cooldown = minf(0.7, _definition.attack_interval * 0.25)
	if is_inside_tree():
		_apply_definition()


func get_definition() -> EnemyDefinition:
	return _definition


func get_health() -> int:
	return _health


func take_damage(amount: int) -> void:
	if _phase == Phase.DEFEATED or amount <= 0:
		return
	_health = maxi(0, _health - amount)
	if _definition != null:
		health_changed.emit(_health, maxi(1, roundi(float(_definition.max_health) * _health_multiplier)))
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
	_contact_cooldown = maxf(0.0, _contact_cooldown - delta)
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
			_tick_chaser()
		EnemyDefinition.Role.CHARGER:
			_tick_charger(delta)
		EnemyDefinition.Role.RANGED:
			_tick_ranged(delta)
		EnemyDefinition.Role.AREA_DENIAL:
			_tick_area_denial(delta)
		EnemyDefinition.Role.BOSS:
			_tick_boss(delta)
			
	if _phase != Phase.DEFEATED:
		if _phase == Phase.APPROACH:
			velocity = _steer_around_obstacles(velocity)
		move_and_slide()
		_update_walk_animation(velocity)
		_apply_contact_damage()


func _steer_around_obstacles(desired_velocity: Vector2) -> Vector2:
	if desired_velocity.is_zero_approx() or get_slide_collision_count() == 0:
		return desired_velocity
	var col := get_slide_collision(0)
	var normal := col.get_normal()
	var desired_dir := desired_velocity.normalized()
	var dot := desired_dir.dot(-normal)
	if dot > 0.15:
		var tangent_a := Vector2(-normal.y, normal.x)
		var tangent_b := Vector2(normal.y, -normal.x)
		var best_tangent := tangent_a if desired_dir.dot(tangent_a) > desired_dir.dot(tangent_b) else tangent_b
		var slide_dir := (best_tangent * 0.8 + normal * 0.2).normalized()
		return slide_dir * desired_velocity.length()
	return desired_velocity


func _tick_chaser() -> void:
	_phase = Phase.APPROACH
	_pending_attack = PendingAttack.NONE
	_hide_telegraphs()
	velocity = _direction_to_target() * _movement_speed()


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
			_spawn_scatter()
			if _definition.role == EnemyDefinition.Role.BOSS:
				_boss_next_charge = true
			_begin_recovery()
		_:
			_phase = Phase.APPROACH


func _begin_recovery() -> void:
	_phase = Phase.RECOVERING
	_phase_timer = maxf(0.15, _definition.recovery_duration)
	_attack_cooldown = maxf(0.2, _definition.attack_interval)
	_pending_attack = PendingAttack.NONE


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
	if _contact_cooldown > 0.0 or not is_instance_valid(_target):
		return
	if global_position.distance_squared_to(_target.global_position) > pow(_definition.contact_range, 2.0):
		return
	var damage: int = _scaled_damage(_definition.contact_damage)
	if _phase == Phase.CHARGING and _definition.attack_damage > 0:
		damage = _scaled_damage(_definition.attack_damage)
	if _target.has_method("take_damage"):
		_target.call("take_damage", damage)
	_contact_cooldown = maxf(0.05, _definition.contact_interval)


func _scaled_damage(base_damage: int, simultaneous_projectiles: int = 1) -> int:
	if base_damage <= 0:
		return 0
	var scaled_damage: int = maxi(1, roundi(float(base_damage) * _damage_multiplier))
	if not (_target is SurvivorPlayer):
		return scaled_damage
	var player := _target as SurvivorPlayer
	var hit_fraction: float = BOSS_HIT_MAX_HEALTH_FRACTION if _definition.role == EnemyDefinition.Role.BOSS else NORMAL_HIT_MAX_HEALTH_FRACTION
	if simultaneous_projectiles > 1:
		hit_fraction /= sqrt(float(simultaneous_projectiles))
	var per_hit_limit: int = maxi(1, floori(float(player.max_health) * hit_fraction))
	return mini(scaled_damage, per_hit_limit)


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
	_health = maxi(1, roundi(float(_definition.max_health) * _health_multiplier))
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
	var actor_scale := 0.2
	if _definition.role == EnemyDefinition.Role.BOSS:
		actor_scale = 0.23
	elif _definition.role == EnemyDefinition.Role.AREA_DENIAL:
		actor_scale = 0.2
	_sprite.scale = Vector2.ONE * actor_scale
	_sprite.visible = _definition.sprite != null
	_fallback_shape.visible = _definition.sprite == null
	_apply_fallback_look()
	_set_collision_radius(_body_radius())
	_attack_cooldown = minf(_attack_cooldown, _definition.attack_interval)
	if _definition.directional_walk_atlas:
		_sprite.play("idle_down")


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
	return _definition.move_speed * multiplier


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
