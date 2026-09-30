class_name HallwayDoorScreenUI
extends Control

## Door-face UI for hallway unit screens (child of a DoorScreen / SubViewport).
## Idle dimming matches IntercomUI: start dimmed, brighten on activity, re-dim after delay.
##
## Scene (HallwayDoorScreenUI.tscn):
##   UIOutside — hallway-facing panel
##     VBoxContainer2/LockedLabel
##     VBoxContainer2/HBoxContainer/UnitNumberLabel
##     VBoxContainer2/HBoxContainer2/OccupantLabel
##   UIInside — room-facing panel
##     VBoxContainer/LockedLabel

enum LockStatus { LOCKED, UNLOCKED }

const LOCK_TEXT: Dictionary = {
	LockStatus.LOCKED: "locked",
	LockStatus.UNLOCKED: "unlocked",
}

const LOCK_COLOR: Dictionary = {
	LockStatus.LOCKED: Color(0.95, 0.78, 0.34, 1.0),
	LockStatus.UNLOCKED: Color(0.62, 0.92, 0.62, 1.0),
}

const VACANT_OCCUPANT_TEXT: String = "vacant"

@export var unit_number: String = ""
## Empty = show "vacant" on the outside occupant line.
@export var occupant_code: String = ""
@export var lock_status: LockStatus = LockStatus.LOCKED

@export_group("Idle Dim")
@export var idle_dim_delay_seconds: float = 3.0
@export var idle_wake_seconds: float = 5.0
@export_range(0.1, 1.0, 0.01) var idle_dim_brightness: float = 0.45
@export var start_idle_dimmed: bool = true

@onready var outside_locked_label: Label = $UIOutside/VBoxContainer2/LockedLabel
@onready var unit_number_label: Label = $UIOutside/VBoxContainer2/HBoxContainer/UnitNumberLabel
@onready var occupant_label: Label = $UIOutside/VBoxContainer2/HBoxContainer2/OccupantLabel
@onready var inside_locked_label: Label = $UIInside/VBoxContainer/LockedLabel

var _idle_dimmed: bool = false
var _idle_dim_cycle: int = 0


func _ready() -> void:
	apply_data()
	if start_idle_dimmed:
		force_idle_dimmed_now()
	else:
		_set_idle_dimmed(false)
		_begin_idle_dim_timer(idle_dim_delay_seconds)


func apply_data() -> void:
	var lock_text: String = String(LOCK_TEXT[lock_status])
	var lock_color: Color = Color(LOCK_COLOR[lock_status])

	outside_locked_label.text = lock_text
	outside_locked_label.add_theme_color_override("font_color", lock_color)
	inside_locked_label.text = lock_text
	inside_locked_label.add_theme_color_override("font_color", lock_color)

	unit_number_label.text = unit_number
	var occupant: String = occupant_code.strip_edges()
	occupant_label.text = VACANT_OCCUPANT_TEXT if occupant.is_empty() else occupant
	_request_screen_redraw()


func set_data(
	new_unit_number: String,
	new_occupant_code: String,
	new_lock_status: LockStatus
) -> void:
	unit_number = new_unit_number
	occupant_code = new_occupant_code
	lock_status = new_lock_status
	apply_data()


## Brighten the screen; re-dim after idle_wake_seconds (same as IntercomUI.register_intercom_activity).
func register_activity() -> void:
	_set_idle_dimmed(false)
	_begin_idle_dim_timer(idle_wake_seconds)


func force_idle_dimmed_now() -> void:
	_cancel_idle_dim_timer()
	_set_idle_dimmed(true)


func _begin_idle_dim_timer(delay_seconds: float) -> void:
	_idle_dim_cycle += 1
	var cycle_snapshot: int = _idle_dim_cycle
	call_deferred("_idle_dim_after_delay", cycle_snapshot, maxf(delay_seconds, 0.0))


func _cancel_idle_dim_timer() -> void:
	_idle_dim_cycle += 1


func _idle_dim_after_delay(cycle_snapshot: int, delay_seconds: float) -> void:
	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds).timeout
	if cycle_snapshot != _idle_dim_cycle:
		return
	_set_idle_dimmed(true)


func _set_idle_dimmed(dimmed: bool) -> void:
	_idle_dimmed = dimmed
	var brightness: float = idle_dim_brightness if dimmed else 1.0
	modulate = Color(brightness, brightness, brightness, 1.0)
	_request_screen_redraw()


func _request_screen_redraw() -> void:
	var screen: SubViewport = get_parent() as SubViewport
	screen.render_target_update_mode = SubViewport.UPDATE_ONCE
