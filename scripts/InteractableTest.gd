extends Area3D

## Drop-in test script. Attach to any Area3D with a CollisionShape3D.
## When the player looks at it and presses E, prints to console.
## Use to verify interaction works, then replace with real logic.

func interact() -> void:
	print("InteractableTest: You interacted with ", name, "!")
