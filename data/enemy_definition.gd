class_name EnemyDefinition
extends Resource
## Authored enemy tuning shared by a shift schedule and its actor.
## Runtime systems should copy these values into actor state and never mutate
## this shared catalog resource.

enum Role {
	CHASER,
	CHARGER,
	AREA_DENIAL,
	RANGED,
	BOSS,
}

enum AttackType {
	CONTACT,
	CHARGE,
	RANGED_PROJECTILE,
	DROP_ZONE,
	CHARGE_AND_SCATTER,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var combat_read: String = ""
@export var role: Role = Role.CHASER
## Actor texture or four-direction walk atlas. Keep art separately licensed.
@export var sprite: Texture2D
@export var directional_walk_atlas: bool = false
## Per-definition art scale. Large single-frame illustrations can opt down while
## atlas-based sprites keep the shared actor scale.
@export_range(0.03, 0.4, 0.01) var sprite_scale: float = 0.2

## Fields consumed by the current chase/contact enemy implementation.
@export_range(0.0, 1000.0, 1.0) var move_speed: float = 60.0
@export_range(1, 100000, 1) var max_health: int = 30
## Flat, enemy-specific additions applied for each wave after wave 1. This
## follows the supplied reference's +HP/+damage per wave model; authored wave
## multipliers remain a separate encounter-level pressure control.
@export_range(0.0, 5000.0, 0.1) var health_growth_per_wave: float = 0.0
@export_range(0.0, 1000.0, 0.1) var damage_growth_per_wave: float = 0.0
@export_range(0, 10000, 1) var contact_damage: int = 8
@export_range(1.0, 256.0, 1.0) var contact_range: float = 36.0
@export_range(0.05, 60.0, 0.05) var contact_interval: float = 1.0
@export_range(0, 10000, 1) var xp_reward: int = 1
## Stock tokens are a separate reward from XP, so enemy and economy tuning can
## move independently.
@export_range(0, 10000, 1) var material_reward: int = 1

## Optional role-specific behavior data for future actor controllers.
@export var attack_type: AttackType = AttackType.CONTACT
@export_range(0.0, 1000.0, 1.0) var attack_range: float = 0.0
@export_range(0.05, 60.0, 0.05) var attack_interval: float = 1.0
@export_range(0, 10000, 1) var attack_damage: int = 0
@export_range(0.0, 2000.0, 1.0) var charge_speed: float = 0.0
@export_range(0.0, 10.0, 0.05) var telegraph_duration: float = 0.0
@export_range(0.0, 10.0, 0.05) var recovery_duration: float = 0.0
@export_range(0.0, 2000.0, 1.0) var projectile_speed: float = 0.0
@export_range(0, 32, 1) var projectile_count: int = 0
@export_range(0.0, 256.0, 1.0) var zone_radius: float = 0.0
@export_range(0.0, 30.0, 0.1) var zone_duration: float = 0.0
@export_range(0.05, 1.0, 0.05) var zone_speed_multiplier: float = 1.0
@export_range(0.0, 100.0, 0.05) var spawn_weight: float = 1.0
