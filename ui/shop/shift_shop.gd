extends CanvasLayer
class_name ShiftShop

signal offer_purchased(index: int)
signal offer_lock_toggled(index: int, locked: bool)
signal reroll_requested
signal continue_requested
signal weapon_sell_requested(weapon_id: StringName)

@export var display_font: FontFile

const TURKISH_FALLBACK_FONT: FontFile = preload("res://assets/fonts/DejaVuSans.ttf")

const INK := Color("172421")
const PANEL := Color("e7dec9", 0.99)
const PANEL_EDGE := Color("886a50")
const TEXT := Color("172421")
const MUTED := Color("53645b")
const TEAL := Color("6da4aa")
const GOLD := Color("b8c7a3")
const RED := Color("d96c4b")
const CARD := Color("f8f1df")
const MAX_OFFERS := 3
const MAX_WEAPON_SLOTS := 6

class ReceiptClamp extends Control:
	func _draw() -> void:
		var center := size.x * 0.5
		draw_rect(Rect2(0, size.y * 0.33, size.x, size.y * 0.6), Color("29332e"))
		draw_rect(Rect2(4, size.y * 0.40, size.x - 8, size.y * 0.45), Color("77776d"))
		draw_rect(Rect2(center - size.x * 0.13, 0, size.x * 0.26, size.y * 0.62), Color("999588"))
		draw_circle(Vector2(center, size.y * 0.22), size.y * 0.11, Color("202421"))

var _round_label: Label
var _currency_label: Label
var _title_label: Label
var _subline_label: Label
var _note_label: Label
var _cards_row: Container
var _shop_sidebar: VBoxContainer
var _reroll_button: Button
var _continue_button: Button
var _inventory_items_label: Label
var _inventory_weapons_label: Label
var _inventory_deployables_label: Label
var _inventory_upgrades_row: HBoxContainer
var _inventory_deployables_row: HBoxContainer
var _inventory_weapons_row: HBoxContainer
var _inventory_open_button: Button
var _inventory_overlay: Control
var _inventory_panel: PanelContainer
var _inventory_close_button: Button
var _inventory_clip: ReceiptClamp
var _inventory_items_list: VBoxContainer
var _weapon_detail_overlay: Control
var _weapon_detail_panel: PanelContainer
var _weapon_detail_icon: TextureRect
var _weapon_detail_name: Label
var _weapon_detail_tier: Label
var _weapon_detail_stats: VBoxContainer
var _weapon_detail_sell: Button
var _weapon_detail_close: Button
var _weapon_detail_clip: ReceiptClamp
var _selected_weapon_id: StringName = &""
var _selected_weapon: Dictionary = {}
var _styles: Dictionary = {}
var _touch_scroll_target: ScrollContainer
var _touch_scroll_start := Vector2.ZERO
var _touch_scroll_last := Vector2.ZERO
var _touch_scroll_active := false
var _touch_scroll_dragging := false
var _current_currency: int = 0
var _current_offers: Array = []
var _current_prices: Array[int] = []
var _current_reroll_cost: int = 0
var _current_round_number: int = 0
var _should_show: bool = false
var _purchased_indices: Array[int] = []
var _locked_indices: Array[int] = []
var _player_summary: Dictionary = {}
var _weapon_names: PackedStringArray = []


func _ready() -> void:
	_apply_turkish_font_fallback()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_shop()
	_update_shop_texts()
	set_shop_state(_current_currency, _current_offers, _current_prices, _current_reroll_cost, _purchased_indices)
	visible = _should_show
	if I18n != null and I18n.has_signal("language_changed"):
		I18n.language_changed.connect(func(_l: String) -> void:
			_update_shop_texts()
			_rebuild_offer_cards()
		)


func _apply_turkish_font_fallback() -> void:
	if display_font == null:
		return
	display_font = display_font.duplicate() as FontFile
	var fallbacks: Array[Font] = display_font.fallbacks.duplicate()
	if not fallbacks.has(TURKISH_FALLBACK_FONT):
		fallbacks.append(TURKISH_FALLBACK_FONT)
	display_font.fallbacks = fallbacks


func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_GO_BACK_REQUEST and visible:
		if is_instance_valid(_inventory_overlay) and _inventory_overlay.visible:
			_inventory_overlay.hide()
		elif is_instance_valid(_weapon_detail_overlay) and _weapon_detail_overlay.visible:
			_weapon_detail_overlay.hide()
		else:
			_on_continue_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if is_instance_valid(_inventory_overlay) and _inventory_overlay.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			_inventory_overlay.hide()
			get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_weapon_detail_overlay) and _weapon_detail_overlay.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			_weapon_detail_overlay.hide()
			get_viewport().set_input_as_handled()
		return
	var back_pressed := event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")
	if event is InputEventKey and event.pressed and not event.echo:
		back_pressed = back_pressed or (event as InputEventKey).keycode in [KEY_ESCAPE, KEY_BACK]
	if back_pressed:
		_on_continue_pressed()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if is_instance_valid(_inventory_overlay) and _inventory_overlay.visible and is_instance_valid(_inventory_close_button) and _inventory_close_button.get_global_rect().has_point(touch.position):
				_close_inventory()
				get_viewport().set_input_as_handled()
				return
			if is_instance_valid(_weapon_detail_overlay) and _weapon_detail_overlay.visible and is_instance_valid(_weapon_detail_close) and _weapon_detail_close.get_global_rect().has_point(touch.position):
				_close_weapon_detail()
				get_viewport().set_input_as_handled()
				return
			_touch_scroll_target = _scroll_container_at(touch.position)
			_touch_scroll_start = touch.position
			_touch_scroll_last = touch.position
			_touch_scroll_active = is_instance_valid(_touch_scroll_target)
			_touch_scroll_dragging = false
		else:
			if _touch_scroll_dragging:
				get_viewport().set_input_as_handled()
			_touch_scroll_active = false
			_touch_scroll_dragging = false
			_touch_scroll_target = null
	elif event is InputEventScreenDrag and _touch_scroll_active and is_instance_valid(_touch_scroll_target):
		var drag := event as InputEventScreenDrag
		if absf(drag.position.y - _touch_scroll_start.y) >= 8.0:
			_touch_scroll_dragging = true
			_touch_scroll_target.scroll_vertical -= roundi(drag.position.y - _touch_scroll_last.y)
			get_viewport().set_input_as_handled()
		_touch_scroll_last = drag.position


func _scroll_container_at(position: Vector2) -> ScrollContainer:
	var candidates: Array[ScrollContainer] = []
	var found: Array[Node] = []
	if is_instance_valid(_weapon_detail_overlay) and _weapon_detail_overlay.visible:
		found = _weapon_detail_overlay.find_children("*", "ScrollContainer", true, false)
	elif is_instance_valid(_inventory_overlay) and _inventory_overlay.visible:
		found = _inventory_overlay.find_children("*", "ScrollContainer", true, false)
	else:
		found = find_children("OfferCardsScroll", "ScrollContainer", true, false)
		if is_instance_valid(_shop_sidebar):
			found.append_array(_shop_sidebar.find_children("StatsScroll", "ScrollContainer", true, false))
	for node: Node in found:
		if node is ScrollContainer:
			candidates.append(node as ScrollContainer)
	for candidate: ScrollContainer in candidates:
		if candidate.is_visible_in_tree() and candidate.get_global_rect().has_point(position):
			return candidate
	return null


func show_shop(round_number: int, currency: int, offers: Array, prices: Array[int], reroll_cost: int, purchased_indices: Array = [], player_summary: Dictionary = {}, weapon_names: PackedStringArray = []) -> void:
	_current_round_number = maxi(0, round_number)
	_player_summary = player_summary.duplicate(true)
	_weapon_names = weapon_names.duplicate()
	_locked_indices.clear()
	_should_show = true
	set_shop_state(currency, offers, prices, reroll_cost, purchased_indices)
	_update_shop_sidebar()
	visible = true
	if is_instance_valid(_continue_button):
		_continue_button.grab_focus.call_deferred()


func set_shop_state(currency: int, offers: Array, prices: Array[int], reroll_cost: int, purchased_indices: Array = [], locked_indices: Array = []) -> void:
	_current_currency = maxi(0, currency)
	_current_offers = offers.duplicate()
	_current_prices = prices.duplicate()
	_current_reroll_cost = maxi(0, reroll_cost)
	_purchased_indices.clear()
	for idx in purchased_indices:
		_purchased_indices.append(int(idx))
	_locked_indices.clear()
	for idx in locked_indices:
		_locked_indices.append(int(idx))
	if not is_instance_valid(_cards_row):
		return
	_update_shop_texts()
	_rebuild_offer_cards()
	_update_shop_sidebar()


func set_shop_summary(player_summary: Dictionary, weapon_names: PackedStringArray) -> void:
	_player_summary = player_summary.duplicate(true)
	_weapon_names = weapon_names.duplicate()
	_update_shop_sidebar()


func _update_shop_texts() -> void:
	if is_instance_valid(_round_label):
		_round_label.text = "SHOP (WAVE %d)" % _current_round_number
		_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if is_instance_valid(_title_label):
		_title_label.text = I18n.t("SHOP_TITLE", "The stockroom")
	if is_instance_valid(_subline_label):
		_subline_label.text = I18n.t("SHOP_SUBTITLE", "Pick supplies for the next wave, or head back to the aisles.")
	if is_instance_valid(_currency_label):
		_currency_label.text = "%d  " % _current_currency + I18n.t("SHOP_TOKENS", "stock tokens")
	if is_instance_valid(_reroll_button):
		_reroll_button.text = I18n.t("SHOP_REFRESH", "Refresh shelf (%d)") % _current_reroll_cost
		var all_offers_locked := not _current_offers.is_empty() and _locked_indices.size() >= _current_offers.size()
		_reroll_button.disabled = _current_currency < _current_reroll_cost or all_offers_locked
	if is_instance_valid(_note_label):
		_note_label.text = String(_player_summary.get("difficulty_event_notice", I18n.t("SHOP_NOTE", "Offers restock after each wave.")))
	if is_instance_valid(_continue_button):
		_continue_button.text = I18n.t("SHOP_RETURN", "Return to aisles")
	if is_instance_valid(_inventory_open_button):
		_inventory_open_button.text = _ui_text("ENVANTER", "INVENTORY") + "   ›"


