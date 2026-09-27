extends Control
class_name BakkalTitleScreen

const ARENA_PATH := "res://levels/arena/arena.tscn"
const TEST_ARENA_PATH := "res://levels/arena/test_arena.tscn"
const RECORD_PATH := "user://bakkal_records.cfg"

# Core Palette Tokens
const COLOR_BASE_DARK := Color("101820")     # Midnight / Deep Charcoal Ink
const COLOR_SURFACE := Color("1A2B30")       # Deep Petrol Slate / Register Chassis
const COLOR_RECEIPT_PAPER := Color("F1E7CE") # Thermal Receipt Cream / Primary Ink
const COLOR_ACCENT_LIME := Color("D4E36D")   # Fluorescent Discount Sticker / Neon Lime / Focus Ring
const COLOR_ACCENT_CORAL := Color("EE806D")  # Price Slash / Alert Coral / Secondary Accent

# Supporting Tonal Tokens
const COLOR_SURFACE_DARK := Color(0.07, 0.11, 0.14, 0.96)
const COLOR_SURFACE_BORDER := Color(0.18, 0.28, 0.32, 1.0)
const COLOR_SURFACE_BORDER_LIGHT := Color(0.24, 0.37, 0.42, 1.0)
const COLOR_MUTED := Color(0.55, 0.65, 0.67, 1.0)
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.70)

# Backward-Compatible Aliases
const INK := COLOR_BASE_DARK
const GOLD := COLOR_ACCENT_LIME
const CREAM := COLOR_RECEIPT_PAPER
const MUTED := COLOR_MUTED
const PANEL := COLOR_SURFACE_DARK

@export var display_font: FontFile

var _menu: VBoxContainer
var _clerk: TextureRect
var _active_modal: Control
var _last_focused_control: Control
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


func _build() -> void:
	# 1. Full-store interior background
	var background := TextureRect.new()
	background.texture = load("res://assets/generated/rooms/market_tidy_lights_on.png")
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
	var card := PanelContainer.new()
	card.offset_left = 100.0
	card.offset_top = 130.0
	card.offset_right = 560.0
	card.offset_bottom = 920.0
	card.custom_minimum_size = Vector2(460, 790)
	card.add_theme_stylebox_override("panel", _chassis_panel_style())
	add_child(card)

	var margins := _margins(18)
	card.add_child(margins)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margins.add_child(stack)

	# Brand & Terminal Identification
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	stack.add_child(status_row)

	var reg_tag := _badge_label("REG 01", COLOR_SURFACE, COLOR_ACCENT_LIME, 12)
	status_row.add_child(reg_tag)

	var shift_tag := _badge_label("NIGHT SHIFT", COLOR_SURFACE, COLOR_RECEIPT_PAPER, 12)
	status_row.add_child(shift_tag)

	var spacer_s := Control.new()
	spacer_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(spacer_s)

	var online_tag := _label("● ON DUTY", 12, COLOR_ACCENT_LIME)
	status_row.add_child(online_tag)

	var title_lbl := _label("SUPERMARKET", 30, COLOR_RECEIPT_PAPER)
	title_lbl.add_theme_constant_override("line_spacing", -3)
	stack.add_child(title_lbl)

	var subtitle_row := HBoxContainer.new()
	subtitle_row.add_theme_constant_override("separation", 8)
	stack.add_child(subtitle_row)

	var sub_lbl := _label("THE NIGHT", 20, COLOR_ACCENT_CORAL)
	subtitle_row.add_child(sub_lbl)

	var dot_lbl := _label("·", 16, COLOR_MUTED)
	subtitle_row.add_child(dot_lbl)

	var genre_lbl := _label("AISLE SURVIVAL", 13, COLOR_MUTED)
	genre_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_row.add_child(genre_lbl)

	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DOUBLE, COLOR_SURFACE_BORDER_LIGHT))

	# Action Menu
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 6)
	_menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_menu)
	_build_menu()

	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DOUBLE, COLOR_SURFACE_BORDER_LIGHT))

	var nav_tip := _label("[WASD / ARROWS] NAVIGATE  ·  [ENTER] SELECT", 11, COLOR_MUTED)
	nav_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(nav_tip)


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
		var wave_num: int = int(summary.get("round_number", 1))
		var cont_text := I18n.t("TITLE_CONTINUE", "VARDİYAYA DEVAM ET (Dalga %02d)") % wave_num
		_add_menu_button(
			cont_text,
			"►",
			"RESUME",
			COLOR_ACCENT_LIME,
			_resume_saved_run,
			first_focus,
			false,
			50
		)
		first_focus = false
		_menu.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.3)))

	# 1. Primary Action: 20-Round Campaign
	_add_menu_button(
		I18n.t("TITLE_CAMPAIGN", "20-ROUND CAMPAIGN"),
		"01",
		"PRIMARY",
		COLOR_ACCENT_LIME,
		_start_run,
		first_focus,
		false,
		48
	)
	first_focus = false

	# 2. Endless Night Mode
	_add_menu_button(
		I18n.t("TITLE_ENDLESS", "ENDLESS NIGHT"),
		"02",
		"SURVIVAL",
		COLOR_ACCENT_CORAL,
		_start_endless_run,
		false,
		false,
		44
	)

	_menu.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.3)))

	# 3. Subpage Actions
	_add_menu_button(I18n.t("TITLE_MANUAL", "HOW TO PLAY"), "03", "GUIDE", COLOR_MUTED, _show_controls, false, false, 42)
	_add_menu_button(I18n.t("TITLE_SETTINGS", "OPTIONS"), "04", "CONFIG", COLOR_MUTED, _show_settings, false, false, 42)
	_add_menu_button(I18n.t("TITLE_RECORDS", "RECORDS"), "05", "AUDIT", COLOR_MUTED, _show_records, false, false, 42)
	_add_menu_button(I18n.t("TITLE_CREDITS", "CREDITS"), "06", "INFO", COLOR_MUTED, _show_credits, false, false, 42)

	_menu.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.3)))

	# 4. Quit Action
	_add_menu_button(I18n.t("TITLE_QUIT", "QUIT"), "ESC", "EXIT", COLOR_ACCENT_CORAL, _quit_game, false, true, 42)

	_setup_focus_navigation()


