class_name WaveDefinition
extends Resource
## Authored encounter template. Shared resources are immutable run inputs.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var purpose: String = ""
@export_range(1.0, 3600.0, 1.0) var duration_seconds: float = 60.0
## Total enemy spawn budget for this wave; the arena stops normal/event spawns
## when it is reached.
@export_range(0, 10000, 1) var planned_spawn_count: int = 0
## Optional Endless-only count change applied once per completed 10-wave cycle.
## Negative values let a later cycle trade raw enemy count for tougher roles.
@export_range(-10000, 10000, 1) var endless_cycle_spawn_delta: int = 0
@export_range(0.05, 60.0, 0.05) var spawn_interval: float = 1.6
@export_range(1, 10000, 1) var max_alive: int = 20
@export_range(0.1, 100.0, 0.05) var enemy_health_multiplier: float = 1.0
## Indices align with spawn_weights; weights should sum to 1.0.
@export var enemy_definitions: Array[EnemyDefinition] = []
@export var spawn_weights: Array[float] = []
@export var event_tag: StringName = &""
@export_multiline var event_description: String = ""
@export var is_boss_wave: bool = false
@export var boss_definition: EnemyDefinition
## Seconds from wave start; only used when is_boss_wave is true.
@export_range(0.0, 3600.0, 1.0) var boss_spawn_seconds: float = 0.0
