extends Control
class_name InventoryUI

const ItemDataClass = preload("res://scripts/item_data.gd")

signal opened
signal closed
signal inventory_changed

const TOTAL_SLOTS := 12
const HOTBAR_SLOT_COUNT := 4

@export var is_open: bool = false

# Array of 12 slot dictionaries: { "item": Resource, "amount": int }
var slots: Array[Dictionary] = []
var selected_inventory_slot: int = -1

@onready var slot_grid: GridContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SlotGrid
@onready var instruction_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/InstructionLabel


func _ready() -> void:
	add_to_group("inventory_ui")
	visible = is_open
	_init_slots()
	_bind_slot_inputs()
	_update_slot_visuals()


func _init_slots() -> void:
	if slots.size() == TOTAL_SLOTS:
		return
	slots.clear()
	for i in range(TOTAL_SLOTS):
		slots.append({ "item": null, "amount": 0 })


func _bind_slot_inputs() -> void:
	if not slot_grid:
		return
	var slot_nodes := slot_grid.get_children()
	for i in range(min(slot_nodes.size(), TOTAL_SLOTS)):
		var slot_panel := slot_nodes[i] as Control
		if slot_panel:
			if not slot_panel.gui_input.is_connected(_on_slot_gui_input):
				slot_panel.gui_input.connect(_on_slot_gui_input.bind(i))
			# Also enable drag and drop forwarding if needed
			slot_panel.set_drag_forwarding(Callable(self, "_get_slot_drag_data").bind(i), Callable(self, "_can_slot_drop_data"), Callable(self, "_slot_drop_data").bind(i))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F):
		toggle()
		get_viewport().set_input_as_handled()
		return
	
	# If inventory is open, allow quick 1-4 assignment of selected slot to hotbar
	if is_open:
		var target_hotbar := -1
		if event.is_action_pressed("hotbar_1") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_1):
			target_hotbar = 0
		elif event.is_action_pressed("hotbar_2") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_2):
			target_hotbar = 1
		elif event.is_action_pressed("hotbar_3") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_3):
			target_hotbar = 2
		elif event.is_action_pressed("hotbar_4") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_4):
			target_hotbar = 3
		
		if target_hotbar >= 0:
			if selected_inventory_slot >= 0:
				move_to_hotbar(selected_inventory_slot, target_hotbar)
				selected_inventory_slot = -1
			else:
				# If no slot is selected, select that hotbar slot
				selected_inventory_slot = target_hotbar
			_update_slot_visuals()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	selected_inventory_slot = -1
	_bind_slot_inputs()
	_update_slot_visuals()
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	selected_inventory_slot = -1
	closed.emit()


## Adds an item to the inventory. Returns the amount that could NOT be added (0 if fully added).
func add_item(item_data: Resource, amount: int = 1) -> int:
	if not item_data or amount <= 0:
		return amount
	
	if slots.size() < TOTAL_SLOTS:
		_init_slots()
	
	var remaining := amount
	var max_stack: int = item_data.get("max_stack") if item_data.get("max_stack") != null else 99
	var item_id: String = item_data.get("item_id") if item_data.get("item_id") != null else ""
	
	# 1. Try to stack into existing matching slots
	if max_stack > 1:
		for i in range(TOTAL_SLOTS):
			var slot := slots[i]
			if slot["item"] != null and slot["item"].get("item_id") == item_id:
				var current_amount: int = slot["amount"]
				var space: int = max_stack - current_amount
				if space > 0:
					var to_add: int = min(remaining, space)
					slot["amount"] += to_add
					remaining -= to_add
					if remaining == 0:
						break
	
	# 2. Put remaining into first empty slot(s)
	if remaining > 0:
		for i in range(TOTAL_SLOTS):
			var slot := slots[i]
			if slot["item"] == null:
				var to_add: int = min(remaining, max_stack)
				slot["item"] = item_data
				slot["amount"] = to_add
				remaining -= to_add
				if remaining == 0:
					break
	
	_update_slot_visuals()
	inventory_changed.emit()
	return remaining


