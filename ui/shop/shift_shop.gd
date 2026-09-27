extends CanvasLayer
class_name ShiftShop

signal offer_purchased(index: int)
signal offer_lock_toggled(index: int, locked: bool)
signal reroll_requested
signal continue_requested
signal weapon_sell_requested(weapon_id: StringName)

@export var display_font: FontFile

const INK := Color("111a1c")
const PANEL := Color("efebd8", 0.99)
const PANEL_EDGE := Color("a59c80")
const TEXT := Color("18231e")
const MUTED := Color("56645a")
const TEAL := Color("4d7658")
const GOLD := Color("b3943d")
const CARD := Color("f8f5e9")
const MAX_OFFERS := 4
const MAX_WEAPON_SLOTS := 6

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
var _weapon_detail_overlay: Control
var _weapon_detail_panel: PanelContainer
var _weapon_detail_icon: TextureRect
var _weapon_detail_name: Label
var _weapon_detail_tier: Label
var _weapon_detail_stats: GridContainer
var _weapon_detail_sell: Button
var _selected_weapon_id: StringName = &""
var _selected_weapon: Dictionary = {}
var _styles: Dictionary = {}
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


func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_GO_BACK_REQUEST and visible:
		_on_continue_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
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
	shade.color = Color(0.04, 0.075, 0.09, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	_build_weapon_detail_overlay(root)

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
	var density_scale := _mobile_density_scale(viewport_size) if mobile else 1.0
	var layout_scale := _mobile_layout_scale(viewport_size) if mobile else 1.0
	var usable_width := maxf(280.0, viewport_size.x - safe.x - safe.z)
	var usable_height := maxf(320.0, viewport_size.y - safe.y - safe.w)
	panel.offset_left = -usable_width * (0.47 if not mobile else 0.49) + (safe.x - safe.z) * 0.5
	panel.offset_right = usable_width * (0.47 if not mobile else 0.49) + (safe.x - safe.z) * 0.5
	panel.offset_top = -usable_height * (0.47 if not mobile else 0.49) + (safe.y - safe.w) * 0.5
	panel.offset_bottom = usable_height * (0.47 if not mobile else 0.49) + (safe.y - safe.w) * 0.5
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

	var header: Control = VBoxContainer.new() if (portrait and not mobile) else HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	content.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.add_theme_constant_override("separation", 4)
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_stack)
	_title_label = _label("The stockroom", 44, TEXT)
	if mobile:
		_title_label.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 38.0)))
	title_stack.add_child(_title_label)
	_subline_label = _label("Pick supplies for the next wave, or head back to the aisles.", 18, MUTED)
	_subline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if mobile:
		_subline_label.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 18.0)))
	title_stack.add_child(_subline_label)

	var right_header: Control = HBoxContainer.new() if (portrait and not mobile) else VBoxContainer.new()
	right_header.add_theme_constant_override("separation", 8)
	header.add_child(right_header)
	_round_label = _label("SHOP (WAVE 000)", 18, GOLD)
	if mobile:
		_round_label.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 18.0)))
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_header.add_child(_round_label)
	var balance_panel := PanelContainer.new()
	balance_panel.custom_minimum_size = Vector2((200 if portrait else 240) * layout_scale if mobile else (200 if portrait else 280), (52 if portrait else 64) * layout_scale if mobile else (52 if portrait else 78))
	balance_panel.add_theme_stylebox_override("panel", _style(Color("e4dbb6"), PANEL_EDGE, 0, 1))
	right_header.add_child(balance_panel)
	var balance_margins := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		balance_margins.add_theme_constant_override("margin_" + side, roundi(8.0 * layout_scale) if mobile else (8 if portrait else 14))
	balance_panel.add_child(balance_margins)
	_currency_label = _label("00  stock tokens", 23, TEXT)
	if mobile:
		_currency_label.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 22.0)))
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_margins.add_child(_center_control(_currency_label))
	_reroll_button = _button("Refresh shelf   /   0", false)
	_reroll_button.custom_minimum_size = Vector2(148 if mobile else 260, (48 * density_scale) if mobile else 52)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	if mobile:
		_reroll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	var offer_layout: Control = VBoxContainer.new() if (portrait and not mobile) else HBoxContainer.new()
	offer_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	offer_layout.add_theme_constant_override("separation", 18)
	content.add_child(offer_layout)
	_cards_row = GridContainer.new() if mobile else HBoxContainer.new()
	if mobile:
		(_cards_row as GridContainer).columns = 4
	_cards_row.name = "OfferCards"
	_cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if mobile else Control.SIZE_EXPAND_FILL
	_cards_row.add_theme_constant_override("separation", roundi(8.0 * layout_scale) if mobile else (10 if compact else 16))
	if mobile:
		var cards_scroll := ScrollContainer.new()
		cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		cards_scroll.add_child(_cards_row)
		offer_layout.add_child(cards_scroll)
	else:
		offer_layout.add_child(_cards_row)
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
	_continue_button.custom_minimum_size = Vector2((150 if mobile else 270), (48 * density_scale) if mobile else 52)
	_continue_button.pressed.connect(_on_continue_pressed)
	footer.add_child(_continue_button)
	if mobile or (portrait and not mobile):
		var touch_size := _touch_target_size(viewport_size)
		_continue_button.custom_minimum_size.x = 0.0
		_continue_button.custom_minimum_size.y = touch_size
		_continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_shop_sidebar()
	_update_inventory_strip()


