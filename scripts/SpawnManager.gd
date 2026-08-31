extends Node2D
class_name SpawnManager

## Dedicated SpawnManager for Night Harvest
##
## Controls where zombies and animals spawn using editor-draggable Marker2D nodes.
##
## Scene Structure:
## SpawnManager (Node2D)
## ├── ZombieSpawnPoints (Node2D)
## │   ├── SpawnPoint01 (Marker2D)
## │   └── ...
## └── AnimalSpawnPoints (Node2D)
##     ├── SpawnPoint01 (Marker2D)
##     └── ...
##
## Features:
## - Spawns strictly at designated Marker2D points
## - No two enemies/animals spawn at the exact same point during one cycle
## - Configurable limits (max_zombies, max_animals)
## - Modular methods: spawn_zombies(), spawn_animals(), clear_zombies(), clear_animals()
## - Day/Night integration with GameClock

@export_group("Zombie Spawning")
@export var zombie_scene: PackedScene = preload("res://Scenes/zombie.tscn")
@export var max_zombies: int = 5
@export var min_player_distance_for_zombies: float = 120.0

@export_group("Animal Spawning")
@export var animal_scene: PackedScene = preload("res://Scenes/chicken.tscn")
@export var animal_scenes: Array[PackedScene] = [
	preload("res://Scenes/chicken.tscn"),
	preload("res://Scenes/cow.tscn"),
	preload("res://Scenes/pig.tscn"),
	preload("res://Scenes/sheep.tscn")
]
@export var max_animals: int = 5

# --- Internal State ---
var _game_clock: Node = null
var _spawned_zombies: Array[Node2D] = []
var _spawned_animals: Array[Node2D] = []


func _ready() -> void:
	add_to_group("spawn_manager")
	call_deferred("_connect_game_clock")


func _connect_game_clock() -> void:
	var clock_nodes := get_tree().get_nodes_in_group("game_clock")
	for c in clock_nodes:
		if is_instance_valid(c):
			_game_clock = c
			break
	
	if _game_clock:
		_game_clock.night_started.connect(_on_night_started)
		_game_clock.night_ended.connect(_on_night_ended)
		
		# Initial spawn based on current period
		if _game_clock.is_night():
			spawn_zombies()
		else:
			spawn_animals()
	else:
		# Fallback initial animal spawn
		spawn_animals()


# ==============================================================================
# SPAWN POINT DISCOVERY
# ==============================================================================

## Returns all Marker2D / Node2D spawn points under ZombieSpawnPoints
func get_zombie_spawn_points() -> Array[Node2D]:
	var points: Array[Node2D] = []
	var container := get_node_or_null("ZombieSpawnPoints")
	if container:
		for child in container.get_children():
			if child is Node2D:
				points.append(child)
	return points


## Returns all Marker2D / Node2D spawn points under AnimalSpawnPoints
func get_animal_spawn_points() -> Array[Node2D]:
	var points: Array[Node2D] = []
	var container := get_node_or_null("AnimalSpawnPoints")
	if container:
		for child in container.get_children():
			if child is Node2D:
				points.append(child)
	return points


# ==============================================================================
# ZOMBIE SPAWNING
# ==============================================================================

## Spawns zombies at available ZombieSpawnPoints up to max_zombies.
## Guarantees no two zombies spawn at the exact same point during this cycle.
func spawn_zombies() -> Array[Node2D]:
	if not zombie_scene:
		return []
	
	_clean_tracked_zombies()
	var available_points := get_zombie_spawn_points()
	if available_points.is_empty():
		return []
	
	# Filter points by distance from player to avoid unfair sudden pop-ins
	var player := _get_player()
	var filtered_points: Array[Node2D] = []
	for pt in available_points:
		if not is_instance_valid(pt):
			continue
		if player and is_instance_valid(player):
			if pt.global_position.distance_to(player.global_position) < min_player_distance_for_zombies:
				continue
		filtered_points.append(pt)
	
	# If all points are too close, fallback to all points
	if filtered_points.is_empty():
		filtered_points = available_points.duplicate()
	
	# Randomly shuffle so selections are unpredictable
	filtered_points.shuffle()
	
	# Determine how many zombies to spawn (respecting max_zombies)
	var slots_available := maxi(0, max_zombies - _spawned_zombies.size())
	var spawn_count := mini(slots_available, filtered_points.size())
	
	var newly_spawned: Array[Node2D] = []
	var target_parent := _get_entity_parent()
	
	for i in range(spawn_count):
		var spawn_pt: Node2D = filtered_points[i]
		var zombie = zombie_scene.instantiate()
		target_parent.add_child(zombie)
		zombie.global_position = spawn_pt.global_position
		_spawned_zombies.append(zombie)
		newly_spawned.append(zombie)
	
	return newly_spawned


## Cleans up active spawned zombies
func clear_zombies() -> void:
	_clean_tracked_zombies()
	for z in _spawned_zombies:
		if is_instance_valid(z):
			z.queue_free()
	_spawned_zombies.clear()


# ==============================================================================
# ANIMAL SPAWNING
# ==============================================================================

## Spawns animals at available AnimalSpawnPoints up to max_animals.
## Guarantees no two animals spawn at the exact same point during this cycle.
func spawn_animals() -> Array[Node2D]:
	_clean_tracked_animals()
	var available_points := get_animal_spawn_points()
	if available_points.is_empty():
		return []
	
	available_points.shuffle()
	
	var slots_available := maxi(0, max_animals - _spawned_animals.size())
	var spawn_count := mini(slots_available, available_points.size())
	
	var newly_spawned: Array[Node2D] = []
	var target_parent := _get_entity_parent()
	
	for i in range(spawn_count):
		var spawn_pt: Node2D = available_points[i]
		
		# Pick animal scene (from list if available, else animal_scene)
		var chosen_scene: PackedScene = animal_scene
		if not animal_scenes.is_empty():
			chosen_scene = animal_scenes[randi() % animal_scenes.size()]
		
		if not chosen_scene:
			continue
		
		var animal = chosen_scene.instantiate()
		target_parent.add_child(animal)
		animal.global_position = spawn_pt.global_position
		_spawned_animals.append(animal)
		newly_spawned.append(animal)
	
	return newly_spawned


## Clears active spawned animals
func clear_animals() -> void:
	_clean_tracked_animals()
	for a in _spawned_animals:
		if is_instance_valid(a):
			a.queue_free()
	_spawned_animals.clear()


# ==============================================================================
# DAY / NIGHT SIGNALS
# ==============================================================================

func _on_night_started() -> void:
	# Night arrives: spawn zombies
	spawn_zombies()


func _on_night_ended() -> void:
	# Morning arrives: clear zombies and spawn daytime animals
	clear_zombies()
	spawn_animals()


# ==============================================================================
# HELPERS
# ==============================================================================

func _clean_tracked_zombies() -> void:
	var valid: Array[Node2D] = []
	for z in _spawned_zombies:
		if is_instance_valid(z) and not z.get("is_dead"):
			valid.append(z)
	_spawned_zombies = valid


func _clean_tracked_animals() -> void:
	var valid: Array[Node2D] = []
	for a in _spawned_animals:
		if is_instance_valid(a):
			valid.append(a)
	_spawned_animals = valid


func _get_entity_parent() -> Node:
	var parent := get_parent()
	if parent:
		return parent
	return get_tree().current_scene if get_tree() else self


func _get_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p is CharacterBody2D:
			return p
	return null
