class_name HallwaySectionTilable
extends Node3D

## Shared hallway bay: two doors, two screens. HallwayEnvironment claims door B
## on the player-apartment instance at runtime. Other instances just author
## unit / occupant / lock in the inspector.
##
## Expected children (inherited from hallway_section_tilable.glb):
##   hallway_door_a / hallway_door_b (HallwayDoorInteractable)
##     └─ DoorFrameCollision (StaticBody3D)
##        └─ CollisionShape3D
##   DoorScreenA / DoorScreenB
##   HallwaySectionLights

const SCREEN_SURFACE_INDEX: int = 4

@export_group("Door A")
@export var door_a_unit_number: String = ""
@export var door_a_occupant_code: String = ""
@export var door_a_lock_status: HallwayDoorScreenUI.LockStatus = HallwayDoorScreenUI.LockStatus.LOCKED

@export_group("Door B")
@export var door_b_unit_number: String = ""
@export var door_b_occupant_code: String = ""
@export var door_b_lock_status: HallwayDoorScreenUI.LockStatus = HallwayDoorScreenUI.LockStatus.LOCKED

@onready var _door_a: HallwayDoorInteractable = $hallway_door_a
@onready var _door_b: HallwayDoorInteractable = $hallway_door_b
@onready var _screen_a: DoorScreen = $DoorScreenA
@onready var _screen_b: DoorScreen = $DoorScreenB
@onready var _ui_a: HallwayDoorScreenUI = $DoorScreenA/HallwayDoorScreenUI
@onready var _ui_b: HallwayDoorScreenUI = $DoorScreenB/HallwayDoorScreenUI


func _ready() -> void:
	_ui_a.set_data(door_a_unit_number, door_a_occupant_code, door_a_lock_status)
	_ui_b.set_data(door_b_unit_number, door_b_occupant_code, door_b_lock_status)
	_door_a.bind_screen_ui(_ui_a)
	_door_b.bind_screen_ui(_ui_b)
	_door_a.set_surface_override_material(SCREEN_SURFACE_INDEX, _screen_a.build_material())
	_door_b.set_surface_override_material(SCREEN_SURFACE_INDEX, _screen_b.build_material())


func claim_door_b_for_player(unit_number: String, occupant_code: String) -> void:
	door_b_unit_number = unit_number
	door_b_occupant_code = occupant_code
	door_b_lock_status = HallwayDoorScreenUI.LockStatus.UNLOCKED
	_door_b.configure_player_owned(unit_number, occupant_code)
