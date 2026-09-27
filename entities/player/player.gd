extends CharacterBody2D
class_name SurvivorPlayer

signal health_changed(current: int, maximum: int)
signal progress_changed(xp: int, needed: int, level: int)
signal level_up(new_level: int)
signal upgrade_applied(upgrade: UpgradeDefinition, rank: int)
signal died

@export var move_speed: float = 220.0
@export var max_health: int = 100
@export var starting_xp_to_next_level: int = 5
@export var level_xp_growth: float = 1.35
@export var level_up_heal: int = 10
@export var walk_atlas: Texture2D

const WALK_COLUMNS := 4
const WALK_ROWS := 4
const WALK_FRAMES_PER_DIRECTION := 4
const WALK_ANIMATION_SPEED := 8.0

var current_health: int
var current_xp: int = 0
var current_level: int = 1
var _xp_required: int
var _is_dead: bool = false
var _move_speed_multiplier: float = 1.0
var _life_steal_fraction: float = 0.0
var _life_steal_remainder: float = 0.0
var _dodge_chance: float = 0.0
var _protection_fraction: float = 0.0
var _slow_effects: Dictionary = {}
var _speed_boosts: Dictionary = {}
var _next_slow_id: int = 1
var _next_speed_boost_id: int = 1
var _upgrade_ranks: Dictionary = {}
var _weapon_controller: SurvivorAutoWeapon
var _facing: StringName = &"down"
@onready var _sprite: AnimatedSprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("player")
	_build_walk_animations()
	_weapon_controller = get_node_or_null("AutoWeapon") as SurvivorAutoWeapon
	current_health = maxi(1, max_health)
	max_health = current_health
	_xp_required = maxi(1, starting_xp_to_next_level)
	health_changed.emit(current_health, max_health)
	progress_changed.emit(current_xp, _xp_required, current_level)


func _physics_process(delta: float) -> void:
	_update_slow_effects(delta)
	if _is_dead:
		velocity = Vector2.ZERO
		return

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * get_effective_move_speed()
	_update_walk_animation(direction)
	move_and_slide()


func _build_walk_animations() -> void:
	if walk_atlas == null:
		return
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var cell_size := Vector2(walk_atlas.get_size()) / Vector2(WALK_COLUMNS, WALK_ROWS)
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
			atlas_frame.atlas = walk_atlas
			atlas_frame.region = Rect2(Vector2(column, row) * cell_size, cell_size)
			frames.add_frame(walk_name, atlas_frame)
			if column == 0:
				frames.add_frame(idle_name, atlas_frame)
	_sprite.sprite_frames = frames
	_sprite.play("idle_down")


func _update_walk_animation(direction: Vector2) -> void:
	if direction.length_squared() > 0.01:
		if absf(direction.x) > absf(direction.y):
			_facing = &"right" if direction.x > 0.0 else &"left"
		else:
			_facing = &"down" if direction.y > 0.0 else &"up"
		_sprite.play(StringName("walk_" + String(_facing)))
	else:
		_sprite.play(StringName("idle_" + String(_facing)))


func take_damage(amount: int) -> void:
	if _is_dead or amount <= 0:
		return
	if _dodge_chance > 0.0 and randf() < _dodge_chance:
		return

	var protected_damage: int = maxi(1, roundi(float(amount) * (1.0 - _protection_fraction)))
	current_health = maxi(0, current_health - protected_damage)
	BakkalAudio.play_sfx(&"player_hurt")
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		_is_dead = true
		velocity = Vector2.ZERO
		died.emit()


func gain_xp(amount: int) -> void:
	if _is_dead or amount <= 0:
		return

	current_xp += amount
	while current_xp >= _xp_required:
		current_xp -= _xp_required
		current_level += 1
		_xp_required = maxi(_xp_required + 1, ceili(float(_xp_required) * maxf(1.0, level_xp_growth)))
		level_up.emit(current_level)

	progress_changed.emit(current_xp, _xp_required, current_level)


