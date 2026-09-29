extends Control
class_name BakkalTitleScreen

const ARENA_PATH := "res://levels/arena/arena.tscn"
const TEST_ARENA_PATH := "res://levels/arena/test_arena.tscn"
const RECORD_PATH := "user://bakkal_records.cfg"
const CHARACTER_PREFERENCE_PATH := "user://character_preferences.cfg"
const CHARACTER_ROSTER := preload("res://data/character_roster.gd")
const DIFFICULTY_CATALOG := preload("res://data/difficulty_catalog.gd")
const TURKISH_FALLBACK_FONT: FontFile = preload("res://assets/fonts/DejaVuSans.ttf")

# Core Palette Tokens
const COLOR_BASE_DARK := Color("172421")     # Dark checkout green
const COLOR_SURFACE := Color("283a34")       # Deep aisle green
const COLOR_RECEIPT_PAPER := Color("e7dec9") # Thermal receipt paper
const COLOR_ACCENT_LIME := Color("b8c7a3")   # Sage shelf label
const COLOR_ACCENT_CORAL := Color("d96c4b")  # Marked-down produce label

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
var _last_character_label: Label
var _active_modal: Control
var _modal_return_focus: Control
var _buttons: Array[Button] = []
var _btn_focus_indicators: Dictionary = {}
var _selected_character_index: int = 0
var _pending_character_id: StringName = &"night_clerk"
var _selected_difficulty_level: int = 0
var _max_difficulty_unlocked: int = 0
var _selected_run_is_endless: bool = false
var _character_preview: TextureRect
var _character_name_label: Label
var _character_description_label: Label
var _character_stats_label: Label
var _character_start_weapon_icon: TextureRect
var _difficulty_name_label: Label
var _difficulty_description_label: Label
var _difficulty_effects_label: Label
var _difficulty_preview: TextureRect
var _difficulty_buttons: Array[Button] = []
var _difficulty_start_button: Button


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


class HangingShopSign extends Control:
	func _draw() -> void:
		var s := size
		var scale := minf(s.x / 700.0, s.y / 290.0)
		var board := Rect2(0.0, 18.0 * scale, s.x, s.y - 18.0 * scale)
		draw_rect(Rect2(board.position + Vector2(7, 9) * scale, board.size), Color(0.0, 0.0, 0.0, 0.72))
		# Two real hanging chains sit behind a pressed steel lip.
		for x_ratio in [0.15, 0.86]:
			var x: float = s.x * float(x_ratio)
			draw_line(Vector2(x, 0), Vector2(x, 30.0 * scale), Color("826c4c"), 7.0 * scale, true)
			draw_line(Vector2(x - 1.5 * scale, 0), Vector2(x - 1.5 * scale, 30.0 * scale), Color("d0b17b"), 1.5 * scale, true)
			for i in range(3):
				var cy := (7.0 + i * 8.0) * scale
				draw_arc(Vector2(x, cy), 5.0 * scale, 0.0, TAU, 16, Color("d1b47c"), 2.0 * scale, true)
		# Layered, chipped enamel and an inset olive-black sign face.
		draw_rect(board, Color("796648"))
		draw_rect(board.grow(-4.0 * scale), Color("c2a06b"))
		draw_rect(board.grow(-10.0 * scale), Color("172923"))
		draw_rect(board.grow(-16.0 * scale), Color("233831"))
		draw_rect(Rect2(board.position + Vector2(13, 12) * scale, Vector2(board.size.x - 26 * scale, 2 * scale)), Color(0.78, 0.69, 0.49, 0.38))
		# Old paint breaks around the rim; deterministic marks keep every launch consistent.
		for i in range(22):
			var x := fposmod(float(i * 73 + 17) * scale, maxf(board.size.x - 20 * scale, 1.0)) + 10 * scale
			var y := fposmod(float(i * 41 + 11) * scale, maxf(board.size.y - 24 * scale, 1.0)) + 12 * scale
			var length := (3.0 + float(i % 5) * 1.4) * scale
			draw_line(Vector2(x, y), Vector2(x + length, y + (1.0 if i % 2 == 0 else -1.0) * scale), Color(0.78, 0.68, 0.48, 0.16), 1.0 * scale, true)
		# Four brass washers with dark screw heads make the board read as hardware.
		for p in [Vector2(17, 17), Vector2(s.x - 17, 17), Vector2(17, s.y - 17), Vector2(s.x - 17, s.y - 17)]:
			draw_circle(p, 5.0 * scale, Color("b69a67"))
			draw_circle(p, 2.0 * scale, Color("463c2a"))
			draw_line(p + Vector2(-1.2, 0) * scale, p + Vector2(1.2, 0) * scale, Color("d9c18b"), 0.8 * scale)


class ReceiptPaper extends Control:
	func _draw() -> void:
		var s := size
		var scale := minf(s.x / 560.0, s.y / 470.0)
		var edge := PackedVector2Array([
			Vector2(5, 0), Vector2(s.x - 7, 0), Vector2(s.x - 2, 11), Vector2(s.x - 6, 24),
			Vector2(s.x - 2, 37), Vector2(s.x - 7, 51), Vector2(s.x - 3, s.y - 28),
			Vector2(s.x - 13, s.y - 17), Vector2(s.x - 23, s.y - 25), Vector2(s.x - 35, s.y - 14),
			Vector2(s.x - 48, s.y - 22), Vector2(s.x - 63, s.y - 13), Vector2(s.x - 78, s.y - 23),
			Vector2(s.x - 91, s.y - 14), Vector2(s.x - 108, s.y - 24), Vector2(s.x - 122, s.y - 15),
			Vector2(2, s.y - 26), Vector2(8, s.y - 45), Vector2(3, 63), Vector2(8, 42), Vector2(2, 24)
		])
		var shadow := PackedVector2Array()
		for p in edge:
			shadow.append(p + Vector2(5, 8) * scale)
		draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.7))
		draw_colored_polygon(edge, Color("d7c8a7"))
		draw_polyline(edge, Color("8b7654"), 2.0 * scale, true)
		draw_rect(Rect2(Vector2(13, 13) * scale, s - Vector2(26, 37) * scale), Color(0.92, 0.87, 0.75, 0.48), false, 1.0 * scale)
		# Fibres, folds, and old handling marks stay very low contrast behind the menu.
		for i in range(18):
			var x := fposmod(float(i * 47 + 9) * scale, maxf(s.x - 28 * scale, 1.0)) + 14 * scale
			var y := fposmod(float(i * 67 + 21) * scale, maxf(s.y - 46 * scale, 1.0)) + 12 * scale
			draw_line(Vector2(x, y), Vector2(x + (8 + i % 14) * scale, y + ((i % 3) - 1) * scale), Color(0.37, 0.29, 0.18, 0.12), 1.0 * scale, true)
		draw_line(Vector2(s.x * 0.04, s.y * 0.29), Vector2(s.x * 0.96, s.y * 0.29), Color(0.43, 0.34, 0.22, 0.20), 1.0 * scale, true)
		draw_line(Vector2(s.x * 0.04, s.y * 0.75), Vector2(s.x * 0.96, s.y * 0.75), Color(0.43, 0.34, 0.22, 0.15), 1.0 * scale, true)