func _build_shop() -> void:
	var root := Control.new()
	root.name = "ShopRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.075, 0.09, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	_build_weapon_detail_overlay(root)
	_build_inventory_overlay(root)

	var panel := PanelContainer.new()
	panel.name = "ShopPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := _safe_insets(viewport_size)
	var portrait := viewport_size.x < viewport_size.y
	var mobile := _is_mobile_platform()
	var portmaster := OS.has_feature("portmaster")
	var density_scale := _mobile_density_scale(viewport_size) if mobile else 1.0
	var layout_scale := _mobile_layout_scale(viewport_size) if mobile else 1.0
	var usable_width := maxf(280.0, viewport_size.x - safe.x - safe.z)
	var usable_height := maxf(320.0, viewport_size.y - safe.y - safe.w)
	panel.offset_left = -usable_width * (0.485 if not mobile else 0.49) + (safe.x - safe.z) * 0.5
	panel.offset_right = usable_width * (0.485 if not mobile else 0.49) + (safe.x - safe.z) * 0.5
	panel.offset_top = -usable_height * (0.485 if not mobile else 0.49) + (safe.y - safe.w) * 0.5
	panel.offset_bottom = usable_height * (0.485 if not mobile else 0.49) + (safe.y - safe.w) * 0.5
	panel.add_theme_stylebox_override("panel", _style(PANEL, PANEL_EDGE, 0, 1))
	root.add_child(panel)

	var margins := MarginContainer.new()
	var compact := mobile or viewport_size.y <= 800.0 or viewport_size.x <= 1400.0
	for side: String in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, roundi(8.0 * layout_scale) if mobile else (14 if compact else 24))
	panel.add_child(margins)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", roundi(8.0 * layout_scale) if mobile else (10 if compact else 14))
	margins.add_child(content)

	var header: Control = VBoxContainer.new() if (portmaster or (portrait and not mobile)) else HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	content.add_child(header)

	var title_board := PanelContainer.new()
	title_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_board.add_theme_stylebox_override("panel", _style(Color("20362f"), Color("a88b5e"), 0, 2))
	var title_margins := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		title_margins.add_theme_constant_override("margin_" + side, 12 if not mobile else roundi(8.0 * layout_scale))
	title_board.add_child(title_margins)
	var title_stack := VBoxContainer.new()
	title_stack.add_theme_constant_override("separation", 4)
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_margins.add_child(title_stack)
	header.add_child(title_board)
	_title_label = _label("The stockroom", 44, Color("f0e7cf"))
	if mobile:
		_title_label.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 38.0)))
	title_stack.add_child(_title_label)
	_subline_label = _label("Pick supplies for the next wave, or head back to the aisles.", 18, Color("b8c7a3"))
	_subline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if mobile:
		_subline_label.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 18.0)))
	title_stack.add_child(_subline_label)

	var right_header: Control = HBoxContainer.new() if (portmaster or (portrait and not mobile)) else VBoxContainer.new()
	right_header.add_theme_constant_override("separation", 8)
	if mobile:
		right_header.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(right_header)
	_round_label = _label("SHOP (WAVE 000)", 18, GOLD)
	if mobile:
		_round_label.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 18.0)))
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_header.add_child(_round_label)
	var balance_panel := PanelContainer.new()
	balance_panel.custom_minimum_size = Vector2((200 if portrait else 240) * layout_scale if mobile else (200 if portrait else 280), (52 if portrait else 64) * layout_scale if mobile else (52 if portrait else 78))
	if mobile:
		balance_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance_panel.add_theme_stylebox_override("panel", _style(Color("e4dbb6"), PANEL_EDGE, 0, 1))
	var balance_margins := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		balance_margins.add_theme_constant_override("margin_" + side, roundi(8.0 * layout_scale) if mobile else (8 if portrait else 14))
	balance_panel.add_child(balance_margins)
	_currency_label = _label("00  stock tokens", 23, TEXT)
	if mobile:
		_currency_label.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 22.0)))
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_margins.add_child(_center_control(_currency_label))
	var currency_controls: Control = HBoxContainer.new() if mobile else right_header
	if mobile:
		currency_controls.add_theme_constant_override("separation", 8)
		currency_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		currency_controls.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		right_header.add_child(currency_controls)
	_reroll_button = _button("Refresh shelf   /   0", false)
	_reroll_button.custom_minimum_size = balance_panel.custom_minimum_size if mobile else Vector2(260, 52)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	if mobile:
		_reroll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		currency_controls.add_child(_reroll_button)
		currency_controls.add_child(balance_panel)
	else:
		right_header.add_child(balance_panel)
		right_header.add_child(_reroll_button)
	if portrait and not mobile:
		_round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_currency_label.add_theme_font_size_override("font_size", _responsive_font_size(17))

	var divider := HSeparator.new()
	var divider_style := StyleBoxLine.new()
	divider_style.color = PANEL_EDGE
	divider_style.thickness = 1
	divider.add_theme_stylebox_override("separator", divider_style)
	content.add_child(divider)

	var offer_layout: Control = VBoxContainer.new() if (portmaster or (portrait and not mobile)) else HBoxContainer.new()
	offer_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	offer_layout.add_theme_constant_override("separation", 18)
	content.add_child(offer_layout)
	_cards_row = GridContainer.new() if mobile else HBoxContainer.new()
	if mobile:
		(_cards_row as GridContainer).columns = 1 if portrait else (2 if portmaster else 3)
	_cards_row.name = "OfferCards"
	_cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_row.add_theme_constant_override("separation", roundi(10.0 * layout_scale) if mobile else (14 if compact else 20))
	if mobile and (portmaster or viewport_size.y <= 600.0):
		var cards_scroll := ScrollContainer.new()
		cards_scroll.name = "OfferCardsScroll"
		cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		cards_scroll.follow_focus = portmaster
		if portmaster:
			var offer_stack := VBoxContainer.new()
			offer_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cards_scroll.add_child(offer_stack)
			offer_stack.add_child(_cards_row)
			_shop_sidebar = _build_shop_sidebar()
			_shop_sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_shop_sidebar.custom_minimum_size.x = 0.0
			offer_stack.add_child(_shop_sidebar)
		else:
			cards_scroll.add_child(_cards_row)
		offer_layout.add_child(cards_scroll)
	else:
		# Landscape phones and tablets have enough room to show every offer at once.
		# Let the grid take the available space so the card copy remains readable.
		_cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		offer_layout.add_child(_cards_row)
	if not portmaster:
		_shop_sidebar = _build_shop_sidebar()
		_shop_sidebar.visible = not portrait or mobile
		if not portrait or mobile:
			offer_layout.add_child(_shop_sidebar)

	content.add_child(_build_inventory_strip(viewport_size, mobile, layout_scale))
	var footer: Control = VBoxContainer.new() if (portrait and not mobile) else HBoxContainer.new()
	footer.add_theme_constant_override("separation", roundi(8.0 * layout_scale) if mobile else 16)
	content.add_child(footer)

	_note_label = _label("Offers restock after each wave.", 14, MUTED)
	_note_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_note_label)

	_continue_button = _button("Return to aisles", true)
	_continue_button.custom_minimum_size = Vector2((150 if mobile else 270), (56.0 if mobile else 52.0))
	_continue_button.pressed.connect(_on_continue_pressed)
	var continue_spacer := MarginContainer.new()
	continue_spacer.add_theme_constant_override("margin_bottom", roundi(10.0 * layout_scale) if mobile else 10)
	footer.add_child(continue_spacer)
	continue_spacer.add_child(_continue_button)
	if mobile or (portrait and not mobile):
		var touch_size := 56.0 if mobile and not portmaster else (48.0 if portmaster else _touch_target_size(viewport_size))
		_continue_button.custom_minimum_size.x = 0.0
		_continue_button.custom_minimum_size.y = touch_size
		_continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_shop_sidebar()
	_update_inventory_strip()


