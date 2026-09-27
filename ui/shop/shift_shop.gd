extends CanvasLayer
class_name ShiftShop

signal offer_purchased(index: int)
signal reroll_requested
signal continue_requested

@export var display_font: FontFile

const INK := Color("101820")
const PANEL := Color("1a2b30", 0.98)
const PANEL_EDGE := Color("71847d")
const TEXT := Color("f1e7ce")
const MUTED := Color("a6b5ae")
const TEAL := Color("79c8b7")
const GOLD := Color("d4e36d")
const CARD := Color("22363b")
const MAX_OFFERS := 3

var _round_label: Label
var _currency_label: Label
var _title_label: Label
var _subline_label: Label
var _note_label: Label
var _cards_row: HBoxContainer
var _reroll_button: Button
var _continue_button: Button
var _styles: Dictionary = {}
var _current_currency: int = 0
var _current_offers: Array = []
var _current_prices: Array[int] = []
var _current_reroll_cost: int = 0
var _current_round_number: int = 0
var _should_show: bool = false
var _purchased_indices: Array[int] = []


func _ready() -> void:
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


func show_shop(round_number: int, currency: int, offers: Array, prices: Array[int], reroll_cost: int, purchased_indices: Array = []) -> void:
	_current_round_number = maxi(0, round_number)
	_should_show = true
	set_shop_state(currency, offers, prices, reroll_cost, purchased_indices)
	visible = true
	if is_instance_valid(_continue_button):
		_continue_button.grab_focus.call_deferred()


func set_shop_state(currency: int, offers: Array, prices: Array[int], reroll_cost: int, purchased_indices: Array = []) -> void:
	_current_currency = maxi(0, currency)
	_current_offers = offers.duplicate()
	_current_prices = prices.duplicate()
	_current_reroll_cost = maxi(0, reroll_cost)
	_purchased_indices.clear()
	for idx in purchased_indices:
		_purchased_indices.append(int(idx))
	if not is_instance_valid(_cards_row):
		return
	_update_shop_texts()
	_rebuild_offer_cards()


func _update_shop_texts() -> void:
	if is_instance_valid(_round_label):
		_round_label.text = I18n.t("SHOP_WAVE_COMPLETE", "WAVE %02d COMPLETE") % _current_round_number
	if is_instance_valid(_title_label):
		_title_label.text = I18n.t("SHOP_TITLE", "The stockroom")
	if is_instance_valid(_subline_label):
		_subline_label.text = I18n.t("SHOP_SUBTITLE", "Pick supplies for the next wave, or head back to the aisles.")
	if is_instance_valid(_currency_label):
		_currency_label.text = "%d  " % _current_currency + I18n.t("SHOP_TOKENS", "stock tokens")
	if is_instance_valid(_reroll_button):
		_reroll_button.text = I18n.t("SHOP_REFRESH", "Refresh shelf (%d)") % _current_reroll_cost
		_reroll_button.disabled = _current_currency < _current_reroll_cost
	if is_instance_valid(_note_label):
		_note_label.text = I18n.t("SHOP_NOTE", "Offers restock after each wave.")
	if is_instance_valid(_continue_button):
		_continue_button.text = I18n.t("SHOP_RETURN", "Return to aisles")


