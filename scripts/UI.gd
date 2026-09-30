extends Control

@onready var currency_label: Label = $TopBar/CurrencyContainer/CurrencyLabel
@onready var current_energy_label: Label = $TopBar/EnergyContainer/CurrentEnergyLabel
@onready var max_energy_label: Label = $TopBar/EnergyContainer/MaxEnergyLabel
@onready var current_day_label: Label = $TopBar/DateTimeContainer/CurrentDayLabel
@onready var time_label: Label = $TopBar/DateTimeContainer/TimeLabel
@onready var dialog_popup: Control = $DialogPopup
@onready var crosshair: CanvasItem = $Crosshair

const PHASE_TIME_TEXT := {
	GameStateManager.Phase.MORNING: "Morning",
	GameStateManager.Phase.WORK: "Evening",
	GameStateManager.Phase.NIGHT: "Night",
	GameStateManager.Phase.END: "End",
}


func _ready() -> void:
	# Safety guard: if UI scene instance is hidden in Game.tscn, dialogue still needs to render.
	visible = true
	crosshair.visible = true
	DialogueManager.register_ui(dialog_popup)
	EnergyManager.energy_changed.connect(_on_energy_changed)
	_update_energy()
	MoneyManager.money_changed.connect(_on_money_changed)
	_update_currency()
	GameStateManager.day_changed.connect(_on_day_changed)
	GameStateManager.phase_changed.connect(_on_phase_changed)
	_update_day()
	_update_time()


func set_crosshair_visible(is_visible: bool) -> void:
	crosshair.visible = is_visible


func _on_energy_changed(_new_value: int, _prev_value: int) -> void:
	_update_energy()


func _on_money_changed(_new_value: float, _prev_value: float) -> void:
	_update_currency()


func _on_day_changed(_new_day: int) -> void:
	_update_day()


func _on_phase_changed(_new_phase: int) -> void:
	_update_time()


func _update_energy() -> void:
	current_energy_label.text = str(EnergyManager.current_energy)
	max_energy_label.text = str(EnergyManager.max_energy)


func _update_currency() -> void:
	currency_label.text = "%.2f" % MoneyManager.current_money


func _update_day() -> void:
	current_day_label.text = str(GameStateManager.current_day)


func _update_time() -> void:
	time_label.text = PHASE_TIME_TEXT[GameStateManager.current_phase]
