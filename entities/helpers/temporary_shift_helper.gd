extends Node2D
class_name TemporaryShiftHelper
## A short-lived assistant earned from a room task. It follows the clerk and
## fires the existing projectile type at nearby enemies; run-specific state
## lives on this actor, never on a shared content Resource.

signal expired

const PROJECTILE_SCENE: PackedScene = preload("res://combat/projectile/projectile.tscn")

@export var follow_distance: float = 42.0
@export var follow_speed: float = 155.0
@export var target_range: float = 310.0
@export var projectile_speed: float = 470.0
@export var walk_atlas: Texture2D

const WALK_COLUMNS := 4
const WALK_ROWS := 4
const WALK_FRAMES_PER_DIRECTION := 4
const WALK_ANIMATION_SPEED := 7.0

@onready var _sprite: AnimatedSprite2D = $Sprite

var _owner_actor: Node2D
var _projectile_layer: Node2D
var _remaining: float = 0.0
var _damage: int = 5
var _fire_interval: float = 0.9
var _fire_cooldown: float = 0.25
var _orbit_angle: float = 0.0
var _active: bool = false
var _facing: StringName = &"down"


func _ready() -> void:
	_build_walk_animations()


func activate(
		owner_actor: Node2D,
		projectile_layer: Node2D,
		duration: float,
		damage: int,
		fire_interval: float = 0.9
) -> void:
	_owner_actor = owner_actor
	_projectile_layer = projectile_layer
	_remaining = maxf(1.0, duration)
	_damage = maxi(1, damage)
	_fire_interval = maxf(0.18, fire_interval)
	_fire_cooldown = 0.2
	_active = is_instance_valid(_owner_actor) and is_instance_valid(_projectile_layer)
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	if not is_instance_valid(_owner_actor) or not is_instance_valid(_projectile_layer):
		_finish()
		return
	_remaining -= delta
	if _remaining <= 0.0:
		_finish()
		return
	_orbit_angle = wrapf(_orbit_angle + delta * 1.6, 0.0, TAU)
	var offset := Vector2.RIGHT.rotated(_orbit_angle) * follow_distance
	var follow_target := _owner_actor.global_position + offset
	var previous_position := global_position
	global_position = global_position.move_toward(follow_target, follow_speed * delta)
	_update_walk_animation(global_position - previous_position)
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if _fire_cooldown <= 0.0:
		var target := _find_target()
		if is_instance_valid(target) and _fire_at(target):
			_fire_cooldown = _fire_interval


func _draw() -> void:
	if walk_atlas != null:
		return
	# Temporary vector silhouette until the dedicated helper sprite is made.
	# Keep it compact and separate from the enemy's collision footprint.
	draw_circle(Vector2(0.0, 5.0), 14.0, Color(0.04, 0.07, 0.06, 0.45))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-13, -8), Vector2(-9, -17), Vector2(9, -17), Vector2(13, -8),
			Vector2(10, 8), Vector2(-10, 8),
		]),
		Color("86c98a")
	)
	draw_rect(Rect2(Vector2(-11, -13), Vector2(22, 4)), Color("e4c56a"), true)
	draw_line(Vector2(-12, 10), Vector2(-15, 15), Color("263532"), 3.0, true)
	draw_line(Vector2(12, 10), Vector2(15, 15), Color("263532"), 3.0, true)
	draw_circle(Vector2(-5, -3), 2.0, Color("253d34"))
	draw_circle(Vector2(5, -3), 2.0, Color("253d34"))
	draw_line(Vector2(-3, 3), Vector2(3, 3), Color("253d34"), 1.5, true)


func _build_walk_animations() -> void:
	if walk_atlas == null:
		return
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var cell_size := Vector2(walk_atlas.get_size()) / Vector2(WALK_COLUMNS, WALK_ROWS)
	var direction_rows: Dictionary = {&"up": 0, &"left": 1, &"right": 2, &"down": 3}
	for direction: StringName in direction_rows:
		var row: int = direction_rows[direction]
		var walk_name := StringName("walk_" + String(direction))
		var idle_name := StringName("idle_" + String(direction))
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, WALK_ANIMATION_SPEED)
		frames.set_animation_loop(walk_name, true)
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 1.0)
		frames.set_animation_loop(idle_name, true)
		for column: int in WALK_FRAMES_PER_DIRECTION:
			var atlas_frame := AtlasTexture.new()
			atlas_frame.atlas = walk_atlas
			atlas_frame.region = Rect2(Vector2(column, row) * cell_size, cell_size)
			frames.add_frame(walk_name, atlas_frame)
			if column == 0:
				frames.add_frame(idle_name, atlas_frame)
	_sprite.sprite_frames = frames
	_sprite.play("idle_down")


func _update_walk_animation(movement: Vector2) -> void:
	if walk_atlas == null:
		return
	if movement.length_squared() > 0.05:
		if absf(movement.x) > absf(movement.y):
			_facing = &"right" if movement.x > 0.0 else &"left"
		else:
			_facing = &"down" if movement.y > 0.0 else &"up"
		_sprite.play(StringName("walk_" + String(_facing)))
	else:
		_sprite.play(StringName("idle_" + String(_facing)))


func _find_target() -> Node2D:
	var best: Node2D
	var best_distance_squared := target_range * target_range
	for candidate: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as Node2D
		if not is_instance_valid(enemy):
			continue
		if enemy.has_meta("room_id") and has_meta("room_id"):
			if StringName(enemy.get_meta("room_id")) != StringName(get_meta("room_id")):
				continue
		var distance_squared := global_position.distance_squared_to(enemy.global_position)
		if distance_squared < best_distance_squared:
			best = enemy
			best_distance_squared = distance_squared
	return best


func _fire_at(target: Node2D) -> bool:
	var projectile := PROJECTILE_SCENE.instantiate() as SurvivorProjectile
	if projectile == null:
		return false
	_projectile_layer.add_child(projectile)
	var direction := global_position.direction_to(target.global_position)
	projectile.global_position = global_position + direction * 12.0
	projectile.launch_with_stats(direction, _damage, projectile_speed, 1.2, 0)
	return true


func _finish() -> void:
	if not _active:
		return
	_active = false
	expired.emit()
	queue_free()