func _build_shop_sidebar() -> VBoxContainer:
	var sidebar := VBoxContainer.new()
	var viewport_size := get_viewport().get_visible_rect().size
	var mobile := _is_mobile_platform()
	sidebar.custom_minimum_size.x = 280 if viewport_size.x <= 1400.0 else 300
	if mobile:
		sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 10)
	var stats_panel := PanelContainer.new()
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel.add_theme_stylebox_override("panel", _style(CARD, PANEL_EDGE, 0, 1))
	var stats_content := VBoxContainer.new()
	stats_content.name = "StatsContent"
	stats_content.add_theme_constant_override("separation", 6)
	if mobile:
		# The full stat list can be taller than a landscape phone's offer area.
		# Keep it scrollable so its minimum height cannot push the inventory and
		# the return-to-aisles action below the visible screen.
		var stats_scroll := ScrollContainer.new()
		stats_scroll.name = "StatsScroll"
		stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stats_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		stats_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		stats_panel.add_child(_margin(stats_scroll, 6))
		stats_scroll.add_child(_margin(stats_content, 6))
	else:
		stats_panel.add_child(_margin(stats_content, 12))
	var stat_font := roundi(_mobile_shop_font(viewport_size, 19.0)) if mobile else 19
	var stat_title_font := roundi(_mobile_shop_font(viewport_size, 23.0)) if mobile else 22
	var stats_title := _label("Shift stats", stat_title_font, TEXT)
	if mobile:
		stats_title.add_theme_font_size_override("font_size", stat_title_font)
	stats_content.add_child(stats_title)
	for key: String in ["level", "health", "damage", "melee_damage", "ranged_damage", "attack_speed", "crit_chance", "elemental_damage", "engineering", "speed", "lifesteal", "dodge", "protection", "armor", "harvesting", "luck", "xp_gain"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var stat_label := "Elemental Damage" if key == "elemental_damage" else ("Engineering" if key == "engineering" else key.replace("_", " ").capitalize())
		var name_label := _label(stat_label, stat_font, MUTED)
		if mobile:
			name_label.add_theme_font_size_override("font_size", stat_font)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value_label := _label("—", stat_font, TEAL)
		if mobile:
			value_label.add_theme_font_size_override("font_size", stat_font)
		value_label.name = "Value_" + key
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(name_label)
		row.add_child(value_label)
		stats_content.add_child(row)
	var training_text := String(_player_summary.get("weapon_training", ""))
	var training_row := stats_content.find_child("WeaponTraining", true, false) as Label
	if not is_instance_valid(training_row):
		var training_font := roundi(_mobile_shop_font(viewport_size, 16.0)) if mobile else 15
		training_row = _label("", training_font, GOLD)
		if mobile:
			training_row.add_theme_font_size_override("font_size", training_font)
		training_row.name = "WeaponTraining"
		training_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_content.add_child(training_row)
	training_row.text = training_text
	training_row.visible = not training_text.is_empty()
	var class_bonus_text := String(_player_summary.get("weapon_class_bonuses", ""))
	var class_bonus_row := stats_content.find_child("WeaponClassBonuses", true, false) as Label
	if not is_instance_valid(class_bonus_row):
		class_bonus_row = _label("", 15, TEAL)
		class_bonus_row.name = "WeaponClassBonuses"
		class_bonus_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_content.add_child(class_bonus_row)
	class_bonus_row.text = class_bonus_text
	class_bonus_row.visible = not class_bonus_text.is_empty()
	sidebar.add_child(stats_panel)
	return sidebar


func _update_shop_sidebar() -> void:
	if not is_instance_valid(_shop_sidebar):
		return
	var stats_content := _shop_sidebar.find_child("StatsContent", true, false) as VBoxContainer
	if is_instance_valid(stats_content):
		for key: String in ["level", "health", "damage", "melee_damage", "ranged_damage", "attack_speed", "crit_chance", "elemental_damage", "engineering", "speed", "lifesteal", "dodge", "protection", "armor", "harvesting", "luck", "xp_gain"]:
			var value_label := stats_content.find_child("Value_" + key, true, false) as Label
			if is_instance_valid(value_label):
				value_label.text = str(_player_summary.get(key, "—"))
		var training_row := stats_content.find_child("WeaponTraining", true, false) as Label
		if is_instance_valid(training_row):
			training_row.text = String(_player_summary.get("weapon_training", ""))
			training_row.visible = not training_row.text.is_empty()
		var class_bonus_row := stats_content.find_child("WeaponClassBonuses", true, false) as Label
		if is_instance_valid(class_bonus_row):
			class_bonus_row.text = String(_player_summary.get("weapon_class_bonuses", ""))
			class_bonus_row.visible = not class_bonus_row.text.is_empty()
	_update_inventory_strip()


func _build_inventory_strip(viewport_size: Vector2, mobile: bool, layout_scale: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "InventoryStrip"
	panel.add_theme_stylebox_override("panel", _style(Color("e4dbb6"), PANEL_EDGE, 0, 1))
	panel.custom_minimum_size.y = 126.0 if mobile else 144.0
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(_margin(body, roundi(5.0 * layout_scale) if mobile else 8))
	var active_column := VBoxContainer.new()
	active_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_column.add_theme_constant_override("separation", 4)
	body.add_child(active_column)
	_inventory_open_button = _button(_ui_text("ENVANTER", "INVENTORY") + "   ›", false)
	_inventory_open_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_inventory_open_button.custom_minimum_size.y = (54.0 if mobile and not OS.has_feature("portmaster") else _touch_target_size(viewport_size)) if mobile else 34
	_inventory_open_button.pressed.connect(_open_inventory)
	active_column.add_child(_inventory_open_button)
	_inventory_upgrades_row = HBoxContainer.new()
	_inventory_deployables_row = HBoxContainer.new()
	active_column.add_child(_make_inventory_scroll(_inventory_upgrades_row))
	active_column.add_child(_make_inventory_scroll(_inventory_deployables_row))
	var weapon_column := VBoxContainer.new()
	weapon_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_column.custom_minimum_size.x = viewport_size.x * (0.32 if mobile else 0.35)
	weapon_column.add_theme_constant_override("separation", 4)
	body.add_child(weapon_column)
	_inventory_weapons_label = _label("WEAPONS (0/6)  ·  select for details", 16, TEXT)
	if OS.has_feature("portmaster"):
		_inventory_weapons_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_column.add_child(_inventory_weapons_label)
	_inventory_weapons_row = HBoxContainer.new()
	weapon_column.add_child(_make_inventory_scroll(_inventory_weapons_row))
	_update_inventory_strip()
	return panel


func _make_inventory_scroll(row: HBoxContainer) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 48.0
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)
	return scroll


func _update_inventory_strip() -> void:
	var inventory: Dictionary = _player_summary.get("inventory", {}) if _player_summary.get("inventory", {}) is Dictionary else {}
	_clear_inventory_row(_inventory_upgrades_row)
	_clear_inventory_row(_inventory_deployables_row)
	_clear_inventory_row(_inventory_weapons_row)
	var upgrades: Array = inventory.get("upgrades", [])
	for upgrade: Variant in upgrades:
		if upgrade is Dictionary:
			_add_inventory_chip(_inventory_upgrades_row, upgrade, "UPGRADE", int(upgrade.get("rank", 1)))
	var deployables: Array = inventory.get("deployables", [])
	for deployed: Variant in deployables:
		if deployed is Dictionary:
			_add_inventory_chip(_inventory_deployables_row, deployed, String(deployed.get("kind", "DEPLOYABLE")).to_upper(), int(deployed.get("count", 0)))
	var weapons: Array = inventory.get("weapons", [])
	if is_instance_valid(_inventory_weapons_label):
		_inventory_weapons_label.text = I18n.t("SHOP_WEAPONS_COUNT", "WEAPONS (%d/6)  ·  select for details") % [mini(weapons.size(), MAX_WEAPON_SLOTS)]
	for weapon: Variant in weapons:
		if weapon is Dictionary:
			_add_weapon_chip(weapon)
	for slot_index in range(mini(weapons.size(), MAX_WEAPON_SLOTS), MAX_WEAPON_SLOTS):
		_add_empty_weapon_slot(slot_index)


func _clear_inventory_row(row: Container) -> void:
	if not is_instance_valid(row):
		return
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()


func _add_inventory_chip(row: HBoxContainer, record: Dictionary, kind: String, count: int) -> void:
	if not is_instance_valid(row):
		return
	var id := String(record.get("id", ""))
	var tier := clampi(int(record.get("tier", record.get("rank", 1))), 1, 4)
	var name := String(record.get("name", id.replace("_", " ").capitalize()))
	var button := Button.new()
	var icon_only := kind in ["TURRET", "MINE", "UPGRADE"]
	button.custom_minimum_size = Vector2(72, 62) if icon_only else Vector2(108, 52)
	button.text = "" if icon_only else ("%s  ×%d" % [name, count] if count > 0 else name)
	button.tooltip_text = "%s · %s" % [kind, name]
	if kind == "WEAPON":
		button.tooltip_text += " · " + String(record.get("weapon_class_name", ""))
	var icon := record.get("icon") as Texture2D
	if icon == null and kind == "UPGRADE":
		var upgrade_path := "res://data/upgrades/%s.tres" % id
		if ResourceLoader.exists(upgrade_path):
			var upgrade_resource := load(upgrade_path) as UpgradeDefinition
			if upgrade_resource != null:
				icon = upgrade_resource.icon
	if icon == null and ResourceLoader.exists("res://assets/generated/shop_icons/%s.png" % id):
		icon = load("res://assets/generated/shop_icons/%s.png" % id) as Texture2D
	if icon == null and icon_only:
		icon = load("res://assets/generated/pickups/pickup_stock_bundle.png") as Texture2D
	if icon != null:
		var image := TextureRect.new()
		image.texture = icon
		image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.offset_left = 4
		image.offset_top = 4
		image.offset_right = -4
		image.offset_bottom = -4
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(image)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _tier_style(tier))
	var hover_style := _tier_style(tier).duplicate() as StyleBoxFlat
	hover_style.border_color = RED
	hover_style.set_border_width_all(3)
	button.add_theme_stylebox_override("hover", hover_style)
	button.pressed.connect(_on_inventory_item_pressed.bind(record, kind, count))
	if kind in ["TURRET", "MINE"]:
		_add_inventory_badge(button, _tier_suffix(tier), true)
		_add_inventory_badge(button, "×%d" % maxi(1, count), false)
	elif kind == "UPGRADE":
		_add_inventory_badge(button, "R%d" % maxi(1, count), false)
	row.add_child(button)


func _add_inventory_badge(button: Button, text: String, top_right: bool) -> void:
	var badge := Label.new()
	badge.text = text
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", INK)
	badge.add_theme_stylebox_override("normal", _style(Color("f8f5e9", 0.94), PANEL_EDGE, 2, 1))
	if top_right:
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.position = Vector2(-23, 2)
		badge.size = Vector2(21, 17)
	else:
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.position = Vector2(-34, -19)
		badge.size = Vector2(32, 17)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)


func _add_weapon_chip(weapon: Dictionary) -> void:
	if not is_instance_valid(_inventory_weapons_row):
		return
	var tier := clampi(int(weapon.get("tier", 1)), 1, 4)
	var id := StringName(String(weapon.get("id", "")))
	var name := String(weapon.get("name", "Weapon"))
	var button := Button.new()
	button.custom_minimum_size = Vector2(68, 60)
	button.text = ""
	button.tooltip_text = "%s %s · %s — tap for stats or sell" % [name, _tier_suffix(tier), String(weapon.get("weapon_class_name", ""))]
	var icon := weapon.get("icon") as Texture2D
	if icon != null:
		var image := TextureRect.new()
		image.texture = icon
		image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.offset_left = 5
		image.offset_top = 4
		image.offset_right = -5
		image.offset_bottom = -4
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(image)
	var tier_tag := Label.new()
	tier_tag.text = _tier_suffix(tier)
	tier_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tier_tag.add_theme_font_size_override("font_size", 12)
	tier_tag.add_theme_color_override("font_color", INK)
	tier_tag.add_theme_stylebox_override("normal", _style(Color("f8f5e9", 0.92), PANEL_EDGE, 2, 1))
	tier_tag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tier_tag.position = Vector2(-24, 2)
	tier_tag.size = Vector2(21, 18)
	tier_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(tier_tag)
	button.add_theme_stylebox_override("normal", _tier_style(tier))
	button.add_theme_stylebox_override("hover", _tier_style(tier).duplicate())
	button.pressed.connect(_on_weapon_chip_pressed.bind(weapon))
	_inventory_weapons_row.add_child(button)


func _add_empty_weapon_slot(slot_index: int) -> void:
	if not is_instance_valid(_inventory_weapons_row):
		return
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(68, 60)
	slot.tooltip_text = _ui_text("Boş silah yuvası", "Empty weapon slot")
	slot.add_theme_stylebox_override("panel", _style(Color("eee7d3"), Color("b5a88e"), 2, 1))
	var mark := _label("+\n%02d" % (slot_index + 1), 12, MUTED)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(mark)
	_inventory_weapons_row.add_child(slot)


func _tier_style(tier: int) -> StyleBoxFlat:
	var fills := [Color("e7dec9"), Color("6da4aa"), Color("aa8db8"), Color("d6a35f")]
	var edges := [Color("886a50"), Color("315f67"), Color("72547f"), Color("a96828")]
	return _style(fills[clampi(tier, 1, 4) - 1], edges[clampi(tier, 1, 4) - 1], 2, 2)


func _offer_tier(offer: Variant) -> int:
	if offer is WeaponDefinition:
		return clampi((offer as WeaponDefinition).tier, 1, 4)
	return 1


func _tier_offer_style(tier: int) -> StyleBoxFlat:
	var style := _tier_style(tier).duplicate() as StyleBoxFlat
	style.set_corner_radius_all(0)
	style.set_border_width_all(2)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style


