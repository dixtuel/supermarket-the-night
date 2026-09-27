extends Node2D
class_name SurvivorAutoWeapon

signal weapon_unlocked(weapon_id: StringName, display_name: String)

const MAX_WEAPON_SLOTS := 6
const MAX_DEPLOYABLE_INSTANCES := 6
const MINE_REDEPLOY_DELAY := 1.8
const OFF_ROOM_TURRET_CHANCE := 0.06
const TURRET_INITIAL_SPAWN_DELAY := 1.5
const DEPLOYABLE_ROOM_IDS: Array[StringName] = [&"market", &"depot", &"restroom", &"manager_office"]

@export var projectile_scene: PackedScene
@export var weapon_definitions: Array[WeaponDefinition] = []
## Legacy Can Launcher tuning remains available for scenes not yet wired to a catalog.
@export var fire_interval: float = 0.65
@export var damage: int = 10
@export var target_range: float = 420.0
@export var muzzle_offset: float = 12.0

var _projectile_layer: Node2D
var _owner_actor: Node2D
var _weapon_catalog: Dictionary = {}
var _weapon_states: Dictionary = {}
var _weapon_order: Array[StringName] = []
var _current_room_id: StringName = &"market"
var _deployable_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_owner_actor = get_parent() as Node2D
	_deployable_rng.randomize()
	if not weapon_definitions.is_empty():
		configure_weapon_catalog(weapon_definitions, _projectile_layer)
	elif _weapon_order.is_empty():
		_create_legacy_can_launcher()


func configure_projectile_layer(layer: Node2D) -> void:
	_projectile_layer = layer


func set_current_room_id(room_id: StringName) -> void:
	_current_room_id = room_id


func begin_wave(room_id: StringName) -> void:
	_current_room_id = room_id
	for weapon_id: StringName in _weapon_order:
		var state: Dictionary = _weapon_states.get(weapon_id, {})
		var mode := int(state.get("attack_mode", -1))
		if mode not in [WeaponDefinition.AttackMode.DEPLOYED_TURRET, WeaponDefinition.AttackMode.DEPLOYED_MINE]:
			continue
		state["deployables_active"] = true
		_ensure_deployable_slots(state)
		var instances: Array = state["deployable_instances"]
		var cooldowns: Array = state["deployable_respawn"]
		var spawn_delays: Array = state["deployable_spawn_delays"]
		var desired_count := clampi(int(state.get("deployable_count", maxi(1, int(state.get("projectile_count", 1))))), 1, MAX_DEPLOYABLE_INSTANCES)
		for index: int in range(desired_count):
			if index < instances.size() and is_instance_valid(instances[index]):
				continue
			if mode == WeaponDefinition.AttackMode.DEPLOYED_TURRET:
				spawn_delays[index] = _deployable_rng.randf_range(0.0, TURRET_INITIAL_SPAWN_DELAY if index == 0 else 4.0)
				continue
			if mode == WeaponDefinition.AttackMode.DEPLOYED_MINE and float(cooldowns[index]) > 0.0:
				continue
			_spawn_deployable(weapon_id, state, index)
		state["deployable_spawn_delays"] = spawn_delays
		_weapon_states[weapon_id] = state


func configure_weapon_catalog(
		definitions: Array[WeaponDefinition],
		projectile_layer: Node2D,
		starter_weapon_ids: Array[StringName] = []
	) -> void:
	_projectile_layer = projectile_layer
	_weapon_catalog.clear()
	_weapon_states.clear()
	_weapon_order.clear()
	for definition: WeaponDefinition in definitions:
		if definition == null or definition.id == &"":
			continue
		_weapon_catalog[definition.id] = definition
	var selected_ids: Array[StringName] = starter_weapon_ids.duplicate()
	if selected_ids.is_empty():
		if _weapon_catalog.has(&"can_launcher"):
			selected_ids.append(&"can_launcher")
		elif not _weapon_catalog.is_empty():
			selected_ids.append(_weapon_catalog.keys()[0])
	for weapon_id: StringName in selected_ids:
		if not unlock_weapon_id(weapon_id):
			push_warning("Starter weapon id '%s' is not present in the weapon catalog." % weapon_id)


func unlock_weapon(definition: WeaponDefinition) -> bool:
	if definition == null or definition.id == &"":
		return false
	_weapon_catalog[definition.id] = definition
	if _weapon_states.has(definition.id):
		return false
	_weapon_states[definition.id] = _build_runtime_state(definition)
	_weapon_order.append(definition.id)
	weapon_unlocked.emit(definition.id, definition.display_name)
	return true


func unlock_weapon_id(weapon_id: StringName) -> bool:
	var definition := _weapon_catalog.get(weapon_id) as WeaponDefinition
	return unlock_weapon(definition)


func has_weapon(weapon_id: StringName) -> bool:
	return _weapon_states.has(weapon_id)


func get_weapon_tier(weapon_id: StringName) -> int:
	if not _weapon_states.has(weapon_id):
		return 0
	return int((_weapon_states[weapon_id] as Dictionary).get("tier", 1))