func apply_upgrade(upgrade: UpgradeDefinition) -> bool:
	if _is_dead or upgrade == null or upgrade.id == &"":
		return false
	var current_rank: int = get_upgrade_rank(upgrade.id)
	if current_rank >= maxi(1, upgrade.max_rank):
		return false
	var applied: bool = false
	match upgrade.effect:
		UpgradeDefinition.Effect.UNLOCK_WEAPON:
			applied = is_instance_valid(_weapon_controller) and _weapon_controller.unlock_weapon(upgrade.unlocks_weapon)
		UpgradeDefinition.Effect.PLAYER_MOVE_SPEED_MULTIPLIER:
			_move_speed_multiplier *= maxf(0.05, 1.0 + upgrade.value)
			applied = true
		UpgradeDefinition.Effect.PLAYER_MAX_HEALTH_ADD:
			var increase: int = maxi(0, roundi(upgrade.value))
			max_health += increase
			current_health = mini(max_health, current_health + maxi(0, roundi(upgrade.immediate_heal)))
			health_changed.emit(current_health, max_health)
			applied = increase > 0 or upgrade.immediate_heal > 0.0
		UpgradeDefinition.Effect.PLAYER_LIFESTEAL_ADD:
			var previous_lifesteal := _life_steal_fraction
			_life_steal_fraction = minf(0.25, _life_steal_fraction + maxf(0.0, upgrade.value))
			applied = _life_steal_fraction > previous_lifesteal
		UpgradeDefinition.Effect.PLAYER_DODGE_ADD:
			var previous_dodge := _dodge_chance
			_dodge_chance = minf(0.6, _dodge_chance + maxf(0.0, upgrade.value))
			applied = _dodge_chance > previous_dodge
		_:
			applied = is_instance_valid(_weapon_controller) and _weapon_controller.apply_upgrade(upgrade)
	if not applied:
		return false
	current_rank += 1
	_upgrade_ranks[upgrade.id] = current_rank
	upgrade_applied.emit(upgrade, current_rank)
	return true


func get_upgrade_rank(upgrade_id: StringName) -> int:
	return int(_upgrade_ranks.get(upgrade_id, 0))


func apply_level_stat(choice_id: StringName, value: float) -> bool:
	if _is_dead or not can_apply_level_stat(choice_id):
		return false
	match choice_id:
		&"speed":
			_move_speed_multiplier *= 1.0 + maxf(0.0, value)
		&"health":
			var increase := maxi(1, roundi(value))
			max_health += increase
			current_health = mini(max_health, current_health + increase)
			health_changed.emit(current_health, max_health)
		&"lifesteal":
			_life_steal_fraction = minf(0.25, _life_steal_fraction + maxf(0.0, value))
		&"dodge":
			_dodge_chance = minf(0.6, _dodge_chance + maxf(0.0, value))
		&"protection":
			_protection_fraction = minf(0.3, _protection_fraction + maxf(0.0, value))
		_:
			return false
	return true


func can_apply_level_stat(choice_id: StringName) -> bool:
	if _is_dead:
		return false
	match choice_id:
		&"speed", &"health":
			return true
		&"lifesteal":
			return _life_steal_fraction < 0.25
		&"dodge":
			return _dodge_chance < 0.6
		&"protection":
			return _protection_fraction < 0.3
	return false


func recover_from_damage_dealt(damage: int) -> void:
	if _is_dead or damage <= 0 or _life_steal_fraction <= 0.0 or current_health >= max_health:
		return
	_life_steal_remainder += float(damage) * _life_steal_fraction
	var recovery := floori(_life_steal_remainder)
	if recovery <= 0:
		return
	_life_steal_remainder -= float(recovery)
	current_health = mini(max_health, current_health + recovery)
	health_changed.emit(current_health, max_health)