func _build_shop_sidebar() -> VBoxContainer:
	var sidebar := VBoxContainer.new()
	var viewport_size := get_viewport().get_visible_rect().size
	var mobile := _is_mobile_platform()
	sidebar.custom_minimum_size.x = 246 if viewport_size.x <= 1400.0 else 278
	sidebar.add_theme_constant_override("separation", 10)
	var stats_panel := PanelContainer.new()
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel.add_theme_stylebox_override("panel", _style(CARD, PANEL_EDGE, 0, 1))
	var stats_content := VBoxContainer.new()
	stats_content.name = "StatsContent"
	stats_content.add_theme_constant_override("separation", 6)
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
	_update_inventory_strip()


func _build_inventory_strip(viewport_size: Vector2, mobile: bool, layout_scale: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "InventoryStrip"
	panel.add_theme_stylebox_override("panel", _style(Color("e4dbb6"), PANEL_EDGE, 0, 1))
	panel.custom_minimum_size.y = 112.0 if mobile else 126.0
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(_margin(body, roundi(5.0 * layout_scale) if mobile else 8))
	var active_column := VBoxContainer.new()
	active_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_column.add_theme_constant_override("separation", 4)
	body.add_child(active_column)
	var active_title := _label("SKILLS  /  UPGRADES · TURRETS · MINES", 16, TEXT)
	_inventory_items_label = active_title
	active_column.add_child(active_title)
	_inventory_upgrades_row = HBoxContainer.new()
	_inventory_deployables_row = HBoxContainer.new()
	active_column.add_child(_make_inventory_scroll(_inventory_upgrades_row))
	active_column.add_child(_make_inventory_scroll(_inventory_deployables_row))
	var weapon_column := VBoxContainer.new()
	weapon_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_column.custom_minimum_size.x = viewport_size.x * (0.32 if mobile else 0.35)
	weapon_column.add_theme_constant_override("separation", 4)
	body.add_child(weapon_column)
	_inventory_weapons_label = _label("WEAPONS (0/6)  ·  tap for stats / sell", 16, TEXT)
	weapon_column.add_child(_inventory_weapons_label)
	_inventory_weapons_row = HBoxContainer.new()
	weapon_column.add_child(_make_inventory_scroll(_inventory_weapons_row))
	_inventory_deployables_label = _label("", 12, MUTED)
	_update_inventory_strip()
	return panel


func _make_inventory_scroll(row: HBoxContainer) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 48.0
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
		_inventory_weapons_label.text = "WEAPONS (%d/%d)  ·  tap for stats / sell" % [mini(weapons.size(), MAX_WEAPON_SLOTS), MAX_WEAPON_SLOTS]
	for weapon: Variant in weapons:
		if weapon is Dictionary:
			_add_weapon_chip(weapon)


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
	var tier := clampi(int(record.get("tier", 1)), 1, 4)
	var name := String(record.get("name", id.replace("_", " ").capitalize()))
	var button := Button.new()
	var icon_only := kind in ["TURRET", "MINE", "UPGRADE"]
	button.custom_minimum_size = Vector2(58, 50) if icon_only else Vector2(84, 42)
	button.text = "" if icon_only else ("%s  ×%d" % [name, count] if count > 0 else name)
	button.tooltip_text = "%s · %s" % [kind, name]
	var icon := record.get("icon") as Texture2D
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
	button.add_theme_stylebox_override("hover", _tier_style(tier).duplicate())
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
	button.custom_minimum_size = Vector2(56, 48)
	button.text = ""
	button.tooltip_text = "%s %s — tap for stats or sell" % [name, _tier_suffix(tier)]
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


func _tier_style(tier: int) -> StyleBoxFlat:
	var fills := [Color("d7d5cb"), Color("93abc0"), Color("b499c6"), Color("d5a35f")]
	var edges := [Color("77766f"), Color("557a99"), Color("80609a"), Color("a96828")]
	return _style(fills[clampi(tier, 1, 4) - 1], edges[clampi(tier, 1, 4) - 1], 2, 2)


func _on_weapon_chip_pressed(weapon: Dictionary) -> void:
	_selected_weapon_id = StringName(String(weapon.get("id", "")))
	_selected_weapon = weapon.duplicate(true)
	_weapon_detail_name.text = String(weapon.get("name", "Weapon"))
	_weapon_detail_tier.text = "TIER %s  /  SELECTED WEAPON" % _tier_suffix(int(weapon.get("tier", 1)))
	_weapon_detail_icon.texture = weapon.get("icon") as Texture2D
	_clear_inventory_row(_weapon_detail_stats)
	_add_detail_stat("Damage", str(weapon.get("damage", "—")))
	_add_detail_stat("Fire interval", "%.2f s" % float(weapon.get("fire_interval", 0.0)))
	_add_detail_stat("Projectiles", str(weapon.get("projectile_count", 1)))
	_add_detail_stat("Range", str(weapon.get("range", 0)))
	_add_detail_stat("Area", str(weapon.get("area", 0)))
	_add_detail_stat("Pierce", str(weapon.get("pierce", 0)))
	_weapon_detail_sell.text = "Sell · %d tokens" % _weapon_sell_price(weapon)
	_weapon_detail_sell.disabled = inventory_weapon_count() <= 1
	_weapon_detail_overlay.show()
	_layout_weapon_detail()


func _weapon_sell_price(weapon: Dictionary) -> int:
	var tier := clampi(int(weapon.get("tier", 1)), 1, 4)
	var base_price := 12 + (tier - 1) * 4
	var wave := maxi(1, int(_player_summary.get("shop_wave", _current_round_number)))
	var inflation := floori(float(wave) * (0.70 + float(base_price) * 0.05))
	var endless_factor := 1.0 + float(maxi(0, wave - 20)) * 0.015 if bool(_player_summary.get("shop_endless", false)) else 1.0
	return maxi(1, floori(float(floori(float(base_price + inflation) * endless_factor)) * 0.45))


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
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	_weapon_detail_panel.add_child(_margin(body, 14))
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 14)
	body.add_child(heading)
	_weapon_detail_icon = TextureRect.new()
	_weapon_detail_icon.custom_minimum_size = Vector2(68, 68)
	_weapon_detail_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_weapon_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	heading.add_child(_center_control(_weapon_detail_icon))
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 3)
	heading.add_child(title_stack)
	_weapon_detail_tier = _label("TIER II  /  SELECTED WEAPON", 14, GOLD)
	title_stack.add_child(_center_control(_weapon_detail_tier))
	_weapon_detail_name = _label("Weapon", 28, TEXT)
	_weapon_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_stack.add_child(_center_control(_weapon_detail_name))
	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", _line_style(GOLD))
	body.add_child(divider)
	_weapon_detail_stats = GridContainer.new()
	_weapon_detail_stats.columns = 2
	_weapon_detail_stats.add_theme_constant_override("h_separation", 12)
	_weapon_detail_stats.add_theme_constant_override("v_separation", 4)
	body.add_child(_weapon_detail_stats)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	body.add_child(actions)
	_weapon_detail_sell = _button("Sell", true)
	_weapon_detail_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_detail_sell.pressed.connect(_on_weapon_sell_confirmed)
	actions.add_child(_weapon_detail_sell)
	var close_button := _button("Close", false)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(_weapon_detail_overlay.hide)
	actions.add_child(close_button)
	get_viewport().size_changed.connect(_layout_weapon_detail)


