extends Node2D
class_name SurvivorAutoWeapon

signal weapon_unlocked(weapon_id: StringName, display_name: String)

const MAX_WEAPON_SLOTS := 6

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


func _ready() -> void:
	_owner_actor = get_parent() as Node2D
	if not weapon_definitions.is_empty():
		configure_weapon_catalog(weapon_definitions, _projectile_layer)
	elif _weapon_order.is_empty():
		_create_legacy_can_launcher()


func configure_projectile_layer(layer: Node2D) -> void:
	_projectile_layer = layer


func set_current_room_id(room_id: StringName) -> void:
	_current_room_id = room_id


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


func purchase_weapon_offer(offer: WeaponDefinition) -> bool:
	if offer == null:
		return false
	if not has_weapon(offer.id):
		if offer.shop_offer_kind != WeaponDefinition.ShopOfferKind.NEW_WEAPON or _weapon_order.size() >= MAX_WEAPON_SLOTS:
			return false
		return unlock_weapon(offer)
	var current_tier := get_weapon_tier(offer.id)
	match offer.shop_offer_kind:
		WeaponDefinition.ShopOfferKind.MERGE_COPY:
			return current_tier < 4 and offer.tier == current_tier + 1 and _raise_weapon_tier(offer.id, current_tier + 1)
		WeaponDefinition.ShopOfferKind.DIRECT_TIER:
			return offer.tier > current_tier and _raise_weapon_tier(offer.id, offer.tier)
	return false


func get_weapon_slot_count() -> int:
	return _weapon_order.size()


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
		var tier := int(state.get("tier", 1))
		var suffix := " %s" % ["I", "II", "III", "IV"][clampi(tier, 1, 4) - 1]
		names.append(String(state.get("display_name", weapon_id)) + suffix)
	return names


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_owner_actor):
		_owner_actor = get_parent() as Node2D
	for weapon_id: StringName in _weapon_order:
		var state: Dictionary = _weapon_states[weapon_id]
		var mode: int = int(state["attack_mode"])
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
				state["cooldown"] = maxf(0.05, float(state["fire_interval"]))
		_weapon_states[weapon_id] = state


func _fire_weapon(state: Dictionary, target: Node2D, direction: Vector2) -> bool:
	if projectile_scene == null:
		return false
	var mode: int = int(state["attack_mode"])
	var count: int = maxi(1, int(state["projectile_count"]))
	if mode == WeaponDefinition.AttackMode.DEPLOYED_SLOW_ZONE:
		var beacon := _create_projectile(target.global_position) as SurvivorProjectile
		if beacon == null:
			return false
		beacon.set_life_steal_source(_owner_actor)
		beacon.launch_zone(
			int(state["damage"]),
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
				int(state["damage"]),
				float(state["projectile_speed"]),
				float(state["projectile_lifetime"]),
				int(state["pierce_count"]),
				float(state["return_distance"]),
				_owner_actor
			)
		else:
			projectile.launch_with_stats(
				shot_direction,
				int(state["damage"]),
				float(state["projectile_speed"]),
				float(state["projectile_lifetime"]),
				int(state["pierce_count"])
			)
		projectile.set_weapon_visual(state.get("sprite") as Texture2D)
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
			int(state["damage"]),
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
			int(state["damage"])
		)
	state["orbitals"] = orbitals
	_weapon_states[weapon_id] = state


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
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_target = enemy
	return best_target


func _build_runtime_state(definition: WeaponDefinition) -> Dictionary:
	var state := {
		"id": definition.id,
		"display_name": definition.display_name,
		"sprite": definition.sprite,
		"attack_mode": definition.attack_mode,
		"damage": definition.damage,
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
		"cooldown": minf(0.15, definition.fire_interval),
		"orbitals": [],
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
	}
	_weapon_order.append(legacy_id)


func get_save_data() -> Array:
	var list: Array = []
	for wid: StringName in _weapon_order:
		list.append({"id": String(wid), "tier": get_weapon_tier(wid)})
	return list


func restore_save_data(saved_list: Array) -> void:
	for entry: Dictionary in saved_list:
		var wid := StringName(String(entry.get("id", "")))
		var target_tier: int = int(entry.get("tier", 1))
		if not has_weapon(wid):
			unlock_weapon_id(wid)
		if target_tier > 1:
			_raise_weapon_tier(wid, target_tier)
