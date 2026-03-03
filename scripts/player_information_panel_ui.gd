extends Control

## Player display (tweak in inspector or set via code).
@export var player_name: String = "Ben Kelso"
@export var player_id: String = "#45832769"

## Currency symbol for Atlas balance/rent display.
@export var currency_symbol: String = "A"

@onready var player_id_label: Label = $VBoxContainer/HBoxContainer/PlayerIDNumberLabel
@onready var player_name_label: Label = $VBoxContainer/HBoxContainer/PlayerNameLabel
@onready var current_date_label: Label = $VBoxContainer/HBoxContainer2/CurrentDateLabel
@onready var citizen_score_label: Label = $VBoxContainer/MarginContainer/HBoxContainer/CitizenScoreLabel
@onready var currency_balance_label: Label = $VBoxContainer/MarginContainer/HBoxContainer/BalanceLabel
@onready var rent_due_label: Label = $VBoxContainer/MarginContainer2/HBoxContainer/RentDueLabel
@onready var pay_rent_button: Button = $VBoxContainer/MarginContainer2/HBoxContainer/PayRentButton
@onready var current_energy_label: Label = $VBoxContainer/MarginContainer3/HBoxContainer/CurrentEnergyLabel
@onready var max_energy_label: Label = $VBoxContainer/MarginContainer3/HBoxContainer/MaxEnergyLabel
@onready var strikes_container: MarginContainer = $VBoxContainer/MarginContainer4
@onready var strikes_label: Label = $VBoxContainer/MarginContainer4/HBoxContainer/StrikesLabel
@onready var prime_plus_citizen_button: Button = $VBoxContainer/PrimePlusCitizenButton


func _ready() -> void:
	_update_player_info()
	_update_date()
	_update_balance()
	_update_rent()
	_update_energy()
	_update_pay_rent_button()

	MoneyManager.money_changed.connect(_on_money_changed)
	EnergyManager.energy_changed.connect(_on_energy_changed)
	GameStateManager.day_changed.connect(_on_day_changed)
	GameStateManager.phase_changed.connect(_on_phase_changed)

	pay_rent_button.pressed.connect(_on_pay_rent_pressed)


func _on_money_changed(_new: float, _prev: float) -> void:
	_update_balance()
	_update_pay_rent_button()


func _on_energy_changed(_new: int, _prev: int) -> void:
	_update_energy()


func _on_day_changed(_new_day: int) -> void:
	_update_date()
	_update_rent()
	_update_pay_rent_button()


func _on_phase_changed(_new_phase: int) -> void:
	_update_date()
	_update_rent()
	_update_pay_rent_button()


func _on_pay_rent_pressed() -> void:
	GameStateManager.pay_rent()
	_update_balance()
	_update_rent()
	_update_pay_rent_button()


func _update_player_info() -> void:
	player_id_label.text = player_id
	player_name_label.text = player_name


func _update_date() -> void:
	var day := GameStateManager.current_day
	var phase_name := _phase_name(GameStateManager.current_phase)
	current_date_label.text = "Day %d - %s" % [day, phase_name]


func _phase_name(phase: int) -> String:
	match phase:
		GameStateManager.Phase.MORNING: return "Morning"
		GameStateManager.Phase.WORK: return "Work"
		GameStateManager.Phase.NIGHT: return "Night"
		GameStateManager.Phase.END: return "End"
	return "—"


func _update_balance() -> void:
	currency_balance_label.text = "%.2f %s" % [MoneyManager.current_money, currency_symbol]


func _update_rent() -> void:
	rent_due_label.text = "%d %s" % [GameStateManager.current_rent, currency_symbol]


func _update_energy() -> void:
	current_energy_label.text = str(EnergyManager.current_energy)
	max_energy_label.text = str(EnergyManager.max_energy)


func _update_pay_rent_button() -> void:
	var paid := GameStateManager.rent_paid_today
	var can_afford := MoneyManager.can_afford(GameStateManager.current_rent)
	pay_rent_button.disabled = paid or not can_afford
	if paid:
		pay_rent_button.text = "PAID"
	else:
		pay_rent_button.text = "PAY NOW"
