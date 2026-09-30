extends Node

## Roommate core system. Manages active roommates, demands, events, sleep/financial modifiers,
## conflicts, and departure logic. Add as autoload (Project → Project Settings → Autoload).

# -----------------------------------------------------------------------------
# Configurable properties
# -----------------------------------------------------------------------------

## Default roommate definitions. Override or add via code.
@export var default_roommates: Array[RoommateData] = []
const DEFAULT_ROOMMATE_REGISTRY: Array[RoommateData] = [
	preload("res://resources/roommates/rico_delgado.tres"),
	preload("res://resources/roommates/marcus_webb.tres"),
	preload("res://resources/roommates/dennis_kruk.tres"),
	preload("res://resources/roommates/skylar_bass.tres"),
	preload("res://resources/roommates/jordan_pike.tres"),
	preload("res://resources/roommates/casey_bloom.tres"),
	preload("res://resources/roommates/walter_hedges.tres"),
	preload("res://resources/roommates/morgan_vale.tres"),
	preload("res://resources/roommates/adrian_cross.tres"),
	preload("res://resources/roommates/terry_ginsburg.tres"),
	preload("res://resources/roommates/priya_nair.tres"),
	preload("res://resources/roommates/prince_emmanuel_obi.tres"),
	preload("res://resources/roommates/greg_hull.tres"),
	preload("res://resources/roommates/denise_porter.tres"),
	preload("res://resources/roommates/avery_quinn.tres"),
	preload("res://resources/roommates/blair_kendrick.tres"),
	preload("res://resources/roommates/silas_morrow.tres"),
	preload("res://resources/roommates/mel_ortega.tres"),
]
const DEFAULT_RANDOM_POOL: Array[RoommateData] = [
	preload("res://resources/roommates/rico_delgado.tres"),
	preload("res://resources/roommates/marcus_webb.tres"),
	preload("res://resources/roommates/dennis_kruk.tres"),
	preload("res://resources/roommates/skylar_bass.tres"),
	preload("res://resources/roommates/jordan_pike.tres"),
	preload("res://resources/roommates/casey_bloom.tres"),
	preload("res://resources/roommates/walter_hedges.tres"),
	preload("res://resources/roommates/morgan_vale.tres"),
	preload("res://resources/roommates/adrian_cross.tres"),
	preload("res://resources/roommates/terry_ginsburg.tres"),
	preload("res://resources/roommates/priya_nair.tres"),
	preload("res://resources/roommates/greg_hull.tres"),
	preload("res://resources/roommates/denise_porter.tres"),
	preload("res://resources/roommates/avery_quinn.tres"),
	preload("res://resources/roommates/blair_kendrick.tres"),
	preload("res://resources/roommates/silas_morrow.tres"),
	preload("res://resources/roommates/mel_ortega.tres"),
]
const DEFAULT_ENCOUNTER_SCHEDULE: RoommateEncounterSchedule = preload("res://resources/roommates/game_encounter_schedule.tres")
## All RoommateData resources for schedule lookup (character_id → resource).
@export var roommate_registry: Array[RoommateData] = DEFAULT_ROOMMATE_REGISTRY
## Random door visitors are drawn from here. If empty, uses roommate_registry instead.
@export var random_encounter_pool: Array[RoommateData] = DEFAULT_RANDOM_POOL
## Per-day forced order + random counts. Create a RoommateEncounterSchedule resource in the inspector.
@export var encounter_schedule: RoommateEncounterSchedule = DEFAULT_ENCOUNTER_SCHEDULE
## If true, random picks skip characters already living here (matched by character_id).
@export var random_exclude_active_roommates: bool = true
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
	var roommate_mod: float = 1.0
	for r in _active_roommates:
		roommate_mod *= r.data.sleep_modifier
	EnergyManager.set_rest_multiplier(roommate_mod)


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
		RoommateData.RoommateType.GAMBLER:
			rd.demand_description = "Needs a flat surface to flip a rock"
			rd.night_event_chance = 0.35
		RoommateData.RoommateType.VIOLENT_NONPAYER:
			rd.demand_description = "Bathroom adjacent; stops paying rent"
			rd.conflict_stability_penalty = 25
		RoommateData.RoommateType.FOOD_THIEF:
			rd.demand_description = "Kitchen; distracts you, steals food"
			rd.night_event_chance = 0.3
		RoommateData.RoommateType.BROKE:
			rd.demand_description = "Has no money; needs a break"
			rd.nightly_bonus = 0
		RoommateData.RoommateType.CAT_OWNER:
			rd.demand_description = "Kitchen; needs space for a cat"
		RoommateData.RoommateType.NIGERIAN_PRINCE:
			rd.demand_description = "Investment opportunity (does not move in)"
		RoommateData.RoommateType.FALSE_NORMAL:
			rd.demand_description = "Seems totally normal"
			rd.night_event_chance = 0.15
		RoommateData.RoommateType.SNITCH:
			rd.demand_description = "Keeps notes on everyone"
			rd.conflict_stability_penalty = 15
		RoommateData.RoommateType.HOT_COLD:
			rd.demand_description = "Mood swings"
		RoommateData.RoommateType.USURPER_HELPER:
			rd.demand_description = "Too helpful"
			rd.sleep_modifier = 1.1
		RoommateData.RoommateType.ORGAN_THIEF:
			rd.demand_description = "Medical supplies in the bathroom"
			rd.nightly_theft = 20
		RoommateData.RoommateType.RECURRING_VISITOR:
			rd.demand_description = "Might knock again later"
			rd.night_event_chance = 0.25
	return rd


