extends Control
class_name BakkalTitleScreen

const ARENA_PATH := "res://levels/arena/arena.tscn"
const TEST_ARENA_PATH := "res://levels/arena/test_arena.tscn"
const RECORD_PATH := "user://bakkal_records.cfg"

# Core Palette Tokens
const COLOR_BASE_DARK := Color("10191c")     # Coolers after closing
const COLOR_SURFACE := Color("263630")       # Deep aisle green
const COLOR_RECEIPT_PAPER := Color("efebd8") # Stockroom paper
const COLOR_ACCENT_LIME := Color("d6c479")   # Faded yellow price sticker
const COLOR_ACCENT_CORAL := Color("d9786b")  # Marked-down produce label

# Supporting Tonal Tokens
const COLOR_SURFACE_DARK := Color(0.07, 0.11, 0.10, 0.94)
const COLOR_SURFACE_BORDER := Color(0.25, 0.35, 0.31, 1.0)
const COLOR_SURFACE_BORDER_LIGHT := Color(0.39, 0.48, 0.40, 1.0)
const COLOR_MUTED := Color(0.64, 0.69, 0.63, 1.0)
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.70)

# Backward-Compatible Aliases
const INK := COLOR_BASE_DARK
const GOLD := COLOR_ACCENT_LIME
const CREAM := COLOR_RECEIPT_PAPER
const MUTED := COLOR_MUTED
const PANEL := COLOR_SURFACE_DARK

@export var display_font: FontFile

var _menu: Control
var _clerk: TextureRect
var _active_modal: Control
var _modal_return_focus: Control
var _buttons: Array[Button] = []
var _btn_focus_indicators: Dictionary = {}


# Custom receipt divider line (dashed or double)
class ReceiptRule extends Control:
	enum RuleType { DASHED, DOUBLE }
	var rule_type: RuleType = RuleType.DASHED
	var rule_color: Color = Color(0.55, 0.65, 0.67, 0.35)

	func _init(p_type: RuleType = RuleType.DASHED, p_color: Color = Color(0.55, 0.65, 0.67, 0.35)) -> void:
		rule_type = p_type
		rule_color = p_color
		custom_minimum_size = Vector2(0, 6 if p_type == RuleType.DOUBLE else 4)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		if w <= 0.0:
			return
		match rule_type:
			RuleType.DASHED:
				var y := size.y * 0.5
				draw_dashed_line(Vector2(0, y), Vector2(w, y), rule_color, 1.0, 4.0)
			RuleType.DOUBLE:
				draw_line(Vector2(0, 1.5), Vector2(w, 1.5), rule_color, 1.0)
				draw_line(Vector2(0, size.y - 1.5), Vector2(w, size.y - 1.5), rule_color, 1.0)


# Custom receipt dot leader control (draws clean dots between key and value)
class DotLeader extends Control:
	var dot_color: Color = Color(0.55, 0.65, 0.67, 0.35)

	func _init(p_color: Color = Color(0.55, 0.65, 0.67, 0.35)) -> void:
		dot_color = p_color
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5 + 1.0
		var x := 4.0
		while x < size.x - 4.0:
			draw_circle(Vector2(x, y), 1.0, dot_color)
			x += 6.0


func _ready() -> void:
	BakkalAudio.play_music()
	_build()
	if I18n != null and I18n.has_signal("language_changed"):
		I18n.language_changed.connect(func(_l: String) -> void:
			_build_menu()
		)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if is_instance_valid(_active_modal):
			if _active_modal.has_meta("is_settings"):
				BakkalAudio.save_settings()
			_close_modal()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what != Node.NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if is_instance_valid(_active_modal):
		if _active_modal.has_meta("is_settings"):
			BakkalAudio.save_settings()
		_close_modal()
	else:
		_show_exit_confirmation()


func _build() -> void:
	# 1. Full-store interior background
	var background := TextureRect.new()
	background.texture = load("res://assets/generated/rooms/market_tidy_lights_on.png")
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# 2. Restrained late-night atmospheric vignette (keeps store art prominent)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(COLOR_BASE_DARK.r, COLOR_BASE_DARK.g, COLOR_BASE_DARK.b, 0.50)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var top_glow := ColorRect.new()
	top_glow.anchor_left = 0.0
	top_glow.anchor_right = 1.0
	top_glow.anchor_top = 0.0
	top_glow.anchor_bottom = 0.10
	top_glow.color = Color(COLOR_BASE_DARK.r, COLOR_BASE_DARK.g, COLOR_BASE_DARK.b, 0.40)
	top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_glow)

	var bot_glow := ColorRect.new()
	bot_glow.anchor_left = 0.0
	bot_glow.anchor_right = 1.0
	bot_glow.anchor_top = 0.90
	bot_glow.anchor_bottom = 1.0
	bot_glow.color = Color(COLOR_BASE_DARK.r, COLOR_BASE_DARK.g, COLOR_BASE_DARK.b, 0.50)
	bot_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot_glow)

	# 3. Night Clerk Character & Grounded Shadow (Firmly grounded, no decorative motion)
	var clerk_shadow := PanelContainer.new()
	clerk_shadow.anchor_left = 0.455
	clerk_shadow.anchor_right = 0.585
	clerk_shadow.anchor_top = 0.725
	clerk_shadow.anchor_bottom = 0.755
	if OS.has_feature("portmaster"):
		clerk_shadow.anchor_left += 0.13
		clerk_shadow.anchor_right += 0.13
	clerk_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	shadow_style.set_corner_radius_all(18)
	clerk_shadow.add_theme_stylebox_override("panel", shadow_style)
	add_child(clerk_shadow)

	_clerk = TextureRect.new()
	_clerk.texture = load("res://assets/generated/actors/player_night_clerk.png")
	_clerk.anchor_left = 0.38
	_clerk.anchor_right = 0.66
	_clerk.anchor_top = 0.13
	_clerk.anchor_bottom = 0.88
	if OS.has_feature("portmaster"):
		_clerk.anchor_left += 0.13
		_clerk.anchor_right += 0.13
	_clerk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_clerk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_clerk.modulate = Color(1.0, 0.99, 0.96, 0.98)
	_clerk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clerk)

	# 4. Compact Operator Terminal Menu (Target: ~320-330px wide, ~420-440px tall at 1280x720)
	_build_compact_menu()

	# 5. Concise Status Badge in Top Right (Compact score/mode status)
	_build_concise_status()

	# 6. Minimal Footer
	_build_footer()

	# 7. Focus Traversal Setup
	_setup_focus_navigation()


