extends Node
class_name RoomEventDirector
## Owns per-wave room-event state for the facility. Room scenes report entry,
## pickup and interaction events through this node; authored definitions stay
## immutable and are copied into this director's state dictionaries.

signal objective_changed(supply_id: StringName, collected: int, required: int)
signal event_message(room_id: StringName, message: String)
signal event_resolved(event_id: StringName, success: bool)
signal helper_summoned(duration: float)

const HELPER_SCENE: PackedScene = preload("res://entities/helpers/temporary_shift_helper.tscn")
const POWERUP_SCENE: PackedScene = preload("res://progression/consumable_pickup/consumable_pickup.tscn")
const SUPPLY_SCENE: PackedScene = preload("res://progression/room_supply_pickup/room_supply_pickup.tscn")

@export var event_definitions: Array[RoomEventDefinition] = []

var _player: Node2D
var _actor_layer: Node2D
var _projectile_layer: Node2D
var _pickup_layer: Node2D
var _active_room_id: StringName = &""
var _active_event_anchor: Vector2 = Vector2.ZERO
var _wave_number: int = 0
var _random := RandomNumberGenerator.new()
## Runtime-only state keyed by event id; never stored back into .tres resources.
var _event_states: Dictionary = {}


func configure(
		definitions: Array[RoomEventDefinition],
		player: Node2D,
		actor_layer: Node2D,
		projectile_layer: Node2D,
		pickup_layer: Node2D
) -> void:
	event_definitions = definitions.duplicate()
	_player = player
	_actor_layer = actor_layer
	_projectile_layer = projectile_layer
	_pickup_layer = pickup_layer


func start_wave(wave_number: int, run_seed: int = 0) -> void:
	_wave_number = maxi(1, wave_number)
	_random.seed = run_seed if run_seed != 0 else int(Time.get_ticks_usec())
	_event_states.clear()
	for definition: RoomEventDefinition in event_definitions:
		if definition == null or definition.id == &"" or definition.room_id == &"":
			continue
		var state := {
			"definition": definition,
			"resolved": false,
			"spawned": false,
			"announced": false,
			"remaining": _random.randf_range(
				minf(definition.min_delay_seconds, definition.max_delay_seconds),
				maxf(definition.min_delay_seconds, definition.max_delay_seconds)
			),
			"collected": 0,
			"required": _random.randi_range(
				mini(definition.request_minimum, definition.request_maximum),
				maxi(definition.request_minimum, definition.request_maximum)
			),
		}
		_event_states[definition.id] = state
		if definition.kind == RoomEventDefinition.Kind.SUPPLY_REQUEST:
			objective_changed.emit(definition.requested_supply_id, 0, int(state["required"]))


func enter_room(room_id: StringName, event_anchor: Vector2) -> void:
	_active_room_id = room_id
	_active_event_anchor = event_anchor
	for value: Variant in _event_states.values():
		var state: Dictionary = value
		var definition := state["definition"] as RoomEventDefinition
		if definition.room_id == _active_room_id and definition.kind == RoomEventDefinition.Kind.TIMED_POWERUP:
			if not bool(state["announced"]) and not bool(state["spawned"]) and not bool(state["resolved"]):
				event_message.emit(room_id, definition.display_name)
				state["announced"] = true
		_event_states[definition.id] = state


func leave_room() -> void:
	_active_room_id = &""


func _process(delta: float) -> void:
	if _active_room_id == &"":
		return
	for event_id: Variant in _event_states.keys():
		var state: Dictionary = _event_states[event_id]
		var definition := state["definition"] as RoomEventDefinition
		if definition.room_id != _active_room_id or definition.kind != RoomEventDefinition.Kind.TIMED_POWERUP:
			continue
		if bool(state["spawned"]) or bool(state["resolved"]):
			continue
		state["remaining"] = maxf(0.0, float(state["remaining"]) - delta)
		if float(state["remaining"]) <= 0.0:
			state["spawned"] = _spawn_powerup(definition, _active_event_anchor)
			state["resolved"] = bool(state["spawned"])
			if bool(state["spawned"]):
				event_resolved.emit(definition.id, true)
		_event_states[event_id] = state


