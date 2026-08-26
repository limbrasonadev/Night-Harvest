extends CharacterBody2D

enum State {
	IDLE,
	WALKING,
	ACTING
}

const ItemDataClass = preload("res://scripts/item_data.gd")
const WorldItemClass = preload("res://scripts/world_item.gd")
const WorldItemScene = preload("res://Scenes/world_item.tscn")
const SwooshEffectClass = preload("res://scripts/swoosh_effect.gd")

@export var walk_speed: float = 135.0
@export var sprint_speed: float = 195.0
@export var speed: float = 135.0
@export var pickup_radius: float = 24.0
@export var interaction_distance: float = 32.0

@export_group("Camera Settings")
@export var camera_zoom: Vector2 = Vector2(3.0, 3.0)
@export var camera_smoothing_enabled: bool = true
@export var camera_smoothing_speed: float = 10.0
@export var camera_limit_left: int = -500
@export var camera_limit_top: int = -500
@export var camera_limit_right: int = 800
@export var camera_limit_bottom: int = 800

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var held_item_anchor: Marker2D = $HeldItemAnchor
@onready var held_item_sprite: Sprite2D = $HeldItemAnchor/HeldItemSprite
@onready var tool_hitbox: Area2D = get_node_or_null("ToolHitbox")
@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var swoosh_effect: SwooshEffect = get_node_or_null("SwooshEffect")

var current_state: State = State.IDLE
var last_direction: Vector2 = Vector2.DOWN
var is_acting: bool = false
var current_held_item: Resource = null
var current_action_type: int = 0
var impact_executed: bool = false
var _current_action_timestamp: int = 0

# Camera Middle-Mouse Drag Panning
var is_panning_camera: bool = false
var pan_drag_start_mouse_pos: Vector2 = Vector2.ZERO
var pan_drag_start_camera_offset: Vector2 = Vector2.ZERO

# Cooldown & Continuous Hold Tracking
var _last_action_end_time: int = 0
var _current_item_cooldown: float = 0.2
var _hit_targets_this_swing: Array = []

# Natural directional hand offsets (aligned with character spritesheet)
const HELD_OFFSETS := {
	"down": { "pos": Vector2(6, 4), "z": 1, "flip": false, "rot": -20.0 },
	"up": { "pos": Vector2(-5, -2), "z": -1, "flip": false, "rot": -20.0 },
	"left": { "pos": Vector2(-7, 3), "z": 1, "flip": true, "rot": 15.0 },
	"right": { "pos": Vector2(7, 3), "z": 1, "flip": false, "rot": -15.0 }
}


func _ready() -> void:
	add_to_group("player")
	
	if not swoosh_effect:
		swoosh_effect = get_node_or_null("SwooshEffect")
	if not swoosh_effect:
		swoosh_effect = SwooshEffectClass.new()
		add_child(swoosh_effect)
	
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
		animated_sprite.frame_changed.connect(_on_sprite_frame_changed)
		play_idle_animation()
	
	_setup_camera()
	call_deferred("_connect_hotbar")


func _connect_hotbar() -> void:
	var hotbar = get_hotbar()
	if hotbar:
		if not hotbar.slot_selected.is_connected(_on_hotbar_slot_selected):
			hotbar.slot_selected.connect(_on_hotbar_slot_selected)
		var item: Resource = hotbar.call("get_selected_item")
		_on_hotbar_slot_selected(hotbar.selected_slot, item)


func _setup_camera() -> void:
	if not camera:
		camera = get_node_or_null("Camera2D")
	if camera:
		camera.zoom = camera_zoom
		camera.position_smoothing_enabled = camera_smoothing_enabled
		camera.position_smoothing_speed = camera_smoothing_speed
		camera.limit_left = camera_limit_left
		camera.limit_top = camera_limit_top
		camera.limit_right = camera_limit_right
		camera.limit_bottom = camera_limit_bottom


