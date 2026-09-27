extends CanvasLayer
class_name SurvivorHud

signal upgrade_selected(index: int)
signal stat_choice_selected(choice_id: StringName)
signal pause_requested
signal resume_requested
signal restart_requested
signal title_requested
signal save_and_quit_requested
signal settings_requested

@export var display_font: FontFile

const INK := Color("101820")
const PANEL := Color("1a2b30", 0.94)
const PANEL_EDGE := Color("71847d")
const TEXT := Color("f1e7ce")
const MUTED := Color("a6b5ae")
const TEAL := Color("79c8b7")
const GOLD := Color("d4e36d")
const RED := Color("ee806d")

var _root: Control
var _health_bar: ProgressBar
var _health_text: Label
var _xp_bar: ProgressBar
var _level_text: Label
var _clock_text: Label
var _kills_text: Label
var _phase_text: Label
var _weapons_text: Label
var _boss_panel: PanelContainer
var _boss_title: Label
var _boss_bar: ProgressBar
var _overlay: Control
var _overlay_body: VBoxContainer
var _overlay_mode: StringName = &""
var _level_up_choice_count: int = 0
var _stat_choice_ids: Array[StringName] = []
var _styles: Dictionary = {}
var _room_event_panel: PanelContainer
var _room_event_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()


func _input(event: InputEvent) -> void:
	var is_pause_key := false
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		is_pause_key = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		is_pause_key = true

	if is_pause_key:
		if _overlay_mode == &"pause" or _overlay_mode == &"in_game_settings":
			if _overlay_mode == &"in_game_settings":
				show_pause_menu()
			else:
				resume_requested.emit()
			BakkalAudio.play_sfx(&"ui_confirm")
		elif _overlay_mode.is_empty():
			show_pause_menu()
			pause_requested.emit()
			BakkalAudio.play_sfx(&"ui_confirm")
		get_viewport().set_input_as_handled()
		return

	if _overlay_mode in [&"level_up", &"stat_choice"] and event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		var index := key - KEY_1
		var choice_count := _level_up_choice_count if _overlay_mode == &"level_up" else _stat_choice_ids.size()
		if key >= KEY_1 and key <= KEY_3 and index < choice_count:
			if _overlay_mode == &"level_up":
				upgrade_selected.emit(index)
			else:
				stat_choice_selected.emit(_stat_choice_ids[index])
			BakkalAudio.play_sfx(&"ui_confirm")
			get_viewport().set_input_as_handled()


func set_run_clock(elapsed_seconds: float, duration_seconds: float) -> void:
	if not is_instance_valid(_clock_text):
		return
	var current := maxi(0, int(elapsed_seconds))
	var duration := maxi(0, int(duration_seconds))
	_clock_text.text = "%02d:%02d  /  %02d:%02d" % [current / 60, current % 60, duration / 60, duration % 60]


func set_round_clock(round_number: int, elapsed_seconds: float, duration_seconds: float) -> void:
	if not is_instance_valid(_clock_text):
		return
	var current := maxi(0, int(elapsed_seconds))
	var duration := maxi(0, int(duration_seconds))
	_clock_text.text = "WAVE %02d\n%02d:%02d / %02d:%02d" % [
		maxi(0, round_number), current / 60, current % 60, duration / 60, duration % 60,
	]


func update_health(current: int, maximum: int) -> void:
	if not is_instance_valid(_health_bar) or not is_instance_valid(_health_text):
		return
	_health_bar.max_value = maxi(1, maximum)
	_health_bar.value = clampi(current, 0, maxi(1, maximum))
	_health_text.text = "Health     %d / %d" % [current, maximum]


func update_progress(xp: int, needed: int, level: int) -> void:
	if not is_instance_valid(_xp_bar) or not is_instance_valid(_level_text):
		return
	_xp_bar.max_value = maxi(1, needed)
	_xp_bar.value = clampi(xp, 0, maxi(1, needed))
	_level_text.text = "Level %02d   /   Stock XP %d / %d" % [level, xp, needed]


func set_kill_count(kills: int) -> void:
	if is_instance_valid(_kills_text):
		_kills_text.text = "Cleared   %03d" % maxi(0, kills)


func set_phase_name(phase_name: String) -> void:
	if is_instance_valid(_phase_text):
		_phase_text.text = phase_name


