extends Node

## Furniture ownership and selling. Bed, Couch, TV, Fridge. Emits on sell for roommate reactions.
## Add as autoload (Project → Project Settings → Autoload) for global access.

# -----------------------------------------------------------------------------
# Configurable properties (tweak at top for easy balance)
# -----------------------------------------------------------------------------

enum Type {
	BED,
	COUCH,
	TV,
	FRIDGE
}

## Sell price per furniture type. Index matches Type enum.
@export var sell_prices: Array[int] = [80, 50, 120, 150]

# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------

var _owned: Dictionary = {}

## Emitted when furniture is sold. Passes furniture type. Roommates can react.
signal furniture_sold(furniture_type: Type)


func _ready() -> void:
	_owned[Type.BED] = true
	_owned[Type.COUCH] = true
	_owned[Type.TV] = true
	_owned[Type.FRIDGE] = true


## Check if the player owns a furniture type.
func is_owned(furniture_type: Type) -> bool:
	return _owned.get(furniture_type, true)


## Sell furniture. Returns true if successful. Emits furniture_sold for roommate hook.
func sell(furniture_type: Type) -> bool:
	if not is_owned(furniture_type):
		return false
	_owned[furniture_type] = false
	var price := get_sell_price(furniture_type)
	MoneyManager.add(price)
	furniture_sold.emit(furniture_type)
	return true


## Get the sell price for a furniture type.
func get_sell_price(furniture_type: Type) -> int:
	var idx := int(furniture_type)
	if idx >= 0 and idx < sell_prices.size():
		return sell_prices[idx]
	return 0


## Start a new game. Resets all furniture to owned.
func start_new_game() -> void:
	_owned[Type.BED] = true
	_owned[Type.COUCH] = true
	_owned[Type.TV] = true
	_owned[Type.FRIDGE] = true