class MenuGlyph extends Control:
	var kind: String = ""
	var tint := Color("26342b")

	func _draw() -> void:
		var c := size * 0.5
		var unit := minf(size.x, size.y) / 32.0
		match kind:
			"cart":
				draw_line(c + Vector2(-12, -9) * unit, c + Vector2(-8, -9) * unit, tint, 2.2 * unit, true)
				draw_line(c + Vector2(-8, -9) * unit, c + Vector2(-4, 4) * unit, tint, 2.2 * unit, true)
				draw_line(c + Vector2(-4, 4) * unit, c + Vector2(10, 4) * unit, tint, 2.2 * unit, true)
				draw_line(c + Vector2(-6, -5) * unit, c + Vector2(12, -5) * unit, tint, 2.2 * unit, true)
				draw_line(c + Vector2(12, -5) * unit, c + Vector2(9, 1) * unit, tint, 2.2 * unit, true)
				for x in [-1.0, 8.0]:
					draw_circle(c + Vector2(x, 9) * unit, 2.1 * unit, tint)
			"infinity":
				var font := ThemeDB.fallback_font
				if font != null:
					draw_string(font, c + Vector2(-13, 8) * unit, "∞", HORIZONTAL_ALIGNMENT_LEFT, 26 * unit, roundi(24 * unit), tint)
			"gear":
				for i in range(8):
					var angle := TAU * float(i) / 8.0
					var start := c + Vector2(cos(angle), sin(angle)) * 7.0 * unit
					var finish := c + Vector2(cos(angle), sin(angle)) * 12.0 * unit
					draw_line(start, finish, tint, 3.2 * unit, true)
				draw_circle(c, 7.0 * unit, tint)
				draw_circle(c, 2.4 * unit, Color("dfd3b8"))
			"door":
				draw_rect(Rect2(c + Vector2(-8, -12) * unit, Vector2(12, 24) * unit), tint, false, 2.0 * unit)
				draw_circle(c + Vector2(1, 0) * unit, 1.2 * unit, tint)
				draw_line(c + Vector2(2, 0) * unit, c + Vector2(13, 0) * unit, tint, 2.0 * unit, true)
				draw_line(c + Vector2(9, -4) * unit, c + Vector2(13, 0) * unit, tint, 2.0 * unit, true)
				draw_line(c + Vector2(9, 4) * unit, c + Vector2(13, 0) * unit, tint, 2.0 * unit, true)
			"start":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -7) * unit, c + Vector2(7, 0) * unit, c + Vector2(-4, 7) * unit]), tint)
			"menu":
				for i in range(3):
					var y := (float(i) - 1.0) * 7.0 * unit
					draw_line(c + Vector2(-11, y), c + Vector2(11, y), tint, 2.4 * unit, true)


class ClipboardClamp extends Control:
	func _draw() -> void:
		var middle := size.x * 0.5
		draw_rect(Rect2(0, size.y * 0.30, size.x, size.y * 0.62), Color("29332e"))
		draw_rect(Rect2(4, size.y * 0.37, size.x - 8, size.y * 0.46), Color("7c7a6c"))
		draw_rect(Rect2(7, size.y * 0.42, size.x - 14, size.y * 0.14), Color("b9b5a1"))
		draw_rect(Rect2(middle - size.x * 0.16, 0, size.x * 0.32, size.y * 0.54), Color("64675f"))
		draw_rect(Rect2(middle - size.x * 0.11, 3, size.x * 0.22, size.y * 0.38), Color("77786e"))
		draw_circle(Vector2(middle, size.y * 0.19), size.y * 0.10, Color("171b19"))
		draw_circle(Vector2(middle - 2, size.y * 0.16), size.y * 0.045, Color("a9a28e"))