func _build_shop() -> void:
	var root := Control.new()
	root.name = "ShopRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.075, 0.09, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "ShopPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -620.0
	panel.offset_right = 620.0
	panel.offset_top = -360.0
	panel.offset_bottom = 360.0
	panel.add_theme_stylebox_override("panel", _style(PANEL, GOLD, 6, 2))
	root.add_child(panel)

	var margins := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margins)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margins.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	content.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.add_theme_constant_override("separation", 4)
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_stack)
	_round_label = _label("WAVE 00 COMPLETE", 14, GOLD)
	title_stack.add_child(_round_label)
	_title_label = _label("The stockroom", 34, TEXT)
	title_stack.add_child(_title_label)
	_subline_label = _label("Pick supplies for the next wave, or head back to the aisles.", 15, MUTED)
	title_stack.add_child(_subline_label)

	var balance_panel := PanelContainer.new()
	balance_panel.custom_minimum_size = Vector2(250, 72)
	balance_panel.add_theme_stylebox_override("panel", _style(INK, PANEL_EDGE, 5, 1))
	header.add_child(balance_panel)
	var balance_margins := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		balance_margins.add_theme_constant_override("margin_" + side, 14)
	balance_panel.add_child(balance_margins)
	_currency_label = _label("00  stock tokens", 18, GOLD)
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_margins.add_child(_center_control(_currency_label))

	var divider := HSeparator.new()
	var divider_style := StyleBoxLine.new()
	divider_style.color = PANEL_EDGE
	divider_style.thickness = 1
	divider.add_theme_stylebox_override("separator", divider_style)
	content.add_child(divider)

	_cards_row = HBoxContainer.new()
	_cards_row.name = "OfferCards"
	_cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_row.add_theme_constant_override("separation", 16)
	content.add_child(_cards_row)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	content.add_child(footer)

	_reroll_button = _button("Refresh shelf   /   0", false)
	_reroll_button.custom_minimum_size = Vector2(260, 52)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	footer.add_child(_reroll_button)

	_note_label = _label("Offers restock after each wave.", 14, MUTED)
	_note_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_note_label)

	_continue_button = _button("Return to aisles", true)
	_continue_button.custom_minimum_size = Vector2(270, 52)
	_continue_button.pressed.connect(_on_continue_pressed)
	footer.add_child(_continue_button)


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
	card.custom_minimum_size = Vector2(0, 440)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(CARD, PANEL_EDGE, 5, 1))

	var margins := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 14)
	card.add_child(margins)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margins.add_child(stack)

	var type_name := "UPGRADE"
	var display_name := "Unavailable offer"
	var description := "This item cannot be displayed."
	var purchase_text := "BUY OFFER"
	var texture: Texture2D
	var resource_valid := false
	if offer is WeaponDefinition:
		var weapon := offer as WeaponDefinition
		var tier_name := _format_tier(weapon.tier)
		match weapon.shop_offer_kind:
			WeaponDefinition.ShopOfferKind.MERGE_COPY:
				type_name = "COPY / MERGE  ·  %s" % tier_name
				purchase_text = "BUY MERGE COPY"
			WeaponDefinition.ShopOfferKind.DIRECT_TIER:
				type_name = "DIRECT %s" % tier_name
				purchase_text = "BUY %s" % tier_name
			_:
				type_name = "NEW WEAPON  ·  %s" % tier_name
				purchase_text = "BUY WEAPON"
		display_name = weapon.display_name
		description = weapon.description
		var icon_path := "res://assets/generated/shop_icons/%s.png" % String(weapon.id)
		var generated_icon: Texture2D
		if ResourceLoader.exists(icon_path):
			generated_icon = load(icon_path) as Texture2D
		texture = generated_icon if generated_icon != null else weapon.sprite
		resource_valid = true
	elif offer is UpgradeDefinition:
		var upgrade := offer as UpgradeDefinition
		type_name = "SHIFT UPGRADE"
		display_name = upgrade.display_name
		description = upgrade.description
		texture = upgrade.icon
		resource_valid = true
	elif offer is Dictionary:
		var stat_offer := offer as Dictionary
		if String(stat_offer.get("kind", "")) == "stat" and not String(stat_offer.get("id", "")).is_empty():
			var stat_id := String(stat_offer.get("id", ""))
			type_name = "SHIFT STAT"
			display_name = String(stat_offer.get("name", "Shift stat"))
			description = String(stat_offer.get("description", "A lasting shift adjustment."))
			resource_valid = true
			match stat_id:
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

	var type_label := _label("SHELF %02d   /   %s" % [index + 1, type_name], 12, GOLD)
	stack.add_child(type_label)
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(0, 110)
	icon_panel.add_theme_stylebox_override("panel", _style(INK, Color("3f5a5d"), 4, 1))
	stack.add_child(icon_panel)
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(88, 88)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 10
		icon.offset_right = -10
		icon.offset_top = 8
		icon.offset_bottom = -8
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_panel.add_child(icon)

	var title := _label(display_name, 19, TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.y = 44
	stack.add_child(title)
	var detail := _label(description, 14, MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(detail)

	var is_purchased := _purchased_indices.has(index)
	var price: int = _current_prices[index] if index < _current_prices.size() else -1
	var price_text := I18n.t("SHOP_PURCHASED", "SATIN ALINDI") if is_purchased else ("%d " % price + I18n.t("SHOP_TOKENS", "stok jetonu") if price >= 0 else "---")
	var price_label := _label(price_text, 14, TEAL if is_purchased else (GOLD if price >= 0 else MUTED))
	price_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(price_label)

	var buy_button := _button(purchase_text, true)
	buy_button.custom_minimum_size.y = 48
	if is_purchased:
		buy_button.text = I18n.t("SHOP_PURCHASED", "SATIN ALINDI")
		buy_button.disabled = true
		card.modulate = Color(0.65, 0.75, 0.75, 0.85)
	else:
		buy_button.text = I18n.t("SHOP_BUY", "Satın Al") if resource_valid else "Unavailable"
		buy_button.disabled = not resource_valid or price < 0 or price > _current_currency
		buy_button.pressed.connect(_on_offer_pressed.bind(index, buy_button))
		card.modulate = Color.WHITE
	stack.add_child(buy_button)
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


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", INK if primary else TEXT)
	button.add_theme_color_override("font_hover_color", INK if primary else GOLD)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(GOLD if primary else Color("294046"), GOLD if primary else PANEL_EDGE, 4, 1))
	button.add_theme_stylebox_override("hover", _style(GOLD.lightened(0.1) if primary else Color("354b4d"), GOLD, 4, 2))
	button.add_theme_stylebox_override("pressed", _style(TEAL if primary else INK, TEAL, 4, 2))
	button.add_theme_stylebox_override("disabled", _style(Color("253338"), Color("3f5659"), 4, 1))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, TEXT, 4, 2))
	if display_font != null:
		button.add_theme_font_override("font", display_font)
	return button


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	if display_font != null:
		label.add_theme_font_override("font", display_font)
	return label


func _center_control(control: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(control)
	return center


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
