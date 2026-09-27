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
var _damage_multiplier: float = 1.0
var _elemental_damage: int = 0
var _engineering: int = 0
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
var _mobile_controls: MobileTouchControls
@onready var _sprite: AnimatedSprite2D = $Sprite2D
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	_build_walk_animations()
	_weapon_controller = get_node_or_null("AutoWeapon") as SurvivorAutoWeapon
	current_health = maxi(1, max_health)
	max_health = current_health
	_xp_required = maxi(1, starting_xp_to_next_level)
	_update_mobile_camera_fit()
	get_viewport().size_changed.connect(_update_mobile_camera_fit)
	health_changed.emit(current_health, max_health)
	progress_changed.emit(current_xp, _xp_required, current_level)


func _update_mobile_camera_fit() -> void:
	if not is_instance_valid(_camera) or not (OS.has_feature("android") or OS.has_feature("ios")):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	# Room art is 1672×941 at a 0.7655 scale (~1280×720 world units).
	# Zoom to cover the full screen on phones/tablets; crop a little at unusual
	# aspect ratios instead of exposing an empty gray border around the store.
	var fit_zoom := maxf(viewport_size.x / 1279.9, viewport_size.y / 720.0)
	_camera.zoom = Vector2(fit_zoom, fit_zoom)


func _physics_process(delta: float) -> void:
	_update_slow_effects(delta)
	if _is_dead:
		velocity = Vector2.ZERO
		return

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not is_instance_valid(_mobile_controls):
		_mobile_controls = get_tree().get_first_node_in_group("mobile_controls") as MobileTouchControls
	if is_instance_valid(_mobile_controls):
		var touch_direction := _mobile_controls.get_move_direction()
		if not touch_direction.is_zero_approx():
			direction = touch_direction
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
	if not can_apply_upgrade(upgrade):
		return false
	var current_rank: int = get_upgrade_rank(upgrade.id)
	var applied: bool = false
	match upgrade.effect:
		UpgradeDefinition.Effect.UNLOCK_WEAPON:
			applied = is_instance_valid(_weapon_controller) and _weapon_controller.unlock_weapon(upgrade.unlocks_weapon)
		UpgradeDefinition.Effect.PLAYER_MOVE_SPEED_MULTIPLIER:
			_move_speed_multiplier = clampf(_move_speed_multiplier * maxf(0.05, 1.0 + upgrade.value), 0.45, 1.8)
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
		UpgradeDefinition.Effect.PLAYER_ENGINEERING_ADD:
			var previous_engineering := _engineering
			_engineering = mini(60, _engineering + maxi(0, roundi(upgrade.value)))
			applied = _engineering > previous_engineering
		_:
			applied = is_instance_valid(_weapon_controller) and _weapon_controller.apply_upgrade(upgrade)
	if not applied:
		return false
	current_rank += 1
	_upgrade_ranks[upgrade.id] = current_rank
	upgrade_applied.emit(upgrade, current_rank)
	return true


func can_apply_upgrade(upgrade: UpgradeDefinition) -> bool:
	if _is_dead or upgrade == null or upgrade.id == &"" or get_upgrade_rank(upgrade.id) >= maxi(1, upgrade.max_rank):
		return false
	match upgrade.effect:
		UpgradeDefinition.Effect.UNLOCK_WEAPON:
			return is_instance_valid(_weapon_controller) and upgrade.unlocks_weapon != null and not _weapon_controller.has_weapon(upgrade.unlocks_weapon.id) and _weapon_controller.get_weapon_slot_count() < SurvivorAutoWeapon.MAX_WEAPON_SLOTS
		UpgradeDefinition.Effect.PLAYER_LIFESTEAL_ADD:
			var next_lifesteal := _life_steal_fraction + maxf(0.0, upgrade.value)
			return next_lifesteal > _life_steal_fraction and next_lifesteal <= 0.25
		UpgradeDefinition.Effect.PLAYER_DODGE_ADD:
			var next_dodge := _dodge_chance + maxf(0.0, upgrade.value)
			return next_dodge > _dodge_chance and next_dodge <= 0.6
		UpgradeDefinition.Effect.PLAYER_ENGINEERING_ADD:
			var increase := maxi(0, roundi(upgrade.value))
			return increase > 0 and _engineering + increase <= 60
		UpgradeDefinition.Effect.PLAYER_MAX_HEALTH_ADD:
			return roundi(upgrade.value) > 0 or upgrade.immediate_heal > 0.0
		UpgradeDefinition.Effect.PLAYER_MOVE_SPEED_MULTIPLIER:
			var next_speed := _move_speed_multiplier * maxf(0.05, 1.0 + upgrade.value)
			return next_speed > _move_speed_multiplier and next_speed <= 1.8
		_:
			if not is_instance_valid(_weapon_controller):
				return false
			if upgrade.target_weapon_id != &"":
				return _weapon_controller.has_weapon(upgrade.target_weapon_id)
			return _weapon_controller.get_weapon_slot_count() > 0


