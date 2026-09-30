extends Node3D

## Player-apartment hallway bay: paints a DoorScreen onto the *neighbor* door only.
## The player's apartment door lives elsewhere (MainDoor) with its own screen data —
## this script does not touch it.
##
## Expected structure:
##   HallwaySectionPlayerApartment (this script)
##   ├─ HallwaySectionLights
##   ├─ hallway_section
##   │  ├─ HALLWAY_DOOR_NEIGHBOR (MeshInstance3D)
##   │  └─ DoorScreenNeighbor (DoorScreen)
##   │     └─ HallwayDoorScreenUI

const SCREEN_SURFACE_INDEX: int = 4

@export_group("Neighbor Door")
@export var neighbor_unit_number: String = ""
@export var neighbor_occupant_code: String = ""
@export var neighbor_lock_status: HallwayDoorScreenUI.LockStatus = HallwayDoorScreenUI.LockStatus.LOCKED

@onready var _neighbor_door: HallwayDoorInteractable = $hallway_section/HALLWAY_DOOR_NEIGHBOR
@onready var _neighbor_screen: DoorScreen = $hallway_section/DoorScreenNeighbor
@onready var _neighbor_ui: HallwayDoorScreenUI = $hallway_section/DoorScreenNeighbor/HallwayDoorScreenUI


func _ready() -> void:
	_neighbor_ui.set_data(neighbor_unit_number, neighbor_occupant_code, neighbor_lock_status)
	_neighbor_door.bind_screen_ui(_neighbor_ui)
	# Wait until the SubViewport has drawn its UI child at least once.
	call_deferred("_paint_neighbor_screen")


func _paint_neighbor_screen() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_neighbor_door.set_surface_override_material(
		SCREEN_SURFACE_INDEX,
		_neighbor_screen.build_material()
	)
