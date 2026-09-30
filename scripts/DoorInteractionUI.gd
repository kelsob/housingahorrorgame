extends Control

## Dedicated dialogue UI for door encounters.
## Scene nodes expected:
## - VBoxContainer/BodyTextPanel/MarginContainer/BodyTextLabel
## - VBoxContainer/SingleDialogChoicePanel
## - VBoxContainer/MultipleChoiceContainer/DialogChoicePanel1
## - VBoxContainer/MultipleChoiceContainer/DialogChoicePanel3

signal option_selected(choice_id: String)

@export var chars_per_second: float = 30.0
@export var sentence_pause: float = 0.3
@export var bracket_pause: float = 0.2
@export var enable_character_voice: bool = true
@export var advance_text_action: String = "door_dialogue_advance"

@onready var body_text_label: RichTextLabel = $VBoxContainer/BodyTextPanel/MarginContainer/BodyTextLabel
@onready var single_choice_panel: Node = $VBoxContainer/SingleDialogChoicePanel
@onready var multiple_choice_container: HBoxContainer = $VBoxContainer/MultipleChoiceContainer
@onready var choice_panel_1: Node = $VBoxContainer/MultipleChoiceContainer/DialogChoicePanel1
@onready var choice_panel_2: Node = $VBoxContainer/MultipleChoiceContainer/DialogChoicePanel3
@onready var voice_player: VoiceAudioStreamPlayer = get_node_or_null("AudioStreamPlayer") as VoiceAudioStreamPlayer

var _typewriter_cycle: int = 0
var _skip_requested: bool = false
var _is_typing: bool = false
var _pending_choices: Array = []
var _pending_disabled_choices: Array = []
var _voice_letter_streams: Dictionary = {}
var _voice_profile: Dictionary = {}
var _voice_stream_warning_sent: bool = false


func _ready() -> void:
	hide()
	if single_choice_panel and single_choice_panel.has_signal("option_selected"):
		single_choice_panel.option_selected.connect(_on_panel_option_selected)
	if choice_panel_1 and choice_panel_1.has_signal("option_selected"):
		choice_panel_1.option_selected.connect(_on_panel_option_selected)
	if choice_panel_2 and choice_panel_2.has_signal("option_selected"):
		choice_panel_2.option_selected.connect(_on_panel_option_selected)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _is_typing:
		return
	if event is InputEventMouseButton and event.pressed:
		_skip_requested = true
		get_viewport().set_input_as_handled()
		return
	if event is InputEventAction and event.pressed and InputMap.has_action(advance_text_action):
		var action_event: InputEventAction = event
		if action_event.action == advance_text_action:
			_skip_requested = true
			get_viewport().set_input_as_handled()


func set_character_voice_profile(profile: Dictionary) -> void:
	_voice_profile = profile.duplicate(true)


func display(text: String, _speaker: String, choices: Array, disabled_choices: Array = []) -> void:
	_pending_choices = choices.duplicate(true)
	_pending_disabled_choices = disabled_choices.duplicate(true)
	_typewriter_cycle += 1
	_skip_requested = false
	_is_typing = true
	_voice_letter_streams.clear()
	_apply_voice_profile()
	if body_text_label:
		body_text_label.text = ""
	if single_choice_panel:
		single_choice_panel.hide()
	if multiple_choice_container:
		multiple_choice_container.hide()
	show()
	call_deferred("_run_typewriter", text, _typewriter_cycle)


func hide_dialogue() -> void:
	_typewriter_cycle += 1
	_is_typing = false
	_skip_requested = false
	hide()


func _run_typewriter(full_text: String, cycle_id: int) -> void:
	var chars_to_show: int = 0
	var total_chars: int = full_text.length()
	var speed: float = max(chars_per_second, 0.001)
	var interval: float = 1.0 / speed
	while chars_to_show < total_chars:
		if cycle_id != _typewriter_cycle:
			return
		if _skip_requested:
			_skip_requested = false
			var next_break := full_text.find("\n", chars_to_show)
			if next_break >= 0:
				chars_to_show = next_break + 1
			else:
				chars_to_show = total_chars
			if body_text_label:
				body_text_label.text = full_text.substr(0, chars_to_show)
			continue
		chars_to_show += 1
		var visible: String = full_text.substr(0, chars_to_show)
		if body_text_label:
			body_text_label.text = visible
		var ch: String = full_text.substr(chars_to_show - 1, 1)
		if _character_voice_usable():
			_play_voice_blip_for_char(ch)
		await get_tree().create_timer(interval).timeout
		if cycle_id != _typewriter_cycle:
			return
		if ch in ".!?":
			await get_tree().create_timer(sentence_pause).timeout
			if cycle_id != _typewriter_cycle:
				return
		elif visible.ends_with("[ONE]") or visible.ends_with("[DAYS]"):
			await get_tree().create_timer(bracket_pause).timeout
			if cycle_id != _typewriter_cycle:
				return
	_is_typing = false
	_show_choices_after_typewriter()


