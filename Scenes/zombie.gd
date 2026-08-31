extends CharacterBody2D

## Natural Zombie AI for Night Harvest
##
## Features:
## - Strict 4-Direction Cardinal Movement (UP, DOWN, LEFT, RIGHT)
## - Zero diagonal movement
## - Movement direction strictly matches visual sprite facing
## - face_target(target: Node2D) cardinal calculation
## - Zombie faces player BEFORE starting attack animation
## - Directional attack hitbox delivery
## - Full State Machine: IDLE, WANDER, ALERT, CHASE, ATTACK, SEARCH, HURT, DEAD
## - Uses provided sprite sheets: idle, walk, attack, hurt, dead
## - Independent real-time per-zombie health bar
## - 30-hit player survivability balance (damage = 3)
## - Integrates with player attack system (take_damage)
## - Emits EventBus.zombie_killed on death

enum State {
	IDLE,
	WANDER,
	ALERT,
	CHASE,
	ATTACK,
	SEARCH,
	HURT,
	DEAD
}

# --- Stats ---
@export var max_health: int = 100
@export var attack_damage: int = 3
@export var wander_speed: float = 22.0
@export var chase_speed: float = 48.0
@export var detection_range: float = 95.0
@export var lose_range: float = 155.0
@export var attack_range: float = 22.0
@export var attack_cooldown_time: float = 1.2

var current_health: int = 100
var current_state: State = State.IDLE
var is_dead: bool = false
var facing_direction: Vector2 = Vector2.DOWN

# --- Cardinal Directions (Strict 4-Way Movement) ---
const CARDINAL_DIRECTIONS: Array[Vector2] = [
	Vector2.UP,
	Vector2.DOWN,
	Vector2.LEFT,
	Vector2.RIGHT
]

# --- Timers & Internal State ---
var _state_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _wander_direction: Vector2 = Vector2.DOWN
var _last_known_player_pos: Vector2 = Vector2.ZERO
var _attack_hit_delivered: bool = false

# --- Node References ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = $HealthBar


func _ready() -> void:
	add_to_group("zombies")
	add_to_group("enemies")
	
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = true
	
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
		if not animated_sprite.frame_changed.is_connected(_on_sprite_frame_changed):
			animated_sprite.frame_changed.connect(_on_sprite_frame_changed)
	
	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if is_dead or current_state == State.DEAD:
		return
	
	# Attack cooldown countdown
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
	
	# State timer countdown
	if _state_timer > 0.0:
		_state_timer -= delta
	
	# Handle knockback decay when hurt
	if current_state == State.HURT:
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		move_and_slide()
		return
	
	var player := _get_player()
	
	match current_state:
		State.IDLE:
			_process_idle(player)
		State.WANDER:
			_process_wander(player, delta)
		State.ALERT:
			_process_alert(player)
		State.CHASE:
			_process_chase(player, delta)
		State.ATTACK:
			_process_attack(player)
		State.SEARCH:
			_process_search(player, delta)
	
	move_and_slide()


# ==============================================================================
# STATE HANDLERS
# ==============================================================================

func _enter_state(new_state: State) -> void:
	current_state = new_state
	
	match new_state:
		State.IDLE:
			velocity = Vector2.ZERO
			_state_timer = randf_range(1.5, 3.5)
			_play_anim("idle")
		
		State.WANDER:
			# Pick strictly from 4 cardinal directions (UP, DOWN, LEFT, RIGHT)
			_wander_direction = CARDINAL_DIRECTIONS[randi() % CARDINAL_DIRECTIONS.size()]
			facing_direction = _wander_direction
			_state_timer = randf_range(2.0, 4.0)
			_apply_directional_facing(_wander_direction)
			_play_anim("walk")
		
		State.ALERT:
			velocity = Vector2.ZERO
			_state_timer = 0.35 # Brief reaction pause
			_play_anim("idle")
		
		State.CHASE:
			_play_anim("walk")
		
		State.ATTACK:
			velocity = Vector2.ZERO
			_attack_hit_delivered = false
			_play_anim("attack")
		
		State.SEARCH:
			_state_timer = 2.5
			_play_anim("walk")
		
		State.HURT:
			_state_timer = 0.25
			_play_anim("hurt")
		
		State.DEAD:
			velocity = Vector2.ZERO
			_play_anim("dead")


func _process_idle(player: CharacterBody2D) -> void:
	# Check if player detected
	if player and _can_detect_player(player):
		_last_known_player_pos = player.global_position
		face_target(player)
		_enter_state(State.ALERT)
		return
	
	# Timer expired -> wander
	if _state_timer <= 0.0:
		_enter_state(State.WANDER)


