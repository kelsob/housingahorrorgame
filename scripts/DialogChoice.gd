extends PanelContainer

## Single dialogue choice option. Instantiated by DialoguePopup.
## Call setup() then add to ChoicesContainer.

signal option_selected(choice_id: String)

@onready var dialog_button: Button = $Button

var _choice_id: String = ""


func setup(text: String, choice_id: String, disabled: bool = false) -> void:
	_choice_id = choice_id
	if dialog_button:
		dialog_button.text = text
		dialog_button.disabled = disabled
		if not dialog_button.pressed.is_connected(_on_button_pressed):
			dialog_button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	option_selected.emit(_choice_id)