func get_deployable_count(weapon_id: StringName) -> int:
	if not _weapon_states.has(weapon_id):
		return 0
	var state: Dictionary = _weapon_states[weapon_id]
	if int(state.get("attack_mode", -1)) not in [WeaponDefinition.AttackMode.DEPLOYED_TURRET, WeaponDefinition.AttackMode.DEPLOYED_MINE]:
		return 0
	return clampi(int(state.get("deployable_count", 1)), 1, MAX_DEPLOYABLE_INSTANCES)


func get_level_choice_weapon_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for weapon_id: StringName in _weapon_order:
		var state: Dictionary = _weapon_states.get(weapon_id, {})
		if state.is_empty():
			continue
		targets.append({
			"id": String(weapon_id),
			"name": String(state.get("display_name", String(weapon_id))),
			"damage_type": int(state.get("damage_type", WeaponDefinition.DamageType.PHYSICAL)),
			"damage_scaling_stat": int(state.get("damage_scaling_stat", WeaponDefinition.DamageScalingStat.RANGED)),
			"engineering_coefficient": float(state.get("engineering_coefficient", 0.0)),
			"is_structure": int(state.get("attack_mode", -1)) in [WeaponDefinition.AttackMode.DEPLOYED_TURRET, WeaponDefinition.AttackMode.DEPLOYED_MINE],
			"supports_fire_rate": int(state.get("attack_mode", -1)) != WeaponDefinition.AttackMode.ORBITAL_CONTACT,
			"tier": int(state.get("tier", 1)),
			"level_damage_add": int(state.get("level_damage_add", 0)),
			"level_fire_rate_bonus": float(state.get("level_fire_rate_bonus", 0.0)),
		})
	return targets


func can_apply_level_weapon_effect(effect: Dictionary) -> bool:
	var weapon_id := StringName(String(effect.get("weapon_id", "")))
	if weapon_id == &"" or not _weapon_states.has(weapon_id):
		return false
	var state: Dictionary = _weapon_states[weapon_id]
	var stat_id := StringName(String(effect.get("stat", "")))
	var value := float(effect.get("value", 0.0))
	match stat_id:
		&"weapon_damage":
			var current_damage_add := int(state.get("level_damage_add", 0))
			var next_damage_add := current_damage_add + roundi(value)
			var current_effective_base := maxi(1, int(state.get("damage", 1)) + current_damage_add)
			var next_effective_base := maxi(1, int(state.get("damage", 1)) + next_damage_add)
			return roundi(value) != 0 and next_damage_add >= -20 and next_damage_add <= 20 and current_effective_base != next_effective_base
		&"weapon_fire_rate":
			return int(state.get("attack_mode", -1)) != WeaponDefinition.AttackMode.ORBITAL_CONTACT and value > 0.0 and float(state.get("level_fire_rate_bonus", 0.0)) + value <= 0.3
	return false


func apply_level_weapon_effect(effect: Dictionary) -> bool:
	if not can_apply_level_weapon_effect(effect):
		return false
	var weapon_id := StringName(String(effect.get("weapon_id", "")))
	var state: Dictionary = _weapon_states[weapon_id]
	match StringName(String(effect.get("stat", ""))):
		&"weapon_damage":
			state["level_damage_add"] = clampi(int(state.get("level_damage_add", 0)) + roundi(float(effect.get("value", 0.0))), -20, 20)
		&"weapon_fire_rate":
			state["level_fire_rate_bonus"] = minf(0.3, float(state.get("level_fire_rate_bonus", 0.0)) + maxf(0.0, float(effect.get("value", 0.0))))
	_weapon_states[weapon_id] = state
	return true


func purchase_weapon_offer(offer: WeaponDefinition) -> bool:
	if offer == null:
		return false
	if not has_weapon(offer.id):
		if offer.shop_offer_kind != WeaponDefinition.ShopOfferKind.NEW_WEAPON or get_weapon_slot_count() >= MAX_WEAPON_SLOTS:
			return false
		return unlock_weapon(offer)
	var current_tier := get_weapon_tier(offer.id)
	var state: Dictionary = _weapon_states[offer.id]
	if offer.shop_offer_kind == WeaponDefinition.ShopOfferKind.DEPLOYABLE_COPY:
		if int(state.get("attack_mode", -1)) not in [WeaponDefinition.AttackMode.DEPLOYED_TURRET, WeaponDefinition.AttackMode.DEPLOYED_MINE]:
			return false
		var owned_count := maxi(1, int(state.get("deployable_count", 1)))
		if owned_count >= MAX_DEPLOYABLE_INSTANCES or offer.tier != current_tier:
			return false
		state["deployable_count"] = owned_count + 1
		_weapon_states[offer.id] = state
		return true
	match offer.shop_offer_kind:
		WeaponDefinition.ShopOfferKind.MERGE_COPY:
			return current_tier < 4 and offer.tier == current_tier + 1 and _raise_weapon_tier(offer.id, current_tier + 1)
		WeaponDefinition.ShopOfferKind.DIRECT_TIER:
			return offer.tier > current_tier and _raise_weapon_tier(offer.id, offer.tier)
	return false


func get_weapon_slot_count() -> int:
	var count := 0
	for weapon_id: StringName in _weapon_order:
		var state: Dictionary = _weapon_states.get(weapon_id, {})
		if int(state.get("attack_mode", -1)) not in [WeaponDefinition.AttackMode.DEPLOYED_TURRET, WeaponDefinition.AttackMode.DEPLOYED_MINE]:
			count += 1
	return count