func _process(delta: float) -> void:
	if is_acting and animated_sprite:
		_sync_held_item_animation_frame(animated_sprite.frame)
	
	# Smoothly return camera offset to center when not actively dragging
	if camera and not is_panning_camera and camera.offset != Vector2.ZERO:
		camera.offset = camera.offset.lerp(Vector2.ZERO, delta * 12.0)
		if camera.offset.length_squared() < 0.1:
			camera.offset = Vector2.ZERO


func _physics_process(_delta: float) -> void:
	# Failsafe: if held item is null but hotbar has an item, sync it
	if current_held_item == null:
		var hotbar = get_hotbar()
		if hotbar:
			var item = hotbar.call("get_selected_item")
			if item:
				_on_hotbar_slot_selected(hotbar.selected_slot, item)

	if is_ui_blocking():
		velocity = Vector2.ZERO
		if not is_acting:
			play_idle_animation()
		move_and_slide()
		return

	if is_acting:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	var is_running := Input.is_key_pressed(KEY_SHIFT) or Input.is_action_pressed("run")
	var active_speed := sprint_speed if is_running else walk_speed
	velocity = direction * active_speed

	if direction != Vector2.ZERO:
		last_direction = get_facing_direction(direction)
		current_state = State.WALKING
		_update_held_item_position()
		_update_tool_hitbox_position()
		play_walk_animation()
	else:
		current_state = State.IDLE
		play_idle_animation()

	check_action_inputs()
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	# Middle-mouse camera drag panning (processed unless UI is blocking)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed and not is_ui_blocking():
				is_panning_camera = true
				pan_drag_start_mouse_pos = event.position
				pan_drag_start_camera_offset = camera.offset if camera else Vector2.ZERO
			else:
				is_panning_camera = false
			return
	elif event is InputEventMouseMotion and is_panning_camera:
		if camera and not is_ui_blocking():
			var delta_screen: Vector2 = event.position - pan_drag_start_mouse_pos
			camera.offset = pan_drag_start_camera_offset - (delta_screen / camera.zoom)
			return

	if is_acting or is_ui_blocking():
		return

	if event.is_action_pressed("swing") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		trigger_primary_action()
	elif event.is_action_pressed("watering") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_CTRL or event.keycode == KEY_META)):
		trigger_watering()
	elif event.is_action_pressed("harvest") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		trigger_primary_action()
	elif event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_G or event.keycode == KEY_E)):
		trigger_interact()
	elif event.is_action_pressed("drop_item") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q):
		trigger_drop_item()


func check_action_inputs() -> bool:
	if is_acting or is_ui_blocking():
		return false

	# 1. Direct one-shot inputs
	if Input.is_action_just_pressed("swing") or Input.is_action_just_pressed("harvest"):
		trigger_primary_action()
		return true
	elif Input.is_action_just_pressed("watering"):
		trigger_watering()
		return true
	elif Input.is_action_just_pressed("interact"):
		trigger_interact()
		return true
	elif Input.is_action_just_pressed("drop_item"):
		trigger_drop_item()
		return true

	# 2. Continuous Hold-to-Swing check
	if _is_action_key_held() and _is_cooldown_ready():
		trigger_primary_action()
		return true

	return false


func _is_action_key_held() -> bool:
	return (
		Input.is_action_pressed("swing")
		or Input.is_action_pressed("harvest")
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_key_pressed(KEY_SPACE)
	)


func _is_cooldown_ready() -> bool:
	if _last_action_end_time == 0:
		return true
	var elapsed_sec := (Time.get_ticks_msec() - _last_action_end_time) / 1000.0
	return elapsed_sec >= _current_item_cooldown


# ==============================================================================
# ACTION FRAMEWORK & STATE LOCKING
# ==============================================================================

func trigger_primary_action() -> void:
	if is_acting or is_ui_blocking():
		return
	
	# If no item is equipped in active slot, do not swing weapon
	if not current_held_item:
		return
	
	var action_type: int = ItemDataClass.ActionType.NONE
	if current_held_item.get("action_type") != null:
		action_type = current_held_item.get("action_type")
	
	match action_type:
		ItemDataClass.ActionType.CHOP:
			trigger_chop()
		ItemDataClass.ActionType.ATTACK:
			trigger_attack()
		ItemDataClass.ActionType.MINE:
			trigger_chop()
		ItemDataClass.ActionType.WATER:
			trigger_watering()
		ItemDataClass.ActionType.HARVEST:
			trigger_harvest()
		_:
			trigger_swing()


