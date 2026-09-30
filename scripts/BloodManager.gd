extends Node

## Blood extraction economy: trade energy for money with daily limits and overuse penalties.
## Add as autoload (Project -> Project Settings -> Autoload) with name "BloodManager".

# -----------------------------------------------------------------------------
# Configurable properties
# -----------------------------------------------------------------------------

## Money payout per extraction in order. If daily count exceeds array length, last value repeats.
@export var payouts_per_extraction: Array[float] = [30.0, 24.0, 18.0]
## Energy cost per extraction in order. If daily count exceeds array length, last value repeats.
@export var energy_costs_per_extraction: Array[int] = [2, 3, 4]
## Hard cap of successful extractions per day.
@export var max_extractions_per_day: int = 3
## Cooldown time between extraction attempts (seconds).
@export var extraction_cooldown_seconds: float = 12.0
## Energy penalty applied when player keeps trying after cap.
@export var overuse_energy_penalty: int = 2
## Money penalty applied when player keeps trying after cap.
@export var overuse_money_penalty: float = 5.0

# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------

var _extractions_today: int = 0
var _overuse_attempts_today: int = 0
var _next_extract_ready_time_msec: int = 0

signal blood_extracted(payout: float, energy_cost: int, extractions_today: int)
signal blood_overused(overuse_attempts_today: int, energy_penalty: int, money_penalty: float)
signal blood_passed_out(payout: float, energy_cost: int, extractions_today: int)


func _ready() -> void:
	GameStateManager.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == GameStateManager.Phase.MORNING:
		_reset_daily_state()


func can_extract_more_today() -> bool:
	return _extractions_today < max_extractions_per_day


func is_on_cooldown() -> bool:
	return Time.get_ticks_msec() < _next_extract_ready_time_msec


func get_cooldown_remaining_seconds() -> float:
	var remain_msec: int = _next_extract_ready_time_msec - Time.get_ticks_msec()
	return maxf(0.0, float(remain_msec) / 1000.0)


func get_current_payout() -> float:
	if payouts_per_extraction.is_empty():
		return 0.0
	var idx: int = mini(_extractions_today, payouts_per_extraction.size() - 1)
	return float(payouts_per_extraction[idx])


func get_current_energy_cost() -> int:
	if energy_costs_per_extraction.is_empty():
		return 1
	var idx: int = mini(_extractions_today, energy_costs_per_extraction.size() - 1)
	return int(energy_costs_per_extraction[idx])


## Attempt one extraction. Always succeeds unless cooldown blocks.
## If daily cap is exceeded, overuse consequences are applied but extraction still occurs.
func extract_blood() -> bool:
	if is_on_cooldown():
		push_warning("[BloodManager] extract_blood FAIL: cooldown %.2fs remaining" % get_cooldown_remaining_seconds())
		return false
	if not can_extract_more_today():
		handle_overuse_attempt()
	var energy_cost: int = get_current_energy_cost()
	var energy_before: int = EnergyManager.current_energy
	var payout: float = get_current_payout()
	if EnergyManager.can_afford(energy_cost):
		EnergyManager.spend(energy_cost)
	else:
		EnergyManager.current_energy = 0
	MoneyManager.add(payout)
	_extractions_today += 1
	_next_extract_ready_time_msec = Time.get_ticks_msec() + int(extraction_cooldown_seconds * 1000.0)
	blood_extracted.emit(payout, energy_cost, _extractions_today)
	if energy_before > 0 and EnergyManager.current_energy <= 0:
		blood_passed_out.emit(payout, energy_cost, _extractions_today)
		push_warning("[BloodManager] PASS OUT triggered after extraction")
	print("[BloodManager] extract_blood OK: payout=$%.2f, energy_cost=%s, extractions_today=%s" % [payout, energy_cost, _extractions_today])
	return true


## Called when player attempts to extract past cap.
func handle_overuse_attempt() -> void:
	_overuse_attempts_today += 1
	if overuse_energy_penalty > 0:
		if EnergyManager.can_afford(overuse_energy_penalty):
			EnergyManager.spend(overuse_energy_penalty)
		else:
			# Force depletion consequence when overusing at critically low energy.
			EnergyManager.current_energy = 0
	if overuse_money_penalty > 0.0:
		MoneyManager.spend(overuse_money_penalty)
	blood_overused.emit(_overuse_attempts_today, overuse_energy_penalty, overuse_money_penalty)
	push_warning("[BloodManager] OVERUSE: attempts_today=%s, energy_penalty=%s, money_penalty=$%.2f" % [_overuse_attempts_today, overuse_energy_penalty, overuse_money_penalty])


func start_new_game() -> void:
	_reset_daily_state()


func get_extractions_today() -> int:
	return _extractions_today


func get_overuse_attempts_today() -> int:
	return _overuse_attempts_today


func _reset_daily_state() -> void:
	_extractions_today = 0
	_overuse_attempts_today = 0
	_next_extract_ready_time_msec = 0
	print("[BloodManager] RESET daily state (morning/new game)")
