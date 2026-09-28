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

const INK := Color("111a1c")
const PANEL := Color("efebd8", 0.97)
const PANEL_EDGE := Color("a59c80")
const TEXT := Color("18231e")
const MUTED := Color("56645a")
const TEAL := Color("4d7658")
const GOLD := Color("a98936")
const RED := Color("b75d54")
const RECEIPT_LIGHT := Color("f8f5e9")

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
var _last_player_summary: Dictionary = {}
var _styles: Dictionary = {}
var _room_event_panel: PanelContainer
var _room_event_tween: Tween
var _touch_pause_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()


func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_platform_back()


func _handle_platform_back() -> void:
	var scene := get_tree().current_scene
	var shop := scene.find_child("ShiftShop", true, false) as ShiftShop if is_instance_valid(scene) else null
	if is_instance_valid(shop) and shop.visible:
		return
	match _overlay_mode:
		&"pause":
			resume_requested.emit()
		&"in_game_settings":
			show_pause_menu()
		&"results":
			title_requested.emit()
		&"level_up", &"stat_choice":
			return
		_:
			_request_pause()


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
			var scene := get_tree().current_scene
			var shop := scene.find_child("ShiftShop", true, false) as ShiftShop if is_instance_valid(scene) else null
			if is_instance_valid(shop) and shop.visible:
				return
			_request_pause()
		get_viewport().set_input_as_handled()
		return

	if _overlay_mode in [&"level_up", &"stat_choice"] and event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		var index := key - KEY_1
		var choice_count := _level_up_choice_count if _overlay_mode == &"level_up" else _stat_choice_ids.size()
		if key >= KEY_1 and key <= KEY_4 and index < choice_count:
			if _overlay_mode == &"level_up":
				upgrade_selected.emit(index)
			else:
				stat_choice_selected.emit(_stat_choice_ids[index])
			BakkalAudio.play_sfx(&"ui_confirm")
			get_viewport().set_input_as_handled()


func set_run_clock(elapsed_seconds: float, duration_seconds: float) -> void:
	if not is_instance_valid(_clock_text):
		return
	var clock := _format_clock(maxf(0.0, duration_seconds - elapsed_seconds))
	_clock_text.text = clock if _is_mobile_platform() else "TIME   " + clock


func set_round_clock(round_number: int, elapsed_seconds: float, duration_seconds: float) -> void:
	if not is_instance_valid(_clock_text):
		return
	var clock := _format_clock(maxf(0.0, duration_seconds - elapsed_seconds))
	_clock_text.text = clock if _is_mobile_platform() else "TIME   " + clock


func update_health(current: int, maximum: int) -> void:
	if not is_instance_valid(_health_bar) or not is_instance_valid(_health_text):
		return
	_health_bar.max_value = maxi(1, maximum)
	_health_bar.value = clampi(current, 0, maxi(1, maximum))
	var compact_desktop := not _is_mobile_platform() and get_viewport().get_visible_rect().size.x < 900.0
	_health_text.text = ("HP   %d / %d" if _is_mobile_platform() or compact_desktop else "Health     %d / %d") % [current, maximum]


func update_progress(xp: int, needed: int, level: int) -> void:
	if not is_instance_valid(_xp_bar) or not is_instance_valid(_level_text):
		return
	_xp_bar.max_value = maxi(1, needed)
	_xp_bar.value = clampi(xp, 0, maxi(1, needed))
	var compact_desktop := not _is_mobile_platform() and get_viewport().get_visible_rect().size.x < 900.0
	_level_text.text = ("LV %02d · XP %d/%d" if _is_mobile_platform() or compact_desktop else "Level %02d   /   Stock XP %d / %d") % [level, xp, needed]


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
	_boss_bar.modulate = Color.WHITE