## Removes a specified amount from a slot. Returns the Resource removed (or null).
func remove_item_at(slot_index: int, amount: int = 1) -> Resource:
	if slot_index < 0 or slot_index >= TOTAL_SLOTS:
		return null
	
	var slot := slots[slot_index]
	if slot["item"] == null or slot["amount"] <= 0:
		return null
	
	var removed_item: Resource = slot["item"]
	slot["amount"] -= amount
	
	if slot["amount"] <= 0:
		slot["item"] = null
		slot["amount"] = 0
	
	_update_slot_visuals()
	inventory_changed.emit()
	return removed_item


## Swaps two inventory slots
func swap_slots(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= TOTAL_SLOTS or to_index < 0 or to_index >= TOTAL_SLOTS:
		return
	if from_index == to_index:
		return
	
	var temp := slots[from_index]
	slots[from_index] = slots[to_index]
	slots[to_index] = temp
	
	_update_slot_visuals()
	inventory_changed.emit()


## Moves/swaps an item from any inventory slot to a hotbar slot (0..3)
func move_to_hotbar(inv_slot_index: int, hotbar_slot_index: int) -> void:
	if hotbar_slot_index < 0 or hotbar_slot_index >= HOTBAR_SLOT_COUNT:
		return
	swap_slots(inv_slot_index, hotbar_slot_index)


func get_item_at(slot_index: int) -> Dictionary:
	if slot_index >= 0 and slot_index < TOTAL_SLOTS:
		if slots.size() <= slot_index:
			_init_slots()
		return slots[slot_index]
	return { "item": null, "amount": 0 }


func has_item(item_id: String, count: int = 1) -> bool:
	var total := 0
	for slot in slots:
		if slot["item"] != null and slot["item"].get("item_id") == item_id:
			total += slot["amount"]
			if total >= count:
				return true
	return false


func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	
	if selected_inventory_slot == -1:
		selected_inventory_slot = slot_index
	elif selected_inventory_slot == slot_index:
		selected_inventory_slot = -1
	else:
		swap_slots(selected_inventory_slot, slot_index)
		selected_inventory_slot = -1
	
	_update_slot_visuals()


# ==============================================================================
# DRAG & DROP SUPPORT
# ==============================================================================

func _get_slot_drag_data(_at_position: Vector2, slot_index: int) -> Variant:
	var slot_data := get_item_at(slot_index)
	if slot_data["item"] == null:
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
		swap_slots(from_slot, to_slot_index)
		selected_inventory_slot = -1
		_update_slot_visuals()


func _update_slot_visuals() -> void:
	if not slot_grid:
		return
	
	if instruction_label:
		if selected_inventory_slot >= 0:
			var slot_name := "Hotbar [%d]" % (selected_inventory_slot + 1) if selected_inventory_slot < 4 else "Slot %d" % (selected_inventory_slot + 1)
			instruction_label.text = "%s Selected: Click another slot to swap | Press 1-4 to assign" % slot_name
			instruction_label.modulate = Color(1.0, 0.9, 0.3, 1.0)
		else:
			instruction_label.text = "Click or Drag to move/swap | 1-4: Quick Assign | F: Close"
			instruction_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
	
	var slot_nodes := slot_grid.get_children()
	for i in range(min(slot_nodes.size(), TOTAL_SLOTS)):
		var slot_panel := slot_nodes[i] as Panel
		var slot_data := get_item_at(i)
		
		# Update highlight visual
		if i == selected_inventory_slot:
			slot_panel.add_theme_stylebox_override("panel", load("res://Scenes/UI/inventory.tscn::StyleBoxFlat_slot_selected"))
		else:
			slot_panel.remove_theme_stylebox_override("panel")
		
		var icon_rect := slot_panel.get_node_or_null("Icon") as TextureRect
		var count_label := slot_panel.get_node_or_null("CountLabel") as Label
		var slot_num_label := slot_panel.get_node_or_null("SlotNumLabel") as Label
		
		if slot_num_label:
			slot_num_label.visible = (i < HOTBAR_SLOT_COUNT)
		
		if slot_data["item"] != null:
			var item: Resource = slot_data["item"]
			var amount: int = slot_data["amount"]
			
			if icon_rect:
				icon_rect.texture = item.get("icon")
				icon_rect.visible = true
			if count_label:
				count_label.text = str(amount) if amount > 1 else ""
				count_label.visible = amount > 1
		else:
			if icon_rect:
				icon_rect.texture = null
				icon_rect.visible = false
			if count_label:
				count_label.text = ""
				count_label.visible = false