func _ready() -> void:
	if display_font != null:
		display_font = display_font.duplicate() as FontFile
		var fallbacks: Array[Font] = display_font.fallbacks.duplicate()
		fallbacks.append(TURKISH_FALLBACK_FONT)
		display_font.fallbacks = fallbacks
	ThemeDB.fallback_font = TURKISH_FALLBACK_FONT
	BakkalAudio.play_music()
	_build()
	if I18n != null and I18n.has_signal("language_changed"):
		I18n.language_changed.connect(func(_l: String) -> void:
			_build_menu()
		)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_active_modal) and _active_modal.has_meta("is_character_select"):
		if event.is_action_pressed("ui_left"):
			_cycle_character(-1)
			get_viewport().set_input_as_handled()
			return
	if is_instance_valid(_active_modal) and _active_modal.has_meta("is_difficulty_select"):
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
			_cycle_difficulty(-1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
			_cycle_difficulty(1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_right"):
			_cycle_character(1)
			get_viewport().set_input_as_handled()
			return
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
	background.texture = load("res://assets/generated/rooms/market_lights_out.png")
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# 2. Restrained late-night atmospheric vignette (keeps store art prominent)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(COLOR_BASE_DARK.r, COLOR_BASE_DARK.g, COLOR_BASE_DARK.b, 0.20)
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
	clerk_shadow.anchor_left = 0.68
	clerk_shadow.anchor_right = 0.77
	clerk_shadow.anchor_top = 0.70
	clerk_shadow.anchor_bottom = 0.735
	if OS.has_feature("portmaster"):
		clerk_shadow.anchor_left -= 0.12
		clerk_shadow.anchor_right -= 0.12
	clerk_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	shadow_style.set_corner_radius_all(18)
	clerk_shadow.add_theme_stylebox_override("panel", shadow_style)
	add_child(clerk_shadow)

	_clerk = TextureRect.new()
	_clerk.texture = _character_portrait(_last_character_id())
	_clerk.anchor_left = 0.66
	_clerk.anchor_right = 0.79
	_clerk.anchor_top = 0.405
	_clerk.anchor_bottom = 0.745
	if OS.has_feature("portmaster"):
		_clerk.anchor_left -= 0.12
		_clerk.anchor_right -= 0.12
	_clerk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_clerk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_clerk.modulate = Color(1.0, 0.99, 0.96, 0.98)
	_clerk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clerk)

	var last_character_prefix := "LAST PLAYED · " if I18n.current_locale == "en" else "SON OYNANAN · "
	_last_character_label = _label(last_character_prefix + _character_display_name(_last_character_id()), 12, COLOR_RECEIPT_PAPER)
	_last_character_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_last_character_label.anchor_left = 0.63
	_last_character_label.anchor_right = 0.82
	_last_character_label.anchor_top = 0.35
	_last_character_label.anchor_bottom = 0.39
	_last_character_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if OS.has_feature("portmaster"):
		_last_character_label.anchor_left -= 0.12
		_last_character_label.anchor_right -= 0.12
	add_child(_last_character_label)

	# 4. Left-side store sign and receipt menu from the concept composition.
	_build_compact_menu()

	# 5. Minimal Footer
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
	var portmaster := OS.has_feature("portmaster")
	var inset := 10.0 * scale_factor if mobile else 26.0
	var usable_width := maxf(220.0, viewport_size.x - safe.x - safe.z - inset * 2.0)
	var desktop := not mobile and not portmaster
	var sign_width := minf(usable_width * (0.39 if desktop else (0.44 if mobile_landscape else 0.92)), 720.0 * scale_factor)
	var paper_width := minf(sign_width * 0.78, 560.0 * scale_factor)
	var sign_height := 320.0 * scale_factor if desktop else (88.0 * scale_factor if mobile_landscape else 158.0 * scale_factor)
	var left := safe.x + (viewport_size.x * 0.05 if desktop else inset)
	var top := safe.y + (viewport_size.y * 0.03 if desktop else inset)
	if portmaster:
		# The handheld's logical canvas is 960x720; leave the background readable
		# while keeping controls comfortably reachable from the device bezel.
		sign_width = minf(usable_width * 0.66, 510.0)
		paper_width = sign_width * 0.95
		sign_height = 154.0

	# The hanging shop sign and paper menu are two independent physical pieces.
	# Keeping them as siblings preserves the reference's clear silhouette and
	# prevents the receipt from growing to fill unused screen height.
	var sign := HangingShopSign.new()
	sign.anchor_left = 0.0
	sign.anchor_right = 0.0
	sign.anchor_top = 0.0
	sign.anchor_bottom = 0.0
	sign.offset_left = left
	sign.offset_top = top
	sign.offset_right = left + sign_width
	sign.offset_bottom = top + sign_height
	sign.custom_minimum_size = Vector2(sign_width, sign_height)
	add_child(sign)

	var sign_margins := _margins(roundi((20.0 if desktop else 12.0) * scale_factor))
	sign_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sign.add_child(sign_margins)
	var sign_center := VBoxContainer.new()
	sign_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sign_center.alignment = BoxContainer.ALIGNMENT_CENTER
	sign_margins.add_child(sign_center)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sign_center.add_child(header_row)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header)
	var title_font_size := 42 if desktop else (19 if mobile_landscape else 30)
	var brand_title := _label("SUPERMARKET:", title_font_size, COLOR_RECEIPT_PAPER)
	if display_font != null:
		brand_title.add_theme_font_override("font", display_font)
	brand_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	header.add_child(brand_title)
	var night_title := _label("THE NIGHT", title_font_size - 2, COLOR_ACCENT_CORAL)
	if display_font != null:
		night_title.add_theme_font_override("font", display_font)
	header.add_child(night_title)
	var receipt_subtitle := _label(
		"NIGHT SHIFT  /  CHOOSE YOUR ROUTE" if I18n.current_locale == "en" else "GECE VARDİYASI  /  ROTANI SEÇ",
		8 if mobile_landscape else 11,
		COLOR_RECEIPT_PAPER
	)
	header.add_child(receipt_subtitle)
	var sign_mark := HBoxContainer.new()
	sign_mark.add_theme_constant_override("separation", 12)
	for mark_kind in ["cart", "menu"]:
		var mark_button := Button.new()
		mark_button.custom_minimum_size = Vector2(48.0 * scale_factor, 52.0 * scale_factor)
		mark_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mark_button.focus_mode = Control.FOCUS_ALL
		mark_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		mark_button.add_theme_stylebox_override("hover", _stylebox(Color(1, 1, 1, 0.08), COLOR_ACCENT_LIME, 1))
		mark_button.add_theme_stylebox_override("focus", _stylebox(Color(1, 1, 1, 0.08), COLOR_ACCENT_LIME, 1))
		mark_button.pressed.connect(_start_run if mark_kind == "cart" else _show_auxiliary_menu)
		var mark := MenuGlyph.new()
		mark.kind = mark_kind
		mark.tint = COLOR_ACCENT_LIME
		mark.custom_minimum_size = Vector2(42.0 * scale_factor, 42.0 * scale_factor)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark_button.add_child(mark)
		sign_mark.add_child(mark_button)
	sign_mark.custom_minimum_size.x = 96.0 * scale_factor
	header_row.add_child(sign_mark)

	var paper := ReceiptPaper.new()
	paper.anchor_left = 0.0
	paper.anchor_right = 0.0
	paper.anchor_top = 0.0
	paper.anchor_bottom = 0.0
	paper.offset_left = left + (sign_width - paper_width) * 0.5
	paper.offset_top = top + sign_height + 6.0 * scale_factor
	var has_saved_run := RunSaveManager != null and RunSaveManager.has_saved_run()
	var resume_menu_extra := 68.0 * scale_factor if has_saved_run else 0.0
	var paper_height := (430.0 * scale_factor + resume_menu_extra) if desktop else (minf(viewport_size.y * 0.51, 470.0) + resume_menu_extra if portrait else (250.0 * scale_factor + resume_menu_extra))
	if portmaster:
		paper_height = 370.0 + (68.0 if has_saved_run else 0.0)
	if portrait:
		paper_height = minf(paper_height, maxf(220.0, viewport_size.y - top - sign_height - 24.0))
	paper.offset_right = paper.offset_left + paper_width
	paper.offset_bottom = paper.offset_top + paper_height
	paper.custom_minimum_size = Vector2(paper_width, paper_height)
	add_child(paper)
	var paper_margins := _margins(roundi((18.0 if desktop else 12.0) * scale_factor))
	paper_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if desktop:
		paper_margins.add_theme_constant_override("margin_top", 30)
		paper_margins.add_theme_constant_override("margin_bottom", 22)
	paper.add_child(paper_margins)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", roundi((5.0 if desktop else 3.0) * scale_factor))
	paper_margins.add_child(stack)
	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DOUBLE, Color(COLOR_BASE_DARK, 0.55)))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", roundi((3.0 if desktop else 2.0) * scale_factor))
	_menu = list
	stack.add_child(_menu)
	_build_menu()
	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_BASE_DARK, 0.42)))
	var day_number := posmod(Time.get_date_dict_from_system().day, 20) + 1
	var receipt_footer := _label(("NIGHT %02d  ·  STORE CLOSED" if I18n.current_locale == "en" else "GECE %02d  ·  MAĞAZA KAPALI") % day_number, 9 if desktop else 8, COLOR_SURFACE)
	receipt_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(receipt_footer)
	paper.queue_redraw()


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
			58,
			true
		)
		first_focus = false
		if not _is_mobile_landscape():
			_menu.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.3)))

	# The two game modes are the prominent receipt choices.
	_add_menu_button(
	("START SHIFT" if I18n.current_locale == "en" else "VARDIYAYA BAŞLA"),
		"▶",
		"",
		COLOR_ACCENT_LIME,
		_start_run,
		first_focus,
		false,
	76,
		true
	)
	first_focus = false

	_add_menu_button(
		I18n.t("TITLE_ENDLESS", "ENDLESS NIGHT"),
		"∞",
		"",
		COLOR_ACCENT_CORAL,
		_start_endless_run,
		false,
		false,
	70,
		true
	)

	if not _is_mobile_landscape():
		_menu.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.3)))

	_add_menu_button(I18n.t("TITLE_SETTINGS", "OPTIONS"), "⚙", "", COLOR_MUTED, _show_settings, false, false, 66, true)
	_add_menu_button(I18n.t("TITLE_QUIT", "QUIT"), "↗", "", COLOR_ACCENT_CORAL, _quit_game, false, true, 66, true)

	if not _is_mobile_landscape():
		_menu.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.3)))

	_setup_focus_navigation()