func set_boss_stagger(name: String, current: int, maximum: int, stunned: bool) -> void:
	if not is_instance_valid(_boss_panel) or not is_instance_valid(_boss_title) or not is_instance_valid(_boss_bar):
		return
	_boss_panel.visible = true
	_boss_title.text = name + ("  ·  STAGGERED" if stunned else "  ·  POISE")
	_boss_bar.max_value = maxi(1, maximum)
	_boss_bar.value = maxi(1, maximum) if stunned else clampi(current, 0, maxi(1, maximum))
	_boss_bar.modulate = Color(1.0, 0.68, 0.32, 1.0) if stunned else Color(1.0, 0.9, 0.62, 1.0)


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
	_room_event_panel.offset_left = -260.0
	_room_event_panel.offset_right = 260.0
	_room_event_panel.offset_top = 92.0
	_room_event_panel.offset_bottom = 184.0
	_room_event_panel.add_theme_stylebox_override("panel", _style(PANEL, PANEL_EDGE, 0, 1))
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 3)
	_room_event_panel.add_child(_margin_content(copy, 9))
	var title := _label(heading, 18, GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(title)
	var body := _label(message, 17, TEXT)
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
	var mobile_layout := _is_mobile_platform()
	var portmaster := OS.has_feature("portmaster")
	var viewport_size := get_viewport().get_visible_rect().size
	var choice_layout: Control = HBoxContainer.new()
	if portmaster:
		choice_layout = VBoxContainer.new()
	choice_layout.add_theme_constant_override("separation", _mobile_spacing(12) if mobile_layout else 16)
	choice_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_layout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_overlay_body.add_child(choice_layout)
	var cards: Control = GridContainer.new() if mobile_layout else HBoxContainer.new()
	if mobile_layout:
		(cards as GridContainer).columns = 2 if portmaster else 4
	var choice_buttons: Array[Button] = []
	cards.add_theme_constant_override("h_separation", _mobile_spacing(12) if mobile_layout else 12)
	cards.add_theme_constant_override("v_separation", _mobile_spacing(10) if mobile_layout else 12)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if mobile_layout:
		var safe := _safe_insets(viewport_size)
		var inner_width := viewport_size.x - safe.x - safe.z - _mobile_spacing(32)
		cards.custom_minimum_size.x = inner_width - (0.0 if portmaster else 260.0) - _mobile_spacing(12)
	choice_layout.add_child(cards)
	for index in range(upgrades.size()):
		var definition := upgrades[index]
		var card := Button.new()
		var columns := 2 if portmaster else 4
		var choice_height := viewport_size.y * (0.35 if portmaster else 0.58) if mobile_layout else 300.0
		card.custom_minimum_size = Vector2((cards.custom_minimum_size.x - _mobile_spacing(12 * (columns + 1))) / float(columns) if mobile_layout else 0, choice_height)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.focus_mode = Control.FOCUS_ALL
		card.add_theme_font_size_override("font_size", _responsive_font_size(18))
		card.add_theme_color_override("font_color", TEXT)
		card.add_theme_color_override("font_hover_color", TEXT)
		card.add_theme_stylebox_override("normal", _style(RECEIPT_LIGHT, PANEL_EDGE, 0, 1))
		card.add_theme_stylebox_override("hover", _style(Color("fffdf4"), GOLD, 0, 2))
		card.add_theme_stylebox_override("pressed", _style(Color("d8e5d2"), TEAL, 0, 2))
		card.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, TEAL, 0, 2))
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", _mobile_spacing(6) if mobile_layout else 12)
		var content_margins := MarginContainer.new()
		content_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_margins.add_theme_constant_override("margin_left", _mobile_spacing(8) if mobile_layout else 12)
		content_margins.add_theme_constant_override("margin_right", _mobile_spacing(8) if mobile_layout else 12)
		content_margins.add_theme_constant_override("margin_top", _mobile_spacing(8) if mobile_layout else 14)
		content_margins.add_theme_constant_override("margin_bottom", _mobile_spacing(8) if mobile_layout else 14)
		var number := _label("SHELF %02d  /  KEY %d" % [index + 1, index + 1], 14, GOLD)
		var icon := TextureRect.new()
		icon.texture = definition.icon
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if icon.texture != null:
			var icon_center := _center_control(icon)
			icon_center.custom_minimum_size.y = _mobile_spacing(42) if mobile_layout else 64
			content.add_child(icon_center)
		var title := _label(definition.display_name, 23, TEXT)
		if mobile_layout:
			title.add_theme_font_size_override("font_size", roundi(_mobile_overlay_font(get_viewport().get_visible_rect().size, 21.0)))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var description := _label(definition.description, 17, MUTED)
		if mobile_layout:
			description.add_theme_font_size_override("font_size", roundi(_mobile_overlay_font(get_viewport().get_visible_rect().size, 17.0)))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(number)
		content.add_child(title)
		content.add_child(description)
		var choose_hint := _label("CHOOSE   /   %d" % (index + 1), 15, TEAL)
		choose_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(choose_hint)
		content_margins.add_child(content)
		card.add_child(content_margins)
		card.pressed.connect(func() -> void: BakkalAudio.play_sfx(&"ui_confirm"); upgrade_selected.emit(index))
		cards.add_child(card)
		choice_buttons.append(card)
		if index == 0 and (portmaster or not mobile_layout):
			card.grab_focus.call_deferred()
	_link_horizontal_focus(choice_buttons)
	if not _last_player_summary.is_empty():
		var ledger := _build_stat_ledger(_last_player_summary)
		if mobile_layout:
			ledger.custom_minimum_size.y = viewport_size.y * 0.58
			ledger.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		choice_layout.add_child(ledger)
	if portmaster:
		var scroll := _overlay.find_child("OverlayContentScroll", true, false) as ScrollContainer
		if is_instance_valid(scroll):
			scroll.set_deferred("scroll_vertical", 0)


func show_stat_choices(choices: Array[Dictionary], player_summary: Dictionary = {}) -> void:
	_open_overlay(&"stat_choice", "Choose a shift adjustment", "Select one lasting bonus. Some upgrades include a trade-off.")
	_last_player_summary = player_summary.duplicate(true)
	_stat_choice_ids.clear()
	var portrait := _is_portrait()
	var mobile_layout := _is_mobile_platform()
	var portmaster := OS.has_feature("portmaster")
	var viewport_size := get_viewport().get_visible_rect().size
	var layout: Control = HBoxContainer.new()
	if portmaster:
		layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_overlay_body.add_child(layout)
	var cards: Control = GridContainer.new() if mobile_layout else HBoxContainer.new()
	if mobile_layout:
		(cards as GridContainer).columns = 2 if portmaster else 4
	var choice_buttons: Array[Button] = []
	cards.add_theme_constant_override("h_separation", _mobile_spacing(8) if mobile_layout else 10)
	cards.add_theme_constant_override("v_separation", _mobile_spacing(8) if mobile_layout else 10)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if mobile_layout:
		var safe := _safe_insets(viewport_size)
		var inner_width := viewport_size.x - safe.x - safe.z - _mobile_spacing(32)
		cards.custom_minimum_size.x = inner_width - (0.0 if portmaster else 260.0) - _mobile_spacing(16)
	layout.add_child(cards)
	var choice_count: int = mini(choices.size(), 4)
	for index: int in range(choice_count):
		var choice: Dictionary = choices[index]
		var choice_id := StringName(String(choice.get("id", "")))
		_stat_choice_ids.append(choice_id)
		var card := PanelContainer.new()
		var columns := 2 if portmaster else 4
		var choice_height := viewport_size.y * (0.35 if portmaster else 0.58) if mobile_layout else 320.0
		card.custom_minimum_size = Vector2((cards.custom_minimum_size.x - _mobile_spacing(8 * (columns + 1))) / float(columns) if mobile_layout else 0, choice_height)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.add_theme_stylebox_override("panel", _style(RECEIPT_LIGHT, PANEL_EDGE, 0, 1))
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", _mobile_spacing(6) if mobile_layout else 10)
		card.add_child(_margin_content(content, _mobile_spacing(8) if mobile_layout else 12))
		var rarity_tier := clampi(int(choice.get("rarity_tier", 1)), 1, 4)
		var tier_names := ["I", "II", "III", "IV"]
		var tier_colors := [MUTED, TEAL, Color("70a8d2"), GOLD]
		content.add_child(_label("PICK %02d  /  KEY %d   ·   TIER %s" % [index + 1, index + 1, tier_names[rarity_tier - 1]], 14, tier_colors[rarity_tier - 1]))
		var icon_texture := _stat_icon(choice)
		if icon_texture != null:
			var icon_panel := PanelContainer.new()
			icon_panel.custom_minimum_size = Vector2(0, _mobile_spacing(54) if mobile_layout else 72)
			icon_panel.add_theme_stylebox_override("panel", _style(Color("e5e0cd"), PANEL_EDGE, 0, 1))
			var icon_rect := TextureRect.new()
			icon_rect.texture = icon_texture
			icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(_mobile_spacing(48), _mobile_spacing(48)) if mobile_layout else Vector2(56, 56)
			icon_panel.add_child(_center_control(icon_rect))
			content.add_child(icon_panel)
		var title := _label(String(choice.get("name", "Stat adjustment")), 22, TEXT)
		if mobile_layout:
			title.add_theme_font_size_override("font_size", roundi(_mobile_overlay_font(get_viewport().get_visible_rect().size, 21.0)))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(title)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_theme_constant_override("separation", 6)
		if portmaster:
			content.add_child(details)
		else:
			var details_scroll := ScrollContainer.new()
			details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			details_scroll.follow_focus = true
			details_scroll.add_child(details)
			content.add_child(details_scroll)
		var effects: Array = choice.get("effects", [])
		for effect: Variant in effects:
			if effect is Dictionary:
				var delta_row := _label(_format_stat_delta(effect), 18, TEAL if float(effect.get("value", 0.0)) >= 0.0 else RED)
				if mobile_layout:
					delta_row.add_theme_font_size_override("font_size", roundi(_mobile_overlay_font(get_viewport().get_visible_rect().size, 19.0)))
				delta_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				details.add_child(delta_row)
		if effects.is_empty() and not portmaster:
			details.add_child(_label("No lasting stat change.", 16, MUTED))
		var reason := _label(String(choice.get("description", "")), 15, MUTED)
		if mobile_layout:
			reason.add_theme_font_size_override("font_size", roundi(_mobile_overlay_font(get_viewport().get_visible_rect().size, 17.0)))
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(reason)
		var choose_button := _add_card_button(content, "Choose", func() -> void:
			BakkalAudio.play_sfx(&"ui_confirm")
			stat_choice_selected.emit(choice_id)
		)
		cards.add_child(card)
		choice_buttons.append(choose_button)
		if index == 0 and (portmaster or not mobile_layout):
			choose_button.grab_focus.call_deferred()

	var ledger := _build_stat_ledger(player_summary)
	if mobile_layout:
		ledger.custom_minimum_size.y = viewport_size.y * (0.38 if portmaster else 0.58)
		ledger.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if portmaster:
			ledger.custom_minimum_size.x = 0.0
			ledger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(ledger)
	_link_horizontal_focus(choice_buttons)
	if portmaster:
		var scroll := _overlay.find_child("OverlayContentScroll", true, false) as ScrollContainer
		if is_instance_valid(scroll):
			scroll.set_deferred("scroll_vertical", 0)