func set_weapons(weapon_names: PackedStringArray) -> void:
	if is_instance_valid(_weapons_text):
		_weapons_text.text = "Equipped   /   " + ("   /   ".join(weapon_names) if not weapon_names.is_empty() else "Can Launcher")


func set_boss_health(name: String, current: int, maximum: int) -> void:
	if not is_instance_valid(_boss_panel) or not is_instance_valid(_boss_title) or not is_instance_valid(_boss_bar):
		return
	_boss_panel.visible = true
	_boss_title.text = name
	_boss_bar.max_value = maxi(1, maximum)
	_boss_bar.value = clampi(current, 0, maxi(1, maximum))


func show_room_event_message(heading: String, message: String) -> void:
	if not is_instance_valid(_root):
		return
	if _room_event_tween != null and _room_event_tween.is_running():
		_room_event_tween.kill()
	if is_instance_valid(_room_event_panel):
		_room_event_panel.queue_free()
	_room_event_panel = PanelContainer.new()
	_room_event_panel.anchor_left = 0.5
	_room_event_panel.anchor_right = 0.5
	_room_event_panel.offset_left = -210.0
	_room_event_panel.offset_right = 210.0
	_room_event_panel.offset_top = 92.0
	_room_event_panel.offset_bottom = 156.0
	_room_event_panel.add_theme_stylebox_override("panel", _style(PANEL, GOLD, 4, 1))
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 3)
	_room_event_panel.add_child(_margin_content(copy, 9))
	var title := _label(heading, 12, GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(title)
	var body := _label(message, 13, TEXT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(body)
	_root.add_child(_room_event_panel)
	var panel := _room_event_panel
	_room_event_tween = create_tween()
	_room_event_tween.tween_interval(3.0)
	_room_event_tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	_room_event_tween.tween_callback(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free()
		if _room_event_panel == panel:
			_room_event_panel = null
	)


func hide_boss_health() -> void:
	if is_instance_valid(_boss_panel):
		_boss_panel.visible = false


func show_level_up(upgrades: Array[UpgradeDefinition]) -> void:
	_open_overlay(&"level_up", "Choose a shift bonus", "One item comes off the shelf. The clock is paused.")
	_level_up_choice_count = upgrades.size()
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_body.add_child(cards)
	for index in range(upgrades.size()):
		var definition := upgrades[index]
		var card := Button.new()
		card.custom_minimum_size = Vector2(178, 176)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.focus_mode = Control.FOCUS_ALL
		card.add_theme_font_size_override("font_size", 18)
		card.add_theme_color_override("font_color", TEXT)
		card.add_theme_color_override("font_hover_color", Color.WHITE)
		card.add_theme_stylebox_override("normal", _style(PANEL, PANEL_EDGE, 4, 1))
		card.add_theme_stylebox_override("hover", _style(Color("294046"), GOLD, 4, 2))
		card.add_theme_stylebox_override("pressed", _style(Color("354b4d"), TEAL, 4, 2))
		card.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, TEXT, 4, 2))
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 12)
		var content_margins := MarginContainer.new()
		content_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_margins.add_theme_constant_override("margin_left", 12)
		content_margins.add_theme_constant_override("margin_right", 12)
		content_margins.add_theme_constant_override("margin_top", 14)
		content_margins.add_theme_constant_override("margin_bottom", 14)
		var number := _label("SHELF %02d  /  KEY %d" % [index + 1, index + 1], 11, GOLD)
		var title := _label(definition.display_name, 19, TEXT)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var description := _label(definition.description, 13, MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(number)
		content.add_child(title)
		content.add_child(description)
		content_margins.add_child(content)
		card.add_child(content_margins)
		card.pressed.connect(func() -> void: BakkalAudio.play_sfx(&"ui_confirm"); upgrade_selected.emit(index))
		cards.add_child(card)
		if index == 0:
			card.grab_focus.call_deferred()


func show_stat_choices(choices: Array[Dictionary]) -> void:
	_open_overlay(&"stat_choice", "Adjust your shift", "Choose one lasting stat. The clock is paused.")
	_stat_choice_ids.clear()
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_body.add_child(cards)
	var choice_count: int = mini(choices.size(), 3)
	for index: int in range(choice_count):
		var choice: Dictionary = choices[index]
		var choice_id := StringName(String(choice.get("id", "")))
		_stat_choice_ids.append(choice_id)
		var card := Button.new()
		card.custom_minimum_size = Vector2(210, 240)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.focus_mode = Control.FOCUS_ALL
		card.add_theme_font_size_override("font_size", 18)
		card.add_theme_color_override("font_color", TEXT)
		card.add_theme_color_override("font_hover_color", Color.WHITE)
		card.add_theme_stylebox_override("normal", _style(PANEL, PANEL_EDGE, 5, 1))
		card.add_theme_stylebox_override("hover", _style(Color("294046"), GOLD, 5, 2))
		card.add_theme_stylebox_override("pressed", _style(Color("354b4d"), TEAL, 5, 2))
		card.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, TEXT, 5, 2))
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 8)
		var content_margins := MarginContainer.new()
		content_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_margins.add_theme_constant_override("margin_left", 12)
		content_margins.add_theme_constant_override("margin_right", 12)
		content_margins.add_theme_constant_override("margin_top", 12)
		content_margins.add_theme_constant_override("margin_bottom", 12)

		var number := _label("SHELF %02d  /  KEY %d" % [index + 1, index + 1], 12, GOLD)
		content.add_child(number)

		var stat_texture: Texture2D
		match String(choice_id):
			"speed":
				stat_texture = load("res://assets/generated/shop_icons/comfortable_shoes.png") as Texture2D
			"health":
				stat_texture = load("res://assets/generated/pickups/pickup_health_bag.png") as Texture2D
			"lifesteal":
				stat_texture = load("res://assets/generated/pickups/pickup_energy_can.png") as Texture2D
			"dodge":
				stat_texture = load("res://assets/generated/shop_icons/longer_shift.png") as Texture2D
			"protection":
				stat_texture = load("res://assets/generated/shop_icons/fresh_apron.png") as Texture2D
			_:
				stat_texture = load("res://assets/generated/pickups/pickup_stock_bundle.png") as Texture2D

		if stat_texture != null:
			var icon_box := PanelContainer.new()
			icon_box.custom_minimum_size = Vector2(0, 72)
			icon_box.add_theme_stylebox_override("panel", _style(INK, Color("3f5a5d"), 4, 1))
			var icon_rect := TextureRect.new()
			icon_rect.texture = stat_texture
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(56, 56)
			icon_box.add_child(_center_control(icon_rect))
			content.add_child(icon_box)

		var title := _label(String(choice.get("name", "Stat adjustment")), 18, TEXT)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var description := _label(String(choice.get("description", "")), 13, MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(title)
		content.add_child(description)
		content_margins.add_child(content)
		card.add_child(content_margins)
		card.pressed.connect(func() -> void: BakkalAudio.play_sfx(&"ui_confirm"); stat_choice_selected.emit(choice_id))
		cards.add_child(card)
		if index == 0:
			card.grab_focus.call_deferred()


func show_pause_menu() -> void:
	_open_overlay(&"pause", I18n.t("PAUSE_TITLE", "VARDİYA DURDURULDU"), I18n.t("PAUSE_SUBTITLE", "Reyonlar biraz bekleyebilir."))
	_add_menu_button(I18n.t("PAUSE_RESUME", "Reyonlara Dön"), func() -> void: resume_requested.emit(), true)
	_add_menu_button(I18n.t("PAUSE_SAVE_QUIT", "Kaydet ve Çık"), func() -> void: save_and_quit_requested.emit())
	_add_menu_button(I18n.t("PAUSE_RESTART", "Yeniden Başlat"), func() -> void: restart_requested.emit())
	_add_menu_button(I18n.t("PAUSE_SETTINGS", "Ayarlar & Dil"), func() -> void: _show_in_game_settings())
	_add_menu_button(I18n.t("PAUSE_TITLE_MENU", "Ana Menü"), func() -> void: title_requested.emit())
	_add_menu_button(I18n.t("PAUSE_QUIT_DESKTOP", "Masaüstüne Çık"), func() -> void: get_tree().quit())


func _show_in_game_settings() -> void:
	_open_overlay(&"in_game_settings", I18n.t("SETTINGS_TITLE", "AYARLAR — SES, EKRAN & DİL"), "")

	# Language toggle row
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 12)
	_overlay_body.add_child(lang_row)

	var lang_title := _label(I18n.t("SETTINGS_LANGUAGE", "DİL / LANGUAGE"), 13, GOLD)
	lang_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(lang_title)

	var tr_btn := Button.new()
	tr_btn.text = "TÜRKÇE"
	tr_btn.custom_minimum_size = Vector2(100, 36)
	tr_btn.disabled = (I18n.current_locale == "tr")
	tr_btn.pressed.connect(func() -> void:
		I18n.set_language("tr")
		BakkalAudio.play_sfx(&"ui_confirm")
		_show_in_game_settings()
	)
	lang_row.add_child(tr_btn)

	var en_btn := Button.new()
	en_btn.text = "ENGLISH"
	en_btn.custom_minimum_size = Vector2(100, 36)
	en_btn.disabled = (I18n.current_locale == "en")
	en_btn.pressed.connect(func() -> void:
		I18n.set_language("en")
		BakkalAudio.play_sfx(&"ui_confirm")
		_show_in_game_settings()
	)
	lang_row.add_child(en_btn)

	var div1 := HSeparator.new()
	_overlay_body.add_child(div1)

	# Resolution selection row
	var res_label := _label(I18n.t("SETTINGS_RESOLUTION", "ÇÖZÜNÜRLÜK"), 13, GOLD)
	_overlay_body.add_child(res_label)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 8)
	_overlay_body.add_child(res_row)

	var resolutions := ["1920x1080", "1600x900", "1366x768", "1280x720"]
	for r_idx: int in range(resolutions.size()):
		var r_btn := Button.new()
		r_btn.text = resolutions[r_idx]
		r_btn.custom_minimum_size = Vector2(110, 34)
		r_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r_btn.disabled = (DisplayManager.current_resolution_index == r_idx)
		r_btn.pressed.connect(func() -> void:
			DisplayManager.set_resolution_index(r_idx)
			BakkalAudio.play_sfx(&"ui_confirm")
			_show_in_game_settings()
		)
		res_row.add_child(r_btn)

	# Window Mode row
	var mode_label := _label(I18n.t("SETTINGS_WINDOW_MODE", "EKRAN MODU"), 13, GOLD)
	_overlay_body.add_child(mode_label)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	_overlay_body.add_child(mode_row)

	var mode_names := [
		I18n.t("WINDOW_FULLSCREEN", "Tam Ekran"),
		I18n.t("WINDOW_BORDERLESS", "Kenarlıksız"),
		I18n.t("WINDOW_WINDOWED", "Pencereli")
	]
	for m_idx: int in range(mode_names.size()):
		var m_btn := Button.new()
		m_btn.text = mode_names[m_idx]
		m_btn.custom_minimum_size = Vector2(140, 34)
		m_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_btn.disabled = (DisplayManager.current_window_mode == m_idx)
		m_btn.pressed.connect(func() -> void:
			DisplayManager.set_window_mode(m_idx)
			BakkalAudio.play_sfx(&"ui_confirm")
			_show_in_game_settings()
		)
		mode_row.add_child(m_btn)

	var div2 := HSeparator.new()
	_overlay_body.add_child(div2)

	# Music slider
	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 10)
	_overlay_body.add_child(music_row)
	var music_label := _label(I18n.t("SETTINGS_MUSIC", "Müzik Sesi"), 13, TEXT)
	music_label.custom_minimum_size = Vector2(180, 0)
	music_row.add_child(music_label)
	var music_slider := HSlider.new()
	music_slider.min_value = -40.0
	music_slider.max_value = 0.0
	music_slider.step = 1.0
	music_slider.value = BakkalAudio.music_volume_db
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.value_changed.connect(func(v: float) -> void:
		BakkalAudio.set_music_volume(v)
		BakkalAudio.save_settings()
	)
	music_row.add_child(music_slider)

	# SFX slider
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 10)
	_overlay_body.add_child(sfx_row)
	var sfx_label := _label(I18n.t("SETTINGS_SFX", "Efekt Sesi"), 13, TEXT)
	sfx_label.custom_minimum_size = Vector2(180, 0)
	sfx_row.add_child(sfx_label)
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = -40.0
	sfx_slider.max_value = 0.0
	sfx_slider.step = 1.0
	sfx_slider.value = BakkalAudio.sfx_volume_db
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.value_changed.connect(func(v: float) -> void:
		BakkalAudio.set_sfx_volume(v)
		BakkalAudio.save_settings()
	)
	sfx_row.add_child(sfx_slider)

	_add_menu_button(I18n.t("MANUAL_CLOSE", "Geri Dön"), func() -> void: show_pause_menu(), true)