func _process_wander(player: CharacterBody2D, _delta: float) -> void:
	# Check if player detected
	if player and _can_detect_player(player):
		_last_known_player_pos = player.global_position
		face_target(player)
		_enter_state(State.ALERT)
		return
	
	# Move strictly in current cardinal wander direction
	velocity = _wander_direction * wander_speed
	_apply_directional_facing(_wander_direction)
	
	# Timer expired or hit obstacle -> idle
	if _state_timer <= 0.0 or is_on_wall():
		_enter_state(State.IDLE)


func _process_alert(player: CharacterBody2D) -> void:
	if player:
		face_target(player)
	
	if _state_timer <= 0.0:
		_enter_state(State.CHASE)


func _process_chase(player: CharacterBody2D, _delta: float) -> void:
	if not player:
		_enter_state(State.IDLE)
		return
	
	var diff := player.global_position - global_position
	var dist := diff.length()
	_last_known_player_pos = player.global_position
	
	# Lost player
	if dist > lose_range:
		_enter_state(State.SEARCH)
		return
	
	# In attack range
	if dist <= attack_range:
		# MUST face player BEFORE entering ATTACK and BEFORE playing attack animation
		face_target(player)
		if _attack_cooldown_timer <= 0.0:
			_enter_state(State.ATTACK)
			return
		else:
			# Cooldown waiting: stay in place facing player
			velocity = Vector2.ZERO
			_play_anim("idle")
			return
	
	# 4-Direction movement towards player (strictly cardinal, NO diagonals)
	var move_dir := _get_chase_cardinal_direction(diff)
	facing_direction = move_dir
	velocity = move_dir * chase_speed
	_apply_directional_facing(move_dir)
	_play_anim("walk")


func _process_attack(player: CharacterBody2D) -> void:
	velocity = Vector2.ZERO
	# Continually ensure zombie faces player during attack
	if player:
		face_target(player)


func _process_search(player: CharacterBody2D, _delta: float) -> void:
	# Check if player re-entered detection range
	if player and _can_detect_player(player):
		_last_known_player_pos = player.global_position
		face_target(player)
		_enter_state(State.CHASE)
		return
	
	var diff_to_search := _last_known_player_pos - global_position
	if diff_to_search.length() > 12.0:
		var search_dir := get_cardinal_direction(diff_to_search)
		facing_direction = search_dir
		velocity = search_dir * wander_speed
		_apply_directional_facing(search_dir)
		_play_anim("walk")
	else:
		# Arrived at last known spot, look around
		velocity = Vector2.ZERO
		_play_anim("idle")
		if _state_timer <= 0.0:
			_enter_state(State.IDLE)


# ==============================================================================
# CARDINAL DIRECTION & FACING SYSTEM
# ==============================================================================

## Reusable function to face a target in one of the 4 cardinal directions (UP, DOWN, LEFT, RIGHT).
## Determines whether the target is primarily above, below, left, or right, and updates facing.
func face_target(target: Node2D) -> void:
	if not target or not is_instance_valid(target):
		return
	
	var diff: Vector2 = target.global_position - global_position
	var cardinal := get_cardinal_direction(diff)
	facing_direction = cardinal
	_apply_directional_facing(cardinal)


## Determines the single closest cardinal direction (UP, DOWN, LEFT, RIGHT) from a vector.
## Never returns a diagonal vector.
func get_cardinal_direction(vec: Vector2) -> Vector2:
	if abs(vec.x) >= abs(vec.y):
		return Vector2.RIGHT if vec.x > 0 else Vector2.LEFT
	else:
		return Vector2.DOWN if vec.y > 0 else Vector2.UP


## Determines cardinal chase direction with wall obstacle fallback.
## Strictly returns UP, DOWN, LEFT, or RIGHT.
func _get_chase_cardinal_direction(diff: Vector2) -> Vector2:
	var primary: Vector2 = Vector2.ZERO
	var secondary: Vector2 = Vector2.ZERO
	
	if abs(diff.x) >= abs(diff.y):
		primary = Vector2.RIGHT if diff.x > 0 else Vector2.LEFT
		secondary = Vector2.DOWN if diff.y > 0 else Vector2.UP
	else:
		primary = Vector2.DOWN if diff.y > 0 else Vector2.UP
		secondary = Vector2.RIGHT if diff.x > 0 else Vector2.LEFT
	
	# If bumping against wall along primary axis, try secondary cardinal axis
	if is_on_wall() and abs(diff.y if primary.x != 0 else diff.x) > 6.0:
		return secondary
	
	return primary


## Applies visual sprite facing for a given cardinal direction.
## Handles horizontal flipping (flip_h) and directional animation variants if present.
func _apply_directional_facing(dir: Vector2) -> void:
	if not animated_sprite:
		return
	
	# Horizontal flipping
	if dir == Vector2.LEFT or dir.x < -0.1:
		animated_sprite.flip_h = true
	elif dir == Vector2.RIGHT or dir.x > 0.1:
		animated_sprite.flip_h = false
	
	# Check for directional animations if scene supports them (e.g. attack_up, walk_down, idle_left)
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
		var current_base := _get_current_base_anim()
		if animated_sprite.sprite_frames.has_animation(current_base + dir_suffix):
			animated_sprite.play(current_base + dir_suffix)


