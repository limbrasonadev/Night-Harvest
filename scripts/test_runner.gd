extends Node

const ItemDataScript = preload("res://scripts/item_data.gd")
const ItemDatabaseScript = preload("res://scripts/item_database.gd")
const WorldItemScript = preload("res://scripts/world_item.gd")
const HotbarScript = preload("res://scripts/hotbar.gd")
const InventoryScript = preload("res://scripts/inventory.gd")
const MenuScript = preload("res://scripts/menu.gd")
const KenScript = preload("res://Scenes/ken_idle_front.gd")
const MinimapScript = preload("res://scripts/minimap.gd")
const FullMapScript = preload("res://scripts/full_map.gd")
const HUDScript = preload("res://scripts/hud.gd")
const TreeScript = preload("res://scripts/tree.gd")

func _ready() -> void:
	print("--- Running Night Harvest Milestone 1 Full Verification Suite ---")
	test_item_database()
	test_inventory_system()
	test_inventory_slot_swapping()
	test_inventory_to_hotbar_assignment()
	test_hotbar_reactive_to_inventory()
	test_minimap()
	test_full_map()
	test_hud()
	test_menu()
	test_ken()
	test_held_item_system_and_directions()
	test_directional_swings_and_flips()
	test_action_state_locking_and_timing()
	test_deterministic_drop_and_held_clear()
	test_camera_follow_settings()
	test_camera_panning()
	test_tree_cutting_and_wood_harvesting()
	test_pickup_drop_cycle()
	test_universal_item_swing_and_swoosh()
	test_hold_to_swing_repeat_and_release()
	test_rpg_chest_7_and_ui()
	test_game_scene()
	test_health_and_defense_system()
	test_game_clock_and_periods()
	test_event_bus_and_daily_quests()
	test_environment_lighting()
	test_zombie_spawner_and_marker2d()
	test_zombie_ai_and_combat()
	test_4_direction_movement_and_facing()
	test_spawn_manager_scene_and_spawning()
	print("--- ALL NIGHT HARVEST TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)


func test_item_database() -> void:
	print("1. Testing Item Database & Action Types...")
	var wood = ItemDatabaseScript.get_item("wood_log")
	assert(wood != null, "Wood Log item exists")
	assert(wood.display_name == "Wood Log", "Wood Log name is correct")
	assert(wood.icon != null, "Wood Log has icon")
	
	var axe = ItemDatabaseScript.get_item("wood_axe")
	assert(axe != null, "Wood Axe exists")
	assert(axe.action_type == ItemDataScript.ActionType.CHOP, "Wood axe has CHOP action type")
	assert(axe.tool_power >= 1, "Wood axe has tool power")
	
	var sword = ItemDatabaseScript.get_item("iron_sword")
	assert(sword != null, "Iron Sword exists")
	assert(sword.max_stack == 1, "Iron sword max stack is 1")
	assert(sword.action_type == ItemDataScript.ActionType.ATTACK, "Iron sword has ATTACK action type")
	assert(sword.weapon_damage == 15, "Iron sword damage is 15")
	print("Item Database tests: OK")


func test_inventory_system() -> void:
	print("2. Testing Inventory Stacking & Remainder Math...")
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	assert(inv_scene != null, "Inventory scene failed to load")
	var inv: InventoryUI = inv_scene.instantiate()
	add_child(inv)
	
	var wood = ItemDatabaseScript.get_item("wood_log")
	var stone = ItemDatabaseScript.get_item("stone_rock")
	
	# Add 10 wood
	var leftover = inv.add_item(wood, 10)
	assert(leftover == 0, "All 10 wood added")
	assert(inv.get_item_at(0)["amount"] == 10, "Slot 0 has 10 wood")
	
	# Add 5 more wood (should stack into slot 0)
	inv.add_item(wood, 5)
	assert(inv.get_item_at(0)["amount"] == 15, "Slot 0 has 15 wood")
	
	# Add stone (should go to slot 1)
	inv.add_item(stone, 3)
	assert(inv.get_item_at(1)["item"].item_id == "stone_rock", "Slot 1 has stone")
	assert(inv.get_item_at(1)["amount"] == 3, "Slot 1 has 3 stone")
	
	# Test direct setters
	inv.set_item_at(5, stone, 2)
	assert(inv.get_item_at(5)["item"].item_id == "stone_rock", "Direct slot 5 set to stone")
	assert(inv.get_item_at(5)["amount"] == 2, "Direct slot 5 amount is 2")
	
	inv.set_hotbar_item_at(2, wood, 7)
	assert(inv.get_hotbar_item_at(2)["item"].item_id == "wood_log", "Hotbar slot 2 set to wood")
	assert(inv.get_hotbar_item_at(2)["amount"] == 7, "Hotbar slot 2 amount is 7")
	
	inv.queue_free()
	print("Inventory tests: OK")


func test_inventory_slot_swapping() -> void:
	print("3. Testing Interactive Inventory Slot Swapping...")
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	var inv: InventoryUI = inv_scene.instantiate()
	add_child(inv)
	
	var sword = ItemDatabaseScript.get_item("iron_sword")
	var axe = ItemDatabaseScript.get_item("wood_axe")
	
	inv.add_item(sword, 1) # Slot 0
	inv.add_item(axe, 1)   # Slot 1
	
	assert(inv.get_item_at(0)["item"].item_id == "iron_sword", "Slot 0 has sword")
	assert(inv.get_item_at(1)["item"].item_id == "wood_axe", "Slot 1 has axe")
	
	# Swap slot 0 and slot 1
	inv.swap_slots(0, 1)
	assert(inv.get_item_at(0)["item"].item_id == "wood_axe", "Slot 0 now has axe after swap")
	assert(inv.get_item_at(1)["item"].item_id == "iron_sword", "Slot 1 now has sword after swap")
	
	# Move to a non-hotbar slot (e.g. Slot 5)
	inv.swap_slots(0, 5)
	assert(inv.get_item_at(0)["item"] == null, "Slot 0 is now empty")
	assert(inv.get_item_at(5)["item"].item_id == "wood_axe", "Slot 5 now has axe")
	
	inv.queue_free()
	print("Slot Swapping tests: OK")


func test_inventory_to_hotbar_assignment() -> void:
	print("4. Testing Inventory to Hotbar Assignment & Space Saving...")
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	var inv: InventoryUI = inv_scene.instantiate()
	add_child(inv)
	
	var seed = ItemDatabaseScript.get_item("wheat_seed")
	# Place seed in backpack slot 7
	inv.slots[7] = { "item": seed, "amount": 5 }
	
	# Move from backpack slot 7 to hotbar slot 0
	inv.move_to_hotbar(7, 0)
	assert(inv.get_hotbar_item_at(0)["item"].item_id == "wheat_seed", "Hotbar slot 0 now has wheat seed")
	assert(inv.get_hotbar_item_at(0)["amount"] == 5, "Hotbar slot 0 has 5 wheat seed")
	assert(inv.get_item_at(7)["item"] == null, "Backpack slot 7 is now empty, saving space for other items")
	
	inv.queue_free()
	print("Hotbar Assignment & Space Saving tests: OK")


func test_hotbar_reactive_to_inventory() -> void:
	print("5. Testing Hotbar Reactive Integration...")
	var root = Node2D.new()
	add_child(root)
	
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	var inv: InventoryUI = inv_scene.instantiate()
	root.add_child(inv)
	
	var hotbar_scene = load("res://Scenes/UI/hotbar.tscn")
	var hotbar: HotbarUI = hotbar_scene.instantiate()
	root.add_child(hotbar)
	
	var axe = ItemDatabaseScript.get_item("wood_axe")
	var sword = ItemDatabaseScript.get_item("iron_sword")
	
	inv.add_item(axe, 1)   # Goes to hotbar slot 0
	inv.add_item(sword, 1) # Goes to hotbar slot 1
	
	# Hotbar slot 0 should instantly reflect axe
	hotbar.select_slot(0)
	assert(hotbar.get_selected_item() == axe, "Hotbar slot 0 is wood axe")
	
	# Hotbar slot 1 should instantly reflect sword
	hotbar.select_slot(1)
	assert(hotbar.get_selected_item() == sword, "Hotbar slot 1 is iron sword")
	
	# Swap in hotbar: slot 0 and slot 1
	inv.swap_hotbar_slots(0, 1)
	# Hotbar slot 1 should now instantly be axe
	assert(hotbar.get_selected_item() == axe, "Hotbar slot 1 is now axe after swap")
	
	root.queue_free()
	print("Hotbar Reactive Integration tests: OK")


func test_minimap() -> void:
	print("6. Testing Minimap Foundation...")
	var minimap_scene = load("res://Scenes/UI/minimap.tscn")
	var minimap = minimap_scene.instantiate()
	add_child(minimap)
	
	var dummy = Node2D.new()
	add_child(dummy)
	dummy.position = Vector2(100, 200)
	minimap.set_target(dummy)
	assert(minimap.target == dummy, "Minimap target is dummy")
	
	minimap.queue_free()
	dummy.queue_free()
	print("Minimap tests: OK")


func test_full_map() -> void:
	print("6b. Testing Full Map System & POIs...")
	var full_map_scene = load("res://Scenes/UI/full_map.tscn")
	var full_map: FullMapUI = full_map_scene.instantiate()
	add_child(full_map)
	
	var dummy = Node2D.new()
	add_child(dummy)
	dummy.position = Vector2(50, -50)
	dummy.set("last_direction", Vector2.UP)
	full_map.target = dummy
	
	# 1. Test Open / Close
	assert(full_map.is_open == false, "Full Map initially closed")
	full_map.open_map()
	assert(full_map.is_open == true, "Full Map opens")
	assert(full_map.visible == true, "Full Map becomes visible")
	
	# 2. Test World to Map coordinate conversion
	var map_pos := full_map.world_to_map_position(dummy.position)
	assert(map_pos != Vector2.ZERO, "World position converted to map position")
	
	# 3. Test Close
	full_map.close_map()
	assert(full_map.is_open == false, "Full Map closes")
	
	full_map.queue_free()
	dummy.queue_free()
	print("Full Map tests: OK")


func test_hud() -> void:
	print("7. Testing HUD Presentation...")
	var hud_scene = load("res://Scenes/UI/hud.tscn")
	var hud = hud_scene.instantiate()
	add_child(hud)
	assert(hud.get_node_or_null("TopLeft/PlayerStatus") != null, "PlayerStatus exists")
	assert(hud.get_node_or_null("BottomCenter/Hotbar") != null, "Hotbar exists")
	hud.queue_free()
	print("HUD tests: OK")


func test_menu() -> void:
	print("8. Testing Pause Menu...")
	var menu_scene = load("res://Scenes/UI/menu.tscn")
	var menu = menu_scene.instantiate()
	add_child(menu)
	assert(menu.is_open == false, "Menu initially closed")
	menu.open()
	assert(menu.is_open == true, "Menu open")
	assert(get_tree().paused == true, "Paused when menu open")
	menu.close()
	assert(menu.is_open == false, "Menu closed")
	assert(get_tree().paused == false, "Unpaused when menu closed")
	menu.queue_free()
	print("Menu tests: OK")


func test_ken() -> void:
	print("9. Testing Ken Animations...")
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	add_child(ken)
	var sprite = ken.get_node("AnimatedSprite2D")
	assert(sprite != null, "Ken has AnimatedSprite2D")
	
	var frames = sprite.sprite_frames
	assert(frames.get_frame_count("swing") == 6, "Swing animation should have 6 frames")
	
	ken.queue_free()
	print("Ken tests: OK")


func test_held_item_system_and_directions() -> void:
	print("10. Testing Data-Driven Held Item & Directional Offsets...")
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	add_child(ken)
	
	var axe = ItemDatabaseScript.get_item("wood_axe")
	ken._on_hotbar_slot_selected(0, axe)
	assert(ken.current_held_item == axe, "Ken held item set to axe")
	assert(ken.held_item_sprite.visible == true, "Held item sprite visible")
	
	# Direction DOWN (Front)
	ken.last_direction = Vector2.DOWN
	ken._update_held_item_position()
	assert(ken.held_item_anchor.position == Vector2(6, 4), "Front position offset correct")
	assert(ken.held_item_anchor.z_index == 1, "Front z_index is 1")
	assert(ken.held_item_sprite.flip_h == false, "Front flip_h is false")
	
	# Direction UP (Back)
	ken.last_direction = Vector2.UP
	ken._update_held_item_position()
	assert(ken.held_item_anchor.position == Vector2(-5, -2), "Back position offset correct")
	assert(ken.held_item_anchor.z_index == -1, "Back z_index is -1 (behind character)")
	
	# Direction LEFT
	ken.last_direction = Vector2.LEFT
	ken._update_held_item_position()
	assert(ken.held_item_anchor.position == Vector2(-7, 3), "Left position offset correct")
	assert(ken.held_item_sprite.flip_h == true, "Left flip_h is true")
	
	# Direction RIGHT
	ken.last_direction = Vector2.RIGHT
	ken._update_held_item_position()
	assert(ken.held_item_anchor.position == Vector2(7, 3), "Right position offset correct")
	assert(ken.held_item_sprite.flip_h == false, "Right flip_h is false")
	
	ken.queue_free()
	print("Held Item & Directional offsets tests: OK")


func test_directional_swings_and_flips() -> void:
	print("11. Testing Directional Swings and Sprite Flipping...")
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	add_child(ken)
	
	var sword = ItemDatabaseScript.get_item("iron_sword")
	ken._on_hotbar_slot_selected(0, sword)
	
	# Swing facing LEFT
	ken.last_direction = Vector2.LEFT
	ken.trigger_primary_action()
	assert(ken.animated_sprite.flip_h == true, "Sprite flipped horizontally when swinging left")
	ken._on_animation_finished()
	assert(ken.animated_sprite.flip_h == false, "Flip reset after action finished")
	
	# Swing facing RIGHT
	ken.last_direction = Vector2.RIGHT
	ken.trigger_primary_action()
	assert(ken.animated_sprite.flip_h == false, "Sprite not flipped when swinging right")
	ken._on_animation_finished()
	
	ken.queue_free()
	print("Directional Swings tests: OK")


func test_action_state_locking_and_timing() -> void:
	print("12. Testing Action State Locking & Impact Timing...")
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	add_child(ken)
	
	var axe = ItemDatabaseScript.get_item("wood_axe")
	ken._on_hotbar_slot_selected(0, axe)
	
	ken.trigger_primary_action()
	assert(ken.is_acting == true, "Ken is acting")
	assert(ken.current_state == KenScript.State.ACTING, "State is ACTING")
	assert(ken.current_action_type == ItemDataScript.ActionType.CHOP, "Action type is CHOP")
	
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(ken.impact_executed == true, "Impact executed on frame 3")
	
	ken._on_animation_finished()
	assert(ken.is_acting == false, "Action lock cleared after animation finishes")
	
	ken.queue_free()
	print("Action state locking tests: OK")


func test_deterministic_drop_and_held_clear() -> void:
	print("13. Testing Deterministic Drop & Instant Held Item Clearing...")
	var world = Node2D.new()
	add_child(world)
	
	var canvas = CanvasLayer.new()
	world.add_child(canvas)
	
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	var inv: InventoryUI = inv_scene.instantiate()
	canvas.add_child(inv)
	
	var hotbar_scene = load("res://Scenes/UI/hotbar.tscn")
	var hotbar: HotbarUI = hotbar_scene.instantiate()
	canvas.add_child(hotbar)
	
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	world.add_child(ken)
	
	# Add exactly 1 seed to inventory slot 0
	var seed = ItemDatabaseScript.get_item("wheat_seed")
	inv.add_item(seed, 1)
	
	hotbar.select_slot(0)
	assert(ken.current_held_item == seed, "Ken is holding seed")
	assert(ken.held_item_sprite.visible == true, "Held sprite visible")
	
	# Drop the 1 seed
	ken.trigger_drop_item()
	
	# Slot 0 in hotbar is now empty (count 0)
	assert(inv.get_hotbar_item_at(0)["item"] == null, "Hotbar slot 0 is empty")
	# Hotbar slot 0 returns null
	assert(hotbar.get_selected_item() == null, "Hotbar selected item is null")
	# Ken held item must immediately be cleared and invisible
	assert(ken.current_held_item == null, "Ken held item cleared immediately")
	assert(ken.held_item_sprite.visible == false, "Ken held sprite is invisible")
	
	world.queue_free()
	print("Deterministic Drop & Held Clear tests: OK")


func test_camera_follow_settings() -> void:
	print("14. Testing Camera Follow Settings...")
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	add_child(ken)
	
	var cam: Camera2D = ken.get_node_or_null("Camera2D")
	assert(cam != null, "Ken has Camera2D child node")
	assert(cam.zoom == Vector2(3, 3), "Camera zoom is 3x3")
	assert(cam.position_smoothing_enabled == true, "Camera smoothing enabled")
	
	ken.queue_free()
	print("Camera follow settings tests: OK")


func test_camera_panning() -> void:
	print("14b. Testing Middle Mouse Camera Drag Panning...")
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	add_child(ken)
	
	var cam: Camera2D = ken.get_node_or_null("Camera2D")
	assert(cam != null, "Ken has Camera2D")
	
	# Simulate Middle Mouse Drag Start
	var press_event := InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_MIDDLE
	press_event.pressed = true
	press_event.position = Vector2(400, 300)
	ken._unhandled_input(press_event)
	assert(ken.is_panning_camera == true, "Camera panning active on middle press")
	
	# Simulate Motion
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = Vector2(460, 300)
	ken._unhandled_input(motion_event)
	assert(cam.offset.x < 0, "Camera offset translated on drag")
	
	# Simulate Release
	var release_event := InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_MIDDLE
	release_event.pressed = false
	ken._unhandled_input(release_event)
	assert(ken.is_panning_camera == false, "Camera panning stopped on release")
	
	ken.queue_free()
	print("Camera panning tests: OK")


func test_tree_cutting_and_wood_harvesting() -> void:
	print("15. Testing Tree Cutting & Wood Harvesting Pipeline...")
	var world_scene = Node2D.new()
	add_child(world_scene)
	
	var tree_scene = load("res://Scenes/tree.tscn")
	var tree: TreeEntity = tree_scene.instantiate()
	tree.position = Vector2(20, 0)
	world_scene.add_child(tree)
	
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	ken.position = Vector2(0, 0)
	ken.last_direction = Vector2.RIGHT
	world_scene.add_child(ken)
	
	# 1. Try hitting tree with Sword -> Must NOT damage tree
	var sword = ItemDatabaseScript.get_item("iron_sword")
	ken._on_hotbar_slot_selected(0, sword)
	ken.trigger_primary_action()
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(tree.current_health == 4, "Sword does NOT damage tree (must be axe only)")
	ken._on_animation_finished()
	
	# 2. Equip Wood Axe
	var axe = ItemDatabaseScript.get_item("wood_axe")
	ken._on_hotbar_slot_selected(0, axe)
	
	# Hit 1
	ken.trigger_primary_action()
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(tree.current_health == 3, "Tree health is 3 after Axe Hit 1")
	ken._on_animation_finished()
	
	# Hit 2
	ken.trigger_primary_action()
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(tree.current_health == 2, "Tree health is 2 after Axe Hit 2")
	ken._on_animation_finished()
	
	# Hit 3
	ken.trigger_primary_action()
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(tree.current_health == 1, "Tree health is 1 after Axe Hit 3")
	ken._on_animation_finished()
	
	# Hit 4 (Fell tree)
	ken.trigger_primary_action()
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(tree.current_health <= 0, "Tree health <= 0 after Axe Hit 4")
	assert(tree.is_dead == true, "Tree marked as dead after 4 hits")
	
	world_scene.queue_free()
	print("Tree Cutting tests: OK")



func test_pickup_drop_cycle() -> void:
	print("16. Testing Pickup / Drop Cycle...")
	var world_scene = Node2D.new()
	add_child(world_scene)
	
	var canvas = CanvasLayer.new()
	world_scene.add_child(canvas)
	
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	var inv = inv_scene.instantiate()
	canvas.add_child(inv)
	
	var hotbar_scene = load("res://Scenes/UI/hotbar.tscn")
	var hotbar = hotbar_scene.instantiate()
	canvas.add_child(hotbar)
	
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	world_scene.add_child(ken)
	
	var w_item_scene = load("res://Scenes/world_item.tscn")
	var w_item = w_item_scene.instantiate()
	w_item.position = Vector2(10, 0)
	world_scene.add_child(w_item)
	
	var mushroom = ItemDatabaseScript.get_item("wild_mushroom")
	w_item.set_item(mushroom, 3)
	
	ken.trigger_interact()
	var picked_slot = inv.get_hotbar_item_at(0) if inv.get_hotbar_item_at(0)["item"] != null else inv.get_item_at(0)
	assert(picked_slot["item"].item_id == "wild_mushroom", "Item is wild mushroom")
	assert(picked_slot["amount"] == 3, "Item amount is 3")
	
	world_scene.queue_free()
	print("Pickup cycle tests: OK")


func test_universal_item_swing_and_swoosh() -> void:
	print("17. Testing Universal Item Swing & Directional Air-Swoosh...")
	var world = Node2D.new()
	add_child(world)
	
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	world.add_child(ken)
	
	var sword = ItemDatabaseScript.get_item("iron_sword")
	assert(sword.swing_speed_scale > 1.0, "Sword has high swing speed scale")
	assert(sword.swoosh_scale.x >= 1.0, "Sword has configured swoosh scale")
	
	# Equip sword and swing RIGHT
	ken._on_hotbar_slot_selected(0, sword)
	ken.last_direction = Vector2.RIGHT
	ken.trigger_primary_action()
	assert(ken.is_acting == true, "Ken is acting with sword")
	
	# Frame 3 trigger (Impact & Swoosh)
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(ken.swoosh_effect != null, "Ken has swoosh effect")
	assert(ken.swoosh_effect.is_active == true, "Swoosh effect is active on impact frame")
	assert(ken.swoosh_effect.current_direction == Vector2.RIGHT, "Swoosh points RIGHT")
	
	ken._on_animation_finished()
	
	# Equip axe and swing UP
	var axe = ItemDatabaseScript.get_item("wood_axe")
	ken._on_hotbar_slot_selected(0, axe)
	ken.last_direction = Vector2.UP
	ken.trigger_primary_action()
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(ken.swoosh_effect.is_active == true, "Swoosh effect active on UP swing")
	assert(ken.swoosh_effect.current_direction == Vector2.UP, "Swoosh points UP")
	
	ken._on_animation_finished()
	world.queue_free()
	print("Universal item swing & swoosh tests: OK")


func test_hold_to_swing_repeat_and_release() -> void:
	print("18. Testing Hold-to-Swing Repeat Logic & Release Stop...")
	var world = Node2D.new()
	add_child(world)
	
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	world.add_child(ken)
	
	var sword = ItemDatabaseScript.get_item("iron_sword")
	ken._on_hotbar_slot_selected(0, sword)
	
	# 1. Cooldown calculation
	ken.trigger_primary_action()
	assert(ken.is_acting == true, "Ken starts swing")
	ken._on_animation_finished()
	assert(ken.is_acting == false, "Ken finishes swing")
	assert(ken._current_item_cooldown == sword.swing_cooldown, "Item cooldown correctly set")
	
	# 2. Empty-hand protection (No weapon equipped)
	ken._on_hotbar_slot_selected(0, null)
	ken.trigger_primary_action()
	assert(ken.is_acting == false, "Ken does not swing when hand is empty")
	
	world.queue_free()
	print("Hold-to-swing & empty-hand tests: OK")


func test_rpg_chest_7_and_ui() -> void:
	print("19. Testing RPG Chest #7 Slicing, Open/Close Animation & Transfers...")
	var world = Node2D.new()
	add_child(world)
	
	# 1. Texture Slicing Test
	var tex = ItemDatabaseScript.get_rpg_chest_texture(7, 0)
	assert(tex != null, "Chest 7 closed texture loaded")
	assert(tex.region.size.x > 0 and tex.region.size.y > 0, "Texture region is valid")
	
	# 2. Chest Entity Test
	var chest_scene = load("res://Scenes/Objects/chest.tscn")
	var chest: ChestEntity = chest_scene.instantiate()
	world.add_child(chest)
	
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	ken.position = Vector2(0, 0)
	world.add_child(ken)
	
	chest.position = Vector2(20, 0)
	assert(chest.can_interact(ken) == true, "Chest can interact within 32px")
	
	# 3. Storage & Stacking Test (24 Slots)
	assert(chest.storage_slots.size() == 24, "Chest has 24 storage slots")
	var wood = ItemDatabaseScript.get_item("wood_log")
	var leftover = chest.add_item(wood, 12)
	assert(leftover == 0, "Stored 12 wood logs in chest")
	assert(chest.get_item_at(0)["item"].item_id == "wood_log", "Chest slot 0 has wood")
	assert(chest.get_item_at(0)["amount"] == 12, "Chest slot 0 count is 12")
	
	# 4. Open/Close sequence
	chest.open_chest(ken)
	assert(chest.is_open == true, "Chest opens")
	chest.close_chest()
	assert(chest.is_open == false, "Chest closes")
	
	world.queue_free()
	print("RPG Chest #7 tests: OK")


func test_game_scene() -> void:
	print("20. Testing Game Scene Integration...")
	var game_scene = load("res://Scenes/game.tscn")
	var game = game_scene.instantiate()
	add_child(game)
	
	var ui = game.get_node_or_null("UI")
	assert(ui != null, "UI exists")
	assert(ui.get_node_or_null("HUD") != null, "HUD exists")
	assert(ui.get_node_or_null("Inventory") != null, "Inventory exists")
	assert(ui.get_node_or_null("ChestUI") != null, "ChestUI exists")
	assert(ui.get_node_or_null("FullMap") != null, "FullMap exists")
	
	var ken = game.get_node_or_null("CharacterBody2D3")
	assert(ken != null, "Ken exists")
	
	var chest = game.get_node_or_null("Chest")
	assert(chest != null, "Chest exists in game scene")
	
	game.queue_free()
	print("Game scene tests: OK")


func test_health_and_defense_system() -> void:
	print("21. Testing Priority 1: Health, Defense & Death System...")
	var stats_script = load("res://scripts/player_stats.gd")
	var stats = stats_script.new()
	add_child(stats)
	
	assert(stats.max_health == 100, "Max HP is 100")
	assert(stats.current_health == 100, "Initial HP is 100")
	assert(stats.current_defense == 0, "Initial defense is 0")
	
	# Zombie base damage is 3. At 0 defense, damage should be 3 (~33 hits to die)
	var dmg = stats.take_damage(3)
	assert(dmg == 3, "Zombie deals 3 damage at 0 defense")
	assert(stats.current_health == 97, "HP is 97 after hit")
	
	# Cooldown invulnerability: immediately taking damage again should deal 0
	var dmg2 = stats.take_damage(3)
	assert(dmg2 == 0, "Damage cooldown prevents consecutive frame damage")
	assert(stats.current_health == 97, "HP remains 97 during cooldown")
	
	# Test defense reduction: formula max(1, base - defense/20)
	stats._is_invulnerable = false
	stats.set_defense(20) # 20 / 20 = 1 reduction -> damage is 3 - 1 = 2
	var dmg_def = stats.take_damage(3)
	assert(dmg_def == 2, "Defense reduces damage by 1 (deals 2)")
	assert(stats.current_health == 95, "HP is 95")
	
	# Test minimum damage clamp (always >= 1)
	stats._is_invulnerable = false
	stats.set_defense(100)
	var dmg_min = stats.take_damage(1)
	assert(dmg_min == 1, "Defense never makes player completely immune (min 1)")
	
	# Test death
	stats._is_invulnerable = false
	var died := [false]
	stats.player_died.connect(func(): died[0] = true)
	stats.take_damage(1000)
	assert(stats.current_health == 0, "HP is 0 after fatal damage")
	assert(stats.is_dead == true, "Player is in dead state")
	assert(died[0] == true, "player_died signal fired")
	
	stats.queue_free()
	print("Health & Defense tests: OK")


func test_game_clock_and_periods() -> void:
	print("22. Testing Priority 2: Game Clock & Day/Night Progression...")
	var clock_script = load("res://scripts/game_clock.gd")
	var clock = clock_script.new()
	add_child(clock)
	
	assert(clock.start_hour == 6, "Clock starts at 6 AM")
	assert(clock.get_period_name() == "MORNING", "6 AM is Morning")
	assert(clock.get_time_string() == "06:00 AM", "Time string is 06:00 AM")
	assert(clock.is_night() == false, "Morning is not night")
	
	# Advance to 12 PM (Afternoon)
	clock.current_hour = 12
	clock.current_minute = 0
	clock.current_period = clock._calculate_period()
	assert(clock.get_period_name() == "AFTERNOON", "12 PM is Afternoon")
	assert(clock.get_time_string() == "12:00 PM", "Time string is 12:00 PM")
	
	# Advance to 5 PM (Sunset)
	clock.current_hour = 17
	clock.current_period = clock._calculate_period()
	assert(clock.get_period_name() == "SUNSET", "5 PM is Sunset")
	
	# Advance to 7 PM (Night)
	clock.current_hour = 19
	clock.current_period = clock._calculate_period()
	assert(clock.get_period_name() == "NIGHT", "7 PM is Night")
	assert(clock.is_night() == true, "7 PM is night")
	
	# Countdown test
	clock.current_hour = 15
	clock.current_minute = 30
	assert(clock.get_nightfall_countdown() == "03:30", "Countdown to 7 PM is 03:30 at 3:30 PM")
	
	# Day roll-over test
	clock.current_day = 1
	clock.current_hour = 23
	clock.current_minute = 59
	clock._advance_minute()
	assert(clock.current_day == 2, "Day advances to 2 at midnight")
	assert(clock.current_hour == 0 and clock.current_minute == 0, "Time resets to 00:00")
	
	clock.queue_free()
	print("Game Clock tests: OK")


func test_event_bus_and_daily_quests() -> void:
	print("23. Testing Priority 3: EventBus & Real-Time Quests...")
	var bus_script = load("res://scripts/event_bus.gd")
	var bus = bus_script.new()
	bus.name = "EventBus"
	add_child(bus)
	
	var qm_script = load("res://scripts/quest_manager.gd")
	var qm = qm_script.new()
	qm.name = "QuestManager"
	add_child(qm)
	qm._connect_event_bus()
	
	# Create a controlled test quest: Plant 3 Carrots
	var q_data_script = load("res://scripts/quest_data.gd")
	var quest = q_data_script.new("test_carrot", "Plant 3 Carrots", "carrot_planted", 3)
	quest.xp_reward = 50
	quest.gold_reward = 100
	qm.active_quests.clear()
	qm.active_quests.append(quest)
	
	assert(quest.current_count == 0, "Quest starts at 0/3")
	assert(quest.is_completed == false, "Quest not completed")
	
	# Emit carrot_planted event 1
	bus.carrot_planted.emit()
	assert(quest.current_count == 1, "Quest progress is 1/3")
	assert(quest.is_completed == false, "Quest not completed at 1/3")
	
	# Emit carrot_planted event 2
	bus.carrot_planted.emit()
	assert(quest.current_count == 2, "Quest progress is 2/3")
	
	# Emit carrot_planted event 3 (Target reached!)
	var quest_finished := [false]
	qm.quest_completed.connect(func(qid): quest_finished[0] = true)
	bus.carrot_planted.emit()
	assert(quest.current_count == 3, "Quest progress reached 3/3")
	assert(quest.is_completed == true, "Quest marked completed")
	assert(quest_finished[0] == true, "quest_completed signal fired")
	
	qm.queue_free()
	bus.queue_free()
	print("EventBus & Quests tests: OK")


func test_environment_lighting() -> void:
	print("24. Testing Priority 4: Environment Lighting...")
	var env_script = load("res://scripts/environment_manager.gd")
	var env = env_script.new()
	add_child(env)
	env._setup()
	
	assert(env.morning_color == Color(1.0, 1.0, 1.0, 1.0), "Morning color is bright neutral")
	assert(env.night_color.b > env.night_color.r, "Night color has cool blue-purple tone")
	
	env.queue_free()
	print("Environment lighting tests: OK")


func test_zombie_spawner_and_marker2d() -> void:
	print("25. Testing Priority 5: Zombie Spawning & Marker2D Editor Points...")
	var spawner_script = load("res://scripts/SpawnManager.gd")
	var spawner = spawner_script.new()
	add_child(spawner)
	
	# Create a mock ZombieSpawnPoints container with Marker2D nodes
	var container = Node2D.new()
	container.name = "ZombieSpawnPoints"
	spawner.add_child(container)
	
	var m1 = Marker2D.new()
	m1.name = "ZombieSpawnPoint01"
	m1.position = Vector2(200, 200)
	m1.add_to_group("zombie_spawn_point")
	container.add_child(m1)
	
	var m2 = Marker2D.new()
	m2.name = "ZombieSpawnPoint02"
	m2.position = Vector2(-200, -200)
	m2.add_to_group("zombie_spawn_point")
	container.add_child(m2)
	
	var points = spawner.get_zombie_spawn_points()
	assert(points.has(m1), "Spawner discovered Marker2D point 1")
	assert(points.has(m2), "Spawner discovered Marker2D point 2")
	
	container.queue_free()
	spawner.queue_free()
	print("Zombie Spawner & Marker2D tests: OK")


func test_zombie_ai_and_combat() -> void:
	print("26. Testing Priority 6: Zombie AI, Health Bars & Combat...")
	var zombie_scene = load("res://Scenes/zombie.tscn")
	var zombie_a = zombie_scene.instantiate()
	var zombie_b = zombie_scene.instantiate()
	add_child(zombie_a)
	add_child(zombie_b)
	
	# Verify initial state
	assert(zombie_a.max_health == 100, "Zombie A has 100 max HP")
	assert(zombie_a.current_health == 100, "Zombie A starts with 100 HP")
	assert(zombie_b.current_health == 100, "Zombie B starts with 100 HP")
	assert(zombie_a.health_bar != null, "Zombie A has health bar node")
	assert(zombie_a.health_bar.value == 100.0, "Health bar shows 100")
	
	# Attack Zombie A: 30 damage
	zombie_a.take_damage(30, Vector2.RIGHT, 20.0)
	assert(zombie_a.current_health == 70, "Zombie A HP is 70 after 30 damage")
	assert(zombie_a.health_bar.value == 70.0, "Zombie A health bar updated immediately to 70")
	
	# Crucial independence check: Zombie B must NOT be affected!
	assert(zombie_b.current_health == 100, "Zombie B is completely unaffected (still 100 HP)")
	assert(zombie_b.health_bar.value == 100.0, "Zombie B health bar remains 100")
	
	# Fatal damage to Zombie A
	zombie_a.take_damage(100)
	assert(zombie_a.current_health == 0, "Zombie A HP reaches 0")
	assert(zombie_a.is_dead == true, "Zombie A enters dead state")
	assert(zombie_a.health_bar.visible == false, "Zombie A health bar disappears on death")
	
	zombie_a.queue_free()
	zombie_b.queue_free()
	print("Zombie AI & Combat tests: OK")


func test_4_direction_movement_and_facing() -> void:
	print("27. Testing 4-Direction Movement, Directional Facing & Zombie Attack...")
	# 1. Test Animal Cardinal Movement
	var chicken_scene = load("res://Scenes/chicken.tscn")
	var chicken = chicken_scene.instantiate()
	add_child(chicken)
	
	chicken.start_walking()
	assert(chicken.direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT], "Chicken moves only cardinally")
	assert(chicken.velocity.x == 0 or chicken.velocity.y == 0, "No diagonal velocity on chicken")
	
	# Test chicken sprite facing
	chicken._update_facing(Vector2.LEFT)
	assert(chicken.animated_sprite.flip_h == true, "Chicken faces LEFT with flip_h true")
	chicken._update_facing(Vector2.RIGHT)
	assert(chicken.animated_sprite.flip_h == false, "Chicken faces RIGHT with flip_h false")
	
	# 2. Test Zombie Cardinal Movement & face_target()
	var zombie_scene = load("res://Scenes/zombie.tscn")
	var zombie = zombie_scene.instantiate()
	add_child(zombie)
	
	# Test cardinal calculation
	assert(zombie.get_cardinal_direction(Vector2(50, 10)) == Vector2.RIGHT, "Primary X right is Vector2.RIGHT")
	assert(zombie.get_cardinal_direction(Vector2(-50, 10)) == Vector2.LEFT, "Primary X left is Vector2.LEFT")
	assert(zombie.get_cardinal_direction(Vector2(10, 50)) == Vector2.DOWN, "Primary Y down is Vector2.DOWN")
	assert(zombie.get_cardinal_direction(Vector2(10, -50)) == Vector2.UP, "Primary Y up is Vector2.UP")
	
	# Test face_target on target node
	var dummy_target = Node2D.new()
	add_child(dummy_target)
	
	# Target to the right
	dummy_target.global_position = zombie.global_position + Vector2(40, 5)
	zombie.face_target(dummy_target)
	assert(zombie.facing_direction == Vector2.RIGHT, "Zombie faces RIGHT towards target")
	assert(zombie.animated_sprite.flip_h == false, "Zombie sprite flip_h is false when facing RIGHT")
	
	# Target to the left
	dummy_target.global_position = zombie.global_position + Vector2(-40, 5)
	zombie.face_target(dummy_target)
	assert(zombie.facing_direction == Vector2.LEFT, "Zombie faces LEFT towards target")
	assert(zombie.animated_sprite.flip_h == true, "Zombie sprite flip_h is true when facing LEFT")
	
	# Target directly above
	dummy_target.global_position = zombie.global_position + Vector2(0, -40)
	zombie.face_target(dummy_target)
	assert(zombie.facing_direction == Vector2.UP, "Zombie faces UP towards target")
	
	# Target directly below
	dummy_target.global_position = zombie.global_position + Vector2(0, 40)
	zombie.face_target(dummy_target)
	assert(zombie.facing_direction == Vector2.DOWN, "Zombie faces DOWN towards target")
	
	# 3. Test Zombie Wander is Cardinal Only
	zombie._enter_state(zombie.State.WANDER)
	assert(zombie._wander_direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT], "Zombie wander direction is cardinal")
	assert(zombie.velocity.x == 0 or zombie.velocity.y == 0, "Zombie wander has no diagonal movement")
	
	dummy_target.queue_free()
	zombie.queue_free()
	chicken.queue_free()
	print("4-Direction movement & facing tests: OK")


