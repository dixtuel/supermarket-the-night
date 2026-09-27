extends Node2D
class_name SurvivorArena
## Owns a single complete shift: schedule, spawning, pickups, level-up pauses,
## boss result, local high score, and the transition to results.

enum RunState { RUNNING, ROUND_CLEAR, LEVEL_UP, SHOP, PAUSED, RESULTS }

@export var shift_schedule: ShiftScheduleDefinition = preload("res://data/shifts/first_shift.tres")
@export var use_authored_waves: bool = true
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy_actor.tscn")
const XP_ORB_SCENE: PackedScene = preload("res://progression/xp_orb/xp_orb.tscn")
const CONSUMABLE_SCENE: PackedScene = preload("res://progression/consumable_pickup/consumable_pickup.tscn")
const ROOM_SCENES: Dictionary = {
	&"market": preload("res://levels/rooms/market_room.tscn"),
	&"depot": preload("res://levels/rooms/depot_room.tscn"),
	&"manager_office": preload("res://levels/rooms/manager_office_room.tscn"),
	&"restroom": preload("res://levels/rooms/restroom_room.tscn"),
}
const STARTER_WEAPON_IDS: Array[StringName] = [&"can_launcher"]
const CAMPAIGN_WAVE_COUNT := 20
const ENDLESS_WAVE_PATTERNS: Array[WaveDefinition] = [
	preload("res://data/endless/wave_01.tres"),
	preload("res://data/endless/wave_02.tres"),
	preload("res://data/endless/wave_03.tres"),
	preload("res://data/endless/wave_04.tres"),
	preload("res://data/endless/wave_05.tres"),
	preload("res://data/endless/wave_06.tres"),
	preload("res://data/endless/wave_07.tres"),
	preload("res://data/endless/wave_08.tres"),
	preload("res://data/endless/wave_09.tres"),
	preload("res://data/endless/wave_10.tres"),
]
const ENDLESS_SUPPLEMENTAL_ENEMIES: Array[EnemyDefinition] = [
	preload("res://data/enemies/scanline_runner.tres"),
	preload("res://data/enemies/cooler_dripper.tres"),
	preload("res://data/enemies/coupon_tosser.tres"),
	preload("res://data/enemies/pallet_jack_pusher.tres"),
	preload("res://data/enemies/night_shift_supervisor.tres"),
]
const WEAPON_DEFINITIONS: Array[WeaponDefinition] = [
	preload("res://data/weapons/can_launcher.tres"),
	preload("res://data/weapons/mop_whirl.tres"),
	preload("res://data/weapons/receipt_boomerang.tres"),
	preload("res://data/weapons/sale_tag_beacon.tres"),
	preload("res://data/weapons/bulk_basket_fan.tres"),
	preload("res://data/weapons/circulation_return.tres"),
	preload("res://data/weapons/basket_orbit.tres"),
	preload("res://data/weapons/barcode_reel.tres"),
	preload("res://data/weapons/shelf_rinse_sprayer.tres"),
	preload("res://data/weapons/aisle_sentinel.tres"),
	preload("res://data/weapons/spill_tripmine.tres"),
	preload("res://data/weapons/thermal_price_gun.tres"),
	preload("res://data/weapons/tote_stack_lobber.tres"),
	preload("res://data/weapons/deposit_ring_reel.tres"),
]
const UPGRADE_DEFINITIONS: Array[UpgradeDefinition] = [
	preload("res://data/upgrades/bulk_pack.tres"),
	preload("res://data/upgrades/better_wringing.tres"),
	preload("res://data/upgrades/bigger_discount.tres"),
	preload("res://data/upgrades/comfortable_shoes.tres"),
	preload("res://data/upgrades/fresh_apron.tres"),
	preload("res://data/upgrades/heavier_cans.tres"),
	preload("res://data/upgrades/long_receipt.tres"),
	preload("res://data/upgrades/long_toss.tres"),
	preload("res://data/upgrades/new_mop.tres"),
	preload("res://data/upgrades/new_receipt_roll.tres"),
	preload("res://data/upgrades/new_sale_tags.tres"),
	preload("res://data/upgrades/quick_stocking.tres"),
	preload("res://data/upgrades/new_bulk_basket_fan.tres"),
	preload("res://data/upgrades/new_circulation_return.tres"),
	preload("res://data/upgrades/new_basket_orbit.tres"),
	preload("res://data/upgrades/reinforced_receipts.tres"),
	preload("res://data/upgrades/extra_basket.tres"),
	preload("res://data/upgrades/longer_shift.tres"),
	preload("res://data/upgrades/quick_checkout.tres"),
	preload("res://data/upgrades/quiet_shift_footwork.tres"),
	preload("res://data/upgrades/engineering_caddy.tres"),
	preload("res://data/upgrades/aisle_sentinel_calibration.tres"),
	preload("res://data/upgrades/tripmine_trigger_tune.tres"),
	preload("res://data/upgrades/reinforced_apron_plus.tres"),
	preload("res://data/upgrades/thermal_price_gun_unlock.tres"),
]
const RECORD_PATH := "user://bakkal_records.cfg"
const SPAWN_MARGIN := 24.0
const SPAWN_MIN_PLAYER_DISTANCE := 260.0
const SPAWN_MIN_X := -566.0
const SPAWN_MAX_X := 566.0
const SPAWN_MIN_Y := -158.0
const SPAWN_MAX_Y := 266.0
const SHOP_SCENE: PackedScene = preload("res://ui/shop/shift_shop.tscn")
const ROOM_EVENT_DIRECTOR_SCENE: PackedScene = preload("res://levels/room_events/room_event_director.tscn")

@onready var _actor_layer: Node2D = %ActorLayer
@onready var _projectile_layer: Node2D = %ProjectileLayer
@onready var _pickup_layer: Node2D = %PickupLayer
@onready var _player: SurvivorPlayer = %Player
@onready var _hud: CanvasLayer = %HUD
@onready var _room_layer: Node2D = %RoomLayer

var _state: RunState = RunState.RUNNING
var _elapsed: float = 0.0
var _round_elapsed: float = 0.0
var _health_regen_elapsed: float = 0.0
var _round_duration: float = 60.0
var _round_number: int = 1
var _spawn_cooldown: float = 0.0
var _powerup_cooldown: float = 0.0
var _kills: int = 0
var _boss_spawned: bool = false
var _boss_defeated: bool = false
var _pending_level_ups: int = 0
var _currency: int = 10
var _shop_reroll_count: int = 0
var _shop_open_round: int = 0
var _active_stat_choices: Array[Dictionary] = []
var _active_shop_offers: Array = []
var _active_shop_prices: Array[int] = []
var _purchased_shop_indices: Array[int] = []
var _locked_shop_indices: Array[int] = []
var _shop: ShiftShop
var _current_phase: ShiftPhaseDefinition
var _best_score: int = 0
var _spawn_clearance_shape: CircleShape2D
var _authored_waves: Array[WaveDefinition] = []
var _current_wave: WaveDefinition
var _endless_mode: bool = false
var _spawned_this_wave: int = 0
var _endless_ambush_rng := RandomNumberGenerator.new()
var _room_migration_rng := RandomNumberGenerator.new()
var _endless_ambush_seed_base: int = 0
var _deployable_ambush_pending: bool = false
var _deployable_ambush_time: float = INF
var _deployable_ambush_deadline: float = INF
var _deployable_ambush_retry_timer: float = 0.0
var _recent_turret_ambush_positions: Array[Vector2] = []
var _best_endless_score: int = 0
var _best_endless_wave: int = 0
var _rooms: Dictionary = {}
var _current_room_id: StringName = &"market"
var _room_transition_pending: bool = false
var _room_transition_cooldown: float = 0.0
var _room_transition_count: int = 0
var _room_event_director: RoomEventDirector
var _wave_director: RuntimeWaveDirector = RuntimeWaveDirector.new()


