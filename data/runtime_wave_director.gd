class_name RuntimeWaveDirector
extends RefCounted
## Builds a bounded runtime composition from an authored wave pool. Authored
## resources remain read-only; all selection history belongs to this instance.

var _active_round: int = 0
var _selected_enemy_ids: Dictionary = {}
var _recent_enemy_ids: Array[StringName] = []


func begin_wave(round_number: int) -> void:
	_active_round = round_number
	_selected_enemy_ids.clear()
	_recent_enemy_ids.clear()


func choose_enemy(
		definitions: Array[EnemyDefinition],
		authored_weights: Array[float],
		context: Dictionary) -> EnemyDefinition:
	if definitions.is_empty():
		return null
	if _active_round != int(context.get("round", _active_round)):
		begin_wave(int(context.get("round", 1)))

	var candidates: Array[int] = []
	var weights: Array[float] = []
	var unrepresented: Array[int] = []
	var spawn_index: int = int(context.get("spawn_index", 0))
	for index: int in range(definitions.size()):
		var definition := definitions[index]
		if definition == null:
			continue
		var authored_weight: float = authored_weights[index] if index < authored_weights.size() else definition.spawn_weight
		if authored_weight <= 0.0:
			continue
		candidates.append(index)
		var adjusted: float = authored_weight * _role_weight_factor(definition, context)
		if _recent_enemy_ids.size() > 0 and definition.id == _recent_enemy_ids.back():
			adjusted *= 0.72
		weights.append(maxf(0.001, adjusted))
		if not _selected_enemy_ids.has(definition.id):
			unrepresented.append(index)

	if candidates.is_empty():
		return definitions[0]
	# When an authored pool has multiple positive-weight enemies, introduce its
	# members during the opening spawns before settling into weighted variation.
	# This guarantees a mixed encounter without violating zero-weight exclusions.
	if spawn_index < candidates.size() and not unrepresented.is_empty():
		var first_choices: Array[int] = []
		for index: int in unrepresented:
			if candidates.has(index):
				first_choices.append(index)
		var forced: int = _weighted_index_from_indices(first_choices, definitions, authored_weights)
		_record_selection(definitions[forced])
		return definitions[forced]

	var selected_index := candidates[0]
	var roll: float = randf() * _sum(weights)
	for offset: int in range(candidates.size()):
		roll -= weights[offset]
		if roll <= 0.0:
			selected_index = candidates[offset]
			break
	_record_selection(definitions[selected_index])
	return definitions[selected_index]


