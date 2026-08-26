extends Control
class_name HotbarUI

const ItemDataClass = preload("res://scripts/item_data.gd")
const InventoryClass = preload("res://scripts/inventory.gd")

signal slot_selected(slot_index: int, item_data: Resource)

const SLOT_COUNT := 4

@export var selected_slot: int = 0:
	set(value):
		if value >= 0 and value < SLOT_COUNT:
			selected_slot = value
			_update_slot_visuals()
			slot_selected.emit(selected_slot, get_selected_item())

@onready var slot_containers: Array[Control] = [
	$Container/SlotsBox/Slot1,
	$Container/SlotsBox/Slot2,
	$Container/SlotsBox/Slot3,
	$Container/SlotsBox/Slot4
]
@onready var inventory_button: Button = $Container/InventoryHint/InvButton


func _ready() -> void:
	add_to_group("hotbar_ui")
	for i in range(slot_containers.size()):
		var slot_node := slot_containers[i]
		if slot_node:
			if not slot_node.gui_input.is_connected(_on_slot_gui_input):
				slot_node.gui_input.connect(_on_slot_gui_input.bind(i))
			slot_node.set_drag_forwarding(Callable(self, "_get_slot_drag_data").bind(i), Callable(self, "_can_slot_drop_data"), Callable(self, "_slot_drop_data").bind(i))
	
	if inventory_button and not inventory_button.pressed.is_connected(_on_inventory_button_pressed):
		inventory_button.pressed.connect(_on_inventory_button_pressed)
	
	call_deferred("_connect_inventory")


func _connect_inventory() -> void:
	var inv = get_inventory()
	if inv:
		if not inv.inventory_changed.is_connected(_on_inventory_changed):
			inv.inventory_changed.connect(_on_inventory_changed)
		_update_slot_visuals()
		slot_selected.emit(selected_slot, get_selected_item())


func _unhandled_input(event: InputEvent) -> void:
	# Don't switch hotbar slots if inventory UI is currently open (inventory handles slot assignment)
	var inv = get_inventory()
	if inv and inv.get("is_open"):
		return
	
	if event.is_action_pressed("hotbar_1") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_1):
		select_slot(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_2") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_2):
		select_slot(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_3") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_3):
		select_slot(2)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_4") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_4):
		select_slot(3)
		get_viewport().set_input_as_handled()


func select_slot(index: int) -> void:
	if index >= 0 and index < SLOT_COUNT:
		selected_slot = index
		_update_slot_visuals()
		slot_selected.emit(selected_slot, get_selected_item())


func get_selected_slot() -> int:
	return selected_slot


func get_selected_item() -> Resource:
	var slot_data := get_slot_data(selected_slot)
	var amount: int = slot_data.get("amount", 0)
	if amount > 0:
		return slot_data.get("item", null)
	return null


func get_slot_data(index: int) -> Dictionary:
	var inv = get_inventory()
	if inv and inv.has_method("get_item_at"):
		return inv.get_item_at(index)
	return { "item": null, "amount": 0 }


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


func _on_inventory_changed() -> void:
	_update_slot_visuals()
	slot_selected.emit(selected_slot, get_selected_item())


func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var inv = get_inventory()
		if inv and inv.get("is_open") and inv.get("selected_inventory_slot") >= 0:
			var from_slot: int = inv.get("selected_inventory_slot")
			inv.move_to_hotbar(from_slot, slot_index)
			inv.set("selected_inventory_slot", -1)
			inv._update_slot_visuals()
		else:
			select_slot(slot_index)


# ==============================================================================
# DRAG & DROP FORWARDING
# ==============================================================================

func _get_slot_drag_data(_at_position: Vector2, slot_index: int) -> Variant:
	var slot_data := get_slot_data(slot_index)
	if slot_data.get("item") == null or slot_data.get("amount", 0) <= 0:
		return null
	
	var item: Resource = slot_data["item"]
	var preview := TextureRect.new()
	preview.texture = item.get("icon")
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(32, 32)
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)
	
	return { "from_slot": slot_index, "item": item }


func _can_slot_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (typeof(data) == TYPE_DICTIONARY and data.has("from_slot"))


func _slot_drop_data(_at_position: Vector2, data: Variant, to_slot_index: int) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.has("from_slot"):
		var from_slot: int = data["from_slot"]
		var inv = get_inventory()
		if inv and inv.has_method("swap_slots"):
			inv.swap_slots(from_slot, to_slot_index)
			inv.set("selected_inventory_slot", -1)
			inv._update_slot_visuals()


func _on_inventory_button_pressed() -> void:
	var inv = get_inventory()
	if inv and inv.has_method("toggle"):
		inv.toggle()


func _update_slot_visuals() -> void:
	for i in range(slot_containers.size()):
		var slot := slot_containers[i]
		if not is_instance_valid(slot):
			continue
		
		var highlight := slot.get_node_or_null("Highlight")
		var number_label := slot.get_node_or_null("NumberLabel") as Label
		var item_label := slot.get_node_or_null("ItemLabel") as Label
		var icon_rect := slot.get_node_or_null("Icon") as TextureRect
		var count_label := slot.get_node_or_null("CountLabel") as Label
		
		var is_current := (i == selected_slot)
		if highlight:
			highlight.visible = is_current
		
		if number_label:
			if is_current:
				number_label.modulate = Color(1.0, 0.9, 0.25, 1.0)
			else:
				number_label.modulate = Color(0.75, 0.7, 0.65, 0.9)
		
		var slot_data := get_slot_data(i)
		var item: Resource = slot_data.get("item", null)
		var amount: int = slot_data.get("amount", 0)
		
		if item and amount > 0:
			if icon_rect:
				icon_rect.texture = item.get("icon")
				icon_rect.visible = true
			if item_label:
				item_label.text = item.get("display_name") if item.get("display_name") != null else ""
			if count_label:
				count_label.text = str(amount) if amount > 1 else ""
				count_label.visible = amount > 1
		else:
			if icon_rect:
				icon_rect.texture = null
				icon_rect.visible = false
			if item_label:
				item_label.text = ""
			if count_label:
				count_label.text = ""
				count_label.visible = false
