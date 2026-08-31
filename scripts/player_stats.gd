extends Node
class_name PlayerStats

## Manages player health, defense, level, XP, and gold.
## Access via "player_stats" group.
##
## Defense Formula: final_damage = max(1, base_damage - int(current_defense / DEFENSE_DIVISOR))
## With DEFENSE_DIVISOR = 20:
##   0 defense  → 0 reduction  → zombie deals 3 → ~33 hits to die
##   20 defense → 1 reduction  → zombie deals 2 → 50 hits to die
##   40 defense → 2 reduction  → zombie deals 1 → 100 hits to die

signal health_changed(current_hp: int, max_hp: int)
signal defense_changed(current_def: int, max_def: int)
signal level_changed(new_level: int)
signal player_died()

# --- Health ---
@export var max_health: int = 100
var current_health: int = 100

# --- Defense ---
@export var max_defense: int = 50
@export var DEFENSE_DIVISOR: float = 20.0
var current_defense: int = 0

# --- Level / XP ---
@export var level: int = 1
var xp: int = 0
var xp_to_next_level: int = 100

# --- Gold ---
var gold: int = 0

# --- State ---
var is_dead: bool = false

# --- Damage Cooldown ---
@export var damage_cooldown: float = 0.5
var _cooldown_timer: float = 0.0
var _is_invulnerable: bool = false


func _ready() -> void:
	current_health = max_health
	add_to_group("player_stats")


func _process(delta: float) -> void:
	if _is_invulnerable:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_is_invulnerable = false
			_cooldown_timer = 0.0


## Apply damage with defense reduction. Returns actual damage dealt (0 if invulnerable).
func take_damage(base_damage: int) -> int:
	if is_dead or _is_invulnerable:
		return 0
	
	var reduction := int(current_defense / DEFENSE_DIVISOR)
	var final_damage := maxi(1, base_damage - reduction)
	
	current_health = maxi(0, current_health - final_damage)
	health_changed.emit(current_health, max_health)
	
	# Start invulnerability window
	_is_invulnerable = true
	_cooldown_timer = damage_cooldown
	
	if current_health <= 0:
		_die()
	
	return final_damage


## Restore health.
func heal(amount: int) -> void:
	if is_dead:
		return
	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


## Set defense value.
func set_defense(value: int) -> void:
	current_defense = clampi(value, 0, max_defense)
	defense_changed.emit(current_defense, max_defense)


## Add XP with automatic level-up.
func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		level += 1
		xp_to_next_level = int(xp_to_next_level * 1.2)
		level_changed.emit(level)


## Add gold.
func add_gold(amount: int) -> void:
	gold += amount


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	player_died.emit()


## Full reset (used on scene restart).
func reset() -> void:
	current_health = max_health
	is_dead = false
	_is_invulnerable = false
	_cooldown_timer = 0.0
	health_changed.emit(current_health, max_health)
	defense_changed.emit(current_defense, max_defense)
