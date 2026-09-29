class_name UpgradeDefinition
extends Resource
## One level-up offer. Upgrade effects are authored data; application code
## should mutate per-run stats and never modify this shared resource.

enum Effect {
	UNLOCK_WEAPON,
	WEAPON_DAMAGE_ADD,
	FIRE_RATE_MULTIPLIER,
	PROJECTILE_COUNT_ADD,
	PROJECTILE_SPEED_MULTIPLIER,
	WEAPON_DAMAGE_MULTIPLIER,
	WEAPON_PIERCE_ADD,
	WEAPON_RADIUS_ADD,
	PLAYER_MOVE_SPEED_MULTIPLIER,
	PLAYER_MAX_HEALTH_ADD,
	PLAYER_LIFESTEAL_ADD,
	PLAYER_DODGE_ADD,
	PLAYER_ENGINEERING_ADD,
	WEAPON_REACH_ADD,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effect: Effect = Effect.UNLOCK_WEAPON
@export var unlocks_weapon: WeaponDefinition
## Shop-card art; weapon-unlock upgrades reuse their matching weapon icon.
@export var icon: Texture2D
## Empty means a player-wide stat; otherwise target a stable weapon id.
@export var target_weapon_id: StringName = &""
@export_range(-10000.0, 10000.0, 0.01) var value: float = 0.0
## Used by health upgrades for the immediate heal accompanying max HP.
@export_range(0.0, 10000.0, 1.0) var immediate_heal: float = 0.0
@export_range(1, 20, 1) var max_rank: int = 1