func _get_current_base_anim() -> String:
	match current_state:
		State.IDLE, State.ALERT:
			return "idle"
		State.WANDER, State.CHASE, State.SEARCH:
			return "walk"
		State.ATTACK:
			return "attack"
		State.HURT:
			return "hurt"
		State.DEAD:
			return "dead"
	return "idle"


# ==============================================================================
# ANIMATION & COMBAT EVENTS
# ==============================================================================

func _on_sprite_frame_changed() -> void:
	if is_dead:
		return
	
	# Attack impact at frame 3 (halfway through attack animation)
	if current_state == State.ATTACK and not _attack_hit_delivered:
		if animated_sprite and animated_sprite.frame >= 3:
			_attack_hit_delivered = true
			_deliver_attack_damage()


func _deliver_attack_damage() -> void:
	var player := _get_player()
	if not player or not is_instance_valid(player):
		return
	
	var diff := player.global_position - global_position
	var dist := diff.length()
	
	# Check distance reach
	if dist <= attack_range + 10.0:
		var cardinal_to_player := get_cardinal_direction(diff)
		# Zombie must be facing the player (or player is practically on top of zombie <= 14px)
		if cardinal_to_player == facing_direction or dist <= 14.0:
			if player.has_method("take_damage"):
				var push_dir := facing_direction if facing_direction != Vector2.ZERO else diff.normalized()
				player.take_damage(attack_damage, push_dir, 35.0)


func _on_animation_finished() -> void:
	if is_dead:
		return
	
	match current_state:
		State.ATTACK:
			_attack_cooldown_timer = attack_cooldown_time
			var player := _get_player()
			if player and _can_detect_player(player):
				face_target(player)
				_enter_state(State.CHASE)
			else:
				_enter_state(State.IDLE)
		
		State.HURT:
			var player := _get_player()
			if player:
				face_target(player)
				_enter_state(State.CHASE)
			else:
				_enter_state(State.IDLE)


## Called by player attack system (see ken_idle_front.gd: _execute_action_impact).
func take_damage(amount: int, direction: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> void:
	if is_dead or current_state == State.DEAD:
		return
	
	current_health = maxi(0, current_health - amount)
	
	# Update individual health bar immediately
	if health_bar:
		health_bar.value = current_health
	
	# Visual hit reaction (red flash)
	if animated_sprite:
		var tween := create_tween()
		animated_sprite.modulate = Color(1.8, 0.3, 0.3, 1.0)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.15)
	
	# Apply knockback
	if direction != Vector2.ZERO and knockback > 0.0:
		velocity = direction.normalized() * knockback
	
	# Check for death
	if current_health <= 0:
		_die()
		return
	
	# If zombie was wandering or idling, immediately alert/aggro on player
	var player := _get_player()
	if player:
		_last_known_player_pos = player.global_position
		face_target(player)
	
	_enter_state(State.HURT)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	_enter_state(State.DEAD)
	
	# Hide health bar
	if health_bar:
		health_bar.visible = false
	
	# Disable physics collision so player and other entities walk through corpse
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Notify QuestManager / EventBus
	var bus_nodes := get_tree().get_nodes_in_group("event_bus")
	for bus in bus_nodes:
		if is_instance_valid(bus) and bus.has_signal("zombie_killed"):
			bus.zombie_killed.emit()
			break
	
	# Play dead animation, then fade out and free
	if animated_sprite:
		_play_anim("dead")
		var tween := create_tween()
		tween.tween_interval(0.8) # Let dead animation display
		tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.4)
		tween.tween_callback(queue_free)
	else:
		queue_free()


# ==============================================================================
# HELPERS
# ==============================================================================

func _can_detect_player(player: CharacterBody2D) -> bool:
	if not player or not is_instance_valid(player):
		return false
	if player.get("_is_dead"):
		return false
	return global_position.distance_to(player.global_position) <= detection_range


func _play_anim(anim_name: String) -> void:
	if not animated_sprite:
		return
	
	# Try directional variant first if available
	var dir_suffix := ""
	if facing_direction == Vector2.UP:
		dir_suffix = "_up"
	elif facing_direction == Vector2.DOWN:
		dir_suffix = "_down"
	elif facing_direction == Vector2.LEFT:
		dir_suffix = "_left"
	elif facing_direction == Vector2.RIGHT:
		dir_suffix = "_right"
	
	if dir_suffix != "" and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name + dir_suffix):
		if animated_sprite.animation != (anim_name + dir_suffix) or not animated_sprite.is_playing():
			animated_sprite.play(anim_name + dir_suffix)
			return
	
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
			animated_sprite.play(anim_name)


func _get_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p is CharacterBody2D:
			return p
	return null
