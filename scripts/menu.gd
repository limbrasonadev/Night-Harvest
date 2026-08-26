extends Control
class_name PauseMenuUI

signal opened
signal closed

@export var is_open: bool = false

@onready var resume_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var settings_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitButton
@onready var status_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel


func _ready() -> void:
	add_to_group("menu_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = is_open
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_menu") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		toggle()
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
	if get_tree():
		get_tree().paused = true
	if resume_button:
		resume_button.grab_focus()
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if get_tree():
		get_tree().paused = false
	if status_label:
		status_label.text = ""
	closed.emit()


func _on_resume_pressed() -> void:
	close()


func _on_settings_pressed() -> void:
	if status_label:
		status_label.text = "Settings (Phase 1 Placeholder)"


func _on_quit_pressed() -> void:
	if get_tree():
		get_tree().quit()
