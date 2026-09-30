extends Control

## Quick harness for AIFace talk / emotion / gesture testing.
##
## Build scenes/AIFaceTalkTest.tscn as:
##   AIFaceTalkTest (Control)                 <- this script
##   ├─ Stage (Control)
##   │  ├─ AIFace (instance of AIFace.tscn)   <- unmasked (mask Off, default)
##   │  └─ AIFaceFocus (CanvasGroup)          <- AIFaceFocusMask.gd
##   │     └─ AIFace (instance of AIFace.tscn)<- masked (mask On)
##   ├─ PreviewText (RichTextLabel)
##   ├─ VoiceAudioStreamPlayer                <- VoiceAudioStreamPlayer + AudioStreamRandomizer stream
##   └─ Panel (PanelContainer)
##      └─ VBox (VBoxContainer)
##         ├─ DialogueInput (TextEdit)
##         ├─ EmotionOption (OptionButton)
##         ├─ PoseOption (OptionButton)
##         ├─ SpeakRow (HBoxContainer)
##         │  ├─ SpeakButton / StopButton
##         ├─ FaceMaskRow (HBoxContainer)
##         │  ├─ OnButton (Button)            <- use masked face
##         │  └─ OffButton (Button)           <- use unmasked face (default)
##         └─ GestureRow (HBoxContainer)
##            ├─ WaveButton / FlapButton
##
## Run this scene directly (F6). Mouse should stay visible for UI.

@onready var ai_face_focus: CanvasGroup = $Stage/AIFaceFocus
@onready var ai_face_masked: AIFace = $Stage/AIFaceFocus/AIFace
@onready var ai_face_unmasked: AIFace = $Stage/AIFace
@onready var preview_text: RichTextLabel = $PreviewText
@onready var voice_player: VoiceAudioStreamPlayer = $VoiceAudioStreamPlayer
@onready var dialogue_input: TextEdit = $Panel/VBox/DialogueInput
@onready var emotion_option: OptionButton = $Panel/VBox/EmotionOption
@onready var pose_option: OptionButton = $Panel/VBox/PoseOption
@onready var speak_button: Button = $Panel/VBox/SpeakRow/SpeakButton
@onready var stop_button: Button = $Panel/VBox/SpeakRow/StopButton
@onready var mask_on_button: Button = $Panel/VBox/FaceMaskRow/OnButton
@onready var mask_off_button: Button = $Panel/VBox/FaceMaskRow/OffButton
@onready var wave_button: Button = $Panel/VBox/GestureRow/WaveButton
@onready var flap_button: Button = $Panel/VBox/GestureRow/FlapButton

@export var voice_profile: VoiceProfile = preload("res://resources/ai_face_voice_profile.tres")

## Speak-style dropdown: label -> talk anim name.
const EMOTION_OPTIONS: Array[Dictionary] = [
	{"label": "talking (calm)", "talk": "talking"},
	{"label": "talking_angry", "talk": "talking_angry"},
	{"label": "talking_agitated", "talk": "talking_agitated"},
]

## Pose dropdown: label -> expression state (spin is a one-shot).
const POSE_OPTIONS: Array[Dictionary] = [
	{"label": "default", "state": "default"},
	{"label": "angry", "state": "angry"},
	{"label": "agitated", "state": "agitated"},
	{"label": "surprised", "state": "surprised"},
	{"label": "holdingbacktears", "state": "holdingbacktears"},
	{"label": "spin", "state": "spin"},
]

var ai_face: AIFace
var _mask_enabled: bool = false
var _voice_signals_bound: bool = false
var _speaking: bool = false
var _syncing_options: bool = false
var _talk_style: StringName = &"talking"
var _rest_style: StringName = &"default"


func _ready() -> void:
	_bind_voice_signals()
	_populate_emotion_options()
	_populate_pose_options()
	_bind_ui()
	preview_text.text = ""
	preview_text.visible_characters = 0
	if dialogue_input.text.strip_edges().is_empty():
		dialogue_input.text = "Welcome to your new home! Take a good look around."
	_set_mask_enabled(false)
	ai_face.expression_now(_rest_style)


func _bind_voice_signals() -> void:
	if _voice_signals_bound:
		return
	voice_player.saying_characters.connect(_on_voice_saying_characters)
	voice_player.finished_saying.connect(_on_voice_finished_saying)
	_voice_signals_bound = true


func _populate_emotion_options() -> void:
	emotion_option.clear()
	for entry: Dictionary in EMOTION_OPTIONS:
		emotion_option.add_item(str(entry["label"]))
	emotion_option.select(0)
	_resolve_styles_from_emotion_option()


func _populate_pose_options() -> void:
	pose_option.clear()
	for entry: Dictionary in POSE_OPTIONS:
		pose_option.add_item(str(entry["label"]))
	pose_option.select(0)