func spawn_supply_pickup(world_position: Vector2, supply_id: StringName, amount: int = 1) -> Node2D:
	if not is_instance_valid(_pickup_layer) or supply_id == &"":
		return null
	var pickup := SUPPLY_SCENE.instantiate() as RoomSupplyPickup
	if pickup == null:
		return null
	pickup.supply_id = supply_id
	pickup.amount = maxi(1, amount)
	pickup.set_meta("room_id", _active_room_id)
	pickup.collected.connect(report_supply_collected)
	_pickup_layer.call_deferred("add_child", pickup)
	pickup.global_position = world_position
	return pickup


func roll_requested_supply_drop(world_position: Vector2, drop_chance: float = 0.2) -> bool:
	if _random.randf() >= clampf(drop_chance, 0.0, 1.0):
		return false
	for value: Variant in _event_states.values():
		var state: Dictionary = value
		var definition := state["definition"] as RoomEventDefinition
		if definition.kind != RoomEventDefinition.Kind.SUPPLY_REQUEST or bool(state["resolved"]):
			continue
		if int(state["collected"]) >= int(state["required"]):
			continue
		return is_instance_valid(spawn_supply_pickup(world_position, definition.requested_supply_id))
	return false


func report_supply_collected(supply_id: StringName, amount: int = 1) -> void:
	if amount <= 0:
		return
	for event_id: Variant in _event_states.keys():
		var state: Dictionary = _event_states[event_id]
		var definition := state["definition"] as RoomEventDefinition
		if definition.kind != RoomEventDefinition.Kind.SUPPLY_REQUEST or definition.requested_supply_id != supply_id:
			continue
		if bool(state["resolved"]):
			continue
		if int(state["collected"]) >= int(state["required"]):
			return
		state["collected"] = mini(int(state["required"]), int(state["collected"]) + amount)
		_event_states[event_id] = state
		objective_changed.emit(supply_id, int(state["collected"]), int(state["required"]))
		if int(state["collected"]) >= int(state["required"]):
			event_message.emit(definition.room_id, "Supply request ready")
		return


func claim_supply_request() -> bool:
	if _active_room_id == &"" or not is_instance_valid(_player) or not is_instance_valid(_actor_layer):
		return false
	for event_id: Variant in _event_states.keys():
		var state: Dictionary = _event_states[event_id]
		var definition := state["definition"] as RoomEventDefinition
		if definition.room_id != _active_room_id or definition.kind != RoomEventDefinition.Kind.SUPPLY_REQUEST:
			continue
		if bool(state["resolved"]) or int(state["collected"]) < int(state["required"]):
			return false
		var helper := HELPER_SCENE.instantiate() as TemporaryShiftHelper
		if helper == null:
			return false
		_actor_layer.add_child(helper)
		helper.set_meta("room_id", _active_room_id)
		helper.global_position = _player.global_position + Vector2(34.0, -20.0)
		helper.activate(
			_player,
			_projectile_layer,
			definition.helper_duration,
			definition.helper_damage,
			definition.helper_fire_interval
		)
		state["resolved"] = true
		_event_states[event_id] = state
		helper_summoned.emit(definition.helper_duration)
		event_resolved.emit(event_id, true)
		event_message.emit(_active_room_id, "Temporary helper joined the shift")
		return true
	return false


func get_objective_status(room_id: StringName) -> Dictionary:
	for value: Variant in _event_states.values():
		var state: Dictionary = value
		var definition := state["definition"] as RoomEventDefinition
		if definition.room_id == room_id and definition.kind == RoomEventDefinition.Kind.SUPPLY_REQUEST:
			return {
				"event_id": definition.id,
				"supply_id": definition.requested_supply_id,
				"collected": int(state["collected"]),
				"required": int(state["required"]),
				"resolved": bool(state["resolved"]),
			}
	return {}


func _spawn_powerup(definition: RoomEventDefinition, world_position: Vector2) -> bool:
	if not is_instance_valid(_pickup_layer):
		return false
	var pickup := POWERUP_SCENE.instantiate() as ConsumablePickup
	if pickup == null:
		return false
	pickup.reward = clampi(definition.powerup_reward, 0, ConsumablePickup.Reward.size() - 1)
	pickup.set_meta("room_id", definition.room_id)
	_pickup_layer.add_child(pickup)
	pickup.global_position = world_position
	event_message.emit(definition.room_id, definition.display_name + " appeared")
	return true
