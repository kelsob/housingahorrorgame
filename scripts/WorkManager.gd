extends Node

## Controls work attendance: energy cost, missed days, escalating penalties.
## Tracks whether the player went to work each day. 3 missed days = fail state.
## Add as autoload (Project → Project Settings → Autoload) for global access.

# -----------------------------------------------------------------------------
# Configurable properties (tweak at top for easy balance)
# -----------------------------------------------------------------------------

## Energy required to go to work.
@export var working_energy_cost: int = 3
## Money earned when the player goes to work.
@export var work_pay: int = 80
## Missed days before game over.
@export var max_missed_days_before_fail: int = 3
## Money penalty per missed day (escalating). Index 0 = 1st miss, 1 = 2nd, etc.
@export var missed_day_penalties: Array[int] = [50, 100, 200]

# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------

var _attended_this_work_period: bool = false
var _previous_phase: int = -1
var _missed_work_count: int = 0

## Emitted when the player successfully goes to work. Passes (day, energy_spent).
signal work_attended(day: int, energy_spent: int)
## Emitted when the player misses work. Passes (day, total_missed_count, penalty).
## Connect to MoneyManager or similar to deduct the penalty.
signal work_missed(day: int, total_missed_count: int, penalty: int)
## Emitted when max missed days reached (game over).
signal work_failure


## Total number of work days missed this game.
var missed_work_count: int:
	get:
		return _missed_work_count


func _ready() -> void:
	GameStateManager.phase_changed.connect(_on_phase_changed)
	work_attended.connect(_on_work_attended)
	work_missed.connect(_on_work_missed)


func _on_phase_changed(new_phase: int) -> void:
	match new_phase:
		GameStateManager.Phase.MORNING:
			_attended_this_work_period = false
		GameStateManager.Phase.NIGHT:
			if _previous_phase == GameStateManager.Phase.MORNING and not _attended_this_work_period:
				_record_missed_work()
	_previous_phase = new_phase


func _on_work_attended(_day: int, _energy_spent: int) -> void:
	MoneyManager.add(work_pay)


func _on_work_missed(_day: int, _total_missed: int, penalty: int) -> void:
	MoneyManager.spend(penalty)


func _record_missed_work() -> void:
	_missed_work_count += 1
	var day := GameStateManager.current_day
	var penalty := _get_penalty_for_miss(_missed_work_count)
	work_missed.emit(day, _missed_work_count, penalty)

	if _missed_work_count >= max_missed_days_before_fail:
		work_failure.emit()
		GameStateManager.trigger_game_over(GameStateManager.GameOverReason.WORK)


func _get_penalty_for_miss(miss_number: int) -> int:
	var idx := miss_number - 1
	if idx >= 0 and idx < missed_day_penalties.size():
		return missed_day_penalties[idx]
	return missed_day_penalties[-1] if missed_day_penalties.size() > 0 else 0


## Start a new game. Resets missed count and attendance state.
func start_new_game() -> void:
	_missed_work_count = 0
	_attended_this_work_period = false
	_previous_phase = GameStateManager.Phase.MORNING


## Attempt to go to work. Returns true if successful (energy spent, day marked attended).
## Only valid during MORNING. Advances MORNING → NIGHT (skips WORK phase).
func go_to_work() -> bool:
	if not _can_go_to_work():
		return false

	if not EnergyManager.spend(working_energy_cost):
		return false

	_attended_this_work_period = true
	var day := GameStateManager.current_day
	work_attended.emit(day, working_energy_cost)
	GameStateManager.advance_morning_to_night()
	return true


## Check if the player can go to work (in WORK phase, has energy, hasn't already gone today).
func can_go_to_work() -> bool:
	return _can_go_to_work()


func _can_go_to_work() -> bool:
	if GameStateManager.current_phase != GameStateManager.Phase.MORNING:
		return false
	if _attended_this_work_period:
		return false
	return EnergyManager.can_afford(working_energy_cost)


## Check if the player has already attended work this period.
func attended_this_period() -> bool:
	return _attended_this_work_period


## Check if one more missed day would trigger game over.
func one_miss_from_failure() -> bool:
	return _missed_work_count >= max_missed_days_before_fail - 1


## Get the penalty amount for the next missed day (for UI display).
func get_next_penalty_amount() -> int:
	return _get_penalty_for_miss(_missed_work_count + 1)