func _layout_weapon_detail() -> void:
	if not is_instance_valid(_weapon_detail_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := _safe_insets(viewport_size)
	var usable_width := maxf(280.0, viewport_size.x - safe.x - safe.z)
	var usable_height := maxf(240.0, viewport_size.y - safe.y - safe.w)
	var width := minf(640.0, usable_width * 0.88)
	var height := minf(480.0, usable_height * 0.84)
	_weapon_detail_panel.offset_left = -width * 0.5 + (safe.x - safe.z) * 0.5
	_weapon_detail_panel.offset_right = width * 0.5 + (safe.x - safe.z) * 0.5
	_weapon_detail_panel.offset_top = -height * 0.5 + (safe.y - safe.w) * 0.5
	_weapon_detail_panel.offset_bottom = height * 0.5 + (safe.y - safe.w) * 0.5
	var compact := viewport_size.y <= 500.0
	_weapon_detail_icon.custom_minimum_size = Vector2(52, 52) if compact else Vector2(68, 68)
	_weapon_detail_name.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 25.0)) if _is_mobile_platform() else 28)
	_weapon_detail_sell.custom_minimum_size.y = _touch_target_size(viewport_size) if _is_mobile_platform() else 46


func _add_detail_stat(stat_name: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := _label(stat_name, 17, MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := _label(value, 18, TEXT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	var layout_scale := _mobile_layout_scale(viewport_size)
	var card_height := maxf(300.0, viewport_size.y * 0.38) if mobile else 0.0
	card.custom_minimum_size = Vector2(0, card_height)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_FILL
	card.add_theme_stylebox_override("panel", _style(CARD, PANEL_EDGE, 0, 1))

	var margins := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, roundi(8.0 * layout_scale) if mobile else 14)
	card.add_child(margins)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", roundi(6.0 * layout_scale) if mobile else 8)
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
		var deployable_kind := "TURRET" if weapon.attack_mode == WeaponDefinition.AttackMode.DEPLOYED_TURRET else ("MINE" if weapon.attack_mode == WeaponDefinition.AttackMode.DEPLOYED_MINE else "")
		match weapon.shop_offer_kind:
			WeaponDefinition.ShopOfferKind.MERGE_COPY:
				type_name = "%s COPY / MERGE  ·  %s" % ["SKILL · " + deployable_kind if not deployable_kind.is_empty() else "WEAPON", tier_name]
				purchase_text = "BUY MERGE COPY"
			WeaponDefinition.ShopOfferKind.DIRECT_TIER:
				type_name = "%s DIRECT %s" % ["SKILL · " + deployable_kind if not deployable_kind.is_empty() else "WEAPON", tier_name]
				purchase_text = "BUY %s" % tier_name
			WeaponDefinition.ShopOfferKind.DEPLOYABLE_COPY:
				type_name = "EXTRA %s  ·  %s" % [deployable_kind, tier_name]
				purchase_text = "BUY EXTRA"
			_:
				type_name = "NEW SKILL · %s  ·  %s" % [deployable_kind, tier_name] if not deployable_kind.is_empty() else "NEW WEAPON  ·  %s" % tier_name
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

	var mobile_type_size := _mobile_shop_font(viewport_size, 16.0)
	var mobile_body_size := _mobile_shop_font(viewport_size, 19.0)
	var type_label := _label("SHELF %02d   /   %s" % [index + 1, type_name], 15, GOLD)
	if mobile:
		type_label.add_theme_font_size_override("font_size", roundi(mobile_type_size))
		type_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	type_label.autowrap_mode = TextServer.AUTOWRAP_OFF if mobile else TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(type_label)
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(0, (76.0 * layout_scale) if mobile else (92 if viewport_size.y <= 800.0 else 116))
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

	var title := _label(display_name, 25, TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF if mobile else TextServer.AUTOWRAP_WORD_SMART
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if mobile else TextServer.OVERRUN_NO_TRIMMING
	title.custom_minimum_size.y = (32.0 * layout_scale) if mobile else 44
	if mobile:
		title.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 28.0)))
	stack.add_child(title)
	var detail := _label(description, 17, MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if mobile:
		detail.add_theme_font_size_override("font_size", roundi(mobile_body_size))
	stack.add_child(detail)

	var is_purchased := _purchased_indices.has(index)
	var price: int = _current_prices[index] if index < _current_prices.size() else -1
	var price_text := I18n.t("SHOP_PURCHASED", "SATIN ALINDI") if is_purchased else ("%d " % price + I18n.t("SHOP_TOKENS", "stok jetonu") if price >= 0 else "---")
	var price_label := _label(price_text, 20, TEAL if is_purchased else (GOLD if price >= 0 else MUTED))
	price_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if mobile:
		price_label.add_theme_font_size_override("font_size", roundi(_mobile_shop_font(viewport_size, 21.0)))
	stack.add_child(price_label)

	var actions: Control = HBoxContainer.new() if mobile else VBoxContainer.new()
	actions.add_theme_constant_override("separation", roundi(6.0 * layout_scale) if mobile else 6)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(actions)
	var buy_button := _button(purchase_text, true)
	buy_button.custom_minimum_size.y = _touch_target_size(viewport_size) if mobile else 48
	if mobile:
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
	var lock_button := _button("Unlock offer" if _locked_indices.has(index) else "Lock offer", false)
	lock_button.custom_minimum_size.y = _touch_target_size(viewport_size) if mobile else 40
	if mobile:
		lock_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock_button.pressed.connect(_on_offer_lock_pressed.bind(index))
	actions.add_child(lock_button)
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


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", _responsive_font_size(17))
	button.add_theme_color_override("font_color", INK if primary else TEXT)
	button.add_theme_color_override("font_hover_color", INK if primary else GOLD)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(GOLD.lightened(0.24) if primary else CARD, GOLD if primary else PANEL_EDGE, 0, 1))
	button.add_theme_stylebox_override("hover", _style(GOLD.lightened(0.32) if primary else Color("fffdf4"), GOLD, 0, 2))
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
	if _is_mobile_platform():
		var viewport_size := get_viewport().get_visible_rect().size
		return maxi(12, roundi(float(size) * clampf(viewport_size.y / 1080.0, 0.75, 1.0)))
	var window_width := float(get_window().size.x) if get_window() != null else 1920.0
	return roundi(float(size) * clampf(1920.0 / maxf(window_width, 1.0), 1.0, 1.4))


func _is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()


func _mobile_density_scale(viewport_size: Vector2) -> float:
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