func _resume_saved_run() -> void:
	BakkalAudio.play_sfx(&"ui_confirm")
	RunSaveManager.set_meta("should_resume", true)
	get_tree().change_scene_to_file("res://levels/arena/arena.tscn")


func _build_concise_status() -> void:
	# Compact score/mode status chip in top right
	var chip := PanelContainer.new()
	chip.anchor_left = 1.0
	chip.anchor_right = 1.0
	chip.offset_left = -340.0
	chip.offset_top = 40.0
	chip.offset_right = -60.0
	chip.offset_bottom = 120.0
	chip.custom_minimum_size = Vector2(280, 80)
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
	var footer := HBoxContainer.new()
	footer.anchor_left = 0.04
	footer.anchor_right = 0.96
	footer.anchor_top = 0.95
	footer.anchor_bottom = 0.985
	add_child(footer)

	var left_lbl := _label("SUPERMARKET: THE NIGHT  ·  NIGHT SHIFT", 11, COLOR_MUTED)
	footer.add_child(left_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	var right_lbl := _label("KEEP AISLES CLEAR UNTIL MORNING", 11, Color(COLOR_ACCENT_LIME, 0.75))
	footer.add_child(right_lbl)


func _setup_focus_navigation() -> void:
	if _buttons.is_empty():
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
	height: int = 30
) -> void:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(0, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	button.add_theme_stylebox_override("normal", _button_normal_style(is_primary, is_danger))
	button.add_theme_stylebox_override("hover", _button_hover_style(is_primary, is_danger))
	button.add_theme_stylebox_override("focus", _button_focus_style(is_primary, is_danger))
	button.add_theme_stylebox_override("pressed", _button_pressed_style(is_danger))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var focus_cursor := Label.new()
	focus_cursor.text = "▶"
	focus_cursor.add_theme_font_size_override("font_size", 13)
	focus_cursor.add_theme_color_override("font_color", COLOR_ACCENT_CORAL if is_danger else COLOR_ACCENT_LIME)
	focus_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_cursor.visible = false
	row.add_child(focus_cursor)
	_btn_focus_indicators[button] = focus_cursor

	var code_lbl := Label.new()
	code_lbl.text = "[%s]" % code
	code_lbl.add_theme_font_size_override("font_size", 12)
	code_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	code_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if display_font != null:
		code_lbl.add_theme_font_override("font", display_font)
	row.add_child(code_lbl)

	var main_lbl := Label.new()
	main_lbl.text = text
	main_lbl.add_theme_font_size_override("font_size", 17 if is_primary else 16)
	main_lbl.add_theme_color_override("font_color", COLOR_RECEIPT_PAPER)
	main_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if display_font != null:
		main_lbl.add_theme_font_override("font", display_font)
	row.add_child(main_lbl)

	if badge_text != "":
		var badge := Label.new()
		badge.text = badge_text
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", badge_color)
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
	_close_modal()
	_last_focused_control = get_viewport().gui_get_focus_owner()

	var overlay := Control.new()
	overlay.name = "ModalOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
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
	card.offset_left = -min_size.x / 2.0
	card.offset_right = min_size.x / 2.0
	card.offset_top = -min_size.y / 2.0
	card.offset_bottom = min_size.y / 2.0
	card.custom_minimum_size = Vector2(min_size)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COLOR_SURFACE
	card_style.border_color = COLOR_ACCENT_LIME
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(6)
	card_style.shadow_color = COLOR_SHADOW
	card_style.shadow_size = 18
	card.add_theme_stylebox_override("panel", card_style)
	overlay.add_child(card)

	var margins := _margins(18)
	card.add_child(margins)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margins.add_child(stack)

	var title_lbl := _label(title_text, 20, COLOR_ACCENT_LIME)
	stack.add_child(title_lbl)

	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DOUBLE, COLOR_SURFACE_BORDER_LIGHT))

	return stack