func _show_auxiliary_menu() -> void:
	var stack := _open_modal("STORE OFFICE", Vector2i(500, 340))
	if stack == null:
		return
	var options := [
		[I18n.t("TITLE_MANUAL", "HOW TO PLAY"), _show_controls],
		[I18n.t("TITLE_RECORDS", "RECORDS"), _show_records],
		[I18n.t("TITLE_CREDITS", "CREDITS"), _show_credits]
	]
	for option: Array in options:
		var button := _character_select_button(String(option[0]), _open_auxiliary_option.bind(Callable(option[1])), 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", _receipt_button_style(false, false, &"normal"))
		button.add_theme_stylebox_override("hover", _receipt_button_style(true, false, &"hover"))
		stack.add_child(button)
	var back := _character_select_button(I18n.t("MANUAL_CLOSE", "BACK TO SHIFT"), _close_modal, 44)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.add_theme_stylebox_override("normal", _receipt_button_style(true, false, &"normal"))
	stack.add_child(back)


func _open_auxiliary_option(callback: Callable) -> void:
	BakkalAudio.play_sfx(&"ui_confirm")
	callback.call()


func _add_menu_utility(parent: Control, label_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0.0, maxf(24.0, _mobile_touch_target(get_viewport().get_visible_rect().size) * 0.56))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", roundi(10.0 * _receipt_ui_scale()))
	button.add_theme_color_override("font_color", COLOR_SURFACE)
	button.add_theme_color_override("font_hover_color", COLOR_ACCENT_CORAL)
	button.add_theme_color_override("font_focus_color", COLOR_ACCENT_CORAL)
	button.add_theme_stylebox_override("normal", _receipt_button_style(false, false, &"normal"))
	button.add_theme_stylebox_override("hover", _receipt_button_style(false, false, &"hover"))
	button.add_theme_stylebox_override("focus", _receipt_button_style(false, false, &"focus"))
	button.pressed.connect(func() -> void:
		BakkalAudio.play_sfx(&"ui_confirm")
		callback.call()
	)
	parent.add_child(button)
	_buttons.append(button)


func _resume_saved_run() -> void:
	BakkalAudio.play_sfx(&"ui_confirm")
	var saved_run := RunSaveManager.get_saved_run_summary()
	var player_data: Dictionary = saved_run.get("player", {})
	var saved_character := StringName(String(saved_run.get("character_id", player_data.get("character_id", "night_clerk"))))
	get_tree().set_meta("supermarket_character_id", String(CHARACTER_ROSTER.get_character(saved_character).id))
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
		var receipt_text_color := COLOR_RECEIPT_PAPER if is_primary else COLOR_BASE_DARK
		button.add_theme_color_override("font_color", receipt_text_color)
		button.add_theme_color_override("font_hover_color", receipt_text_color)
		button.add_theme_color_override("font_pressed_color", receipt_text_color)
		button.add_theme_color_override("font_focus_color", receipt_text_color)
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
	code_lbl.text = "▶" if code == "▶" else ""
	code_lbl.add_theme_font_size_override("font_size", roundi((12.0 if mobile_landscape else 18.0) * scale_factor))
	code_lbl.add_theme_color_override("font_color", COLOR_RECEIPT_PAPER if is_primary else COLOR_SURFACE)
	code_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if display_font != null:
		code_lbl.add_theme_font_override("font", display_font)
	row.add_child(code_lbl)

	var main_lbl := Label.new()
	main_lbl.text = text
	var landscape_font_compaction := 0.85 if OS.has_feature("portmaster") else (0.50 if mobile_landscape else 1.0)
	main_lbl.add_theme_font_size_override("font_size", roundi(float(24 if is_primary else 22) * scale_factor * landscape_font_compaction))
	main_lbl.add_theme_color_override("font_color", COLOR_RECEIPT_PAPER if use_receipt_style and is_primary else (COLOR_BASE_DARK if use_receipt_style else COLOR_RECEIPT_PAPER))
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
		badge.add_theme_color_override("font_color", COLOR_RECEIPT_PAPER if use_receipt_style and is_primary else (COLOR_BASE_DARK if use_receipt_style else badge_color))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if display_font != null:
			badge.add_theme_font_override("font", display_font)
		row.add_child(badge)

	var glyph := MenuGlyph.new()
	glyph.kind = "cart" if code == "▶" else ("infinity" if code == "∞" else ("gear" if code == "⚙" else ("door" if code == "↗" else "start")))
	glyph.tint = COLOR_RECEIPT_PAPER if is_primary else COLOR_BASE_DARK
	glyph.custom_minimum_size = Vector2(36.0 * scale_factor, 36.0 * scale_factor)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)

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
	_show_character_select(false)


func _start_endless_run() -> void:
	_show_character_select(true)


