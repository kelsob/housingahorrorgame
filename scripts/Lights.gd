extends Node3D

## Iterates over child lights and sets their color based on day/night phase.
## Day: warm #ccbc8b. Night: cool #8bc4cc.

var _day_color := Color.from_string("#ccbc8b", Color.WHITE)
var _night_color := Color.from_string("#8bc4cc", Color.WHITE)


func _ready() -> void:
	GameStateManager.phase_changed.connect(_on_phase_changed)
	_apply_color_for_phase(GameStateManager.current_phase)


func _on_phase_changed(new_phase: int) -> void:
	_apply_color_for_phase(new_phase)


func _apply_color_for_phase(phase: int) -> void:
	var col := _day_color if _is_day(phase) else _night_color
	for child in get_children():
		if child is Light3D:
			child.light_color = col


func _is_day(phase: int) -> bool:
	return phase == GameStateManager.Phase.MORNING or phase == GameStateManager.Phase.WORK