func get_effective_move_speed() -> float:
	var strongest_slow: float = 1.0
	for effect: Variant in _slow_effects.values():
		strongest_slow = minf(strongest_slow, float(effect.get("multiplier", 1.0)))
	var strongest_boost: float = 1.0
	for effect: Variant in _speed_boosts.values():
		strongest_boost = maxf(strongest_boost, float(effect.get("multiplier", 1.0)))
	return maxf(0.0, move_speed * _move_speed_multiplier * strongest_boost * strongest_slow)


func get_survivability_profile() -> Dictionary:
	## Runtime snapshot for systems that need to adapt encounter pressure without
	## reaching into private player state. Returned values do not mutate the actor.
	return {
		"max_health": max_health,
		"current_health": current_health,
		"dodge_chance": _dodge_chance,
		"lifesteal_fraction": _life_steal_fraction,
		"protection_fraction": _protection_fraction,
		"effective_move_speed": get_effective_move_speed(),
	}


func heal(amount: int) -> int:
	if _is_dead or amount <= 0:
		return 0
	var old_health: int = current_health
	current_health = mini(max_health, current_health + amount)
	var restored: int = current_health - old_health
	if restored > 0:
		health_changed.emit(current_health, max_health)
	return restored


func apply_slow(multiplier: float, duration: float) -> int:
	if _is_dead or duration <= 0.0:
		return -1
	var effect_id: int = _next_slow_id
	_next_slow_id += 1
	_slow_effects[effect_id] = {
		"multiplier": clampf(multiplier, 0.05, 1.0),
		"remaining": duration,
	}
	return effect_id


func apply_speed_boost(multiplier: float, duration: float) -> int:
	if _is_dead or duration <= 0.0:
		return -1
	var effect_id: int = _next_speed_boost_id
	_next_speed_boost_id += 1
	_speed_boosts[effect_id] = {
		"multiplier": maxf(1.0, multiplier),
		"remaining": duration,
	}
	return effect_id


func _update_slow_effects(delta: float) -> void:
	_update_timed_modifiers(_slow_effects, delta)
	_update_timed_modifiers(_speed_boosts, delta)


func _update_timed_modifiers(effects: Dictionary, delta: float) -> void:
	var expired: Array[int] = []
	for effect_id: Variant in effects.keys():
		var effect: Dictionary = effects[effect_id]
		effect["remaining"] = float(effect.get("remaining", 0.0)) - delta
		if float(effect["remaining"]) <= 0.0:
			expired.append(int(effect_id))
		else:
			effects[effect_id] = effect
	for effect_id: int in expired:
		effects.erase(effect_id)


func get_save_data() -> Dictionary:
	return {
		"current_health": current_health,
		"max_health": max_health,
		"current_level": current_level,
		"current_xp": current_xp,
		"xp_required": _xp_required,
		"move_speed_multiplier": _move_speed_multiplier,
		"life_steal_fraction": _life_steal_fraction,
		"dodge_chance": _dodge_chance,
		"protection_fraction": _protection_fraction,
		"upgrade_ranks": _upgrade_ranks.duplicate(),
	}


func restore_save_data(data: Dictionary) -> void:
	max_health = maxi(1, int(data.get("max_health", max_health)))
	current_health = clampi(int(data.get("current_health", max_health)), 1, max_health)
	current_level = maxi(1, int(data.get("current_level", 1)))
	current_xp = maxi(0, int(data.get("current_xp", 0)))
	_xp_required = maxi(1, int(data.get("xp_required", starting_xp_to_next_level)))
	_move_speed_multiplier = float(data.get("move_speed_multiplier", 1.0))
	_life_steal_fraction = float(data.get("life_steal_fraction", 0.0))
	_dodge_chance = float(data.get("dodge_chance", 0.0))
	_protection_fraction = float(data.get("protection_fraction", 0.0))
	_upgrade_ranks = (data.get("upgrade_ranks", {}) as Dictionary).duplicate()
	health_changed.emit(current_health, max_health)
	progress_changed.emit(current_xp, _xp_required, current_level)