func _raise_weapon_tier(weapon_id: StringName, target_tier: int) -> bool:
	if not _weapon_states.has(weapon_id):
		return false
	var state: Dictionary = _weapon_states[weapon_id]
	var current_tier: int = int(state.get("tier", 1))
	var bounded_target: int = clampi(target_tier, 1, 4)
	if bounded_target <= current_tier:
		return false
	while current_tier < bounded_target:
		current_tier += 1
		state["tier"] = current_tier
		state["damage"] = maxi(1, roundi(float(state["damage"]) * 1.2))
		state["fire_interval"] = maxf(0.05, float(state["fire_interval"]) * 0.93)
		state["projectile_speed"] = float(state["projectile_speed"]) * 1.05
		state["area_radius"] = float(state["area_radius"]) + 8.0
		if current_tier % 2 == 1:
			state["projectile_count"] = clampi(int(state["projectile_count"]) + 1, 1, 32)
	_weapon_states[weapon_id] = state
	return true


func apply_upgrade(upgrade: UpgradeDefinition) -> bool:
	if upgrade == null:
		return false
	if upgrade.effect == UpgradeDefinition.Effect.UNLOCK_WEAPON:
		return unlock_weapon(upgrade.unlocks_weapon)
	var affected: bool = false
	for weapon_id: StringName in _weapon_order:
		if upgrade.target_weapon_id != &"" and weapon_id != upgrade.target_weapon_id:
			continue
		var state: Dictionary = _weapon_states[weapon_id]
		match upgrade.effect:
			UpgradeDefinition.Effect.WEAPON_DAMAGE_ADD:
				state["damage"] = maxi(1, int(state["damage"]) + roundi(upgrade.value))
			UpgradeDefinition.Effect.FIRE_RATE_MULTIPLIER:
				state["fire_interval"] = maxf(0.05, float(state["fire_interval"]) / maxf(0.1, 1.0 + upgrade.value))
			UpgradeDefinition.Effect.PROJECTILE_COUNT_ADD:
				state["projectile_count"] = clampi(int(state["projectile_count"]) + roundi(upgrade.value), 1, 32)
			UpgradeDefinition.Effect.PROJECTILE_SPEED_MULTIPLIER:
				state["projectile_speed"] = maxf(1.0, float(state["projectile_speed"]) * maxf(0.1, 1.0 + upgrade.value))
			UpgradeDefinition.Effect.WEAPON_DAMAGE_MULTIPLIER:
				state["damage"] = maxi(1, roundi(float(state["damage"]) * maxf(0.1, 1.0 + upgrade.value)))
			UpgradeDefinition.Effect.WEAPON_PIERCE_ADD:
				state["pierce_count"] = clampi(int(state["pierce_count"]) + roundi(upgrade.value), 0, 32)
			UpgradeDefinition.Effect.WEAPON_RADIUS_ADD:
				state["area_radius"] = maxf(0.0, float(state["area_radius"]) + upgrade.value)
			_:
				continue
		_weapon_states[weapon_id] = state
		affected = true
	return affected


func get_unlocked_weapon_ids() -> Array[StringName]:
	return _weapon_order.duplicate()


func get_unlocked_weapon_names() -> PackedStringArray:
	var names := PackedStringArray()
	for weapon_id: StringName in _weapon_order:
		var state: Dictionary = _weapon_states[weapon_id]
		if int(state.get("attack_mode", -1)) in [WeaponDefinition.AttackMode.DEPLOYED_TURRET, WeaponDefinition.AttackMode.DEPLOYED_MINE]:
			continue
		var tier := int(state.get("tier", 1))
		var suffix := " %s" % ["I", "II", "III", "IV"][clampi(tier, 1, 4) - 1]
		names.append(String(state.get("display_name", weapon_id)) + suffix)
	return names


func get_shop_inventory_summary() -> Dictionary:
	var weapons: Array[Dictionary] = []
	var deployable_indices: Dictionary = {}
	var deployables: Array[Dictionary] = []
	for weapon_id: StringName in _weapon_order:
		var state: Dictionary = _weapon_states.get(weapon_id, {})
		if state.is_empty():
			continue
		var tier := int(state.get("tier", 1))
		var name := String(state.get("display_name", String(weapon_id)))
		var definition := _weapon_catalog.get(weapon_id) as WeaponDefinition
		var mode := int(state.get("attack_mode", -1))
		if mode in [WeaponDefinition.AttackMode.DEPLOYED_TURRET, WeaponDefinition.AttackMode.DEPLOYED_MINE]:
			var kind := "turret" if mode == WeaponDefinition.AttackMode.DEPLOYED_TURRET else "mine"
			var key := "%s:%d" % [String(weapon_id), tier]
			deployable_indices[key] = deployables.size()
			deployables.append({"id": weapon_id, "name": name, "tier": tier, "kind": kind, "count": maxi(1, int(state.get("deployable_count", 1))), "icon": definition.sprite if definition != null else null})
			continue
		weapons.append({
			"id": String(weapon_id),
			"name": name,
			"tier": tier,
			"damage": _effective_weapon_damage(state),
			"fire_interval": float(state.get("fire_interval", 0.0)),
			"projectile_count": int(state.get("projectile_count", 1)),
			"range": roundi(float(state.get("target_range", 0.0))),
			"area": roundi(float(state.get("area_radius", 0.0))),
			"pierce": int(state.get("pierce_count", 0)),
			"icon": definition.sprite if definition != null else null,
		})
	for structure: Node in get_tree().get_nodes_in_group("deployed_structures"):
		if not is_instance_valid(structure) or structure.is_queued_for_deletion():
			continue
		var weapon_id := StringName(structure.get_meta("weapon_id", &""))
		var tier := int(structure.get_meta("weapon_tier", 1))
		var key := "%s:%d" % [String(weapon_id), tier]
		if not deployable_indices.has(key):
			var name := String(structure.get_meta("weapon_name", String(weapon_id)))
			var kind := "turret" if structure.is_in_group("deployed_turrets") else "mine"
			var definition := _weapon_catalog.get(weapon_id) as WeaponDefinition
			deployable_indices[key] = deployables.size()
			deployables.append({"id": weapon_id, "name": name, "tier": tier, "kind": kind, "count": 0, "icon": definition.sprite if definition != null else null})
	return {"weapons": weapons, "deployables": deployables}


