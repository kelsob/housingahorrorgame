extends Control

@onready var currency_label: Label = $CurrencyContainer/MarginContainer/HBoxContainer/CurrencyLabel
@onready var current_energy_label: Label = $EnergyContainer/MarginContainer/HBoxContainer/CurrentEnergyLabel
@onready var max_energy_label: Label = $EnergyContainer/MarginContainer/HBoxContainer/MaxEnergyLabel
@onready var current_day_label: Label = $DayContainer/MarginContainer/HBoxContainer/CurrentDayLabel
@onready var dialog_popup: Control = $DialogPopup

func _ready() -> void:
	if dialog_popup and dialog_popup.has_method("display"):
		DialogueManager.register_ui(dialog_popup)
	EnergyManager.energy_changed.connect(_on_energy_changed)
	_update_energy()
	MoneyManager.money_changed.connect(_on_money_changed)
	_update_currency()
	GameStateManager.day_changed.connect(_on_day_changed)
	_update_day()


func _on_energy_changed(_new_value: int, _prev_value: int) -> void:
	_update_energy()


func _on_money_changed(_new_value: float, _prev_value: float) -> void:
	_update_currency()


func _on_day_changed(_new_day: int) -> void:
	_update_day()


func _update_energy() -> void:
	current_energy_label.text = str(EnergyManager.current_energy)
	max_energy_label.text = str(EnergyManager.max_energy)


func _update_currency() -> void:
	currency_label.text = "%.2f" % MoneyManager.current_money


func _update_day() -> void:
	current_day_label.text = str(GameStateManager.current_day)