func show_results(report: Dictionary, victory: bool) -> void:
	var endless := String(report.get("mode", "")) == "ENDLESS NIGHT"
	var headline := "Shift survived" if victory else ("Endless night over" if endless else "Shift cut short")
	var subline := "The bakkal made it to morning." if victory else ("You held the store through wave %02d." % int(report.get("round", 1)) if endless else "The night shift got the better of you.")
	_open_overlay(&"results", headline, subline)
	var details := _label(
		"MODE  %s\nTIME  %s\nKNOCKED OUT  %d\nLEVEL  %d\nWEAPONS  %s\nRETURN CART  %s\nSCORE  %d\nBEST  %d%s" % [
			String(report.get("mode", "CAMPAIGN")),
			_format_clock(float(report.get("time", 0.0))),
			int(report.get("kills", 0)),
			int(report.get("level", 1)),
			String(report.get("weapons", "Can Launcher")),
			String(report.get("boss", "NOT CLEARED")),
			int(report.get("score", 0)),
			int(report.get("best_score", 0)),
			("\nBEST WAVE  %02d" % int(report.get("best_wave", 0))) if endless else "",
		],
		16,
		TEXT
	)
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_body.add_child(details)
	_add_menu_button("Run it back", func() -> void: restart_requested.emit(), true)
	_add_menu_button("Main menu", func() -> void: title_requested.emit())