func _offer_value_lines(offer: Variant) -> PackedStringArray:
	var lines := PackedStringArray()
	if offer is WeaponDefinition:
		var weapon := offer as WeaponDefinition
		lines.append("%s  %d / %s · %s" % [_ui_text("HASAR", "DAMAGE"), _weapon_damage_at_tier(weapon, weapon.tier), _ui_text("VURUŞ", "HIT"), _scaling_stat_name(weapon.damage_scaling_stat).to_upper()])
		lines.append("%s  %.2f s · %s  %d · %s  %d" % [_ui_text("ATIŞ", "FIRE"), maxf(0.05, weapon.fire_interval * pow(0.93, float(maxi(0, weapon.tier - 1)))), _ui_text("MERMI", "PROJECTILES"), _projectile_count_at_tier(weapon), _ui_text("MENZİL", "RANGE"), _weapon_range_at_tier(weapon, weapon.tier)])
		if _weapon_area_at_tier(weapon, weapon.tier) > 0 or weapon.pierce_count > 0:
			lines.append("%s  %d px · %s  %d" % [_ui_text("ALAN", "AREA"), _weapon_area_at_tier(weapon, weapon.tier), _ui_text("DELME", "PIERCE"), weapon.pierce_count])
	elif offer is UpgradeDefinition:
		var upgrade := offer as UpgradeDefinition
		lines.append(_upgrade_effect_summary(upgrade, 1).to_upper())
		if upgrade.target_weapon_id != &"":
			lines.append("HEDEF  %s" % String(upgrade.target_weapon_id).replace("_", " ").to_upper())
	elif offer is Dictionary:
		var stat_offer := offer as Dictionary
		lines.append(_format_shop_delta(String(stat_offer.get("id", "")), float(stat_offer.get("value", 0.0))).to_upper())
	return lines


func _projectile_count_at_tier(weapon: WeaponDefinition) -> int:
	var extra := 0
	if weapon.id == &"milk_hose":
		extra = maxi(0, weapon.tier - 1)
	elif weapon.tier >= 3 and weapon.attack_mode in [WeaponDefinition.AttackMode.TARGETED_PROJECTILE, WeaponDefinition.AttackMode.RETURNING_PROJECTILE, WeaponDefinition.AttackMode.CONE_PROJECTILES, WeaponDefinition.AttackMode.ORBITAL_CONTACT, WeaponDefinition.AttackMode.EXPLOSIVE_PROJECTILE]:
		extra = 1
	return weapon.projectile_count + extra


func _on_weapon_chip_pressed(weapon: Dictionary) -> void:
	_selected_weapon_id = StringName(String(weapon.get("id", "")))
	_selected_weapon = weapon.duplicate(true)
	_weapon_detail_name.text = String(weapon.get("name", "Weapon"))
	_weapon_detail_tier.text = "TIER %s  /  %s" % [_tier_suffix(int(weapon.get("tier", 1))), String(weapon.get("weapon_class_name", weapon.get("category", "WEAPON"))).to_upper()]
	_weapon_detail_icon.texture = weapon.get("icon") as Texture2D
	_clear_inventory_row(_weapon_detail_stats)
	_add_detail_stat("Weapon class", String(weapon.get("weapon_class_name", weapon.get("category", "Ranged"))))
	var weapon_class_id := int(weapon.get("weapon_class", -1))
	if weapon_class_id >= 0:
		_add_detail_stat(_ui_text("Sınıf seti", "Class set"), _describe_class_set(weapon_class_id, false))
	_add_detail_stat("Damage per hit", str(weapon.get("damage", "—")))
	_add_detail_stat("Scales from", _scaling_stat_name(int(weapon.get("damage_scaling_stat", WeaponDefinition.DamageScalingStat.RANGED))))
	if int(weapon.get("damage_type", WeaponDefinition.DamageType.PHYSICAL)) == WeaponDefinition.DamageType.ELEMENTAL:
		_add_detail_stat("Elemental scaling", "%d%%" % roundi(float(weapon.get("elemental_scaling_coefficient", 0.0)) * 100.0))
	if String(weapon.get("category", "")) == "Melee":
		_add_detail_stat("Swing arc", "%d°" % roundi(float(weapon.get("melee_arc_degrees", 100.0))))
	elif float(weapon.get("projectile_spread_degrees", 0.0)) > 0.0:
		_add_detail_stat("Fan width", "%d°" % roundi(float(weapon.get("projectile_spread_degrees", 0.0))))
	_add_detail_stat("Fire interval", "%.2f s" % float(weapon.get("fire_interval", 0.0)))
	if String(weapon.get("category", "")) != "Melee":
		_add_detail_stat("Projectiles", str(weapon.get("projectile_count", 1)))
	_add_detail_stat("Range", str(weapon.get("range", 0)))
	_add_detail_stat("Area", str(weapon.get("area", 0)))
	_add_detail_stat("Pierce", str(weapon.get("pierce", 0)))
	_weapon_detail_sell.text = I18n.t("SHOP_SELL_FOR", "SELL · %d TOKENS") % _weapon_sell_price(weapon)
	_weapon_detail_sell.disabled = inventory_weapon_count() <= 1
	_weapon_detail_sell.show()
	_weapon_detail_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_detail_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_detail_close.text = I18n.t("SHOP_CLOSE", "CLOSE")
	_weapon_detail_overlay.show()
	_weapon_detail_panel.add_theme_stylebox_override("panel", _tier_style(int(weapon.get("tier", 1))))
	_layout_weapon_detail()


func _weapon_sell_price(weapon: Dictionary) -> int:
	if weapon.has("sell_price"):
		return int(weapon["sell_price"])
	var tier := clampi(int(weapon.get("tier", 1)), 1, 4)
	var base_price := 12 + (tier - 1) * 4
	if String(weapon.get("kind", "")) in ["turret", "mine"]:
		base_price = 8 + tier * 2
	var wave := maxi(1, int(_player_summary.get("shop_wave", _current_round_number)))
	var inflation := floori(float(wave) * (0.70 + float(base_price) * 0.05))
	var endless_factor := 1.0 + float(maxi(0, wave - 20)) * 0.015 if bool(_player_summary.get("shop_endless", false)) else 1.0
	return maxi(1, floori(float(floori(float(base_price + inflation) * endless_factor)) * 0.45))


func _on_inventory_item_pressed(record: Dictionary, kind: String, count: int) -> void:
	if kind == "WEAPON":
		_on_weapon_chip_pressed(record)
		return
	var tier := clampi(int(record.get("tier", record.get("rank", 1))), 1, 4)
	_weapon_detail_name.text = String(record.get("name", "Inventory item"))
	_weapon_detail_tier.text = "%s  /  %s" % [_tier_suffix(tier), kind]
	_weapon_detail_icon.texture = record.get("icon") as Texture2D
	_clear_inventory_row(_weapon_detail_stats)
	_weapon_detail_sell.hide()
	_weapon_detail_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_weapon_detail_close.text = I18n.t("SHOP_CLOSE", "CLOSE")
	if kind == "UPGRADE":
		var path := "res://data/upgrades/%s.tres" % String(record.get("id", ""))
		var upgrade := load(path) as UpgradeDefinition if ResourceLoader.exists(path) else null
		_add_detail_stat("Rank", "%d%s" % [count, (" / %d" % upgrade.max_rank) if upgrade != null else ""])
		if upgrade != null:
			_weapon_detail_icon.texture = upgrade.icon
			_add_detail_stat("Effect", _upgrade_effect_summary(upgrade, count))
			if upgrade.unlocks_weapon != null:
				_add_weapon_definition_details(upgrade.unlocks_weapon)
			else:
				_add_detail_stat("Details", upgrade.description)
	else:
		_add_detail_stat("Type", kind.capitalize())
		_add_detail_stat("Owned / active", str(count))
		var definition_path := "res://data/weapons/%s.tres" % String(record.get("id", ""))
		var definition := load(definition_path) as WeaponDefinition if ResourceLoader.exists(definition_path) else null
		if definition != null:
			if _weapon_detail_icon.texture == null:
				_weapon_detail_icon.texture = definition.sprite
			_add_detail_stat("Damage / hit", str(record.get("damage", _weapon_damage_at_tier(definition, tier))))
			_add_detail_stat(_ui_text("Sınıf seti", "Class set"), _describe_class_set(int(record.get("weapon_class", definition.weapon_class)), false))
			_add_detail_stat("Engineering scaling", "×%.2f" % float(record.get("engineering_coefficient", definition.engineering_coefficient)))
			_add_detail_stat("Attack interval", "%.2f s" % float(record.get("fire_interval", definition.fire_interval)))
			_add_detail_stat("Range", "%d px" % roundi(float(record.get("range", definition.target_range))))
			if float(record.get("area", definition.area_radius)) > 0.0:
				_add_detail_stat("Area", "%d px" % roundi(float(record.get("area", definition.area_radius))))
			if float(record.get("duration", definition.effect_duration)) > 0.0:
				_add_detail_stat("Duration", "%.1f s" % float(record.get("duration", definition.effect_duration)))
			if definition.attack_mode == WeaponDefinition.AttackMode.DEPLOYED_TURRET:
				_add_detail_stat("Targeting", "Automatic · nearest enemy")
			elif definition.attack_mode == WeaponDefinition.AttackMode.DEPLOYED_MINE:
				_add_detail_stat("Trigger", "Enemy contact · one blast")
			_add_detail_stat("Effect", definition.description)
	_weapon_detail_overlay.show()
	_weapon_detail_panel.add_theme_stylebox_override("panel", _tier_style(tier))
	_layout_weapon_detail()