func _link_horizontal_focus(buttons: Array[Button]) -> void:
	for index in range(buttons.size()):
		var previous := (index - 1 + buttons.size()) % buttons.size()
		var next := (index + 1) % buttons.size()
		buttons[index].focus_neighbor_left = buttons[previous].get_path()
		buttons[index].focus_neighbor_right = buttons[next].get_path()


func _stat_icon(choice: Dictionary) -> Texture2D:
	match String(choice.get("id", "")):
		"health":
			return load("res://assets/generated/pickups/pickup_health_bag.png") as Texture2D
		"speed":
			return load("res://assets/generated/shop_icons/comfortable_shoes.png") as Texture2D
		"lifesteal":
			return load("res://assets/generated/pickups/pickup_energy_can.png") as Texture2D
		"dodge":
			return load("res://assets/generated/shop_icons/longer_shift.png") as Texture2D
		"protection", "armor":
			return load("res://assets/generated/shop_icons/fresh_apron.png") as Texture2D
		"luck":
			return load("res://assets/generated/pickups/pickup_stock_bundle.png") as Texture2D
	var effects: Array = choice.get("effects", [])
	for effect: Variant in effects:
		if not effect is Dictionary or float(effect.get("value", 0.0)) <= 0.0:
			continue
		var weapon_id := String(effect.get("weapon_id", ""))
		if not weapon_id.is_empty():
			var weapon_path := "res://data/weapons/%s.tres" % weapon_id
			if ResourceLoader.exists(weapon_path):
				var weapon := load(weapon_path) as WeaponDefinition
				if weapon != null and weapon.sprite != null:
					return weapon.sprite
		match String(effect.get("stat", "")):
			"max_health":
				return load("res://assets/generated/pickups/pickup_health_bag.png") as Texture2D
			"damage":
				return load("res://assets/generated/shop_icons/heavier_cans.png") as Texture2D
			"move_speed":
				return load("res://assets/generated/shop_icons/comfortable_shoes.png") as Texture2D
			"lifesteal":
				return load("res://assets/generated/pickups/pickup_energy_can.png") as Texture2D
			"dodge":
				return load("res://assets/generated/shop_icons/longer_shift.png") as Texture2D
			"protection":
				return load("res://assets/generated/shop_icons/fresh_apron.png") as Texture2D
			"armor":
				return load("res://assets/generated/shop_icons/fresh_apron.png") as Texture2D
			"luck":
				return load("res://assets/generated/pickups/pickup_stock_bundle.png") as Texture2D
			"elemental_damage":
				return load("res://assets/generated/weapons/shelf_rinse_sprayer.png") as Texture2D
			"engineering":
				return load("res://assets/generated/content_pack/engineering_caddy.png") as Texture2D
			"harvesting":
				return load("res://assets/generated/pickups/pickup_stock_bundle.png") as Texture2D
			"xp_gain":
				return load("res://assets/generated/pickups/pickup_xp_token.png") as Texture2D
			"melee_damage":
				return load("res://assets/generated/weapons/mop_whirl.png") as Texture2D
			"ranged_damage":
				return load("res://assets/generated/weapons/projectile_tomato_can.png") as Texture2D
			"attack_speed":
				return load("res://assets/generated/shop_icons/comfortable_shoes.png") as Texture2D
			"crit_chance":
				return load("res://assets/generated/shop_icons/heavier_cans.png") as Texture2D
	return null


func _add_card_button(parent: Control, button_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size.y = _touch_target_size(get_viewport().get_visible_rect().size) if _is_mobile_platform() else 48
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", _responsive_font_size(17))
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_stylebox_override("normal", _style(GOLD.lightened(0.24), GOLD, 0, 1))
	button.add_theme_stylebox_override("hover", _style(GOLD.lightened(0.32), TEXT, 0, 1))
	button.add_theme_stylebox_override("pressed", _style(Color("d8e5d2"), TEAL, 0, 2))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, TEAL, 0, 2))
	button.pressed.connect(func() -> void: callback.call())
	parent.add_child(button)
	return button