func trigger_swing() -> void:
	_start_directional_swing(ItemDataClass.ActionType.NONE)


func trigger_chop() -> void:
	_start_directional_swing(ItemDataClass.ActionType.CHOP)


func trigger_attack() -> void:
	_start_directional_swing(ItemDataClass.ActionType.ATTACK)


func _start_directional_swing(action_type: int) -> void:
	var anim_name := "swing"
	if last_direction == Vector2.UP:
		anim_name = "swing_back"
	
	_start_action(action_type, anim_name)


func trigger_watering() -> void:
	var anim_name := "watering_front"
	if last_direction == Vector2.DOWN:
		anim_name = "watering_front"
	elif last_direction == Vector2.UP:
		anim_name = "watering_back"
	elif last_direction == Vector2.LEFT:
		anim_name = "watering_left"
	elif last_direction == Vector2.RIGHT:
		anim_name = "watering_right"
	_start_action(ItemDataClass.ActionType.WATER, anim_name)


func trigger_harvest() -> void:
	var anim_name := "harvest_front"
	if last_direction == Vector2.DOWN:
		anim_name = "harvest_front"
	elif last_direction == Vector2.UP:
		anim_name = "harvest_back"
	elif last_direction == Vector2.LEFT:
		anim_name = "harvest_left"
	elif last_direction == Vector2.RIGHT:
		anim_name = "harvest_right"
	_start_action(ItemDataClass.ActionType.HARVEST, anim_name)


func _start_action(action_type: int, animation_name: String) -> void:
	is_acting = true
	current_state = State.ACTING
	current_action_type = action_type
	impact_executed = false
	velocity = Vector2.ZERO
	_hit_targets_this_swing.clear()
	
	# Fetch item speed scaling and cooldown
	var speed_mult := 1.0
	if current_held_item and current_held_item.get("swing_speed_scale") != null:
		speed_mult = max(0.5, current_held_item.get("swing_speed_scale"))
	
	_current_item_cooldown = 0.2
	if current_held_item and current_held_item.get("swing_cooldown") != null:
		_current_item_cooldown = max(0.05, current_held_item.get("swing_cooldown"))
	
	# Direction-specific sprite orientation
	if animation_name == "swing":
		if last_direction == Vector2.LEFT:
			animated_sprite.flip_h = true
		else:
			animated_sprite.flip_h = false
	elif animation_name == "swing_back":
		animated_sprite.flip_h = false
	elif animation_name.begins_with("watering_") or animation_name.begins_with("harvest_"):
		if held_item_sprite:
			held_item_sprite.visible = false
	
	_update_tool_hitbox_position()
	
	if animated_sprite:
		animated_sprite.speed_scale = speed_mult
		animated_sprite.stop()
		animated_sprite.play(animation_name)
	
	_sync_held_item_animation_frame(0)
	
	# Failsafe action timeout (scaled with speed)
	var action_id := Time.get_ticks_msec()
	_current_action_timestamp = action_id
	var failsafe_duration := 0.55 / speed_mult
	get_tree().create_timer(failsafe_duration).timeout.connect(func():
		if is_acting and _current_action_timestamp == action_id:
			_on_animation_finished()
	)


func _on_sprite_frame_changed() -> void:
	if not animated_sprite:
		return
	
	var frame_idx: int = animated_sprite.frame
	_sync_held_item_animation_frame(frame_idx)
	
	# Impact frame trigger (Frame 3 on swings)
	if is_acting and not impact_executed:
		if (animated_sprite.animation == "swing" or animated_sprite.animation == "swing_back") and frame_idx >= 3:
			impact_executed = true
			_execute_action_impact()