func get_upgrade_rank(upgrade_id: StringName) -> int:
	return int(_upgrade_ranks.get(upgrade_id, 0))


func apply_level_stat(choice_id: StringName, value: float) -> bool:
	if not can_apply_level_stat_delta(choice_id, value):
		return false
	match choice_id:
		&"speed":
			_move_speed_multiplier = clampf(_move_speed_multiplier * (1.0 + maxf(0.0, value)), 0.45, 1.8)
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


func apply_level_choice(choice: Dictionary) -> bool:
	if not can_apply_level_choice(choice):
		return false
	var effects: Array = choice.get("effects", [])
	for effect: Dictionary in effects:
		var stat_id := StringName(String(effect.get("stat", "")))
		if stat_id in [&"weapon_damage", &"weapon_fire_rate"]:
			if is_instance_valid(_weapon_controller):
				_weapon_controller.apply_level_weapon_effect(effect)
		else:
			_apply_stat_delta(stat_id, float(effect.get("value", 0.0)))
	return true


func can_apply_level_choice(choice: Dictionary) -> bool:
	if _is_dead:
		return false
	var effects: Array = choice.get("effects", [])
	if effects.is_empty():
		return false
	for effect: Variant in effects:
		if not effect is Dictionary:
			return false
		var stat_id := StringName(String(effect.get("stat", "")))
		var value := float(effect.get("value", 0.0))
		if not _is_supported_level_stat(stat_id):
			return false
		if not _level_delta_changes_stat(stat_id, value, effect):
			return false
	return true


func _is_supported_level_stat(stat_id: StringName) -> bool:
	return stat_id in [&"max_health", &"damage", &"elemental_damage", &"engineering", &"move_speed", &"lifesteal", &"dodge", &"protection", &"weapon_damage", &"weapon_fire_rate"]


func _level_delta_changes_stat(stat_id: StringName, value: float, effect: Dictionary = {}) -> bool:
	match stat_id:
		&"weapon_damage", &"weapon_fire_rate":
			return is_instance_valid(_weapon_controller) and _weapon_controller.can_apply_level_weapon_effect(effect)
		&"max_health":
			return roundi(value) != 0 and max_health + roundi(value) >= 1
		&"damage":
			var next_damage := _damage_multiplier * (1.0 + value)
			return next_damage >= 0.25 and next_damage <= 2.5 and not is_equal_approx(_damage_multiplier, next_damage)
		&"elemental_damage":
			return roundi(value) > 0 and _elemental_damage + roundi(value) <= 99
		&"engineering":
			return roundi(value) > 0 and _engineering + roundi(value) <= 60
		&"move_speed":
			var next_speed := _move_speed_multiplier * (1.0 + value)
			return next_speed >= 0.45 and next_speed <= 1.8 and not is_equal_approx(_move_speed_multiplier, next_speed)
		&"lifesteal":
			var next_lifesteal := _life_steal_fraction + value
			return next_lifesteal >= 0.0 and next_lifesteal <= 0.25 and not is_equal_approx(_life_steal_fraction, next_lifesteal)
		&"dodge":
			var next_dodge := _dodge_chance + value
			return next_dodge >= 0.0 and next_dodge <= 0.6 and not is_equal_approx(_dodge_chance, next_dodge)
		&"protection":
			var next_protection := _protection_fraction + value
			return next_protection >= 0.0 and next_protection <= 0.3 and not is_equal_approx(_protection_fraction, next_protection)
	return false


func _apply_stat_delta(stat_id: StringName, value: float) -> void:
	match stat_id:
		&"max_health":
			max_health = maxi(1, max_health + roundi(value))
			current_health = mini(current_health, max_health)
			health_changed.emit(current_health, max_health)
		&"damage":
			_damage_multiplier = clampf(_damage_multiplier * (1.0 + value), 0.25, 2.5)
		&"elemental_damage":
			_elemental_damage = mini(99, _elemental_damage + maxi(1, roundi(value)))
		&"engineering":
			_engineering = mini(60, _engineering + maxi(1, roundi(value)))
		&"move_speed":
			_move_speed_multiplier = clampf(_move_speed_multiplier * (1.0 + value), 0.45, 1.8)
		&"lifesteal":
			_life_steal_fraction = clampf(_life_steal_fraction + value, 0.0, 0.25)
		&"dodge":
			_dodge_chance = clampf(_dodge_chance + value, 0.0, 0.6)
		&"protection":
			_protection_fraction = clampf(_protection_fraction + value, 0.0, 0.3)


