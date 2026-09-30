extends Node3D

@onready var character_position_marker: Node3D = $CharacterPositionMarker3D

const PLACEHOLDER_DOOR_CHARACTER_SCENE := preload("res://scenes/PlaceholderDoorCharacter.tscn")
const INTERCOM_PATH := "PlayerApartment/Environment/Intercom"

@export var arrival_trigger_name: String = "street_level_arrivals"
@export var auto_show_arrival_dialogue_on_buzz: bool = false
@export var debug: bool = true

signal arrival_spawned(dialogue_id: String)
signal arrival_resolved(dialogue_id: String, accepted: bool)
signal queue_exhausted

var _queued_arrival_dialogue_ids: Array[String] = []
var _active_arrival_dialogue_id: String = ""
var _active_character: Node3D = null
var _arrival_window_open: bool = false


func _ready() -> void:
	GameStateManager.phase_changed.connect(_on_phase_changed)
	if GameStateManager.current_phase != GameStateManager.Phase.MORNING:
		_clear_arrival_state()


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == GameStateManager.Phase.MORNING:
		_arrival_window_open = false
		_clear_arrival_state()
		return
	_clear_arrival_state()


func begin_arrival_window() -> void:
	if GameStateManager.current_phase != GameStateManager.Phase.MORNING:
		return
	if _arrival_window_open:
		return
	_arrival_window_open = true
	_queue_arrivals_for_current_day()


func _queue_arrivals_for_current_day() -> void:
	_clear_arrival_state()
	var trigger_name: String = arrival_trigger_name.strip_edges()
	if trigger_name.is_empty():
		return
	var day: int = GameStateManager.current_day
	var ids: Array[String] = NarrativeEventManager.consume_dialogues_for_trigger(trigger_name, day)
	if ids.is_empty():
		if debug:
			print("[StreetLevel] no narrative arrivals for trigger='%s' day=%s" % [trigger_name, day])
		return
	for dialogue_id in ids:
		if dialogue_id.strip_edges().is_empty():
			continue
		_queued_arrival_dialogue_ids.append(dialogue_id)
	if debug:
		print("[StreetLevel] queued arrivals: %s" % _queued_arrival_dialogue_ids.size())
	_activate_next_arrival_if_idle()


func _activate_next_arrival_if_idle() -> void:
	if _active_character != null:
		return
	if _queued_arrival_dialogue_ids.is_empty():
		queue_exhausted.emit()
		return
	var next_dialogue_id: String = String(_queued_arrival_dialogue_ids.pop_front())
	_spawn_placeholder_character()
	_active_arrival_dialogue_id = next_dialogue_id
	arrival_spawned.emit(_active_arrival_dialogue_id)
	_notify_intercom_arrival_buzz()
	if auto_show_arrival_dialogue_on_buzz:
		_try_auto_open_intercom_dialogue()
	if debug:
		print("[StreetLevel] active arrival dialogue: %s" % _active_arrival_dialogue_id)


func accept_current_arrival() -> void:
	_resolve_active_arrival(true)


func reject_current_arrival() -> void:
	_resolve_active_arrival(false)


func has_active_arrival() -> bool:
	return _active_character != null and not _active_arrival_dialogue_id.is_empty()


func get_active_arrival_dialogue_id() -> String:
	return _active_arrival_dialogue_id


func show_active_arrival_dialogue() -> bool:
	if not has_active_arrival():
		return false
	if not DialogueManager.has_dialogue(_active_arrival_dialogue_id):
		return false
	DialogueManager.show_dialogue(_active_arrival_dialogue_id)
	return true


func _resolve_active_arrival(accepted: bool) -> void:
	if not has_active_arrival():
		return
	var resolved_dialogue_id: String = _active_arrival_dialogue_id
	_clear_active_arrival_only()
	arrival_resolved.emit(resolved_dialogue_id, accepted)
	if debug:
		print("[StreetLevel] resolved arrival='%s' accepted=%s" % [resolved_dialogue_id, accepted])
	_activate_next_arrival_if_idle()


func _spawn_placeholder_character() -> void:
	if character_position_marker == null:
		push_warning("[StreetLevel] Missing CharacterPositionMarker3D")
		return
	var inst: Node = PLACEHOLDER_DOOR_CHARACTER_SCENE.instantiate()
	var door_character: Node3D = inst as Node3D
	if door_character == null:
		push_warning("[StreetLevel] PlaceholderDoorCharacter.tscn root is not Node3D")
		return
	call_deferred("_attach_spawned_character", door_character)


func _attach_spawned_character(door_character: Node3D) -> void:
	if door_character == null:
		return
	add_child(door_character)
	door_character.global_transform = character_position_marker.global_transform
	_active_character = door_character


func _notify_intercom_arrival_buzz() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var intercom: Node = current_scene.get_node_or_null(INTERCOM_PATH)
	if intercom and intercom.has_method("play_street_buzz"):
		intercom.play_street_buzz()


func _try_auto_open_intercom_dialogue() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var intercom: Node = current_scene.get_node_or_null(INTERCOM_PATH)
	if intercom == null:
		return
	if not intercom.has_method("open_active_arrival_dialogue"):
		return
	intercom.call("open_active_arrival_dialogue")


func _clear_arrival_state() -> void:
	_queued_arrival_dialogue_ids.clear()
	_clear_active_arrival_only()


func _clear_active_arrival_only() -> void:
	_active_arrival_dialogue_id = ""
	if _active_character == null:
		return
	_active_character.queue_free()
	_active_character = null