func _build_compact_menu() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := _safe_insets(viewport_size)
	var portrait := viewport_size.x < viewport_size.y
	var mobile := _is_mobile_platform()
	var mobile_landscape := mobile and not portrait
	var scale_factor := _receipt_ui_scale()
	var inset := 8.0 * scale_factor if mobile else 24.0
	var available_width := maxf(200.0 * scale_factor, viewport_size.x - safe.x - safe.z - inset * 2.0)
	var available_height := maxf(200.0 * scale_factor, viewport_size.y - safe.y - safe.w - inset * 2.0)
	var portmaster := OS.has_feature("portmaster")
	var menu_width := available_width * (0.46 if portmaster else (0.29 if mobile_landscape else 0.90)) if mobile else (available_width * 0.88 if portrait else minf(390.0 * scale_factor, available_width * 0.48))
	var menu_height := available_height * (0.78 if portmaster else (0.72 if mobile_landscape else 0.90)) if mobile else (available_height * 0.68 if portrait else minf(462.0 * scale_factor, available_height * 0.88))
	var card := PanelContainer.new()
	card.anchor_left = 0.0
	card.anchor_right = 0.0
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = safe.x + inset
	card.offset_right = card.offset_left + menu_width
	card.offset_top = -menu_height - safe.w - inset
	card.offset_bottom = -safe.w - inset
	card.custom_minimum_size = Vector2(menu_width, 0)
	card.add_theme_stylebox_override("panel", _receipt_panel_style())
	add_child(card)

	var margins := _margins(roundi((2.0 if mobile_landscape else 12.0) * scale_factor) if mobile else 18)
	card.add_child(margins)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", roundi((1.0 if mobile_landscape else 8.0) * scale_factor) if mobile else 8)
	margins.add_child(stack)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	stack.add_child(header)
	var title_line := HBoxContainer.new()
	title_line.add_theme_constant_override("separation", 8)
	header.add_child(title_line)
	var brand_title := _label("SUPERMARKET", 13 if mobile_landscape else 22, COLOR_BASE_DARK)
	brand_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_line.add_child(brand_title)
	title_line.add_child(_label("THE NIGHT", 9 if mobile_landscape else 12, COLOR_ACCENT_CORAL))
	var receipt_subtitle := _label("NIGHT SHIFT  /  CHOOSE YOUR ROUTE", 6 if mobile_landscape else 10, COLOR_SURFACE)
	header.add_child(receipt_subtitle)
	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DOUBLE, Color(COLOR_BASE_DARK, 0.55)))

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", roundi((1.0 if mobile_landscape else 4.0) * scale_factor) if mobile else 4)
	_menu = list
	_menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_menu)
	_build_menu()
	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_BASE_DARK, 0.42)))
	var receipt_footer := _label("KEEP AISLES CLEAR UNTIL MORNING", 6 if mobile_landscape else 10, COLOR_SURFACE)
	receipt_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(receipt_footer)


func _build_menu() -> void:
	if not is_instance_valid(_menu):
		return
	for child: Node in _menu.get_children():
		child.queue_free()
	_buttons.clear()

	var first_focus := true

	# 0. Resume saved run if available
	if RunSaveManager != null and RunSaveManager.has_saved_run():
		var summary := RunSaveManager.get_saved_run_summary()
		var cont_text := "CONTINUE SHIFT" if I18n.current_locale == "en" else "VARDIYAYA DEVAM ET"
		_add_menu_button(
			cont_text,
			"↻",
			"",
			COLOR_ACCENT_LIME,
			_resume_saved_run,
			first_focus,
			false,
			42,
			true
		)
		first_focus = false
		if not _is_mobile_landscape():
			_menu.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.3)))

	# 1. Primary Action: 20-Round Campaign
	_add_menu_button(
		I18n.t("TITLE_CAMPAIGN", "START SHIFT"),
		"01",
		"",
		COLOR_ACCENT_LIME,
		_start_run,
		first_focus,
		false,
		42,
		true
	)
	first_focus = false

	# 2. Endless Night Mode
	_add_menu_button(
		I18n.t("TITLE_ENDLESS", "ENDLESS NIGHT"),
		"02",
		"",
		COLOR_ACCENT_CORAL,
		_start_endless_run,
		false,
		false,
		40,
		true
	)

	if not _is_mobile_landscape():
		_menu.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.3)))

	# 3. Subpage Actions
	_add_menu_button(I18n.t("TITLE_MANUAL", "HOW TO PLAY"), "03", "", COLOR_MUTED, _show_controls, false, false, 36, true)
	_add_menu_button(I18n.t("TITLE_SETTINGS", "OPTIONS"), "04", "", COLOR_MUTED, _show_settings, false, false, 36, true)
	_add_menu_button(I18n.t("TITLE_RECORDS", "RECORDS"), "05", "", COLOR_MUTED, _show_records, false, false, 36, true)
	_add_menu_button(I18n.t("TITLE_CREDITS", "CREDITS"), "06", "", COLOR_MUTED, _show_credits, false, false, 36, true)

	if not _is_mobile_landscape():
		_menu.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.3)))

	# 4. Quit Action
	_add_menu_button(I18n.t("TITLE_QUIT", "QUIT"), "ESC", "", COLOR_ACCENT_CORAL, _quit_game, false, true, 36, true)

	_setup_focus_navigation()


func _resume_saved_run() -> void:
	BakkalAudio.play_sfx(&"ui_confirm")
	RunSaveManager.set_meta("should_resume", true)
	get_tree().change_scene_to_file("res://levels/arena/arena.tscn")


