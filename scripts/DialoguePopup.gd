extends Control

## Toast: show, wait, move up, reset, hide.
## Scene:
##   DialogPopup
##   ├─ AIFaceFocus (CanvasGroup + AIFaceFocusMask.gd)
##   │  └─ AIFace
##   ├─ DialogueText
##   └─ VoiceAudioStreamPlayer (VoiceAudioStreamPlayer + AudioStreamRandomizer)
##
## Per-dialogue AIFace state comes from dialogue.json "face_state".
## Optional dialogue.json "complete_on": ["eat_pellet", ...] — task actions that
## may force-complete this toast early (sleep always can).
## Appear in rest → talk variant while speaking → back to rest → exit.

@onready var dialogue_text: RichTextLabel = $DialogueText
@onready var ai_face_focus: Node = $AIFaceFocus
@onready var ai_face: AIFace = $AIFaceFocus/AIFace
@onready var voice_player: VoiceAudioStreamPlayer = $VoiceAudioStreamPlayer

@export var voice_profile: VoiceProfile = preload("res://resources/ai_face_voice_profile.tres")
## Pause after speech finishes (fully displayed), before the float/fade exit.
@export var hold_duration: float = 1.0
@export var float_distance: float = 48.0
## Fade / float-up duration after the hold.
@export var float_duration: float = 1.0

var _tween: Tween
var _home_y: float = 0.0
var _voice_signals_bound: bool = false
var _waiting_for_voice: bool = false
var _talk_style: StringName = &"talking"
var _rest_style: StringName = &"default"
## When true, _finish must not call DialogueManager.close_dialogue (already closed).
var _suppress_close_callback: bool = false


func _ready() -> void:
	add_to_group("dialogue_ui")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bind_voice_signals()
	hide()
	DialogueManager.dialogue_closed.connect(_on_dialogue_closed)


func _bind_voice_signals() -> void:
	if _voice_signals_bound:
		return
	voice_player.saying_characters.connect(_on_voice_saying_characters)
	voice_player.finished_saying.connect(_on_voice_finished_saying)
	_voice_signals_bound = true


func _on_dialogue_closed() -> void:
	_clear()


func display(
	text: String,
	_speaker: String,
	_choices: Array,
	_disabled_choices: Array = [],
	face_state: String = "talking"
) -> void:
	_clear()
	_suppress_close_callback = false
	_resolve_face_styles(face_state)
	dialogue_text.text = text
	dialogue_text.visible_characters = 0
	dialogue_text.modulate.a = 1.0
	ai_face.expression_now(_rest_style)
	show()
	_home_y = position.y
	ai_face_focus.reset_focus()
	ai_face_focus.expand_focus()

	var open_duration: float = float(ai_face_focus.open_duration)
	_tween = create_tween()
	_tween.tween_interval(open_duration)
	_tween.tween_callback(func() -> void:
		ai_face.talk_now(_talk_style)
		_start_voice(text)
	)


func hide_dialogue() -> void:
	_clear()


## Snap text/voice to finished and start the normal fade/float exit immediately.
func force_complete_and_fade() -> void:
	if not visible:
		return
	_waiting_for_voice = false
	_stop_voice()
	dialogue_text.visible_characters = -1
	dialogue_text.modulate.a = 1.0
	ai_face.set_speech_level(0.0)
	ai_face.expression_now(_rest_style)
	ai_face.set_syllable_mouth_sync(false)
	_begin_exit(true)


## Kill tweens/voice and hide now (e.g. sleep cut-to-black). Does not notify manager.
func abort_and_hide() -> void:
	_suppress_close_callback = true
	_waiting_for_voice = false
	_clear()


func _resolve_face_styles(face_state: String) -> void:
	var state: String = face_state.strip_edges().to_lower()
	if state.is_empty():
		state = "talking"

	if state.begins_with("talking"):
		_talk_style = StringName(state)
		if state == "talking":
			_rest_style = &"default"
		else:
			_rest_style = StringName(state.trim_prefix("talking_"))
		return

	_rest_style = StringName(state)
	if state == "default":
		_talk_style = &"talking"
	else:
		_talk_style = StringName("talking_" + state)


func _start_voice(text: String) -> void:
	var emotion: StringName = _rest_style
	if emotion == &"default":
		emotion = &""
	voice_profile.apply_to(voice_player, emotion)
	ai_face.set_syllable_mouth_sync(true)
	dialogue_text.visible_characters = 0
	_waiting_for_voice = true
	voice_player.say(text)
	if voice_player.saying_words.is_empty():
		_on_voice_finished_saying()


func _stop_voice() -> void:
	_waiting_for_voice = false
	voice_player.stop_saying()
	ai_face.set_syllable_mouth_sync(false)
	ai_face.set_speech_level(0.0)


func _on_voice_saying_characters(position: int) -> void:
	ai_face.advance_mouth_for_syllable()
	dialogue_text.visible_characters = maxi(dialogue_text.visible_characters, position)


func _on_voice_finished_saying() -> void:
	dialogue_text.visible_characters = -1
	ai_face.set_speech_level(0.0)
	ai_face.expression_now(_rest_style)
	ai_face.set_syllable_mouth_sync(false)
	if not _waiting_for_voice:
		return
	_waiting_for_voice = false
	_begin_exit(false)


func _begin_exit(skip_hold: bool = false) -> void:
	if _tween:
		_tween.kill()
		_tween = null
	_tween = create_tween()
	if not skip_hold:
		_tween.tween_interval(hold_duration)
	_tween.tween_callback(func() -> void:
		ai_face_focus.shrink_focus(float_duration)
	)
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", _home_y - float_distance, float_duration)
	_tween.tween_property(dialogue_text, "modulate:a", 0.0, float_duration)
	_tween.set_parallel(false)
	_tween.tween_callback(_finish)


func _finish() -> void:
	_tween = null
	position.y = _home_y
	dialogue_text.modulate.a = 1.0
	_stop_voice()
	ai_face_focus.reset_focus()
	hide()
	if _suppress_close_callback:
		_suppress_close_callback = false
		return
	DialogueManager.close_dialogue()


func _clear() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	_stop_voice()
	dialogue_text.visible_characters = 0
	dialogue_text.modulate.a = 1.0
	if visible:
		position.y = _home_y
	ai_face_focus.reset_focus()
	_talk_style = &"talking"
	_rest_style = &"default"
	ai_face.default_now()
	hide()
