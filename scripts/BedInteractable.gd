extends Node3D

## Attach to bed root. At night, press-and-hold interact to sleep.
## Requires collision on this node or a child for raycast to hit.

const HOLD_PROMPT_PATH := "CanvasLayer/UI/HoldConfirmPrompt"
const PLAYER_BODY_PATH := "PlayerBody"

@export var hold_duration_seconds: float = 1.0
@export var hold_prompt_text: String = "Hold E to sleep"
@export var day_block_dialogue_id: String = "bed_day"
@export var debug: bool = true
## Added to the player's interact_range for this object only (meters along look ray).
@export var interact_range_extra: float = 0.0

var _holding: bool = false
var _hold_time: float = 0.0


func get_interaction_prompt() -> String:
	if GameStateManager.current_phase != GameStateManager.Phase.NIGHT:
		return "Can't sleep now"
	return hold_prompt_text


func interact() -> void:
	if debug:
		print("[Bed] interact() called")
	if GameStateManager.current_phase != GameStateManager.Phase.NIGHT:
		if debug:
			print("[Bed] SKIP hold: not night (phase=%s)" % GameStateManager.current_phase)
		if not day_block_dialogue_id.strip_edges().is_empty():
			DialogueManager.show_dialogue(day_block_dialogue_id)
		return
	if _holding:
		return
	_begin_hold()


func _process(delta: float) -> void:
	if not _holding:
		return
	if not Input.is_action_pressed("interact"):
		_cancel_hold()
		return
	if not _is_player_still_aiming_at_bed():
		_cancel_hold()
		return
	_hold_time += delta
	_hold_prompt().set_progress(_hold_time / hold_duration_seconds)
	if _hold_time >= hold_duration_seconds:
		_complete_hold()


func _begin_hold() -> void:
	_holding = true
	_hold_time = 0.0
	_hold_prompt().begin(hold_prompt_text)
	if debug:
		print("[Bed] hold started")


func _cancel_hold() -> void:
	_holding = false
	_hold_time = 0.0
	_hold_prompt().end()
	if debug:
		print("[Bed] hold cancelled")


func _complete_hold() -> void:
	_holding = false
	_hold_time = 0.0
	_hold_prompt().end()
	if debug:
		print("[Bed] hold completed — sleeping")
	if GameStateManager.current_phase != GameStateManager.Phase.NIGHT:
		if debug:
			print("[Bed] SKIP sleep: phase is %s (not NIGHT)" % GameStateManager.current_phase)
		return
	DialogueManager.try_complete_for_action("sleep")
	var overlay = get_tree().get_first_node_in_group("fade_overlay")
	if overlay and overlay.has_method("run_transition"):
		overlay.run_transition(_do_sleep)
	else:
		_do_sleep()


func _do_sleep() -> void:
	print("[Bed] _do_sleep() called")
	DialogueManager.force_hide_immediate()
	if GameStateManager.current_phase != GameStateManager.Phase.NIGHT:
		print("[Bed] _do_sleep: SKIP advance_phase - phase is %s (not NIGHT)" % GameStateManager.current_phase)
		return
	_reset_player_room_door_silent()
	EnergyManager.rest()
	print("[Bed] _do_sleep: calling advance_phase()")
	GameStateManager.advance_phase()


func _reset_player_room_door_silent() -> void:
	var current := get_tree().current_scene
	if current == null:
		return
	var door = current.get_node_or_null("PlayerApartment/Environment/PlayerRoomDoor")
	if door and door.has_method("reset_to_closed_silent"):
		door.reset_to_closed_silent()


func _is_player_still_aiming_at_bed() -> bool:
	var scene: Node = get_tree().current_scene
	var player: Node = scene.get_node(PLAYER_BODY_PATH)
	var aimed: Node = player.get_aimed_interactable()
	return aimed == self


func _hold_prompt() -> HoldConfirmPrompt:
	var node: Node = get_tree().current_scene.get_node(HOLD_PROMPT_PATH)
	assert(
		node is HoldConfirmPrompt,
		"[Bed] Attach scripts/HoldConfirmPrompt.gd to the HoldConfirmPrompt node (path: %s)" % HOLD_PROMPT_PATH
	)
	return node as HoldConfirmPrompt
