extends Resource

## Collection of per-day encounter rules. Assign on RoommateManager.encounter_schedule.
class_name RoommateEncounterSchedule

@export var day_schedules: Array[RoommateDaySchedule] = []