func hide_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_overlay_body = null
	_overlay_mode = &""
	_level_up_choice_count = 0
	_stat_choice_ids.clear()


func _build_hud() -> void:
	_root = Control.new()
	_root.name = "HudRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var vitals := _panel(Vector2(24, 20), Vector2(360, 115))
	_root.add_child(vitals)
	var vitals_stack := VBoxContainer.new()
	vitals_stack.add_theme_constant_override("separation", 4)
	vitals.add_child(_margin_content(vitals_stack, 10))
	_health_text = _label("Health  100 / 100", 15, TEXT)
	vitals_stack.add_child(_health_text)
	_health_bar = _bar(RED)
	_health_bar.custom_minimum_size = Vector2(0, 16)
	vitals_stack.add_child(_health_bar)
	_level_text = _label("Level 01   /   Stock XP 0 / 5", 14, MUTED)
	vitals_stack.add_child(_level_text)
	_xp_bar = _bar(TEAL)
	_xp_bar.custom_minimum_size = Vector2(0, 12)
	vitals_stack.add_child(_xp_bar)

	var wave_panel := _panel(Vector2(-160, 20), Vector2(320, 92))
	wave_panel.anchor_left = 0.5
	wave_panel.anchor_right = 0.5
	_root.add_child(wave_panel)
	_clock_text = _label("WAVE 01\n00:00 / 00:50", 20, TEXT, true)
	_clock_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_panel.add_child(_clock_text)

	var report_panel := _panel(Vector2(-360, 20), Vector2(336, 92))
	report_panel.anchor_left = 1.0
	report_panel.anchor_right = 1.0
	_root.add_child(report_panel)
	var report_stack := VBoxContainer.new()
	report_stack.add_theme_constant_override("separation", 4)
	report_panel.add_child(_margin_content(report_stack, 10))
	_kills_text = _label("Cleared  000", 16, GOLD)
	_kills_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	report_stack.add_child(_kills_text)
	_phase_text = _label("Opening shift", 14, MUTED)
	_phase_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_phase_text.clip_text = true
	report_stack.add_child(_phase_text)

	_boss_panel = _panel(Vector2(-320, 125), Vector2(640, 72))
	_boss_panel.anchor_left = 0.5
	_boss_panel.anchor_right = 0.5
	_boss_panel.visible = false
	_root.add_child(_boss_panel)
	var boss_stack := VBoxContainer.new()
	boss_stack.add_theme_constant_override("separation", 3)
	_boss_panel.add_child(_margin_content(boss_stack, 8))
	_boss_title = _label("The Return Cart", 16, RED, true)
	_boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_stack.add_child(_boss_title)
	_boss_bar = _bar(RED)
	_boss_bar.custom_minimum_size = Vector2(0, 18)
	boss_stack.add_child(_boss_bar)

	var loadout_panel := _panel(Vector2(24, -64), Vector2(580, 46))
	loadout_panel.anchor_top = 1.0
	loadout_panel.anchor_bottom = 1.0
	_root.add_child(loadout_panel)
	_weapons_text = _label("Equipped  /  Can Launcher", 15, TEXT)
	_weapons_text.clip_text = true
	loadout_panel.add_child(_weapons_text)


