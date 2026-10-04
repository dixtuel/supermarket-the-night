extends Node
## Central Internationalization (I18n) Singleton.
## Manages English and Turkish translations and persists language preference.

signal language_changed(new_locale: String)

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LOCALE := "en"

var current_locale: String = "en"

const TRANSLATIONS: Dictionary = {
	"tr": {
		# Title Screen
		"TITLE_CAMPAIGN": "20 DALGALI KAMPANYA",
		"TITLE_CAMPAIGN_DESC": "Sabaha kadar 20 vardiya dalgasında hayatta kal.",
		"TITLE_ENDLESS": "SONSUZ GECE MODU",
		"TITLE_ENDLESS_DESC": "Döngüsel elitler ve limitsiz gece baskınları.",
		"TITLE_CONTINUE": "VARDİYAYA DEVAM ET (Dalga %02d)",
		"TITLE_CONTINUE_DESC": "Kaydedilen vardiyadan devam et.",
		"TITLE_RECORDS": "PERFORMANS KAYITLARI",
		"TITLE_MANUAL": "NASIL OYNANIR (REHBER)",
		"TITLE_SETTINGS": "AYARLAR & SEÇENEKLER",
		"TITLE_CREDITS": "EMEĞİ GEÇENLER",
		"TITLE_QUIT": "OYUNDAN ÇIK",

		# Settings Modal
		"SETTINGS_TITLE": "AYARLAR — SES, EKRAN & DİL",
		"SETTINGS_LANGUAGE": "OYUN DİLİ / LANGUAGE",
		"SETTINGS_DISPLAY_TITLE": "EKRAN VE ÇÖZÜNÜRLÜK",
		"SETTINGS_RESOLUTION": "ÇÖZÜNÜRLÜK",
		"SETTINGS_WINDOW_MODE": "EKRAN MODU",
		"SETTINGS_TOUCH_CONTROLS": "Dokunmatik joystick kullan",
		"WINDOW_FULLSCREEN": "Tam Ekran",
		"WINDOW_BORDERLESS": "Kenarlıksız",
		"WINDOW_WINDOWED": "Pencereli",
		"SETTINGS_MUSIC": "GECE VARDİYASI MÜZİĞİ",
		"SETTINGS_SFX": "SES EFEKTLERİ (SFX)",
		"SETTINGS_SAVE": "KAYDET VE KAPAT",

		# Pause Menu
		"PAUSE_TITLE": "VARDİYA DURDURULDU",
		"PAUSE_SUBTITLE": "Reyonlar biraz bekleyebilir. Saat durduruldu.",
		"PAUSE_RESUME": "REYONLARA DÖN",
		"PAUSE_SAVE_QUIT": "KAYDET VE ÇIK",
		"PAUSE_RESTART": "YENİDEN BAŞLAT",
		"PAUSE_SETTINGS": "AYARLAR",
		"PAUSE_TITLE_MENU": "ANA MENÜYE DÖN",
		"PAUSE_QUIT_DESKTOP": "MASAÜSTÜNE ÇIK",

		# Shop Screen
		"SHOP_TITLE": "Vardiya Deposu",
		"SHOP_SUBTITLE": "Sonraki dalga için malzeme seç veya reyonlara geri dön.",
		"SHOP_WAVE_COMPLETE": "DALGA %02d TAMAMLANDI",
		"SHOP_TOKENS": "stok jetonu",
		"SHOP_REFRESH": "Reyonu Yenile (%d)",
		"SHOP_NOTE": "Ürünler her dalga sonrası yenilenir.",
		"SHOP_RETURN": "Reyonlara Dön",
		"SHOP_BUY": "Satın Al",
		"SHOP_PURCHASED": "SATIN ALINDI",
		"SHOP_EMPTY": "Reyon boş. Devam etmek için reyonlara dönün.",
		"SHOP_NEW_WEAPON": "YENİ SİLAH",
		"SHOP_UPGRADE": "VARDİYA YÜKSELTMESİ",
		"SHOP_STAT": "KALICI GELİŞTİRME",
		"SHOP_MERGE": "BİRLEŞTİRME KOPYASI",
		"SHOP_INVENTORY": "ENVANTER  ·  YÜKSELTMELER & KONUŞLANDIRILANLAR",
		"SHOP_WEAPONS_COUNT": "SİLAHLAR (%d/6)  ·  DETAYLAR İÇİN SEÇ",
		"SHOP_DETAILS": "DETAYLAR",
		"SHOP_LOCK": "KİLİTLE",
		"SHOP_UNLOCK": "KİLİDİ AÇ",
		"SHOP_CLOSE": "KAPAT",
		"SHOP_SELL_FOR": "SAT · %d JETON",

		# Level Up / Stat choices
		"LEVELUP_TITLE": "Vardiya Bonusu Seç",
		"LEVELUP_SUBTITLE": "Bir malzeme seç. Zaman durduruldu.",
		"STAT_TITLE": "Vardiyanı Özelleştir",
		"STAT_SUBTITLE": "Kalıcı bir özellik seç. Zaman durduruldu.",

		# HUD Elements
		"HUD_WAVE": "DALGA",
		"HUD_SHIFT_TIME": "VARDİYA",
		"HUD_KNOCKED": "ETKİSİZ",
		"HUD_LEVEL": "SEVİYE",
		"HUD_EQUIPMENT": "DONANIM",
		"HUD_BOSS": "ELİT MÜŞTERİ",
		"HUD_EVENT": "ODA OLAYI",

		# Results Screen
		"RESULTS_VICTORY": "Vardiya Başarıyla Tamamlandı!",
		"RESULTS_DEFEAT": "Vardiya Erken Bitti",
		"RESULTS_ENDLESS_OVER": "Sonsuz Gece Sona Erdi",
		"RESULTS_VICTORY_SUB": "Bakkal sabah 07:00 açılışına kadar ayakta kaldı.",
		"RESULTS_DEFEAT_SUB": "Gece vardiyasının baskısı galip geldi.",
		"RESULTS_ENDLESS_SUB": "Marketi %02d. dalgaya kadar savundun.",
		"RESULTS_RESTART": "YENİDEN DENE",
		"RESULTS_TITLE": "ANA MENÜ",

		# Records Modal
		"RECORDS_TITLE": "VARDİYA RAPORU — PERFORMANS KAYITLARI",
		"RECORDS_STORE_LOG": "BAKKAL 24/7 MARKET · KASA 01 GÜNLÜĞÜ",
		"RECORDS_BEST_CAMPAIGN": "EN İYİ KAMPANYA SKORU",
		"RECORDS_ENDLESS_WAVE": "SONSUZ EN İYİ DALGA",
		"RECORDS_ENDLESS_SCORE": "SONSUZ EN İYİ SKOR",
		"RECORDS_DIRECTIVE": "GÖREV: 07:00'A KADAR REYONLARI KORU",
		"RECORDS_CLOSE": "GERİ DÖN",

		# Help / Manual Modal
		"MANUAL_TITLE": "VARDİYA KILAVUZU — REYON REHBERİ",
		"MANUAL_MOVE_TITLE": "HAREKET VE REYONLAR",
		"MANUAL_MOVE_DESC": "WASD veya ok tuşları ile hareket et, market arabalarından kaçın.",
		"MANUAL_TOOLS_TITLE": "OTOMATİK EKİPMANLAR",
		"MANUAL_TOOLS_DESC": "Market araçları yakındaki hedeflere otomatik olarak saldırır.",
		"MANUAL_TOKENS_TITLE": "STOK JETONLARI VE TECRÜBE",
		"MANUAL_TOKENS_DESC": "Düşmanlardan düşen jeton ve tecrübe puanlarını toplayarak geliş.",
		"MANUAL_PAUSE_TITLE": "DURAKLATMA TERMİNALİ",
		"MANUAL_PAUSE_DESC": "Vardiyayı durdurup kaydetmek için istediğin an ESC tuşuna bas.",
		"MANUAL_CLOSE": "VARDİYAYA DÖN",

		# Stats & Upgrades
		"STAT_MAX_HEALTH": "Maksimum Can",
		"STAT_SPEED": "Hareket Hızı",
		"STAT_DODGE": "Kaçınma Şansı",
		"STAT_LIFESTEAL": "Can Çalma",
		"STAT_DAMAGE": "Hasar Gücü",
		"STAT_ARMOR": "Zırh / Koruma",
	},
	"en": {
		# Title Screen
		"TITLE_CAMPAIGN": "20-ROUND CAMPAIGN",
		"TITLE_CAMPAIGN_DESC": "Survive 20 shift waves until morning opening.",
		"TITLE_ENDLESS": "ENDLESS NIGHT",
		"TITLE_ENDLESS_DESC": "Cycling elites and unlimited night raids.",
		"TITLE_CONTINUE": "CONTINUE SHIFT (Wave %02d)",
		"TITLE_CONTINUE_DESC": "Resume saved shift progress.",
		"TITLE_RECORDS": "PERFORMANCE RECORDS",
		"TITLE_MANUAL": "HOW TO PLAY (MANUAL)",
		"TITLE_SETTINGS": "OPTIONS & SETTINGS",
		"TITLE_CREDITS": "CREDITS",
		"TITLE_QUIT": "QUIT GAME",

		# Settings Modal
		"SETTINGS_TITLE": "OPTIONS — SOUND, DISPLAY & LANGUAGE",
		"SETTINGS_LANGUAGE": "GAME LANGUAGE / DİL",
		"SETTINGS_DISPLAY_TITLE": "DISPLAY & RESOLUTION",
		"SETTINGS_RESOLUTION": "RESOLUTION",
		"SETTINGS_WINDOW_MODE": "WINDOW MODE",
		"SETTINGS_TOUCH_CONTROLS": "Use touch joystick",
		"WINDOW_FULLSCREEN": "Fullscreen",
		"WINDOW_BORDERLESS": "Borderless",
		"WINDOW_WINDOWED": "Windowed",
		"SETTINGS_MUSIC": "NIGHT SHIFT MUSIC",
		"SETTINGS_SFX": "GAME FEEDBACK (SFX)",
		"SETTINGS_SAVE": "SAVE AND CLOSE",

		# Pause Menu
		"PAUSE_TITLE": "SHIFT ON HOLD",
		"PAUSE_SUBTITLE": "The aisles can wait. The clock is paused.",
		"PAUSE_RESUME": "RETURN TO AISLES",
		"PAUSE_SAVE_QUIT": "SAVE AND QUIT",
		"PAUSE_RESTART": "RESTART SHIFT",
		"PAUSE_SETTINGS": "OPTIONS",
		"PAUSE_TITLE_MENU": "MAIN MENU",
		"PAUSE_QUIT_DESKTOP": "QUIT TO DESKTOP",

		# Shop Screen
		"SHOP_TITLE": "The Stockroom",
		"SHOP_SUBTITLE": "Pick supplies for the next wave, or head back to the aisles.",
		"SHOP_WAVE_COMPLETE": "WAVE %02d COMPLETE",
		"SHOP_TOKENS": "stock tokens",
		"SHOP_REFRESH": "Refresh shelf (%d)",
		"SHOP_NOTE": "Offers restock after each wave.",
		"SHOP_RETURN": "Return to aisles",
		"SHOP_BUY": "Take from shelf",
		"SHOP_PURCHASED": "PURCHASED",
		"SHOP_EMPTY": "The shelf is empty. Return to the aisles to continue.",
		"SHOP_NEW_WEAPON": "NEW WEAPON",
		"SHOP_UPGRADE": "SHIFT UPGRADE",
		"SHOP_STAT": "SHIFT STAT",
		"SHOP_MERGE": "MERGE COPY",
		"SHOP_INVENTORY": "INVENTORY  ·  UPGRADES & DEPLOYABLES",
		"SHOP_WEAPONS_COUNT": "WEAPONS (%d/6)  ·  SELECT FOR DETAILS",
		"SHOP_DETAILS": "DETAILS",
		"SHOP_LOCK": "LOCK",
		"SHOP_UNLOCK": "UNLOCK",
		"SHOP_CLOSE": "CLOSE",
		"SHOP_SELL_FOR": "SELL · %d TOKENS",

		# Level Up / Stat choices
		"LEVELUP_TITLE": "Choose a shift bonus",
		"LEVELUP_SUBTITLE": "One item comes off the shelf. The clock is paused.",
		"STAT_TITLE": "Adjust your shift",
		"STAT_SUBTITLE": "Choose one lasting stat. The clock is paused.",

		# HUD Elements
		"HUD_WAVE": "WAVE",
		"HUD_SHIFT_TIME": "SHIFT TIME",
		"HUD_KNOCKED": "KNOCKED OUT",
		"HUD_LEVEL": "LEVEL",
		"HUD_EQUIPMENT": "EQUIPMENT",
		"HUD_BOSS": "ELITE SHOPPER",
		"HUD_EVENT": "ROOM EVENT",

		# Results Screen
		"RESULTS_VICTORY": "Shift Survived!",
		"RESULTS_DEFEAT": "Shift Cut Short",
		"RESULTS_ENDLESS_OVER": "Endless Night Over",
		"RESULTS_VICTORY_SUB": "The store made it to the 07:00 morning opening.",
		"RESULTS_DEFEAT_SUB": "The night shift got the better of you.",
		"RESULTS_ENDLESS_SUB": "You held the store through wave %02d.",
		"RESULTS_RESTART": "TRY AGAIN",
		"RESULTS_TITLE": "MAIN MENU",

		# Records Modal
		"RECORDS_TITLE": "SHIFT AUDIT — PERFORMANCE RECORDS",
		"RECORDS_STORE_LOG": "BAKKAL 24/7 MART · REGISTER 01 LOG",
		"RECORDS_BEST_CAMPAIGN": "BEST CAMPAIGN SCORE",
		"RECORDS_ENDLESS_WAVE": "ENDLESS BEST WAVE",
		"RECORDS_ENDLESS_SCORE": "ENDLESS BEST SCORE",
		"RECORDS_DIRECTIVE": "DIRECTIVE: KEEP AISLES PATROLLED UNTIL 07:00",
		"RECORDS_CLOSE": "BACK TO SHIFT",

		# Help / Manual Modal
		"MANUAL_TITLE": "SHIFT MANUAL — AISLE DIRECTIVE",
		"MANUAL_MOVE_TITLE": "MOVEMENT & AISLE NAVIGATION",
		"MANUAL_MOVE_DESC": "Move with WASD or arrow keys to patrol grocery aisles and evade cart hazards.",
		"MANUAL_TOOLS_TITLE": "AUTOMATIC TOOLS",
		"MANUAL_TOOLS_DESC": "Store tools engage nearby targets automatically. Position your reach to clear aisles.",
		"MANUAL_TOKENS_TITLE": "STOCK TOKENS & XP",
		"MANUAL_TOKENS_DESC": "Collect tokens and XP for upgrades between rounds.",
		"MANUAL_PAUSE_TITLE": "PAUSE TERMINAL",
		"MANUAL_PAUSE_DESC": "Press ESC anytime to pause the shift and save progress.",
		"MANUAL_CLOSE": "BACK TO SHIFT",

		# Stats & Upgrades
		"STAT_MAX_HEALTH": "Max Health",
		"STAT_SPEED": "Movement Speed",
		"STAT_DODGE": "Dodge Chance",
		"STAT_LIFESTEAL": "Life Steal",
		"STAT_DAMAGE": "Damage",
		"STAT_ARMOR": "Armor",
	}
}


func _ready() -> void:
	load_language_setting()


func t(key: String, fallback: String = "") -> String:
	var dict: Dictionary = TRANSLATIONS.get(current_locale, TRANSLATIONS["en"])
	if dict.has(key):
		return dict[key]
	var en_dict: Dictionary = TRANSLATIONS["en"]
	if en_dict.has(key):
		return en_dict[key]
	return fallback if not fallback.is_empty() else key


func set_language(locale: String) -> void:
	if locale != "tr" and locale != "en":
		locale = "en"
	if current_locale == locale:
		return
	current_locale = locale
	save_language_setting()
	language_changed.emit(current_locale)


func load_language_setting() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		current_locale = config.get_value("general", "language", DEFAULT_LOCALE)
	else:
		current_locale = DEFAULT_LOCALE


func save_language_setting() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("general", "language", current_locale)
	config.save(SETTINGS_PATH)
