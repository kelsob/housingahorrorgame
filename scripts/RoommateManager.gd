extends Node

## Roommate core system. Manages active roommates, demands, events, sleep/financial modifiers,
## conflicts, and departure logic. Add as autoload (Project → Project Settings → Autoload).

# -----------------------------------------------------------------------------
# Configurable properties
# -----------------------------------------------------------------------------

## Default roommate definitions. Override or add via code.
@export var default_roommates: Array[RoommateData] = []
## Chance (0–1) for roommate conflict check per night.
@export var conflict_check_chance: float = 0.15

# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------

var _active_roommates: Array[Dictionary] = []  ## { data: RoommateData, unmet_count: int }
var _stability: int = 100  ## 0–100, reduced by conflicts

## Emitted when a roommate is added. Passes roommate data.
signal roommate_added(roommate_data: RoommateData)
## Emitted when a roommate departs. Passes roommate data and reason.
signal roommate_departed(roommate_data: RoommateData, reason: String)
## Emitted when demand is unmet. Passes roommate data and penalty.
signal demand_unmet(roommate_data: RoommateData, penalty: int)
## Emitted when a night event triggers. Passes roommate data.
signal night_event_triggered(roommate_data: RoommateData)
## Emitted when roommates conflict. Passes stability penalty.
signal roommate_conflict(penalty: int)

## List of active roommate data (read-only).
var active_roommates: Array:
	get:
		var out: Array = []
		for r in _active_roommates:
			out.append(r.data)
		return out

## Current stability (0–100).
var stability: int:
	get:
		return _stability


func _ready() -> void:
	GameStateManager.phase_changed.connect(_on_phase_changed)
	ThermostatManager.thermostat_changed.connect(_on_thermostat_changed)
	FurnitureManager.furniture_sold.connect(_on_furniture_sold)
	_update_sleep_modifier()


func _on_phase_changed(new_phase: int) -> void:
	match new_phase:
		GameStateManager.Phase.MORNING:
			_check_demands_morning()
		GameStateManager.Phase.NIGHT:
			_check_demands_night()
			_apply_financial_modifiers()
			_trigger_night_events()
			_check_conflicts()


func _on_thermostat_changed(_new_setting: int) -> void:
	_check_heat_departures()
	_update_sleep_modifier()


func _on_furniture_sold(furniture_type: int) -> void:
	_check_furniture_departures(furniture_type)


# -----------------------------------------------------------------------------
# Roommate Manager: Add / Remove
# -----------------------------------------------------------------------------

## Add a roommate. Returns true if added.
func add_roommate(roommate_data: RoommateData) -> bool:
	if roommate_data == null:
		return false
	for r in _active_roommates:
		if r.data == roommate_data:
			return false
	_active_roommates.append({"data": roommate_data, "unmet_count": 0})
	roommate_added.emit(roommate_data)
	_update_sleep_modifier()
	return true


## Remove a roommate by data reference.
func remove_roommate(roommate_data: RoommateData) -> bool:
	for i in range(_active_roommates.size() - 1, -1, -1):
		if _active_roommates[i].data == roommate_data:
			_active_roommates.remove_at(i)
			roommate_departed.emit(roommate_data, "removed")
			_update_sleep_modifier()
			return true
	return false


## Get unmet demand count for a roommate.
func get_unmet_count(roommate_data: RoommateData) -> int:
	for r in _active_roommates:
		if r.data == roommate_data:
			return r.unmet_count
	return 0


# -----------------------------------------------------------------------------
# Demand System
# -----------------------------------------------------------------------------

const DEMAND_UNMET_PENALTY: int = 5

func _check_demands_morning() -> void:
	for r in _active_roommates.duplicate():
		var data: RoommateData = r.data
		if not _is_demand_met(data):
			r.unmet_count += 1
			_apply_demand_penalty(data)
			if r.unmet_count >= data.unmet_demands_to_leave:
				_remove_roommate_for_unmet_demands(data)
		else:
			r.unmet_count = 0


func _check_demands_night() -> void:
	for r in _active_roommates.duplicate():
		var data: RoommateData = r.data
		if not _is_demand_met(data):
			r.unmet_count += 1
			_apply_demand_penalty(data)
			if r.unmet_count >= data.unmet_demands_to_leave:
				_remove_roommate_for_unmet_demands(data)
		else:
			r.unmet_count = 0


func _apply_demand_penalty(data: RoommateData) -> void:
	demand_unmet.emit(data, DEMAND_UNMET_PENALTY)
	MoneyManager.spend(DEMAND_UNMET_PENALTY)


func _is_demand_met(data: RoommateData) -> bool:
	match data.roommate_type:
		RoommateData.RoommateType.TV_ADDICT:
			return FurnitureManager.is_owned(FurnitureManager.Type.TV)
	return true


