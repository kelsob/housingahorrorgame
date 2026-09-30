extends Node3D

## Attach to BloodExtractor root (wall machine). Hold interact to donate blood for money at energy cost.
## Requires collision on this node or a child (e.g. donate button) for raycast hits.

const AI_FACE_PATH := "SubViewport/Control/HBoxContainer/AIFace"
const HOLD_PROMPT_PATH := "CanvasLayer/UI/HoldConfirmPrompt"
const PLAYER_BODY_PATH := "PlayerBody"
const DONATE_BUTTON_PATH := "StaticBody3D"

@export var debug: bool = true
@export var hold_duration_seconds: float = 1.0
@export var hold_prompt_text: String = "Hold E to donate blood"
@export var pass_out_dialogue_id: String = "blood_extract_pass_out"
## Added to the player's interact_range for this object only (meters along look ray).
@export var interact_range_extra: float = 0.0

@onready var ai_face: AIFace = get_node(AI_FACE_PATH) as AIFace
@onready var donate_button: Node = get_node(DONATE_BUTTON_PATH)

var _pending_game_over_after_pass_out: bool = false
var _holding: bool = false
var _hold_time: float = 0.0


func get_interaction_prompt() -> String:
	if BloodManager.is_on_cooldown():
		return "Blood machine cooling down"
	return hold_prompt_text


func _ready() -> void:
	DialogueManager.dialogue_closed.connect(_on_dialogue_closed)
	BloodManager.blood_passed_out.connect(_on_blood_passed_out)


func interact() -> void:
	if debug:
		print("[BloodExtractor] interact() called")
	if BloodManager.is_on_cooldown():
		if debug:
			print("[BloodExtractor] SKIP hold: on cooldown")
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
	if not _is_player_still_aiming_at_machine():
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
		print("[BloodExtractor] hold started")


func _cancel_hold() -> void:
	_holding = false
	_hold_time = 0.0
	_hold_prompt().end()
	if debug:
		print("[BloodExtractor] hold cancelled")


func _complete_hold() -> void:
	_holding = false
	_hold_time = 0.0
	_hold_prompt().end()
	if BloodManager.is_on_cooldown():
		if debug:
			print("[BloodExtractor] SKIP extract: cooldown during hold")
		return
	if not BloodManager.extract_blood():
		if debug:
			print("[BloodExtractor] extraction blocked (likely cooldown)")
		return
	ai_face.celebrate()
	if debug:
		print(
			"[BloodExtractor] extraction success (count=%s, overuse_attempts=%s)"
			% [BloodManager.get_extractions_today(), BloodManager.get_overuse_attempts_today()]
		)


func _is_player_still_aiming_at_machine() -> bool:
	var scene: Node = get_tree().current_scene
	var player: Node = scene.get_node(PLAYER_BODY_PATH)
	var aimed: Node = player.get_aimed_interactable()
	return aimed == self or aimed == donate_button


func _hold_prompt() -> HoldConfirmPrompt:
	var node: Node = get_tree().current_scene.get_node(HOLD_PROMPT_PATH)
	assert(
		node is HoldConfirmPrompt,
		"[BloodExtractor] Attach scripts/HoldConfirmPrompt.gd to HoldConfirmPrompt (path: %s)"
		% HOLD_PROMPT_PATH
	)
	return node as HoldConfirmPrompt


func _on_blood_passed_out(_payout: float, _energy_cost: int, _extractions_today: int) -> void:
	_pending_game_over_after_pass_out = true
	DialogueManager.show_dialogue(pass_out_dialogue_id)


func _on_dialogue_closed() -> void:
	if not _pending_game_over_after_pass_out:
		return
	_pending_game_over_after_pass_out = false
	GameStateManager.trigger_game_over(GameStateManager.GameOverReason.ENERGY)