func test_spawn_manager_scene_and_spawning() -> void:
	print("28. Testing Dedicated SpawnManager.tscn & Spawning Rules...")
	var sm_scene = load("res://Scenes/SpawnManager.tscn")
	var sm = sm_scene.instantiate()
	add_child(sm)
	
	# Verify structure
	var z_points = sm.get_zombie_spawn_points()
	var a_points = sm.get_animal_spawn_points()
	assert(z_points.size() == 5, "Found 5 ZombieSpawnPoints in SpawnManager.tscn")
	assert(a_points.size() == 5, "Found 5 AnimalSpawnPoints in SpawnManager.tscn")
	
	# Test zombie spawning
	sm.max_zombies = 3
	sm.min_player_distance_for_zombies = 0.0 # Disable distance filter for unit test
	var spawned_zombies = sm.spawn_zombies()
	assert(spawned_zombies.size() == 3, "Spawned exactly 3 zombies (max_zombies = 3)")
	
	# Check no duplicate positions
	var positions: Array[Vector2] = []
	for z in spawned_zombies:
		assert(not positions.has(z.global_position), "No two zombies share the exact same spawn point")
		positions.append(z.global_position)
	
	# Test clearing zombies
	sm.clear_zombies()
	assert(sm._spawned_zombies.is_empty(), "All spawned zombies cleared")
	
	# Test animal spawning
	sm.max_animals = 4
	var spawned_animals = sm.spawn_animals()
	assert(spawned_animals.size() == 4, "Spawned exactly 4 animals (max_animals = 4)")
	
	var a_positions: Array[Vector2] = []
	for a in spawned_animals:
		assert(not a_positions.has(a.global_position), "No two animals share the exact same spawn point")
		a_positions.append(a.global_position)
	
	sm.clear_animals()
	assert(sm._spawned_animals.is_empty(), "All spawned animals cleared")
	
	sm.queue_free()
	print("SpawnManager.tscn tests: OK")



