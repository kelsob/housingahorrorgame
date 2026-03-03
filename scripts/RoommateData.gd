extends Resource

## Data structure for a roommate. Defines type, demand, effects, and departure conditions.
## Create instances or extend for custom roommate definitions.

class_name RoommateData

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
## If true, departs when thermostat is HIGH.
@export var leaves_on_high_heat: bool = false

enum RoommateType {
	LOUD_NIGHT,           ## Reduces sleep
	THIEF,                ## Steals money at night
	TV_ADDICT,            ## Leaves if TV sold
	SEDUCTIVE_MANIPULATOR,## Risky advantage (placeholder)
	SUSPICIOUS_FOOD_VENDOR## Cheaper food, hidden downside (placeholder)
}
