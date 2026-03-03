extends PanelContainer

@onready var game_over_text_label: Label = $MarginContainer/VBoxContainer/Label
@onready var new_game_button: Button = $MarginContainer/VBoxContainer/NewGameButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/QuitButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	new_game_button.pressed.connect(_on_new_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	game_over_text_label.text = _get_game_over_text()


func _get_game_over_text() -> String:
	if GameStateManager.did_win:
		return "You survived.\n\nSomehow, you made it."
	match GameStateManager.game_over_reason:
		GameStateManager.GameOverReason.RENT:
			return "The rent was due.\nYou didn't pay.\nThey came in the night. You're gone now."
		GameStateManager.GameOverReason.WORK:
			return "Too many days missed.\nNo job. No money. No way out.\n\nThey found you in the apartment. Empty."
		GameStateManager.GameOverReason.ENERGY:
			return "You couldn't keep going.\nYour body gave out.\n\nNobody noticed for days."
		_:
			return "Game Over."


func _on_new_game_pressed() -> void:
	GameStateManager.play_again()


func _on_quit_pressed() -> void:
	get_tree().quit()
