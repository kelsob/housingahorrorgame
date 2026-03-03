extends Node3D

## Attach to MainDoor root. Add an Area3D child with CollisionShape3D for the raycast to hit.
## When hit, traverses up to find this node and calls interact().
## Shows "Go to work?" dialogue during MORNING. Going to work advances MORNING → NIGHT.
signal interact_requested

@export var work_dialogue_id: String = "door_work"
@export var debug: bool = true


func _ready() -> void:
	DialogueManager.choice_selected.connect(_on_choice_selected)


func interact() -> void:
	if debug:
		print("[MainDoor] interact() called")
	if GameStateManager.current_phase != GameStateManager.Phase.MORNING:
		if debug:
			print("[MainDoor] SKIP: not MORNING phase (current=%s)" % GameStateManager.current_phase)
		return
	if debug:
		print("[MainDoor] showing dialogue: ", work_dialogue_id)
	var disabled: Array[String] = []
	if not EnergyManager.can_afford(WorkManager.working_energy_cost):
		disabled.append("go")
	elif WorkManager.attended_this_period():
		disabled.append("go")
	DialogueManager.show_dialogue(work_dialogue_id, disabled)


func _on_choice_selected(choice_id: String, dialogue_id: String) -> void:
	if dialogue_id != work_dialogue_id:
		return
	if choice_id != "go":
		return
	if debug:
		print("[MainDoor] choice_selected go, running _do_go_to_work")
	var overlay = get_tree().get_first_node_in_group("fade_overlay")
	if overlay and overlay.has_method("run_transition"):
		overlay.run_transition(_do_go_to_work)
	else:
		_do_go_to_work()


func _do_go_to_work() -> void:
	if debug:
		print("[MainDoor] _do_go_to_work called")
	var ok: bool = WorkManager.go_to_work()
	if debug:
		print("[MainDoor] go_to_work returned: ", ok)