func _show_character_select(is_endless: bool) -> void:
	_selected_run_is_endless = is_endless
	_selected_character_index = CHARACTER_ROSTER.get_index(_last_character_id())
	var title := "CHOOSE YOUR CHARACTER" if I18n.current_locale == "en" else "KARAKTERİNİ SEÇ"
	var stack := _open_modal(title, Vector2i(840, 740))
	_active_modal.set_meta("is_character_select", true)
	var mode_text := "ENDLESS NIGHT" if is_endless else "20-ROUND CAMPAIGN"
	stack.add_child(_label(mode_text, 15, COLOR_SURFACE))

	var character_row := HBoxContainer.new()
	character_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_row.add_theme_constant_override("separation", 14)
	stack.add_child(character_row)
	var previous := _character_select_button("←", func() -> void: _cycle_character(-1), 96)
	character_row.add_child(previous)
	_character_preview = TextureRect.new()
	_character_preview.custom_minimum_size = Vector2(340, 360)
	_character_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_character_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_character_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_character_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_character_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_row.add_child(_character_preview)
	var next := _character_select_button("→", func() -> void: _cycle_character(1), 96)
	character_row.add_child(next)

	_character_name_label = _label("", 28, COLOR_BASE_DARK)
	_character_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_character_name_label)
	_character_description_label = _label("", 17, COLOR_SURFACE)
	_character_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_character_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_character_description_label)
	var loadout := HBoxContainer.new()
	loadout.alignment = BoxContainer.ALIGNMENT_CENTER
	loadout.add_theme_constant_override("separation", 12)
	stack.add_child(loadout)
	_character_start_weapon_icon = TextureRect.new()
	_character_start_weapon_icon.custom_minimum_size = Vector2(56, 56)
	_character_start_weapon_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_character_start_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_character_start_weapon_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var weapon_icon_center := CenterContainer.new()
	weapon_icon_center.custom_minimum_size = Vector2(72, 72)
	weapon_icon_center.add_child(_character_start_weapon_icon)
	loadout.add_child(weapon_icon_center)
	_character_stats_label = _label("", 16, COLOR_BASE_DARK)
	_character_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loadout.add_child(_character_stats_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	stack.add_child(actions)
	var back := _character_select_button("BACK" if I18n.current_locale == "en" else "GERİ", _close_modal, 60)
	var begin := _character_select_button("CHOOSE DIFFICULTY" if I18n.current_locale == "en" else "ZORLUK SEÇ", _confirm_character_selection, 60)
	begin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(back)
	actions.add_child(begin)
	previous.focus_neighbor_top = previous.get_path()
	previous.focus_neighbor_bottom = begin.get_path()
	previous.focus_neighbor_right = next.get_path()
	next.focus_neighbor_left = previous.get_path()
	next.focus_neighbor_top = next.get_path()
	next.focus_neighbor_bottom = begin.get_path()
	back.focus_neighbor_top = previous.get_path()
	back.focus_neighbor_right = begin.get_path()
	begin.focus_neighbor_top = next.get_path()
	begin.focus_neighbor_left = back.get_path()
	begin.grab_focus.call_deferred()
	_refresh_character_selection()


func _character_select_button(text: String, callback: Callable, height: float) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(maxf(72.0, _mobile_touch_target(get_viewport().get_visible_rect().size)), maxf(height, _mobile_touch_target(get_viewport().get_visible_rect().size)))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var is_carousel_arrow := text in ["←", "→"]
	button.add_theme_font_size_override("font_size", roundi((30.0 if is_carousel_arrow else 15.0) * _receipt_ui_scale()))
	button.add_theme_color_override("font_color", COLOR_BASE_DARK)
	button.add_theme_color_override("font_hover_color", COLOR_ACCENT_CORAL.darkened(0.15))
	button.add_theme_color_override("font_focus_color", COLOR_ACCENT_CORAL.darkened(0.15))
	button.add_theme_color_override("font_pressed_color", COLOR_ACCENT_CORAL.darkened(0.15))
	button.add_theme_stylebox_override("normal", _receipt_button_style(false, false, &"normal"))
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	if display_font != null:
		var emphasized_font := FontVariation.new()
		emphasized_font.base_font = display_font
		emphasized_font.variation_embolden = 0.35
		button.add_theme_font_override("font_hover", emphasized_font)
		button.add_theme_font_override("font_focus", emphasized_font)
		button.add_theme_font_override("font_pressed", emphasized_font)
	button.pressed.connect(callback)
	return button


func _cycle_character(direction: int) -> void:
	var count := CHARACTER_ROSTER.CHARACTERS.size()
	if count <= 0:
		return
	_selected_character_index = posmod(_selected_character_index + direction, count)
	_refresh_character_selection()
	BakkalAudio.play_sfx(&"ui_confirm")


func _refresh_character_selection() -> void:
	if not is_instance_valid(_character_preview):
		return
	var definition: CharacterDefinition = CHARACTER_ROSTER.CHARACTERS[_selected_character_index]
	_character_preview.texture = _character_portrait(definition.id)
	var weapon_path := "res://data/weapons/%s.tres" % String(definition.starting_weapon_id)
	if ResourceLoader.exists(weapon_path):
		var weapon := load(weapon_path) as WeaponDefinition
		_character_start_weapon_icon.texture = weapon.sprite if weapon != null else null
	var english := I18n.current_locale == "en"
	_character_name_label.text = definition.display_name if english else definition.display_name_tr
	_character_description_label.text = definition.description if english else definition.description_tr
	var weapon_name := String(definition.starting_weapon_id).replace("_", " ").to_upper()
	if english:
		_character_stats_label.text = "HP %d  ·  DAMAGE %d%%  ·  ELEMENT %+d\nSTARTER: %s" % [definition.max_health, roundi((definition.damage_multiplier - 1.0) * 100.0), definition.elemental_damage, weapon_name]
	else:
		if definition.starting_weapon_id == &"milk_hose":
			weapon_name = "SÜT HORTUMU"
		elif definition.starting_weapon_id == &"can_launcher":
			weapon_name = "KONSERVE FIRLATICI"
		_character_stats_label.text = "CAN %d  ·  HASAR %d%%  ·  ELEMENT %+d\nBAŞLANGIÇ: %s" % [definition.max_health, roundi((definition.damage_multiplier - 1.0) * 100.0), definition.elemental_damage, weapon_name]


func _confirm_character_selection() -> void:
	var definition: CharacterDefinition = CHARACTER_ROSTER.CHARACTERS[_selected_character_index]
	_save_last_character_id(definition.id)
	_pending_character_id = definition.id
	_show_difficulty_select()


func _show_difficulty_select() -> void:
	_max_difficulty_unlocked = _load_max_difficulty_unlocked()
	_selected_difficulty_level = mini(_max_difficulty_unlocked, _selected_difficulty_level)
	var english := I18n.current_locale == "en"
	var title := "CHOOSE DIFFICULTY" if english else "ZORLUĞU SEÇ"
	var stack := _open_modal(title, Vector2i(1120, 560))
	_active_modal.set_meta("is_difficulty_select", true)
	var definition := CHARACTER_ROSTER.get_character(_pending_character_id)
	var context := _label("%s     /     %s" % [definition.display_name if english else definition.display_name_tr, "ENDLESS NIGHT" if _selected_run_is_endless else ("20-ROUND CAMPAIGN" if english else "20 DALGALIK KAMPANYA")], 14, COLOR_SURFACE)
	stack.add_child(context)
	var selector_scroll := ScrollContainer.new()
	selector_scroll.name = "DifficultySelectorScroll"
	selector_scroll.custom_minimum_size.y = 104.0
	selector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	selector_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selector_scroll.follow_focus = true
	stack.add_child(selector_scroll)
	var selector := HBoxContainer.new()
	selector.add_theme_constant_override("separation", 8)
	selector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selector_scroll.add_child(selector)
	_difficulty_buttons.clear()
	for level in range(DIFFICULTY_CATALOG.MAX_LEVEL + 1):
		var profile: Dictionary = DIFFICULTY_CATALOG.get_profile(level)
		var profile_name := String(profile.get("name" if english else "name_tr", ""))
		var locked := level > _max_difficulty_unlocked
		var tier_button := Button.new()
		tier_button.custom_minimum_size = Vector2(116.0, 92.0)
		tier_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_button.focus_mode = Control.FOCUS_ALL
		tier_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tier_button.text = "%02d\n%s\n%s" % [level, profile_name.to_upper(), ("LOCKED" if english else "KİLİTLİ") if locked else ("OPEN" if english else "AÇIK")]
		tier_button.add_theme_font_size_override("font_size", roundi(13.0 * _receipt_ui_scale()))
		tier_button.add_theme_color_override("font_color", COLOR_BASE_DARK)
		tier_button.add_theme_color_override("font_hover_color", COLOR_BASE_DARK)
		tier_button.add_theme_color_override("font_focus_color", COLOR_BASE_DARK)
		tier_button.add_theme_stylebox_override("normal", _receipt_button_style(false, false, &"normal"))
		tier_button.add_theme_stylebox_override("hover", _receipt_button_style(false, false, &"hover"))
		tier_button.add_theme_stylebox_override("focus", _receipt_button_style(false, false, &"focus"))
		tier_button.pressed.connect(_select_difficulty.bind(level))
		selector.add_child(tier_button)
		_difficulty_buttons.append(tier_button)

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 18)
	info_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(info_row)
	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(210, 160)
	preview_panel.add_theme_stylebox_override("panel", _stylebox(COLOR_SURFACE, COLOR_SURFACE_BORDER, 2))
	info_row.add_child(preview_panel)
	_difficulty_preview = TextureRect.new()
	_difficulty_preview.texture = load("res://assets/generated/rooms/market_lights_out.png") as Texture2D
	_difficulty_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_difficulty_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_difficulty_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_difficulty_preview.modulate = Color(0.78, 0.84, 0.78)
	preview_panel.add_child(_difficulty_preview)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 8)
	info_row.add_child(info)
	_difficulty_name_label = _label("", 24, COLOR_BASE_DARK)
	_difficulty_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(_difficulty_name_label)
	_difficulty_description_label = _label("", 16, COLOR_SURFACE)
	_difficulty_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_difficulty_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(_difficulty_description_label)
	_difficulty_effects_label = _label("", 16, COLOR_BASE_DARK)
	_difficulty_effects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_difficulty_effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_difficulty_effects_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	var back := _character_select_button("BACK" if english else "GERİ", _show_character_select.bind(_selected_run_is_endless), 60)
	_difficulty_start_button = _character_select_button("START SHIFT" if english else "VARDİYAYI BAŞLAT", _confirm_difficulty_selection, 60)
	_difficulty_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(back)
	actions.add_child(_difficulty_start_button)
	back.focus_neighbor_right = _difficulty_start_button.get_path()
	_difficulty_start_button.focus_neighbor_left = back.get_path()
	_difficulty_start_button.grab_focus.call_deferred()
	_refresh_difficulty_selection()