func _open_overlay(mode: StringName, title: String, subtitle: String) -> void:
	hide_overlay()
	_overlay_mode = mode
	_overlay = Control.new()
	_overlay.name = "ModalOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.04, 0.075, 0.09, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760 if mode in [&"level_up", &"stat_choice", &"in_game_settings"] else (660 if mode == &"results" else 500), 0)
	panel.add_theme_stylebox_override("panel", _style(PANEL, GOLD, 6, 2))
	center.add_child(panel)
	_overlay_body = VBoxContainer.new()
	_overlay_body.add_theme_constant_override("separation", 16)
	panel.add_child(_margin_content(_overlay_body, 24))
	var receipt := _label("SUPERMARKET: THE NIGHT    /    SHIFT RECORD", 13, MUTED, true)
	receipt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_body.add_child(receipt)
	var heading := _label(title, 28, TEXT, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_body.add_child(heading)
	if not subtitle.is_empty():
		var description := _label(subtitle, 15, MUTED)
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_overlay_body.add_child(description)
	var rule := HSeparator.new()
	var rule_style := StyleBoxLine.new()
	rule_style.color = PANEL_EDGE
	rule_style.thickness = 1
	rule.add_theme_stylebox_override("separator", rule_style)
	_overlay_body.add_child(rule)
	_root.add_child(_overlay)


func _add_menu_button(text: String, callback: Callable, primary: bool = false) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", INK if primary else TEXT)
	button.add_theme_color_override("font_hover_color", INK if primary else GOLD)
	button.add_theme_stylebox_override("normal", _style(GOLD if primary else Color("22363b"), GOLD if primary else PANEL_EDGE, 4, 1))
	button.add_theme_stylebox_override("hover", _style(GOLD.lightened(0.1) if primary else Color("294046"), GOLD, 4, 2))
	button.add_theme_stylebox_override("pressed", _style(TEAL if primary else Color("17282c"), TEAL, 4, 2))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, TEXT, 4, 2))
	button.pressed.connect(func() -> void: BakkalAudio.play_sfx(&"ui_confirm"); callback.call())
	_overlay_body.add_child(button)
	if primary:
		button.grab_focus.call_deferred()