func sell_weapon(weapon_id: StringName) -> Dictionary:
	if not _weapon_states.has(weapon_id):
		return {}
	var state: Dictionary = _weapon_states[weapon_id]
	var is_deployable := int(state.get("attack_mode", -1)) in [WeaponDefinition.AttackMode.DEPLOYED_TURRET, WeaponDefinition.AttackMode.DEPLOYED_MINE]
	if not is_deployable and get_weapon_slot_count() <= 1:
		return {}
	var tier := clampi(int(state.get("tier", 1)), 1, 4)
	var payout := 4 + tier * 3
	var sold := {
		"id": String(weapon_id),
		"name": String(state.get("display_name", String(weapon_id))),
		"tier": tier,
		"payout": payout,
	}
	_weapon_states.erase(weapon_id)
	_weapon_order.erase(weapon_id)
	if is_deployable:
		for structure: Node in get_tree().get_nodes_in_group("deployed_structures"):
			if is_instance_valid(structure) and StringName(structure.get_meta("weapon_id", &"")) == weapon_id:
				structure.queue_free()
	return sold


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_owner_actor):
		_owner_actor = get_parent() as Node2D
	for weapon_id: StringName in _weapon_order:
		var state: Dictionary = _weapon_states[weapon_id]
		var mode: int = int(state["attack_mode"])
		if mode in [WeaponDefinition.AttackMode.DEPLOYED_TURRET, WeaponDefinition.AttackMode.DEPLOYED_MINE]:
			_update_deployables(weapon_id, state, delta)
			continue
		if mode == WeaponDefinition.AttackMode.ORBITAL_CONTACT:
			_ensure_orbitals(weapon_id, state)
			_weapon_states[weapon_id] = state
			continue
		state["cooldown"] = maxf(0.0, float(state["cooldown"]) - delta)
		var target := _find_nearest_enemy(float(state["target_range"]))
		if not is_instance_valid(target):
			_weapon_states[weapon_id] = state
			continue
		var direction: Vector2 = global_position.direction_to(target.global_position)
		if not direction.is_zero_approx():
			global_rotation = direction.angle()
		if float(state["cooldown"]) <= 0.0 and is_instance_valid(_projectile_layer):
			if _fire_weapon(state, target, direction):
				state["cooldown"] = _effective_fire_interval(state)
		_weapon_states[weapon_id] = state


func _fire_weapon(state: Dictionary, target: Node2D, direction: Vector2) -> bool:
	if projectile_scene == null:
		return false
	var mode: int = int(state["attack_mode"])
	var count: int = maxi(1, int(state["projectile_count"]))
	if mode == WeaponDefinition.AttackMode.DEPLOYED_TURRET:
		var turret := _create_projectile(global_position) as SurvivorProjectile
		if turret == null:
			return false
		turret.set_life_steal_source(_owner_actor)
		turret.launch_turret(
			_effective_structure_damage(state), float(state["target_range"]), float(state["fire_interval"]),
			float(state["effect_duration"]), _owner_actor, _current_room_id,
			StringName(state.get("id", &"")), String(state.get("display_name", "Turret")), int(state.get("tier", 1))
		)
		turret.set_weapon_visual(state.get("sprite") as Texture2D)
		return true
	if mode == WeaponDefinition.AttackMode.DEPLOYED_MINE:
		var mine := _create_projectile(global_position) as SurvivorProjectile
		if mine == null:
			return false
		mine.set_life_steal_source(_owner_actor)
		mine.launch_mine(
			_effective_structure_damage(state), float(state["area_radius"]), float(state["effect_duration"]),
			_owner_actor, _current_room_id,
			StringName(state.get("id", &"")), String(state.get("display_name", "Mine")), int(state.get("tier", 1))
		)
		mine.set_weapon_visual(state.get("sprite") as Texture2D)
		return true
	if mode == WeaponDefinition.AttackMode.DEPLOYED_SLOW_ZONE:
		var beacon := _create_projectile(target.global_position) as SurvivorProjectile
		if beacon == null:
			return false
		beacon.set_life_steal_source(_owner_actor)
		beacon.launch_zone(
			_effective_weapon_damage(state),
			float(state["area_radius"]),
			float(state["effect_duration"]),
			float(state["slow_multiplier"])
		)
		beacon.set_weapon_visual(state.get("sprite") as Texture2D, 32.0, true)
		return true
	var fired: bool = false
	for index: int in range(count):
		var angle_offset: float = (float(index) - float(count - 1) * 0.5) * 0.12
		var shot_direction := direction.rotated(angle_offset)
		var projectile := _create_projectile(global_position + shot_direction * float(state["muzzle_offset"])) as SurvivorProjectile
		if projectile == null:
			continue
		projectile.set_life_steal_source(_owner_actor)
		if mode == WeaponDefinition.AttackMode.RETURNING_PROJECTILE:
			projectile.launch_returning(
				shot_direction,
				_effective_weapon_damage(state),
				float(state["projectile_speed"]),
				float(state["projectile_lifetime"]),
				int(state["pierce_count"]),
				float(state["return_distance"]),
				_owner_actor
			)
		else:
			projectile.launch_with_stats(
				shot_direction,
				_effective_weapon_damage(state),
				float(state["projectile_speed"]),
				float(state["projectile_lifetime"]),
				int(state["pierce_count"])
			)
		var sprite_size := 29.0 if StringName(state.get("id", &"")) == &"can_launcher" else 28.0
		projectile.set_weapon_visual(state.get("sprite") as Texture2D, sprite_size)
		fired = true
	return fired


