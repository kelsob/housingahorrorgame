extends Node

## Data-driven narrative hooks by trigger name and day.
## Reads dialogue ids from res://dialogue/dialogue_events.json.
## Example structure:
## {
##   "day_start": { "1": ["thought_wakeup_day_1"] },
##   "arrive_home": { "2": ["thought_arrive_home_day_2"] }
## }

const EVENTS_PATH := "res://dialogue/dialogue_events.json"

var _events: Dictionary = {}
var _consumed_keys: Dictionary = {}


func _ready() -> void:
	_load_events()


func consume_dialogues_for_trigger(trigger_name: String, day: int) -> Array[String]:
	var out: Array[String] = []
	if trigger_name.strip_edges().is_empty():
		return out
	var trigger_block_variant: Variant = _events.get(trigger_name, {})
	if not (trigger_block_variant is Dictionary):
		return out
	var trigger_block: Dictionary = trigger_block_variant
	var day_key: String = str(day)
	var ids_variant: Variant = trigger_block.get(day_key, [])
	if not (ids_variant is Array):
		return out
	var ids: Array = ids_variant
	for id_variant in ids:
		var dialogue_id: String = String(id_variant).strip_edges()
		if dialogue_id.is_empty():
			continue
		var consume_key: String = "%s|%s|%s" % [trigger_name, day_key, dialogue_id]
		if bool(_consumed_keys.get(consume_key, false)):
			continue
		_consumed_keys[consume_key] = true
		out.append(dialogue_id)
	return out


func _load_events() -> void:
	if not FileAccess.file_exists(EVENTS_PATH):
		push_warning("[NarrativeEventManager] No events file at %s" % EVENTS_PATH)
		_events.clear()
		return
	var file: FileAccess = FileAccess.open(EVENTS_PATH, FileAccess.READ)
	if file == null:
		push_warning("[NarrativeEventManager] Failed to open %s" % EVENTS_PATH)
		_events.clear()
		return
	var parser := JSON.new()
	var parse_error: int = parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		push_warning("[NarrativeEventManager] Invalid JSON: %s" % parser.get_error_message())
		_events.clear()
		return
	var parsed: Variant = parser.data
	if parsed is Dictionary:
		_events = parsed
	else:
		push_warning("[NarrativeEventManager] Root must be a dictionary/object")
		_events.clear()