func _close_modal() -> void:
	if is_instance_valid(_active_modal):
		_active_modal.queue_free()
		_active_modal = null
	if is_instance_valid(_last_focused_control):
		_last_focused_control.grab_focus.call_deferred()


func _add_modal_section(parent: VBoxContainer, sec_title: String, description: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)

	var t_lbl := _label(sec_title, 14, COLOR_ACCENT_LIME)
	box.add_child(t_lbl)

	var d_lbl := Label.new()
	d_lbl.text = description
	d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_lbl.add_theme_font_size_override("font_size", 14)
	d_lbl.add_theme_color_override("font_color", COLOR_RECEIPT_PAPER)
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
	close_btn.custom_minimum_size.y = 38
	close_btn.focus_mode = Control.FOCUS_ALL
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_color_override("font_color", COLOR_RECEIPT_PAPER)
	close_btn.add_theme_color_override("font_focus_color", COLOR_ACCENT_LIME)
	if display_font != null:
		close_btn.add_theme_font_override("font", display_font)
	close_btn.add_theme_stylebox_override("normal", _button_normal_style(true, false))
	close_btn.add_theme_stylebox_override("hover", _button_hover_style(true, false))
	close_btn.add_theme_stylebox_override("focus", _button_focus_style(true, false))
	close_btn.add_theme_stylebox_override("pressed", _button_pressed_style(false))
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
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 12)
	stack.add_child(lang_row)

	var lang_title := _label(I18n.t("SETTINGS_LANGUAGE", "DİL / LANGUAGE"), 11, COLOR_ACCENT_LIME)
	lang_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(lang_title)

	var tr_btn := Button.new()
	tr_btn.text = "TÜRKÇE"
	tr_btn.custom_minimum_size = Vector2(100, 36)
	tr_btn.disabled = (I18n.current_locale == "tr")
	tr_btn.focus_mode = Control.FOCUS_ALL
	tr_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tr_btn.pressed.connect(func() -> void:
		I18n.set_language("tr")
		BakkalAudio.play_sfx(&"ui_confirm")
		_close_modal()
		_build_menu()
		_show_settings()
	)
	lang_row.add_child(tr_btn)

	var en_btn := Button.new()
	en_btn.text = "ENGLISH"
	en_btn.custom_minimum_size = Vector2(100, 36)
	en_btn.disabled = (I18n.current_locale == "en")
	en_btn.focus_mode = Control.FOCUS_ALL
	en_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	en_btn.pressed.connect(func() -> void:
		I18n.set_language("en")
		BakkalAudio.play_sfx(&"ui_confirm")
		_close_modal()
		_build_menu()
		_show_settings()
	)
	lang_row.add_child(en_btn)

	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.4)))

	# 2. Resolution selection
	var res_label := _label(I18n.t("SETTINGS_RESOLUTION", "ÇÖZÜNÜRLÜK"), 11, COLOR_ACCENT_LIME)
	stack.add_child(res_label)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 8)
	stack.add_child(res_row)

	var resolutions := ["1920x1080", "1600x900", "1366x768", "1280x720"]
	for r_idx: int in range(resolutions.size()):
		var r_btn := Button.new()
		r_btn.text = resolutions[r_idx]
		r_btn.custom_minimum_size = Vector2(110, 36)
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
		res_row.add_child(r_btn)

	# 3. Window Mode selection
	var mode_label := _label(I18n.t("SETTINGS_WINDOW_MODE", "EKRAN MODU"), 11, COLOR_ACCENT_LIME)
	stack.add_child(mode_label)

	var mode_row := HBoxContainer.new()
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
		m_btn.custom_minimum_size = Vector2(140, 36)
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
		mode_row.add_child(m_btn)

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
	done.custom_minimum_size.y = 44
	done.focus_mode = Control.FOCUS_ALL
	done.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	done.add_theme_color_override("font_color", COLOR_RECEIPT_PAPER)
	done.add_theme_color_override("font_focus_color", COLOR_ACCENT_LIME)
	if display_font != null:
		done.add_theme_font_override("font", display_font)
	done.add_theme_stylebox_override("normal", _button_normal_style(true, false))
	done.add_theme_stylebox_override("hover", _button_hover_style(true, false))
	done.add_theme_stylebox_override("focus", _button_focus_style(true, false))
	done.add_theme_stylebox_override("pressed", _button_pressed_style(false))
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

	var info := _label("BAKKAL 24/7 MART · REGISTER 01 LOG", 9, COLOR_MUTED)
	stack.add_child(info)

	_add_record_entry(stack, "BEST CAMPAIGN SCORE", "%06d" % _load_best_score(), COLOR_ACCENT_LIME, 16)
	_add_record_entry(stack, "ENDLESS BEST WAVE", "WAVE %02d" % _load_endless_best_wave(), COLOR_RECEIPT_PAPER, 13)
	_add_record_entry(stack, "ENDLESS BEST SCORE", "%06d" % _load_endless_best_score(), COLOR_RECEIPT_PAPER, 13)

	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.4)))

	var dir_lbl := _label("DIRECTIVE: KEEP AISLES PATROLLED UNTIL 07:00", 9, COLOR_MUTED)
	dir_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(dir_lbl)

	var barcode := _label("||| | |||| | ||| || |||| | |||| || |", 10, COLOR_MUTED)
	barcode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(barcode)

	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DOUBLE, COLOR_SURFACE_BORDER_LIGHT))

	var close := Button.new()
	close.text = "BACK TO SHIFT"
	close.custom_minimum_size.y = 38
	close.focus_mode = Control.FOCUS_ALL
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.add_theme_color_override("font_color", COLOR_RECEIPT_PAPER)
	close.add_theme_color_override("font_focus_color", COLOR_ACCENT_LIME)
	if display_font != null:
		close.add_theme_font_override("font", display_font)
	close.add_theme_stylebox_override("normal", _button_normal_style(true, false))
	close.add_theme_stylebox_override("hover", _button_hover_style(true, false))
	close.add_theme_stylebox_override("focus", _button_focus_style(true, false))
	close.add_theme_stylebox_override("pressed", _button_pressed_style(false))
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

	var k_lbl := _label(key, 10, COLOR_RECEIPT_PAPER)
	row.add_child(k_lbl)

	var dl := DotLeader.new(Color(COLOR_MUTED, 0.35))
	row.add_child(dl)

	var v_lbl := _label(val, val_size, val_color)
	row.add_child(v_lbl)