func _ensure_orbitals(weapon_id: StringName, state: Dictionary) -> void:
	if projectile_scene == null or not is_instance_valid(_projectile_layer) or not is_instance_valid(_owner_actor):
		return
	var orbitals: Array = state.get("orbitals", [])
	var valid_orbitals: Array = []
	for entry: Variant in orbitals:
		if is_instance_valid(entry):
			valid_orbitals.append(entry)
	orbitals = valid_orbitals
	var desired_count: int = maxi(1, int(state["projectile_count"]))
	while orbitals.size() < desired_count:
		var projectile := _create_projectile(_owner_actor.global_position) as SurvivorProjectile
		if projectile == null:
			break
		projectile.set_life_steal_source(_owner_actor)
		projectile.launch_orbit(
			_owner_actor,
			float(state["area_radius"]),
			float(state["orbit_speed"]),
			_effective_weapon_damage(state),
			TAU * float(orbitals.size()) / float(desired_count)
		)
		projectile.set_weapon_visual(state.get("sprite") as Texture2D)
		orbitals.append(projectile)
	for index: int in range(orbitals.size()):
		var entry: Variant = orbitals[index]
		if not is_instance_valid(entry):
			continue
		var projectile := entry as SurvivorProjectile
		projectile.update_orbit(
			float(state["area_radius"]),
			float(state["orbit_speed"]),
		_effective_weapon_damage(state)
		)
	state["orbitals"] = orbitals
	_weapon_states[weapon_id] = state


func _effective_damage(
		base_damage: int,
		damage_type: int = WeaponDefinition.DamageType.PHYSICAL,
		elemental_coefficient: float = 1.0) -> int:
	var typed_damage := base_damage
	if damage_type == WeaponDefinition.DamageType.ELEMENTAL and is_instance_valid(_owner_actor) and _owner_actor.has_method("get_elemental_damage"):
		typed_damage += roundi(float(_owner_actor.call("get_elemental_damage")) * clampf(elemental_coefficient, 0.0, 2.0))
	if is_instance_valid(_owner_actor) and _owner_actor.has_method("get_attack_damage_multiplier"):
		return maxi(1, roundi(float(typed_damage) * float(_owner_actor.call("get_attack_damage_multiplier"))))
	return maxi(1, typed_damage)


func _effective_weapon_damage(state: Dictionary) -> int:
	var tuned_damage := int(state.get("damage", 1)) + int(state.get("level_damage_add", 0))
	var coefficient := clampf(float(state.get("damage_scaling_coefficient", 0.5)), 0.0, 2.0)
	if is_instance_valid(_owner_actor):
		match int(state.get("damage_scaling_stat", WeaponDefinition.DamageScalingStat.RANGED)):
			WeaponDefinition.DamageScalingStat.MELEE:
				if _owner_actor.has_method("get_melee_damage"):
					tuned_damage += roundi(float(_owner_actor.call("get_melee_damage")) * coefficient)
			WeaponDefinition.DamageScalingStat.RANGED:
				if _owner_actor.has_method("get_ranged_damage"):
					tuned_damage += roundi(float(_owner_actor.call("get_ranged_damage")) * coefficient)
			WeaponDefinition.DamageScalingStat.ELEMENTAL:
				pass
	return _effective_damage(
		tuned_damage,
		int(state.get("damage_type", WeaponDefinition.DamageType.PHYSICAL)),
		coefficient
	)


func _effective_structure_damage(state: Dictionary) -> int:
	var engineering := 0
	if is_instance_valid(_owner_actor) and _owner_actor.has_method("get_engineering"):
		engineering = int(_owner_actor.call("get_engineering"))
	return maxi(1, int(state.get("damage", 1)) + int(state.get("level_damage_add", 0)) + roundi(float(engineering) * clampf(float(state.get("engineering_coefficient", 0.0)), 0.0, 2.0)))