func _build_concise_status() -> void:
	# Compact score/mode status chip in top right
	if _is_mobile_landscape():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := _safe_insets(viewport_size)
	var chip_width := minf(280.0 * _receipt_ui_scale(), maxf(220.0, viewport_size.x * 0.46 - safe.z))
	var chip := PanelContainer.new()
	chip.anchor_left = 1.0
	chip.anchor_right = 1.0
	chip.offset_left = -chip_width - safe.z - 24.0
	chip.offset_top = safe.y + 24.0
	chip.offset_right = -safe.z - 24.0
	chip.offset_bottom = chip.offset_top + 80.0 * _receipt_ui_scale()
	chip.custom_minimum_size = Vector2(chip_width, 80.0 * _receipt_ui_scale())
	chip.add_theme_stylebox_override("panel", _chip_panel_style())
	add_child(chip)

	var margins := _margins(12)
	chip.add_child(margins)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margins.add_child(stack)

	var head_row := HBoxContainer.new()
	stack.add_child(head_row)
	var head_lbl := _label("SHIFT AUDIT · BEST MARKS", 11, COLOR_ACCENT_LIME)
	head_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(head_lbl)

	var row1 := HBoxContainer.new()
	stack.add_child(row1)
	var c_lbl := _label("CAMPAIGN SCORE", 12, COLOR_RECEIPT_PAPER)
	row1.add_child(c_lbl)
	var dl1 := DotLeader.new(Color(COLOR_MUTED, 0.35))
	row1.add_child(dl1)
	var c_val := _label("%06d" % _load_best_score(), 14, COLOR_ACCENT_LIME)
	row1.add_child(c_val)

	var row2 := HBoxContainer.new()
	stack.add_child(row2)
	var e_lbl := _label("ENDLESS SURVIVAL", 12, COLOR_RECEIPT_PAPER)
	row2.add_child(e_lbl)
	var dl2 := DotLeader.new(Color(COLOR_MUTED, 0.35))
	row2.add_child(dl2)
	var e_val := _label("W%02d" % _load_endless_best_wave(), 13, COLOR_RECEIPT_PAPER)
	row2.add_child(e_val)


func _build_footer() -> void:
	# The receipt already carries the one-line store sign-off; avoid a second floating footer.
	return


func _setup_focus_navigation() -> void:
	if _buttons.is_empty():
		return
	if _is_mobile_landscape():
		for i in range(_buttons.size()):
			var left := i - 1 if i % 2 == 1 else i
			var right := i + 1 if i % 2 == 0 and i + 1 < _buttons.size() else i
			var top := i - 2 if i >= 2 else i
			var bottom := i + 2 if i + 2 < _buttons.size() else i
			_buttons[i].focus_neighbor_left = _buttons[left].get_path()
			_buttons[i].focus_neighbor_right = _buttons[right].get_path()
			_buttons[i].focus_neighbor_top = _buttons[top].get_path()
			_buttons[i].focus_neighbor_bottom = _buttons[bottom].get_path()
		return
	for i in range(_buttons.size()):
		var prev_idx := (i - 1 + _buttons.size()) % _buttons.size()
		var next_idx := (i + 1) % _buttons.size()
		_buttons[i].focus_neighbor_top = _buttons[prev_idx].get_path()
		_buttons[i].focus_neighbor_bottom = _buttons[next_idx].get_path()


func _add_menu_button(
	text: String,
	code: String,
	badge_text: String,
	badge_color: Color,
	callback: Callable,
	is_primary: bool = false,
	is_danger: bool = false,
	height: int = 30,
	use_receipt_style: bool = false
) -> void:
	var button := Button.new()
	button.text = ""
	var scale_factor := _receipt_ui_scale()
	var touch_size := _mobile_touch_target(get_viewport().get_visible_rect().size)
	var mobile_landscape := _is_mobile_landscape()
	var landscape_row_height := minf(26.0 * scale_factor, get_viewport().get_visible_rect().size.y / 15.0)
	if mobile_landscape:
		text = _mobile_menu_label(badge_text, text)
		touch_size = minf(touch_size, landscape_row_height)
	button.custom_minimum_size = Vector2(0, landscape_row_height if mobile_landscape else maxf(float(height) * scale_factor, touch_size))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	button.add_theme_stylebox_override("normal", _receipt_button_style(is_primary, is_danger, &"normal") if use_receipt_style else _button_normal_style(is_primary, is_danger))
	button.add_theme_stylebox_override("hover", _receipt_button_style(is_primary, is_danger, &"hover") if use_receipt_style else _button_hover_style(is_primary, is_danger))
	button.add_theme_stylebox_override("focus", _receipt_button_style(is_primary, is_danger, &"focus") if use_receipt_style else _button_focus_style(is_primary, is_danger))
	button.add_theme_stylebox_override("pressed", _receipt_button_style(is_primary, is_danger, &"pressed") if use_receipt_style else _button_pressed_style(is_danger))
	if use_receipt_style:
		button.add_theme_color_override("font_color", COLOR_BASE_DARK)
		button.add_theme_color_override("font_hover_color", COLOR_BASE_DARK)
		button.add_theme_color_override("font_pressed_color", COLOR_BASE_DARK)
		button.add_theme_color_override("font_focus_color", COLOR_BASE_DARK)
	button.clip_contents = true

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", roundi((4.0 if mobile_landscape else 12.0) * scale_factor))
	margin.add_theme_constant_override("margin_right", roundi((4.0 if mobile_landscape else 12.0) * scale_factor))
	margin.add_theme_constant_override("margin_top", roundi((1.0 if mobile_landscape else 4.0) * scale_factor))
	margin.add_theme_constant_override("margin_bottom", roundi((1.0 if mobile_landscape else 4.0) * scale_factor))
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", roundi((5.0 if mobile_landscape else 8.0) * scale_factor))
	margin.add_child(row)

	var focus_cursor := Label.new()
	focus_cursor.text = "▶"
	focus_cursor.add_theme_font_size_override("font_size", roundi(13.0 * scale_factor))
	focus_cursor.add_theme_color_override("font_color", COLOR_ACCENT_CORAL if is_danger else (COLOR_SURFACE if use_receipt_style else COLOR_ACCENT_LIME))
	focus_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_cursor.visible = false
	row.add_child(focus_cursor)
	_btn_focus_indicators[button] = focus_cursor

	var code_lbl := Label.new()
	code_lbl.text = "[%s]" % code
	code_lbl.add_theme_font_size_override("font_size", roundi((10.0 if mobile_landscape else 13.0) * scale_factor))
	code_lbl.add_theme_color_override("font_color", COLOR_SURFACE if use_receipt_style else COLOR_MUTED)
	code_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if display_font != null:
		code_lbl.add_theme_font_override("font", display_font)
	row.add_child(code_lbl)

	var main_lbl := Label.new()
	main_lbl.text = text
	var landscape_font_compaction := 0.85 if OS.has_feature("portmaster") else (0.50 if mobile_landscape else 1.0)
	main_lbl.add_theme_font_size_override("font_size", roundi(float(16 if is_primary else 15) * scale_factor * landscape_font_compaction))
	main_lbl.add_theme_color_override("font_color", COLOR_BASE_DARK if use_receipt_style else COLOR_RECEIPT_PAPER)
	main_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mobile_landscape:
		main_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		main_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		main_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		main_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	main_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if display_font != null:
		main_lbl.add_theme_font_override("font", display_font)
	row.add_child(main_lbl)

	if badge_text != "":
		var badge := Label.new()
		badge.text = badge_text
		badge.add_theme_font_size_override("font_size", roundi(12.0 * scale_factor))
		badge.add_theme_color_override("font_color", COLOR_BASE_DARK if use_receipt_style else badge_color)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if display_font != null:
			badge.add_theme_font_override("font", display_font)
		row.add_child(badge)

	button.focus_entered.connect(func() -> void:
		if is_instance_valid(focus_cursor):
			focus_cursor.visible = true
	)
	button.focus_exited.connect(func() -> void:
		if is_instance_valid(focus_cursor):
			focus_cursor.visible = false
	)

	button.pressed.connect(func() -> void:
		BakkalAudio.play_sfx(&"ui_confirm")
	)
	button.pressed.connect(callback)

	_menu.add_child(button)
	_buttons.append(button)

	if is_primary:
		button.grab_focus.call_deferred()


