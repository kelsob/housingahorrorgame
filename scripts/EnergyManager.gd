extends Node

## Global energy management for the player. Discrete energy, max 10.
## Actions cost energy; rest, eating, and other sources restore it.
## Add as autoload (Project → Project Settings → Autoload) for global access.

# -----------------------------------------------------------------------------
# Configurable properties (tweak at top for easy balance)
# -----------------------------------------------------------------------------

## Energy the player starts with at game start.
@export var initial_energy: int = 3
## Maximum energy cap. Energy never exceeds this.
@export var max_energy: int = 10
## Energy restored when the player rests/sleeps.
@export var rest_energy_gain: int = 3
## Energy restored when the player eats.
@export var eating_energy_gain: int = 1
## Energy cost to sell plasma.
@export var plasma_selling_energy_cost: int = 2
## Energy cost for gambling (if applicable).
@export var gambling_energy_cost: int = 1

## Multiplier applied to rest gain (e.g. 0.5 = roommates reduce sleep quality).
@export var rest_energy_multiplier: float = 1.0

# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------

var _current_energy: int = 3

## Emitted when energy changes. Passes (new_value, previous_value).
signal energy_changed(new_value: int, previous_value: int)
## Emitted when energy reaches 0 (failure condition).
signal energy_depleted


## Current energy. Clamped to [0, max_energy].
var current_energy: int:
	get:
		return _current_energy
	set(value):
		var prev := _current_energy
		_current_energy = clampi(value, 0, max_energy)
		if _current_energy != prev:
			energy_changed.emit(_current_energy, prev)
			if _current_energy <= 0:
				energy_depleted.emit()


## Start a new game. Resets energy to initial_energy.
func start_new_game() -> void:
	current_energy = initial_energy


## Spend energy for an action. Returns true if successful, false if insufficient.
func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	current_energy -= amount
	return true


## Gain energy (rest, eating, etc.). Returns actual amount gained (capped by max).
func gain(amount: int) -> int:
	var prev := _current_energy
	current_energy += amount
	return _current_energy - prev


## Rest/sleep. Applies rest_energy_gain with rest_energy_multiplier.
func rest() -> int:
	var amount := int(ceilf(rest_energy_gain * rest_energy_multiplier))
	return gain(amount)


## Eat. Returns amount gained.
func eat() -> int:
	return gain(eating_energy_gain)


## Spend energy for plasma selling. Returns true if successful.
func spend_for_plasma() -> bool:
	return spend(plasma_selling_energy_cost)


## Spend energy for gambling. Returns true if successful.
func spend_for_gambling() -> bool:
	return spend(gambling_energy_cost)


## Check if the player can afford an energy cost.
func can_afford(amount: int) -> bool:
	return _current_energy >= amount


## Check if the player can afford to sell plasma.
func can_sell_plasma() -> bool:
	return can_afford(plasma_selling_energy_cost)


## Set the rest multiplier (e.g. for roommate sleep quality reduction).
func set_rest_multiplier(multiplier: float) -> void:
	rest_energy_multiplier = clampf(multiplier, 0.0, 2.0)