func _show_credits() -> void:
	var stack := _open_modal("CREDITS", Vector2i(620, 470))
	if stack == null:
		return

	var heading := _label("THE PEOPLE AND TOOLS BEHIND THE SHIFT", 11, COLOR_MUTED)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(columns)

	columns.add_child(_credit_category(
		"PEOPLE",
		"[center]Producer / Developer\n[b]Asrın Kılıç (dixtuel)[/b]\n\nIdea contributors\nkiyici + [b]I3aN.Ka![/b][/center]",
		Vector2(270, 168)
	))
	columns.add_child(_credit_category(
		"PRODUCTION",
		"[center]Engine\n[b]Godot 4.7.2[/b]\n\nVisual generation\n[b]OpenAI Image 2.5[/b]\n\nDebug Team\nChatGPT Codex · Google Gemini[/center]",
		Vector2(270, 168)
	))

	var assets := _credit_category(
		"ASSETS & LICENSES",
		"[center]Project-authored code: [url=https://github.com/dixtuel/supermarket-the-night/blob/main/LICENSE][color=#a3e635][u]MIT License[/u][/color][/url]   ·   Assets: [b]Kenney CC0 1.0[/b]\nOfficial Store: [url=https://dixtuel.itch.io/supermarket-the-night][color=#a3e635][u]itch.io/supermarket-the-night[/u][/color][/url]\nFull asset record: [url=https://github.com/dixtuel/supermarket-the-night/blob/main/ATTRIBUTION.md][color=#a3e635][u]ATTRIBUTION.md[/u][/color][/url][/center]",
		Vector2(0, 106)
	)
	stack.add_child(assets)

	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size.y = 38
	close.focus_mode = Control.FOCUS_ALL
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.add_theme_color_override("font_color", COLOR_RECEIPT_PAPER)
	close.add_theme_color_override("font_focus_color", COLOR_ACCENT_LIME)
	if display_font != null:
		close.add_theme_font_override("font", display_font)
	close.add_theme_stylebox_override("normal", _button_normal_style(false, false))
	close.add_theme_stylebox_override("hover", _button_hover_style(false, false))
	close.add_theme_stylebox_override("focus", _button_focus_style(false, false))
	close.add_theme_stylebox_override("pressed", _button_pressed_style(false))
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
	card_style.bg_color = COLOR_SURFACE_DARK
	card_style.border_color = COLOR_SURFACE_BORDER_LIGHT
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", card_style)

	var margins := _margins(12)
	card.add_child(margins)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margins.add_child(content)
	var category := _label(title_text, 11, COLOR_ACCENT_LIME)
	category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(category)
	content.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, COLOR_SURFACE_BORDER_LIGHT))

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_color_override("default_color", COLOR_RECEIPT_PAPER)
	body.add_theme_font_size_override("normal_font_size", 11)
	body.add_theme_font_size_override("bold_font_size", 12)
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

	var label := _label(label_text, 9, COLOR_RECEIPT_PAPER)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(label)

	var value_label := _label(_format_db(initial_value), 9, COLOR_ACCENT_LIME)
	header_row.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = -40.0
	slider.max_value = 0.0
	slider.step = 1.0
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 22
	slider.focus_mode = Control.FOCUS_ALL

	var track := StyleBoxFlat.new()
	track.bg_color = COLOR_BASE_DARK
	track.border_color = COLOR_SURFACE_BORDER
	track.set_border_width_all(1)
	track.set_corner_radius_all(3)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = COLOR_ACCENT_LIME
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
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
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
