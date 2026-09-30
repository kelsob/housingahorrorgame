extends Node3D

## Elevator hallway bay: paints the neighbor unit door screen only.
##
## Expected structure (set up in Game / HallwaySectionElevator):
##   HallwaySectionElevator (this script)
##   └─ hallway_ELEVATOR_section
##      ├─ HALLWAY_DOOR_001
##      └─ DoorScreenElevator
##         └─ HallwayDoorScreenUI

const DOOR_SCREEN_SURFACE_INDEX: int = 4

@export_group("Elevator Door")
@export var unit_number: String = ""
@export var occupant_code: String = ""
@export var lock_status: HallwayDoorScreenUI.LockStatus = HallwayDoorScreenUI.LockStatus.LOCKED

@onready var _door: HallwayDoorInteractable = $hallway_elevator_door_a
@onready var _door_screen: DoorScreen = $DoorScreenA
@onready var _door_ui: HallwayDoorScreenUI = $DoorScreenA/HallwayDoorScreenUI


func _ready() -> void:
	_door_ui.set_data(unit_number, occupant_code, lock_status)
	_door.bind_screen_ui(_door_ui)
	call_deferred("_paint_door_screen")

func _paint_door_screen() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_door.set_surface_override_material(DOOR_SCREEN_SURFACE_INDEX, _door_screen.build_material())