func _mobile_menu_label(code: String, fallback: String) -> String:
	var english := I18n.current_locale == "en"
	match code:
		"01": return "CAMPAIGN SHIFT" if english else "KAMPANYA VARDİYASI"
		"02": return "ENDLESS NIGHT" if english else "SONSUZ GECE MODU"
		"03": return "HOW TO PLAY" if english else "NASIL OYNANIR"
		"04": return "OPTIONS" if english else "AYARLAR"
		"05": return "RECORDS" if english else "KAYITLAR"
		"06": return "CREDITS" if english else "EMEĞİ GEÇENLER"
		"ESC": return "QUIT" if english else "ÇIKIŞ"
		"↻": return "RESUME SHIFT" if english else "VARDİYAYA DÖN"
	return fallback


# --- Actions and Callbacks (Preserved 1:1) ---

func _start_run() -> void:
	get_tree().set_meta("supermarket_endless_mode", false)
	get_tree().change_scene_to_file(ARENA_PATH)


func _start_endless_run() -> void:
	get_tree().set_meta("supermarket_endless_mode", true)
	get_tree().change_scene_to_file(ARENA_PATH)


func _start_test_run() -> void:
	get_tree().set_meta("supermarket_endless_mode", false)
	get_tree().change_scene_to_file(TEST_ARENA_PATH)


func _quit_game() -> void:
	get_tree().quit()


# --- Modal Management ---

func _open_modal(title_text: String, min_size: Vector2i) -> VBoxContainer:
	# Replacing a modal should preserve the original menu focus target; restoring
	# focus to the modal being replaced would leave a stale control after queue_free.
	if is_instance_valid(_active_modal):
		_active_modal.queue_free()
		_active_modal = null
	else:
		_modal_return_focus = get_viewport().gui_get_focus_owner()

	var overlay := Control.new()
	overlay.name = "ModalOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.theme = _receipt_modal_theme()
	add_child(overlay)
	_active_modal = overlay

	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(COLOR_BASE_DARK.r, COLOR_BASE_DARK.g, COLOR_BASE_DARK.b, 0.85)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dimmer)

	var card := PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := _safe_insets(viewport_size)
	var available_size := Vector2(viewport_size.x - safe.x - safe.z, viewport_size.y - safe.y - safe.w)
	var scale_factor := _receipt_ui_scale()
	var mobile := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	var modal_size := Vector2(minf(min_size.x * scale_factor, available_size.x * 0.92), minf(min_size.y * scale_factor, available_size.y * 0.92))
	var safe_center := Vector2((safe.x - safe.z) / 2.0, (safe.y - safe.w) / 2.0)
	card.offset_left = safe_center.x - modal_size.x / 2.0
	card.offset_right = safe_center.x + modal_size.x / 2.0
	card.offset_top = safe_center.y - modal_size.y / 2.0
	card.offset_bottom = safe_center.y + modal_size.y / 2.0
	card.custom_minimum_size = modal_size

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COLOR_RECEIPT_PAPER
	card_style.border_color = COLOR_SURFACE_BORDER
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(0)
	card_style.shadow_color = COLOR_SHADOW
	card_style.shadow_size = 18
	card.add_theme_stylebox_override("panel", card_style)
	overlay.add_child(card)

	var margins := _margins(roundi(12.0 * scale_factor) if mobile else 18)
	var settings_scroll := mobile and (title_text.to_upper().contains("OPTIONS") or title_text.to_upper().contains("AYARLAR"))
	if settings_scroll:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.add_child(margins)
		card.add_child(scroll)
	else:
		card.add_child(margins)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", roundi(8.0 * scale_factor))
	margins.add_child(stack)

	var title_lbl := _label(title_text, 22, COLOR_BASE_DARK)
	stack.add_child(title_lbl)

	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DOUBLE, Color(COLOR_SURFACE, 0.45)))

	return stack


