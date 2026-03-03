extends Control

@onready var new_game_button: Button = $HBoxContainer/VBoxContainer/VBoxContainer/NewGameButton
@onready var options_button: Button = $HBoxContainer/VBoxContainer/VBoxContainer/OptionsButton
@onready var exit_button: Button = $HBoxContainer/VBoxContainer/VBoxContainer/ExitButton

var options_menu_instance: Control


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	exit_button.pressed.connect(_on_exit_pressed)


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/IntroCutscene.tscn")


func _on_options_pressed() -> void:
	if options_menu_instance == null:
		var options_scene: PackedScene = load("res://scenes/OptionsMenu.tscn") as PackedScene
		options_menu_instance = options_scene.instantiate()
		options_menu_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
		options_menu_instance.visible = false
		call_deferred("add_child", options_menu_instance)
		options_menu_instance.close_requested.connect(_on_options_menu_closed)
	options_menu_instance.visible = true


func _on_options_menu_closed() -> void:
	if options_menu_instance:
		options_menu_instance.visible = false


func _on_exit_pressed() -> void:
	get_tree().quit()
