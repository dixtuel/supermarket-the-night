class_name WeaponClassCatalog
extends RefCounted
## Supermarket-themed weapon family set bonuses.

const DEFINITIONS: Array[WeaponClassDefinition] = [
	preload("res://data/weapon_classes/blade.tres"),
	preload("res://data/weapon_classes/gun.tres"),
	preload("res://data/weapon_classes/elemental.tres"),
	preload("res://data/weapon_classes/heavy.tres"),
	preload("res://data/weapon_classes/tool.tres"),
	preload("res://data/weapon_classes/support.tres"),
]


static func get_definition(class_id: int) -> WeaponClassDefinition:
	for definition: WeaponClassDefinition in DEFINITIONS:
		if definition != null and int(definition.class_id) == class_id:
			return definition
	return null


static func get_bonus(class_id: int, stat: int, weapon_count: int) -> float:
	var definition := get_definition(class_id)
	return definition.bonus(stat, weapon_count) if definition != null else 0.0


static func describe_set(class_id: int, weapon_count: int) -> String:
	var definition := get_definition(class_id)
	if definition == null or weapon_count <= 0:
		return ""
	var class_label := definition.display_name.to_upper()
	if weapon_count < 2:
		return "%s %d/6 · 1 MORE FOR SET BONUS" % [class_label, weapon_count]
	var parts: Array[String] = []
	for stat: int in [
		WeaponClassDefinition.BonusStat.MELEE_DAMAGE,
		WeaponClassDefinition.BonusStat.RANGED_DAMAGE,
		WeaponClassDefinition.BonusStat.ELEMENTAL_DAMAGE,
		WeaponClassDefinition.BonusStat.ENGINEERING,
		WeaponClassDefinition.BonusStat.ATTACK_SPEED,
		WeaponClassDefinition.BonusStat.LIFESTEAL,
		WeaponClassDefinition.BonusStat.HARVESTING,
		WeaponClassDefinition.BonusStat.WEAPON_DAMAGE,
	]:
		var amount := definition.bonus(stat, weapon_count)
		if amount <= 0.0:
			continue
		parts.append(_format_bonus(stat, amount))
	return "%s %d/6 · %s" % [class_label, weapon_count, " / ".join(parts)]


static func _format_bonus(stat: int, amount: float) -> String:
	match stat:
		WeaponClassDefinition.BonusStat.MELEE_DAMAGE:
			return "+%d melee" % roundi(amount)
		WeaponClassDefinition.BonusStat.RANGED_DAMAGE:
			return "+%d ranged" % roundi(amount)
		WeaponClassDefinition.BonusStat.ELEMENTAL_DAMAGE:
			return "+%d elemental" % roundi(amount)
		WeaponClassDefinition.BonusStat.ENGINEERING:
			return "+%d engineering" % roundi(amount)
		WeaponClassDefinition.BonusStat.ATTACK_SPEED:
			return "+%d%% attack speed" % roundi(amount * 100.0)
		WeaponClassDefinition.BonusStat.LIFESTEAL:
			return "+%d%% lifesteal" % roundi(amount * 100.0)
		WeaponClassDefinition.BonusStat.HARVESTING:
			return "+%d harvesting" % roundi(amount)
		WeaponClassDefinition.BonusStat.WEAPON_DAMAGE:
			return "+%d%% class damage" % roundi(amount * 100.0)
	return ""