func _effective_fire_interval(state: Dictionary) -> float:
	var rate_bonus := clampf(float(state.get("level_fire_rate_bonus", 0.0)), 0.0, 0.3)
	var player_rate_bonus := 0.0
	if is_instance_valid(_owner_actor) and _owner_actor.has_method("get_attack_speed_bonus"):
		player_rate_bonus = float(_owner_actor.call("get_attack_speed_bonus"))
	# Brotato's reference caps weapon rate at 12 hits per second. Use the same
	# readable safety ceiling for handheld weapons and thrown beacon skills.
	return maxf(1.0 / 12.0, float(state.get("fire_interval", fire_interval)) / ((1.0 + rate_bonus) * (1.0 + player_rate_bonus)))


func _create_projectile(spawn_position: Vector2) -> Area2D:
	if projectile_scene == null or not is_instance_valid(_projectile_layer):
		return null
	var projectile := projectile_scene.instantiate() as Area2D
	if projectile == null:
		push_warning("AutoWeapon projectile_scene must have an Area2D root.")
		return null
	_projectile_layer.add_child(projectile)
	projectile.set_meta("room_id", _current_room_id)
	projectile.global_position = spawn_position
	return projectile


func _find_nearest_enemy(range_limit: float) -> Node2D:
	var best_target: Node2D
	var best_distance_squared: float = range_limit * range_limit
	for candidate: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as Node2D
		if enemy == null or not enemy.is_inside_tree():
			continue
		if enemy.has_meta("room_id") and StringName(enemy.get_meta("room_id")) != _current_room_id:
			continue
		var distance_squared := global_position.distance_squared_to(enemy.global_position)
		if distance_squared < best_distance_squared and _has_clear_shot_to(enemy):
			best_distance_squared = distance_squared
			best_target = enemy
	return best_target


