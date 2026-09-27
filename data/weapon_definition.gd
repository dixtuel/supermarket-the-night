class_name WeaponDefinition
extends Resource
## Authored weapon tuning. Treat loaded resources as immutable; active run
## modifiers belong to runtime weapon state, not these shared definitions.

enum AttackMode {
	TARGETED_PROJECTILE,
	ORBITAL_CONTACT,
	RETURNING_PROJECTILE,
	DEPLOYED_SLOW_ZONE,
}

enum ShopOfferKind { NEW_WEAPON, MERGE_COPY, DIRECT_TIER }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var sprite: Texture2D
@export_range(1, 4, 1) var tier: int = 1
@export var shop_offer_kind: ShopOfferKind = ShopOfferKind.NEW_WEAPON
@export var attack_mode: AttackMode = AttackMode.TARGETED_PROJECTILE
@export_range(1, 10000, 1) var damage: int = 10
## Matches SurvivorAutoWeapon's current authored field names.
@export_range(0.05, 60.0, 0.05) var fire_interval: float = 0.65
@export_range(0.0, 2000.0, 1.0) var target_range: float = 420.0
@export_range(0.0, 128.0, 1.0) var muzzle_offset: float = 12.0

## Mode-specific tuning. Controllers copy these into runtime state.
@export_range(0.0, 2000.0, 1.0) var projectile_speed: float = 560.0
@export_range(0.05, 30.0, 0.05) var projectile_lifetime: float = 1.5
@export_range(1, 32, 1) var projectile_count: int = 1
@export_range(0, 32, 1) var pierce_count: int = 0
@export_range(0.0, 512.0, 1.0) var area_radius: float = 0.0
@export_range(0.0, 30.0, 0.05) var effect_duration: float = 0.0
@export_range(0.05, 1.0, 0.05) var slow_multiplier: float = 1.0
@export_range(-20.0, 20.0, 0.1) var orbit_speed: float = 0.0
@export_range(0.0, 1000.0, 1.0) var return_distance: float = 0.0