static func _default_name_for_type(type: RoommateData.RoommateType) -> String:
	match type:
		RoommateData.RoommateType.LOUD_NIGHT: return "Loud Neighbor"
		RoommateData.RoommateType.THIEF: return "Shifty"
		RoommateData.RoommateType.TV_ADDICT: return "Couch Potato"
		RoommateData.RoommateType.SEDUCTIVE_MANIPULATOR: return "Charmer"
		RoommateData.RoommateType.SUSPICIOUS_FOOD_VENDOR: return "Vendor"
		RoommateData.RoommateType.GAMBLER: return "Gambler"
		RoommateData.RoommateType.VIOLENT_NONPAYER: return "Rough Tenant"
		RoommateData.RoommateType.FOOD_THIEF: return "Snack Thief"
		RoommateData.RoommateType.BROKE: return "Broke Roommate"
		RoommateData.RoommateType.CAT_OWNER: return "Cat Person"
		RoommateData.RoommateType.NIGERIAN_PRINCE: return "Investor"
		RoommateData.RoommateType.FALSE_NORMAL: return "Normal Guy"
		RoommateData.RoommateType.SNITCH: return "Snitch"
		RoommateData.RoommateType.HOT_COLD: return "Mood Swing"
		RoommateData.RoommateType.USURPER_HELPER: return "Helpful Stranger"
		RoommateData.RoommateType.ORGAN_THIEF: return "Quiet Doctor"
		RoommateData.RoommateType.RECURRING_VISITOR: return "Return Visitor"
	return "Roommate"


# -----------------------------------------------------------------------------
# Door encounter schedule (forced order + random pool)
# -----------------------------------------------------------------------------

## Build today's visitor queue: forced IDs in order, then random_encounter_count picks from the pool.
func get_encounter_queue_for_day(day: int) -> Array[RoommateData]:
	var queue: Array[RoommateData] = []
	if encounter_schedule == null:
		return queue
	var day_cfg: RoommateDaySchedule = null
	for ds in encounter_schedule.day_schedules:
		if ds != null and ds.day == day:
			day_cfg = ds
			break
	if day_cfg == null:
		return queue
	var reg := _registry_by_id()
	var used_ids: Dictionary = {}
	for id in day_cfg.forced_in_order:
		var sid := String(id).strip_edges()
		if sid.is_empty():
			continue
		if not reg.has(sid):
			push_warning("[RoommateManager] Schedule day %s: unknown character_id '%s'" % [day, sid])
			continue
		queue.append(reg[sid])
		used_ids[sid] = true
	var want_random: int = day_cfg.random_encounter_count
	if want_random <= 0:
		return queue
	var pool: Array[RoommateData] = _random_pool_source()
	var candidates: Array[RoommateData] = []
	for rd in pool:
		if rd == null or String(rd.character_id).strip_edges().is_empty():
			continue
		if used_ids.has(rd.character_id):
			continue
		if random_exclude_active_roommates and _is_active_character_id(rd.character_id):
			continue
		candidates.append(rd)
	candidates.shuffle()
	var pick_count: int = mini(want_random, candidates.size())
	for i in range(pick_count):
		queue.append(candidates[i])
	return queue


func _registry_by_id() -> Dictionary:
	var d: Dictionary = {}
	for rd in roommate_registry:
		if rd == null:
			continue
		var cid := String(rd.character_id).strip_edges()
		if cid.is_empty():
			continue
		d[cid] = rd
	return d


func _random_pool_source() -> Array[RoommateData]:
	if random_encounter_pool.size() > 0:
		return random_encounter_pool.duplicate()
	return roommate_registry.duplicate()


func _is_active_character_id(character_id: String) -> bool:
	for r in _active_roommates:
		var d: RoommateData = r.data
		if d and d.character_id == character_id:
			return true
	return false


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