func _bind_ui() -> void:
	speak_button.pressed.connect(_on_speak_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	emotion_option.item_selected.connect(_on_emotion_selected)
	pose_option.item_selected.connect(_on_pose_selected)
	mask_on_button.pressed.connect(func() -> void: _set_mask_enabled(true))
	mask_off_button.pressed.connect(func() -> void: _set_mask_enabled(false))
	wave_button.pressed.connect(func() -> void: ai_face.wave_now())
	flap_button.pressed.connect(func() -> void: ai_face.flap_now())


func _set_mask_enabled(enabled: bool) -> void:
	if ai_face != null:
		_stop_speech(false)
	_mask_enabled = enabled
	if enabled:
		ai_face_unmasked.visible = false
		ai_face_focus.visible = true
		ai_face = ai_face_masked
		ai_face_focus.reset_focus()
		ai_face_focus.expand_focus()
	else:
		ai_face_focus.reset_focus()
		ai_face_focus.visible = false
		ai_face_unmasked.visible = true
		ai_face = ai_face_unmasked
	ai_face.expression_now(_rest_style)


func _on_emotion_selected(_index: int) -> void:
	if _syncing_options:
		return
	_resolve_styles_from_emotion_option()
	_sync_pose_option_to_rest()
	_stop_speech(false)
	ai_face.expression_now(_rest_style)


func _on_pose_selected(_index: int) -> void:
	if _syncing_options:
		return
	var state: StringName = _pose_state_from_option()
	_stop_speech(false)
	if state == &"spin":
		ai_face.spin_now()
		return
	_rest_style = state
	ai_face.expression_now(state)
	match state:
		&"angry":
			_talk_style = &"talking_angry"
			_select_emotion_by_talk(_talk_style)
		&"agitated":
			_talk_style = &"talking_agitated"
			_select_emotion_by_talk(_talk_style)
		&"default":
			_talk_style = &"talking"
			_select_emotion_by_talk(_talk_style)


func _resolve_styles_from_emotion_option() -> void:
	var idx: int = emotion_option.selected
	if idx < 0 or idx >= EMOTION_OPTIONS.size():
		idx = 0
	var talk: String = str(EMOTION_OPTIONS[idx]["talk"])
	_talk_style = StringName(talk)
	if talk == "talking":
		_rest_style = &"default"
	else:
		_rest_style = StringName(talk.trim_prefix("talking_"))


func _pose_state_from_option() -> StringName:
	var idx: int = pose_option.selected
	if idx < 0 or idx >= POSE_OPTIONS.size():
		idx = 0
	return StringName(str(POSE_OPTIONS[idx]["state"]))


func _sync_pose_option_to_rest() -> void:
	for i: int in POSE_OPTIONS.size():
		if str(POSE_OPTIONS[i]["state"]) == String(_rest_style):
			_syncing_options = true
			pose_option.select(i)
			_syncing_options = false
			return


func _select_emotion_by_talk(talk: StringName) -> void:
	for i: int in EMOTION_OPTIONS.size():
		if str(EMOTION_OPTIONS[i]["talk"]) == String(talk):
			_syncing_options = true
			emotion_option.select(i)
			_syncing_options = false
			return


func _on_speak_pressed() -> void:
	_resolve_styles_from_emotion_option()
	var text: String = dialogue_input.text.strip_edges()
	if text.is_empty():
		return
	_stop_speech(false)
	preview_text.text = text
	preview_text.visible_characters = 0
	ai_face.expression_now(_rest_style)
	ai_face.talk_now(_talk_style)
	_start_voice(text)


func _on_stop_pressed() -> void:
	_stop_speech(true)


func _start_voice(text: String) -> void:
	var emotion: StringName = _rest_style
	if emotion == &"default":
		emotion = &""
	voice_profile.apply_to(voice_player, emotion)
	ai_face.set_syllable_mouth_sync(true)
	_speaking = true
	voice_player.say(text)
	if voice_player.saying_words.is_empty():
		_on_voice_finished_saying()


func _stop_speech(return_to_rest: bool) -> void:
	_speaking = false
	voice_player.stop_saying()
	if ai_face == null:
		return
	ai_face.set_syllable_mouth_sync(false)
	ai_face.set_speech_level(0.0)
	if return_to_rest:
		ai_face.expression_now(_rest_style)


func _on_voice_saying_characters(position: int) -> void:
	ai_face.advance_mouth_for_syllable()
	preview_text.visible_characters = maxi(preview_text.visible_characters, position)


func _on_voice_finished_saying() -> void:
	preview_text.visible_characters = -1
	ai_face.set_speech_level(0.0)
	ai_face.set_syllable_mouth_sync(false)
	if not _speaking:
		return
	_speaking = false
	ai_face.expression_now(_rest_style)
