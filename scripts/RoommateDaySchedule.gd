extends Resource

## One game day's door-encounter plan: forced order, then random draws from the pool.
class_name RoommateDaySchedule

## Game day (1 = first day). Must match GameStateManager.current_day when encounters run.
@export var day: int = 1
## Character IDs (RoommateData.character_id) that MUST appear at the door, in this order.
@export var forced_in_order: PackedStringArray = []
## After all forced encounters, this many additional visitors are drawn from the random pool.
@export var random_encounter_count: int = 0
