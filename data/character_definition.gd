class_name CharacterDefinition
extends Resource
## Immutable starting profile and presentation data for a playable character.

@export var id: StringName = &"night_clerk"
@export var display_name: String = "Night Clerk"
@export var display_name_tr: String = "Gece Kasiyeri"
@export_multiline var description: String = ""
@export_multiline var description_tr: String = ""
@export var max_health: int = 100
@export var damage_multiplier: float = 1.0
@export var elemental_damage: int = 0
@export var starting_weapon_id: StringName = &"can_launcher"
@export_file("*.png") var portrait_path: String = "res://assets/generated/actors/player_night_clerk.png"
@export_file("*.png") var walk_atlas_path: String = "res://assets/generated/actors/player_night_clerk_walk.png"