func _show_offer_detail(offer: Variant, index: int) -> void:
	_clear_inventory_row(_weapon_detail_stats)
	_weapon_detail_sell.hide()
	_weapon_detail_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_weapon_detail_close.text = I18n.t("SHOP_CLOSE", "CLOSE")
	if offer is WeaponDefinition:
		var weapon := offer as WeaponDefinition
		_weapon_detail_name.text = weapon.display_name
		_weapon_detail_tier.text = "%s  /  %s" % [_tier_suffix(weapon.tier), _weapon_class_name(weapon)]
		_weapon_detail_icon.texture = weapon.sprite
		_add_weapon_definition_details(weapon, weapon.tier)
		_add_detail_stat("Offer price", "%d %s" % [_current_prices[index], I18n.t("SHOP_TOKENS", "stock tokens")])
		_add_detail_stat("Type", _weapon_offer_type(weapon))
		_add_detail_stat("Available from", "Wave %d" % weapon.shop_unlock_wave)
	elif offer is UpgradeDefinition:
		var upgrade := offer as UpgradeDefinition
		_weapon_detail_name.text = upgrade.display_name
		_weapon_detail_tier.text = I18n.t("SHOP_UPGRADE", "SHIFT UPGRADE")
		_weapon_detail_icon.texture = upgrade.icon
		_add_detail_stat("Effect", _upgrade_effect_summary(upgrade, 1))
		_add_detail_stat("Rank limit", str(upgrade.max_rank))
		if upgrade.unlocks_weapon != null:
			_add_weapon_definition_details(upgrade.unlocks_weapon)
		_add_detail_stat("Details", upgrade.description)
		_add_detail_stat("Offer price", "%d %s" % [_current_prices[index], I18n.t("SHOP_TOKENS", "stock tokens")])
	elif offer is Dictionary:
		var stat_offer := offer as Dictionary
		_weapon_detail_name.text = String(stat_offer.get("name", "Shift stat"))
		_weapon_detail_tier.text = I18n.t("SHOP_STAT", "SHIFT STAT")
		_weapon_detail_icon.texture = _stat_offer_icon(stat_offer)
		_add_detail_stat("Change", _format_shop_delta(String(stat_offer.get("id", "")), float(stat_offer.get("value", 0.0))))
		_add_detail_stat("Details", String(stat_offer.get("description", "")))
		_add_detail_stat("Offer price", "%d %s" % [_current_prices[index], I18n.t("SHOP_TOKENS", "stock tokens")])
	_weapon_detail_overlay.show()
	_weapon_detail_panel.add_theme_stylebox_override("panel", _tier_style(_offer_tier(offer)))
	_layout_weapon_detail()


func _add_weapon_definition_details(weapon: WeaponDefinition, tier: int = 1) -> void:
	_add_detail_stat("Weapon class", _weapon_class_name(weapon))
	var class_count := _owned_class_count(int(weapon.weapon_class))
	if not _inventory_has_weapon(weapon.id):
		class_count += 1
	if class_count > 0:
		_add_detail_stat(_ui_text("Alım sonrası sınıf seti", "Class set after purchase"), _describe_class_set(int(weapon.weapon_class), not _inventory_has_weapon(weapon.id)))
	_add_detail_stat("Damage / hit", str(_weapon_damage_at_tier(weapon, tier)))
	_add_detail_stat("Scales from", _scaling_stat_name(weapon.damage_scaling_stat))
	_add_detail_stat("Attack interval", "%.2f s" % maxf(0.05, weapon.fire_interval * pow(0.93, float(maxi(0, tier - 1)))))
	_add_detail_stat("Projectiles", str(_projectile_count_at_tier(weapon)))
	_add_detail_stat("Range", "%d px" % _weapon_range_at_tier(weapon, tier))
	if _weapon_area_at_tier(weapon, tier) > 0:
		_add_detail_stat("Area", "%d px" % _weapon_area_at_tier(weapon, tier))
	if weapon.pierce_count > 0:
		_add_detail_stat("Pierce", str(weapon.pierce_count))
	if weapon.engineering_coefficient > 0.0:
		_add_detail_stat("Engineering scaling", "×%.2f" % weapon.engineering_coefficient)


func _weapon_damage_at_tier(weapon: WeaponDefinition, tier: int = 1) -> int:
	var damage := weapon.damage
	for _tier_index in range(1, clampi(tier, 1, 4)):
		if weapon.id == &"milk_hose":
			damage += 1
		else:
			damage = roundi(float(damage) * 1.2)
	if weapon.attack_mode in [WeaponDefinition.AttackMode.DEPLOYED_TURRET, WeaponDefinition.AttackMode.DEPLOYED_MINE]:
		return maxi(1, damage + roundi(float(int(_player_summary.get("engineering", 0))) * clampf(weapon.engineering_coefficient, 0.0, 2.0)))
	if weapon.elemental_damage_only:
		damage += roundi(float(int(_player_summary.get("elemental_damage", 0))) * clampf(weapon.damage_scaling_coefficient, 0.0, 2.0))
		var elemental_count := _owned_class_count(int(weapon.weapon_class))
		if not _inventory_has_weapon(weapon.id):
			elemental_count += 1
		damage = roundi(float(damage) * (1.0 + WeaponClassCatalog.get_bonus(int(weapon.weapon_class), WeaponClassDefinition.BonusStat.WEAPON_DAMAGE, elemental_count)))
		return maxi(1, damage)
	var scaling_stat := weapon.damage_scaling_stat
	var player_stat := 0
	match scaling_stat:
		WeaponDefinition.DamageScalingStat.MELEE:
			player_stat = int(_player_summary.get("melee_damage", 0))
		WeaponDefinition.DamageScalingStat.RANGED:
			player_stat = int(_player_summary.get("ranged_damage", 0))
		WeaponDefinition.DamageScalingStat.ELEMENTAL:
			player_stat = int(_player_summary.get("elemental_damage", 0))
		WeaponDefinition.DamageScalingStat.ENGINEERING:
			player_stat = int(_player_summary.get("engineering", 0))
	if weapon.damage_scaling_stat != WeaponDefinition.DamageScalingStat.ELEMENTAL or weapon.elemental_damage_only:
		damage += roundi(float(player_stat) * weapon.damage_scaling_coefficient)
	if weapon.damage_type == WeaponDefinition.DamageType.ELEMENTAL and not weapon.elemental_damage_only:
		damage += roundi(float(int(_player_summary.get("elemental_damage", 0))) * weapon.damage_scaling_coefficient)
	var class_count := _owned_class_count(int(weapon.weapon_class))
	if not _inventory_has_weapon(weapon.id):
		class_count += 1
	damage = roundi(float(damage) * (1.0 + WeaponClassCatalog.get_bonus(int(weapon.weapon_class), WeaponClassDefinition.BonusStat.WEAPON_DAMAGE, class_count)))
	var global_bonus := String(_player_summary.get("damage", "+0%")).replace("%", "").replace("+", "").to_float() / 100.0
	return maxi(1, roundi(float(damage) * (1.0 + global_bonus)))


func _owned_class_count(class_id: int) -> int:
	var inventory: Dictionary = _player_summary.get("inventory", {}) if _player_summary.get("inventory", {}) is Dictionary else {}
	var count := 0
	for key: String in ["weapons", "deployables"]:
		for item: Variant in inventory.get(key, []):
			if item is Dictionary and int(item.get("weapon_class", -1)) == class_id:
				count += 1
	return count


func _describe_class_set(class_id: int, adding_item: bool) -> String:
	var class_count := _owned_class_count(class_id)
	if adding_item:
		class_count += 1
	return WeaponClassCatalog.describe_set(class_id, class_count)


func _inventory_has_weapon(weapon_id: StringName) -> bool:
	var inventory: Dictionary = _player_summary.get("inventory", {}) if _player_summary.get("inventory", {}) is Dictionary else {}
	for key: String in ["weapons", "deployables"]:
		for item: Variant in inventory.get(key, []):
			if item is Dictionary and String(item.get("id", "")) == String(weapon_id):
				return true
	return false


func _weapon_range_at_tier(weapon: WeaponDefinition, tier: int) -> int:
	var range_value := weapon.target_range
	for _tier_index in range(2, clampi(tier, 1, 4) + 1):
		if weapon.id == &"box_cutter":
			range_value = minf(118.0, range_value + 7.0)
		elif weapon.attack_mode == WeaponDefinition.AttackMode.DEPLOYED_TURRET:
			range_value += 20.0
		elif weapon.attack_mode == WeaponDefinition.AttackMode.MELEE_SWEEP:
			range_value = minf(220.0, range_value + 8.0)
	return roundi(range_value)


func _weapon_area_at_tier(weapon: WeaponDefinition, tier: int) -> int:
	var area := weapon.area_radius
	if weapon.attack_mode in [WeaponDefinition.AttackMode.ORBITAL_CONTACT, WeaponDefinition.AttackMode.DEPLOYED_SLOW_ZONE, WeaponDefinition.AttackMode.DEPLOYED_MINE, WeaponDefinition.AttackMode.EXPLOSIVE_PROJECTILE]:
		area += 8.0 * float(maxi(0, clampi(tier, 1, 4) - 1))
	return roundi(area)


func _weapon_class_name(weapon: WeaponDefinition) -> String:
	var class_definition := WeaponClassCatalog.get_definition(int(weapon.weapon_class))
	return class_definition.display_name if class_definition != null else "Weapon"


func _scaling_stat_name(stat: int) -> String:
	match stat:
		WeaponDefinition.DamageScalingStat.MELEE: return _ui_text("Yakın Dövüş Hasarı", "Melee Damage")
		WeaponDefinition.DamageScalingStat.RANGED: return _ui_text("Menzilli Hasar", "Ranged Damage")
		WeaponDefinition.DamageScalingStat.ELEMENTAL: return _ui_text("Element Hasarı", "Elemental Damage")
		WeaponDefinition.DamageScalingStat.ENGINEERING: return _ui_text("Mühendislik", "Engineering")
	return _ui_text("Yok", "None")


func _upgrade_effect_summary(upgrade: UpgradeDefinition, rank: int) -> String:
	var value := upgrade.value * float(maxi(1, rank))
	match upgrade.effect:
		UpgradeDefinition.Effect.UNLOCK_WEAPON:
			return "%s %s" % [_ui_text("Aç", "Unlock"), upgrade.unlocks_weapon.display_name if upgrade.unlocks_weapon != null else _ui_text("silah", "weapon")]
		UpgradeDefinition.Effect.WEAPON_DAMAGE_ADD: return "%+d %s" % [roundi(value), _ui_text("silah hasarı", "weapon damage")]
		UpgradeDefinition.Effect.FIRE_RATE_MULTIPLIER: return "%+d%% %s" % [roundi(value * 100.0), _ui_text("saldırı hızı", "attack rate")]
		UpgradeDefinition.Effect.PROJECTILE_COUNT_ADD: return "%+d %s" % [roundi(value), _ui_text("mermi", "projectile(s)")]
		UpgradeDefinition.Effect.PROJECTILE_SPEED_MULTIPLIER: return "%+d%% %s" % [roundi(value * 100.0), _ui_text("mermi hızı", "projectile speed")]
		UpgradeDefinition.Effect.WEAPON_DAMAGE_MULTIPLIER: return "%+d%% %s" % [roundi(value * 100.0), _ui_text("silah hasarı", "weapon damage")]
		UpgradeDefinition.Effect.WEAPON_PIERCE_ADD: return "%+d %s" % [roundi(value), _ui_text("delme", "pierce")]
		UpgradeDefinition.Effect.WEAPON_RADIUS_ADD: return "%+d px %s" % [roundi(value), _ui_text("alan", "area")]
		UpgradeDefinition.Effect.PLAYER_MOVE_SPEED_MULTIPLIER: return "%+d%% %s" % [roundi(value * 100.0), _ui_text("hareket hızı", "movement speed")]
		UpgradeDefinition.Effect.PLAYER_MAX_HEALTH_ADD: return "%+d %s · %d %s" % [roundi(value), _ui_text("maks. CAN", "max HP"), roundi(upgrade.immediate_heal), _ui_text("hemen iyileşme", "heal now")]
		UpgradeDefinition.Effect.PLAYER_LIFESTEAL_ADD: return "%+d%% %s" % [roundi(value * 100.0), _ui_text("can çalma", "lifesteal")]
		UpgradeDefinition.Effect.PLAYER_DODGE_ADD: return "%+d%% %s" % [roundi(value * 100.0), _ui_text("kaçınma", "dodge")]
		UpgradeDefinition.Effect.PLAYER_ENGINEERING_ADD: return "%+d %s" % [roundi(value), _ui_text("mühendislik", "engineering")]
		UpgradeDefinition.Effect.WEAPON_REACH_ADD: return "%+d px %s" % [roundi(value), _ui_text("erişim", "reach")]
	return upgrade.description


