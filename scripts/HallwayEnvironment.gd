extends Node3D

## Owns hallway layout. The player-apartment bay is the same Tilable scene as
## every other section; this script marks its door B as the player's unit.

@export var player_unit_number: String = "216"
@export var player_occupant_code: String = "#0842321967370122-BKCF"

@onready var player_apartment_section: HallwaySectionTilable = $HallwaySectionPlayerApartment


func _ready() -> void:
	player_apartment_section.claim_door_b_for_player(player_unit_number, player_occupant_code)