func _sync_held_item_animation_frame(frame_idx: int) -> void:
	if not held_item_sprite or not held_item_sprite.visible:
		return
	
	var dir_key := _get_direction_key()
	var base_cfg: Dictionary = HELD_OFFSETS[dir_key]
	var base_pos: Vector2 = base_cfg["pos"]
	var base_rot: float = base_cfg["rot"]
	
	if is_acting:
		if animated_sprite.animation == "swing":
			match dir_key:
				"right":
					match frame_idx:
						0:
							held_item_anchor.position = Vector2(-2, -3)
							held_item_sprite.rotation_degrees = -75.0
						1:
							held_item_anchor.position = Vector2(0, -6)
							held_item_sprite.rotation_degrees = -95.0
						2:
							held_item_anchor.position = Vector2(6, -2)
							held_item_sprite.rotation_degrees = -10.0
						3:
							held_item_anchor.position = Vector2(12, 3)
							held_item_sprite.rotation_degrees = 45.0
						4:
							held_item_anchor.position = Vector2(10, 6)
							held_item_sprite.rotation_degrees = 70.0
						_:
							held_item_anchor.position = base_pos
							held_item_sprite.rotation_degrees = base_rot
				"left":
					match frame_idx:
						0:
							held_item_anchor.position = Vector2(2, -3)
							held_item_sprite.rotation_degrees = 75.0
						1:
							held_item_anchor.position = Vector2(0, -6)
							held_item_sprite.rotation_degrees = 95.0
						2:
							held_item_anchor.position = Vector2(-6, -2)
							held_item_sprite.rotation_degrees = 10.0
						3:
							held_item_anchor.position = Vector2(-12, 3)
							held_item_sprite.rotation_degrees = -45.0
						4:
							held_item_anchor.position = Vector2(-10, 6)
							held_item_sprite.rotation_degrees = -70.0
						_:
							held_item_anchor.position = base_pos
							held_item_sprite.rotation_degrees = base_rot
				"down", _:
					match frame_idx:
						0:
							held_item_anchor.position = Vector2(4, -3)
							held_item_sprite.rotation_degrees = -60.0
						1:
							held_item_anchor.position = Vector2(5, -6)
							held_item_sprite.rotation_degrees = -90.0
						2:
							held_item_anchor.position = Vector2(8, -1)
							held_item_sprite.rotation_degrees = -15.0
						3:
							held_item_anchor.position = Vector2(6, 7)
							held_item_sprite.rotation_degrees = 55.0
						4:
							held_item_anchor.position = Vector2(3, 8)
							held_item_sprite.rotation_degrees = 75.0
						_:
							held_item_anchor.position = base_pos
							held_item_sprite.rotation_degrees = base_rot
		elif animated_sprite.animation == "swing_back":
			match frame_idx:
				0:
					held_item_anchor.position = Vector2(6, 3)
					held_item_sprite.rotation_degrees = 20.0
				1:
					held_item_anchor.position = Vector2(6, -2)
					held_item_sprite.rotation_degrees = 50.0
				2:
					held_item_anchor.position = Vector2(3, -7)
					held_item_sprite.rotation_degrees = 15.0
				3:
					held_item_anchor.position = Vector2(-2, -9)
					held_item_sprite.rotation_degrees = -50.0
				4:
					held_item_anchor.position = Vector2(-5, -6)
					held_item_sprite.rotation_degrees = -80.0
				_:
					held_item_anchor.position = base_pos
					held_item_sprite.rotation_degrees = base_rot
	elif current_state == State.WALKING:
		var bob := -1.5 if (frame_idx % 2 == 1) else 0.0
		held_item_anchor.position = base_pos + Vector2(0, bob)
		held_item_sprite.rotation_degrees = base_rot
	else:
		held_item_anchor.position = base_pos
		held_item_sprite.rotation_degrees = base_rot


