extends Node

## Tracks and drives the daily phase cycle: Morning → Work → Night → End.
## Fully controls day number. Day changes only when transitioning from Night → Morning.
## Add as autoload (Project → Project Settings → Autoload) for global access.

enum Phase {
	MORNING,
	WORK,
	NIGHT,
	END
}

## Emitted when the phase changes. Passes the new phase.
signal phase_changed(new_phase: Phase)
## Emitted when the day number changes (e.g. after Night → next Morning).
signal day_changed(new_day: int)

## Current phase in the daily loop.
var current_phase: Phase = Phase.MORNING:
	set(value):
		if current_phase != value:
			current_phase = value
			phase_changed.emit(current_phase)

var _current_day: int = 0
## Current day (0–5). Day 0 is the move-in night. Day changes only on Night -> Morning.
var current_day: int:
	get:
		return _current_day
	set(value):
		if _current_day != value:
			_current_day = clampi(value, 0, total_days)
			day_changed.emit(_current_day)

## Total days to survive.
@export var total_days: int = 5

const GAME_OVER_SCENE_PATH := "res://scenes/GameOverMenu.tscn"
const GAME_SCENE_PATH := "res://scenes/Game.tscn"

# -----------------------------------------------------------------------------
# Rent (paid daily; tracked per day; penalties not implemented)
# -----------------------------------------------------------------------------

## Base rent amount at game start.
@export var base_rent: int = 50
var _current_rent: int = 50
var _rent_paid_today: bool = false
var _missed_rent_payments: int = 0
## History of rent paid per day. Index 0 = day 1, index 1 = day 2, etc.
var _rent_payment_history: Array[bool] = []

## Current rent amount due each day.
var current_rent: int:
	get:
		return _current_rent

## Whether rent has been paid for the current day.
var rent_paid_today: bool:
	get:
		return _rent_paid_today

## Total missed rent payments this game.
var missed_rent_payments: int:
	get:
		return _missed_rent_payments

## History of whether rent was paid each day. Index 0 = day 1.
var rent_payment_history: Array[bool]:
	get:
		return _rent_payment_history.duplicate()


func _ready() -> void:
	phase_changed.connect(_on_phase_changed)
	phase_changed.emit(current_phase)
	day_changed.emit(current_day)


func _on_phase_changed(new_phase: Phase) -> void:
	if new_phase == Phase.END:
		_go_to_game_over_screen()


## Start a new game. Resets to Day 0, Night and resets all managers.
func start_new_game() -> void:
	did_win = false
	game_over_reason = GameOverReason.UNKNOWN
	_current_day = 0
	current_phase = Phase.NIGHT
	day_changed.emit(current_day)
	EnergyManager.start_new_game()
	WorkManager.start_new_game()
	MoneyManager.start_new_game()
	RoommateManager.start_new_game()
	FurnitureManager.start_new_game()
	FoodManager.start_new_game()
	_current_rent = base_rent
	_rent_paid_today = false
	_missed_rent_payments = 0
	_rent_payment_history.clear()


## Pay rent for the current day. Returns true if payment was made (money deducted).
func pay_rent() -> bool:
	if _rent_paid_today:
		return false
	MoneyManager.spend(_current_rent)
	_rent_paid_today = true
	return true


## Increase rent by the given amount.
func increase_rent(amount: int) -> void:
	_current_rent += amount


## Set rent to a specific amount.
func set_rent(amount: int) -> void:
	_current_rent = maxi(0, amount)


## Explicitly set the current day. Use for save/load or debugging.
func set_day(day: int) -> void:
	_current_day = clampi(day, 0, total_days)
	day_changed.emit(_current_day)


## Transition to the next phase.
## Morning → Work → Night → End.
## Day increments only when advancing from Night to the next Morning.
func advance_phase() -> void:
	var phase_name := _phase_name(current_phase)
	print("[GameStateManager] advance_phase() called, current_phase=%s" % phase_name)
	match current_phase:
		Phase.MORNING:
			current_phase = Phase.WORK
			print("[GameStateManager] MORNING -> WORK")
		Phase.WORK:
			current_phase = Phase.NIGHT
			print("[GameStateManager] WORK -> NIGHT")
		Phase.NIGHT:
			_advance_from_night()
		Phase.END:
			print("[GameStateManager] END phase, no advance")


## Skip from MORNING to NIGHT (player went to work; WORK phase is not played).
func advance_morning_to_night() -> void:
	if current_phase == Phase.MORNING:
		current_phase = Phase.NIGHT


func _advance_from_night() -> void:
	print("[GameStateManager] _advance_from_night() day=%s rent_paid=%s missed=%s total_days=%s" % [current_day, _rent_paid_today, _missed_rent_payments, total_days])
	_rent_payment_history.append(_rent_paid_today)
	if not _rent_paid_today:
		_missed_rent_payments += 1
		if _missed_rent_payments >= 2:
			print("[GameStateManager] GAME OVER: 2+ missed rent, going to END (FoodManager will NOT reset)")
			trigger_game_over(GameOverReason.RENT)
			return
	_rent_paid_today = false

	if current_day >= total_days:
		print("[GameStateManager] WIN: day %s >= total_days, going to END (FoodManager will NOT reset)" % current_day)
		did_win = true
		current_phase = Phase.END
	else:
		_current_day += 1
		day_changed.emit(_current_day)
		print("[GameStateManager] advancing to day %s, emitting phase_changed(MORNING) -> FoodManager should reset" % _current_day)
		current_phase = Phase.MORNING


## True if the player won (survived all days). Set when reaching End via night completion.
var did_win: bool = false

## Why the game ended (for GameOverMenu). Set when trigger_game_over is called.
enum GameOverReason {
	RENT,
	WORK,
	ENERGY,
	UNKNOWN
}
var game_over_reason: GameOverReason = GameOverReason.UNKNOWN

## Check if the game has reached its final state (win or loss).
func is_game_over() -> bool:
	return current_phase == Phase.END


func _phase_name(p: Phase) -> String:
	match p:
		Phase.MORNING: return "MORNING"
		Phase.WORK: return "WORK"
		Phase.NIGHT: return "NIGHT"
		Phase.END: return "END"
	return "UNKNOWN"


## Call when a fail condition is met (eviction, energy 0, etc.).
## Transitions to End with did_win = false.
func trigger_game_over(reason: GameOverReason = GameOverReason.UNKNOWN) -> void:
	did_win = false
	game_over_reason = reason
	current_phase = Phase.END


func _go_to_game_over_screen() -> void:
	get_tree().change_scene_to_file(GAME_OVER_SCENE_PATH)


## Call from GameOver screen "Play Again" button. Resets state and loads Game scene.
func play_again() -> void:
	start_new_game()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)
