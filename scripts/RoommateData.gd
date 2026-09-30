extends Resource

## Data structure for a roommate. Defines type, demand, effects, and departure conditions.
## Create instances or extend for custom roommate definitions.

class_name RoommateData

## Stable id for dialogue, saves, and encounter logic (e.g. "rico_food_vendor").
@export var character_id: String = ""
## Display name.
@export var display_name: String = "Roommate"
## Archetype that defines behavior.
@export var roommate_type: RoommateType = RoommateType.LOUD_NIGHT
## Demand description (for UI).
@export var demand_description: String = ""
## Consecutive unmet demands before departure.
@export var unmet_demands_to_leave: int = 2
## Sleep modifier when this roommate is present (multiplier, e.g. 0.8 = 20% less sleep).
@export var sleep_modifier: float = 1.0
## Money stolen per night (negative = theft). 0 = no theft.
@export var nightly_theft: int = 0
## Money bonus per night (positive). 0 = no bonus.
@export var nightly_bonus: int = 0
## Chance (0–1) to trigger unique event at night.
@export var night_event_chance: float = 0.2
## Stability penalty when in conflict with another roommate.
@export var conflict_stability_penalty: int = 10
## Voice-generator settings for this character's door dialogue.
@export var voice_enabled: bool = true
## Subfolder under res://addons/godot-voice-generator/sound/alphabet/.
@export_enum("high", "med", "low", "lowest") var voice_alphabet_pitch: String = "med"
@export_range(0.1, 4.0, 0.01) var voice_main_pitch_scale: float = 1.0
@export_range(0.0, 2.0, 0.01) var voice_random_pitch: float = 1.0
@export_range(0.0, 24.0, 0.1) var voice_random_volume_offset_db: float = 0.0

enum RoommateType {
	LOUD_NIGHT,              ## Reduces sleep (adjoining room / bathroom)
	THIEF,                   ## Steals money at night (hallway)
	TV_ADDICT,               ## Leaves if TV sold (living room)
	SEDUCTIVE_MANIPULATOR,   ## Your room, pay quirks
	SUSPICIOUS_FOOD_VENDOR,  ## Kitchen, cheap questionable food
	GAMBLER,                 ## Living room, gambling
	VIOLENT_NONPAYER,        ## Bathroom, violent, stops paying
	FOOD_THIEF,              ## Kitchen, steals food pellets
	BROKE,                   ## No money
	CAT_OWNER,               ## Kitchen, has a cat
	NIGERIAN_PRINCE,         ## Does not move in; investment bit (special handling later)
	FALSE_NORMAL,            ## Seems fine, hidden danger
	SNITCH,                  ## Reports you / instability
	HOT_COLD,                ## Mood swings
	USURPER_HELPER,          ## Helpful until they take your room (fail state)
	ORGAN_THIEF,             ## Medical horror
	RECURRING_VISITOR,       ## Can show up at the door more than once
}