func _ready() -> void:
	# Keep the game world (player, enemies, projectiles) under the SceneTree pause.
	# HUD and lifecycle helpers opt into PROCESS_MODE_ALWAYS independently.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_endless_ambush_rng.randomize()
	_endless_ambush_seed_base = int(_endless_ambush_rng.randi())
	if use_authored_waves:
		_authored_waves = _load_authored_waves()
	else:
		_authored_waves.clear()
	if get_tree().has_meta("supermarket_endless_mode"):
		_endless_mode = bool(get_tree().get_meta("supermarket_endless_mode"))
		get_tree().remove_meta("supermarket_endless_mode")
	_spawn_clearance_shape = CircleShape2D.new()
	_spawn_clearance_shape.radius = SPAWN_MARGIN
	_build_room_scenes()
	_room_event_director = ROOM_EVENT_DIRECTOR_SCENE.instantiate() as RoomEventDirector
	add_child(_room_event_director)
	_room_event_director.configure(
		_room_event_director.event_definitions,
		_player,
		_actor_layer,
		_projectile_layer,
		_pickup_layer
	)
	_room_event_director.event_message.connect(_on_room_event_message)
	_room_event_director.objective_changed.connect(_on_room_event_objective_changed)
	_room_event_director.helper_summoned.connect(_on_room_event_helper_summoned)
	for room: SurvivorRoom in _rooms.values():
		var console := room.find_child("SupplyRequestConsole", true, false) as SupplyRequestConsole
		if console != null:
			console.set_event_director(_room_event_director)
	_player.global_position = Vector2(0.0, 180.0)
	BakkalAudio.play_music()
	_load_records()
	_connect_run_signals()
	_configure_starter_weapon()
	_shop = SHOP_SCENE.instantiate() as ShiftShop
	add_child(_shop)
	_shop.offer_purchased.connect(_on_shop_offer_purchased)
	_shop.offer_lock_toggled.connect(_on_shop_offer_lock_toggled)
	_shop.reroll_requested.connect(_on_shop_reroll_requested)
	_shop.continue_requested.connect(_on_shop_continue_requested)
	_shop.weapon_sell_requested.connect(_on_shop_weapon_sell_requested)
	if RunSaveManager != null and RunSaveManager.has_meta("should_resume") and bool(RunSaveManager.get_meta("should_resume")):
		RunSaveManager.set_meta("should_resume", false)
		var saved_data := RunSaveManager.load_and_clear_saved_run()
		if not saved_data.is_empty():
			_restore_run_state(saved_data)
	else:
		_select_phase(true)
		_hud.set_round_clock(_round_number, 0.0, _round_duration)
		_hud.set_kill_count(0)
		_hud.set_weapons(_weapon_names())
	_player.get_node("AutoWeapon").call("set_current_room_id", _current_room_id)
	_spawn_cooldown = 1.2
	_powerup_cooldown = randf_range(20.0, 36.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if _state != RunState.RESULTS and RunSaveManager != null:
			RunSaveManager.save_run_state(_gather_save_state())
			if _state == RunState.RUNNING:
				_pause_run()
				_hud.show_pause_menu()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _state == RunState.RUNNING:
			_pause_run()
			_hud.show_pause_menu()
		elif _state == RunState.PAUSED:
			_resume_run()


func _process(delta: float) -> void:
	if _state != RunState.RUNNING:
		return
	_elapsed += delta
	_round_elapsed += delta
	_health_regen_elapsed += delta
	if _health_regen_elapsed >= 4.0:
		_health_regen_elapsed = fmod(_health_regen_elapsed, 4.0)
		_player.heal(1)
	_room_transition_cooldown = maxf(0.0, _room_transition_cooldown - delta)
	_hud.set_round_clock(_round_number, _round_elapsed, _round_duration)
	_spawn_cooldown -= delta
	if _spawn_cooldown <= 0.0:
		_spawn_from_phase()
		_spawn_cooldown = _current_spawn_interval()
	_tick_endless_deployable_ambush(delta)
	_powerup_cooldown -= delta
	if _powerup_cooldown <= 0.0:
		_spawn_random_powerup()
		_powerup_cooldown = randf_range(18.0, 34.0)
	var boss_spawn_time := _current_wave.boss_spawn_seconds if _current_wave != null and _current_wave.boss_spawn_seconds > 0.0 else maxf(8.0, _round_duration - 12.0)
	if _is_boss_round() and not _boss_spawned and _round_elapsed >= boss_spawn_time:
		_boss_spawned = true
		var boss_definition := _boss_definition_for_round()
		if boss_definition != null:
			_spawn_enemy(boss_definition, _boss_health_multiplier(), true)
		else:
			_boss_defeated = true
	if _round_elapsed >= _round_duration:
		_complete_round()


func _unhandled_input(event: InputEvent) -> void:
	if _state == RunState.RESULTS and event.is_action_pressed("restart"):
		_restart_run()
		get_viewport().set_input_as_handled()
		return

	var is_pause := false
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		is_pause = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		is_pause = true

	if is_pause:
		if _state == RunState.RUNNING:
			_pause_run()
			_hud.show_pause_menu()
			get_viewport().set_input_as_handled()
		elif _state == RunState.PAUSED:
			_resume_run()
			get_viewport().set_input_as_handled()


func _connect_run_signals() -> void:
	_player.health_changed.connect(_on_player_health_changed)
	_player.progress_changed.connect(_on_player_progress_changed)
	_player.died.connect(_on_player_died)
	if _player.has_signal("level_up"):
		_player.connect("level_up", _on_player_level_up)
	_on_player_health_changed(_player.current_health, _player.max_health)
	_on_player_progress_changed(_player.current_xp, _player.get("_xp_required"), _player.current_level)
	_hud.stat_choice_selected.connect(_on_stat_choice_selected)
	_hud.pause_requested.connect(_pause_run)
	_hud.resume_requested.connect(_resume_run)
	_hud.restart_requested.connect(_restart_run)
	_hud.title_requested.connect(_open_title)
	_hud.save_and_quit_requested.connect(_on_save_and_quit_requested)


func _configure_starter_weapon() -> void:
	var weapon := _player.get_node_or_null("AutoWeapon")
	if weapon != null and weapon.has_method("configure_weapon_catalog"):
		weapon.call("configure_weapon_catalog", WEAPON_DEFINITIONS, _projectile_layer, STARTER_WEAPON_IDS)
	elif weapon != null and weapon.has_method("configure_projectile_layer"):
		weapon.call("configure_projectile_layer", _projectile_layer)


func _select_phase(initial: bool) -> void:
	_current_wave = _wave_for_round(_round_number)
	_current_phase = _phase_for_round(_round_number)
	if _current_wave == null and _current_phase == null:
		return
	if _current_wave != null:
		_round_duration = maxf(20.0, _current_wave.duration_seconds)
	elif _current_phase != null:
		_round_duration = maxf(20.0, _current_phase.end_seconds - _current_phase.start_seconds)
	_apply_room_visual_states()
	_refresh_room_title()
	if not initial:
		_spawn_cooldown = minf(_spawn_cooldown, 0.4)
	_spawned_this_wave = 0
	_wave_director.begin_wave(_round_number)
	_setup_endless_deployable_ambush()
	_spawn_cooldown = 1.0 if initial else 0.4
	if is_instance_valid(_room_event_director):
		_room_event_director.start_wave(_round_number)
		_room_event_director.enter_room(_current_room_id, _room_event_anchor(_current_room_id))
	var weapon_controller := _player.get_node_or_null("AutoWeapon") if is_instance_valid(_player) else null
	if weapon_controller != null and weapon_controller.has_method("begin_wave"):
		weapon_controller.call("begin_wave", _current_room_id)


func _room_event_anchor(room_id: StringName) -> Vector2:
	match room_id:
		&"market":
			return Vector2(0.0, 214.0)
		&"depot":
			return Vector2(335.0, 65.0)
		&"manager_office":
			return Vector2(-30.0, 155.0)
		&"restroom":
			return Vector2(0.0, 175.0)
	return Vector2.ZERO


func _build_room_scenes() -> void:
	var street_backdrop := Sprite2D.new()
	street_backdrop.name = "NightStreetBackdrop"
	street_backdrop.texture = load("res://assets/generated/exterior/night_street_backdrop.png") as Texture2D
	street_backdrop.scale = Vector2(1600.0 / 1536.0, 900.0 / 1024.0)
	street_backdrop.z_index = -20
	_room_layer.add_child(street_backdrop)
	for room_id: StringName in ROOM_SCENES:
		var room_scene := ROOM_SCENES[room_id] as PackedScene
		var room := room_scene.instantiate() as SurvivorRoom
		room.name = String(room_id).to_pascal_case() + "Room"
		_room_layer.add_child(room)
		_rooms[room_id] = room
		room.portal_requested.connect(_on_room_portal_requested)
		room.set_active(room_id == _current_room_id)


func _apply_room_visual_states() -> void:
	var state: StringName = &"clean_shift_start"
	if _current_phase != null:
		match _current_phase.id:
			&"cart_rush":
				state = &"messy_midrun"
			&"freezer_aisle":
				state = &"tidy_lights_on"
			&"lights_out":
				state = &"lights_out"
			&"open_door":
				state = &"entrance_open"
	for room: SurvivorRoom in _rooms.values():
		room.set_visual_state(state)


func _refresh_room_title() -> void:
	var room_names := {
		&"market": "MAIN MARKET",
		&"depot": "STOCKROOM",
		&"manager_office": "MANAGER OFFICE",
		&"restroom": "RESTROOM",
	}
	var title := String(room_names.get(_current_room_id, "MARKET"))
	if _current_wave != null:
		title = "%s  ·  %s" % [_current_wave.display_name, title]
	elif _current_phase != null:
		title = "%s  ·  %s" % [_current_phase.display_name, title]
	_hud.set_phase_name(title)


func _on_room_portal_requested(from_room_id: StringName, target_room_id: StringName, arrival_position: Vector2) -> void:
	if _room_transition_pending or _room_transition_cooldown > 0.0 or from_room_id != _current_room_id or not _rooms.has(target_room_id):
		return
	_room_transition_pending = true
	call_deferred("_complete_room_transition", target_room_id, arrival_position)


func _complete_room_transition(target_room_id: StringName, arrival_position: Vector2) -> void:
	if not _rooms.has(target_room_id):
		_room_transition_pending = false
		return
	var source_room_id := _current_room_id
	if is_instance_valid(_room_event_director):
		_room_event_director.leave_room()
	(_rooms[_current_room_id] as SurvivorRoom).set_active(false)
	_current_room_id = target_room_id
	(_rooms[_current_room_id] as SurvivorRoom).set_active(true)
	_player.global_position = arrival_position
	var weapon_controller := _player.get_node_or_null("AutoWeapon")
	if weapon_controller != null and weapon_controller.has_method("set_current_room_id"):
		weapon_controller.call("set_current_room_id", _current_room_id)
	for projectile: Node in _projectile_layer.get_children():
		if projectile.is_in_group("deployed_structures"):
			if projectile.has_method("set_deployable_room_active"):
				projectile.call("set_deployable_room_active", StringName(projectile.get_meta("room_id", &"market")) == _current_room_id)
			continue
		projectile.queue_free()
	_set_room_actor_presence()
	await get_tree().physics_frame
	_migrate_enemies_between_rooms(source_room_id, target_room_id)
	_set_room_actor_presence()
	if is_instance_valid(_room_event_director):
		_room_event_director.enter_room(_current_room_id, _room_event_anchor(_current_room_id))
	_refresh_room_title()
	_room_transition_cooldown = 0.6
	_room_transition_pending = false
	_room_transition_count += 1


func _migrate_enemies_between_rooms(source_room_id: StringName, target_room_id: StringName) -> void:
	if source_room_id == target_room_id or not is_instance_valid(_player):
		return
	var candidates: Array[EnemyActor] = []
	for actor: Node in _actor_layer.get_children():
		if actor is EnemyActor and actor.has_meta("room_id") and StringName(actor.get_meta("room_id")) == source_room_id:
			candidates.append(actor as EnemyActor)
	if candidates.is_empty():
		return
	var progress := clampf(float(_round_number - 1) * 0.006 + float(_player.current_level - 1) * 0.003, 0.0, 0.18)
	var weighted_candidates: Array[Dictionary] = []
	for enemy: EnemyActor in candidates:
		var definition := enemy.get_definition()
		if definition == null or definition.role == EnemyDefinition.Role.BOSS:
			continue
		var weight := 0.0
		match definition.role:
			EnemyDefinition.Role.CHASER:
				weight = 0.52
			EnemyDefinition.Role.CHARGER:
				weight = 0.36
			EnemyDefinition.Role.RANGED:
				weight = 0.16
			EnemyDefinition.Role.AREA_DENIAL:
				weight = 0.08
		var enemy_id := String(definition.id)
		if enemy_id.contains("runner") or enemy_id.contains("sprinter") or enemy_id.contains("pusher"):
			weight += 0.08
		weight = clampf(weight + progress, 0.0, 0.72)
		if weight > 0.0:
			weighted_candidates.append({"enemy": enemy, "weight": weight})
	if weighted_candidates.is_empty():
		return
	var seed_value := _endless_ambush_seed_base ^ (_round_number * 19349663) ^ (_room_transition_count * 83492791) ^ (_player.current_level * 73856093)
	_room_migration_rng.seed = maxi(1, absi(seed_value))
	var available_slots := maxi(0, _current_max_alive() - _alive_enemy_count())
	var population_cap := maxi(1, floori(float(maxi(1, candidates.size() - 1)) * 0.5))
	var max_migrants := mini(available_slots, mini(2, population_cap))
	var migrated: Array[EnemyActor] = []
	while not weighted_candidates.is_empty() and migrated.size() < max_migrants:
		var total_weight := 0.0
		for entry: Dictionary in weighted_candidates:
			total_weight += float(entry["weight"])
		var roll := _room_migration_rng.randf() * total_weight
		var selected_index := 0
		for index: int in range(weighted_candidates.size()):
			roll -= float(weighted_candidates[index]["weight"])
			if roll <= 0.0:
				selected_index = index
				break
		var selected: Dictionary = weighted_candidates.pop_at(selected_index)
		if migrated.is_empty() and weighted_candidates.size() > 0:
			# With a crowd, one eligible pursuer follows while the cap guarantees the
			# remaining actors stay behind. A lone candidate still gets a real chance.
			pass
		elif _room_migration_rng.randf() > float(selected["weight"]):
			break
		migrated.append(selected["enemy"] as EnemyActor)
	for enemy: EnemyActor in migrated:
		var spawn_point := _room_migration_spawn_point()
		if not spawn_point.is_finite():
			continue
		enemy.migrate_to_room(target_room_id, spawn_point)


func _room_migration_spawn_point() -> Vector2:
	for _attempt: int in range(36):
		var radius := _room_migration_rng.randf_range(300.0, 390.0)
		var point := _player.global_position + Vector2.RIGHT.rotated(_room_migration_rng.randf_range(0.0, TAU)) * radius
		point.x = clampf(point.x, SPAWN_MIN_X, SPAWN_MAX_X)
		point.y = clampf(point.y, SPAWN_MIN_Y, SPAWN_MAX_Y)
		if point.distance_to(_player.global_position) >= SPAWN_MIN_PLAYER_DISTANCE and _spawn_point_is_clear(point):
			return point
	return _spawn_position()


func _set_room_actor_presence() -> void:
	for actor: Node in _actor_layer.get_children():
		if actor is TemporaryShiftHelper:
			actor.set_meta("room_id", _current_room_id)
			actor.process_mode = Node.PROCESS_MODE_INHERIT
			if actor.has_method("snap_to_owner"):
				actor.call("snap_to_owner")
		elif actor is EnemyActor and actor.has_meta("room_id"):
			var active: bool = StringName(actor.get_meta("room_id")) == _current_room_id
			actor.visible = active
			actor.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
			actor.collision_layer = 4 if active else 0
			actor.collision_mask = 1 if active else 0
			var attack_area := actor.get_node_or_null("AttackArea") as Area2D
			if attack_area != null:
				attack_area.collision_mask = 2 if active else 0
				if not active:
					attack_area.set_deferred("monitoring", false)
				elif actor.has_method("_update_attack_area"):
					actor.call("_update_attack_area")
	for pickup: Node in _pickup_layer.get_children():
		if pickup is Area2D and pickup.has_meta("room_id"):
			var active: bool = StringName(pickup.get_meta("room_id")) == _current_room_id
			pickup.visible = active
			pickup.set_deferred("monitoring", active)
			pickup.set_deferred("monitorable", active)
			pickup.set_deferred("collision_layer", 8 if active else 0)
			pickup.set_deferred("collision_mask", 2 if active else 0)
	for structure: Node in _projectile_layer.get_children():
		if not structure.is_in_group("deployed_structures"):
			continue
		var active := StringName(structure.get_meta("room_id", &"market")) == _current_room_id
		if structure.has_method("set_deployable_room_active"):
			structure.call("set_deployable_room_active", active)


func _load_authored_waves() -> Array[WaveDefinition]:
	var waves: Array[WaveDefinition] = []
	for wave_number: int in range(1, CAMPAIGN_WAVE_COUNT + 1):
		var path := "res://data/waves/wave_%02d.tres" % wave_number
		if not ResourceLoader.exists(path):
			push_error("Campaign schedule is incomplete; missing wave resource: " + path)
			return []
		var wave := load(path) as WaveDefinition
		if wave == null or wave.id != StringName("wave_%02d" % wave_number):
			push_error("Campaign schedule has an invalid wave resource: " + path)
			return []
		if wave.enemy_definitions.is_empty() or wave.spawn_weights.size() != wave.enemy_definitions.size():
			push_error("Campaign wave needs matching enemy and weight arrays: " + path)
			return []
		waves.append(wave)
	return waves


func _wave_for_round(round_number: int) -> WaveDefinition:
	if _authored_waves.is_empty():
		return null
	if round_number > _authored_waves.size() and not _endless_mode:
		return null
	if _endless_mode and round_number > _authored_waves.size():
		if ENDLESS_WAVE_PATTERNS.is_empty():
			push_error("Endless Night has no authored wave patterns.")
			return null
		var endless_round_index := round_number - _authored_waves.size() - 1
		var pattern_index := posmod(endless_round_index, ENDLESS_WAVE_PATTERNS.size())
		var cycle_index := floori(float(endless_round_index) / float(ENDLESS_WAVE_PATTERNS.size()))
		var wave := ENDLESS_WAVE_PATTERNS[pattern_index].duplicate(true) as WaveDefinition
		wave.id = StringName("endless_%03d" % round_number)
		wave.planned_spawn_count = maxi(16, wave.planned_spawn_count + wave.endless_cycle_spawn_delta * cycle_index)
		wave.enemy_health_multiplier += float(cycle_index) * 0.14
		wave.max_alive += mini(cycle_index, 24)
		wave.spawn_interval = maxf(0.55, wave.spawn_interval / (1.0 + float(cycle_index) * 0.025))
		_extend_endless_roster(wave, pattern_index, cycle_index, round_number)
		return wave
	return _authored_waves[round_number - 1]


func _phase_for_round(round_number: int) -> ShiftPhaseDefinition:
	if shift_schedule.phases.is_empty():
		return null
	var phase_index: int = posmod(maxi(0, round_number - 1), shift_schedule.phases.size())
	return shift_schedule.phases[phase_index]


func _run_cycle_multiplier() -> int:
	return maxi(0, int(floor(float(maxi(1, _round_number) - 1) / float(maxi(1, shift_schedule.phases.size())))))


func _current_health_multiplier() -> float:
	if _current_wave != null:
		return _current_wave.enemy_health_multiplier
	if _current_phase == null:
		return 1.0
	return _current_phase.enemy_health_multiplier * (1.0 + float(_run_cycle_multiplier()) * 0.15)


func _current_spawn_interval() -> float:
	if _current_wave != null:
		return _current_wave.spawn_interval
	if _current_phase == null:
		return 1.5
	return maxf(0.35, _current_phase.spawn_interval / (1.0 + float(_run_cycle_multiplier()) * 0.08))


func _current_max_alive() -> int:
	if _current_wave != null:
		return _current_wave.max_alive
	if _current_phase == null:
		return 12
	return _current_phase.max_alive + _run_cycle_multiplier() * 2


func _current_spawn_budget() -> int:
	if _current_wave == null:
		return 0
	return _current_wave.planned_spawn_count


func _extend_endless_roster(wave: WaveDefinition, pattern_index: int, cycle_index: int, round_number: int) -> void:
	if wave == null or ENDLESS_SUPPLEMENTAL_ENEMIES.is_empty():
		return
	var supplemental: EnemyDefinition
	for offset: int in range(ENDLESS_SUPPLEMENTAL_ENEMIES.size()):
		var candidate := ENDLESS_SUPPLEMENTAL_ENEMIES[posmod(pattern_index + cycle_index + offset, ENDLESS_SUPPLEMENTAL_ENEMIES.size())]
		var already_present := false
		for existing: EnemyDefinition in wave.enemy_definitions:
			if existing != null and existing.id == candidate.id:
				already_present = true
				break
		if not already_present:
			supplemental = candidate
			break
	if supplemental == null:
		return
	var weapon_controller := _player.get_node_or_null("AutoWeapon") if is_instance_valid(_player) else null
	var average_tier := 1.0
	if weapon_controller != null and weapon_controller.has_method("get_unlocked_weapon_ids"):
		var weapon_ids: Array = weapon_controller.call("get_unlocked_weapon_ids")
		if not weapon_ids.is_empty():
			var tier_sum := 0.0
			for weapon_id: StringName in weapon_ids:
				tier_sum += float(weapon_controller.call("get_weapon_tier", weapon_id))
			average_tier = tier_sum / float(weapon_ids.size())
	var player_level := maxi(1, _player.current_level) if is_instance_valid(_player) else 1
	var expected_level := 1.0 + float(maxi(0, round_number - 1)) * 0.5
	var level_advantage := clampf(float(player_level) - expected_level, 0.0, 10.0)
	var new_weight := clampf(0.055 + float(mini(cycle_index, 6)) * 0.003 + level_advantage * 0.0015 + (average_tier - 1.0) * 0.004, 0.055, 0.12)
	var definitions: Array[EnemyDefinition] = wave.enemy_definitions.duplicate()
	var weights: Array[float] = wave.spawn_weights.duplicate()
	var total_weight := 0.0
	for index: int in range(definitions.size()):
		total_weight += maxf(0.0, weights[index])
	if total_weight <= 0.0:
		return
	for index: int in range(weights.size()):
		weights[index] = maxf(0.0, weights[index] / total_weight * (1.0 - new_weight))
	definitions.append(supplemental)
	weights.append(new_weight)
	wave.enemy_definitions = definitions
	wave.spawn_weights = weights


func _setup_endless_deployable_ambush() -> void:
	_deployable_ambush_pending = false
	_deployable_ambush_time = INF
	_deployable_ambush_deadline = INF
	_deployable_ambush_retry_timer = 0.0
	if not _endless_mode or _current_wave == null or _round_number <= _authored_waves.size() or not is_instance_valid(_player):
		return
	var inventory := _player.get_shop_inventory_summary()
	var turret_weapon_count := 0
	var active_turret_count := 0
	var highest_turret_tier := 1
	for deployable: Dictionary in inventory.get("deployables", []):
		if String(deployable.get("kind", "")) in ["turret", "mine"]:
			turret_weapon_count += 1
			active_turret_count += maxi(0, int(deployable.get("count", 0)))
			highest_turret_tier = maxi(highest_turret_tier, int(deployable.get("tier", 1)))
	if turret_weapon_count <= 0:
		return
	var cycle_index := maxi(0, floori(float(_round_number - _authored_waves.size() - 1) / float(ENDLESS_WAVE_PATTERNS.size())))
	var seed_value := _endless_ambush_seed_base ^ (_round_number * 73856093) ^ (_player.current_level * 19349663) ^ (highest_turret_tier * 83492791)
	_endless_ambush_rng.seed = maxi(1, absi(seed_value))
	var window_start := clampf(6.5 - float(mini(_player.current_level, 30)) * 0.035 - float(mini(highest_turret_tier - 1, 3)) * 0.35, 4.0, 6.5)
	var window_end := minf(20.0, _round_duration * 0.36)
	window_end = minf(window_end, window_start + 8.0 + float(mini(active_turret_count, 4)) * 0.35 + float(mini(cycle_index, 5)) * 0.25)
	if window_end <= window_start:
		return
	_deployable_ambush_time = _endless_ambush_rng.randf_range(window_start, window_end)
	_deployable_ambush_deadline = minf(_round_duration * 0.68, _deployable_ambush_time + 12.0)
	_deployable_ambush_pending = true


func _active_room_deployables() -> Array[Node2D]:
	var deployables: Array[Node2D] = []
	for candidate: Node in get_tree().get_nodes_in_group("deployed_structures"):
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate is Node2D:
			continue
		if StringName(candidate.get_meta("room_id", _current_room_id)) != _current_room_id:
			continue
		deployables.append(candidate as Node2D)
	return deployables


func _tick_endless_deployable_ambush(delta: float) -> void:
	if not _deployable_ambush_pending or _round_elapsed < _deployable_ambush_time or _state != RunState.RUNNING:
		return
	if _spawned_this_wave >= _current_spawn_budget() or _alive_enemy_count() >= _current_max_alive():
		return
	_deployable_ambush_retry_timer = maxf(0.0, _deployable_ambush_retry_timer - delta)
	if _deployable_ambush_retry_timer > 0.0:
		return
	_deployable_ambush_retry_timer = 0.5
	var deployables := _active_room_deployables()
	var preferred_group := "deployed_turrets" if posmod(_round_number + floori(float(_round_number - _authored_waves.size() - 1) / float(ENDLESS_WAVE_PATTERNS.size())), 2) == 0 else "deployed_mines"
	var candidates: Array[Node2D] = []
	for structure: Node2D in deployables:
		if structure.is_in_group(preferred_group):
			candidates.append(structure)
	if candidates.is_empty():
		candidates = deployables
	var spawn_point := Vector2(INF, INF)
	if not candidates.is_empty():
		var structure := candidates[_endless_ambush_rng.randi_range(0, candidates.size() - 1)]
		spawn_point = _deployable_ambush_spawn_point(structure)
	if not spawn_point.is_finite() and _round_elapsed >= _deployable_ambush_deadline:
		spawn_point = _safe_edge_spawn_point()
	if not spawn_point.is_finite() and _round_elapsed >= _deployable_ambush_deadline:
		spawn_point = _spawn_position()
	if not spawn_point.is_finite():
		return
	var definition := _wave_director.choose_enemy(_current_wave.enemy_definitions, _current_wave.spawn_weights, _build_wave_context())
	if definition == null:
		_deployable_ambush_pending = false
		return
	_spawn_enemy(definition, _current_health_multiplier(), false, spawn_point)
	_spawned_this_wave += 1
	_deployable_ambush_pending = false
	_recent_turret_ambush_positions.append(spawn_point)
	if _recent_turret_ambush_positions.size() > 5:
		_recent_turret_ambush_positions.pop_front()


func _deployable_ambush_spawn_point(structure: Node2D) -> Vector2:
	if not is_instance_valid(structure):
		return Vector2(INF, INF)
	var is_mine := structure.is_in_group("deployed_mines")
	var min_radius := 144.0 if is_mine else 96.0
	var max_radius := 252.0 if is_mine else 220.0
	for _attempt: int in range(48):
		var radius := _endless_ambush_rng.randf_range(min_radius, max_radius)
		var point := structure.global_position + Vector2.RIGHT.rotated(_endless_ambush_rng.randf_range(0.0, TAU)) * radius
		point.x = clampf(point.x, SPAWN_MIN_X, SPAWN_MAX_X)
		point.y = clampf(point.y, SPAWN_MIN_Y, SPAWN_MAX_Y)
		if point.distance_to(_player.global_position) < SPAWN_MIN_PLAYER_DISTANCE or not _spawn_point_is_clear(point):
			continue
		var recently_used := false
		for previous: Vector2 in _recent_turret_ambush_positions:
			if previous.distance_squared_to(point) < 96.0 * 96.0:
				recently_used = true
				break
		if not recently_used:
			return point
	return Vector2(INF, INF)


func _safe_edge_spawn_point() -> Vector2:
	var edge_points: Array[Vector2] = [
		Vector2(SPAWN_MIN_X + 24.0, -100.0), Vector2(SPAWN_MAX_X - 24.0, -100.0),
		Vector2(SPAWN_MIN_X + 24.0, 170.0), Vector2(SPAWN_MAX_X - 24.0, 170.0),
		Vector2(-430.0, SPAWN_MIN_Y + 24.0), Vector2(0.0, SPAWN_MIN_Y + 24.0), Vector2(430.0, SPAWN_MIN_Y + 24.0),
		Vector2(-430.0, SPAWN_MAX_Y - 24.0), Vector2(0.0, SPAWN_MAX_Y - 24.0), Vector2(430.0, SPAWN_MAX_Y - 24.0),
	]
	for attempt: int in range(edge_points.size()):
		var index := posmod(attempt + _endless_ambush_rng.randi_range(0, edge_points.size() - 1), edge_points.size())
		var point := edge_points[index]
		if point.distance_to(_player.global_position) >= SPAWN_MIN_PLAYER_DISTANCE and _spawn_point_is_clear(point):
			return point
	return Vector2(INF, INF)


func _is_boss_round() -> bool:
	if _current_wave != null:
		if _endless_mode and _round_number > _authored_waves.size():
			return _current_wave.is_boss_wave
		return _current_wave.is_boss_wave or posmod(_round_number, 5) == 0
	return posmod(_round_number, maxi(1, shift_schedule.phases.size())) == 0


func _boss_definition_for_round() -> EnemyDefinition:
	if _current_wave != null and _current_wave.is_boss_wave and _current_wave.boss_definition != null:
		return _current_wave.boss_definition
	return shift_schedule.boss_definition


func _boss_health_multiplier() -> float:
	var encounter_scale := 1.0
	if _current_wave != null and not _current_wave.is_boss_wave:
		match _round_number:
			5:
				encounter_scale = 0.28
			10:
				encounter_scale = 0.42
			15:
				encounter_scale = 0.58
	return _current_health_multiplier() * encounter_scale


func _current_damage_multiplier() -> float:
	return _wave_director.damage_multiplier(_build_wave_context())


func _build_wave_context() -> Dictionary:
	var context := {
		"round": _round_number,
		"level": maxi(1, _player.current_level),
		"spawn_index": _spawned_this_wave,
		"average_tier": 1.0,
		"combat_upgrade_ranks": 0.0,
		"crowd_power": 0.0,
		"precision_power": 0.0,
		"offense_index": 1.0,
		"survivability": _player.get_survivability_profile(),
		"wave_health_multiplier": _current_health_multiplier(),
		"spawn_rate": 0.52,
		"max_alive": float(_current_max_alive()),
		"spawn_interval": _current_spawn_interval(),
	}
	if _current_wave != null and _current_wave.duration_seconds > 0.0:
		context["spawn_rate"] = float(_current_wave.planned_spawn_count) / _current_wave.duration_seconds
	else:
		context["spawn_rate"] = 0.52 / (1.0 + float(_run_cycle_multiplier()) * 0.08)
	var weapon_controller: Node = _player.get_node_or_null("AutoWeapon")
	var estimated_output: float = 0.0
	if weapon_controller != null and weapon_controller.has_method("get_unlocked_weapon_ids"):
		var unlocked: Array = weapon_controller.call("get_unlocked_weapon_ids")
		var tier_total: float = 0.0
		for weapon_id_value: Variant in unlocked:
			var weapon_id := StringName(weapon_id_value)
			var tier: int = int(weapon_controller.call("get_weapon_tier", weapon_id)) if weapon_controller.has_method("get_weapon_tier") else 1
			tier_total += float(tier)
			var definition := _weapon_definition(weapon_id)
			if definition == null:
				continue
			var tier_factor: float = 1.0 + float(maxi(0, tier - 1)) * 0.18
			var estimated_damage: float = float(definition.damage) * pow(1.2, float(maxi(0, tier - 1)))
			var estimated_interval: float = maxf(0.05, definition.fire_interval * pow(0.93, float(maxi(0, tier - 1))))
			var estimated_count: float = float(definition.projectile_count)
			for tier_step: int in range(2, tier + 1):
				if tier_step % 2 == 1:
					estimated_count += 1.0
			match definition.attack_mode:
				WeaponDefinition.AttackMode.ORBITAL_CONTACT:
					context["crowd_power"] = float(context["crowd_power"]) + 1.0 * tier_factor
				WeaponDefinition.AttackMode.RETURNING_PROJECTILE:
					context["crowd_power"] = float(context["crowd_power"]) + (0.55 + float(definition.pierce_count) * 0.18 + float(definition.projectile_count) * 0.1) * tier_factor
				WeaponDefinition.AttackMode.DEPLOYED_SLOW_ZONE:
					context["crowd_power"] = float(context["crowd_power"]) + (0.45 + definition.area_radius / 180.0) * tier_factor
				WeaponDefinition.AttackMode.TARGETED_PROJECTILE:
					context["precision_power"] = float(context["precision_power"]) + (0.5 + float(definition.damage) / 45.0) * tier_factor
					context["crowd_power"] = float(context["crowd_power"]) + (float(definition.pierce_count) * 0.16 + float(definition.projectile_count - 1) * 0.18 + definition.area_radius / 220.0) * tier_factor
			var estimated_pierce: float = float(definition.pierce_count)
			var estimated_area: float = definition.area_radius
			for upgrade: UpgradeDefinition in UPGRADE_DEFINITIONS:
				if upgrade.target_weapon_id != &"" and upgrade.target_weapon_id != weapon_id:
					continue
				var rank: int = _player.get_upgrade_rank(upgrade.id)
				if rank <= 0:
					continue
				match upgrade.effect:
					UpgradeDefinition.Effect.WEAPON_DAMAGE_ADD:
						estimated_damage += upgrade.value * float(rank)
					UpgradeDefinition.Effect.WEAPON_DAMAGE_MULTIPLIER:
						estimated_damage *= pow(maxf(0.1, 1.0 + upgrade.value), float(rank))
					UpgradeDefinition.Effect.FIRE_RATE_MULTIPLIER:
						estimated_interval /= pow(maxf(0.1, 1.0 + upgrade.value), float(rank))
					UpgradeDefinition.Effect.PROJECTILE_COUNT_ADD:
						estimated_count += upgrade.value * float(rank)
					UpgradeDefinition.Effect.WEAPON_PIERCE_ADD:
						estimated_pierce += upgrade.value * float(rank)
					UpgradeDefinition.Effect.WEAPON_RADIUS_ADD:
						estimated_area += upgrade.value * float(rank)
			var hit_opportunity: float = 1.0 + estimated_pierce * 0.16 + minf(1.0, estimated_area / 180.0) * 0.25
			estimated_output += maxf(0.0, estimated_damage) * maxf(1.0, estimated_count) / estimated_interval * hit_opportunity
		if not unlocked.is_empty():
			context["average_tier"] = tier_total / float(unlocked.size())
	for upgrade: UpgradeDefinition in UPGRADE_DEFINITIONS:
		var rank: int = _player.get_upgrade_rank(upgrade.id)
		if rank <= 0:
			continue
		if upgrade.effect in [
			UpgradeDefinition.Effect.WEAPON_DAMAGE_ADD,
			UpgradeDefinition.Effect.FIRE_RATE_MULTIPLIER,
			UpgradeDefinition.Effect.PROJECTILE_COUNT_ADD,
			UpgradeDefinition.Effect.PROJECTILE_SPEED_MULTIPLIER,
			UpgradeDefinition.Effect.WEAPON_DAMAGE_MULTIPLIER,
			UpgradeDefinition.Effect.WEAPON_PIERCE_ADD,
			UpgradeDefinition.Effect.WEAPON_RADIUS_ADD,
		]:
			context["combat_upgrade_ranks"] = float(context["combat_upgrade_ranks"]) + float(rank)
	var starter_definition := _weapon_definition(&"can_launcher")
	var starter_output: float = 1.0
	if starter_definition != null:
		starter_output = float(starter_definition.damage) * float(starter_definition.projectile_count) / maxf(0.05, starter_definition.fire_interval)
	context["offense_index"] = maxf(0.5, estimated_output / starter_output) * _player.get_attack_damage_multiplier() * pow(1.0 + float(context["combat_upgrade_ranks"]) * 0.015, 0.2)
	return context


func _weapon_definition(weapon_id: StringName) -> WeaponDefinition:
	for definition: WeaponDefinition in WEAPON_DEFINITIONS:
		if definition.id == weapon_id:
			return definition
	return null


func _spawn_from_phase() -> void:
	if _current_phase == null and _current_wave == null:
		return
	var max_alive := _current_max_alive()
	var planned_budget := _current_spawn_budget()
	if _deployable_ambush_pending:
		# Reserve one legal live slot and one authored spawn slot for the scheduled
		# deployable encounter. The event itself still obeys both limits.
		max_alive = maxi(0, max_alive - 1)
		if planned_budget > 0:
			planned_budget = maxi(0, planned_budget - 1)
	if _alive_enemy_count() >= max_alive:
		return
	if _current_wave != null and _current_spawn_budget() > 0 and _spawned_this_wave >= planned_budget:
		return
	var definition := _wave_director.choose_enemy(_current_wave.enemy_definitions, _current_wave.spawn_weights, _build_wave_context()) if _current_wave != null else _weighted_enemy(_current_phase)
	if definition != null:
		_spawn_enemy(definition, _current_health_multiplier())
		_spawned_this_wave += 1


func _weighted_enemy(phase: ShiftPhaseDefinition) -> EnemyDefinition:
	return _weighted_enemy_from_arrays(phase.enemy_definitions, phase.spawn_weights)


func _weighted_enemy_from_arrays(definitions: Array[EnemyDefinition], weights: Array[float]) -> EnemyDefinition:
	if definitions.is_empty():
		return null
	var total_weight := 0.0
	for index: int in range(definitions.size()):
		var weight := weights[index] if index < weights.size() else definitions[index].spawn_weight
		total_weight += maxf(0.0, weight)
	if total_weight <= 0.0:
		return definitions.pick_random()
	var roll := randf() * total_weight
	for index: int in range(definitions.size()):
		var weight := weights[index] if index < weights.size() else definitions[index].spawn_weight
		roll -= maxf(0.0, weight)
		if roll <= 0.0:
			return definitions[index]
	return definitions.back()


func _spawn_enemy(
		definition: EnemyDefinition, health_multiplier: float, boss: bool = false,
		forced_spawn_point: Vector2 = Vector2(INF, INF)) -> void:
	if definition == null:
		return
	var spawn_point: Vector2 = forced_spawn_point
	if not spawn_point.is_finite():
		spawn_point = _boss_spawn_position() if boss else _spawn_position()
	if not spawn_point.is_finite():
		return
	var enemy := ENEMY_SCENE.instantiate() as EnemyActor
	if enemy == null:
		push_error("Enemy scene must have an EnemyActor root.")
		return
	enemy.configure(definition, health_multiplier, _player, _current_damage_multiplier())
	enemy.set_meta("room_id", _current_room_id)
	if boss:
		enemy.health_changed.connect(_on_boss_health_changed)
	_actor_layer.add_child(enemy)
	enemy.global_position = spawn_point
	enemy.defeated.connect(_on_enemy_defeated)
	if boss:
		_hud.set_phase_name("BOSS: " + definition.display_name)
		BakkalAudio.play_sfx(&"boss_arrival")
		_on_boss_health_changed(enemy.get_health(), maxi(1, roundi(float(definition.max_health) * health_multiplier)))


func _spawn_position() -> Vector2:
	for _attempt: int in range(40):
		var direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		var point := _player.global_position + direction * randf_range(330.0, 430.0)
		point.x = clampf(point.x, SPAWN_MIN_X, SPAWN_MAX_X)
		point.y = clampf(point.y, SPAWN_MIN_Y, SPAWN_MAX_Y)
		if point.distance_to(_player.global_position) >= SPAWN_MIN_PLAYER_DISTANCE and _spawn_point_is_clear(point):
			return point
	# If random attempts land on fixtures or existing actors, search the walkable
	# floor. A failed search skips the spawn instead of using an unchecked point.
	for y: int in range(-150, 251, 48):
		for x: int in range(-550, 551, 48):
			var point := Vector2(x, y)
			if point.distance_to(_player.global_position) >= SPAWN_MIN_PLAYER_DISTANCE and _spawn_point_is_clear(point):
				return point
	return Vector2(INF, INF)


func _boss_spawn_position() -> Vector2:
	var entrance := Vector2(0.0, 250.0)
	if _spawn_point_is_clear(entrance):
		return entrance
	return _spawn_position()


func _spawn_point_is_clear(point: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _spawn_clearance_shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = 5 # Store fixtures and existing enemy bodies.
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if is_instance_valid(_player):
		query.exclude = [_player.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _on_enemy_defeated(definition: EnemyDefinition, death_position: Vector2) -> void:
	_kills += 1
	_currency += maxi(1, definition.xp_reward * 2)
	_hud.set_kill_count(_kills)
	_spawn_xp_orb(definition.xp_reward, death_position)
	if _current_room_id == &"depot" and is_instance_valid(_room_event_director):
		_room_event_director.roll_requested_supply_drop(death_position)
	if definition.role == EnemyDefinition.Role.BOSS:
		_boss_defeated = true
		_hud.set_phase_name("%s CLEARED" % definition.display_name.to_upper())
		_hud.hide_boss_health()
		# Bosses pay out a visible extra XP pickup and a guaranteed health pack.
		_spawn_xp_orb(maxi(6, roundi(float(definition.xp_reward) * 0.5)), death_position + Vector2(0, -24))
		_spawn_consumable(death_position + Vector2(30, 0), ConsumablePickup.Reward.HEALTH)
		_spawn_consumable(death_position + Vector2(-30, 0), ConsumablePickup.Reward.ENERGY)
	elif randf() < 0.035:
		_spawn_consumable(death_position, ConsumablePickup.Reward.HEALTH)


func _spawn_xp_orb(amount: int, position: Vector2) -> void:
	call_deferred("_spawn_xp_orb_now", amount, position)


func _spawn_xp_orb_now(amount: int, position: Vector2) -> void:
	var orb := XP_ORB_SCENE.instantiate() as Node2D
	if orb == null:
		return
	_pickup_layer.add_child(orb)
	orb.set_meta("room_id", _current_room_id)
	orb.global_position = position
	orb.set("xp_amount", maxi(1, amount))
	_set_pickup_room_presence(orb)


func _spawn_consumable(position: Vector2, reward: int) -> void:
	call_deferred("_spawn_consumable_now", position, reward)


func _spawn_consumable_now(position: Vector2, reward: int) -> void:
	var pickup := CONSUMABLE_SCENE.instantiate() as ConsumablePickup
	if pickup == null:
		return
	pickup.reward = reward
	if reward == ConsumablePickup.Reward.HEALTH:
		pickup.amount = 18
	else:
		pickup.speed_multiplier = 1.28
		pickup.duration = 6.0
	_pickup_layer.add_child(pickup)
	pickup.set_meta("room_id", _current_room_id)
	pickup.global_position = position
	_set_pickup_room_presence(pickup)


func _set_pickup_room_presence(pickup: Area2D) -> void:
	var active := StringName(pickup.get_meta("room_id", &"market")) == _current_room_id
	pickup.visible = active
	pickup.set_deferred("monitoring", active)
	pickup.set_deferred("monitorable", active)
	pickup.set_deferred("collision_layer", 8 if active else 0)
	pickup.set_deferred("collision_mask", 2 if active else 0)


func _spawn_random_powerup() -> void:
	var existing_powerups := 0
	for pickup: Node in _pickup_layer.get_children():
		if pickup is ConsumablePickup:
			existing_powerups += 1
	if existing_powerups >= 2:
		_powerup_cooldown = 10.0
		return
	var point := _random_walkable_point()
	if not point.is_finite():
		_powerup_cooldown = 8.0
		return
	_spawn_consumable_now(point, ConsumablePickup.Reward.HEALTH if randf() < 0.55 else ConsumablePickup.Reward.ENERGY)


func _random_walkable_point() -> Vector2:
	for _attempt: int in range(64):
		var point := Vector2(randf_range(-550.0, 550.0), randf_range(-150.0, 245.0))
		if point.distance_to(_player.global_position) >= 140.0 and _spawn_point_is_clear(point):
			return point
	return Vector2(INF, INF)


func _on_player_health_changed(current: int, maximum: int) -> void:
	_hud.update_health(current, maximum)


func _on_boss_health_changed(current: int, maximum: int) -> void:
	var boss_definition := _boss_definition_for_round()
	var boss_name := boss_definition.display_name if boss_definition != null else "ELITE"
	_hud.set_boss_health(boss_name.to_upper(), current, maximum)


func _on_room_event_message(room_id: StringName, message: String) -> void:
	var room_names := {
		&"market": "MAIN MARKET",
		&"depot": "STOCKROOM",
		&"manager_office": "MANAGER OFFICE",
		&"restroom": "RESTROOM",
	}
	_hud.show_room_event_message(String(room_names.get(room_id, "STORE")), message)


func _on_room_event_objective_changed(supply_id: StringName, collected: int, required: int) -> void:
	if required <= 0:
		return
	_hud.show_room_event_message(
		"STOCK REQUEST",
		"%s  %d / %d" % [String(supply_id).replace("_", " ").to_upper(), collected, required]
	)


func _on_room_event_helper_summoned(duration: float) -> void:
	_hud.show_room_event_message("STOCKROOM REWARD", "TEMPORARY HELPER  ·  %d SEC" % roundi(duration))


func _on_player_progress_changed(xp: int, needed: int, level: int) -> void:
	_hud.update_progress(xp, needed, level)


func _on_player_level_up(_new_level: int) -> void:
	if _state == RunState.RESULTS or _state == RunState.PAUSED:
		return
	_pending_level_ups += 1
	BakkalAudio.play_sfx(&"level_up")


func _complete_round() -> void:
	if _state != RunState.RUNNING:
		return
	if _is_boss_round() and _boss_spawned and not _boss_defeated:
		# The boss can outlast the shift timer; its round still clears into the shop.
		_hud.hide_boss_health()
	_state = RunState.ROUND_CLEAR
	for actor: Node in _actor_layer.get_children():
		if actor is EnemyActor:
			actor.queue_free()
	for projectile: Node in _projectile_layer.get_children():
		if not projectile.is_in_group("deployed_structures"):
			projectile.queue_free()
	for pickup: Node in _pickup_layer.get_children():
		if pickup is SurvivorXpOrb:
			pickup.collect_for_player(_player)
		elif pickup is ConsumablePickup:
			pickup.collect_for_player(_player)
			pickup.queue_free()
		elif pickup is RoomSupplyPickup:
			pickup.queue_free()
	call_deferred("_open_intermission")


func _open_intermission() -> void:
	if _state != RunState.ROUND_CLEAR:
		return
	if _pending_level_ups > 0:
		_show_next_stat_choice()
	else:
		_open_shop()


func _show_next_stat_choice() -> void:
	if _pending_level_ups <= 0 or _state == RunState.RESULTS:
		_open_shop()
		return
	_pending_level_ups -= 1
	_active_stat_choices.clear()
	for choice: Dictionary in _build_level_choices():
		if _player.can_apply_level_choice(choice):
			_active_stat_choices.append(choice)
	_active_stat_choices.shuffle()
	if _active_stat_choices.size() > 4:
		_active_stat_choices.resize(4)
	_state = RunState.LEVEL_UP
	get_tree().paused = true
	_hud.show_stat_choices(_active_stat_choices, _player.get_shop_summary())


func _build_level_choices() -> Array[Dictionary]:
	var progress_tier := mini(4, floori(float(_player.current_level - 1) / 5.0) + floori(float(_round_number - 1) / 5.0))
	var health_bonus := 4 + progress_tier
	var damage_bonus := minf(0.12, 0.07 + float(progress_tier) * 0.01)
	var speed_bonus := minf(0.09, 0.06 + float(progress_tier) * 0.0075)
	var lifesteal_bonus := minf(0.04, 0.025 + float(progress_tier) * 0.00375)
	var elemental_bonus := mini(3, 1 + floori(float(progress_tier) / 2.0))
	var bundle_health := 2 + progress_tier
	var bundle_protection := minf(0.04, 0.02 + float(progress_tier) * 0.005)
	var bundle_speed := minf(0.055, 0.035 + float(progress_tier) * 0.005)
	var bundle_dodge := minf(0.03, 0.015 + float(progress_tier) * 0.00375)
	var choices: Array[Dictionary] = [
		{"id": &"health_pickup", "name": "Break-room soup", "description": "A hearty meal raises your maximum health.", "effects": [{"stat": &"max_health", "value": health_bonus}]},
		{"id": &"damage_pickup", "name": "Heavy-duty price gun", "description": "A sturdier grip improves every hit.", "effects": [{"stat": &"damage", "value": minf(0.10, 0.04 + float(progress_tier) * 0.015)}]},
		{"id": &"steady_footing_bundle", "name": "Fresh aisle runners", "description": "A better pace helps you slip past trouble.", "effects": [{"stat": &"move_speed", "value": bundle_speed}, {"stat": &"dodge", "value": bundle_dodge}]},
		{"id": &"apron_bundle", "name": "Reinforced apron", "description": "Extra padding and a little more room to take a hit.", "effects": [{"stat": &"protection", "value": bundle_protection}, {"stat": &"max_health", "value": bundle_health}]},
		{"id": &"elemental_bundle", "name": "Aisle-rinse concentrate", "description": "Stronger mist and a small reserve of extra health.", "effects": [{"stat": &"elemental_damage", "value": elemental_bonus}, {"stat": &"max_health", "value": 1 + floori(float(progress_tier) / 2.0)}]},
		{"id": &"damage_tradeoff", "name": "Marked-down cans", "description": "Pack a harder hit, take on less maximum health.", "effects": [{"stat": &"damage", "value": damage_bonus}, {"stat": &"max_health", "value": -3}]},
		{"id": &"speed_tradeoff", "name": "Non-slip shoes", "description": "Move faster, give up a little force.", "effects": [{"stat": &"move_speed", "value": speed_bonus}, {"stat": &"damage", "value": -0.04}]},
		{"id": &"lifesteal_tradeoff", "name": "Energy drink", "description": "Recover on hits, lose some staying power.", "effects": [{"stat": &"lifesteal", "value": lifesteal_bonus}, {"stat": &"max_health", "value": -3}]},
	]
	var weapon_targets := _player.get_level_choice_weapon_targets()
	if weapon_targets.is_empty():
		return choices
	var target_index := posmod(_player.current_level + _round_number, weapon_targets.size())
	var primary: Dictionary = weapon_targets[target_index]
	var primary_id := String(primary.get("id", ""))
	var primary_name := String(primary.get("name", "equipped tool"))
	var primary_is_elemental := int(primary.get("damage_type", WeaponDefinition.DamageType.PHYSICAL)) == WeaponDefinition.DamageType.ELEMENTAL
	var primary_supports_rate := bool(primary.get("supports_fire_rate", true))
	var weapon_damage_bonus := mini(4, 1 + floori(float(progress_tier + int(primary.get("tier", 1))) / 2.0))
	var weapon_rate_bonus := minf(0.12, 0.04 + float(progress_tier) * 0.015)
	choices.append({
		"id": &"aisle_tool_calibration",
		"name": "Aisle-tool calibration",
		"description": "%s lands a firmer hit after the mid-shift tune-up." % primary_name,
		"effects": [{"stat": &"weapon_damage", "value": weapon_damage_bonus, "label": "%s damage" % primary_name, "weapon_id": primary_id}],
	})
	var tuneup_name := "Closer's tune-up"
	var tuneup_description := "Rebalance %s for a faster, slightly stronger cycle." % primary_name
	var tuneup_effects: Array[Dictionary] = [
		{"stat": &"weapon_damage", "value": maxi(1, weapon_damage_bonus - 1), "label": "%s damage" % primary_name, "weapon_id": primary_id},
		{"stat": &"weapon_fire_rate", "value": weapon_rate_bonus, "label": "%s fire rate" % primary_name, "weapon_id": primary_id},
	]
	if primary_is_elemental:
		tuneup_name = "Pressure-regulator tune-up"
		tuneup_description = "Set %s to a stronger spray and keep its cycle moving." % primary_name
		tuneup_effects[1] = {"stat": &"elemental_damage", "value": elemental_bonus, "label": "Elemental Damage"}
	elif not primary_supports_rate:
		tuneup_name = "Steady-hand reinforcement"
		tuneup_description = "Brace %s for cleaner, harder contact." % primary_name
		tuneup_effects[1] = {"stat": &"protection", "value": bundle_protection}
	choices.append({
		"id": &"closer_tuneup_bundle",
		"name": tuneup_name,
		"description": tuneup_description,
		"effects": tuneup_effects,
	})
	var extra_effects: Array[Dictionary] = [
		{"stat": &"weapon_damage", "value": weapon_damage_bonus, "label": "%s damage" % primary_name, "weapon_id": primary_id},
		{"stat": &"move_speed", "value": minf(0.04, 0.02 + float(progress_tier) * 0.005)},
	]
	if primary_is_elemental:
		extra_effects.append({"stat": &"elemental_damage", "value": elemental_bonus, "label": "Elemental Damage"})
	elif primary_supports_rate:
		var secondary_name := primary_name
		var secondary_id := primary_id
		if weapon_targets.size() > 1:
			for offset: int in range(1, weapon_targets.size()):
				var secondary_index := posmod(target_index + offset, weapon_targets.size())
				var secondary: Dictionary = weapon_targets[secondary_index]
				if bool(secondary.get("supports_fire_rate", true)):
					secondary_name = String(secondary.get("name", "backup tool"))
					secondary_id = String(secondary.get("id", ""))
					break
		extra_effects.append({"stat": &"weapon_fire_rate", "value": minf(0.08, weapon_rate_bonus * 0.75), "label": "%s fire rate" % secondary_name, "weapon_id": secondary_id})
	else:
		extra_effects.append({"stat": &"protection", "value": minf(0.04, 0.02 + float(progress_tier) * 0.005)})
	choices.append({
		"id": &"closing_round_routine",
		"name": "Closing-round routine",
		"description": "A practice lap for %s, with a little more room to move." % primary_name,
		"effects": extra_effects,
	})
	var tradeoff_positive: Dictionary
	var tradeoff_name := "Overclocked register"
	var tradeoff_description := "Run %s faster, at the cost of your general striking force." % primary_name
	if primary_supports_rate:
		tradeoff_positive = {"stat": &"weapon_fire_rate", "value": minf(0.14, weapon_rate_bonus + 0.025), "label": "%s fire rate" % primary_name, "weapon_id": primary_id}
	else:
		tradeoff_name = "Heavy-handed restock"
		tradeoff_description = "Hit harder with %s, but give up some general striking force." % primary_name
		tradeoff_positive = {"stat": &"weapon_damage", "value": weapon_damage_bonus, "label": "%s damage" % primary_name, "weapon_id": primary_id}
	choices.append({
		"id": &"overclocked_register_tradeoff",
		"name": tradeoff_name,
		"description": tradeoff_description,
		"effects": [tradeoff_positive, {"stat": &"damage", "value": -minf(0.08, 0.04 + float(progress_tier) * 0.01)}],
	})
	if bool(primary.get("is_structure", false)):
		var engineering_bonus := mini(5, 2 + progress_tier)
		choices.append({
			"id": &"engineering_shift_training",
			"name": "Fixture maintenance",
			"description": "Tune your deployed gear; higher Engineering adds direct turret and mine damage.",
			"effects": [{"stat": &"engineering", "value": engineering_bonus, "label": "Engineering"}],
		})
		choices.append({
			"id": &"structure_and_stock_bundle",
			"name": "Spare-parts crate",
			"description": "Improve the equipped %s and your fixture output." % primary_name,
			"effects": [
				{"stat": &"weapon_damage", "value": mini(3, weapon_damage_bonus), "label": "%s damage" % primary_name, "weapon_id": primary_id},
				{"stat": &"engineering", "value": 1 + floori(float(progress_tier) / 2.0), "label": "Engineering"},
			],
		})
	if weapon_targets.size() > 1:
		var secondary_index := posmod(target_index + 1, weapon_targets.size())
		var secondary: Dictionary = weapon_targets[secondary_index]
		var secondary_id := String(secondary.get("id", ""))
		var secondary_name := String(secondary.get("name", "backup tool"))
		choices.append({
			"id": &"cross_tool_rebalance",
			"name": "Borrowed torque",
			"description": "Move one point of force from %s into %s." % [secondary_name, primary_name],
			"effects": [
				{"stat": &"weapon_damage", "value": mini(3, weapon_damage_bonus), "label": "%s damage" % primary_name, "weapon_id": primary_id},
				{"stat": &"weapon_damage", "value": -1, "label": "%s damage" % secondary_name, "weapon_id": secondary_id},
			],
		})
	return choices


func _on_stat_choice_selected(choice_id: StringName) -> void:
	if _state != RunState.LEVEL_UP:
		return
	var selected_choice: Dictionary = {}
	for choice: Dictionary in _active_stat_choices:
		if StringName(String(choice.get("id", ""))) == choice_id:
			selected_choice = choice
			break
	if selected_choice.is_empty() or not _player.apply_level_choice(selected_choice):
		return
	_active_stat_choices.clear()
	_hud.hide_overlay()
	if _pending_level_ups > 0:
		_show_next_stat_choice()
	else:
		_open_shop()


func _open_shop() -> void:
	if _state == RunState.SHOP or _shop_open_round == _round_number:
		return
	if not _endless_mode and not _authored_waves.is_empty() and _round_number >= _authored_waves.size():
		_finish_run(true)
		return
	_state = RunState.SHOP
	_shop_open_round = _round_number
	get_tree().paused = true
	_shop_reroll_count = 0
	_purchased_shop_indices.clear()
	_locked_shop_indices.clear()
	_active_shop_offers = _roll_shop_offers()
	_active_shop_prices = _prices_for_offers(_active_shop_offers)
	_shop.show_shop(_round_number, _currency, _active_shop_offers, _active_shop_prices, _reroll_price(), _purchased_shop_indices, _player.get_shop_summary(), _weapon_names())


func _roll_shop_offers(excluded_keys: Dictionary = {}) -> Array:
	var candidates: Array = []
	var weapon_controller := _player.get_node_or_null("AutoWeapon")
	for weapon: WeaponDefinition in WEAPON_DEFINITIONS:
		if weapon_controller == null or not weapon_controller.has_method("has_weapon"):
			continue
		var owns_weapon := bool(weapon_controller.call("has_weapon", weapon.id))
		if not owns_weapon:
			if weapon_controller.has_method("get_weapon_slot_count") and int(weapon_controller.call("get_weapon_slot_count")) < SurvivorAutoWeapon.MAX_WEAPON_SLOTS:
				var new_offer := weapon.duplicate(true) as WeaponDefinition
				new_offer.tier = 1
				new_offer.shop_offer_kind = WeaponDefinition.ShopOfferKind.NEW_WEAPON
				candidates.append(new_offer)
			continue
		var current_tier := int(weapon_controller.call("get_weapon_tier", weapon.id)) if weapon_controller.has_method("get_weapon_tier") else 1
		if current_tier < 4:
			var merge_offer := weapon.duplicate(true) as WeaponDefinition
			merge_offer.tier = current_tier + 1
			merge_offer.shop_offer_kind = WeaponDefinition.ShopOfferKind.MERGE_COPY
			merge_offer.description = "Buy a matching copy to merge this tool into Tier %s." % _tier_roman(current_tier + 1)
			candidates.append(merge_offer)
			var available_direct_tier := clampi(1 + floori(float(_round_number + _player.current_level) / 9.0), 2, 4)
			if current_tier + 1 < available_direct_tier:
				var direct_offer := weapon.duplicate(true) as WeaponDefinition
				direct_offer.tier = available_direct_tier
				direct_offer.shop_offer_kind = WeaponDefinition.ShopOfferKind.DIRECT_TIER
				direct_offer.description = "Skip the merge and upgrade this tool directly to Tier %s." % _tier_roman(available_direct_tier)
				candidates.append(direct_offer)
	for upgrade: UpgradeDefinition in UPGRADE_DEFINITIONS:
		if not _player.can_apply_upgrade(upgrade):
			continue
		if upgrade.effect == UpgradeDefinition.Effect.UNLOCK_WEAPON:
			# New weapons already have a dedicated tier-aware offer, so avoid two
			# different cards competing for the same unlock.
			continue
		candidates.append(upgrade)
	candidates.shuffle()
	var offers: Array = []
	var candidate_keys: Dictionary = {}
	for candidate: Variant in candidates:
		if offers.size() >= ShiftShop.MAX_OFFERS:
			break
		var key := _shop_candidate_key(candidate)
		if candidate_keys.has(key) or excluded_keys.has(key):
			continue
		candidate_keys[key] = true
		offers.append(candidate)
	for stat_offer: Dictionary in _eligible_stat_shop_offers():
		if offers.size() >= ShiftShop.MAX_OFFERS:
			break
		var key := _shop_candidate_key(stat_offer)
		if candidate_keys.has(key) or excluded_keys.has(key):
			continue
		candidate_keys[key] = true
		offers.append(stat_offer)
	# Health and speed are always valid repeatable stats. If every authored
	# upgrade/weapon is capped and lifesteal/dodge have hit their limits, use a
	# separately keyed repeatable stat offer to keep all three slots actionable.
	var repeat_index: int = 0
	while offers.size() < ShiftShop.MAX_OFFERS and repeat_index < 16:
		var fallback := _repeatable_stat_fallback(repeat_index)
		if fallback.is_empty():
			break
		var fallback_key := _shop_candidate_key(fallback)
		repeat_index += 1
		if candidate_keys.has(fallback_key) or excluded_keys.has(fallback_key):
			continue
		candidate_keys[fallback_key] = true
		offers.append(fallback)
	return offers


func _eligible_stat_shop_offers() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for choice: Dictionary in _build_stat_choices():
		var choice_id := StringName(choice.get("id", &""))
		if not _player.can_apply_level_stat_delta(choice_id, float(choice.get("value", 0.0))):
			continue
		offers.append({
			"kind": "stat",
			"id": choice_id,
			"name": String(choice.get("name", "SHIFT BONUS")),
			"description": String(choice.get("description", "Apply a run stat bonus.")),
			"value": float(choice.get("value", 0.0)),
		})
	return offers


func _build_stat_choices() -> Array[Dictionary]:
	var progress_tier := mini(4, floori(float(_player.current_level - 1) / 5.0) + floori(float(_round_number - 1) / 5.0))
	var speed_bonus := 0.03 + float(progress_tier) * 0.01
	var health_bonus := 3 + progress_tier * 2
	var lifesteal_bonus := minf(0.07, 0.02 + float(progress_tier) * 0.0125)
	var dodge_bonus := minf(0.07, 0.02 + float(progress_tier) * 0.0125)
	var protection_bonus := minf(0.07, 0.03 + float(progress_tier) * 0.01)
	return [
		{"id": &"speed", "name": "QUICKER FEET", "description": "+%d%% movement speed for this run." % roundi(speed_bonus * 100.0), "value": speed_bonus},
		{"id": &"health", "name": "HEALTHIER SHIFT", "description": "+%d maximum health and restore %d health now." % [health_bonus, health_bonus], "value": float(health_bonus)},
		{"id": &"lifesteal", "name": "RETURNING ENERGY", "description": "Recover %d%% of damage dealt as health." % roundi(lifesteal_bonus * 100.0), "value": lifesteal_bonus},
		{"id": &"dodge", "name": "QUICK REFLEXES", "description": "+%d%% chance to dodge an incoming hit." % roundi(dodge_bonus * 100.0), "value": dodge_bonus},
		{"id": &"protection", "name": "PROTECTIVE APRON", "description": "Reduce each hit's damage by %d%% for this run." % roundi(protection_bonus * 100.0), "value": protection_bonus},
	]


func _repeatable_stat_fallback(variant_index: int) -> Dictionary:
	var choices: Array[Dictionary] = _build_stat_choices()
	var repeatable_choices: Array[Dictionary] = []
	for choice: Dictionary in choices:
		var choice_id := StringName(choice.get("id", &""))
		if choice_id in [&"health", &"speed", &"protection"] and _player.can_apply_level_stat_delta(choice_id, float(choice.get("value", 0.0))):
			repeatable_choices.append(choice)
	if repeatable_choices.is_empty():
		return {}
	var choice: Dictionary = repeatable_choices[posmod(variant_index, repeatable_choices.size())]
	var choice_id := StringName(choice.get("id", &""))
	return {
		"kind": "stat",
		"id": choice_id,
		"name": String(choice.get("name", "SHIFT BONUS")),
		"description": String(choice.get("description", "Apply a run stat bonus.")),
		"value": float(choice.get("value", 0.0)),
		"offer_key": "stat:%s:repeat:%d" % [String(choice_id), variant_index],
	}


func _shop_candidate_key(offer: Variant) -> String:
	if offer is Dictionary:
		return String(offer.get("offer_key", "stat:%s" % String(offer.get("id", "unknown"))))
	if offer is WeaponDefinition:
		return "weapon:%s:%d:%d" % [String(offer.id), offer.shop_offer_kind, offer.tier]
	if offer is UpgradeDefinition:
		return "upgrade:%s" % String(offer.id)
	return "unknown"


func _tier_roman(tier: int) -> String:
	return ["I", "II", "III", "IV"][clampi(tier, 1, 4) - 1]


func _prices_for_offers(offers: Array) -> Array[int]:
	var prices: Array[int] = []
	for offer: Variant in offers:
		var progression := _round_number + floori(float(_player.current_level) / 2.0)
		var offer_id: StringName = StringName(offer.get("id", &"")) if offer is Dictionary else StringName(offer.id)
		var base_price := 7 + _player.get_upgrade_rank(offer_id) * 3
		if offer is WeaponDefinition:
			match offer.shop_offer_kind:
				WeaponDefinition.ShopOfferKind.NEW_WEAPON:
					base_price = 12
				WeaponDefinition.ShopOfferKind.MERGE_COPY:
					base_price = 10 + offer.tier * 3
				WeaponDefinition.ShopOfferKind.DIRECT_TIER:
					base_price = 12 + offer.tier * offer.tier * 3
		prices.append(clampi(base_price + floori(float(progression) * (0.8 if offer is WeaponDefinition else 0.5)), 1, 999))
	return prices


func _reroll_price() -> int:
	return 5 + _shop_reroll_count * 3


func _on_shop_offer_purchased(index: int) -> void:
	if _state != RunState.SHOP or index < 0 or index >= _active_shop_offers.size():
		return
	if _purchased_shop_indices.has(index):
		return
	if index >= _active_shop_prices.size() or _currency < _active_shop_prices[index]:
		_shop.set_shop_state(_currency, _active_shop_offers, _active_shop_prices, _reroll_price(), _purchased_shop_indices, _locked_shop_indices)
		return
	var offer: Variant = _active_shop_offers[index]
	var purchased := false
	if offer is WeaponDefinition:
		var weapon_controller := _player.get_node_or_null("AutoWeapon")
		purchased = weapon_controller != null and weapon_controller.has_method("purchase_weapon_offer") and bool(weapon_controller.call("purchase_weapon_offer", offer))
	elif offer is UpgradeDefinition:
		purchased = _player.apply_upgrade(offer)
	elif offer is Dictionary and String(offer.get("kind", "")) == "stat":
		var stat_id := StringName(offer.get("id", &""))
		purchased = _player.can_apply_level_stat_delta(stat_id, float(offer.get("value", 0.0))) and _player.apply_level_stat(stat_id, float(offer.get("value", 0.0)))
	if not purchased:
		return
	_currency -= _active_shop_prices[index]
	if not _purchased_shop_indices.has(index):
		_purchased_shop_indices.append(index)
	_hud.set_weapons(_weapon_names())
	_shop.set_shop_state(_currency, _active_shop_offers, _active_shop_prices, _reroll_price(), _purchased_shop_indices, _locked_shop_indices)
	_shop.set_shop_summary(_player.get_shop_summary(), _weapon_names())


func _on_shop_weapon_sell_requested(weapon_id: StringName) -> void:
	if _state != RunState.SHOP:
		return
	var weapon_controller := _player.get_node_or_null("AutoWeapon")
	if weapon_controller == null or not weapon_controller.has_method("sell_weapon"):
		return
	var sold: Dictionary = weapon_controller.call("sell_weapon", weapon_id)
	if sold.is_empty():
		return
	_currency += int(sold.get("payout", 0))
	_hud.set_weapons(_weapon_names())
	_shop.set_shop_state(_currency, _active_shop_offers, _active_shop_prices, _reroll_price(), _purchased_shop_indices, _locked_shop_indices)
	_shop.set_shop_summary(_player.get_shop_summary(), _weapon_names())


func _on_shop_reroll_requested() -> void:
	if _state != RunState.SHOP:
		return
	var cost := _reroll_price()
	if _currency < cost:
		_shop.set_shop_state(_currency, _active_shop_offers, _active_shop_prices, cost, _purchased_shop_indices, _locked_shop_indices)
		return
	_currency -= cost
	_shop_reroll_count += 1
	var locked_by_index: Dictionary = {}
	var locked_keys: Dictionary = {}
	var next_purchased: Array[int] = []
	for index: int in _locked_shop_indices:
		if index < 0 or index >= _active_shop_offers.size():
			continue
		locked_by_index[index] = {"offer": _active_shop_offers[index], "price": _active_shop_prices[index] if index < _active_shop_prices.size() else 0}
		locked_keys[_shop_candidate_key(_active_shop_offers[index])] = true
		if _purchased_shop_indices.has(index):
			next_purchased.append(index)
	var rerolled_offers := _roll_shop_offers(locked_keys)
	var rerolled_prices := _prices_for_offers(rerolled_offers)
	var next_offers: Array = []
	var next_prices: Array[int] = []
	var rolled_index := 0
	var next_locked: Array[int] = []
	for index: int in range(ShiftShop.MAX_OFFERS):
		if locked_by_index.has(index):
			var saved: Dictionary = locked_by_index[index]
			next_offers.append(saved["offer"])
			next_prices.append(int(saved["price"]))
			next_locked.append(index)
		else:
			if rolled_index < rerolled_offers.size():
				next_offers.append(rerolled_offers[rolled_index])
				next_prices.append(rerolled_prices[rolled_index])
				rolled_index += 1
	_active_shop_offers = next_offers
	_active_shop_prices = next_prices
	_locked_shop_indices = next_locked
	_purchased_shop_indices = next_purchased
	_shop.set_shop_state(_currency, _active_shop_offers, _active_shop_prices, _reroll_price(), _purchased_shop_indices, _locked_shop_indices)
	_shop.set_shop_summary(_player.get_shop_summary(), _weapon_names())


func _on_shop_offer_lock_toggled(index: int, locked: bool) -> void:
	if _state != RunState.SHOP or index < 0 or index >= _active_shop_offers.size():
		return
	if locked and not _locked_shop_indices.has(index):
		_locked_shop_indices.append(index)
	elif not locked:
		_locked_shop_indices.erase(index)
	_shop.set_shop_state(_currency, _active_shop_offers, _active_shop_prices, _reroll_price(), _purchased_shop_indices, _locked_shop_indices)


func _on_shop_continue_requested() -> void:
	if _state != RunState.SHOP:
		return
	_shop.visible = false
	_round_number += 1
	_round_elapsed = 0.0
	_health_regen_elapsed = 0.0
	_player.heal(maxi(1, roundi(float(_player.max_health) * 0.10)))
	_boss_spawned = false
	_boss_defeated = false
	_powerup_cooldown = randf_range(18.0, 32.0)
	_spawn_cooldown = 1.2
	_select_phase(true)
	_state = RunState.RUNNING
	get_tree().paused = false
	_hud.set_round_clock(_round_number, _round_elapsed, _round_duration)


func _pause_run() -> void:
	if _state != RunState.RUNNING:
		return
	_state = RunState.PAUSED
	get_tree().paused = true


func _resume_run() -> void:
	if _state != RunState.PAUSED:
		return
	_state = RunState.RUNNING
	get_tree().paused = false
	_hud.hide_overlay()


func _restart_run() -> void:
	RunSaveManager.clear_saved_run()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_player_died() -> void:
	RunSaveManager.clear_saved_run()
	_finish_run(false)


func _finish_run(victory: bool) -> void:
	if _state == RunState.RESULTS:
		return
	_state = RunState.RESULTS
	RunSaveManager.clear_saved_run()
	BakkalAudio.play_sfx(&"shift_survived" if victory else &"shift_lost")
	var score := maxi(0, _kills * 25 + _player.current_level * 100 + int(_elapsed * 2.0) + (500 if victory else 0))
	if _endless_mode:
		_best_endless_score = maxi(_best_endless_score, score)
		_best_endless_wave = maxi(_best_endless_wave, _round_number)
	else:
		_best_score = maxi(_best_score, score)
	_save_records()
	get_tree().paused = true
	var report := {
		"time": _elapsed,
		"kills": _kills,
		"level": _player.current_level,
		"weapons": " / ".join(_weapon_names()),
		"boss": "CLEARED" if _boss_defeated else "NOT CLEARED",
		"mode": "ENDLESS NIGHT" if _endless_mode else "20-ROUND CAMPAIGN",
		"round": _round_number,
		"score": score,
		"best_score": _best_endless_score if _endless_mode else _best_score,
		"best_wave": _best_endless_wave,
	}
	_hud.show_results(report, victory)


func _gather_save_state() -> Dictionary:
	var weapon_controller := _player.get_node_or_null("AutoWeapon")
	var weapons_data: Array = []
	if weapon_controller != null and weapon_controller.has_method("get_save_data"):
		weapons_data = weapon_controller.call("get_save_data")
	var p_data: Dictionary = {}
	if _player.has_method("get_save_data"):
		p_data = _player.call("get_save_data")

	return {
		"round_number": _round_number,
		"round_elapsed": _round_elapsed,
		"elapsed": _elapsed,
		"kills": _kills,
		"currency": _currency,
		"endless_mode": _endless_mode,
		"current_room_id": String(_current_room_id),
		"player": p_data,
		"weapons": weapons_data,
	}


func _restore_run_state(saved_data: Dictionary) -> void:
	_round_number = maxi(1, int(saved_data.get("round_number", 1)))
	_round_elapsed = float(saved_data.get("round_elapsed", 0.0))
	_elapsed = float(saved_data.get("elapsed", 0.0))
	_kills = maxi(0, int(saved_data.get("kills", 0)))
	_currency = maxi(0, int(saved_data.get("currency", 0)))
	_endless_mode = bool(saved_data.get("endless_mode", false))
	var room_name := String(saved_data.get("current_room_id", "market"))
	if _rooms.has(StringName(room_name)) and StringName(room_name) != _current_room_id:
		_complete_room_transition(StringName(room_name), Vector2(0.0, 180.0))

	var p_data: Dictionary = saved_data.get("player", {})
	if not p_data.is_empty() and _player.has_method("restore_save_data"):
		_player.call("restore_save_data", p_data)

	var w_list: Array = saved_data.get("weapons", [])
	var weapon_controller := _player.get_node_or_null("AutoWeapon")
	if weapon_controller != null and weapon_controller.has_method("restore_save_data"):
		weapon_controller.call("restore_save_data", w_list)

	_hud.set_weapons(_weapon_names())
	_hud.set_kill_count(_kills)
	_select_phase(true)
	_hud.set_round_clock(_round_number, _round_elapsed, _round_duration)


func _on_save_and_quit_requested() -> void:
	var state_data := _gather_save_state()
	RunSaveManager.save_run_state(state_data)
	get_tree().paused = false
	_open_title()


func _open_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/title/title.tscn")


func _weapon_names() -> PackedStringArray:
	var weapon := _player.get_node_or_null("AutoWeapon")
	if weapon != null and weapon.has_method("get_unlocked_weapon_names"):
		return weapon.call("get_unlocked_weapon_names")
	return PackedStringArray(["Can Launcher"])


func _alive_enemy_count() -> int:
	var count := 0
	for actor: Node in _actor_layer.get_children():
		if actor is EnemyActor and StringName(actor.get_meta("room_id", &"market")) == _current_room_id:
			count += 1
	return count


func _load_records() -> void:
	var config := ConfigFile.new()
	if config.load(RECORD_PATH) == OK:
		_best_score = int(config.get_value("records", "best_campaign_score", config.get_value("records", "best_score", 0)))
		_best_endless_score = int(config.get_value("records", "best_endless_score", 0))
		_best_endless_wave = int(config.get_value("records", "best_endless_wave", 0))


func _save_records() -> void:
	var config := ConfigFile.new()
	config.set_value("records", "best_score", _best_score)
	config.set_value("records", "best_campaign_score", _best_score)
	config.set_value("records", "best_endless_score", _best_endless_score)
	config.set_value("records", "best_endless_wave", _best_endless_wave)
	config.save(RECORD_PATH)
