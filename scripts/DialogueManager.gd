extends Node

## Loads dialogue from JSON, shows via DialogueUI, emits choice signals.
## Add as autoload (Project → Project Settings → Autoload).
## UI registers its dialog popup via register_ui().

const DIALOGUE_PATH := "res://dialogue/dialogue.json"

## Emitted when a choice is selected. (choice_id, dialogue_id)
signal choice_selected(choice_id: String, dialogue_id: String)
## Emitted when dialogue is closed (no choices or after choice).
signal dialogue_closed
## Emitted when dialogue is shown (for mouse/camera release).
signal dialogue_opened

var _data: Dictionary = {}
var _current_dialogue_id: String = ""
var _registered_ui: Control = null


## Register the dialogue popup (UI calls this with its dialog_popup).
func register_ui(ui: Control) -> void:
	_registered_ui = ui
	print("[DialogueManager] UI registered: ", ui.name)


func _ready() -> void:
	_load_dialogue()


func _load_dialogue() -> void:
	if not FileAccess.file_exists(DIALOGUE_PATH):
		push_warning("[DialogueManager] No dialogue file at %s" % DIALOGUE_PATH)
		return
	var file := FileAccess.open(DIALOGUE_PATH, FileAccess.READ)
	if not file:
		push_warning("[DialogueManager] Failed to open %s" % DIALOGUE_PATH)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("[DialogueManager] Invalid JSON: %s" % json.get_error_message())
		return
	_data = json.data
	if _data.is_empty():
		push_warning("[DialogueManager] Dialogue file is empty")


## Show dialogue by ID. Does nothing if ID not found.
## disabled_choices: array of choice IDs to grey out (e.g. ["go"] when can't afford).
func show_dialogue(dialogue_id: String, disabled_choices: Array = []) -> void:
	print("[DialogueManager] show_dialogue(%s)" % dialogue_id)
	if dialogue_id.is_empty() or not _data.has(dialogue_id):
		push_warning("[DialogueManager] Unknown dialogue: %s" % dialogue_id)
		return
	_current_dialogue_id = dialogue_id
	var entry: Dictionary = _data[dialogue_id]
	var text: String = entry.get("text", "")
	var speaker: String = entry.get("speaker", "")
	var choices: Array = entry.get("choices", [])
	var ui = _get_ui()
	if ui:
		print("[DialogueManager] Calling display on: ", ui.name)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui.display(text, speaker, choices, disabled_choices)
		dialogue_opened.emit()
	else:
		push_warning("[DialogueManager] No UI — not registered and none in group 'dialogue_ui'")


## Called by DialogueUI when user selects a choice.
func select_choice(choice_id: String) -> void:
	var id := _current_dialogue_id
	_close_dialogue()
	choice_selected.emit(choice_id, id)


## Called by DialogueUI when dialogue is dismissed (no choice).
func close_dialogue() -> void:
	_close_dialogue()


func _close_dialogue() -> void:
	_current_dialogue_id = ""
	var ui = _get_ui()
	if ui:
		ui.hide_dialogue()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	dialogue_closed.emit()


func _get_ui():
	if _registered_ui:
		return _registered_ui
	return get_tree().get_first_node_in_group("dialogue_ui") if get_tree() else null
