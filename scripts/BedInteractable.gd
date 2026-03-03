extends Node3D

## Attach to bed root. Interact to show sleep dialogue only when phase is NIGHT; no popup during day.
## Requires collision on this node or a child for raycast to hit.

## Dialogue ID when it's night (sleep prompt).
@export var sleep_dialogue_id: String = "bed_sleep"
@export var debug: bool = true


func _ready() -> void:
	DialogueManager.choice_selected.connect(_on_choice_selected)


func interact() -> void:
	if debug:
		print("[Bed] interact() called")
	if GameStateManager.current_phase != GameStateManager.Phase.NIGHT:
		if debug:
			print("[Bed] SKIP: not night (phase=%s)" % GameStateManager.current_phase)
		return
	if debug:
		print("[Bed] showing dialogue: ", sleep_dialogue_id)
	DialogueManager.show_dialogue(sleep_dialogue_id)


func _on_choice_selected(choice_id: String, dialogue_id: String) -> void:
	if dialogue_id != sleep_dialogue_id:
		return
	if choice_id != "sleep":
		return
	var overlay = get_tree().get_first_node_in_group("fade_overlay")
	if overlay and overlay.has_method("run_transition"):
		overlay.run_transition(_do_sleep)
	else:
		_do_sleep()


func _do_sleep() -> void:
	print("[Bed] _do_sleep() called")
	EnergyManager.rest()
	if GameStateManager.current_phase != GameStateManager.Phase.NIGHT:
		print("[Bed] _do_sleep: SKIP advance_phase - phase is %s (not NIGHT)" % GameStateManager.current_phase)
		return
	print("[Bed] _do_sleep: calling advance_phase()")
	GameStateManager.advance_phase()
