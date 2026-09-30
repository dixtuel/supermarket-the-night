extends VBoxContainer
class_name SharedSettingsPanel

signal close_requested
signal language_changed
signal display_changed

const INK := Color("172421")
const PAPER := Color("f8f1df")
const PAPER_EDGE := Color("886a50")
const TEAL := Color("6da4aa")
const MUTED := Color("53645b")
const CORAL := Color("d96c4b")

var display_font: Font
var in_game_context := false


func configure(for_game: bool, font: Font) -> void:
	in_game_context = for_game
	display_font = font
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		child.free()
	var viewport_size := get_viewport().get_visible_rect().size
	var mobile := _is_mobile_platform()
	add_theme_constant_override("separation", _spacing(9, viewport_size))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var language_section := VBoxContainer.new()
	language_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_section.add_theme_constant_override("separation", _spacing(5, viewport_size))
	var language_title := _section_label(I18n.t("SETTINGS_LANGUAGE", "DİL / LANGUAGE"), mobile)
	language_section.add_child(language_title)
	var language_row := HBoxContainer.new()
	language_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	language_row.alignment = BoxContainer.ALIGNMENT_CENTER
	language_row.add_theme_constant_override("separation", _spacing(8, viewport_size))
	for language: Array in [["tr", "TÜRKÇE"], ["en", "ENGLISH"]]:
		var locale := String(language[0])
		var button := _button(String(language[1]), mobile, I18n.current_locale == locale)
		button.pressed.connect(_select_language.bind(locale))
		language_row.add_child(button)
	language_section.add_child(language_row)
	add_child(language_section)
	_add_separator()

	# Resolution and window controls are desktop-only in both settings screens.
	if not mobile:
		_add_display_choices(viewport_size)
		if not _is_native_mobile_platform():
			_add_touch_controls(viewport_size)
		_add_separator()

	_add_volume_setting(
		I18n.t("SETTINGS_MUSIC", "NIGHT SHIFT MUSIC"),
		BakkalAudio.music_volume_db,
		func(value: float) -> void: BakkalAudio.set_music_volume(value),
		mobile,
		viewport_size
	)
	_add_volume_setting(
		I18n.t("SETTINGS_SFX", "GAME FEEDBACK (SFX)"),
		BakkalAudio.sfx_volume_db,
		func(value: float) -> void: BakkalAudio.set_sfx_volume(value),
		mobile,
		viewport_size
	)
	_add_separator()

	var close_text := (
		I18n.t("MANUAL_CLOSE", "BACK TO SHIFT")
		if in_game_context
		else I18n.t("SETTINGS_SAVE", "SAVE AND CLOSE")
	)
	var close_button := _button(close_text, mobile, false, true)
	close_button.pressed.connect(
		func() -> void:
			BakkalAudio.play_sfx(&"ui_confirm")
			BakkalAudio.save_settings()
			DisplayManager.save_settings()
			close_requested.emit()
	)
	add_child(close_button)
	close_button.grab_focus.call_deferred()


func _add_display_choices(viewport_size: Vector2) -> void:
	var resolution_title := _section_label(I18n.t("SETTINGS_RESOLUTION", "ÇÖZÜNÜRLÜK"), false)
	add_child(resolution_title)
	var resolution_row := HBoxContainer.new()
	resolution_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolution_row.add_theme_constant_override("separation", _spacing(6, viewport_size))
	var resolutions := ["1920x1080", "1600x900", "1366x768", "1280x720"]
	for index: int in range(resolutions.size()):
		var button := _button(
			resolutions[index], false, DisplayManager.current_resolution_index == index
		)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(
			func() -> void:
				DisplayManager.set_resolution_index(index)
				BakkalAudio.play_sfx(&"ui_confirm")
				display_changed.emit()
		)
		resolution_row.add_child(button)
	add_child(resolution_row)

	var mode_title := _section_label(I18n.t("SETTINGS_WINDOW_MODE", "EKRAN MODU"), false)
	add_child(mode_title)
	var mode_row := HBoxContainer.new()
	mode_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_theme_constant_override("separation", _spacing(6, viewport_size))
	var mode_names := [
		I18n.t("WINDOW_FULLSCREEN", "Tam Ekran"),
		I18n.t("WINDOW_BORDERLESS", "Kenarlıksız"),
		I18n.t("WINDOW_WINDOWED", "Pencereli")
	]
	for index: int in range(mode_names.size()):
		var button := _button(mode_names[index], false, DisplayManager.current_window_mode == index)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(
			func() -> void:
				DisplayManager.set_window_mode(index)
				BakkalAudio.play_sfx(&"ui_confirm")
				display_changed.emit()
		)
		mode_row.add_child(button)
	add_child(mode_row)


