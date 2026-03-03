extends Control

## Intro cutscene: fade from black, letter text animating character-by-character.

## Full letter text to animate. Shown character-by-character.
@export_multiline var letter_text: String = "Dear Resident,\n\nWelcome to your new home."
## Pause after fade-in, before text starts (seconds).
@export var text_start_delay: float = 1.5
## Characters per second for the typewriter effect.
@export var chars_per_second: float = 30.0
## Extra pause at end of sentence (. ! ?).
@export var sentence_pause: float = 0.3
## Brief pause after [ONE] and [DAYS] in the text.
@export var bracket_pause: float = 0.4

## Emitted when all text has been displayed.
signal text_fully_displayed

const GAME_SCENE_PATH := "res://scenes/Game.tscn"

@onready var fade_rect: ColorRect = $FadeOverlay/ColorRect
@onready var letter_label: RichTextLabel = $PanelContainer/MarginContainer/LetterLabel
@onready var letter_panel: PanelContainer = $PanelContainer

var _skip_requested := false
var _text_complete := false
var _continue_requested := false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _text_complete:
			_continue_requested = true
		else:
			_skip_requested = true
		get_viewport().set_input_as_handled()


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	letter_label.text = ""
	fade_rect.color = Color.BLACK
	var tween := create_tween()
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0), 0.5)
	await tween.finished
	await get_tree().create_timer(text_start_delay).timeout
	letter_panel.show()
	await _run_typewriter()
	text_fully_displayed.emit()
	_text_complete = true
	while not _continue_requested:
		await get_tree().process_frame
	var fade_out := create_tween()
	fade_out.tween_property(fade_rect, "color", Color.BLACK, 0.5)
	await fade_out.finished
	GameStateManager.start_new_game()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _run_typewriter() -> void:
	var chars_to_show := 0
	var total_chars := letter_text.length()
	var interval := 1.0 / chars_per_second
	while chars_to_show < total_chars:
		if _skip_requested:
			_skip_requested = false
			var next_break := letter_text.find("\n", chars_to_show)
			if next_break >= 0:
				chars_to_show = next_break + 1
			else:
				chars_to_show = total_chars
			letter_label.text = letter_text.substr(0, chars_to_show)
			continue
		chars_to_show += 1
		letter_label.text = letter_text.substr(0, chars_to_show)
		await get_tree().create_timer(interval).timeout
		var ch := letter_text[chars_to_show - 1]
		if ch in ".!?":
			await get_tree().create_timer(sentence_pause).timeout
		else:
			var visible := letter_text.substr(0, chars_to_show)
			if visible.ends_with("[ONE]") or visible.ends_with("[DAYS]"):
				await get_tree().create_timer(bracket_pause).timeout
