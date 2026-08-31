extends Node2D

const ItemDatabaseClass = preload("res://scripts/item_database.gd")


func _ready() -> void:
	call_deferred("_setup_gameplay_items")
	call_deferred("_setup_player_systems")


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


func _setup_player_systems() -> void:
	# --- PlayerStats ---
	var stats_script = preload("res://scripts/player_stats.gd")
	var stats: Node = stats_script.new()
	stats.name = "PlayerStats"
	add_child(stats)
	
	# --- DeathScreen ---
	var death_script = preload("res://scripts/death_screen.gd")
	var death_screen: CanvasLayer = death_script.new()
	death_screen.name = "DeathScreen"
	add_child(death_screen)
	
	# Wire death signal
	stats.player_died.connect(death_screen.show_death_screen)
	
	# --- Wire HUD ---
	var hud = get_node_or_null("UI/HUD")
	if hud:
		stats.health_changed.connect(hud.set_hp)
		stats.defense_changed.connect(hud.set_defense)
		stats.level_changed.connect(func(lvl: int):
			hud.set_level_xp(lvl, stats.xp, stats.xp_to_next_level)
		)
		# Initial sync
		hud.set_hp(stats.current_health, stats.max_health)
		hud.set_defense(stats.current_defense, stats.max_defense)
		hud.set_level_xp(stats.level, stats.xp, stats.xp_to_next_level)
	
	# --- GameClock ---
	var clock_script = preload("res://scripts/game_clock.gd")
	var clock: Node = clock_script.new()
	clock.name = "GameClock"
	add_child(clock)
	
	# Wire clock to HUD
	if hud:
		clock.time_updated.connect(func(hour: int, minute: int):
			hud.set_calendar(clock.current_day, clock.get_time_string())
			if clock.is_night():
				hud.set_nightfall_status("ARRIVED")
			else:
				hud.set_nightfall_warning(clock.get_nightfall_countdown())
		)
		clock.day_changed.connect(func(new_day: int):
			hud.set_calendar(new_day, clock.get_time_string())
		)
		clock.night_started.connect(func():
			hud.set_nightfall_status("ARRIVED")
		)
		clock.night_ended.connect(func():
			hud.set_nightfall_warning(clock.get_nightfall_countdown())
		)
		# Initial sync
		hud.set_calendar(clock.current_day, clock.get_time_string())
		hud.set_nightfall_warning(clock.get_nightfall_countdown())
	
	# --- EventBus ---
	var bus_script = preload("res://scripts/event_bus.gd")
	var event_bus: Node = bus_script.new()
	event_bus.name = "EventBus"
	add_child(event_bus)
	
	# --- QuestManager ---
	var qm_script = preload("res://scripts/quest_manager.gd")
	var quest_mgr: Node = qm_script.new()
	quest_mgr.name = "QuestManager"
	add_child(quest_mgr)
	
	# Wire quest UI updates to HUD
	if hud:
		quest_mgr.quest_progress_updated.connect(func(_qid: String, _cur: int, _tgt: int):
			_update_quest_hud(hud, quest_mgr)
		)
		quest_mgr.quest_completed.connect(func(_qid: String):
			_update_quest_hud(hud, quest_mgr)
		)
		quest_mgr.daily_quests_refreshed.connect(func():
			_update_quest_hud(hud, quest_mgr)
		)
	
	# Refresh quests on new day
	clock.day_changed.connect(func(_day: int):
		quest_mgr.refresh_daily_quests()
	)
	
	# --- EnvironmentManager ---
	var env_script = preload("res://scripts/environment_manager.gd")
	var env_mgr: Node = env_script.new()
	env_mgr.name = "EnvironmentManager"
	add_child(env_mgr)
	
	# --- SpawnManager ---
	var spawn_mgr = get_node_or_null("SpawnManager")
	if not spawn_mgr:
		var spawn_scene = preload("res://Scenes/SpawnManager.tscn")
		spawn_mgr = spawn_scene.instantiate()
		add_child(spawn_mgr)


func _update_quest_hud(hud: Control, quest_mgr: Node) -> void:
	# Update the quest tracker labels (Quest1, Quest2, etc.) in the HUD
	var quest_container = hud.get_node_or_null("MidLeft/QuestTracker/Margin/VBox")
	if not quest_container:
		return
	
	var quest_labels: Array = []
	for child in quest_container.get_children():
		if child is Label and child.name.begins_with("Quest"):
			quest_labels.append(child)
	
	var quests: Array = quest_mgr.active_quests
	
	for i in range(quest_labels.size()):
		var label: Label = quest_labels[i]
		if i < quests.size():
			label.text = quests[i].get_progress_text()
			label.visible = true
			if quests[i].is_completed:
				label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4, 1.0))
			else:
				label.add_theme_color_override("font_color", Color(0.88, 0.85, 0.78, 1.0))
		else:
			label.text = ""
			label.visible = false
