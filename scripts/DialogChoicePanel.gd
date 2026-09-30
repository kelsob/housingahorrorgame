extends PanelContainer

## Reusable choice panel used by DoorInteractionUI.
## Call setup(text, choice_id, disabled) then wait for option_selected.

signal option_selected(choice_id: String)

@onready var choice_label: RichTextLabel = $MarginContainer/ChoiceLabel
@onready var button: Button = $Button

var _choice_id: String = ""


func _ready() -> void:
	if button and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)


func setup(text: String, choice_id: String, disabled: bool = false) -> void:
	_choice_id = choice_id
	if choice_label:
		choice_label.text = text
	if button:
		button.disabled = disabled


func _on_button_pressed() -> void:
	option_selected.emit(_choice_id)