func _receipt_modal_theme() -> Theme:
	var theme := Theme.new()
	var normal := _receipt_button_style(false, false, &"normal")
	var hover := _receipt_button_style(false, false, &"hover")
	var pressed := _receipt_button_style(false, false, &"pressed")
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("e1dece")
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("focus", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		theme.set_color(state, "Button", COLOR_BASE_DARK)
	theme.set_color("font_disabled_color", "Button", COLOR_MUTED)
	theme.set_font_size("font_size", "Button", roundi(15.0 * _receipt_ui_scale()))
	if display_font != null:
		theme.set_font("font", "Button", display_font)
	return theme


func _receipt_ui_scale() -> float:
	if OS.has_feature("portmaster"):
		# At the 960×720 logical handheld canvas, compensate for its 2/3 output
		# scale so the receipt menu remains readable on a 640×480 panel.
		return 1.5
	if _is_mobile_platform():
		return _mobile_density_scale(get_viewport().get_visible_rect().size)
	var window_width := float(get_window().size.x) if get_window() != null else 1920.0
	return clampf(1920.0 / maxf(window_width, 1.0), 1.0, 1.4)


func _is_portrait() -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	return viewport_size.x < viewport_size.y


func _is_mobile_landscape() -> bool:
	return _is_mobile_platform() and not _is_portrait()


func _is_mobile_platform() -> bool:
	return OS.has_feature("portmaster") or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()


func _is_native_mobile_platform() -> bool:
	return OS.has_feature("portmaster") or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func _add_touch_controls_setting(parent: VBoxContainer) -> void:
	var toggle := CheckButton.new()
	toggle.text = I18n.t("SETTINGS_TOUCH_CONTROLS", "Dokunmatik joystick kullan")
	toggle.button_pressed = DisplayManager.touch_controls_enabled
	toggle.custom_minimum_size.y = maxf(40.0, _mobile_touch_target(get_viewport().get_visible_rect().size))
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.add_theme_color_override("font_color", COLOR_BASE_DARK)
	toggle.add_theme_color_override("font_hover_color", COLOR_BASE_DARK)
	toggle.add_theme_color_override("font_focus_color", COLOR_BASE_DARK)
	toggle.add_theme_stylebox_override("normal", _receipt_button_style(true, false, &"normal"))
	toggle.add_theme_stylebox_override("hover", _receipt_button_style(true, false, &"hover"))
	toggle.add_theme_stylebox_override("focus", _receipt_button_style(true, false, &"focus"))
	toggle.add_theme_stylebox_override("pressed", _receipt_button_style(true, false, &"pressed"))
	toggle.toggled.connect(func(enabled: bool) -> void:
		DisplayManager.set_touch_controls_enabled(enabled)
		BakkalAudio.play_sfx(&"ui_confirm")
		_close_modal()
		_show_settings()
	)
	parent.add_child(toggle)


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


func _mobile_touch_target(viewport_size: Vector2) -> float:
	if not _is_mobile_platform():
		return 0.0
	return 48.0 * _mobile_density_scale(viewport_size)


func _mobile_density_scale(viewport_size: Vector2) -> float:
	if OS.has_feature("portmaster"):
		# Controller UI does not need a phone-style touch target derived from the
		# handheld panel's reported DPI.
		return 1.0
	var window_width := float(get_window().size.x) if get_window() != null else viewport_size.x
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		dpi = 160.0 if _is_mobile_platform() else 96.0
	var viewport_scale := viewport_size.x / maxf(window_width, 1.0)
	return clampf(dpi / 160.0 * viewport_scale, 1.0, 4.0)


func _show_exit_confirmation() -> void:
	var stack := _open_modal("CLOCKING OUT?", Vector2i(520, 236))
	var prompt := _label("Leave the night shift and close the game?", 16, COLOR_BASE_DARK)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(prompt)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	stack.add_child(actions)
	var stay := Button.new()
	stay.text = "KEEP WORKING"
	var exit_button := Button.new()
	exit_button.text = "CLOCK OUT"
	for button in [stay, exit_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = maxf(44.0, _mobile_touch_target(get_viewport().get_visible_rect().size))
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", roundi(15.0 * _receipt_ui_scale()))
		button.add_theme_color_override("font_color", COLOR_BASE_DARK)
		button.add_theme_color_override("font_hover_color", COLOR_BASE_DARK)
		button.add_theme_color_override("font_focus_color", COLOR_BASE_DARK)
		button.add_theme_stylebox_override("normal", _receipt_button_style(false, false, &"normal"))
		button.add_theme_stylebox_override("hover", _receipt_button_style(false, false, &"hover"))
		button.add_theme_stylebox_override("focus", _receipt_button_style(false, false, &"focus"))
		button.add_theme_stylebox_override("pressed", _receipt_button_style(false, false, &"pressed"))
		actions.add_child(button)
	stay.pressed.connect(_close_modal)
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	stay.grab_focus.call_deferred()


func _close_modal() -> void:
	var closing_modal := _active_modal
	if is_instance_valid(_active_modal):
		_active_modal.queue_free()
		_active_modal = null
	var return_focus := _modal_return_focus
	_modal_return_focus = null
	if is_instance_valid(return_focus) and (not is_instance_valid(closing_modal) or not closing_modal.is_ancestor_of(return_focus)):
		return_focus.grab_focus.call_deferred()


func _add_modal_section(parent: VBoxContainer, sec_title: String, description: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)

	var t_lbl := _label(sec_title, 17, COLOR_SURFACE)
	box.add_child(t_lbl)

	var d_lbl := Label.new()
	d_lbl.text = description
	d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_lbl.add_theme_font_size_override("font_size", 17)
	d_lbl.add_theme_color_override("font_color", COLOR_BASE_DARK)
	d_lbl.add_theme_constant_override("line_spacing", 2)
	box.add_child(d_lbl)


func _show_controls() -> void:
	var stack := _open_modal("HOW TO PLAY — TERMINAL GUIDE", Vector2i(560, 420))
	if stack == null:
		return

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	_add_modal_section(body, "MOVEMENT & AISLE NAVIGATION", "Move with WASD or arrow keys to patrol grocery aisles and evade cart hazards.")
	_add_modal_section(body, "AUTOMATIC TOOLS", "Store tools engage nearby targets automatically. Position your reach to clear aisles.")
	_add_modal_section(body, "STOCK TOKENS & XP", "Collect tokens and XP for upgrades between rounds.")
	_add_modal_section(body, "SHIFT MODES", "Choose the 20-round campaign or Endless Night.")
	_add_modal_section(body, "PAUSE TERMINAL", "Press ESC anytime to pause the shift.")

	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.4)))

	var close_btn := Button.new()
	close_btn.text = "BACK TO SHIFT"
	close_btn.custom_minimum_size.y = maxf(38.0, _mobile_touch_target(get_viewport().get_visible_rect().size))
	close_btn.focus_mode = Control.FOCUS_ALL
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_color_override("font_color", COLOR_BASE_DARK)
	close_btn.add_theme_color_override("font_focus_color", COLOR_BASE_DARK)
	if display_font != null:
		close_btn.add_theme_font_override("font", display_font)
	close_btn.add_theme_stylebox_override("normal", _receipt_button_style(true, false, &"normal"))
	close_btn.add_theme_stylebox_override("hover", _receipt_button_style(true, false, &"hover"))
	close_btn.add_theme_stylebox_override("focus", _receipt_button_style(true, false, &"focus"))
	close_btn.add_theme_stylebox_override("pressed", _receipt_button_style(true, false, &"pressed"))
	close_btn.pressed.connect(func() -> void:
		BakkalAudio.play_sfx(&"ui_confirm")
		_close_modal()
	)
	stack.add_child(close_btn)
	close_btn.grab_focus.call_deferred()