func _cycle_difficulty(direction: int) -> void:
	_selected_difficulty_level = posmod(_selected_difficulty_level + direction, DIFFICULTY_CATALOG.MAX_LEVEL + 1)
	_refresh_difficulty_selection()
	BakkalAudio.play_sfx(&"ui_confirm")


func _select_difficulty(level: int) -> void:
	_selected_difficulty_level = clampi(level, 0, DIFFICULTY_CATALOG.MAX_LEVEL)
	_refresh_difficulty_selection()
	BakkalAudio.play_sfx(&"ui_confirm")


func _refresh_difficulty_selection() -> void:
	if not is_instance_valid(_difficulty_name_label):
		return
	var profile: Dictionary = DIFFICULTY_CATALOG.get_profile(_selected_difficulty_level)
	var english := I18n.current_locale == "en"
	var locked := _selected_difficulty_level > _max_difficulty_unlocked
	var tier_text := "SHIFT %d" % _selected_difficulty_level if english else "VARDİYA %d" % _selected_difficulty_level
	var lock_text := "  ·  LOCKED" if english else "  ·  KİLİTLİ"
	_difficulty_name_label.text = "%s  ·  %s%s" % [tier_text, profile.get("name" if english else "name_tr", ""), lock_text if locked else ""]
	_difficulty_description_label.text = String(profile.get("description" if english else "description_tr", ""))
	var health_pct := roundi((float(profile.enemy_health) - 1.0) * 100.0)
	var damage_pct := roundi((float(profile.enemy_damage) - 1.0) * 100.0)
	var pressure := int(profile.pressure_waves)
	var enemies_line := "ENEMIES UNLOCKED: %d/5" % int(profile.new_enemy_tier) if english else "EK DÜŞMAN TÜRÜ: %d/5" % int(profile.new_enemy_tier)
	var pressure_line := "PRESSURE WAVES: none" if english else "BASKI DALGASI: yok"
	if pressure == 1:
		pressure_line = "CHALLENGE: one random wave at 11 or 12 · 40% horde / 60% elite\nHORDE: more enemies · material drop chance −35%" if english else "BASKI: 11 veya 12. dalgada rastgele · %40 sürü / %60 elit\nSÜRÜ: daha fazla düşman · malzeme düşme olasılığı −%35"
	elif pressure == 3:
		pressure_line = "CHALLENGE: one at 11–12, 14–15, 17–18 · first two: 40% horde / 60% elite · final: elite\nHORDE: more enemies · material drop chance −35%" if english else "BASKI: 11–12, 14–15, 17–18 aralığında birer dalga · ilk ikisi: %40 sürü / %60 elit · sonuncusu elit\nSÜRÜ: daha fazla düşman · malzeme düşme olasılığı −%35"
	var scaling_line := "ENEMY HP +%d%%  ·  ENEMY DAMAGE +%d%%" % [health_pct, damage_pct] if english else "DÜŞMAN CANI +%%%d  ·  DÜŞMAN HASARI +%%%d" % [health_pct, damage_pct]
	if bool(profile.double_boss):
		scaling_line += "\n" + ("FINAL WAVE: TWO BOSSES · 25% LESS HEALTH EACH" if english else "SON DALGA: İKİ BOSS · HER BİRİNİN CANI %25 AZ")
	var economy_line := "SHOP PRICES / PLAYER UPGRADES: unchanged" if english else "MAĞAZA FİYATI / OYUNCU GELİŞİMİ: değişmez"
	if bool(profile.get("environmental_hazards", false)):
		pressure_line += "\n" + ("NIGHTMARE: hazards + fog · enemy speed +10%" if english else "KÂBUS: çevresel atışlar + sis · düşman hızı +%10")
	_difficulty_effects_label.text = "%s\n%s\n%s\n%s" % [enemies_line, pressure_line, scaling_line, economy_line]
	if is_instance_valid(_difficulty_start_button):
		_difficulty_start_button.disabled = locked
		_difficulty_start_button.tooltip_text = "Complete Wave 20 at the previous difficulty to unlock this one." if locked and english else ("Önceki zorluğu açmak için önceki zorlukta 20. dalgayı tamamla." if locked else "")
	for index in range(_difficulty_buttons.size()):
		var button := _difficulty_buttons[index]
		var is_selected := index == _selected_difficulty_level
		var is_locked := index > _max_difficulty_unlocked
		var fill := COLOR_ACCENT_CORAL if is_selected else (Color("9c9887") if is_locked else Color("d2d3ae"))
		var edge := COLOR_ACCENT_CORAL.darkened(0.25) if is_selected else COLOR_SURFACE_BORDER
		var state_style := _stylebox(fill, edge, 2 if is_selected else 1)
		button.add_theme_stylebox_override("normal", state_style)
		button.add_theme_stylebox_override("hover", _stylebox(fill.lightened(0.08), edge, 2))
		button.add_theme_stylebox_override("focus", _stylebox(fill.lightened(0.08), edge, 2))
		var color := COLOR_RECEIPT_PAPER if is_selected else COLOR_BASE_DARK
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", color)
		button.add_theme_color_override("font_focus_color", color)
	for child: Node in _active_modal.find_children("", "Button", true, false):
		if child is Button and child.text in ["START SHIFT", "VARDİYAYI BAŞLAT"]:
			(child as Button).disabled = locked
			(child as Button).tooltip_text = "Complete Wave 20 at the previous difficulty to unlock this one." if locked and english else ("Önceki zorluğu açmak için önceki zorlukta 20. dalgayı tamamla." if locked else "")


