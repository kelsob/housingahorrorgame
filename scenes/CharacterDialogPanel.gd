extends NinePatchRect

@onready var visitor_dialog_label: RichTextLabel = $MarginContainer/VBoxContainer/CharacterDialogLabel
@onready var response_option_panel_1: NinePatchRect = $MarginContainer/VBoxContainer/HBoxContainer/NinePatchRect
@onready var response_option_panel_2: NinePatchRect = $MarginContainer/VBoxContainer/HBoxContainer/NinePatchRect2
@onready var player_response_label_1: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer/NinePatchRect/ResponseOptionLabel
@onready var player_response_label_2: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer/NinePatchRect2/ResponseOptionLabel
@onready var player_response_button_1: Button = $MarginContainer/VBoxContainer/HBoxContainer/NinePatchRect/Button
@onready var player_response_button_2: Button = $MarginContainer/VBoxContainer/HBoxContainer/NinePatchRect2/Button
@onready var voice_player: VoiceAudioStreamPlayer = get_node_or_null("AudioStreamPlayer") as VoiceAudioStreamPlayer

signal response_selected(choice_id: String)

@export var chars_per_second: float = 30.0
@export var sentence_pause: float = 0.3
@export var comma_pause: float = 0.15
@export var bracket_pause: float = 0.2
@export var enable_character_voice: bool = true
@export var default_voice_enabled: bool = true
@export var default_voice_alphabet_pitch: String = "med"
@export var default_voice_main_pitch_scale: float = 1.0
@export var default_voice_random_pitch: float = 1.0
@export var default_voice_random_volume_offset_db: float = 0.0
@export var hover_tween_seconds: float = 0.08
@export_range(1.0, 1.2, 0.01) var hover_scale_multiplier: float = 1.04
@export var response_normal_modulate: Color = Color(1, 1, 1, 1)
@export var response_hover_modulate: Color = Color(1.15, 1.15, 1.15, 1)
@export var debug_hover: bool = false
@export var auto_continue_on_empty_choices: bool = false

var _choice_id_1: String = ""
var _choice_id_2: String = ""
var _pending_choices: Array = []
var _typewriter_cycle: int = 0
var _skip_requested: bool = false
var _is_typing: bool = false
var _voice_letter_streams: Dictionary = {}
var _voice_profile: Dictionary = {}
var _voice_stream_warning_sent: bool = false
var _response_panel_base_scale_1: Vector2 = Vector2.ONE
var _response_panel_base_scale_2: Vector2 = Vector2.ONE
var _hover_tween_1: Tween = null
var _hover_tween_2: Tween = null
var _current_hover_slot: int = 0


func _ready() -> void:
	hide()
	_response_panel_base_scale_1 = response_option_panel_1.scale
	_response_panel_base_scale_2 = response_option_panel_2.scale
	if not player_response_button_1.pressed.is_connected(_on_response_button_1_pressed):
		player_response_button_1.pressed.connect(_on_response_button_1_pressed)
	if not player_response_button_2.pressed.is_connected(_on_response_button_2_pressed):
		player_response_button_2.pressed.connect(_on_response_button_2_pressed)
	if not player_response_button_1.mouse_entered.is_connected(_on_response_button_1_mouse_entered):
		player_response_button_1.mouse_entered.connect(_on_response_button_1_mouse_entered)
	if not player_response_button_1.mouse_exited.is_connected(_on_response_button_1_mouse_exited):
		player_response_button_1.mouse_exited.connect(_on_response_button_1_mouse_exited)
	if not player_response_button_2.mouse_entered.is_connected(_on_response_button_2_mouse_entered):
		player_response_button_2.mouse_entered.connect(_on_response_button_2_mouse_entered)
	if not player_response_button_2.mouse_exited.is_connected(_on_response_button_2_mouse_exited):
		player_response_button_2.mouse_exited.connect(_on_response_button_2_mouse_exited)
	_apply_hover_visual_state(1, false, false)
	_apply_hover_visual_state(2, false, false)
	_reset_voice_profile_to_defaults()


func display_dialogue(text: String, choices: Array, speaker: String = "") -> void:
	_pending_choices = choices.duplicate(true)
	_typewriter_cycle += 1
	_skip_requested = false
	_is_typing = true
	_voice_letter_streams.clear()
	_apply_voice_profile()
	var full_text: String = text
	var speaker_name: String = speaker.strip_edges()
	if not speaker_name.is_empty():
		full_text = "[center][b]%s[/b][/center]\n%s" % [speaker_name, text]
	visitor_dialog_label.text = ""
	_set_button_slot(1, {})
	_set_button_slot(2, {})
	show()
	call_deferred("_run_typewriter", full_text, _typewriter_cycle)