func _show_settings() -> void:
	var stack := _open_modal(I18n.t("SETTINGS_TITLE", "OPTIONS — SOUND, DISPLAY & LANGUAGE"), Vector2i(620, 560))
	if stack == null:
		return
	_active_modal.set_meta("is_settings", true)

	# 1. Language selection
	var portrait := _is_portrait()
	var lang_row: Control = VBoxContainer.new() if portrait else HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 12)
	stack.add_child(lang_row)

	var lang_title := _label(I18n.t("SETTINGS_LANGUAGE", "DİL / LANGUAGE"), 16, COLOR_SURFACE)
	lang_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(lang_title)

	var tr_btn := Button.new()
	tr_btn.text = "TÜRKÇE"
	tr_btn.custom_minimum_size = Vector2(100, 36)
	tr_btn.custom_minimum_size.y = maxf(tr_btn.custom_minimum_size.y, _mobile_touch_target(get_viewport().get_visible_rect().size))
	tr_btn.disabled = (I18n.current_locale == "tr")
	tr_btn.focus_mode = Control.FOCUS_ALL
	tr_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tr_btn.pressed.connect(func() -> void:
		I18n.set_language("tr")
		BakkalAudio.play_sfx(&"ui_confirm")
		_build_menu()
		_modal_return_focus = _buttons[0] if not _buttons.is_empty() else null
		_show_settings()
	)
	var language_buttons: Control = HBoxContainer.new() if portrait else lang_row
	if portrait:
		lang_row.add_child(language_buttons)
	language_buttons.add_child(tr_btn)

	var en_btn := Button.new()
	en_btn.text = "ENGLISH"
	en_btn.custom_minimum_size = Vector2(100, 36)
	en_btn.custom_minimum_size.y = maxf(en_btn.custom_minimum_size.y, _mobile_touch_target(get_viewport().get_visible_rect().size))
	en_btn.disabled = (I18n.current_locale == "en")
	en_btn.focus_mode = Control.FOCUS_ALL
	en_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	en_btn.pressed.connect(func() -> void:
		I18n.set_language("en")
		BakkalAudio.play_sfx(&"ui_confirm")
		_build_menu()
		_modal_return_focus = _buttons[0] if not _buttons.is_empty() else null
		_show_settings()
	)
	language_buttons.add_child(en_btn)

	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.4)))

	if not OS.has_feature("portmaster"):
		# 2. Resolution selection
		var res_label := _label(I18n.t("SETTINGS_RESOLUTION", "ÇÖZÜNÜRLÜK"), 16, COLOR_SURFACE)
		stack.add_child(res_label)

		var res_row: Control = GridContainer.new() if portrait else HBoxContainer.new()
		if portrait:
			(res_row as GridContainer).columns = 2
		res_row.add_theme_constant_override("separation", 8)
		stack.add_child(res_row)

		var resolutions := ["1920x1080", "1600x900", "1366x768", "1280x720"]
		for r_idx: int in range(resolutions.size()):
			var r_btn := Button.new()
			r_btn.text = resolutions[r_idx]
			r_btn.custom_minimum_size = Vector2(110, maxf(36.0, _mobile_touch_target(get_viewport().get_visible_rect().size)))
			r_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r_btn.disabled = (DisplayManager.current_resolution_index == r_idx)
			r_btn.focus_mode = Control.FOCUS_ALL
			r_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			r_btn.pressed.connect(func() -> void:
				DisplayManager.set_resolution_index(r_idx)
				BakkalAudio.play_sfx(&"ui_confirm")
				_close_modal()
				_show_settings()
			)
			r_btn.custom_minimum_size.y = maxf(36.0, _mobile_touch_target(get_viewport().get_visible_rect().size))
			res_row.add_child(r_btn)

		# 3. Window Mode selection
		var mode_label := _label(I18n.t("SETTINGS_WINDOW_MODE", "EKRAN MODU"), 16, COLOR_SURFACE)
		stack.add_child(mode_label)

		var mode_row: Control = GridContainer.new() if portrait else HBoxContainer.new()
		if portrait:
			(mode_row as GridContainer).columns = 2
		mode_row.add_theme_constant_override("separation", 8)
		stack.add_child(mode_row)

		var mode_names := [
			I18n.t("WINDOW_FULLSCREEN", "Tam Ekran"),
			I18n.t("WINDOW_BORDERLESS", "Kenarlıksız"),
			I18n.t("WINDOW_WINDOWED", "Pencereli")
		]
		for m_idx: int in range(mode_names.size()):
			var m_btn := Button.new()
			m_btn.text = mode_names[m_idx]
			m_btn.custom_minimum_size = Vector2(140, maxf(36.0, _mobile_touch_target(get_viewport().get_visible_rect().size)))
			m_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			m_btn.disabled = (DisplayManager.current_window_mode == m_idx)
			m_btn.focus_mode = Control.FOCUS_ALL
			m_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			m_btn.pressed.connect(func() -> void:
				DisplayManager.set_window_mode(m_idx)
				BakkalAudio.play_sfx(&"ui_confirm")
				_close_modal()
				_show_settings()
			)
			m_btn.custom_minimum_size.y = maxf(36.0, _mobile_touch_target(get_viewport().get_visible_rect().size))
			mode_row.add_child(m_btn)

	if not _is_native_mobile_platform():
		_add_touch_controls_setting(stack)

	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.4)))

	# 4. Audio settings
	var music := _volume_control(stack, I18n.t("SETTINGS_MUSIC", "NIGHT SHIFT MUSIC"), float(BakkalAudio.music_volume_db))
	var sfx := _volume_control(stack, I18n.t("SETTINGS_SFX", "GAME FEEDBACK (SFX)"), float(BakkalAudio.sfx_volume_db))
	music.value_changed.connect(BakkalAudio.set_music_volume)
	sfx.value_changed.connect(BakkalAudio.set_sfx_volume)

	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.4)))

	# 5. Save & Close
	var done := Button.new()
	done.text = I18n.t("SETTINGS_SAVE", "SAVE AND CLOSE")
	done.custom_minimum_size.y = maxf(44.0, _mobile_touch_target(get_viewport().get_visible_rect().size))
	done.focus_mode = Control.FOCUS_ALL
	done.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	done.add_theme_color_override("font_color", COLOR_BASE_DARK)
	done.add_theme_color_override("font_focus_color", COLOR_BASE_DARK)
	if display_font != null:
		done.add_theme_font_override("font", display_font)
	done.add_theme_stylebox_override("normal", _receipt_button_style(true, false, &"normal"))
	done.add_theme_stylebox_override("hover", _receipt_button_style(true, false, &"hover"))
	done.add_theme_stylebox_override("focus", _receipt_button_style(true, false, &"focus"))
	done.add_theme_stylebox_override("pressed", _receipt_button_style(true, false, &"pressed"))
	done.pressed.connect(func() -> void:
		BakkalAudio.play_sfx(&"ui_confirm")
		BakkalAudio.save_settings()
		DisplayManager.save_settings()
		_close_modal()
	)
	stack.add_child(done)
	done.grab_focus.call_deferred()


