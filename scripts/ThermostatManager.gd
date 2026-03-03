extends Node

## Thermostat / AC system. Temperature range, daily cost, sleep modifier.
## Add as autoload (Project → Project Settings → Autoload) for global access.

# -----------------------------------------------------------------------------
# Configurable properties (tweak at top for easy balance)
# -----------------------------------------------------------------------------

## Minimum temperature (inclusive).
@export var min_temp: int = 60
## Maximum temperature (inclusive).
@export var max_temp: int = 110
## Step when pressing up/down.
@export var temp_step: int = 1

## Cost per day: tier 0 = coldest (most expensive, AC working hard), tier 2 = hottest (cheapest).
## Climate apocalypse: cooling costs more; 82° is moderate cost.
@export var daily_costs: Array[int] = [30, 18, 10]
## Sleep modifier at low / mid / high tier.
@export var sleep_modifiers: Array[float] = [0.6, 1.0, 1.2]
## Temp thresholds: below low = tier 0, below high = tier 1, else tier 2.
@export var temp_threshold_low: int = 68
@export var temp_threshold_high: int = 78
## Above this temp counts as "high heat" (spoilage, roommate departures).
@export var high_heat_threshold: int = 80
## Starting temp (and new-game reset). Hot default = AC struggling against brutal heat outside.
@export var default_temp: int = 82

# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------

var _current_temp: int = 82

## Emitted when thermostat temperature changes. Passes new temp.
signal thermostat_changed(new_temp: int)

## Current thermostat temperature.
var current_temp: int:
	get:
		return _current_temp


func _ready() -> void:
	GameStateManager.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == GameStateManager.Phase.MORNING:
		_charge_daily_cost()


func _charge_daily_cost() -> void:
	var cost := get_daily_cost()
	if cost > 0:
		MoneyManager.spend(cost)


## Get the tier index (0=low, 1=mid, 2=high) for the current temp.
func _get_tier() -> int:
	if _current_temp < temp_threshold_low:
		return 0
	if _current_temp < temp_threshold_high:
		return 1
	return 2


## Get the daily cost for the current temperature.
func get_daily_cost() -> int:
	var idx := _get_tier()
	if idx >= 0 and idx < daily_costs.size():
		return daily_costs[idx]
	return daily_costs[0] if daily_costs.size() > 0 else 0


## Get the sleep modifier for the current temperature.
func get_sleep_modifier() -> float:
	var idx := _get_tier()
	if idx >= 0 and idx < sleep_modifiers.size():
		return sleep_modifiers[idx]
	return 1.0


## True if current temp is at or above high-heat threshold.
func is_high_heat() -> bool:
	return _current_temp >= high_heat_threshold


## Increase temperature by one step. Clamps to max. Returns true if changed.
func increase_temp() -> bool:
	var next := mini(_current_temp + temp_step, max_temp)
	if next != _current_temp:
		_current_temp = next
		thermostat_changed.emit(_current_temp)
		return true
	return false


## Decrease temperature by one step. Clamps to min. Returns true if changed.
func decrease_temp() -> bool:
	var next := maxi(_current_temp - temp_step, min_temp)
	if next != _current_temp:
		_current_temp = next
		thermostat_changed.emit(_current_temp)
		return true
	return false


## Set temperature directly (clamped to min/max).
func set_temp(temp: int) -> void:
	var clamped := clampi(temp, min_temp, max_temp)
	if clamped != _current_temp:
		_current_temp = clamped
		thermostat_changed.emit(_current_temp)


## Start a new game. Resets to default_temp.
func start_new_game() -> void:
	_current_temp = clampi(default_temp, min_temp, max_temp)
	thermostat_changed.emit(_current_temp)
