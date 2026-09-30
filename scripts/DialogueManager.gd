extends Node

## Loads dialogue from JSON, shows via DialogueUI, emits choice signals.
## Add as autoload (Project → Project Settings → Autoload).
## UI registers its dialog popup via register_ui().

const DIALOGUE_PATH := "res://dialogue/dialogue.json"

## Emitted when a choice is selected. (choice_id, dialogue_id)
signal choice_selected(choice_id: String, dialogue_id: String)
## Emitted when dialogue is closed (no choices or after choice).
signal dialogue_closed
## Emitted when dialogue toast is shown.
signal dialogue_opened

var _data: Dictionary = {}
var _current_dialogue_id: String = ""
var _current_complete_on: Array[String] = []
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


func has_dialogue(dialogue_id: String) -> bool:
	return not dialogue_id.is_empty() and _data.has(dialogue_id)


func get_dialogue_payload(dialogue_id: String) -> Dictionary:
	if dialogue_id.is_empty() or not _data.has(dialogue_id):
		return {}
	var raw: Variant = _data[dialogue_id]
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	return {}


func is_dialogue_open() -> bool:
	return not _current_dialogue_id.is_empty()


func get_current_dialogue_id() -> String:
	return _current_dialogue_id


func show_dialogue(dialogue_id: String, disabled_choices: Array = []) -> void:
	print("[DialogueManager] show_dialogue(%s)" % dialogue_id)
	if dialogue_id.is_empty() or not _data.has(dialogue_id):
		push_warning("[DialogueManager] Unknown dialogue: %s" % dialogue_id)
		return
	_current_dialogue_id = dialogue_id
	var entry: Dictionary = _data[dialogue_id]
	_current_complete_on = _parse_complete_on(entry)
	var text: String = str(entry.get("text", ""))
	var speaker: String = str(entry.get("speaker", ""))
	var choices: Array = entry.get("choices", []) as Array
	var face_state: String = str(entry.get("face_state", "talking")).strip_edges()
	if face_state.is_empty():
		face_state = "talking"
	var ui = _get_ui()
	if ui:
		print("[DialogueManager] Calling display on: ", ui.name)
		ui.display(text, speaker, choices, disabled_choices, face_state)
		dialogue_opened.emit()
	else:
		push_warning("[DialogueManager] No UI — not registered and none in group 'dialogue_ui'")


## If a toast is open and this action may complete it, snap + fade.
## "sleep" always matches. Other actions need dialogue.json "complete_on".
func try_complete_for_action(action: String) -> bool:
	var key: String = action.strip_edges()
	if key.is_empty() or _current_dialogue_id.is_empty():
		return false
	if key != "sleep" and not _current_complete_on.has(key):
		return false
	var ui = _get_ui()
	if ui == null:
		return false
	ui.force_complete_and_fade()
	return true


## Hard-clear the toast now (sleep cut-to-black). Safe if nothing is open.
func force_hide_immediate() -> void:
	var ui = _get_ui()
	if ui != null:
		ui.abort_and_hide()
	if _current_dialogue_id.is_empty():
		return
	_current_dialogue_id = ""
	_current_complete_on.clear()
	dialogue_closed.emit()


func _parse_complete_on(entry: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = entry.get("complete_on", [])
	if raw is Array:
		for item: Variant in raw as Array:
			var tag: String = str(item).strip_edges()
			if not tag.is_empty():
				out.append(tag)
	return out


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
	_current_complete_on.clear()
	var ui = _get_ui()
	if ui:
		ui.hide_dialogue()
	dialogue_closed.emit()


func _get_ui():
	if _registered_ui:
		return _registered_ui
	return get_tree().get_first_node_in_group("dialogue_ui") if get_tree() else null