func _show_choices_after_typewriter() -> void:
	var choices: Array = _pending_choices
	var disabled_choices: Array = _pending_disabled_choices
	if choices.size() <= 1:
		_show_single_choice(choices, disabled_choices)
	else:
		_show_multiple_choices(choices, disabled_choices)


func _show_single_choice(choices: Array, disabled_choices: Array) -> void:
	if single_choice_panel:
		single_choice_panel.show()
	if multiple_choice_container:
		multiple_choice_container.hide()
	var choice_text: String = "Continue"
	var choice_id: String = "continue"
	if choices.size() == 1:
		var c: Dictionary = choices[0]
		choice_text = str(c.get("text", "Continue"))
		choice_id = str(c.get("id", "continue"))
	var disabled: bool = choice_id in disabled_choices
	if single_choice_panel and single_choice_panel.has_method("setup"):
		single_choice_panel.setup(choice_text, choice_id, disabled)


func _show_multiple_choices(choices: Array, disabled_choices: Array) -> void:
	if single_choice_panel:
		single_choice_panel.hide()
	if multiple_choice_container:
		multiple_choice_container.show()
	var c1: Dictionary = choices[0]
	var c2: Dictionary = choices[1]
	var id1: String = str(c1.get("id", "choice_1"))
	var id2: String = str(c2.get("id", "choice_2"))
	if choice_panel_1 and choice_panel_1.has_method("setup"):
		choice_panel_1.setup(str(c1.get("text", "Choice 1")), id1, id1 in disabled_choices)
	if choice_panel_2 and choice_panel_2.has_method("setup"):
		choice_panel_2.setup(str(c2.get("text", "Choice 2")), id2, id2 in disabled_choices)


func _on_panel_option_selected(choice_id: String) -> void:
	option_selected.emit(choice_id)


func _apply_voice_profile() -> void:
	if voice_player == null:
		return
	var main_pitch: float = float(_voice_profile.get("main_pitch_scale", 1.0))
	var random_pitch: float = float(_voice_profile.get("random_pitch", 1.0))
	var random_volume_offset: float = float(_voice_profile.get("random_volume_offset_db", 0.0))
	voice_player.main_pitch_scale = main_pitch
	voice_player.random_pitch = random_pitch
	voice_player.random_volume_offset_db = random_volume_offset


func _character_voice_usable() -> bool:
	if not enable_character_voice:
		return false
	if not bool(_voice_profile.get("enabled", true)):
		return false
	if voice_player == null:
		return false
	var st: Variant = voice_player.stream
	if st == null or not (st is AudioStreamRandomizer):
		if not _voice_stream_warning_sent:
			_voice_stream_warning_sent = true
			push_warning(
				"DoorInteractionUI: assign AudioStreamPlayer as VoiceAudioStreamPlayer with AudioStreamRandomizer stream 0."
			)
		return false
	return true


func _play_voice_blip_for_char(ch: String) -> void:
	if ch.length() != 1:
		return
	_ensure_voice_letter_streams()
	var key: String = ch.to_lower()
	var stream: Variant = _voice_letter_streams.get(key)
	if stream == null:
		stream = _voice_letter_streams.get("default")
	if stream == null:
		return
	voice_player.set_sub_stream(stream as AudioStream)
	voice_player.play()


func _ensure_voice_letter_streams() -> void:
	if not _voice_letter_streams.is_empty():
		return
	var pitch: String = str(_voice_profile.get("alphabet_pitch", "med")).strip_edges()
	if pitch.is_empty():
		pitch = "med"
	_voice_letter_streams = _build_alphabet_mapping(pitch)


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
