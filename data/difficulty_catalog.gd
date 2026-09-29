class_name DifficultyCatalog
extends RefCounted
## Difficulty profiles inspired by Brotato's cumulative Danger Levels.
## The authored campaign economy and player upgrade values remain unchanged.

const MAX_LEVEL := 6

const PROFILES: Array[Dictionary] = [
	{
		"level": 0, "name": "QUIET SHIFT", "name_tr": "SAKİN VARDİYA",
		"description": "The standard 20-wave shift. Learn the aisles and build your loadout.",
		"description_tr": "Standart 20 dalgalık vardiya. Reyonları tanı ve donanımını kur.",
		"enemy_health": 1.0, "enemy_damage": 1.0, "enemy_speed": 1.0,
		"pressure_waves": 0, "new_enemy_tier": 0, "double_boss": false,
	},
	{
		"level": 1, "name": "LATE DELIVERY", "name_tr": "GEÇ TESLİMAT",
		"description": "A new fast enemy type joins the later rounds.",
		"description_tr": "Sonraki dalgalara yeni ve hızlı bir düşman türü katılır.",
		"enemy_health": 1.0, "enemy_damage": 1.0, "enemy_speed": 1.0,
		"pressure_waves": 0, "new_enemy_tier": 1, "double_boss": false,
	},
	{
		"level": 2, "name": "BUSY NIGHT", "name_tr": "YOĞUN GECE",
		"description": "One pressure wave arrives in rounds 11–12, and another enemy type joins.",
		"description_tr": "11–12. dalgalardan birinde baskı dalgası ve yeni bir düşman türü gelir.",
		"enemy_health": 1.0, "enemy_damage": 1.0, "enemy_speed": 1.0,
		"pressure_waves": 1, "new_enemy_tier": 2, "double_boss": false,
	},
	{
		"level": 3, "name": "OVERTIME", "name_tr": "FAZLA MESAİ",
		"description": "Enemies have +12% health and damage. One pressure wave and more enemy types appear.",
		"description_tr": "Düşmanların canı ve hasarı +%12. Bir baskı dalgası ve daha fazla düşman türü eklenir.",
		"enemy_health": 1.12, "enemy_damage": 1.12, "enemy_speed": 1.0,
		"pressure_waves": 1, "new_enemy_tier": 3, "double_boss": false,
	},
	{
		"level": 4, "name": "STOCKROOM RUSH", "name_tr": "DEPO BASKINI",
		"description": "Enemies have +26% health and damage. Three pressure waves test the late shift.",
		"description_tr": "Düşmanların canı ve hasarı +%26. Üç baskı dalgası son vardiyayı zorlar.",
		"enemy_health": 1.26, "enemy_damage": 1.26, "enemy_speed": 1.0,
		"pressure_waves": 3, "new_enemy_tier": 4, "double_boss": false,
	},
	{
		"level": 5, "name": "CLOSING TIME", "name_tr": "KAPANIŞ SAATİ",
		"description": "Enemies have +40% health and damage. Three pressure waves and two bosses in the final round.",
		"description_tr": "Düşmanların canı ve hasarı +%40. Üç baskı dalgası ve son dalgada iki boss.",
		"enemy_health": 1.40, "enemy_damage": 1.40, "enemy_speed": 1.0,
		"pressure_waves": 3, "new_enemy_tier": 5, "double_boss": true,
	},
	{
		"level": 6, "name": "NIGHTMARE", "name_tr": "KÂBUS",
		"description": "Everything from Closing Time. Enemies have +60% health and damage, move 10% faster, and environmental shots and low-visibility fog appear.",
		"description_tr": "Kapanış Saati'nin tüm etkileri. Düşmanların canı ve hasarı +%60, hızları +%10; çevresel atışlar ve görüşü azaltan sis eklenir.",
		"enemy_health": 1.60, "enemy_damage": 1.60, "enemy_speed": 1.10,
		"pressure_waves": 3, "new_enemy_tier": 5, "double_boss": true,
		"environmental_hazards": true, "obscuring_fog": true,
	},
]


static func get_profile(level: int) -> Dictionary:
	return PROFILES[clampi(level, 0, MAX_LEVEL)].duplicate(true)


static func pressure_wave_rounds(level: int) -> Array[int]:
	if level < 2:
		return []
	if level < 4:
		return [11]
	return [11, 14, 17]


static func newly_introduced_enemy_id(tier: int) -> StringName:
	match tier:
		1: return &"scanline_runner"
		2: return &"cooler_dripper"
		3: return &"coupon_tosser"
		4: return &"pallet_jack_pusher"
		5: return &"night_shift_supervisor"
	return &""
