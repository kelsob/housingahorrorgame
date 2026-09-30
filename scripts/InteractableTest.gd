extends Area3D

## Drop-in test script. Attach to any Area3D with a CollisionShape3D.
## When the player looks at it and presses E, prints to console.
## Use to verify interaction works, then replace with real logic.

## Added to the player's interact_range for this object only (meters along look ray).
@export var interact_range_extra: float = 0.0


func get_interaction_prompt() -> String:
	return "Test interact [E]"


func interact() -> void:
	print("InteractableTest: You interacted with ", name, "!")