func get_attack_damage_multiplier() -> float:
	return _damage_multiplier


func get_elemental_damage() -> int:
	return _elemental_damage


func get_engineering() -> int:
	return _engineering


func get_level_choice_weapon_targets() -> Array[Dictionary]:
	if not is_instance_valid(_weapon_controller):
		return []
	return _weapon_controller.get_level_choice_weapon_targets()


func get_shop_summary() -> Dictionary:
	var weapon_training: Array[String] = []
	if is_instance_valid(_weapon_controller):
		for target: Dictionary in _weapon_controller.get_level_choice_weapon_targets():
			var damage_add := int(target.get("level_damage_add", 0))
			var fire_rate_bonus := float(target.get("level_fire_rate_bonus", 0.0))
			if damage_add == 0 and fire_rate_bonus <= 0.0:
				continue
			var training_text := String(target.get("name", "Weapon"))
			var modifiers: Array[String] = []
			if damage_add != 0:
				modifiers.append("%+d dmg" % damage_add)
			if fire_rate_bonus > 0.0:
				modifiers.append("+%d%% rate" % roundi(fire_rate_bonus * 100.0))
			weapon_training.append("%s %s" % [training_text, "/".join(modifiers)])
	return {
		"level": current_level,
		"health": "%d / %d" % [current_health, max_health],
		"damage": "%+d%%" % roundi((_damage_multiplier - 1.0) * 100.0),
		"elemental_damage": str(_elemental_damage),
		"engineering": str(_engineering),
		"speed": "%+d%%" % roundi((_move_speed_multiplier - 1.0) * 100.0),
		"lifesteal": "%d%%" % roundi(_life_steal_fraction * 100.0),
		"dodge": "%d%%" % roundi(_dodge_chance * 100.0),
		"protection": "%d%%" % roundi(_protection_fraction * 100.0),
		"weapon_training": " · ".join(weapon_training),
		"inventory": get_shop_inventory_summary(),
	}


func get_shop_inventory_summary() -> Dictionary:
	if is_instance_valid(_weapon_controller) and _weapon_controller.has_method("get_shop_inventory_summary"):
		var inventory: Dictionary = _weapon_controller.get_shop_inventory_summary()
		var upgrades: Array[Dictionary] = []
		for upgrade_id: Variant in _upgrade_ranks.keys():
			var rank := int(_upgrade_ranks[upgrade_id])
			if rank <= 0:
				continue
			var readable_name := String(upgrade_id).replace("_", " ").capitalize()
			upgrades.append({"id": String(upgrade_id), "name": readable_name, "rank": rank})
		inventory["upgrades"] = upgrades
		return inventory
	return {"weapons": [], "deployables": [], "upgrades": []}


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


func can_apply_level_stat_delta(choice_id: StringName, value: float) -> bool:
	if _is_dead:
		return false
	match choice_id:
		&"health":
			return roundi(value) > 0
		&"speed":
			var next_speed := _move_speed_multiplier * (1.0 + maxf(0.0, value))
			return next_speed > _move_speed_multiplier and next_speed <= 1.8
		&"lifesteal":
			var next_lifesteal := _life_steal_fraction + maxf(0.0, value)
			return next_lifesteal > _life_steal_fraction and next_lifesteal <= 0.25
		&"dodge":
			var next_dodge := _dodge_chance + maxf(0.0, value)
			return next_dodge > _dodge_chance and next_dodge <= 0.6
		&"protection":
			var next_protection := _protection_fraction + maxf(0.0, value)
			return next_protection > _protection_fraction and next_protection <= 0.3
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
		"damage_multiplier": _damage_multiplier,
		"elemental_damage": _elemental_damage,
		"engineering": _engineering,
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
	_move_speed_multiplier = clampf(float(data.get("move_speed_multiplier", 1.0)), 0.45, 1.8)
	_damage_multiplier = clampf(float(data.get("damage_multiplier", 1.0)), 0.25, 2.5)
	_elemental_damage = clampi(int(data.get("elemental_damage", 0)), 0, 99)
	_engineering = clampi(int(data.get("engineering", 0)), 0, 60)
	_life_steal_fraction = clampf(float(data.get("life_steal_fraction", 0.0)), 0.0, 0.25)
	_dodge_chance = clampf(float(data.get("dodge_chance", 0.0)), 0.0, 0.6)
	_protection_fraction = clampf(float(data.get("protection_fraction", 0.0)), 0.0, 0.3)
	_upgrade_ranks = (data.get("upgrade_ranks", {}) as Dictionary).duplicate()
	health_changed.emit(current_health, max_health)
	progress_changed.emit(current_xp, _xp_required, current_level)