func _execute_action_impact() -> void:
	if not current_held_item:
		return
	
	var tool_power: int = current_held_item.get("tool_power") if current_held_item.get("tool_power") != null else 1
	var damage: int = current_held_item.get("weapon_damage") if current_held_item.get("weapon_damage") != null else 10
	var is_axe: bool = (current_held_item.get("action_type") == ItemDataClass.ActionType.CHOP or current_held_item.get("item_id") == "wood_axe")
	var knockback: float = current_held_item.get("knockback_force") if current_held_item.get("knockback_force") != null else 40.0
	var s_scale: Vector2 = current_held_item.get("swoosh_scale") if current_held_item.get("swoosh_scale") != null else Vector2.ONE
	var s_color: Color = current_held_item.get("swoosh_color") if current_held_item.get("swoosh_color") != null else Color.WHITE
	var s_duration: float = 0.14
	if current_held_item.get("swing_speed_scale") != null:
		s_duration /= max(0.5, current_held_item.get("swing_speed_scale"))
	
	# 1. Trigger Air-Swoosh Effect
	if swoosh_effect and (animated_sprite.animation == "swing" or animated_sprite.animation == "swing_back"):
		swoosh_effect.play_swoosh(last_direction, s_scale, s_color, s_duration)
	
	# 2. Check for choppable trees in reach
	var hit_tree: TreeEntity = get_target_tree_in_reach()
	if hit_tree and not _hit_targets_this_swing.has(hit_tree):
		_hit_targets_this_swing.append(hit_tree)
		hit_tree.take_hit(tool_power, last_direction, is_axe)
		return
	
	# 3. Check for combat enemies and interactable targets in tool hitbox
	if tool_hitbox:
		var bodies = tool_hitbox.get_overlapping_bodies()
		for body in bodies:
			if body != self and is_instance_valid(body) and not _hit_targets_this_swing.has(body):
				_hit_targets_this_swing.append(body)
				if body.has_method("take_damage"):
					body.take_damage(damage, last_direction, knockback)
					return
				elif body.has_method("take_hit"):
					body.take_hit(tool_power, last_direction)
					return
		
		var areas = tool_hitbox.get_overlapping_areas()
		for area in areas:
			if area != tool_hitbox and is_instance_valid(area) and not _hit_targets_this_swing.has(area):
				_hit_targets_this_swing.append(area)
				if area.has_method("take_damage"):
					area.take_damage(damage, last_direction, knockback)
					return
				elif area.has_method("take_hit"):
					area.take_hit(tool_power, last_direction)
					return


func get_target_tree_in_reach() -> TreeEntity:
	if not get_tree():
		return null
	
	var trees := get_tree().get_nodes_in_group("choppable_trees")
	var reach_point := global_position + (last_direction * 14.0)
	var closest_tree: TreeEntity = null
	var min_dist := 16.0
	
	for tree_node in trees:
		if tree_node is TreeEntity and is_instance_valid(tree_node) and not tree_node.is_dead:
			var tree_pos: Vector2 = tree_node.global_position
			var dist_to_reach := reach_point.distance_to(tree_pos)
			var dist_to_ken := global_position.distance_to(tree_pos)
			var to_tree := (tree_pos - global_position).normalized()
			var is_facing := to_tree.dot(last_direction) > 0.4
			
			if (dist_to_reach <= min_dist or dist_to_ken <= 18.0) and is_facing:
				if dist_to_reach < min_dist:
					min_dist = dist_to_reach
					closest_tree = tree_node
	
	return closest_tree


func _update_tool_hitbox_position() -> void:
	if not tool_hitbox:
		return
	
	var reach_dist := 10.0
	if current_held_item and current_held_item.get("swing_range") != null:
		reach_dist = current_held_item.get("swing_range") * 0.5
	
	tool_hitbox.position = last_direction * reach_dist


# ==============================================================================
# WORLD ITEM & CHEST INTERACTION
# ==============================================================================