func _has_clear_shot_to(enemy: Node2D) -> bool:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return false
	var direction := global_position.direction_to(enemy.global_position)
	if direction.is_zero_approx():
		return true
	var perpendicular := Vector2(-direction.y, direction.x) * 5.0
	var query := PhysicsRayQueryParameters2D.create(global_position, enemy.global_position, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [enemy.get_rid()] if enemy is CollisionObject2D else []
	if is_instance_valid(_owner_actor) and _owner_actor is CollisionObject2D:
		query.exclude.append((_owner_actor as CollisionObject2D).get_rid())
	var space := get_world_2d().direct_space_state
	return space.intersect_ray(query).is_empty() \
		and _ray_to_target_is_clear(space, global_position + perpendicular, enemy.global_position + perpendicular, query.exclude) \
		and _ray_to_target_is_clear(space, global_position - perpendicular, enemy.global_position - perpendicular, query.exclude)


func _ray_to_target_is_clear(space: PhysicsDirectSpaceState2D, origin: Vector2, destination: Vector2, exclusions: Array[RID]) -> bool:
	var query := PhysicsRayQueryParameters2D.create(origin, destination, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = exclusions
	return space.intersect_ray(query).is_empty()


func _ensure_deployable_slots(state: Dictionary) -> void:
	var instances: Array = state.get("deployable_instances", [])
	var cooldowns: Array = state.get("deployable_respawn", [])
	var last_positions: Array = state.get("deployable_last_positions", [])
	var spawn_delays: Array = state.get("deployable_spawn_delays", [])
	var desired_count := clampi(int(state.get("deployable_count", maxi(1, int(state.get("projectile_count", 1))))), 1, MAX_DEPLOYABLE_INSTANCES)
	while instances.size() < desired_count:
		instances.append(null)
		cooldowns.append(0.0)
		last_positions.append(Vector2(-10000.0, -10000.0))
		spawn_delays.append(0.0)
	if instances.size() > desired_count:
		instances.resize(desired_count)
		cooldowns.resize(desired_count)
		last_positions.resize(desired_count)
		spawn_delays.resize(desired_count)
	state["deployable_instances"] = instances
	state["deployable_respawn"] = cooldowns
	state["deployable_last_positions"] = last_positions
	state["deployable_spawn_delays"] = spawn_delays


func _update_deployables(weapon_id: StringName, state: Dictionary, delta: float) -> void:
	if not bool(state.get("deployables_active", false)):
		return
	_ensure_deployable_slots(state)
	var mode := int(state.get("attack_mode", -1))
	var instances: Array = state["deployable_instances"]
	var cooldowns: Array = state["deployable_respawn"]
	var spawn_delays: Array = state["deployable_spawn_delays"]
	for index: int in range(instances.size()):
		if is_instance_valid(instances[index]):
			continue
		if mode == WeaponDefinition.AttackMode.DEPLOYED_TURRET:
			spawn_delays[index] = maxf(0.0, float(spawn_delays[index]) - delta)
			if float(spawn_delays[index]) > 0.0:
				continue
			_spawn_deployable(weapon_id, state, index)
			continue
		if mode == WeaponDefinition.AttackMode.DEPLOYED_MINE:
			cooldowns[index] = maxf(0.0, float(cooldowns[index]) - delta)
			if float(cooldowns[index]) > 0.0:
				continue
		_spawn_deployable(weapon_id, state, index)
	state["deployable_instances"] = instances
	state["deployable_respawn"] = cooldowns
	state["deployable_spawn_delays"] = spawn_delays
	_weapon_states[weapon_id] = state


func _spawn_deployable(weapon_id: StringName, state: Dictionary, slot_index: int) -> void:
	if projectile_scene == null or not is_instance_valid(_projectile_layer) or not is_instance_valid(_owner_actor):
		return
	_ensure_deployable_slots(state)
	var instances: Array = state["deployable_instances"]
	if slot_index >= instances.size() or is_instance_valid(instances[slot_index]):
		return
	var last_positions: Array = state["deployable_last_positions"]
	var mode := int(state.get("attack_mode", -1))
	var is_turret := mode == WeaponDefinition.AttackMode.DEPLOYED_TURRET
	var placement_room := _current_room_id
	if is_turret and slot_index > 0 and _deployable_rng.randf() < OFF_ROOM_TURRET_CHANCE:
		var other_rooms: Array[StringName] = []
		for room_id: StringName in DEPLOYABLE_ROOM_IDS:
			if room_id != _current_room_id:
				other_rooms.append(room_id)
		if not other_rooms.is_empty():
			placement_room = other_rooms[_deployable_rng.randi_range(0, other_rooms.size() - 1)]
	var spawn_position := _choose_deployable_position(placement_room, last_positions[slot_index] as Vector2)
	var deployed := _create_projectile(spawn_position) as SurvivorProjectile
	if deployed == null:
		return
	deployed.set_life_steal_source(_owner_actor)
	if is_turret:
		deployed.launch_turret(
			_effective_structure_damage(state), float(state["target_range"]), float(state["fire_interval"]),
			float(state["effect_duration"]), _owner_actor, placement_room,
			weapon_id, String(state.get("display_name", "Turret")), int(state.get("tier", 1))
		)
	else:
		deployed.launch_mine(
			_effective_structure_damage(state), float(state["area_radius"]), float(state["effect_duration"]),
			_owner_actor, placement_room, weapon_id,
			String(state.get("display_name", "Mine")), int(state.get("tier", 1))
		)
		deployed.mine_detonated.connect(_on_mine_detonated.bind(weapon_id, slot_index))
	deployed.set_weapon_visual(state.get("sprite") as Texture2D)
	deployed.set_deployable_room_active(placement_room == _current_room_id)
	instances[slot_index] = deployed
	last_positions[slot_index] = spawn_position
	state["deployable_instances"] = instances
	state["deployable_last_positions"] = last_positions
	_weapon_states[weapon_id] = state


func _choose_deployable_position(room_id: StringName, previous_position: Vector2) -> Vector2:
	var origin := _owner_actor.global_position if is_instance_valid(_owner_actor) else global_position
	for _attempt: int in range(24):
		var angle := _deployable_rng.randf_range(0.0, TAU)
		var radius := _deployable_rng.randf_range(82.0, 168.0)
		var candidate := origin + Vector2.RIGHT.rotated(angle) * radius
		candidate.x = clampf(candidate.x, -540.0, 540.0)
		candidate.y = clampf(candidate.y, -132.0, 240.0)
		if candidate.distance_squared_to(previous_position) < 96.0 * 96.0:
			continue
		if not _deployable_position_is_clear(candidate):
			continue
		var occupied := false
		for structure: Node in get_tree().get_nodes_in_group("deployed_structures"):
			if not is_instance_valid(structure) or structure.is_queued_for_deletion():
				continue
			if StringName(structure.get_meta("room_id", &"market")) != room_id:
				continue
			if (structure as Node2D).global_position.distance_squared_to(candidate) < 68.0 * 68.0:
				occupied = true
				break
		if not occupied:
			return candidate
	for radius: float in [112.0, 160.0, 208.0]:
		for step: int in range(8):
			var candidate := origin + Vector2.RIGHT.rotated(TAU * float(step) / 8.0) * radius
			candidate.x = clampf(candidate.x, -540.0, 540.0)
			candidate.y = clampf(candidate.y, -132.0, 240.0)
			if candidate.distance_squared_to(previous_position) < 96.0 * 96.0:
				continue
			if _deployable_position_is_clear(candidate) and not _deployable_position_is_occupied(candidate, room_id):
				return candidate
	if previous_position.x > -1000.0:
		return previous_position + Vector2.RIGHT.rotated(_deployable_rng.randf_range(0.0, TAU)) * 144.0
	return origin


func _deployable_position_is_clear(candidate: Vector2) -> bool:
	if not is_instance_valid(_owner_actor) or not _owner_actor.is_inside_tree():
		return true
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = 5 # Store fixtures and enemies; leave the player out.
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [_owner_actor.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _deployable_position_is_occupied(candidate: Vector2, room_id: StringName) -> bool:
	for structure: Node in get_tree().get_nodes_in_group("deployed_structures"):
		if not is_instance_valid(structure) or structure.is_queued_for_deletion():
			continue
		if StringName(structure.get_meta("room_id", &"market")) != room_id:
			continue
		if (structure as Node2D).global_position.distance_squared_to(candidate) < 68.0 * 68.0:
			return true
	return false


func _on_mine_detonated(weapon_id: StringName, slot_index: int) -> void:
	if not _weapon_states.has(weapon_id):
		return
	var state: Dictionary = _weapon_states[weapon_id]
	var instances: Array = state.get("deployable_instances", [])
	var cooldowns: Array = state.get("deployable_respawn", [])
	if slot_index < instances.size():
		instances[slot_index] = null
	if slot_index < cooldowns.size():
		cooldowns[slot_index] = MINE_REDEPLOY_DELAY
	state["deployable_instances"] = instances
	state["deployable_respawn"] = cooldowns
	_weapon_states[weapon_id] = state


func _build_runtime_state(definition: WeaponDefinition) -> Dictionary:
	var state := {
		"id": definition.id,
		"display_name": definition.display_name,
		"sprite": definition.sprite,
		"attack_mode": definition.attack_mode,
		"damage": definition.damage,
		"damage_type": definition.damage_type,
		"damage_scaling_stat": definition.damage_scaling_stat,
		"damage_scaling_coefficient": definition.damage_scaling_coefficient,
		"engineering_coefficient": definition.engineering_coefficient,
		"fire_interval": definition.fire_interval,
		"target_range": definition.target_range,
		"muzzle_offset": definition.muzzle_offset,
		"projectile_speed": definition.projectile_speed,
		"projectile_lifetime": definition.projectile_lifetime,
		"projectile_count": definition.projectile_count,
		"pierce_count": definition.pierce_count,
		"area_radius": definition.area_radius,
		"effect_duration": definition.effect_duration,
		"slow_multiplier": definition.slow_multiplier,
		"orbit_speed": definition.orbit_speed,
		"return_distance": definition.return_distance,
		"tier": 1,
		"level_damage_add": 0,
		"level_fire_rate_bonus": 0.0,
		"cooldown": minf(0.15, definition.fire_interval),
		"orbitals": [],
		"deployable_instances": [],
		"deployable_respawn": [],
		"deployable_last_positions": [],
		"deployable_spawn_delays": [],
		"deployables_active": false,
		"deployable_count": 1 if definition.attack_mode in [WeaponDefinition.AttackMode.DEPLOYED_TURRET, WeaponDefinition.AttackMode.DEPLOYED_MINE] else 0,
	}
	if definition.tier > 1:
		_weapon_states[definition.id] = state
		_raise_weapon_tier(definition.id, definition.tier)
		state = _weapon_states[definition.id]
	return state


func _create_legacy_can_launcher() -> void:
	var legacy_id: StringName = &"can_launcher"
	if _weapon_states.has(legacy_id):
		return
	_weapon_states[legacy_id] = {
		"id": legacy_id,
		"display_name": "Can Launcher",
		"sprite": null,
		"attack_mode": WeaponDefinition.AttackMode.TARGETED_PROJECTILE,
		"damage": maxi(1, damage),
		"fire_interval": maxf(0.05, fire_interval),
		"target_range": maxf(0.0, target_range),
		"muzzle_offset": maxf(0.0, muzzle_offset),
		"projectile_speed": 560.0,
		"projectile_lifetime": 1.5,
		"projectile_count": 1,
		"pierce_count": 0,
		"area_radius": 0.0,
		"effect_duration": 0.0,
		"slow_multiplier": 1.0,
		"orbit_speed": 0.0,
		"return_distance": 0.0,
		"cooldown": 0.15,
		"orbitals": [],
		"deployable_instances": [],
		"deployable_respawn": [],
		"deployable_last_positions": [],
		"deployable_spawn_delays": [],
		"deployables_active": false,
	}
	_weapon_order.append(legacy_id)


func get_save_data() -> Array:
	var list: Array = []
	for wid: StringName in _weapon_order:
		var state: Dictionary = _weapon_states.get(wid, {})
		list.append({
			"id": String(wid),
			"tier": get_weapon_tier(wid),
			"deployable_count": int(state.get("deployable_count", 1)),
			"level_damage_add": int(state.get("level_damage_add", 0)),
			"level_fire_rate_bonus": float(state.get("level_fire_rate_bonus", 0.0)),
		})
	return list


func restore_save_data(saved_list: Array) -> void:
	for entry: Dictionary in saved_list:
		var wid := StringName(String(entry.get("id", "")))
		var target_tier: int = int(entry.get("tier", 1))
		if not has_weapon(wid):
			unlock_weapon_id(wid)
		if target_tier > 1:
			_raise_weapon_tier(wid, target_tier)
		if _weapon_states.has(wid):
			var state: Dictionary = _weapon_states[wid]
			if int(state.get("attack_mode", -1)) in [WeaponDefinition.AttackMode.DEPLOYED_TURRET, WeaponDefinition.AttackMode.DEPLOYED_MINE]:
				state["deployable_count"] = clampi(int(entry.get("deployable_count", 1)), 1, MAX_DEPLOYABLE_INSTANCES)
			state["level_damage_add"] = clampi(int(entry.get("level_damage_add", 0)), -20, 20)
			state["level_fire_rate_bonus"] = clampf(float(entry.get("level_fire_rate_bonus", 0.0)), 0.0, 0.3)
			_weapon_states[wid] = state