func _add_touch_controls(viewport_size: Vector2) -> void:
	var toggle := CheckButton.new()
	toggle.text = I18n.t("SETTINGS_TOUCH_CONTROLS", "Dokunmatik joystick kullan")
	toggle.button_pressed = DisplayManager.touch_controls_enabled
	toggle.custom_minimum_size.y = _touch_height(viewport_size)
	_style_button(toggle, false, viewport_size)
	toggle.toggled.connect(
		func(enabled: bool) -> void:
			DisplayManager.set_touch_controls_enabled(enabled)
			BakkalAudio.play_sfx(&"ui_confirm")
			display_changed.emit()
	)
	add_child(toggle)


func _add_volume_setting(
	label_text: String, initial_value: float, setter: Callable, mobile: bool, viewport_size: Vector2
) -> void:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", _spacing(3, viewport_size))
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := _section_label(label_text, mobile)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := _section_label(_format_db(initial_value), mobile)
	value.custom_minimum_size.x = 70.0
	value.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT if not mobile else HORIZONTAL_ALIGNMENT_CENTER
	)
	if mobile:
		section.add_child(label)
	else:
		header.add_child(label)
		header.add_child(value)
		section.add_child(header)
	var slider := HSlider.new()
	slider.min_value = -40.0
	slider.max_value = 0.0
	slider.step = 1.0
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = _touch_height(viewport_size) if mobile else 34.0
	slider.value_changed.connect(
		func(next_value: float) -> void:
			value.text = _format_db(next_value)
			setter.call(next_value)
			BakkalAudio.save_settings()
	)
	section.add_child(slider)
	if mobile:
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section.add_child(value)
	add_child(section)


func _section_label(text: String, centered: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	)
	label.add_theme_font_size_override("font_size", 15 if _is_mobile_platform() else 14)
	label.add_theme_color_override("font_color", INK)
	if display_font != null:
		label.add_theme_font_override("font", display_font)
	return label


func _button(text: String, mobile: bool, selected: bool, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL if primary else Control.SIZE_SHRINK_CENTER
	)
	button.custom_minimum_size = Vector2(
		110.0 if not primary else 0.0,
		_touch_height(get_viewport().get_visible_rect().size) if mobile else 40.0
	)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button(button, selected, get_viewport().get_visible_rect().size, primary)
	return button


func _style_button(
	button: Button, selected: bool, viewport_size: Vector2, primary: bool = false
) -> void:
	button.add_theme_font_size_override("font_size", 15 if _is_mobile_platform() else 14)
	button.add_theme_color_override("font_color", PAPER if primary else INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	if display_font != null:
		button.add_theme_font_override("font", display_font)
	button.add_theme_stylebox_override(
		"normal",
		_button_style(
			PAPER if selected else (CORAL if primary else PAPER),
			TEAL if selected else (CORAL if primary else PAPER_EDGE),
			2 if selected else 1
		)
	)
	button.add_theme_stylebox_override("hover", _button_style(PAPER.lightened(0.08), TEAL, 2))
	button.add_theme_stylebox_override("focus", _button_style(PAPER, TEAL, 2))
	button.add_theme_stylebox_override("pressed", _button_style(Color("d8e5d2"), TEAL, 2))
	if primary:
		button.add_theme_color_override("font_hover_color", INK)
		button.add_theme_color_override("font_focus_color", INK)
		button.add_theme_color_override("font_pressed_color", INK)
	if button is CheckButton:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = (
			_touch_height(viewport_size) if _is_mobile_platform() else 40.0
		)


func _button_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(0)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _add_separator() -> void:
	var separator := HSeparator.new()
	separator.add_theme_color_override("color", Color(INK, 0.2))
	add_child(separator)


func _select_language(locale: String) -> void:
	I18n.set_language(locale)
	BakkalAudio.play_sfx(&"ui_confirm")
	language_changed.emit()


func _format_db(value: float) -> String:
	return "MUTED" if value <= -39.0 else "%d dB" % roundi(value)


func _touch_height(viewport_size: Vector2) -> float:
	return maxf(48.0, viewport_size.y * 0.044)


func _spacing(value: float, viewport_size: Vector2) -> int:
	return roundi(value * clampf(viewport_size.y / 1080.0, 0.75, 1.2))


func _is_mobile_platform() -> bool:
	return (
		OS.has_feature("portmaster")
		or OS.has_feature("mobile")
		or OS.has_feature("android")
		or OS.has_feature("ios")
	)


func _is_native_mobile_platform() -> bool:
	return (
		OS.has_feature("portmaster")
		or OS.has_feature("mobile")
		or OS.has_feature("android")
		or OS.has_feature("ios")
	)