func _confirm_difficulty_selection() -> void:
	if _selected_difficulty_level > _max_difficulty_unlocked:
		return
	get_tree().set_meta("supermarket_endless_mode", _selected_run_is_endless)
	get_tree().set_meta("supermarket_character_id", String(_pending_character_id))
	get_tree().set_meta("supermarket_difficulty_level", _selected_difficulty_level)
	BakkalAudio.play_sfx(&"ui_confirm")
	get_tree().change_scene_to_file(ARENA_PATH)


func _load_max_difficulty_unlocked() -> int:
	var config := ConfigFile.new()
	if config.load(RECORD_PATH) == OK:
		return clampi(int(config.get_value("progression", "max_difficulty_unlocked", 0)), 0, DIFFICULTY_CATALOG.MAX_LEVEL)
	return 0


func _last_character_id() -> StringName:
	var config := ConfigFile.new()
	if config.load(CHARACTER_PREFERENCE_PATH) == OK:
		var saved := StringName(String(config.get_value("character", "last_character_id", "night_clerk")))
		return CHARACTER_ROSTER.get_character(saved).id
	return CHARACTER_ROSTER.DEFAULT_CHARACTER_ID


func _save_last_character_id(character_id: StringName) -> void:
	var config := ConfigFile.new()
	config.load(CHARACTER_PREFERENCE_PATH)
	config.set_value("character", "last_character_id", String(character_id))
	var error := config.save(CHARACTER_PREFERENCE_PATH)
	if error != OK:
		push_warning("Could not save last selected character preference: %s" % error_string(error))


func _character_display_name(character_id: StringName) -> String:
	var definition: CharacterDefinition = CHARACTER_ROSTER.get_character(character_id)
	return String(definition.display_name if I18n.current_locale == "en" else definition.display_name_tr).to_upper()


func _character_portrait(character_id: StringName) -> Texture2D:
	var definition: CharacterDefinition = CHARACTER_ROSTER.get_character(character_id)
	var path := definition.portrait_path
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return load("res://assets/generated/actors/player_night_clerk.png") as Texture2D


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
	var mobile := _is_mobile_platform()
	var modal_size := Vector2(minf(min_size.x * scale_factor, available_size.x * 0.92), minf(min_size.y * scale_factor, available_size.y * 0.92))
	var safe_center := Vector2((safe.x - safe.z) / 2.0, (safe.y - safe.w) / 2.0)
	card.offset_left = safe_center.x - modal_size.x / 2.0
	card.offset_right = safe_center.x + modal_size.x / 2.0
	card.offset_top = safe_center.y - modal_size.y / 2.0
	card.offset_bottom = safe_center.y + modal_size.y / 2.0
	card.custom_minimum_size = modal_size
	var clipboard := PanelContainer.new()
	clipboard.anchor_left = 0.5
	clipboard.anchor_right = 0.5
	clipboard.anchor_top = 0.5
	clipboard.anchor_bottom = 0.5
	clipboard.offset_left = card.offset_left - 12.0 * scale_factor
	clipboard.offset_right = card.offset_right + 12.0 * scale_factor
	clipboard.offset_top = card.offset_top - 8.0 * scale_factor
	clipboard.offset_bottom = card.offset_bottom + 18.0 * scale_factor
	clipboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clipboard_style := StyleBoxFlat.new()
	clipboard_style.bg_color = COLOR_SURFACE
	clipboard_style.border_color = Color("80694a")
	clipboard_style.set_border_width_all(roundi(7.0 * scale_factor))
	clipboard_style.set_corner_radius_all(0)
	clipboard_style.shadow_color = Color(0.0, 0.0, 0.0, 0.78)
	clipboard_style.shadow_size = 20.0 * scale_factor
	clipboard_style.shadow_offset = Vector2(3.0, 8.0) * scale_factor
	clipboard.add_theme_stylebox_override("panel", clipboard_style)
	overlay.add_child(clipboard)
	var paper := ReceiptPaper.new()
	paper.anchor_left = card.anchor_left
	paper.anchor_right = card.anchor_right
	paper.anchor_top = card.anchor_top
	paper.anchor_bottom = card.anchor_bottom
	paper.offset_left = card.offset_left
	paper.offset_right = card.offset_right
	paper.offset_top = card.offset_top
	paper.offset_bottom = card.offset_bottom
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(paper)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	card_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	card_style.set_border_width_all(0)
	card_style.set_corner_radius_all(0)
	card.add_theme_stylebox_override("panel", card_style)
	overlay.add_child(card)
	var clamp := ClipboardClamp.new()
	clamp.anchor_left = 0.5
	clamp.anchor_right = 0.5
	clamp.anchor_top = 0.5
	clamp.anchor_bottom = 0.5
	clamp.offset_left = -105.0 * scale_factor
	clamp.offset_right = 105.0 * scale_factor
	clamp.offset_top = card.offset_top - 18.0 * scale_factor
	clamp.offset_bottom = card.offset_top + 32.0 * scale_factor
	clamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clamp.z_index = 2
	overlay.add_child(clamp)

	var margins := _margins(roundi(12.0 * scale_factor) if mobile else 18)
	margins.add_theme_constant_override("margin_top", roundi((44.0 if not mobile else 34.0) * scale_factor))
	var settings_scroll := mobile and (title_text.to_upper().contains("OPTIONS") or title_text.to_upper().contains("AYARLAR"))
	var selection_scroll := mobile and (title_text.to_upper().contains("CHARACTER") or title_text.to_upper().contains("KARAKTER") or title_text.to_upper().contains("DIFFICULTY") or title_text.to_upper().contains("ZORLUĞ"))
	if settings_scroll or selection_scroll:
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
	# Android may expose the panel's physical DPI while still presenting a
	# 1080p-or-higher logical viewport. Multiplying those scales without a cap
	# makes menu cards taller than the screen on dense devices. Keep touch
	# controls comfortably large while letting selection dialogs fit.
	return clampf(dpi / 160.0 * viewport_scale, 1.0, 1.5)


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
	var stack := _open_modal("HOW TO PLAY — TERMINAL GUIDE", Vector2i(760, 540))
	if stack == null:
		return

	var scroll := ScrollContainer.new()
	var mobile := _is_mobile_platform()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL if mobile else Control.SIZE_SHRINK_BEGIN
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	_add_controls_row(body, "MOVEMENT & AISLE NAVIGATION", "Move through the store and evade cart hazards.", "↕", "W A S D\n← ↑ ↓ →")
	_add_controls_row(body, "AUTOMATIC TOOLS", "Tools engage nearby targets. Position your reach to clear aisles.", "✦", "AUTO")
	_add_controls_row(body, "STOCK TOKENS & XP", "Collect tokens and XP for upgrades between rounds.", "¤", "PICK UP")
	_add_controls_row(body, "SHIFT MODES", "Choose the 20-round campaign or Endless Night.", "☾", "ROUTE")
	_add_controls_row(body, "PAUSE TERMINAL", "Pause the shift at any time.", "Ⅱ", "ESC")

	stack.add_child(ReceiptRule.new(ReceiptRule.RuleType.DASHED, Color(COLOR_MUTED, 0.4)))
	var close_area := CenterContainer.new()
	close_area.size_flags_vertical = Control.SIZE_EXPAND_FILL

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
	if mobile:
		stack.add_child(close_btn)
	else:
		close_area.add_child(close_btn)
		stack.add_child(close_area)
	close_btn.grab_focus.call_deferred()


