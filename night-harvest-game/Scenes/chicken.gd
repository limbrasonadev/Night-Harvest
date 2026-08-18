extends CharacterBody2D

@export var walk_speed := 25.0
@export var min_walk_time := 1.0
@export var max_walk_time := 3.0
@export var min_idle_time := 1.0
@export var max_idle_time := 3.0

var direction := Vector2.ZERO
var state := "idle"
var timer := 0.0


func _ready() -> void:
	randomize()
	start_idle()


func _physics_process(delta: float) -> void:
	timer -= delta

	if timer <= 0:
		if state == "idle":
			start_walking()
		else:
			start_idle()

	if state == "walking":
		velocity = direction * walk_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO


func start_idle() -> void:
	state = "idle"
	timer = randf_range(min_idle_time, max_idle_time)
	velocity = Vector2.ZERO


func start_walking() -> void:
	state = "walking"

	# Pick a random direction
	var random_angle := randf_range(0.0, TAU)
	direction = Vector2.from_angle(random_angle)

	# Slightly random walking speed
	walk_speed = randf_range(20.0, 35.0)

	# Walk for a random amount of time
	timer = randf_range(min_walk_time, max_walk_time)
