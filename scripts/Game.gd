extends Node

@onready var player_camera: Camera3D = $PlayerBody/PlayerCamera
@onready var player_body: CharacterBody3D = $PlayerBody
@onready var street_level: Node = $GameObjects/StreetLevel

## Delay before narrative event dialogue is queued.
@export var narrative_event_delay_seconds: float = 0.5
## Day 1 special prephase: after first pellet is eaten, wait this long before ending prephase.
@export var day1_prephase_unlock_delay_seconds: float = 5.0
## Main-door block message during day-1 prephase before first pellet.
@export var day1_prephase_hungry_dialogue_id: String = "door_block_day1_hungry"
## Main-door block message during day-1 prephase after first pellet (before arrivals begin).
@export var day1_prephase_early_dialogue_id: String = "door_block_day1_too_early"

const WAKEUP_POSITION := Vector3(-0.7, 1.0, -0.85)
const WAKEUP_ROTATION_DEGREES := Vector3(0, -90, 0)

enum MorningSubphase {
	NONE,
	PREPHASE,
	WORK_UNLOCKED
}

var _thought_queue: Array[String] = []
var _dialogue_open: bool = false
var _thought_currently_showing: bool = false
var _last_phase: int = -1
var _morning_subphase: MorningSubphase = MorningSubphase.NONE
var _prephase_gate_cycle: int = 0
var _waiting_for_day1_first_pellet: bool = false
var _day1_post_food_delay_active: bool = false


## Legacy hook for PlayerCamera input lock. Peephole door UI is retired; arrivals are intercom-only.
func is_door_interaction_active() -> bool:
	return false


func _ready() -> void:
	DialogueManager.dialogue_opened.connect(_on_dialogue_opened)
	DialogueManager.dialogue_closed.connect(_on_dialogue_closed)
	GameStateManager.phase_changed.connect(_on_phase_changed)
	FoodManager.pellet_eaten.connect(_on_food_pellet_eaten)
	_last_phase = GameStateManager.current_phase
	_queue_narrative_event("game_start", narrative_event_delay_seconds)
	if GameStateManager.current_phase == GameStateManager.Phase.MORNING:
		_start_morning_flow()


func _on_dialogue_opened() -> void:
	_dialogue_open = true


func _on_dialogue_closed() -> void:
	_dialogue_open = false
	if _thought_currently_showing:
		_thought_currently_showing = false
	_try_show_next_thought()


func queue_thought_dialogue(dialogue_id: String) -> void:
	if dialogue_id.strip_edges().is_empty():
		return
	_thought_queue.append(dialogue_id)
	_try_show_next_thought()


func _try_show_next_thought() -> void:
	if _dialogue_open:
		return
	if _thought_currently_showing:
		return
	if _thought_queue.is_empty():
		return
	var next_id: String = String(_thought_queue.pop_front())
	_thought_currently_showing = true
	DialogueManager.show_dialogue(next_id)


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == GameStateManager.Phase.MORNING:
		_set_player_wakeup_transform()
		_start_morning_flow()
	if new_phase == GameStateManager.Phase.NIGHT and _last_phase == GameStateManager.Phase.MORNING:
		_queue_narrative_event("arrive_home", narrative_event_delay_seconds)
	if new_phase != GameStateManager.Phase.MORNING:
		_morning_subphase = MorningSubphase.NONE
	_last_phase = new_phase


func _set_player_wakeup_transform() -> void:
	player_body.global_position = WAKEUP_POSITION
	player_body.rotation_degrees = WAKEUP_ROTATION_DEGREES
	player_camera.rotation = Vector3.ZERO
	player_body.velocity = Vector3.ZERO


func _start_morning_flow() -> void:
	_morning_subphase = MorningSubphase.PREPHASE
	_prephase_gate_cycle += 1
	_waiting_for_day1_first_pellet = false
	_day1_post_food_delay_active = false
	_queue_narrative_event("day_start", narrative_event_delay_seconds)
	_configure_prephase_gate_for_day(GameStateManager.current_day, _prephase_gate_cycle)


func _configure_prephase_gate_for_day(day: int, cycle_snapshot: int) -> void:
	match day:
		1:
			_start_day1_prephase_gate(cycle_snapshot)
		_:
			_start_default_prephase_gate(day, cycle_snapshot)


