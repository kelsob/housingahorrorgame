extends Control

@onready var temperature_label: Label = $TemperatureLabel
@onready var thermostat_progress: TextureProgressBar = $TextureRect/ThermostatProgress
@onready var thermostat_nub: TextureRect = $TextureRect/NubTexture
@onready var day_night_icon: TextureRect = $DayNightIcon

## Day icon (MORNING, WORK phases).
@export var day_icon: Texture2D
## Night icon (NIGHT, END phases).
@export var night_icon: Texture2D

## Format string for display. {temp} is replaced with the temperature value.
@export var display_format: String = "{temp}°"
## Color when temp is low.
@export var color_low: Color = Color(0.3, 0.6, 1.0)
## Color when temp is mid.
@export var color_mid: Color = Color(1.0, 0.9, 0.2)
## Color when temp is high.
@export var color_high: Color = Color(1.0, 0.25, 0.2)
## Temp at or below this = low (blue). Between low and high = mid (yellow).
@export var temp_threshold_low: int = 74
@export var temp_threshold_high: int = 89


func _ready() -> void:
	if not day_icon:
		day_icon = load("res://assets/icons/day-icon.png") as Texture2D
	if not night_icon:
		night_icon = load("res://assets/icons/night-icon.png") as Texture2D
	GameStateManager.phase_changed.connect(_on_phase_changed)
	_update_day_night_icon(GameStateManager.current_phase)
	ThermostatManager.thermostat_changed.connect(_on_thermostat_changed)
	_update_all(ThermostatManager.current_temp)


func _on_phase_changed(new_phase: int) -> void:
	_update_day_night_icon(new_phase)


func _on_thermostat_changed(new_temp: int) -> void:
	_update_all(new_temp)


func _update_day_night_icon(phase: int) -> void:
	if not day_night_icon:
		return
	var is_night: bool = phase == GameStateManager.Phase.NIGHT or phase == GameStateManager.Phase.END
	var tex := night_icon if is_night else day_icon
	if tex:
		day_night_icon.texture = tex


func _update_all(temp: int) -> void:
	temperature_label.text = display_format.replace("{temp}", str(temp))
	_update_progress(temp)
	_update_color(temp)


func _update_progress(temp: int) -> void:
	var min_t := ThermostatManager.min_temp
	var max_t := ThermostatManager.max_temp
	var range_t := max_t - min_t
	if range_t <= 0:
		thermostat_progress.value = 0
		return
	var t := clampf(float(temp - min_t) / float(range_t), 0.0, 1.0)
	thermostat_progress.value = t * 100.0


func _update_color(temp: int) -> void:
	var col: Color
	if temp <= temp_threshold_low:
		col = color_low
	elif temp < temp_threshold_high:
		col = color_mid
	else:
		col = color_high
	thermostat_progress.modulate = col
	thermostat_nub.modulate = col
