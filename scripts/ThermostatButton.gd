extends StaticBody3D

## Attach to thermostatButtonUp or thermostatButtonDown. Calls ThermostatManager on interact.
## true = up (increase temp), false = down (decrease temp).
@export var is_up_button: bool = true


func interact() -> void:
	if not ThermostatManager:
		return
	if is_up_button:
		ThermostatManager.increase_temp()
	else:
		ThermostatManager.decrease_temp()
