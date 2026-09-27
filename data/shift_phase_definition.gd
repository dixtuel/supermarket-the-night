class_name ShiftPhaseDefinition
extends Resource
## Time window in the five-minute shift. Spawn weights align by index with
## enemy_definitions. The editor-authored resource is read-only run input.

@export var id: StringName = &""
@export var display_name: String = ""
@export_range(0.0, 3600.0, 0.1) var start_seconds: float = 0.0
@export_range(0.0, 3600.0, 0.1) var end_seconds: float = 60.0
@export var store_background: Texture2D
@export_range(0.05, 60.0, 0.05) var spawn_interval: float = 1.6
@export_range(1, 10000, 1) var max_alive: int = 20
@export_range(0.1, 100.0, 0.05) var enemy_health_multiplier: float = 1.0
@export var enemy_definitions: Array[EnemyDefinition] = []
@export var spawn_weights: Array[float] = []