func _panel(position: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position
	panel.size = size
	panel.add_theme_stylebox_override("panel", _style(PANEL, PANEL_EDGE, 4, 1))
	return panel


func _bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 9)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _style(INK, PANEL_EDGE, 2, 1))
	bar.add_theme_stylebox_override("fill", _style(fill_color, fill_color, 2, 0))
	return bar


func _label(text: String, size: int, color: Color, pixel_accent: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	if pixel_accent and display_font != null:
		label.add_theme_font_override("font", display_font)
	return label


func _margin_content(child: Control, margin: int) -> MarginContainer:
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", margin)
	margins.add_theme_constant_override("margin_top", margin)
	margins.add_theme_constant_override("margin_right", margin)
	margins.add_theme_constant_override("margin_bottom", margin)
	margins.add_child(child)
	return margins


func _style(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var key := "%s|%s|%d|%d" % [fill.to_html(true), border.to_html(true), radius, border_width]
	if _styles.has(key):
		return _styles[key] as StyleBoxFlat
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_top = 8
	box.content_margin_right = 12
	box.content_margin_bottom = 8
	_styles[key] = box
	return box


func _format_clock(seconds: float) -> String:
	var whole := maxi(0, int(seconds))
	return "%02d:%02d" % [whole / 60, whole % 60]


func _center_control(control: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(control)
	return center