func _format_shop_delta(stat_id: String, value: float) -> String:
	var label := stat_id.replace("_", " ").capitalize()
	var percent := stat_id in ["speed", "lifesteal", "dodge", "protection"]
	var localized := _ui_text(label, label)
	return ("%+d%% %s" % [roundi(value * 100.0), localized]) if percent else ("%+d %s" % [roundi(value), localized])


func _stat_offer_icon(offer: Dictionary) -> Texture2D:
	var id := String(offer.get("id", ""))
	var path := "res://assets/generated/shop_icons/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return load("res://assets/generated/pickups/pickup_stock_bundle.png") as Texture2D


func _weapon_offer_type(weapon: WeaponDefinition) -> String:
	match weapon.shop_offer_kind:
		WeaponDefinition.ShopOfferKind.NEW_WEAPON: return "New weapon"
		WeaponDefinition.ShopOfferKind.MERGE_COPY: return "Merge copy"
		WeaponDefinition.ShopOfferKind.DIRECT_TIER: return "Direct tier upgrade"
		WeaponDefinition.ShopOfferKind.DEPLOYABLE_COPY: return "Additional deployable"
	return "Weapon"


func inventory_weapon_count() -> int:
	var inventory: Dictionary = _player_summary.get("inventory", {})
	return (inventory.get("weapons", []) as Array).size()


func _on_weapon_sell_confirmed() -> void:
	if _selected_weapon_id != &"":
		weapon_sell_requested.emit(_selected_weapon_id)
		_selected_weapon_id = &""
		_selected_weapon.clear()
		_weapon_detail_overlay.hide()


func _build_weapon_detail_overlay(parent: Control) -> void:
	_weapon_detail_overlay = Control.new()
	_weapon_detail_overlay.name = "WeaponDetailReceipt"
	_weapon_detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_weapon_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_weapon_detail_overlay.visible = false
	_weapon_detail_overlay.z_index = 100
	parent.add_child(_weapon_detail_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.055, 0.052, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_weapon_detail_overlay.add_child(shade)
	_weapon_detail_panel = PanelContainer.new()
	_weapon_detail_panel.name = "DetailReceipt"
	_weapon_detail_panel.anchor_left = 0.5
	_weapon_detail_panel.anchor_right = 0.5
	_weapon_detail_panel.anchor_top = 0.5
	_weapon_detail_panel.anchor_bottom = 0.5
	_weapon_detail_panel.add_theme_stylebox_override("panel", _style(PANEL, GOLD, 1, 2))
	_weapon_detail_overlay.add_child(_weapon_detail_panel)
	_weapon_detail_clip = ReceiptClamp.new()
	_weapon_detail_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_detail_overlay.add_child(_weapon_detail_clip)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	_weapon_detail_panel.add_child(_margin(body, 14))
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 14)
	if OS.has_feature("portmaster"):
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(heading)
	_weapon_detail_icon = TextureRect.new()
	_weapon_detail_icon.custom_minimum_size = Vector2(68, 68)
	_weapon_detail_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_weapon_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	heading.add_child(_center_control(_weapon_detail_icon))
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if OS.has_feature("portmaster"):
		title_stack.custom_minimum_size.x = 240.0
	title_stack.add_theme_constant_override("separation", 3)
	heading.add_child(title_stack)
	_weapon_detail_tier = _label("TIER II  /  SELECTED WEAPON", 14, GOLD)
	_weapon_detail_name = _label("Weapon", 28, TEXT)
	_weapon_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if OS.has_feature("portmaster"):
		_weapon_detail_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_child(_weapon_detail_tier)
	title_stack.add_child(_weapon_detail_name)
	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", _line_style(GOLD))
	body.add_child(divider)
	_weapon_detail_stats = VBoxContainer.new()
	_weapon_detail_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_detail_stats.add_theme_constant_override("separation", 4)
	var stats_scroll := ScrollContainer.new()
	stats_scroll.name = "WeaponDetailScroll"
	stats_scroll.custom_minimum_size.y = 92
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stats_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	stats_scroll.add_child(_weapon_detail_stats)
	body.add_child(stats_scroll)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	body.add_child(actions)
	_weapon_detail_sell = _button("Sell", true)
	_weapon_detail_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_detail_sell.pressed.connect(_on_weapon_sell_confirmed)
	actions.add_child(_weapon_detail_sell)
	_weapon_detail_close = _button("Close", false)
	_weapon_detail_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_weapon_detail_close.custom_minimum_size.x = 180.0
	_weapon_detail_close.pressed.connect(_close_weapon_detail)
	actions.add_child(_weapon_detail_close)
	get_viewport().size_changed.connect(_layout_weapon_detail)


