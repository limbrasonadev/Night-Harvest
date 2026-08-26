extends Node

const ItemDataScript = preload("res://scripts/item_data.gd")
const ItemDatabaseScript = preload("res://scripts/item_database.gd")
const WorldItemScript = preload("res://scripts/world_item.gd")
const HotbarScript = preload("res://scripts/hotbar.gd")
const InventoryScript = preload("res://scripts/inventory.gd")
const MenuScript = preload("res://scripts/menu.gd")
const KenScript = preload("res://Scenes/ken_idle_front.gd")
const MinimapScript = preload("res://scripts/minimap.gd")
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
	test_hud()
	test_menu()
	test_ken()
	test_held_item_system_and_directions()
	test_directional_swings_and_flips()
	test_action_state_locking_and_timing()
	test_deterministic_drop_and_held_clear()
	test_camera_follow_settings()
	test_tree_cutting_and_wood_harvesting()
	test_pickup_drop_cycle()
	test_game_scene()
	print("--- ALL NIGHT HARVEST MILESTONE 1 TESTS PASSED SUCCESSFULLY! ---")
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
	
	# Remove 1 wood
	var removed = inv.remove_item_at(0, 1)
	assert(removed.item_id == "wood_log", "Removed item is wood")
	assert(inv.get_item_at(0)["amount"] == 14, "Slot 0 now has 14 wood")
	
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
	print("4. Testing Inventory to Hotbar Assignment...")
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	var inv: InventoryUI = inv_scene.instantiate()
	add_child(inv)
	
	var seed = ItemDatabaseScript.get_item("wheat_seed")
	# Place seed in inventory slot 7
	inv.slots[7] = { "item": seed, "amount": 5 }
	
	# Move from slot 7 to hotbar slot 0 (Slot 1 in UI)
	inv.move_to_hotbar(7, 0)
	assert(inv.get_item_at(0)["item"].item_id == "wheat_seed", "Hotbar slot 0 now has wheat seed")
	assert(inv.get_item_at(0)["amount"] == 5, "Hotbar slot 0 has 5 wheat seed")
	assert(inv.get_item_at(7)["item"] == null, "Slot 7 is now empty")
	
	inv.queue_free()
	print("Hotbar Assignment tests: OK")


func test_hotbar_reactive_to_inventory() -> void:
	print("5. Testing Hotbar Reactive Projection of Inventory...")
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
	
	inv.add_item(axe, 1)   # Goes to slot 0
	inv.add_item(sword, 1) # Goes to slot 1
	
	# Hotbar slot 0 should instantly reflect axe
	hotbar.select_slot(0)
	assert(hotbar.get_selected_item() == axe, "Hotbar slot 0 is wood axe")
	
	# Hotbar slot 1 should instantly reflect sword
	hotbar.select_slot(1)
	assert(hotbar.get_selected_item() == sword, "Hotbar slot 1 is iron sword")
	
	# Swap in inventory: slot 0 and slot 1
	inv.swap_slots(0, 1)
	# Hotbar slot 1 should now instantly be axe
	assert(hotbar.get_selected_item() == axe, "Hotbar slot 1 is now axe after inventory swap")
	
	root.queue_free()
	print("Hotbar Reactive Projection tests: OK")


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
	
	# Slot 0 in inventory is now empty (count 0)
	assert(inv.get_item_at(0)["item"] == null, "Inventory slot 0 is empty")
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
	assert(inv.get_item_at(0)["item"].item_id == "wild_mushroom", "Item is wild mushroom")
	assert(inv.get_item_at(0)["amount"] == 3, "Item amount is 3")
	
	world_scene.queue_free()
	print("Pickup cycle tests: OK")


func test_game_scene() -> void:
	print("17. Testing Game Scene Integration...")
	var game_scene = load("res://Scenes/game.tscn")
	var game = game_scene.instantiate()
	add_child(game)
	
	var ui = game.get_node_or_null("UI")
	assert(ui != null, "UI exists")
	assert(ui.get_node_or_null("HUD") != null, "HUD exists")
	assert(ui.get_node_or_null("Inventory") != null, "Inventory exists")
	
	var ken = game.get_node_or_null("CharacterBody2D3")
	assert(ken != null, "Ken exists")
	
	game.queue_free()
	print("Game scene tests: OK")