func damage_multiplier(context: Dictionary) -> float:
	var round_number: int = maxi(1, int(context.get("round", 1)))
	var level: int = maxi(1, int(context.get("level", 1)))
	var profile: Dictionary = context.get("survivability", {})
	var max_health: float = maxf(1.0, float(profile.get("max_health", 100.0)))
	var current_health: float = maxf(0.0, float(profile.get("current_health", max_health)))
	var dodge: float = clampf(float(profile.get("dodge_chance", 0.0)), 0.0, 0.8)
	var lifesteal: float = clampf(float(profile.get("lifesteal_fraction", 0.0)), 0.0, 0.5)
	var protection: float = clampf(float(profile.get("protection_fraction", 0.0)), 0.0, 0.3)
	var move_speed: float = maxf(1.0, float(profile.get("effective_move_speed", 220.0)))
	# Effective durability is estimated from the actual run stats. Exponents keep
	# each defensive investment meaningful while making the response sublinear;
	# doubling one defense never doubles incoming hits.
	var health_factor: float = pow(max_health / 100.0, 0.28)
	var dodge_factor: float = pow(1.0 / maxf(0.2, 1.0 - dodge), 0.22)
	var sustain_factor: float = pow(1.0 + lifesteal * 1.2, 0.18)
	var protection_factor: float = pow(1.0 / (1.0 - protection), 0.24)
	var mobility_factor: float = pow(maxf(0.5, move_speed / 220.0), 0.14)
	var durability_response: float = health_factor * dodge_factor * sustain_factor * protection_factor * mobility_factor
	# Critical health eases pressure slightly, but health loss can only lower the
	# multiplier by a small amount so taking damage is not an exploit.
	var health_ratio: float = clampf(current_health / max_health, 0.0, 1.0)
	var wounded_relief: float = 1.0 - 0.08 * clampf((0.45 - health_ratio) / 0.45, 0.0, 1.0)

	var wave_health: float = maxf(0.1, float(context.get("wave_health_multiplier", 1.0)))
	var spawn_rate: float = maxf(0.01, float(context.get("spawn_rate", 0.52)))
	var max_alive: float = maxf(1.0, float(context.get("max_alive", 12.0)))
	var spawn_interval: float = maxf(0.05, float(context.get("spawn_interval", 1.95)))
	# Use authored encounter pressure instead of a round-number damage ramp.
	# These low exponents account for tougher/faster waves without letting one
	# unusually dense authored schedule dominate the player's incoming damage.
	var wave_response: float = pow(wave_health, 0.16)
	wave_response *= pow(spawn_rate / 0.52, 0.08)
	wave_response *= pow(max_alive / 12.0, 0.06)
	wave_response *= pow(1.95 / spawn_interval, 0.06)

	var offense_index: float = maxf(0.5, float(context.get("offense_index", 1.0)))
	var expected_level: float = 1.0 + float(round_number - 1) * 0.5
	var level_advantage: float = maxf(0.0, float(level) - expected_level)
	var offense_response: float = pow(offense_index, 0.16) * pow(1.0 + level_advantage * 0.025, 0.1)
	return durability_response * wounded_relief * wave_response * offense_response


func _role_weight_factor(definition: EnemyDefinition, context: Dictionary) -> float:
	var factor: float = 1.0
	var crowd_power: float = float(context.get("crowd_power", 0.0))
	var precision_power: float = float(context.get("precision_power", 0.0))
	var level: int = int(context.get("level", 1))
	var round_number: int = int(context.get("round", 1))
	var role: int = definition.role

	# Weapon families make modest composition nudges; every authored positive
	# weight stays possible, and each factor is tightly bounded to avoid counters.
	if crowd_power < 0.8 and role in [EnemyDefinition.Role.CHASER, EnemyDefinition.Role.CHARGER]:
		factor += 0.12
	elif crowd_power > 2.0 and role in [EnemyDefinition.Role.RANGED, EnemyDefinition.Role.AREA_DENIAL]:
		factor += 0.12
	if precision_power > 1.6 and role in [EnemyDefinition.Role.CHARGER, EnemyDefinition.Role.BOSS]:
		factor += 0.08
	if level >= round_number + 4 and role in [EnemyDefinition.Role.CHARGER, EnemyDefinition.Role.AREA_DENIAL]:
		factor += 0.08
	return clampf(factor, 0.72, 1.30)


func _weighted_index_from_indices(
		indices: Array[int],
		definitions: Array[EnemyDefinition],
		authored_weights: Array[float]) -> int:
	if indices.is_empty():
		return 0
	var total: float = 0.0
	for index: int in indices:
		var weight: float = authored_weights[index] if index < authored_weights.size() else definitions[index].spawn_weight
		total += maxf(0.001, weight)
	var roll: float = randf() * total
	for index: int in indices:
		var weight: float = authored_weights[index] if index < authored_weights.size() else definitions[index].spawn_weight
		roll -= maxf(0.001, weight)
		if roll <= 0.0:
			return index
	return indices.back()


func _record_selection(definition: EnemyDefinition) -> void:
	_selected_enemy_ids[definition.id] = int(_selected_enemy_ids.get(definition.id, 0)) + 1
	_recent_enemy_ids.append(definition.id)
	if _recent_enemy_ids.size() > 3:
		_recent_enemy_ids.pop_front()


func _sum(values: Array[float]) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total
