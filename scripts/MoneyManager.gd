extends Node

## Global money management. Earn from work, plasma, gambling. Spend on rent, food, thermostat.
## Add as autoload (Project → Project Settings → Autoload) for global access.

# -----------------------------------------------------------------------------
# Configurable properties (tweak at top for easy balance)
# -----------------------------------------------------------------------------

## Starting money at game start.
@export var initial_money: float = 100.0

# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------

var _current_money: float = 0.0

## Emitted when money changes. Passes (new_value, previous_value).
signal money_changed(new_value: float, previous_value: float)

## Current money. Can go negative.
var current_money: float:
	get:
		return _current_money
	set(value):
		var prev := _current_money
		_current_money = value
		if _current_money != prev:
			money_changed.emit(_current_money, prev)


## Start a new game. Resets to initial_money.
func start_new_game() -> void:
	current_money = initial_money


## Add money. Returns actual amount added.
func add(amount: float) -> float:
	if amount <= 0:
		return 0.0
	var prev := _current_money
	current_money += amount
	return _current_money - prev


## Spend money. Always deducts; can go negative.
func spend(amount: float) -> bool:
	current_money -= amount
	return true


## Check if the player can afford an amount.
func can_afford(amount: float) -> bool:
	return _current_money >= amount
