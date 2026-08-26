extends Resource
class_name ItemData

enum ItemType {
	TOOL,
	WEAPON,
	MATERIAL,
	SEED,
	CROP,
	PLACEABLE
}

enum ActionType {
	NONE,
	CHOP,
	MINE,
	ATTACK,
	WATER,
	TILL,
	HARVEST,
	PLANT,
	USE
}

@export var item_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var item_type: ItemType = ItemType.MATERIAL
@export var action_type: ActionType = ActionType.NONE
@export var max_stack: int = 99
@export var icon: Texture2D
@export var world_texture: Texture2D
@export var held_texture: Texture2D
@export var usable: bool = false
@export var placeable: bool = false
@export var tool_power: int = 1
@export var weapon_damage: int = 10
@export var use_distance: float = 36.0


func _init(p_id: String = "", p_name: String = "", p_type: ItemType = ItemType.MATERIAL, p_icon: Texture2D = null, p_max_stack: int = 99, p_action: ActionType = ActionType.NONE) -> void:
	item_id = p_id
	display_name = p_name
	item_type = p_type
	icon = p_icon
	world_texture = p_icon
	held_texture = p_icon
	max_stack = p_max_stack
	action_type = p_action
