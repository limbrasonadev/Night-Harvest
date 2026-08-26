extends Control
class_name FullMapUI

signal map_opened
signal map_closed

@export var map_center: Vector2 = Vector2(80, 0)
@export var map_zoom: float = 0.52

var is_open: bool = false
var target: Node2D = null

@onready var modal_panel: PanelContainer = $CenterContainer/MapWindow
@onready var map_area: Control = $CenterContainer/MapWindow/MarginContainer/VBoxContainer/MapClip/MapArea
@onready var sub_viewport: SubViewport = $CenterContainer/MapWindow/MarginContainer/VBoxContainer/MapClip/MapArea/SubViewportContainer/SubViewport
@onready var map_camera: Camera2D = $CenterContainer/MapWindow/MarginContainer/VBoxContainer/MapClip/MapArea/SubViewportContainer/SubViewport/MapCamera
@onready var player_indicator: Control = $CenterContainer/MapWindow/MarginContainer/VBoxContainer/MapClip/MapArea/PlayerIndicator
@onready var player_arrow: Label = $CenterContainer/MapWindow/MarginContainer/VBoxContainer/MapClip/MapArea/PlayerIndicator/MarkerBox/ArrowLabel
@onready var poi_container: Control = $CenterContainer/MapWindow/MarginContainer/VBoxContainer/MapClip/MapArea/POIContainer
@onready var close_button: Button = $CenterContainer/MapWindow/MarginContainer/VBoxContainer/Header/CloseButton

# Landmark POIs in world coordinates
const LANDMARKS: Array[Dictionary] = [
	{ "name": "Player Cabin", "icon": "🏠", "pos": Vector2(-32, -197), "color": Color(0.3, 0.7, 1.0) },
	{ "name": "Storage Chest", "icon": "📦", "pos": Vector2(14, -180), "color": Color(1.0, 0.8, 0.2) },
	{ "name": "Farmland", "icon": "🌾", "pos": Vector2(60, -40), "color": Color(0.4, 0.9, 0.3) },
	{ "name": "Deep Forest", "icon": "🌲", "pos": Vector2(450, 100), "color": Color(0.2, 0.8, 0.5) },
	{ "name": "Pasture / Coop", "icon": "🐔", "pos": Vector2(90, -5), "color": Color(1.0, 0.6, 0.3) },
]

var _poi_nodes: Array[Control] = []


func _ready() -> void:
	add_to_group("full_map_ui")
	add_to_group("map_ui")
	visible = false
	modulate.a = 0.0
	
	if close_button:
		close_button.pressed.connect(close_map)
	
	call_deferred("_setup_world_viewport")
	call_deferred("_spawn_landmarks")
	_locate_player()


func _setup_world_viewport() -> void:
	if not sub_viewport:
		return
	
	var parent_viewport := get_viewport()
	if parent_viewport and parent_viewport.find_world_2d():
		sub_viewport.world_2d = parent_viewport.find_world_2d()
	
	if map_camera:
		map_camera.global_position = map_center
		map_camera.zoom = Vector2(map_zoom, map_zoom)


func _locate_player() -> void:
	if not target:
		var ken := get_tree().get_first_node_in_group("player")
		if ken and ken is Node2D:
			target = ken
		else:
			var root_node := get_tree().current_scene
			if root_node:
				var candidate := root_node.find_child("CharacterBody2D3", true, false)
				if candidate and candidate is Node2D:
					target = candidate


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_map"):
		toggle_map()
		get_viewport().set_input_as_handled()
	elif is_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_menu")):
		close_map()
		get_viewport().set_input_as_handled()


func toggle_map() -> void:
	if is_open:
		close_map()
	else:
		open_map()


func open_map() -> void:
	if is_open:
		return
	
	_locate_player()
	_setup_world_viewport()
	
	is_open = true
	visible = true
	
	# Smooth fade-in
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if modal_panel:
		modal_panel.scale = Vector2(0.96, 0.96)
		tween.tween_property(modal_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	_sync_elements()
	map_opened.emit()


func close_map() -> void:
	if not is_open:
		return
	
	is_open = false
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if modal_panel:
		tween.tween_property(modal_panel, "scale", Vector2(0.96, 0.96), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.chain().tween_callback(func():
		visible = false
		map_closed.emit()
	)


func _process(_delta: float) -> void:
	if not is_open:
		return
	
	if not is_instance_valid(target):
		_locate_player()
		return
	
	_sync_elements()


func _sync_elements() -> void:
	if not map_area or not map_camera:
		return
	
	# Update player indicator position & facing direction
	if player_indicator and is_instance_valid(target):
		var screen_pos := world_to_map_position(target.global_position)
		player_indicator.position = screen_pos
		
		var facing_dir: Vector2 = target.get("last_direction") if target.get("last_direction") != null else Vector2.DOWN
		if player_arrow:
			if facing_dir == Vector2.UP:
				player_arrow.text = "▲"
			elif facing_dir == Vector2.RIGHT:
				player_arrow.text = "►"
			elif facing_dir == Vector2.LEFT:
				player_arrow.text = "◄"
			else:
				player_arrow.text = "▼"
	
	# Update POI positions
	for i in range(LANDMARKS.size()):
		if i < _poi_nodes.size() and is_instance_valid(_poi_nodes[i]):
			_poi_nodes[i].position = world_to_map_position(LANDMARKS[i].pos)


func world_to_map_position(world_pos: Vector2) -> Vector2:
	if not map_area or not map_camera:
		return Vector2.ZERO
	
	var cam_pos: Vector2 = map_camera.global_position
	var cam_zoom: Vector2 = map_camera.zoom
	var half_size: Vector2 = map_area.size * 0.5
	var offset: Vector2 = (world_pos - cam_pos) * cam_zoom
	return half_size + offset


func _spawn_landmarks() -> void:
	if not poi_container:
		return
	
	for child in poi_container.get_children():
		child.queue_free()
	_poi_nodes.clear()
	
	for poi in LANDMARKS:
		var poi_panel := PanelContainer.new()
		poi_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.08, 0.06, 0.9)
		style.set_border_width_all(1)
		style.border_color = poi.color
		style.set_corner_radius_all(4)
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		poi_panel.add_theme_stylebox_override("panel", style)
		
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 3)
		
		var icon_lbl := Label.new()
		icon_lbl.text = poi.icon
		icon_lbl.add_theme_font_size_override("font_size", 10)
		hbox.add_child(icon_lbl)
		
		var name_lbl := Label.new()
		name_lbl.text = poi.name
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", poi.color)
		hbox.add_child(name_lbl)
		
		poi_panel.add_child(hbox)
		poi_container.add_child(poi_panel)
		_poi_nodes.append(poi_panel)