func _start_default_prephase_gate(day: int, cycle_snapshot: int) -> void:
	call_deferred("_finish_morning_prephase", day, cycle_snapshot)


func _start_day1_prephase_gate(_cycle_snapshot: int) -> void:
	_waiting_for_day1_first_pellet = true


func _finish_morning_prephase(day_snapshot: int, cycle_snapshot: int) -> void:
	if cycle_snapshot != _prephase_gate_cycle:
		return
	await _wait_for_dialogues_idle()
	if cycle_snapshot != _prephase_gate_cycle:
		return
	if GameStateManager.current_phase != GameStateManager.Phase.MORNING:
		return
	if GameStateManager.current_day != day_snapshot:
		return
	_unlock_work_and_begin_street_arrivals()


func _wait_for_dialogues_idle() -> void:
	while _dialogue_open or _thought_currently_showing or not _thought_queue.is_empty():
		await get_tree().process_frame


func _on_food_pellet_eaten() -> void:
	DialogueManager.try_complete_for_action("eat_pellet")
	_try_finish_day1_prephase_gate()


func _try_finish_day1_prephase_gate() -> void:
	if not _waiting_for_day1_first_pellet:
		return
	if _morning_subphase != MorningSubphase.PREPHASE:
		return
	if GameStateManager.current_phase != GameStateManager.Phase.MORNING:
		return
	if GameStateManager.current_day != 1:
		return
	_waiting_for_day1_first_pellet = false
	_day1_post_food_delay_active = true
	var day_snapshot: int = GameStateManager.current_day
	var cycle_snapshot: int = _prephase_gate_cycle
	call_deferred("_finish_day1_prephase_after_food_delay", day_snapshot, cycle_snapshot)


func _finish_day1_prephase_after_food_delay(day_snapshot: int, cycle_snapshot: int) -> void:
	await get_tree().create_timer(day1_prephase_unlock_delay_seconds).timeout
	_day1_post_food_delay_active = false
	_finish_morning_prephase(day_snapshot, cycle_snapshot)


func _unlock_work_and_begin_street_arrivals() -> void:
	# Front door is player exit to hallway. Arrivals are handled by StreetLevel + Intercom.
	_morning_subphase = MorningSubphase.WORK_UNLOCKED
	street_level.begin_arrival_window()


func _queue_narrative_event(trigger_name: String, delay_seconds: float) -> void:
	var day: int = GameStateManager.current_day
	var phase_snapshot: int = GameStateManager.current_phase
	var ids: Array[String] = NarrativeEventManager.consume_dialogues_for_trigger(trigger_name, day)
	if ids.is_empty():
		return
	call_deferred("_queue_narrative_event_delayed", ids, day, phase_snapshot, delay_seconds)


func _queue_narrative_event_delayed(ids: Array[String], day_snapshot: int, phase_snapshot: int, delay_seconds: float) -> void:
	await get_tree().create_timer(delay_seconds).timeout
	if GameStateManager.current_day != day_snapshot:
		return
	if GameStateManager.current_phase != phase_snapshot:
		return
	for dialogue_id in ids:
		if DialogueManager.has_dialogue(dialogue_id):
			queue_thought_dialogue(dialogue_id)


## Called by MainDoorInteractable to enforce morning subphases.
## Returns true if interaction was consumed by day-flow logic.
func handle_main_door_interaction() -> bool:
	if GameStateManager.current_phase != GameStateManager.Phase.MORNING:
		return false
	match _morning_subphase:
		MorningSubphase.PREPHASE:
			if _dialogue_open:
				return true
			var block_dialogue_id := _get_prephase_main_door_dialogue_id()
			if DialogueManager.has_dialogue(block_dialogue_id):
				DialogueManager.show_dialogue(block_dialogue_id)
			return true
		MorningSubphase.WORK_UNLOCKED:
			return false
		_:
			return true


func _get_prephase_main_door_dialogue_id() -> String:
	if GameStateManager.current_day == 1:
		if _waiting_for_day1_first_pellet:
			return day1_prephase_hungry_dialogue_id
		if _day1_post_food_delay_active:
			return day1_prephase_early_dialogue_id
	return ""
