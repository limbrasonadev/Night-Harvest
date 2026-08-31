extends Control
class_name HUDUI

@onready var hp_bar: ProgressBar = $TopLeft/PlayerStatus/Margin/HBox/VBox/HPBar
@onready var hp_label: Label = $TopLeft/PlayerStatus/Margin/HBox/VBox/HPBar/HPLabel
@onready var defense_bar: ProgressBar = $TopLeft/PlayerStatus/Margin/HBox/VBox/EnergyBar
@onready var defense_label: Label = $TopLeft/PlayerStatus/Margin/HBox/VBox/EnergyBar/EnergyLabel
@onready var level_label: Label = $TopLeft/PlayerStatus/Margin/HBox/VBox/LevelRow/LevelLabel
@onready var xp_bar: ProgressBar = $TopLeft/PlayerStatus/Margin/HBox/VBox/LevelRow/XPBar

@onready var day_label: Label = $TopCenter/Calendar/Margin/VBox/DayLabel
@onready var time_label: Label = $TopCenter/Calendar/Margin/VBox/TimeLabel

@onready var gold_label: Label = $TopRight/VBox/Resources/Margin/HBox/GoldLabel
@onready var wood_label: Label = $TopRight/VBox/Resources/Margin/HBox/WoodLabel
@onready var stone_label: Label = $TopRight/VBox/Resources/Margin/HBox/StoneLabel
@onready var minimap: Control = $TopRight/VBox/Minimap

@onready var nightfall_title_label: Label = $BottomRight/Nightfall/Margin/VBox/TitleLabel
@onready var nightfall_timer_label: Label = $BottomRight/Nightfall/Margin/VBox/TimeLabel
@onready var hotbar: Control = $BottomCenter/Hotbar


func _ready() -> void:
	add_to_group("hud_ui")
	# Initial presentation defaults
	set_hp(100, 100)
	set_defense(0, 50)
	set_level_xp(1, 0, 100)
	set_calendar(1, "06:00 AM")
	set_resources(0, 0, 0)
	set_nightfall_warning("13:00")


func set_hp(current: int, max_val: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_val
		hp_bar.value = current
	if hp_label:
		hp_label.text = "❤️ %d/%d" % [current, max_val]


func set_defense(current: int, max_val: int) -> void:
	if defense_bar:
		defense_bar.max_value = max_val
		defense_bar.value = current
	if defense_label:
		defense_label.text = "🛡 %d/%d" % [current, max_val]


func set_level_xp(level: int, current_xp: int, max_xp: int) -> void:
	if level_label:
		level_label.text = "Lv. %d" % level
	if xp_bar:
		xp_bar.max_value = max_xp
		xp_bar.value = current_xp


func set_calendar(day: int, time_str: String) -> void:
	if day_label:
		day_label.text = "☀ DAY %d" % day
	if time_label:
		time_label.text = time_str


func set_resources(gold: int, wood: int, stone: int) -> void:
	if gold_label:
		gold_label.text = "💰 %s" % _format_number(gold)
	if wood_label:
		wood_label.text = "🪵 %d" % wood
	if stone_label:
		stone_label.text = "🪨 %d" % stone


func set_nightfall_warning(time_str: String) -> void:
	if nightfall_title_label:
		nightfall_title_label.text = "🌙 NIGHT COMING IN:"
	if nightfall_timer_label:
		nightfall_timer_label.text = time_str


func set_nightfall_status(status: String) -> void:
	if status == "ARRIVED":
		if nightfall_title_label:
			nightfall_title_label.text = "🌙 NIGHT HAS ARRIVED"
		if nightfall_timer_label:
			nightfall_timer_label.text = ""


func _format_number(n: int) -> String:
	var s := str(n)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count == 3 and i > 0:
			result = "," + result
			count = 0
	return result
