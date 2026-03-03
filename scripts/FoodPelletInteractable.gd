extends RigidBody3D

## Attach to FoodPellet root (RigidBody3D). Falls under gravity when spawned.
## Requires CollisionShape3D for physics and raycast. Interact to eat.


func interact() -> void:
	FoodManager.eat_pellet()
	queue_free()
