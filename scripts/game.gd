extends Node2D

const ItemDatabaseClass = preload("res://scripts/item_database.gd")


func _ready() -> void:
	call_deferred("_setup_gameplay_items")


func _setup_gameplay_items() -> void:
	_give_initial_tools()
	_populate_starter_chest()
	
	# Explicit sync for first frame
	var hotbar = get_node_or_null("UI/HUD/BottomCenter/Hotbar")
	var ken = get_node_or_null("CharacterBody2D3")
	if hotbar and ken:
		hotbar.call("_update_slot_visuals")
		ken.call("_on_hotbar_slot_selected", hotbar.get("selected_slot"), hotbar.call("get_selected_item"))


func _give_initial_tools() -> void:
	var inv: Control = get_node_or_null("UI/Inventory")
	if inv and inv.has_method("add_item"):
		var sword = ItemDatabaseClass.get_item("iron_sword")
		var axe = ItemDatabaseClass.get_item("wood_axe")
		var can = ItemDatabaseClass.get_item("watering_can")
		var pick = ItemDatabaseClass.get_item("pickaxe")
		
		if sword: inv.call("add_item", sword, 1)
		if axe: inv.call("add_item", axe, 1)
		if can: inv.call("add_item", can, 1)
		if pick: inv.call("add_item", pick, 1)


func _populate_starter_chest() -> void:
	var chest: Node = get_node_or_null("Chest")
	if chest and chest.has_method("add_item"):
		var wood = ItemDatabaseClass.get_item("wood_log")
		var stone = ItemDatabaseClass.get_item("stone_rock")
		var carrot_seed = ItemDatabaseClass.get_item("carrot_seed")
		
		if wood: chest.call("add_item", wood, 8)
		if stone: chest.call("add_item", stone, 5)
		if carrot_seed: chest.call("add_item", carrot_seed, 4)
