extends Control
class_name MinimapUI

@export var target: Node2D
@export var zoom: float = 0.1

@onready var map_area: Control = $Frame/MapClip/MapArea
@onready var player_marker: Control = $Frame/MapClip/MapArea/PlayerMarker


func _ready() -> void:
	if not target:
		# Auto-locate Ken/player in scene if available
		var ken := get_tree().get_first_node_in_group("player")
		if ken and ken is Node2D:
			target = ken
		else:
			# Look for CharacterBody2D3 or any CharacterBody2D
			var root_node := get_tree().current_scene
			if root_node:
				var candidate := root_node.find_child("CharacterBody2D3", true, false)
				if candidate and candidate is Node2D:
					target = candidate


func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	
	_update_player_marker()


func set_target(new_target: Node2D) -> void:
	target = new_target
	_update_player_marker()


func _update_player_marker() -> void:
	if not player_marker or not map_area:
		return
	
	# In this foundation, map center is map_area center
	var center := map_area.size * 0.5
	if target:
		# The marker stays at center or represents player position
		# Map center anchor
		player_marker.position = center