func _show_records() -> void:
	var stack := _open_modal("SHIFT AUDIT — PERFORMANCE RECORDS", Vector2i(500, 360))
	if stack == null:
		return

	var info := _label("BAKKAL 24/7 MART · REGISTER 01 LOG", 13, COLOR_MUTED)
	stack.add_child(info)

	_add_record_entry(stack, "BEST CAMPAIGN SCORE", "%06d" % _load_best_score(), COLOR_ACCENT_LIME, 16)
	_add_record_entry(stack, "ENDLESS BEST WAVE", "WAVE %02d" % _load_endless_best_wave(), COLOR_BASE_DARK, 16)
	_add_record_entry(stack, "ENDLESS BEST SCORE", "%06d" % _load_endless_best_score(), COLOR_BASE_DARK, 16)

	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.4)))

	var dir_lbl := _label("DIRECTIVE: KEEP AISLES PATROLLED UNTIL 07:00", 12, COLOR_MUTED)
	dir_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(dir_lbl)

	var barcode := _label("||| | |||| | ||| || |||| | |||| || |", 12, COLOR_MUTED)
	barcode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(barcode)

	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DOUBLE, COLOR_SURFACE_BORDER_LIGHT))

	var close := Button.new()
	close.text = "BACK TO SHIFT"
	close.custom_minimum_size.y = maxf(38.0, _mobile_touch_target(get_viewport().get_visible_rect().size))
	close.focus_mode = Control.FOCUS_ALL
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.add_theme_color_override("font_color", COLOR_BASE_DARK)
	close.add_theme_color_override("font_focus_color", COLOR_BASE_DARK)
	if display_font != null:
		close.add_theme_font_override("font", display_font)
	close.add_theme_stylebox_override("normal", _receipt_button_style(true, false, &"normal"))
	close.add_theme_stylebox_override("hover", _receipt_button_style(true, false, &"hover"))
	close.add_theme_stylebox_override("focus", _receipt_button_style(true, false, &"focus"))
	close.add_theme_stylebox_override("pressed", _receipt_button_style(true, false, &"pressed"))
	close.pressed.connect(func() -> void:
		BakkalAudio.play_sfx(&"ui_confirm")
		_close_modal()
	)
	stack.add_child(close)
	close.grab_focus.call_deferred()


func _add_record_entry(parent: Control, key: String, val: String, val_color: Color, val_size: int = 12) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var k_lbl := _label(key, 14, COLOR_BASE_DARK)
	row.add_child(k_lbl)

	var dl := DotLeader.new(Color(COLOR_MUTED, 0.35))
	row.add_child(dl)

	var v_lbl := _label(val, val_size, val_color)
	row.add_child(v_lbl)


func _show_credits() -> void:
	var stack := _open_modal("CREDITS", Vector2i(620, 470))
	if stack == null:
		return

	var heading := _label("THE PEOPLE AND TOOLS BEHIND THE SHIFT", 14, COLOR_MUTED)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)

	var columns: Control = VBoxContainer.new() if _is_portrait() else HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(columns)

	columns.add_child(_credit_category(
		"PEOPLE",
		"[center]Producer / Developer\n[b]Asrın Kılıç (dixtuel)[/b]\n\nIdea contributors\nkiyici + [b]I3aN.Ka![/b]\n\nTester: Temuchin[/center]",
		Vector2(270, 188)
	))
	columns.add_child(_credit_category(
		"PRODUCTION",
		"[center]Engine\n[b]Godot 4.7.2[/b]\n\nVisual generation\n[b]OpenAI Image 2.5[/b]\n\nDebug Team\nChatGPT Codex · Google Gemini[/center]",
		Vector2(270, 168)
	))

	var assets := _credit_category(
		"ASSETS & LICENSES",
		"[center]Project-authored code: [url=https://github.com/dixtuel/supermarket-the-night/blob/main/LICENSE][color=#38664b][u]MIT License[/u][/color][/url]   ·   Assets: [b]Kenney CC0 1.0[/b]\nOfficial Store: [url=https://dixtuel.itch.io/supermarket-the-night][color=#38664b][u]itch.io/supermarket-the-night[/u][/color][/url]\nFull asset record: [url=https://github.com/dixtuel/supermarket-the-night/blob/main/ATTRIBUTION.md][color=#38664b][u]ATTRIBUTION.md[/u][/color][/url][/center]",
		Vector2(0, 106)
	)
	stack.add_child(assets)

	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size.y = maxf(38.0, _mobile_touch_target(get_viewport().get_visible_rect().size))
	close.focus_mode = Control.FOCUS_ALL
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.add_theme_color_override("font_color", COLOR_BASE_DARK)
	close.add_theme_color_override("font_focus_color", COLOR_BASE_DARK)
	if display_font != null:
		close.add_theme_font_override("font", display_font)
	close.add_theme_stylebox_override("normal", _receipt_button_style(true, false, &"normal"))
	close.add_theme_stylebox_override("hover", _receipt_button_style(true, false, &"hover"))
	close.add_theme_stylebox_override("focus", _receipt_button_style(true, false, &"focus"))
	close.add_theme_stylebox_override("pressed", _receipt_button_style(true, false, &"pressed"))
	close.pressed.connect(func() -> void:
		BakkalAudio.play_sfx(&"ui_confirm")
		_close_modal()
	)
	stack.add_child(close)
	close.grab_focus.call_deferred()


func _credit_category(title_text: String, body_bbcode: String, minimum_size: Vector2) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = minimum_size
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("f8f5e9")
	card_style.border_color = COLOR_SURFACE_BORDER
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(0)
	card.add_theme_stylebox_override("panel", card_style)

	var margins := _margins(12)
	card.add_child(margins)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margins.add_child(content)
	var category := _label(title_text, 14, COLOR_SURFACE)
	category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(category)
	content.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, COLOR_SURFACE_BORDER))

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_color_override("default_color", COLOR_BASE_DARK)
	body.add_theme_font_size_override("normal_font_size", 14)
	body.add_theme_font_size_override("bold_font_size", 15)
	body.text = body_bbcode
	body.meta_clicked.connect(func(meta: Variant) -> void: OS.shell_open(String(meta)))
	content.add_child(body)
	return card


