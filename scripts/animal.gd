extends CharacterBody2D
class_name Animal

## Base Animal Controller for Night Harvest
##
## Features:
## - Strict 4-Direction Cardinal Movement (UP, DOWN, LEFT, RIGHT)
## - Zero diagonal movement
## - Movement direction matches visual sprite facing (flip_h)
## - Idle and walking states with configurable timers
## - Reusable for Chickens, Cows, Pigs, and Sheep

@export var walk_speed: float = 25.0
@export var min_walk_time: float = 1.0
@export var max_walk_time: float = 3.0
@export var min_idle_time: float = 1.0
@export var max_idle_time: float = 3.0

var direction: Vector2 = Vector2.ZERO
var state: String = "idle"
var timer: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const CARDINAL_DIRECTIONS: Array[Vector2] = [
	Vector2.UP,
	Vector2.DOWN,
	Vector2.LEFT,
	Vector2.RIGHT
]


func _ready() -> void:
	add_to_group("animals")
	randomize()
	start_idle()


func _physics_process(delta: float) -> void:
	timer -= delta

	if timer <= 0.0:
		if state == "idle":
			start_walking()
		else:
			start_idle()

	if state == "walking":
		velocity = direction * walk_speed
		# Switch to idle if blocked by wall/obstacle
		if is_on_wall():
			start_idle()
		else:
			move_and_slide()
	else:
		velocity = Vector2.ZERO


func start_idle() -> void:
	state = "idle"
	timer = randf_range(min_idle_time, max_idle_time)
	velocity = Vector2.ZERO
	_play_anim("idle")


func start_walking() -> void:
	state = "walking"

	# Pick strictly from 4 cardinal directions (UP, DOWN, LEFT, RIGHT)
	direction = CARDINAL_DIRECTIONS[randi() % CARDINAL_DIRECTIONS.size()]

	# Slightly random walking speed
	walk_speed = randf_range(18.0, 30.0)

	# Walk for a random amount of time
	timer = randf_range(min_walk_time, max_walk_time)

	# Update visual facing
	_update_facing(direction)
	_play_anim("walk")


func _update_facing(dir: Vector2) -> void:
	if not animated_sprite:
		return
	
	# Horizontal flipping
	if dir == Vector2.LEFT:
		animated_sprite.flip_h = true
	elif dir == Vector2.RIGHT:
		animated_sprite.flip_h = false
	# If moving UP or DOWN, keep current horizontal facing or face direction if animation exists
	
	# Check for directional animations if scene supports them (e.g. walk_up, walk_down, walk_left, walk_right)
	var dir_suffix := ""
	if dir == Vector2.UP:
		dir_suffix = "_up"
	elif dir == Vector2.DOWN:
		dir_suffix = "_down"
	elif dir == Vector2.LEFT:
		dir_suffix = "_left"
	elif dir == Vector2.RIGHT:
		dir_suffix = "_right"
	
	if dir_suffix != "" and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("walk" + dir_suffix):
			animated_sprite.play("walk" + dir_suffix)
		elif animated_sprite.sprite_frames.has_animation("idle" + dir_suffix) and state == "idle":
			animated_sprite.play("idle" + dir_suffix)


func _play_anim(base_name: String) -> void:
	if not animated_sprite:
		return
	if not animated_sprite.sprite_frames:
		return
	
	# Try specific animation first
	if animated_sprite.sprite_frames.has_animation(base_name):
		if animated_sprite.animation != base_name or not animated_sprite.is_playing():
			animated_sprite.play(base_name)
	elif animated_sprite.sprite_frames.has_animation("default"):
		if animated_sprite.animation != "default" or not animated_sprite.is_playing():
			animated_sprite.play("default")