func trigger_interact() -> void:
	if is_ui_blocking():
		return
	
	# 1. Check for nearby Chest
	var chest: ChestEntity = get_closest_chest()
	if chest and is_instance_valid(chest):
		chest.interact(self)
		return
	
	# 2. Check for ground world item
	var closest_item: Area2D = get_closest_world_item()
	if closest_item and is_instance_valid(closest_item):
		var inv: Control = get_inventory()
		if inv and inv.has_method("add_item"):
			var item_data: Resource = closest_item.get("item_data")
			var amount: int = closest_item.get("amount") if closest_item.get("amount") != null else 1
			var leftover: int = inv.add_item(item_data, amount)
			if leftover == 0:
				closest_item.queue_free()
			else:
				closest_item.set("amount", leftover)
			var item_name: String = item_data.get("display_name") if item_data and item_data.get("display_name") != null else "Item"
			print("Ken: Picked up ", item_name)
	else:
		print("Ken: No chest or item nearby")


func get_closest_chest() -> ChestEntity:
	if not get_tree():
		return null
	var chests := get_tree().get_nodes_in_group("chests")
	var closest: ChestEntity = null
	var min_dist := interaction_distance
	for node in chests:
		if node is ChestEntity and is_instance_valid(node):
			var dist := global_position.distance_to(node.global_position)
			if dist <= min_dist:
				min_dist = dist
				closest = node
	return closest


func trigger_drop_item() -> void:
	var hotbar: Control = get_hotbar()
	var inv: Control = get_inventory()
	if not hotbar or not inv:
		return
	
	var active_slot: int = hotbar.get("selected_slot") if hotbar.get("selected_slot") != null else 0
	var slot_data: Dictionary = hotbar.call("get_slot_data", active_slot) if hotbar.has_method("get_slot_data") else (inv.call("get_hotbar_item_at", active_slot) if inv.has_method("get_hotbar_item_at") else inv.call("get_item_at", active_slot))
	var item_to_drop: Resource = slot_data.get("item", null)
	
	if item_to_drop:
		var removed_item: Resource = null
		if inv.has_method("remove_hotbar_item_at"):
			removed_item = inv.call("remove_hotbar_item_at", active_slot, 1)
		else:
			removed_item = inv.call("remove_item_at", active_slot, 1)
		if removed_item:
			var world_item: Area2D = WorldItemScene.instantiate()
			var spawn_parent: Node = get_parent() if get_parent() else self
			spawn_parent.add_child(world_item)
			world_item.global_position = global_position + (last_direction * 18.0)
			world_item.call("set_item", removed_item, 1)
			var item_name: String = removed_item.get("display_name") if removed_item.get("display_name") != null else "Item"
			print("Ken: Dropped 1 ", item_name)
	else:
		print("Ken: Selected hotbar slot is empty, nothing to drop")


# ==============================================================================
# HELD ITEM RENDERING & DIRECTIONAL ORIENTATION
# ==============================================================================

func _on_hotbar_slot_selected(_slot_index: int, item_data: Resource) -> void:
	current_held_item = item_data
	_update_held_item_visuals()


func _update_held_item_visuals() -> void:
	if not held_item_sprite:
		return
	
	if current_held_item:
		var tex: Texture2D = current_held_item.get("held_texture")
		if not tex:
			tex = current_held_item.get("icon")
		held_item_sprite.texture = tex
		held_item_sprite.visible = (tex != null)
		_update_held_item_position()
	else:
		held_item_sprite.texture = null
		held_item_sprite.visible = false


func _update_held_item_position() -> void:
	if not held_item_anchor or not held_item_sprite:
		return
	
	var dir_key := _get_direction_key()
	var cfg: Dictionary = HELD_OFFSETS[dir_key]
	
	held_item_anchor.position = cfg["pos"]
	held_item_anchor.z_index = cfg["z"]
	held_item_sprite.flip_h = cfg["flip"]
	held_item_sprite.rotation_degrees = cfg["rot"]


func _get_direction_key() -> String:
	if last_direction == Vector2.UP:
		return "up"
	elif last_direction == Vector2.LEFT:
		return "left"
	elif last_direction == Vector2.RIGHT:
		return "right"
	return "down"


func get_facing_direction(direction: Vector2) -> Vector2:
	if abs(direction.x) > abs(direction.y):
		return Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
	else:
		return Vector2.DOWN if direction.y > 0 else Vector2.UP


