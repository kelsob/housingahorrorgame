extends RigidBody3D

## Attach to FoodPellet root (RigidBody3D). Falls under gravity when spawned.
## Settles into freeze after being still (or after a max awake time). Eating any pellet
## wakes all other pellets so piles can collapse, then they settle/freeze again.
## Requires CollisionShape3D for physics and raycast. Interact to eat.

const GROUP_NAME := &"food_pellets"

## Linear + angular speed below this counts as "stationary".
@export var settle_speed_threshold: float = 0.08
## Must stay under the speed threshold this long before locking.
@export var settle_hold_seconds: float = 0.4
## Force-lock even if still jittering (avoids never-settling piles).
@export var max_awake_seconds: float = 5.0
## Added to the player's interact_range for this object only (meters along look ray).
@export var interact_range_extra: float = 0.0

var _locked: bool = false
var _awake_time: float = 0.0
var _settle_time: float = 0.0


func get_interaction_prompt() -> String:
	return "Eat food pellet [E]"


func _ready() -> void:
	add_to_group(GROUP_NAME)
	# We own settle/lock via freeze; don't rely on engine sleep for piles.
	can_sleep = false
	FoodManager.pellet_eaten.connect(_on_any_pellet_eaten)
	_begin_awake()


func _exit_tree() -> void:
	if FoodManager.pellet_eaten.is_connected(_on_any_pellet_eaten):
		FoodManager.pellet_eaten.disconnect(_on_any_pellet_eaten)


func _physics_process(delta: float) -> void:
	if _locked:
		return
	_awake_time += delta
	var speed: float = linear_velocity.length() + angular_velocity.length()
	if speed <= settle_speed_threshold:
		_settle_time += delta
	else:
		_settle_time = 0.0
	if _settle_time >= settle_hold_seconds or _awake_time >= max_awake_seconds:
		_lock()


func interact() -> void:
	FoodManager.eat_pellet()
	queue_free()


## Wake this pellet so gravity/collisions run again until it re-settles.
func wake_for_settle() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_begin_awake()


func _on_any_pellet_eaten() -> void:
	wake_for_settle()


func _begin_awake() -> void:
	_locked = false
	_awake_time = 0.0
	_settle_time = 0.0
	freeze = false
	sleeping = false


func _lock() -> void:
	_locked = true
	_settle_time = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
