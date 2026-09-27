class_name ShiftScheduleDefinition
extends Resource
## Top-level authored run schedule. Phases cover the clock without gaps;
## gameplay state and the final boss remain owned by the run controller.

@export var id: StringName = &""
@export var display_name: String = ""
@export_range(1.0, 3600.0, 1.0) var duration_seconds: float = 300.0
@export var phases: Array[ShiftPhaseDefinition] = []
@export_range(0.0, 3600.0, 1.0) var boss_spawn_time: float = 240.0
@export var boss_definition: EnemyDefinition
@export var win_requires_boss_defeated: bool = true

