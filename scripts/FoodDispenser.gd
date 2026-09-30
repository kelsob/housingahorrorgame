extends Node3D

## Attach to FoodDispenser root. Button (food_dispenser_R-button) has collision for raycast.
## Interact to dispense a food pellet. Cost increases each time (via FoodManager).

## Local offset (relative to dispenser) where pellets spawn.
@export var pellet_spawn_offset: Vector3 = Vector3(0.002, 0.193, 0.007)
## FoodPellet scene to instantiate.
@export var pellet_scene: PackedScene
@export var debug: bool = true
## Added to the player's interact_range for this object only (meters along look ray).
@export var interact_range_extra: float = 0.0

const DEFAULT_PELLET_SCENE := "res://scenes/FoodPellet.tscn"


func get_interaction_prompt() -> String:
	if not FoodManager.can_buy_more():
		return "Food sold out today"
	var price: float = FoodManager.get_current_price()
	if not MoneyManager.can_afford(price):
		return "Need $%.2f for food pellet" % price
	return "Buy food pellet for $%.2f? [E]" % price


func interact() -> void:
	if debug:
		print("[FoodDispenser] interact() called")
	if not FoodManager.can_buy_more():
		if debug:
			print("[FoodDispenser] SKIP: daily cap reached (purchases=%s, cap=%s)" % [FoodManager.get_purchases_today(), FoodManager.prices_per_pellet.size()])
		return
	if not FoodManager.dispense_pellet():
		if debug:
			print("[FoodDispenser] FAIL: dispense_pellet returned false")
		return
	if debug:
		print("[FoodDispenser] dispensed, spawning pellet")
	_spawn_pellet()


func _spawn_pellet() -> void:
	var scene := pellet_scene if pellet_scene else load(DEFAULT_PELLET_SCENE) as PackedScene
	if not scene:
		if debug:
			print("[FoodDispenser] FAIL: pellet scene null")
		return
	var pellet = scene.instantiate()
	var parent := get_tree().current_scene
	if parent.has_node("GameObjects"):
		parent = parent.get_node("GameObjects")
	parent.call_deferred("add_child", pellet)
	var world_pos := global_transform * pellet_spawn_offset
	call_deferred("_set_pellet_position", pellet, world_pos)


func _set_pellet_position(pellet: Node3D, world_pos: Vector3) -> void:
	if pellet:
		pellet.global_position = world_pos