func _build_inventory_overlay(parent: Control) -> void:
	_inventory_overlay = Control.new()
	_inventory_overlay.name = "InventoryReceipt"
	_inventory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inventory_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_overlay.visible = false
	_inventory_overlay.z_index = 100
	parent.add_child(_inventory_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.055, 0.052, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_overlay.add_child(shade)
	_inventory_panel = PanelContainer.new()
	_inventory_panel.anchor_left = 0.5
	_inventory_panel.anchor_right = 0.5
	_inventory_panel.anchor_top = 0.5
	_inventory_panel.anchor_bottom = 0.5
	_inventory_panel.add_theme_stylebox_override("panel", _style(PANEL, PANEL_EDGE, 0, 2))
	_inventory_overlay.add_child(_inventory_panel)
	_inventory_clip = ReceiptClamp.new()
	_inventory_overlay.add_child(_inventory_clip)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_inventory_panel.add_child(_margin(content, 14))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)
	var title := _label(_ui_text("ENVANTER", "INVENTORY"), 30, TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := _button(I18n.t("SHOP_CLOSE", "KAPAT"), false)
	close.custom_minimum_size = Vector2(140, 54 if _is_mobile_platform() and not OS.has_feature("portmaster") else 46)
	close.pressed.connect(_close_inventory)
	_inventory_close_button = close
	header.add_child(close)
	var subtitle := _label(_ui_text("Tüm yükseltmeler ve konuşlandırılanlar silah yuvalarından ayrı tutulur.", "All upgrades and deployables are tracked separately from weapon slots."), 15, MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(subtitle)
	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", _line_style(PANEL_EDGE))
	content.add_child(divider)
	var scroll := ScrollContainer.new()
	scroll.name = "InventoryScroll"
	scroll.custom_minimum_size.y = 180
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	content.add_child(scroll)
	_inventory_items_list = VBoxContainer.new()
	_inventory_items_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_items_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_inventory_items_list)
	get_viewport().size_changed.connect(_layout_inventory_overlay)
	_layout_inventory_overlay()


func _layout_inventory_overlay() -> void:
	if not is_instance_valid(_inventory_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := _safe_insets(viewport_size)
	var usable_width := maxf(280.0, viewport_size.x - safe.x - safe.z)
	var usable_height := maxf(240.0, viewport_size.y - safe.y - safe.w)
	var panel_width := minf(860.0, usable_width * 0.92)
	var inventory: Dictionary = _player_summary.get("inventory", {}) if _player_summary.get("inventory", {}) is Dictionary else {}
	var entry_count := (inventory.get("upgrades", []) as Array).size() + (inventory.get("deployables", []) as Array).size()
	var entry_height := 54.0 if _is_mobile_platform() and not OS.has_feature("portmaster") else _touch_target_size(viewport_size)
	var desired_height := maxf(300.0, 270.0 + float(entry_count) * maxf(58.0, entry_height + 8.0))
	var panel_height := minf(desired_height, minf(760.0, usable_height * 0.86))
	_inventory_panel.offset_left = -panel_width * 0.5 + (safe.x - safe.z) * 0.5
	_inventory_panel.offset_right = panel_width * 0.5 + (safe.x - safe.z) * 0.5
	_inventory_panel.offset_top = -panel_height * 0.5 + (safe.y - safe.w) * 0.5
	_inventory_panel.offset_bottom = panel_height * 0.5 + (safe.y - safe.w) * 0.5
	_inventory_clip.size = Vector2(170.0, 42.0)
	_inventory_clip.position = Vector2(viewport_size.x * 0.5 - 85.0 + (safe.x - safe.z) * 0.5, viewport_size.y * 0.5 - panel_height * 0.5 + (safe.y - safe.w) * 0.5 - 14.0)
	_inventory_clip.queue_redraw()


func _open_inventory() -> void:
	_rebuild_inventory_contents()
	_layout_inventory_overlay()
	_inventory_overlay.show()
	var first_button := _inventory_items_list.find_child("InventoryEntry", true, false) as Button
	if is_instance_valid(first_button):
		first_button.grab_focus.call_deferred()


func _rebuild_inventory_contents() -> void:
	_clear_inventory_row(_inventory_items_list)
	var inventory: Dictionary = _player_summary.get("inventory", {}) if _player_summary.get("inventory", {}) is Dictionary else {}
	var upgrades: Array = inventory.get("upgrades", [])
	var deployables: Array = inventory.get("deployables", [])
	_add_inventory_section(_ui_text("YÜKSELTMELER", "UPGRADES"), upgrades, "UPGRADE", "rank")
	_add_inventory_section(_ui_text("KONUŞLANDIRILANLAR", "DEPLOYABLES"), deployables, "DEPLOYABLE", "count")
	if upgrades.is_empty() and deployables.is_empty():
		var empty := _label(_ui_text("Henüz yükseltme veya konuşlandırılan yok. Market teklifleri dalga sonunda açılır.", "No upgrades or deployables yet. Shop offers appear after each wave."), 17, MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_inventory_items_list.add_child(empty)


func _add_inventory_section(section_title: String, records: Array, default_kind: String, count_key: String) -> void:
	if records.is_empty():
		return
	var heading := _label(section_title, 18, RED)
	_inventory_items_list.add_child(heading)
	for record_value: Variant in records:
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		var kind := String(record.get("kind", default_kind)).to_upper()
		var count := int(record.get(count_key, 0))
		var tier := clampi(int(record.get("tier", record.get("rank", 1))), 1, 4)
		var entry := Button.new()
		entry.name = "InventoryEntry"
		entry.custom_minimum_size.y = maxf(58.0, 54.0 if _is_mobile_platform() and not OS.has_feature("portmaster") else _touch_target_size(get_viewport().get_visible_rect().size))
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.focus_mode = Control.FOCUS_ALL
		entry.add_theme_stylebox_override("normal", _tier_style(tier))
		var hover := _tier_style(tier).duplicate() as StyleBoxFlat
		hover.border_color = RED
		hover.set_border_width_all(3)
		entry.add_theme_stylebox_override("hover", hover)
		entry.add_theme_color_override("font_color", TEXT)
		entry.add_theme_color_override("font_hover_color", TEXT)
		entry.add_theme_font_override("font", display_font)
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10
		row.offset_top = 4
		row.offset_right = -10
		row.offset_bottom = -4
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(row)
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(42, 42)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := record.get("icon") as Texture2D
		if icon == null and kind == "UPGRADE":
			var path := "res://data/upgrades/%s.tres" % String(record.get("id", ""))
			if ResourceLoader.exists(path):
				var upgrade := load(path) as UpgradeDefinition
				icon = upgrade.icon if upgrade != null else null
		icon_rect.texture = icon
		row.add_child(icon_rect)
		var item_copy := VBoxContainer.new()
		item_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_copy.add_theme_constant_override("separation", 2)
		row.add_child(item_copy)
		var item_name := _label(String(record.get("name", String(record.get("id", "Item")).replace("_", " ").capitalize())), 17, TEXT)
		item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_copy.add_child(item_name)
		var item_value := _label(_inventory_item_summary(record, kind, count), 13, MUTED)
		item_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_copy.add_child(item_value)
		var badge_text := ("R%d" % count) if kind == "UPGRADE" else ("×%d" % maxi(0, count))
		var badge := _label(badge_text, 15, TEXT)
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(badge)
		entry.pressed.connect(_on_inventory_entry_pressed.bind(record, kind, count))
		_inventory_items_list.add_child(entry)


func _on_inventory_entry_pressed(record: Dictionary, kind: String, count: int) -> void:
	_inventory_overlay.hide()
	_on_inventory_item_pressed(record, kind, count)


func _inventory_item_summary(record: Dictionary, kind: String, count: int) -> String:
	if kind == "UPGRADE":
		var path := "res://data/upgrades/%s.tres" % String(record.get("id", ""))
		if ResourceLoader.exists(path):
			var upgrade := load(path) as UpgradeDefinition
			if upgrade != null:
				return _upgrade_effect_summary(upgrade, count)
	return "%s  ·  %s %s %d" % [String(record.get("weapon_class_name", kind.capitalize())), _tier_suffix(int(record.get("tier", 1))), _ui_text("ADET", "COUNT") if kind != "UPGRADE" else _ui_text("RÜTBE", "RANK"), count]


func _layout_weapon_detail() -> void:
	if not is_instance_valid(_weapon_detail_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := _safe_insets(viewport_size)
	var usable_width := maxf(280.0, viewport_size.x - safe.x - safe.z)
	var usable_height := maxf(240.0, viewport_size.y - safe.y - safe.w)
	var width := minf(640.0, usable_width * 0.88)
	var mobile := _is_mobile_platform() and not OS.has_feature("portmaster")
	width = minf(900.0 if mobile else 640.0, usable_width * (0.92 if mobile else 0.88))
	var height := minf(600.0 if mobile else 480.0, usable_height * 0.88)
	_weapon_detail_panel.offset_left = -width * 0.5 + (safe.x - safe.z) * 0.5
	_weapon_detail_panel.offset_right = width * 0.5 + (safe.x - safe.z) * 0.5
	_weapon_detail_panel.offset_top = -height * 0.5 + (safe.y - safe.w) * 0.5
	_weapon_detail_panel.offset_bottom = height * 0.5 + (safe.y - safe.w) * 0.5
	var detail_content_width := maxf(220.0, width - 56.0)
	var stats_scroll := _weapon_detail_overlay.find_child("WeaponDetailScroll", true, false) as ScrollContainer
	if is_instance_valid(stats_scroll):
		stats_scroll.custom_minimum_size.x = detail_content_width
		stats_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_detail_stats.custom_minimum_size.x = detail_content_width
	_weapon_detail_clip.size = Vector2(170.0, 42.0)
	_weapon_detail_clip.position = Vector2(viewport_size.x * 0.5 - 85.0 + (safe.x - safe.z) * 0.5, viewport_size.y * 0.5 - height * 0.5 + (safe.y - safe.w) * 0.5 - 14.0)
	_weapon_detail_clip.queue_redraw()
	var compact := viewport_size.y <= 500.0
	_weapon_detail_icon.custom_minimum_size = Vector2(52, 52) if compact else Vector2(68, 68)
	_weapon_detail_name.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 25.0)) if _is_mobile_platform() else 28)
	_weapon_detail_sell.custom_minimum_size.y = _touch_target_size(viewport_size) if _is_mobile_platform() else 46
	_weapon_detail_close.custom_minimum_size.y = _touch_target_size(viewport_size) if _is_mobile_platform() else 46
	if _is_mobile_platform() and not OS.has_feature("portmaster"):
		_weapon_detail_close.custom_minimum_size.y = 54.0
		_weapon_detail_sell.custom_minimum_size.y = 54.0
	_weapon_detail_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_weapon_detail_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_weapon_detail_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_weapon_detail_tier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_detail_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _close_weapon_detail() -> void:
	if is_instance_valid(_weapon_detail_overlay):
		_weapon_detail_overlay.hide()
	if is_instance_valid(_continue_button) and _continue_button.is_inside_tree():
		_continue_button.grab_focus.call_deferred()


func _close_inventory() -> void:
	if is_instance_valid(_inventory_overlay):
		_inventory_overlay.hide()
	if is_instance_valid(_inventory_open_button) and _inventory_open_button.is_inside_tree():
		_inventory_open_button.grab_focus.call_deferred()


func _add_detail_stat(stat_name: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.x = maxf(220.0, _weapon_detail_panel.size.x - 56.0) if is_instance_valid(_weapon_detail_panel) else 0.0
	var name_label := _label(stat_name, 17, MUTED)
	name_label.custom_minimum_size.x = clampf(get_viewport().get_visible_rect().size.x * 0.20, 150.0, 280.0)
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var value_label := _label(value, 18, TEXT)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.custom_minimum_size.x = 180.0
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_label)
	row.add_child(value_label)
	_weapon_detail_stats.add_child(row)


func _line_style(color: Color) -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = color
	line.thickness = 1
	return line


func _tier_suffix(tier: int) -> String:
	var tiers := ["I", "II", "III", "IV"]
	return tiers[clampi(tier, 1, 4) - 1]


func _rebuild_offer_cards() -> void:
	for child: Node in _cards_row.get_children():
		_cards_row.remove_child(child)
		child.queue_free()

	var card_count: int = mini(_current_offers.size(), MAX_OFFERS)
	if card_count == 0:
		var empty_panel := PanelContainer.new()
		empty_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_panel.add_theme_stylebox_override("panel", _style(CARD, PANEL_EDGE, 4, 1))
		var empty_message := _label("The shelf is empty. Return to the aisles to continue.", 16, MUTED)
		empty_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_panel.add_child(empty_message)
		_cards_row.add_child(empty_panel)
		return

	for index: int in range(card_count):
		var card := _make_offer_card(index, _current_offers[index])
		_cards_row.add_child(card)


func _make_offer_card(index: int, offer: Variant) -> Control:
	var card := PanelContainer.new()
	var viewport_size := get_viewport().get_visible_rect().size
	var mobile := _is_mobile_platform()
	var portmaster := OS.has_feature("portmaster")
	var layout_scale := _mobile_layout_scale(viewport_size)
	var card_height := maxf(268.0, viewport_size.y * 0.40) if portmaster else (maxf(318.0, viewport_size.y * 0.39) if mobile else clampf(viewport_size.y * 0.46, 430.0, 510.0))
	card.custom_minimum_size = Vector2(0, card_height)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.0
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _tier_offer_style(_offer_tier(offer)))

	var margins := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, roundi(8.0 * layout_scale) if mobile else 14)
	card.add_child(margins)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", roundi(6.0 * layout_scale) if mobile else 8)
	margins.add_child(stack)

	var type_name := I18n.t("SHOP_UPGRADE", "SHIFT UPGRADE")
	var display_name := "Unavailable offer"
	var description := "This item cannot be displayed."
	var purchase_text := "BUY OFFER"
	var texture: Texture2D
	var resource_valid := false
	if offer is WeaponDefinition:
		var weapon := offer as WeaponDefinition
		var tier_name := _format_tier(weapon.tier)
		var deployable_kind := "TURRET" if weapon.attack_mode == WeaponDefinition.AttackMode.DEPLOYED_TURRET else ("MINE" if weapon.attack_mode == WeaponDefinition.AttackMode.DEPLOYED_MINE else "")
		match weapon.shop_offer_kind:
			WeaponDefinition.ShopOfferKind.MERGE_COPY:
				type_name = "%s COPY / MERGE  ·  %s" % ["SKILL · " + deployable_kind if not deployable_kind.is_empty() else "WEAPON", tier_name]
				purchase_text = I18n.t("SHOP_MERGE", "MERGE COPY")
			WeaponDefinition.ShopOfferKind.DIRECT_TIER:
				type_name = "%s DIRECT %s" % ["SKILL · " + deployable_kind if not deployable_kind.is_empty() else "WEAPON", tier_name]
				purchase_text = "BUY %s" % tier_name
			WeaponDefinition.ShopOfferKind.DEPLOYABLE_COPY:
				type_name = "EXTRA %s  ·  %s" % [deployable_kind, tier_name]
				purchase_text = "BUY EXTRA"
			_:
				type_name = "%s · %s · %s" % [_ui_text("YENİ YETENEK", "NEW SKILL"), deployable_kind, tier_name] if not deployable_kind.is_empty() else "%s · %s" % [I18n.t("SHOP_NEW_WEAPON", "NEW WEAPON"), tier_name]
				purchase_text = "BUY WEAPON"
		var class_definition := WeaponClassCatalog.get_definition(int(weapon.weapon_class))
		if class_definition != null:
			type_name += " · " + class_definition.display_name.to_upper()
		display_name = weapon.display_name
		description = weapon.description
		texture = weapon.sprite
		resource_valid = true
	elif offer is UpgradeDefinition:
		var upgrade := offer as UpgradeDefinition
		type_name = I18n.t("SHOP_UPGRADE", "SHIFT UPGRADE")
		display_name = upgrade.display_name
		description = upgrade.description
		texture = upgrade.icon
		resource_valid = true
	elif offer is Dictionary:
		var stat_offer := offer as Dictionary
		if String(stat_offer.get("kind", "")) == "stat" and not String(stat_offer.get("id", "")).is_empty():
			var stat_id := String(stat_offer.get("id", ""))
			type_name = I18n.t("SHOP_STAT", "SHIFT STAT")
			display_name = String(stat_offer.get("name", "Shift stat"))
			description = String(stat_offer.get("description", "A lasting shift adjustment."))
			resource_valid = true
			match stat_id:
				"melee_damage":
					texture = load("res://assets/generated/weapons/box_cutter.png") as Texture2D
				"ranged_damage":
					texture = load("res://assets/generated/weapons/projectile_tomato_can.png") as Texture2D
				"elemental_damage":
					texture = load("res://assets/generated/weapons/milk_hose.svg") as Texture2D
				"engineering":
					texture = load("res://assets/generated/content_pack/engineering_caddy.png") as Texture2D
				"speed":
					texture = load("res://assets/generated/shop_icons/comfortable_shoes.png") as Texture2D
				"health":
					texture = load("res://assets/generated/pickups/pickup_health_bag.png") as Texture2D
				"lifesteal":
					texture = load("res://assets/generated/pickups/pickup_energy_can.png") as Texture2D
				"dodge":
					texture = load("res://assets/generated/shop_icons/longer_shift.png") as Texture2D
				"protection":
					texture = load("res://assets/generated/shop_icons/fresh_apron.png") as Texture2D
				_:
					texture = load("res://assets/generated/pickups/pickup_stock_bundle.png") as Texture2D

	if texture == null:
		texture = load("res://assets/generated/pickups/pickup_stock_bundle.png") as Texture2D

	var mobile_type_size := _mobile_shop_font(viewport_size, 16.0)
	var mobile_body_size := _mobile_shop_font(viewport_size, 19.0)
	var type_label := _label("SHELF %02d   /   %s" % [index + 1, type_name], 17, GOLD)
	if mobile:
		type_label.add_theme_font_size_override("font_size", roundi(mobile_type_size))
		type_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	type_label.autowrap_mode = TextServer.AUTOWRAP_OFF if mobile else TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(type_label)
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(0, (88.0 * layout_scale) if mobile else (112 if viewport_size.y <= 800.0 else 136))
	icon_panel.add_theme_stylebox_override("panel", _style(Color("e5e0cd"), PANEL_EDGE, 0, 1))
	stack.add_child(icon_panel)
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(64, 64) * layout_scale if mobile else (Vector2(76, 76) if viewport_size.y <= 800.0 else Vector2(96, 96))
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 10
		icon.offset_right = -10
		icon.offset_top = 8
		icon.offset_bottom = -8
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_panel.add_child(icon)

	var title := _label(display_name, 28, TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	title.custom_minimum_size.y = (44.0 * layout_scale) if mobile else 48
	if mobile:
		title.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 30.0)))
	stack.add_child(title)
	var detail := _label(description, 19, MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if mobile:
		detail.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 20.0)))
	stack.add_child(detail)
	var offer_value_lines := _offer_value_lines(offer)
	var values := _label("\n".join(offer_value_lines), 17, TEXT)
	values.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	values.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	values.custom_minimum_size.y = maxf(26.0, float(offer_value_lines.size()) * (21.0 if mobile else 22.0))
	if mobile:
		values.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 17.0)))
	stack.add_child(values)

	var is_purchased := _purchased_indices.has(index)
	var price: int = _current_prices[index] if index < _current_prices.size() else -1
	var price_text := I18n.t("SHOP_PURCHASED", "SATIN ALINDI") if is_purchased else ("%d " % price + I18n.t("SHOP_TOKENS", "stok jetonu") if price >= 0 else "---")
	var price_label := _label(price_text, 20, TEAL if is_purchased else (GOLD if price >= 0 else MUTED))
	price_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if mobile:
		price_label.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 21.0)))
	stack.add_child(price_label)

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", roundi(5.0 * layout_scale) if mobile else 6)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(actions)
	var secondary_actions := HBoxContainer.new()
	secondary_actions.add_theme_constant_override("separation", 6)
	actions.add_child(secondary_actions)
	var details_button := _button(I18n.t("SHOP_DETAILS", "DETAYLAR"), false)
	details_button.custom_minimum_size.y = (54.0 if mobile and not portmaster else _touch_target_size(viewport_size)) if mobile else 38
	details_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_button.pressed.connect(_show_offer_detail.bind(offer, index))
	secondary_actions.add_child(details_button)
	var lock_button := _button(I18n.t("SHOP_LOCK", "KİLİTLE") if not _locked_indices.has(index) else I18n.t("SHOP_UNLOCK", "KİLİDİ AÇ"), false)
	lock_button.custom_minimum_size.y = details_button.custom_minimum_size.y
	lock_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock_button.pressed.connect(_on_offer_lock_pressed.bind(index))
	secondary_actions.add_child(lock_button)
	var buy_button := _button(purchase_text, true)
	buy_button.custom_minimum_size.y = (54.0 if mobile and not portmaster else _touch_target_size(viewport_size)) if mobile else 48
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_purchased:
		buy_button.text = I18n.t("SHOP_PURCHASED", "SATIN ALINDI")
		buy_button.disabled = true
		card.modulate = Color(0.65, 0.75, 0.75, 0.85)
	else:
		buy_button.text = I18n.t("SHOP_BUY", "Satın Al") if resource_valid else "Unavailable"
		buy_button.disabled = not resource_valid or price < 0 or price > _current_currency
		buy_button.pressed.connect(_on_offer_pressed.bind(index, buy_button))
		card.modulate = Color.WHITE
	actions.add_child(buy_button)
	return card