func _format_stat_delta(effect: Dictionary) -> String:
	var stat_key := String(effect.get("stat", ""))
	var custom_label := String(effect.get("label", "")).strip_edges()
	var stat_name := custom_label if not custom_label.is_empty() else _stat_display_name(stat_key)
	var value := float(effect.get("value", 0.0))
	var unit := String(effect.get("unit", effect.get("format", ""))).to_lower()
	var is_percent := unit in ["percent", "%", "percentage"] or stat_key in ["damage", "move_speed", "lifesteal", "dodge", "protection", "xp_gain", "attack_speed", "crit_chance", "weapon_fire_rate"]
	var amount := "%+d%%" % roundi(value * 100.0) if is_percent else "%+d" % roundi(value)
	return "%s  %s" % [amount, stat_name]


func _stat_display_name(stat_key: String) -> String:
	match stat_key:
		"engineering":
			return "Engineering"
		"elemental_damage":
			return "Elemental Damage"
		"max_health":
			return "Max Health"
		"move_speed":
			return "Move Speed"
		"lifesteal":
			return "Life Steal"
		"weapon_damage":
			return "Weapon Damage"
		"weapon_fire_rate":
			return "Weapon Fire Rate"
		_:
			return stat_key.replace("_", " ").capitalize()


func _build_stat_ledger(stats: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var mobile := _is_mobile_platform()
	var viewport_size := get_viewport().get_visible_rect().size
	panel.custom_minimum_size.x = 260 if mobile else 280
	panel.add_theme_stylebox_override("panel", _style(RECEIPT_LIGHT, PANEL_EDGE, 0, 1))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(_margin_content(content, 14))
	var heading := _label("Current shift", 23, TEXT)
	var level_line := _label("Level  %s" % str(stats.get("level", "1")), 17, MUTED)
	if mobile:
		heading.add_theme_font_size_override("font_size", roundi(_mobile_overlay_font(viewport_size, 23.0)))
		level_line.add_theme_font_size_override("font_size", roundi(_mobile_overlay_font(viewport_size, 17.0)))
	content.add_child(heading)
	content.add_child(level_line)
	for key: String in ["health", "damage", "melee_damage", "ranged_damage", "attack_speed", "crit_chance", "elemental_damage", "engineering", "speed", "lifesteal", "dodge", "protection", "armor", "harvesting", "luck", "xp_gain"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var stat_label := "Elemental Damage" if key == "elemental_damage" else ("Engineering" if key == "engineering" else key.replace("_", " ").capitalize())
		var name_label := _label(stat_label, 17, MUTED)
		var value_label := _label(str(stats.get(key, "0")), 17, GOLD)
		if mobile:
			var row_font := roundi(_mobile_overlay_font(viewport_size, 17.0))
			name_label.add_theme_font_size_override("font_size", row_font)
			value_label.add_theme_font_size_override("font_size", row_font)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(name_label)
		row.add_child(value_label)
		content.add_child(row)
	var training_text := String(stats.get("weapon_training", ""))
	if not training_text.is_empty():
		var training_label := _label("Weapon Training  %s" % training_text, 13, GOLD)
		if mobile:
			training_label.add_theme_font_size_override("font_size", roundi(_mobile_overlay_font(viewport_size, 15.0)))
		training_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(training_label)
	return panel


func show_pause_menu() -> void:
	_open_overlay(&"pause", I18n.t("PAUSE_TITLE", "VARDİYA DURDURULDU"), I18n.t("PAUSE_SUBTITLE", "Reyonlar biraz bekleyebilir."))
	_add_menu_button(I18n.t("PAUSE_RESUME", "Reyonlara Dön"), func() -> void: resume_requested.emit(), true)
	_add_menu_button(I18n.t("PAUSE_SAVE_QUIT", "Kaydet ve Çık"), func() -> void: save_and_quit_requested.emit())
	_add_menu_button(I18n.t("PAUSE_RESTART", "Yeniden Başlat"), func() -> void: restart_requested.emit())
	_add_menu_button(I18n.t("PAUSE_SETTINGS", "Ayarlar & Dil"), func() -> void: _show_in_game_settings())
	_add_menu_button(I18n.t("PAUSE_TITLE_MENU", "Ana Menü"), func() -> void: title_requested.emit())
	if not _is_mobile_platform():
		_add_menu_button(I18n.t("PAUSE_QUIT_DESKTOP", "Masaüstüne Çık"), func() -> void: get_tree().quit())


func _show_in_game_settings() -> void:
	_open_overlay(&"in_game_settings", I18n.t("SETTINGS_TITLE", "AYARLAR — SES, EKRAN & DİL"), "")

	# Language toggle row
	var portrait := _is_portrait()
	var lang_row: Control = VBoxContainer.new() if portrait else HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 12)
	_overlay_body.add_child(lang_row)

	var lang_title := _label(I18n.t("SETTINGS_LANGUAGE", "DİL / LANGUAGE"), 13, GOLD)
	lang_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(lang_title)

	var tr_btn := Button.new()
	tr_btn.text = "TÜRKÇE"
	tr_btn.custom_minimum_size = Vector2(100, 36)
	_style_settings_button(tr_btn)
	tr_btn.disabled = (I18n.current_locale == "tr")
	tr_btn.pressed.connect(func() -> void:
		I18n.set_language("tr")
		BakkalAudio.play_sfx(&"ui_confirm")
		_show_in_game_settings()
	)
	var language_buttons: Control = HBoxContainer.new() if portrait else lang_row
	if portrait:
		lang_row.add_child(language_buttons)
	language_buttons.add_child(tr_btn)

	var en_btn := Button.new()
	en_btn.text = "ENGLISH"
	en_btn.custom_minimum_size = Vector2(100, 36)
	_style_settings_button(en_btn)
	en_btn.disabled = (I18n.current_locale == "en")
	en_btn.pressed.connect(func() -> void:
		I18n.set_language("en")
		BakkalAudio.play_sfx(&"ui_confirm")
		_show_in_game_settings()
	)
	language_buttons.add_child(en_btn)

	var div1 := HSeparator.new()
	_overlay_body.add_child(div1)

	if not OS.has_feature("portmaster"):
		# Resolution selection row
		var res_label := _label(I18n.t("SETTINGS_RESOLUTION", "ÇÖZÜNÜRLÜK"), 13, GOLD)
		_overlay_body.add_child(res_label)

		var res_row: Control = GridContainer.new() if portrait else HBoxContainer.new()
		if portrait:
			(res_row as GridContainer).columns = 2
		res_row.add_theme_constant_override("separation", 8)
		_overlay_body.add_child(res_row)

		var resolutions := ["1920x1080", "1600x900", "1366x768", "1280x720"]
		for r_idx: int in range(resolutions.size()):
			var r_btn := Button.new()
			r_btn.text = resolutions[r_idx]
			r_btn.custom_minimum_size = Vector2(110, 34)
			r_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_settings_button(r_btn)
			r_btn.disabled = (DisplayManager.current_resolution_index == r_idx)
			r_btn.pressed.connect(func() -> void:
				DisplayManager.set_resolution_index(r_idx)
				BakkalAudio.play_sfx(&"ui_confirm")
				_show_in_game_settings()
			)
			r_btn.custom_minimum_size.y = _touch_target_size(get_viewport().get_visible_rect().size) if _is_mobile_platform() else 34
			res_row.add_child(r_btn)

		# Window Mode row
		var mode_label := _label(I18n.t("SETTINGS_WINDOW_MODE", "EKRAN MODU"), 13, GOLD)
		_overlay_body.add_child(mode_label)

		var mode_row: Control = GridContainer.new() if portrait else HBoxContainer.new()
		if portrait:
			(mode_row as GridContainer).columns = 2
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
			_style_settings_button(m_btn)
			m_btn.disabled = (DisplayManager.current_window_mode == m_idx)
			m_btn.pressed.connect(func() -> void:
				DisplayManager.set_window_mode(m_idx)
				BakkalAudio.play_sfx(&"ui_confirm")
				_show_in_game_settings()
			)
			m_btn.custom_minimum_size.y = _touch_target_size(get_viewport().get_visible_rect().size) if _is_mobile_platform() else 34
			mode_row.add_child(m_btn)

	if not _is_native_mobile_platform():
		_add_touch_controls_setting(_overlay_body)

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
	var metrics := GridContainer.new()
	metrics.columns = 2
	metrics.add_theme_constant_override("h_separation", 28)
	metrics.add_theme_constant_override("v_separation", 8)
	metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_body.add_child(metrics)
	_add_result_metric(metrics, "SHIFT", String(report.get("mode", "CAMPAIGN")))
	_add_result_metric(metrics, "TIME ON CLOCK", _format_clock(float(report.get("time", 0.0))))
	_add_result_metric(metrics, "AISLES CLEARED", "%03d" % int(report.get("kills", 0)))
	_add_result_metric(metrics, "SHIFT LEVEL", "%02d" % int(report.get("level", 1)))
	_add_result_metric(metrics, "RETURN CART", String(report.get("boss", "NOT CLEARED")))
	_add_result_metric(metrics, "SHIFT SCORE", "%06d" % int(report.get("score", 0)))
	_add_result_metric(metrics, "PERSONAL BEST", "%06d" % int(report.get("best_score", 0)))
	if endless:
		_add_result_metric(metrics, "BEST WAVE", "WAVE %02d" % int(report.get("best_wave", 0)))
	_overlay_body.add_child(HSeparator.new())
	var tools_heading := _label("TOOLS ON THE RECEIPT", 15, GOLD, true)
	_overlay_body.add_child(tools_heading)
	var tools := _label(String(report.get("weapons", "Can Launcher")).replace(" / ", "   ·   "), 18, TEXT)
	tools.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_body.add_child(tools)
	if _is_mobile_platform():
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", _mobile_spacing(8))
		actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_overlay_body.add_child(actions)
		var retry_button := _result_action_button("Run it back", true, func() -> void: restart_requested.emit())
		retry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(retry_button)
		retry_button.grab_focus.call_deferred()
		var menu_button := _result_action_button("Main menu", false, func() -> void: title_requested.emit())
		menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(menu_button)
	else:
		_add_menu_button("Run it back", func() -> void: restart_requested.emit(), true)
		_add_menu_button("Main menu", func() -> void: title_requested.emit())
	if OS.has_feature("portmaster"):
		var scroll := _overlay.find_child("OverlayContentScroll", true, false) as ScrollContainer
		if is_instance_valid(scroll):
			scroll.set_deferred("scroll_vertical", 0)


func _result_action_button(text: String, primary: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = _touch_target_size(get_viewport().get_visible_rect().size)
	button.add_theme_font_size_override("font_size", _responsive_font_size(18))
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_stylebox_override("normal", _style(GOLD.lightened(0.24) if primary else RECEIPT_LIGHT, GOLD if primary else PANEL_EDGE, 0, 1))
	button.add_theme_stylebox_override("hover", _style(GOLD.lightened(0.32) if primary else Color("fffdf4"), GOLD, 0, 2))
	button.add_theme_stylebox_override("pressed", _style(Color("d8e5d2"), TEAL, 0, 2))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, TEAL, 0, 2))
	button.pressed.connect(func() -> void:
		BakkalAudio.play_sfx(&"ui_confirm")
		callback.call()
	)
	return button


