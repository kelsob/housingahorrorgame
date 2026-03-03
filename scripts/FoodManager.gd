extends Node

## Food pellet purchase system. Escalating price, daily cap, energy gain, spoilage on high heat.
## Add as autoload (Project → Project Settings → Autoload) for global access.

# -----------------------------------------------------------------------------
# Configurable properties (tweak at top for easy balance)
# -----------------------------------------------------------------------------

## Price per pellet, in order. 5 pieces per day, resets each morning.
@export var prices_per_pellet: Array[float] = [5.0, 6.0, 7.0, 8.0, 9.0]
## Energy gained per pellet (via EnergyManager.eat).
@export var energy_per_pellet: int = 1
## Chance (0–1) that food spoils when heat is high. Set to 0 to disable.
@export var spoilage_chance_high_heat: float = 0.0
## Energy penalty when food spoils (negative = lose energy).
@export var spoilage_energy_penalty: int = -1

# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------

var _purchases_today: int = 0

## Emitted when food spoils. Passes energy penalty applied.
signal food_spoiled(energy_penalty: int)


func _ready() -> void:
	GameStateManager.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(new_phase: int) -> void:
	var phase_name := "UNKNOWN"
	match new_phase:
		GameStateManager.Phase.MORNING: phase_name = "MORNING"
		GameStateManager.Phase.WORK: phase_name = "WORK"
		GameStateManager.Phase.NIGHT: phase_name = "NIGHT"
		GameStateManager.Phase.END: phase_name = "END"
	print("[FoodManager] phase_changed received: %s (purchases_before=%s)" % [phase_name, _purchases_today])
	if new_phase == GameStateManager.Phase.MORNING:
		_purchases_today = 0
		print("[FoodManager] RESET _purchases_today -> 0 (new morning)")
	else:
		print("[FoodManager] NO RESET (phase is %s, not MORNING)" % phase_name)


## Get the current price for next food pellet (from prices_per_pellet, resets daily).
func get_current_price() -> float:
	var idx := _purchases_today
	if idx < 0 or idx >= prices_per_pellet.size():
		return prices_per_pellet[-1] if prices_per_pellet.size() > 0 else 0.0
	return prices_per_pellet[idx]


## Check if the player can buy more food today.
func can_buy_more() -> bool:
	return _purchases_today < prices_per_pellet.size()


## Dispense one food pellet. Charges money, increments count. Returns true if successful.
## Does not add energy — the pellet must be interacted with to eat.
func dispense_pellet() -> bool:
	if not can_buy_more():
		push_warning("[FoodManager] dispense_pellet FAIL: can_buy_more=false (purchases=%s, cap=%s)" % [_purchases_today, prices_per_pellet.size()])
		return false
	var price := get_current_price()
	if not MoneyManager.can_afford(price):
		push_warning("[FoodManager] dispense_pellet FAIL: can't afford $%.2f (have $%.2f)" % [price, MoneyManager.current_money])
		return false
	MoneyManager.spend(price)
	_purchases_today += 1
	print("[FoodManager] dispense_pellet OK: purchases_today now %s" % _purchases_today)
	return true


## Eat a food pellet. Always gives energy. May emit food_spoiled for flavor/feedback.
func eat_pellet() -> void:
	EnergyManager.gain(energy_per_pellet)
	if _check_spoilage():
		food_spoiled.emit(spoilage_energy_penalty)


func _check_spoilage() -> bool:
	if not ThermostatManager.is_high_heat():
		return false
	return randf() < spoilage_chance_high_heat


## Start a new game. Resets daily purchase count.
func start_new_game() -> void:
	print("[FoodManager] start_new_game() -> _purchases_today = 0")
	_purchases_today = 0


## Debug: current purchase count (for logging).
func get_purchases_today() -> int:
	return _purchases_today