func _add_controls_row(parent: Control, heading: String, description: String, symbol: String, key_text: String) -> void:
	var row := PanelContainer.new()
	row.custom_minimum_size.y = 62.0 * _receipt_ui_scale()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", _stylebox(Color("e8dfc3"), Color("aa9978"), 1))
	parent.add_child(row)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	row.add_child(_margins(8))
	row.get_child(0).add_child(layout)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(48, 44)
	badge.add_theme_stylebox_override("panel", _stylebox(COLOR_BASE_DARK, Color("7c755f"), 1))
	var glyph := _label(symbol, 25, COLOR_RECEIPT_PAPER)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(glyph)
	layout.add_child(badge)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_child(_label(heading, 13, COLOR_BASE_DARK))
	var detail := _label(description, 13, COLOR_SURFACE)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(detail)
	layout.add_child(copy)
	var key_panel := PanelContainer.new()
	key_panel.custom_minimum_size = Vector2(104, 42)
	key_panel.add_theme_stylebox_override("panel", _stylebox(Color("f3eedb"), Color("817960"), 1))
	var key := _label(key_text, 12, COLOR_BASE_DARK)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_panel.add_child(key)
	layout.add_child(key_panel)


func _show_settings() -> void:
	var stack := _open_modal(I18n.t("SETTINGS_TITLE", "OPTIONS — SOUND, DISPLAY & LANGUAGE"), Vector2i(760, 600))
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
	_style_setting_choice(tr_btn, tr_btn.disabled)
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
	_style_setting_choice(en_btn, en_btn.disabled)
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
			_style_setting_choice(r_btn, r_btn.disabled)
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
			_style_setting_choice(m_btn, m_btn.disabled)
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

	if not OS.has_feature("portmaster") and not _is_native_mobile_platform():
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
	var stack := _open_modal("SHIFT AUDIT — PERFORMANCE RECORDS", Vector2i(760, 460))
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
	var stack := _open_modal("CREDITS", Vector2i(840, 680))
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


func _stylebox(fill: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(0)
	return style


func _receipt_button_style(is_primary: bool, is_danger: bool, state: StringName) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if state == &"pressed":
		style.bg_color = Color("d8e5d2") if not is_danger else Color("f0d6cc")
		style.border_color = COLOR_ACCENT_CORAL if is_danger else COLOR_SURFACE
		style.set_border_width_all(1)
	elif state in [&"hover", &"focus"]:
		style.bg_color = COLOR_ACCENT_CORAL.lightened(0.1) if is_primary else Color("fffdf4")
		style.border_color = COLOR_ACCENT_CORAL if is_danger else COLOR_SURFACE
		style.set_border_width_all(1)
		if state == &"focus":
			style.shadow_color = Color(COLOR_ACCENT_LIME, 0.75)
			style.shadow_size = 5
	else:
		style.bg_color = COLOR_ACCENT_CORAL if is_primary else Color(COLOR_RECEIPT_PAPER, 0.0)
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


func _style_setting_choice(button: Button, selected: bool) -> void:
	var fill := COLOR_ACCENT_CORAL if selected else COLOR_ACCENT_LIME
	var ink := COLOR_RECEIPT_PAPER if selected else COLOR_BASE_DARK
	button.add_theme_stylebox_override("normal", _stylebox(fill, COLOR_SURFACE, 1 if selected else 1))
	button.add_theme_stylebox_override("hover", _stylebox(fill.lightened(0.08), COLOR_ACCENT_CORAL, 2))
	button.add_theme_stylebox_override("focus", _stylebox(fill.lightened(0.08), COLOR_ACCENT_CORAL, 2))
	button.add_theme_stylebox_override("pressed", _stylebox(COLOR_RECEIPT_PAPER, COLOR_SURFACE, 2))
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_font_size_override("font_size", roundi(15.0 * _receipt_ui_scale()))


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
		style.bg_color = COLOR_ACCENT_CORAL
		style.border_color = COLOR_BASE_DARK
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
		style.bg_color = COLOR_ACCENT_CORAL.lightened(0.1)
		style.border_color = COLOR_RECEIPT_PAPER
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