func _add_result_metric(parent: GridContainer, label_text: String, value_text: String) -> void:
	var item := VBoxContainer.new()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_constant_override("separation", 2)
	var label := _label(label_text, 14, MUTED, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := _label(value_text, 19, TEXT)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _is_mobile_platform():
		var viewport_size := get_viewport().get_visible_rect().size
		label.add_theme_font_size_override("font_size", roundi(_mobile_overlay_font(viewport_size, 14.0)))
		value.add_theme_font_size_override("font_size", roundi(_mobile_overlay_font(viewport_size, 19.0)))
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_child(label)
	item.add_child(value)
	parent.add_child(item)


func hide_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_overlay_body = null
	_overlay_mode = &""
	_level_up_choice_count = 0
	_stat_choice_ids.clear()
	if is_instance_valid(_touch_pause_button):
		_touch_pause_button.visible = true


func _build_hud() -> void:
	_root = Control.new()
	_root.name = "HudRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var viewport_size := get_viewport().get_visible_rect().size
	var safe := _safe_insets(viewport_size)
	var portrait := viewport_size.x < viewport_size.y
	var mobile := _is_mobile_platform()
	var compact_desktop := not mobile and viewport_size.x < 900.0
	var usable_width := maxf(280.0, viewport_size.x - safe.x - safe.z - 40.0)
	var vitals_width := minf(440.0, usable_width * 0.48) if portrait else (minf(400.0, usable_width * 0.32) if mobile else (minf(440.0, usable_width * 0.46) if compact_desktop else 440.0))
	var vitals_height := 106.0 if mobile else (116.0 if compact_desktop else 142.0)
	var vitals := _panel(Vector2.ZERO, Vector2(vitals_width, vitals_height))
	if mobile:
		vitals.anchor_left = 1.0
		vitals.anchor_right = 1.0
		vitals.offset_left = -safe.z - 20.0 - vitals_width
		vitals.offset_right = -safe.z - 20.0
	else:
		vitals.offset_left = safe.x + 20.0
		vitals.offset_right = safe.x + 20.0 + vitals_width
	vitals.offset_top = safe.y + (12.0 if mobile else 20.0)
	vitals.offset_bottom = vitals.offset_top + vitals_height
	vitals.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_root.add_child(vitals)
	var vitals_stack := VBoxContainer.new()
	vitals_stack.add_theme_constant_override("separation", 2 if mobile or compact_desktop else 4)
	vitals.add_child(_margin_content(vitals_stack, 6 if mobile or compact_desktop else 10))
	_health_text = _label("HP  100 / 100" if mobile or compact_desktop else "Health  100 / 100", 18 if mobile else (16 if compact_desktop else 20), RECEIPT_LIGHT)
	_apply_world_text_contrast(_health_text)
	vitals_stack.add_child(_health_text)
	_health_bar = _bar(RED)
	_health_bar.custom_minimum_size = Vector2(0, 12 if mobile else (16 if compact_desktop else 20))
	vitals_stack.add_child(_health_bar)
	_level_text = _label("LV 01 · XP 0 / 5" if mobile or compact_desktop else "Level 01   /   Stock XP 0 / 5", 16 if mobile else (14 if compact_desktop else 18), RECEIPT_LIGHT)
	_apply_world_text_contrast(_level_text)
	vitals_stack.add_child(_level_text)
	_xp_bar = _bar(TEAL)
	_xp_bar.custom_minimum_size = Vector2(0, 9 if mobile else (10 if compact_desktop else 14))
	vitals_stack.add_child(_xp_bar)

	_clock_text = _label("00:50" if mobile else "TIME   00:50", 12 if mobile else 12, RECEIPT_LIGHT, true)
	_apply_world_text_contrast(_clock_text)
	_clock_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock_text.clip_text = true
	_clock_text.anchor_left = 1.0
	_clock_text.anchor_right = 1.0
	_clock_text.anchor_top = 1.0
	_clock_text.anchor_bottom = 1.0
	_clock_text.offset_left = -(120.0 if mobile else 236.0) - safe.z
	_clock_text.offset_right = -16.0 - safe.z
	_clock_text.offset_top = -(34.0 if mobile else 52.0) - safe.w
	_clock_text.offset_bottom = -12.0 - safe.w
	_root.add_child(_clock_text)

	var report_width := minf(380.0, usable_width * 0.40) if compact_desktop else 380.0
	var report_height := 90.0 if compact_desktop else 104.0
	var report_panel := _panel(Vector2(-report_width - 20.0 - safe.z, safe.y + 20.0), Vector2(report_width, report_height))
	if mobile:
		report_panel.anchor_left = 0.0
		report_panel.anchor_right = 0.0
		report_panel.position = Vector2(safe.x + 20.0, safe.y + 20.0)
		report_panel.custom_minimum_size = Vector2(minf(360.0, usable_width * 0.38), 78.0)
		report_panel.size = report_panel.custom_minimum_size
	elif portrait:
		report_panel.position = Vector2(safe.x + 20.0, safe.y + 174.0)
		report_panel.custom_minimum_size = Vector2(usable_width, 90.0)
		report_panel.size = report_panel.custom_minimum_size
	else:
		report_panel.anchor_left = 1.0
		report_panel.anchor_right = 1.0
	_root.add_child(report_panel)
	var report_stack := VBoxContainer.new()
	report_stack.add_theme_constant_override("separation", 4 if not compact_desktop else 2)
	report_panel.add_child(_margin_content(report_stack, 6 if compact_desktop else 10))
	_kills_text = _label("Cleared  000", 16 if compact_desktop else 20, GOLD)
	_kills_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if mobile:
		_kills_text.add_theme_font_size_override("font_size", roundi(_mobile_hud_font(viewport_size, 18.0)))
	report_stack.add_child(_kills_text)
	_phase_text = _label("Opening shift", 17, MUTED)
	_phase_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_phase_text.clip_text = true
	_phase_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if mobile:
		_phase_text.add_theme_font_size_override("font_size", roundi(_mobile_hud_font(viewport_size, 15.0)))
	elif compact_desktop:
		_phase_text.add_theme_font_size_override("font_size", 14)
	report_stack.add_child(_phase_text)

	var layout_scale := _mobile_layout_scale(viewport_size) if mobile else 1.0
	var boss_width := minf(760.0 * layout_scale, maxf(320.0 * layout_scale, viewport_size.x - safe.x - safe.z - 48.0 * layout_scale))
	var boss_height := 92.0 * layout_scale
	_boss_panel = _panel(Vector2(-boss_width / 2.0, (200.0 if portrait else 132.0) * layout_scale + safe.y), Vector2(boss_width, boss_height))
	_boss_panel.anchor_left = 0.5
	_boss_panel.anchor_right = 0.5
	_boss_panel.offset_left = (safe.x - safe.z) / 2.0 - boss_width / 2.0
	_boss_panel.offset_right = (safe.x - safe.z) / 2.0 + boss_width / 2.0
	_boss_panel.offset_bottom = _boss_panel.offset_top + boss_height
	_boss_panel.visible = false
	_root.add_child(_boss_panel)
	var boss_stack := VBoxContainer.new()
	boss_stack.add_theme_constant_override("separation", 3)
	_boss_panel.add_child(_margin_content(boss_stack, 8))
	_boss_title = _label("The Return Cart", 19, RED, true)
	_boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_stack.add_child(_boss_title)
	_boss_bar = _bar(RED)
	_boss_bar.custom_minimum_size = Vector2(0, 22)
	boss_stack.add_child(_boss_bar)

	_weapons_text = null
	if (mobile and not OS.has_feature("portmaster")) or DisplayServer.is_touchscreen_available() or (portrait and not OS.has_feature("portmaster")):
		_touch_pause_button = Button.new()
		_touch_pause_button.name = "TouchPause"
		_touch_pause_button.text = ""
		_touch_pause_button.tooltip_text = "Pause shift"
		_touch_pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
		_touch_pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
		_touch_pause_button.z_index = 100
		var target_size := _touch_target_size(viewport_size)
		_touch_pause_button.custom_minimum_size = Vector2(target_size, target_size)
		_touch_pause_button.anchor_left = 0.5
		_touch_pause_button.anchor_right = 0.5
		_touch_pause_button.offset_left = -target_size * 0.5
		_touch_pause_button.offset_right = target_size * 0.5
		_touch_pause_button.offset_top = safe.y + 8.0 * layout_scale
		_touch_pause_button.offset_bottom = _touch_pause_button.offset_top + target_size
		_touch_pause_button.focus_mode = Control.FOCUS_ALL
		_touch_pause_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		_touch_pause_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		_touch_pause_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		var pause_chip := PanelContainer.new()
		pause_chip.name = "PauseGlyphChip"
		pause_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pause_chip.set_anchors_preset(Control.PRESET_CENTER)
		var chip_size := 32.0 * layout_scale
		pause_chip.offset_left = -chip_size * 0.5
		pause_chip.offset_right = chip_size * 0.5
		pause_chip.offset_top = -chip_size * 0.5
		pause_chip.offset_bottom = chip_size * 0.5
		pause_chip.add_theme_stylebox_override("panel", _style(RECEIPT_LIGHT, PANEL_EDGE, 0, 1))
		var pause_glyph := _label("Ⅱ", 18, INK)
		pause_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pause_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pause_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pause_chip.add_child(pause_glyph)
		_touch_pause_button.add_child(pause_chip)
		_touch_pause_button.pressed.connect(_on_touch_pause_pressed)
		_root.add_child(_touch_pause_button)


func _on_touch_pause_pressed() -> void:
	if not _overlay_mode.is_empty():
		return
	var scene := get_tree().current_scene
	var shop := scene.find_child("ShiftShop", true, false) as ShiftShop if is_instance_valid(scene) else null
	if is_instance_valid(shop) and shop.visible:
		return
	_request_pause()


func _request_pause() -> void:
	if not _overlay_mode.is_empty():
		return
	var scene := get_tree().current_scene
	var shop := scene.find_child("ShiftShop", true, false) as ShiftShop if is_instance_valid(scene) else null
	if is_instance_valid(shop) and shop.visible:
		return
	pause_requested.emit()
	if _overlay_mode.is_empty():
		show_pause_menu()


func _safe_insets(viewport_size: Vector2) -> Vector4:
	if not _is_mobile_platform() or get_window() == null:
		return Vector4.ZERO
	var safe_area := DisplayServer.get_display_safe_area()
	var window_position := DisplayServer.window_get_position()
	var window_size := get_window().size
	if safe_area.size.x <= 0 or safe_area.size.y <= 0 or window_size.x <= 0 or window_size.y <= 0:
		return Vector4.ZERO
	var left_px := clampf(float(safe_area.position.x - window_position.x), 0.0, float(window_size.x))
	var top_px := clampf(float(safe_area.position.y - window_position.y), 0.0, float(window_size.y))
	var right_px := clampf(float(window_position.x + window_size.x - safe_area.end.x), 0.0, float(window_size.x))
	var bottom_px := clampf(float(window_position.y + window_size.y - safe_area.end.y), 0.0, float(window_size.y))
	return Vector4(left_px * viewport_size.x / window_size.x, top_px * viewport_size.y / window_size.y, right_px * viewport_size.x / window_size.x, bottom_px * viewport_size.y / window_size.y)


func _touch_target_size(viewport_size: Vector2) -> float:
	return 48.0 * _mobile_density_scale(viewport_size)


func _mobile_spacing(value: float) -> int:
	if not _is_mobile_platform():
		return roundi(value)
	return roundi(value * _mobile_layout_scale(get_viewport().get_visible_rect().size))


func _mobile_layout_scale(viewport_size: Vector2) -> float:
	return clampf(viewport_size.y / 1080.0, 0.75, 1.0)


func _mobile_density_scale(viewport_size: Vector2) -> float:
	if OS.has_feature("portmaster"):
		return 1.0
	var window_width := float(get_window().size.x) if get_window() != null else viewport_size.x
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		dpi = 160.0 if _is_mobile_platform() else 96.0
	return clampf(dpi / 160.0 * viewport_size.x / maxf(window_width, 1.0), 1.0, 4.0)


func _is_mobile_platform() -> bool:
	return OS.has_feature("portmaster") or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()


func _is_native_mobile_platform() -> bool:
	return OS.has_feature("portmaster") or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func _is_portrait() -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	return viewport_size.x < viewport_size.y


func _open_overlay(mode: StringName, title: String, subtitle: String) -> void:
	hide_overlay()
	_overlay_mode = mode
	var is_choice := mode == &"level_up" or mode == &"stat_choice"
	if is_instance_valid(_touch_pause_button):
		_touch_pause_button.visible = false
	_overlay = Control.new()
	_overlay.name = "ModalOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.04, 0.075, 0.09, 0.66 if is_choice else 0.84)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := _safe_insets(viewport_size)
	var portmaster := OS.has_feature("portmaster")
	var available_width := viewport_size.x - safe.x - safe.z
	var available_height := viewport_size.y - safe.y - safe.w
	center.offset_left = safe.x
	center.offset_right = -safe.z
	center.offset_top = safe.y
	center.offset_bottom = -safe.w
	if portmaster:
		var width_ratio := 0.96 if is_choice else 0.92
		var height_ratio := 0.90 if is_choice or mode == &"results" else 0.86
		panel.custom_minimum_size = Vector2(available_width * width_ratio, available_height * height_ratio)
	elif _is_mobile_platform():
		if is_choice:
			panel.custom_minimum_size = Vector2(available_width * 0.96, available_height * 0.88)
		elif mode == &"results":
			panel.custom_minimum_size = Vector2(available_width * 0.66, available_height * 0.66)
		else:
			panel.custom_minimum_size = Vector2(available_width * 0.90, available_height * 0.90)
	else:
		panel.custom_minimum_size = Vector2(available_width * 0.92 if is_choice else minf(760 if mode == &"in_game_settings" else (660 if mode == &"results" else 500), available_width * 0.92), available_height * 0.84 if is_choice else 0.0)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new() if is_choice else _style(PANEL, PANEL_EDGE, 0, 1))
	center.add_child(panel)
	_overlay_body = VBoxContainer.new()
	_overlay_body.add_theme_constant_override("separation", _mobile_spacing(8) if _is_mobile_platform() else 16)
	var body_margin := _mobile_spacing(8) if _is_mobile_platform() else 24
	var body_margins := _margin_content(_overlay_body, body_margin)
	_overlay_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body_width := available_width * 0.92 if portmaster and mode == &"results" else (available_width * 0.66 if _is_mobile_platform() and mode == &"results" else available_width)
	_overlay_body.custom_minimum_size.x = maxf(0.0, body_width - body_margin * 2.0)
	body_margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_margins.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _is_mobile_platform():
		var scroll := ScrollContainer.new()
		var scroll_height_ratio := 0.84 if is_choice or (portmaster and mode == &"results") else (0.60 if mode == &"results" else 0.86)
		scroll.custom_minimum_size.y = maxf(120.0, available_height * scroll_height_ratio - body_margin * 2.0)
		scroll.name = "OverlayContentScroll"
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.follow_focus = portmaster and is_choice
		scroll.add_child(body_margins)
		panel.add_child(scroll)
	else:
		panel.add_child(body_margins)
	var receipt := _label("SUPERMARKET: THE NIGHT    /    SHIFT RECORD", 15, TEAL, true)
	if _is_mobile_platform():
		receipt.add_theme_font_size_override("font_size", roundi(_mobile_overlay_font(viewport_size, 16.0)))
	receipt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	receipt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if _is_mobile_platform() else TextServer.AUTOWRAP_OFF
	receipt.visible = not is_choice
	_overlay_body.add_child(receipt)
	var heading := _label(title, 34, RECEIPT_LIGHT if is_choice else TEXT, true)
	if _is_mobile_platform():
		heading.add_theme_font_size_override("font_size", roundi(clampf(viewport_size.y * 0.032, 24.0, 34.0)))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if _is_mobile_platform() else TextServer.AUTOWRAP_OFF
	_overlay_body.add_child(heading)
	if not subtitle.is_empty():
		var description := _label(subtitle, 19, RECEIPT_LIGHT if is_choice else MUTED)
		if _is_mobile_platform():
			description.add_theme_font_size_override("font_size", roundi(_mobile_overlay_font(viewport_size, 19.0)))
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
	var viewport_size := get_viewport().get_visible_rect().size
	var button_width := minf(360.0, viewport_size.x * 0.78)
	if _is_mobile_platform():
		button_width = minf(360.0 * _mobile_density_scale(viewport_size), viewport_size.x * 0.70)
	button.custom_minimum_size = Vector2(button_width, maxf(54.0, _touch_target_size(viewport_size)))
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", _responsive_font_size(20))
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override("normal", _style(GOLD.lightened(0.24) if primary else RECEIPT_LIGHT, GOLD if primary else PANEL_EDGE, 0, 1))
	button.add_theme_stylebox_override("hover", _style(GOLD.lightened(0.32) if primary else Color("fffdf4"), GOLD, 0, 2))
	button.add_theme_stylebox_override("pressed", _style(Color("d8e5d2"), TEAL, 0, 2))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, TEAL, 0, 2))
	button.pressed.connect(func() -> void: BakkalAudio.play_sfx(&"ui_confirm"); callback.call())
	_overlay_body.add_child(button)
	if primary:
		button.grab_focus.call_deferred()


