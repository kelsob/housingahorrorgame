extends StaticBody3D

## Attach to donate button collision on the blood machine screen.
## Proxies look-prompt and interact to the BloodExtractor root.

const TARGET_PATH := ^".."

@export var debug: bool = true
## Added to the player's interact_range for this object only (meters along look ray).
@export var interact_range_extra: float = 0.0

@onready var target: Node = get_node(TARGET_PATH)


func get_interaction_prompt() -> String:
	return String(target.get_interaction_prompt())


func interact() -> void:
	if debug:
		print("[BloodDonateButton] interact() called")
	target.interact()