func _remove_roommate_for_unmet_demands(data: RoommateData) -> void:
	for i in range(_active_roommates.size() - 1, -1, -1):
		if _active_roommates[i].data == data:
			_active_roommates.remove_at(i)
			roommate_departed.emit(data, "demands_unmet")
			_update_sleep_modifier()
			return


# -----------------------------------------------------------------------------
# Night Event Trigger
# -----------------------------------------------------------------------------

func _trigger_night_events() -> void:
	for r in _active_roommates:
		var data: RoommateData = r.data
		if data.night_event_chance > 0 and randf() < data.night_event_chance:
			night_event_triggered.emit(data)


# -----------------------------------------------------------------------------
# Sleep Modifier Hook
# -----------------------------------------------------------------------------

func _update_sleep_modifier() -> void:
	var base_mod: float = ThermostatManager.get_sleep_modifier()
	var roommate_mod: float = 1.0
	for r in _active_roommates:
		roommate_mod *= r.data.sleep_modifier
	EnergyManager.set_rest_multiplier(base_mod * roommate_mod)


# -----------------------------------------------------------------------------
# Financial Modifier Hook
# -----------------------------------------------------------------------------

func _apply_financial_modifiers() -> void:
	for r in _active_roommates:
		var data: RoommateData = r.data
		if data.nightly_theft > 0:
			MoneyManager.spend(data.nightly_theft)
		if data.nightly_bonus > 0:
			MoneyManager.add(data.nightly_bonus)


# -----------------------------------------------------------------------------
# Conflict System
# -----------------------------------------------------------------------------

func _check_conflicts() -> void:
	if _active_roommates.size() < 2:
		return
	if randf() > conflict_check_chance:
		return
	var penalty := 0
	for r in _active_roommates:
		penalty += r.data.conflict_stability_penalty
	if penalty > 0:
		_stability = maxi(0, _stability - penalty)
		roommate_conflict.emit(penalty)


# -----------------------------------------------------------------------------
# Departure Logic
# -----------------------------------------------------------------------------

func _check_furniture_departures(furniture_type: int) -> void:
	if furniture_type != FurnitureManager.Type.TV:
		return
	for i in range(_active_roommates.size() - 1, -1, -1):
		var data: RoommateData = _active_roommates[i].data
		if data.roommate_type == RoommateData.RoommateType.TV_ADDICT:
			_active_roommates.remove_at(i)
			roommate_departed.emit(data, "tv_sold")
			_update_sleep_modifier()
			return


func _check_heat_departures() -> void:
	if not ThermostatManager or not ThermostatManager.is_high_heat():
		return
	for i in range(_active_roommates.size() - 1, -1, -1):
		var data: RoommateData = _active_roommates[i].data
		if data.leaves_on_high_heat:
			_active_roommates.remove_at(i)
			roommate_departed.emit(data, "high_heat")
			_update_sleep_modifier()


# -----------------------------------------------------------------------------
# Helpers: Create roommates by type
# -----------------------------------------------------------------------------

## Create a RoommateData with default stats for a type.
static func create_roommate(type: RoommateData.RoommateType, name: String = "") -> RoommateData:
	var rd := RoommateData.new()
	rd.roommate_type = type
	rd.display_name = name if name != "" else _default_name_for_type(type)
	match type:
		RoommateData.RoommateType.LOUD_NIGHT:
			rd.demand_description = "Needs quiet"
			rd.sleep_modifier = 0.7
		RoommateData.RoommateType.THIEF:
			rd.demand_description = "Needs trust"
			rd.nightly_theft = 15
		RoommateData.RoommateType.TV_ADDICT:
			rd.demand_description = "Needs TV"
			rd.unmet_demands_to_leave = 1  ## Leaves immediately if TV sold
		RoommateData.RoommateType.SEDUCTIVE_MANIPULATOR:
			rd.demand_description = "Needs attention"
		RoommateData.RoommateType.SUSPICIOUS_FOOD_VENDOR:
			rd.demand_description = "Needs kitchen access"
	return rd


static func _default_name_for_type(type: RoommateData.RoommateType) -> String:
	match type:
		RoommateData.RoommateType.LOUD_NIGHT: return "Loud Neighbor"
		RoommateData.RoommateType.THIEF: return "Shifty"
		RoommateData.RoommateType.TV_ADDICT: return "Couch Potato"
		RoommateData.RoommateType.SEDUCTIVE_MANIPULATOR: return "Charmer"
		RoommateData.RoommateType.SUSPICIOUS_FOOD_VENDOR: return "Vendor"
	return "Roommate"


# -----------------------------------------------------------------------------
# Start New Game
# -----------------------------------------------------------------------------

func start_new_game() -> void:
	_active_roommates.clear()
	_stability = 100
	if default_roommates.size() > 0:
		for rd in default_roommates:
			if rd:
				add_roommate(rd)
	_update_sleep_modifier()
