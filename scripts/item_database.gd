extends RefCounted
class_name ItemDatabase

const ItemDataClass = preload("res://scripts/item_data.gd")
const DECOR_TEXTURE_PATH := "res://Assets/Outdoor decoration/Outdoor_Decor_Free.png"
const TOOLS_TEXTURE_PATH := "res://Assets/Items/tools.png"

static var _items: Dictionary = {}
static var _decor_texture: Texture2D = null
static var _tools_texture: Texture2D = null


static func get_decor_texture(col: int, row: int, tile_w: int = 16, tile_h: int = 16) -> AtlasTexture:
	if not _decor_texture:
		_decor_texture = load(DECOR_TEXTURE_PATH)
	
	var atlas := AtlasTexture.new()
	atlas.atlas = _decor_texture
	atlas.region = Rect2(col * tile_w, row * tile_h, tile_w, tile_h)
	return atlas


static func get_tool_texture(col: int, tile_w: int = 16, tile_h: int = 16) -> AtlasTexture:
	if not _tools_texture:
		_tools_texture = load(TOOLS_TEXTURE_PATH)
	
	var atlas := AtlasTexture.new()
	atlas.atlas = _tools_texture
	atlas.region = Rect2(col * tile_w, 0, tile_w, tile_h)
	return atlas


static func get_item(item_id: String) -> Resource:
	_init_database_if_needed()
	if _items.has(item_id):
		return _items[item_id]
	return null


static func _init_database_if_needed() -> void:
	if not _items.is_empty():
		return
	
	# Wood Log (Row 7, Col 0 - 32x16 log)
	_items["wood_log"] = ItemDataClass.new(
		"wood_log",
		"Wood Log",
		ItemDataClass.ItemType.MATERIAL,
		get_decor_texture(0, 7, 32, 16),
		99
	)
	
	# Stone Rock (Row 2, Col 2 - medium rock)
	_items["stone_rock"] = ItemDataClass.new(
		"stone_rock",
		"Stone Rock",
		ItemDataClass.ItemType.MATERIAL,
		get_decor_texture(2, 2),
		99
	)
	
	# Wild Mushroom (Row 7, Col 2 - red mushroom)
	_items["wild_mushroom"] = ItemDataClass.new(
		"wild_mushroom",
		"Wild Mushroom",
		ItemDataClass.ItemType.CROP,
		get_decor_texture(2, 7),
		99
	)
	
	# Wheat Seed (Row 0, Col 6 - wheat seed pouch)
	var wheat_seed = ItemDataClass.new(
		"wheat_seed",
		"Wheat Seed",
		ItemDataClass.ItemType.SEED,
		get_decor_texture(6, 0),
		99,
		ItemDataClass.ActionType.PLANT
	)
	_items["wheat_seed"] = wheat_seed
	
	# Carrot Seed (Row 0, Col 4 - carrot seed pouch)
	var carrot_seed = ItemDataClass.new(
		"carrot_seed",
		"Carrot Seed",
		ItemDataClass.ItemType.SEED,
		get_decor_texture(4, 0),
		99,
		ItemDataClass.ActionType.PLANT
	)
	_items["carrot_seed"] = carrot_seed
	
	# Iron Sword (Col 0 in tools.png)
	var sword = ItemDataClass.new(
		"iron_sword",
		"Iron Sword",
		ItemDataClass.ItemType.WEAPON,
		get_tool_texture(0),
		1,
		ItemDataClass.ActionType.ATTACK
	)
	sword.usable = true
	sword.weapon_damage = 15
	sword.tool_power = 1
	_items["iron_sword"] = sword
	
	# Wood Axe (Col 1 in tools.png)
	var axe = ItemDataClass.new(
		"wood_axe",
		"Wood Axe",
		ItemDataClass.ItemType.TOOL,
		get_tool_texture(1),
		1,
		ItemDataClass.ActionType.CHOP
	)
	axe.usable = true
	axe.tool_power = 1
	_items["wood_axe"] = axe
	
	# Watering Can (Col 2 in tools.png)
	var can = ItemDataClass.new(
		"watering_can",
		"Watering Can",
		ItemDataClass.ItemType.TOOL,
		get_tool_texture(2),
		1,
		ItemDataClass.ActionType.WATER
	)
	can.usable = true
	_items["watering_can"] = can
	
	# Pickaxe (Col 3 in tools.png)
	var pick = ItemDataClass.new(
		"pickaxe",
		"Pickaxe",
		ItemDataClass.ItemType.TOOL,
		get_tool_texture(3),
		1,
		ItemDataClass.ActionType.MINE
	)
	pick.usable = true
	pick.tool_power = 1
	_items["pickaxe"] = pick
	
	# Hoe (Col 4 in tools.png)
	var hoe = ItemDataClass.new(
		"hoe",
		"Hoe",
		ItemDataClass.ItemType.TOOL,
		get_tool_texture(4),
		1,
		ItemDataClass.ActionType.TILL
	)
	hoe.usable = true
	_items["hoe"] = hoe
