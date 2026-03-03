extends Control

## Displays dialogue text and choice buttons. Add to group "dialogue_ui".
##
## Scene structure (create manually):
##   Root: Control (full rect or centered)
##   └─ PanelContainer
##      └─ VBoxContainer
##         ├─ DialogueText (Label)
##         └─ ChoicesContainer (VBoxContainer)

@onready var dialogue_text: RichTextLabel = $MarginContainer/MarginContainer/VBoxContainer/RichTextLabel
@onready var choices_container: VBoxContainer = $MarginContainer/MarginContainer/VBoxContainer/ChoicesContainer

## Scene to instantiate for each choice. Must have setup(text, choice_id) and option_selected signal.
@export var choice_scene: PackedScene

var _current_choices: Array = []


func _ready() -> void:
	add_to_group("dialogue_ui")
	hide()
	DialogueManager.dialogue_closed.connect(_on_dialogue_closed)


func _on_dialogue_closed() -> void:
	hide()


func display(text: String, speaker: String, choices: Array, disabled_choices: Array = []) -> void:
	print("[DialoguePopup] display(%s)" % text)
	dialogue_text.text = text
	_current_choices = choices
	_clear_choices()
	var scene := choice_scene if choice_scene else load("res://scenes/DialogChoice.tscn") as PackedScene
	if not scene:
		push_warning("[DialoguePopup] No choice scene")
		show()
		return
	if choices.is_empty():
		var choice = scene.instantiate()
		choices_container.add_child(choice)
		if choice.has_method("setup"):
			choice.setup("Continue", "continue", false)
		if choice.has_signal("option_selected"):
			choice.option_selected.connect(_on_choice_option_selected)
	else:
		for c in choices:
			var choice = scene.instantiate()
			choices_container.add_child(choice)
			var choice_id: String = str(c.get("id", ""))
			var disabled: bool = choice_id in disabled_choices
			if choice.has_method("setup"):
				choice.setup(c.get("text", "?"), choice_id, disabled)
			if choice.has_signal("option_selected"):
				choice.option_selected.connect(_on_choice_option_selected)
	show()


func _on_choice_option_selected(choice_id: String) -> void:
	if choice_id == "continue" or choice_id == "cancel":
		DialogueManager.close_dialogue()
	else:
		DialogueManager.select_choice(choice_id)


func _clear_choices() -> void:
	for c in choices_container.get_children():
		c.queue_free()


func hide_dialogue() -> void:
	_clear_choices()
	hide()