# ==============================================================================
# ANIMATION CONTROLLER & UI BLOCKING
# ==============================================================================

func _on_animation_finished() -> void:
	if is_acting:
		is_acting = false
		current_state = State.IDLE
		impact_executed = false
		animated_sprite.flip_h = false
		animated_sprite.speed_scale = 1.0
		_last_action_end_time = Time.get_ticks_msec()
		
		# Restore held item visual in case it was hidden
		_update_held_item_visuals()
		
		if is_ui_blocking():
			play_idle_animation()
			return

		# Continuous hold-to-swing evaluation after cooldown
		if _is_action_key_held() and current_held_item != null:
			get_tree().create_timer(_current_item_cooldown).timeout.connect(func():
				if not is_acting and _is_action_key_held() and not is_ui_blocking():
					trigger_primary_action()
			)
			return

		var direction := Input.get_vector(
			"move_left",
			"move_right",
			"move_up",
			"move_down"
		)
		if direction != Vector2.ZERO:
			last_direction = get_facing_direction(direction)
			current_state = State.WALKING
			play_walk_animation()
		else:
			play_idle_animation()
		
		_update_held_item_position()


func play_walk_animation() -> void:
	animated_sprite.flip_h = false
	var animation_name := ""
	if last_direction == Vector2.DOWN:
		animation_name = "walk_front"
	elif last_direction == Vector2.UP:
		animation_name = "walk_back"
	elif last_direction == Vector2.LEFT:
		animation_name = "walk_left"
	elif last_direction == Vector2.RIGHT:
		animation_name = "walk_right"

	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)


func play_idle_animation() -> void:
	animated_sprite.flip_h = false
	var animation_name := ""
	if last_direction == Vector2.DOWN:
		animation_name = "idle_front"
	elif last_direction == Vector2.UP:
		animation_name = "idle_back"
	elif last_direction == Vector2.LEFT:
		animation_name = "idle_left"
	elif last_direction == Vector2.RIGHT:
		animation_name = "idle_right"

	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)


func get_inventory() -> Control:
	if not get_tree():
		return null
	var nodes := get_tree().get_nodes_in_group("inventory_ui")
	for node in nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			return node as Control
	
	if get_tree().root:
		var inv = get_tree().root.find_child("Inventory", true, false)
		if inv and is_instance_valid(inv):
			return inv as Control
	return null


func get_hotbar() -> Control:
	if not get_tree():
		return null
	var nodes := get_tree().get_nodes_in_group("hotbar_ui")
	for node in nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			return node as Control
	
	if get_tree().root:
		var hb = get_tree().root.find_child("Hotbar", true, false)
		if hb and is_instance_valid(hb):
			return hb as Control
	return null


func get_closest_world_item() -> Area2D:
	if not get_tree():
		return null
	
	var items := get_tree().get_nodes_in_group("world_items")
	var closest: Area2D = null
	var min_dist := pickup_radius
	
	for item in items:
		if item is Area2D and is_instance_valid(item) and not item.is_queued_for_deletion():
			var dist := global_position.distance_to(item.global_position)
			if dist <= min_dist:
				min_dist = dist
				closest = item
	
	return closest


func is_ui_blocking() -> bool:
	if not get_tree():
		return false
	var inv_nodes := get_tree().get_nodes_in_group("inventory_ui")
	for inv in inv_nodes:
		if is_instance_valid(inv) and inv.get("is_open"):
			return true
	
	var menu_nodes := get_tree().get_nodes_in_group("menu_ui")
	for menu in menu_nodes:
		if is_instance_valid(menu) and menu.get("is_open"):
			return true
	
	var container_nodes := get_tree().get_nodes_in_group("container_ui")
	for container in container_nodes:
		if is_instance_valid(container) and container.get("is_open"):
			return true
	
	var map_nodes := get_tree().get_nodes_in_group("map_ui")
	for m in map_nodes:
		if is_instance_valid(m) and m.get("is_open"):
			return true
	
	return false
