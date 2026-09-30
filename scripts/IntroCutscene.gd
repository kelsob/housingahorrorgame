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

## When enabled and [member intro_voice_player] is set, plays alphabet blips while the typewriter runs.
## Text speed is always [member chars_per_second] (and your sentence/bracket pauses); each new letter
## restarts audio on the same player so clips are cut short instead of waiting for full WAVs like [method VoiceAudioStreamPlayer.say] does.
## The node must use an [AudioStreamRandomizer] as [member AudioStreamPlayer.stream] with stream 0 (see example scene).
@export var enable_intro_voice: bool = true
@onready var intro_voice_player: VoiceAudioStreamPlayer = $AudioStreamPlayer
## Subfolder under [code]res://addons/godot-voice-generator/sound/alphabet/[/code]: [code]high[/code], [code]med[/code], [code]low[/code], [code]lowest[/code].
@export var intro_voice_alphabet_pitch: String = "med"

## Emitted when all text has been displayed.
signal text_fully_displayed

const GAME_SCENE_PATH := "res://scenes/Game.tscn"

@onready var fade_rect: ColorRect = $FadeOverlay/ColorRect
@onready var letter_label: RichTextLabel = $PanelContainer/MarginContainer/LetterLabel
@onready var letter_panel: PanelContainer = $PanelContainer

var _skip_requested := false
var _text_complete := false
var _continue_requested := false
## Letter -> [AudioStream], built when intro voice is first used.
var _intro_voice_letter_streams: Dictionary = {}


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
	_intro_voice_letter_streams.clear()
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
		var ch: String = letter_text.substr(chars_to_show - 1, 1)
		if _intro_voice_usable():
			_play_intro_voice_blip_for_char(ch)
		await get_tree().create_timer(interval).timeout
		if ch in ".!?":
			await get_tree().create_timer(sentence_pause).timeout
		else:
			var visible := letter_text.substr(0, chars_to_show)
			if visible.ends_with("[ONE]") or visible.ends_with("[DAYS]"):
				await get_tree().create_timer(bracket_pause).timeout


func _intro_voice_usable() -> bool:
	if not enable_intro_voice or intro_voice_player == null:
		return false
	var st: Variant = intro_voice_player.stream
	if st == null or not (st is AudioStreamRandomizer):
		push_warning(
			"IntroCutscene: assign intro_voice_player and set its Stream to AudioStreamRandomizer (stream 0), like example_scene.tscn. Falling back to typewriter."
		)
		return false
	return true


func _ensure_intro_voice_letter_streams() -> void:
	if not _intro_voice_letter_streams.is_empty():
		return
	_intro_voice_letter_streams = _build_alphabet_mapping(intro_voice_alphabet_pitch)


func _play_intro_voice_blip_for_char(ch: String) -> void:
	if ch.length() != 1:
		return
	_ensure_intro_voice_letter_streams()
	var key: String = ch.to_lower()
	var stream: Variant = _intro_voice_letter_streams.get(key)
	if stream == null:
		stream = _intro_voice_letter_streams.get("default")
	if stream == null:
		return
	intro_voice_player.set_sub_stream(stream as AudioStream)
	intro_voice_player.play()


func _build_alphabet_mapping(pitch: String) -> Dictionary:
	var base: String = "res://addons/godot-voice-generator/sound/alphabet/%s/" % pitch
	return {
		"default": load(base + "a.wav") as AudioStream,
		"a": load(base + "a.wav") as AudioStream,
		"b": load(base + "b.wav") as AudioStream,
		"c": load(base + "c.wav") as AudioStream,
		"d": load(base + "d.wav") as AudioStream,
		"e": load(base + "e.wav") as AudioStream,
		"f": load(base + "f.wav") as AudioStream,
		"g": load(base + "g.wav") as AudioStream,
		"h": load(base + "h.wav") as AudioStream,
		"i": load(base + "i.wav") as AudioStream,
		"j": load(base + "j.wav") as AudioStream,
		"k": load(base + "k.wav") as AudioStream,
		"l": load(base + "l.wav") as AudioStream,
		"m": load(base + "m.wav") as AudioStream,
		"n": load(base + "n.wav") as AudioStream,
		"o": load(base + "o.wav") as AudioStream,
		"p": load(base + "p.wav") as AudioStream,
		"q": load(base + "q.wav") as AudioStream,
		"r": load(base + "r.wav") as AudioStream,
		"s": load(base + "s.wav") as AudioStream,
		"t": load(base + "t.wav") as AudioStream,
		"u": load(base + "u.wav") as AudioStream,
		"v": load(base + "v.wav") as AudioStream,
		"w": load(base + "w.wav") as AudioStream,
		"x": load(base + "x.wav") as AudioStream,
		"y": load(base + "y.wav") as AudioStream,
		"z": load(base + "z.wav") as AudioStream,
	}