func _style_settings_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_ALL
	if _is_mobile_platform():
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, _touch_target_size(get_viewport().get_visible_rect().size))
	button.add_theme_font_size_override("font_size", _responsive_font_size(16))
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override("normal", _style(RECEIPT_LIGHT, PANEL_EDGE, 0, 1))
	button.add_theme_stylebox_override("hover", _style(Color("fffdf4"), GOLD, 0, 2))
	button.add_theme_stylebox_override("focus", _style(RECEIPT_LIGHT, TEAL, 0, 2))
	button.add_theme_stylebox_override("pressed", _style(Color("d8e5d2"), TEAL, 0, 2))


func _add_touch_controls_setting(parent: Control) -> void:
	var toggle := CheckButton.new()
	toggle.text = I18n.t("SETTINGS_TOUCH_CONTROLS", "Dokunmatik joystick kullan")
	toggle.button_pressed = DisplayManager.touch_controls_enabled
	toggle.custom_minimum_size.y = 40
	_style_settings_button(toggle)
	toggle.toggled.connect(func(enabled: bool) -> void:
		DisplayManager.set_touch_controls_enabled(enabled)
		BakkalAudio.play_sfx(&"ui_confirm")
		_show_in_game_settings()
	)
	parent.add_child(toggle)


func _panel(position: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position
	panel.size = size
	panel.add_theme_stylebox_override("panel", _style(PANEL, PANEL_EDGE, 0, 1))
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
	label.add_theme_font_size_override("font_size", _responsive_font_size(size))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.14))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	if pixel_accent and display_font != null:
		label.add_theme_font_override("font", display_font)
	return label


func _apply_world_text_contrast(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 3)


func _responsive_font_size(size: int) -> int:
	if OS.has_feature("portmaster"):
		return roundi(float(size) * 1.15)
	if _is_mobile_platform():
		var viewport_size := get_viewport().get_visible_rect().size
		return maxi(12, roundi(float(size) * clampf(viewport_size.y / 1080.0, 0.75, 1.0)))
	var window_width := float(get_window().size.x) if get_window() != null else 1920.0
	return roundi(float(size) * clampf(1920.0 / maxf(window_width, 1.0), 1.0, 1.4))


func _mobile_hud_font(viewport_size: Vector2, preferred: float) -> float:
	if OS.has_feature("portmaster"):
		return minf(preferred * 1.25, 23.0)
	return clampf(viewport_size.y * 0.018, 14.0, preferred)


func _mobile_overlay_font(viewport_size: Vector2, preferred: float) -> float:
	if OS.has_feature("portmaster"):
		return minf(preferred * 1.30, 25.0)
	return clampf(viewport_size.y * 0.020, 15.0, preferred)


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
