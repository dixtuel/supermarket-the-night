class_name RoomEventDefinition
extends Resource
## Authored room-event rules. The event director copies mutable progress to
## per-run state and does not modify these shared definitions.

enum Kind {
	TIMED_POWERUP,
	SUPPLY_REQUEST,
}

@export var id: StringName = &""
@export var room_id: StringName = &""
@export_range(1, 20, 1) var minimum_wave: int = 1
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.TIMED_POWERUP
@export_range(0.0, 600.0, 0.5) var min_delay_seconds: float = 18.0
@export_range(0.0, 600.0, 0.5) var max_delay_seconds: float = 42.0
@export_range(1, 20, 1) var request_minimum: int = 3
@export_range(1, 20, 1) var request_maximum: int = 5
@export var requested_supply_id: StringName = &""
## Uses ConsumablePickup.Reward values for the existing health/energy pickups.
@export_range(0, 4, 1) var powerup_reward: int = 1
@export_range(1.0, 120.0, 1.0) var helper_duration: float = 24.0
@export_range(1, 100, 1) var helper_damage: int = 5
@export_range(0.1, 10.0, 0.05) var helper_fire_interval: float = 0.9