func _on_offer_pressed(index: int, button: Button) -> void:
	button.disabled = true
	button.text = I18n.t("SHOP_PURCHASED", "SATIN ALINDI")
	if not _purchased_indices.has(index):
		_purchased_indices.append(index)
	offer_purchased.emit(index)


func _on_reroll_pressed() -> void:
	_reroll_button.disabled = true
	reroll_requested.emit()


func _on_offer_lock_pressed(index: int) -> void:
	var locked := not _locked_indices.has(index)
	if locked:
		_locked_indices.append(index)
	else:
		_locked_indices.erase(index)
	offer_lock_toggled.emit(index, locked)


func _on_continue_pressed() -> void:
	continue_requested.emit()


func _format_tier(tier: int) -> String:
	match clampi(tier, 1, 4):
		1:
			return "TIER I"
		2:
			return "TIER II"
		3:
			return "TIER III"
		_:
			return "TIER IV"


func _ui_text(turkish: String, english: String) -> String:
	return turkish if I18n.current_locale == "tr" else english


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", _responsive_font_size(17))
	button.add_theme_color_override("font_color", PANEL if primary else TEXT)
	button.add_theme_color_override("font_hover_color", PANEL if primary else RED)
	button.add_theme_color_override("font_focus_color", PANEL if primary else TEXT)
	button.add_theme_color_override("font_pressed_color", PANEL)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(RED if primary else CARD, RED.darkened(0.2) if primary else PANEL_EDGE, 0, 1))
	button.add_theme_stylebox_override("hover", _style(RED.lightened(0.1) if primary else Color("fffdf4"), GOLD, 0, 2))
	button.add_theme_stylebox_override("pressed", _style(Color("d8e5d2"), TEAL, 0, 2))
	button.add_theme_stylebox_override("disabled", _style(Color("ded9c7"), PANEL_EDGE, 0, 1))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, TEAL, 0, 2))
	if display_font != null:
		button.add_theme_font_override("font", display_font)
	return button


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", _responsive_font_size(size))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	if display_font != null:
		label.add_theme_font_override("font", display_font)
	return label


func _responsive_font_size(size: int) -> int:
	if OS.has_feature("portmaster"):
		return roundi(float(size) * 1.15)
	if _is_mobile_platform():
		var viewport_size := get_viewport().get_visible_rect().size
		return maxi(12, roundi(float(size) * clampf(viewport_size.y / 1080.0, 0.75, 1.0)))
	var window_width := float(get_window().size.x) if get_window() != null else 1920.0
	return roundi(float(size) * clampf(1920.0 / maxf(window_width, 1.0), 1.0, 1.4))


func _is_mobile_platform() -> bool:
	return OS.has_feature("portmaster") or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()


func _mobile_density_scale(viewport_size: Vector2) -> float:
	if OS.has_feature("portmaster"):
		return 1.0
	var window_width := float(get_window().size.x) if get_window() != null else viewport_size.x
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		dpi = 160.0 if _is_mobile_platform() else 96.0
	return clampf(dpi / 160.0 * viewport_size.x / maxf(window_width, 1.0), 1.0, 4.0)


func _safe_insets(viewport_size: Vector2) -> Vector4:
	if not _is_mobile_platform() or get_window() == null:
		return Vector4.ZERO
	var area := DisplayServer.get_display_safe_area()
	var pos := DisplayServer.window_get_position()
	var win := get_window().size
	if area.size.x <= 0 or area.size.y <= 0 or win.x <= 0 or win.y <= 0:
		return Vector4.ZERO
	var sx := viewport_size.x / float(win.x)
	var sy := viewport_size.y / float(win.y)
	return Vector4(clampf(float(area.position.x - pos.x), 0.0, float(win.x)) * sx, clampf(float(area.position.y - pos.y), 0.0, float(win.y)) * sy, clampf(float(pos.x + win.x - area.end.x), 0.0, float(win.x)) * sx, clampf(float(pos.y + win.y - area.end.y), 0.0, float(win.y)) * sy)


func _touch_target_size(viewport_size: Vector2) -> float:
	return 48.0 * _mobile_density_scale(viewport_size)


func _mobile_shop_font(viewport_size: Vector2, preferred: float) -> float:
	if OS.has_feature("portmaster"):
		return minf(maxf(19.0, viewport_size.y * 0.030), preferred)
	# Use the available landscape height as a stable cap; the OS density scale
	# otherwise makes text enormous on high-DPI phones running a 1920-wide canvas.
	return clampf(viewport_size.y * 0.024, 17.0, preferred)


func _mobile_layout_scale(viewport_size: Vector2) -> float:
	return clampf(viewport_size.y / 1080.0, 0.75, 1.0)


func _center_control(control: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(control)
	return center


func _margin(child: Control, amount: int) -> MarginContainer:
	var margins := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, amount)
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
	box.content_margin_left = 10
	box.content_margin_top = 8
	box.content_margin_right = 10
	box.content_margin_bottom = 8
	_styles[key] = box
	return box
