extends Node3D

## Added to the player's interact_range for this object only (meters along look ray).
@export var interact_range_extra: float = 0.0


func get_interaction_prompt() -> String:
	return "Use water feeder [E]"


func interact() -> void:
	# Placeholder hook for upcoming water feeder animation/SFX.
	# Intentionally no gameplay effect yet.
	pass