func hide_dialogue() -> void:
	_typewriter_cycle += 1
	_is_typing = false
	_skip_requested = false
	_voice_letter_streams.clear()
	_current_hover_slot = 0
	_apply_hover_visual_state(1, false, false)
	_apply_hover_visual_state(2, false, false)
	hide()


func _apply_choices(choices: Array) -> void:
	var normalized_choices: Array[Dictionary] = _normalize_choices(choices)
	if normalized_choices.is_empty() and auto_continue_on_empty_choices:
		normalized_choices = [{"id": "continue", "text": "Continue"}]
	if normalized_choices.is_empty():
		_set_button_slot(1, {})
		_set_button_slot(2, {})
		return
	var first_choice: Dictionary = normalized_choices[0]
	_set_button_slot(1, first_choice)
	if normalized_choices.size() > 1:
		var second_choice: Dictionary = normalized_choices[1]
		_set_button_slot(2, second_choice)
	else:
		_set_button_slot(2, {})


func _normalize_choices(raw_choices: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_choice in raw_choices:
		if not (raw_choice is Dictionary):
			continue
		var choice_dict: Dictionary = raw_choice as Dictionary
		var choice_id: String = str(choice_dict.get("id", "")).strip_edges()
		var choice_text: String = str(choice_dict.get("text", "")).strip_edges()
		if choice_id.is_empty() and choice_text.is_empty():
			continue
		if choice_id.is_empty():
			choice_id = choice_text.to_lower().replace(" ", "_")
		if choice_text.is_empty():
			choice_text = "Continue"
		result.append({"id": choice_id, "text": choice_text})
	return result


func _set_button_slot(slot: int, choice_data: Dictionary) -> void:
	var has_choice: bool = not choice_data.is_empty()
	var choice_id: String = str(choice_data.get("id", "")).strip_edges()
	var choice_text: String = str(choice_data.get("text", "Continue")).strip_edges()
	if choice_id.is_empty():
		has_choice = false
		choice_id = ""
	if choice_text.is_empty():
		choice_text = "Continue"

	if slot == 1:
		_choice_id_1 = choice_id
		player_response_label_1.text = choice_text
		response_option_panel_1.visible = has_choice
		player_response_button_1.visible = has_choice
		player_response_button_1.disabled = not has_choice
		player_response_label_1.visible = has_choice
		_apply_hover_visual_state(1, false, false)
		return

	_choice_id_2 = choice_id
	player_response_label_2.text = choice_text
	response_option_panel_2.visible = has_choice
	player_response_button_2.visible = has_choice
	player_response_button_2.disabled = not has_choice
	player_response_label_2.visible = has_choice
	_apply_hover_visual_state(2, false, false)


func _on_response_button_1_pressed() -> void:
	if _is_typing:
		_skip_requested = true
		return
	if _choice_id_1.is_empty():
		return
	print("[CharacterDialogPanel] response 1 pressed choice_id=%s" % _choice_id_1)
	response_selected.emit(_choice_id_1)


func _on_response_button_2_pressed() -> void:
	if _is_typing:
		_skip_requested = true
		return
	if _choice_id_2.is_empty():
		return
	print("[CharacterDialogPanel] response 2 pressed choice_id=%s" % _choice_id_2)
	response_selected.emit(_choice_id_2)


func _on_response_button_1_mouse_entered() -> void:
	_apply_hover_visual_state(1, true, true)


func _on_response_button_1_mouse_exited() -> void:
	_apply_hover_visual_state(1, false, true)


func _on_response_button_2_mouse_entered() -> void:
	_apply_hover_visual_state(2, true, true)


func _on_response_button_2_mouse_exited() -> void:
	_apply_hover_visual_state(2, false, true)


func _apply_hover_visual_state(slot: int, hovered: bool, animate: bool) -> void:
	var target_modulate: Color = response_hover_modulate if hovered else response_normal_modulate
	var base_scale: Vector2 = _response_panel_base_scale_1 if slot == 1 else _response_panel_base_scale_2
	var target_scale: Vector2 = base_scale * hover_scale_multiplier if hovered else base_scale
	if slot == 1:
		_apply_hover_visual_state_to_controls(
			response_option_panel_1,
			player_response_label_1,
			target_modulate,
			target_scale,
			animate,
			1
		)
	else:
		_apply_hover_visual_state_to_controls(
			response_option_panel_2,
			player_response_label_2,
			target_modulate,
			target_scale,
			animate,
			2
		)
	if debug_hover:
		print("[CharacterDialogPanel] hover slot=%s hovered=%s" % [slot, hovered])


func _apply_hover_visual_state_to_controls(
	panel: CanvasItem,
	label: CanvasItem,
	target_modulate: Color,
	target_scale: Vector2,
	animate: bool,
	slot: int
) -> void:
	if panel == null:
		return
	if slot == 1 and _hover_tween_1:
		_hover_tween_1.kill()
		_hover_tween_1 = null
	if slot == 2 and _hover_tween_2:
		_hover_tween_2.kill()
		_hover_tween_2 = null
	if not animate:
		panel.modulate = target_modulate
		panel.scale = target_scale
		if label:
			label.modulate = target_modulate
		return
	var tween: Tween = create_tween()
	tween.tween_property(panel, "modulate", target_modulate, hover_tween_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "scale", target_scale, hover_tween_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if label:
		tween.parallel().tween_property(label, "modulate", target_modulate, hover_tween_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if slot == 1:
		_hover_tween_1 = tween
	else:
		_hover_tween_2 = tween


func force_click_at(screen_pos: Vector2) -> bool:
	if not visible:
		return false
	if _is_typing:
		_skip_requested = true
		return true
	force_hover_at(screen_pos)
	if player_response_button_1.visible and not player_response_button_1.disabled:
		var rect_1: Rect2 = player_response_button_1.get_global_rect()
		if rect_1.has_point(screen_pos):
			player_response_button_1.emit_signal("pressed")
			return true
	if player_response_button_2.visible and not player_response_button_2.disabled:
		var rect_2: Rect2 = player_response_button_2.get_global_rect()
		if rect_2.has_point(screen_pos):
			player_response_button_2.emit_signal("pressed")
			return true
	return false


func force_hover_at(screen_pos: Vector2) -> bool:
	if not visible:
		_set_hover_slot(0)
		return false
	var hover_slot: int = 0
	if player_response_button_1.visible and not player_response_button_1.disabled:
		var rect_1: Rect2 = player_response_button_1.get_global_rect()
		if rect_1.has_point(screen_pos):
			hover_slot = 1
	if hover_slot == 0 and player_response_button_2.visible and not player_response_button_2.disabled:
		var rect_2: Rect2 = player_response_button_2.get_global_rect()
		if rect_2.has_point(screen_pos):
			hover_slot = 2
	_set_hover_slot(hover_slot)
	return hover_slot != 0


func clear_hover_state() -> void:
	_set_hover_slot(0)


func is_waiting_for_ack_click() -> bool:
	if not visible:
		return false
	if _is_typing:
		return false
	return _choice_id_1.is_empty() and _choice_id_2.is_empty()


func _set_hover_slot(slot: int) -> void:
	if _current_hover_slot == slot:
		return
	_current_hover_slot = slot
	_apply_hover_visual_state(1, slot == 1, true)
	_apply_hover_visual_state(2, slot == 2, true)


func set_character_voice_profile(profile: Dictionary) -> void:
	_voice_profile = profile.duplicate(true)


func _reset_voice_profile_to_defaults() -> void:
	_voice_profile = {
		"enabled": default_voice_enabled,
		"alphabet_pitch": default_voice_alphabet_pitch,
		"main_pitch_scale": default_voice_main_pitch_scale,
		"random_pitch": default_voice_random_pitch,
		"random_volume_offset_db": default_voice_random_volume_offset_db
	}


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
			chars_to_show = total_chars
			visitor_dialog_label.text = full_text
			break
		chars_to_show += 1
		var visible: String = full_text.substr(0, chars_to_show)
		visitor_dialog_label.text = visible
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
		elif ch == "," or ch == ";":
			await get_tree().create_timer(comma_pause).timeout
			if cycle_id != _typewriter_cycle:
				return
		elif visible.ends_with("[ONE]") or visible.ends_with("[DAYS]"):
			await get_tree().create_timer(bracket_pause).timeout
			if cycle_id != _typewriter_cycle:
				return
	_is_typing = false
	_apply_choices(_pending_choices)


func _apply_voice_profile() -> void:
	if voice_player == null:
		return
	var main_pitch: float = float(_voice_profile.get("main_pitch_scale", default_voice_main_pitch_scale))
	var random_pitch: float = float(_voice_profile.get("random_pitch", default_voice_random_pitch))
	var random_volume_offset: float = float(_voice_profile.get("random_volume_offset_db", default_voice_random_volume_offset_db))
	voice_player.main_pitch_scale = main_pitch
	voice_player.random_pitch = random_pitch
	voice_player.random_volume_offset_db = random_volume_offset


func _character_voice_usable() -> bool:
	if not enable_character_voice:
		return false
	if not bool(_voice_profile.get("enabled", default_voice_enabled)):
		return false
	if voice_player == null:
		return false
	var st: Variant = voice_player.stream
	if st == null or not (st is AudioStreamRandomizer):
		if not _voice_stream_warning_sent:
			_voice_stream_warning_sent = true
			push_warning(
				"CharacterDialogPanel: assign AudioStreamPlayer as VoiceAudioStreamPlayer with AudioStreamRandomizer stream 0."
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
	var pitch: String = str(_voice_profile.get("alphabet_pitch", default_voice_alphabet_pitch)).strip_edges()
	if pitch.is_empty():
		pitch = default_voice_alphabet_pitch
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
