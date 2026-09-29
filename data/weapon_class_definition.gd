class_name WeaponClassDefinition
extends Resource
## Read-only set-bonus data. Each additional distinct weapon after the first
## grants the authored amount, up to the six-slot cap.

enum BonusStat {
	NONE,
	MELEE_DAMAGE,
	RANGED_DAMAGE,
	ELEMENTAL_DAMAGE,
	ENGINEERING,
	ATTACK_SPEED,
	LIFESTEAL,
	HARVESTING,
	WEAPON_DAMAGE
}

@export var class_id: WeaponDefinition.WeaponClass = WeaponDefinition.WeaponClass.BLADE
@export var display_name: String = ""
@export var primary_bonus_stat: BonusStat = BonusStat.NONE
@export var primary_per_additional_weapon: float = 0.0
@export var secondary_bonus_stat: BonusStat = BonusStat.NONE
@export var secondary_per_additional_weapon: float = 0.0


func bonus(stat: int, weapon_count: int) -> float:
	if weapon_count < 2:
		return 0.0
	var extra_weapons := mini(5, weapon_count - 1)
	if stat == primary_bonus_stat:
		return primary_per_additional_weapon * float(extra_weapons)
	if stat == secondary_bonus_stat:
		return secondary_per_additional_weapon * float(extra_weapons)
	return 0.0