func _format_db(val: float) -> String:
	if val <= -39.0:
		return "MUTED"
	return "%d dB" % int(val)


func _volume_control(parent: VBoxContainer, label_text: String, initial_value: float) -> HSlider:
	var header_row := HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(header_row)

	var label := _label(label_text, 14, COLOR_BASE_DARK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(label)

	var value_label := _label(_format_db(initial_value), 14, COLOR_SURFACE)
	header_row.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = -40.0
	slider.max_value = 0.0
	slider.step = 1.0
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = maxf(22.0, _mobile_touch_target(get_viewport().get_visible_rect().size))
	slider.focus_mode = Control.FOCUS_ALL

	var track := StyleBoxFlat.new()
	track.bg_color = Color("d7d1bc")
	track.border_color = COLOR_SURFACE_BORDER
	track.set_border_width_all(1)
	track.set_corner_radius_all(3)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = COLOR_SURFACE
	fill.set_corner_radius_all(3)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)

	slider.value_changed.connect(func(val: float) -> void:
		value_label.text = _format_db(val)
	)

	parent.add_child(slider)
	return slider


# --- UI Helper & Styling Constructors ---

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", roundi(float(size) * _receipt_ui_scale()))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.10))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	if display_font != null:
		label.add_theme_font_override("font", display_font)
	return label


func _badge_label(text: String, bg_color: Color, text_color: Color, font_size: int = 8) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = text_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)

	var lbl := _label(text, font_size, text_color)
	panel.add_child(lbl)
	return panel


func _margins(amount: int) -> MarginContainer:
	var margins := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, amount)
	return margins


func _chassis_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SURFACE_DARK
	style.border_color = COLOR_SURFACE_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.shadow_color = COLOR_SHADOW
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 3)
	return style


func _receipt_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_RECEIPT_PAPER, 0.98)
	style.border_color = Color(COLOR_BASE_DARK, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.shadow_color = COLOR_SHADOW
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _receipt_button_style(is_primary: bool, is_danger: bool, state: StringName) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if state == &"pressed":
		style.bg_color = Color("d8e5d2") if not is_danger else Color("f0d6cc")
		style.border_color = COLOR_ACCENT_CORAL if is_danger else COLOR_SURFACE
		style.set_border_width_all(1)
	elif state in [&"hover", &"focus"]:
		style.bg_color = Color("fffdf4")
		style.border_color = COLOR_ACCENT_CORAL if is_danger else COLOR_SURFACE
		style.set_border_width_all(1)
		if state == &"focus":
			style.shadow_color = Color(COLOR_ACCENT_LIME, 0.75)
			style.shadow_size = 5
	else:
		style.bg_color = Color(COLOR_RECEIPT_PAPER.lightened(0.08), 0.86) if is_primary else Color(COLOR_RECEIPT_PAPER, 0.0)
		style.border_color = Color(COLOR_BASE_DARK, 0.18) if not is_primary else Color(COLOR_BASE_DARK, 0.58)
		style.set_border_width_all(0)
		style.border_width_left = 3 if is_primary else 0
		style.border_width_bottom = 1
	style.set_corner_radius_all(0)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _chip_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_SURFACE.r, COLOR_SURFACE.g, COLOR_SURFACE.b, 0.95)
	style.border_color = COLOR_SURFACE_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.shadow_color = COLOR_SHADOW
	style.shadow_size = 8
	return style


func _button_normal_style(is_primary: bool, is_danger: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if is_primary:
		style.bg_color = Color(0.12, 0.22, 0.20, 0.98)
		style.border_color = Color("557733")
		style.border_width_left = 3
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
	elif is_danger:
		style.bg_color = Color(0.14, 0.11, 0.13, 0.96)
		style.border_color = Color(0.32, 0.20, 0.22, 1.0)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.09, 0.15, 0.17, 0.96)
		style.border_color = COLOR_SURFACE_BORDER
		style.set_border_width_all(1)

	style.set_corner_radius_all(3)
	return style


func _button_hover_style(is_primary: bool, is_danger: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if is_primary:
		style.bg_color = Color(0.16, 0.30, 0.26, 1.0)
		style.border_color = COLOR_ACCENT_LIME
		style.border_width_left = 4
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
	elif is_danger:
		style.bg_color = Color(0.24, 0.15, 0.18, 1.0)
		style.border_color = COLOR_ACCENT_CORAL
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.14, 0.23, 0.26, 1.0)
		style.border_color = COLOR_SURFACE_BORDER_LIGHT
		style.set_border_width_all(1)

	style.set_corner_radius_all(3)
	return style


func _button_focus_style(is_primary: bool, is_danger: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if is_danger:
		style.bg_color = Color(0.26, 0.14, 0.17, 1.0)
		style.border_color = COLOR_ACCENT_CORAL
		style.shadow_color = Color(COLOR_ACCENT_CORAL, 0.35)
	else:
		style.bg_color = Color(0.15, 0.28, 0.25, 1.0)
		style.border_color = COLOR_ACCENT_LIME
		style.shadow_color = Color(COLOR_ACCENT_LIME, 0.35)

	style.border_width_left = 5
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.set_corner_radius_all(3)
	style.shadow_size = 6
	return style


func _button_pressed_style(is_danger: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BASE_DARK
	style.border_color = COLOR_ACCENT_CORAL if is_danger else COLOR_ACCENT_LIME
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style


# --- Record Loading Helpers (Preserved 1:1) ---

func _load_best_score() -> int:
	var config := ConfigFile.new()
	if config.load(RECORD_PATH) == OK:
		return int(config.get_value("records", "best_campaign_score", config.get_value("records", "best_score", 0)))
	return 0


func _load_endless_best_score() -> int:
	var config := ConfigFile.new()
	if config.load(RECORD_PATH) == OK:
		return int(config.get_value("records", "best_endless_score", 0))
	return 0


func _load_endless_best_wave() -> int:
	var config := ConfigFile.new()
	if config.load(RECORD_PATH) == OK:
		return int(config.get_value("records", "best_endless_wave", 0))
	return 0
