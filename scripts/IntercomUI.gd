extends Control

enum IntercomUiState {
	IDLE,
	RINGING,
	CHATTING
}

@onready var background_color: ColorRect = $ColorRect
@onready var fx_root: Control = $FX
@onready var state_labels_root: Control = $Control/StateLabels
@onready var state_label: Label = $Control/StateLabels/StateLabelActive
@onready var ringing_dots_root: Control = $RingingDots
@onready var ringing_dots: Array = [$RingingDots/Dot1, $RingingDots/Dot2, $RingingDots/Dot3]
@onready var state_label_burnin_1: Control = $Control/StateLabels/StateLabelBurnin
@onready var state_label_burnin_2: Control = $Control/StateLabels/StateLabelBurnin2
@onready var status_dot_root: Control = $Control/StatusDot
@onready var status_dot: TextureRect = $Control/StatusDot/StatusDot
@onready var character_dialog_panel: Control = $CharacterDialogPanel
@onready var standby_frame_root: Control = $MarginContainer
@onready var logo: CanvasItem = $AtlasCoLogo
@onready var mouse_cursor: Sprite2D = $Mouse

var _state: IntercomUiState = IntercomUiState.IDLE
var _ringing_dot_tweens: Array[Tween] = []
var _flicker_tween: Tween = null
var _fx_passes: Array[ColorRect] = []
var _pass_materials: Array[ShaderMaterial] = []
var _status_dot_tween: Tween = null
var _feed_visible: bool = false

const RING_DOT_FADE_SECONDS: float = 0.45
const RING_DOT_PHASE_SECONDS: float = 0.18
const STATUS_DOT_IDLE: Texture2D = preload("res://assets/icons/idle-icon.png")
const STATUS_DOT_RINGING: Texture2D = preload("res://assets/icons/ringing-icon.png")
const STATUS_DOT_LIVE: Texture2D = preload("res://assets/icons/live-icon.png")

@export var ui_burn_in_alpha: float = 0.02
@export var status_dot_burn_in_alpha: float = 0.035
@export var post_fx_base_alpha: float = 1.0
@export var chromatic_aberration_strength: float = 0.0012
@export var blur_strength: float = 0.65
@export var scanline_strength: float = 0.05
@export var flicker_min_interval_seconds: float = 2.0
@export var flicker_max_interval_seconds: float = 8.0
@export var flicker_min_alpha: float = 0.86
@export var flicker_max_alpha: float = 0.96
@export var flicker_drop_duration_seconds: float = 0.03
@export var flicker_recover_duration_seconds: float = 0.06
@export var debug_character_dialog_clicks: bool = false
@export var idle_dim_delay_seconds: float = 3.0
@export var idle_wake_seconds: float = 5.0
@export_range(0.1, 1.0, 0.01) var idle_dim_brightness: float = 0.45
@export var start_idle_dimmed: bool = true

signal character_dialogue_choice_selected(choice_id: String)

var _idle_dimmed: bool = false
var _idle_dim_cycle: int = 0


func _ready() -> void:
	_cache_fx_passes()
	_bind_editor_pass_materials()
	_apply_pass_shader_parameters()
	mouse_cursor.visible = false
	if character_dialog_panel and character_dialog_panel.has_method("hide_dialogue"):
		character_dialog_panel.call("hide_dialogue")
	if character_dialog_panel and character_dialog_panel.has_signal("response_selected"):
		var callback: Callable = Callable(self, "_on_character_dialogue_response_selected")
		if not character_dialog_panel.is_connected("response_selected", callback):
			character_dialog_panel.connect("response_selected", callback)
	for pass_variant in _fx_passes:
		var fx_pass: ColorRect = pass_variant as ColorRect
		var c: Color = fx_pass.modulate
		c.a = 1.0
		fx_pass.modulate = c
	apply_state()
	if start_idle_dimmed and _state == IntercomUiState.IDLE:
		_set_idle_dimmed(true)
	else:
		_set_idle_dimmed(false)
		_begin_idle_dim_timer(idle_dim_delay_seconds)
	call_deferred("_run_random_flicker_loop")


func _cache_fx_passes() -> void:
	_fx_passes.clear()
	if fx_root == null:
		return
	for child in fx_root.get_children():
		if child is ColorRect:
			_fx_passes.append(child as ColorRect)


func _bind_editor_pass_materials() -> void:
	_pass_materials.clear()
	for fx_pass in _fx_passes:
		if fx_pass == null:
			continue
		var mat: ShaderMaterial = fx_pass.material as ShaderMaterial
		if mat == null or mat.shader == null:
			continue
		_pass_materials.append(mat)


func _apply_pass_shader_parameters() -> void:
	for mat in _pass_materials:
		mat.set_shader_parameter("overlay_alpha", post_fx_base_alpha)


func set_state_by_name(state_name: String) -> void:
	var previous_state: IntercomUiState = _state
	var normalized: String = state_name.strip_edges().to_lower()
	match normalized:
		"idle":
			_state = IntercomUiState.IDLE
		"ringing":
			_state = IntercomUiState.RINGING
		"chatting":
			_state = IntercomUiState.CHATTING
		_:
			push_warning("[IntercomUI] Unknown state name: %s" % state_name)
			return
	_handle_idle_dim_state_transition(previous_state, _state)
	apply_state()


func get_state_name() -> String:
	match _state:
		IntercomUiState.IDLE:
			return "idle"
		IntercomUiState.RINGING:
			return "ringing"
		IntercomUiState.CHATTING:
			return "chatting"
	return "idle"


func set_feed_visible(feed_visible: bool) -> void:
	_feed_visible = feed_visible
	_apply_feed_chrome_visibility()


func register_intercom_activity() -> void:
	_set_idle_dimmed(false)
	if _state == IntercomUiState.IDLE:
		_begin_idle_dim_timer(idle_wake_seconds)


func set_screen_cursor_active(active: bool) -> void:
	mouse_cursor.visible = active


func set_screen_cursor_position(viewport_pos: Vector2) -> void:
	mouse_cursor.position = viewport_pos


func force_idle_dimmed_now() -> void:
	_cancel_idle_dim_timer()
	_set_idle_dimmed(true)


func show_character_dialogue(text: String, speaker: String, choices: Array) -> void:
	character_dialog_panel.call("display_dialogue", text, choices, speaker)
	set_state_by_name("chatting")


func hide_character_dialogue() -> void:
	character_dialog_panel.call("hide_dialogue")


func apply_state() -> void:
	# Keep UI root visible at all times; only swap contextual elements.
	visible = true
	_apply_background_visibility()
	_apply_context_state()
	_apply_feed_chrome_visibility()


func _handle_idle_dim_state_transition(previous_state: IntercomUiState, next_state: IntercomUiState) -> void:
	if previous_state == next_state:
		if next_state == IntercomUiState.IDLE and not _idle_dimmed:
			_begin_idle_dim_timer(idle_dim_delay_seconds)
		return
	if next_state == IntercomUiState.IDLE:
		if not _idle_dimmed:
			_begin_idle_dim_timer(idle_dim_delay_seconds)
		return
	_cancel_idle_dim_timer()
	_set_idle_dimmed(false)


func _begin_idle_dim_timer(delay_seconds: float) -> void:
	_idle_dim_cycle += 1
	var cycle_snapshot: int = _idle_dim_cycle
	call_deferred("_idle_dim_after_delay", cycle_snapshot, max(delay_seconds, 0.0))


func _cancel_idle_dim_timer() -> void:
	_idle_dim_cycle += 1


func _idle_dim_after_delay(cycle_snapshot: int, delay_seconds: float) -> void:
	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds).timeout
	if cycle_snapshot != _idle_dim_cycle:
		return
	if _state != IntercomUiState.IDLE:
		return
	_set_idle_dimmed(true)


func _set_idle_dimmed(dimmed: bool) -> void:
	_idle_dimmed = dimmed
	var brightness: float = idle_dim_brightness if dimmed else 1.0
	modulate = Color(brightness, brightness, brightness, 1.0)


func _apply_background_visibility() -> void:
	# Blue standby fill only when feed is off.
	background_color.visible = not _feed_visible


## Feed mode keeps logo, dialog panel, status light, and status text.
func _apply_feed_chrome_visibility() -> void:
	var feed_on: bool = _feed_visible
	logo.visible = true
	status_dot_root.visible = true
	status_dot.visible = true
	state_labels_root.visible = true
	# CharacterDialogPanel manages its own shown/hidden state.

	background_color.visible = not feed_on
	fx_root.visible = not feed_on
	ringing_dots_root.visible = not feed_on and _state == IntercomUiState.RINGING
	standby_frame_root.visible = not feed_on


func _apply_context_state() -> void:
	match _state:
		IntercomUiState.IDLE:
			state_label.text = "standby"
			status_dot.texture = STATUS_DOT_IDLE
			_stop_ringing_dot_animation()
			_start_status_dot_pattern_idle()
		IntercomUiState.RINGING:
			state_label.text = "incoming call"
			status_dot.texture = STATUS_DOT_RINGING
			if not _feed_visible:
				_set_ringing_dots_visible(true)
				_start_ringing_dot_animation()
			else:
				_stop_ringing_dot_animation()
			_start_status_dot_pattern_ringing()
		IntercomUiState.CHATTING:
			state_label.text = "live"
			status_dot.texture = STATUS_DOT_LIVE
			_stop_ringing_dot_animation()
			_start_status_dot_pattern_live()


func _set_ringing_dots_visible(is_visible: bool) -> void:
	for dot_variant in ringing_dots:
		var dot: CanvasItem = dot_variant as CanvasItem
		dot.visible = true
		var reset_modulate: Color = dot.modulate
		reset_modulate.a = 1.0 if is_visible else ui_burn_in_alpha
		dot.modulate = reset_modulate


func _start_ringing_dot_animation() -> void:
	_stop_ringing_dot_animation()
	for i in range(ringing_dots.size()):
		var dot_variant: Variant = ringing_dots[i]
		var dot: CanvasItem = dot_variant as CanvasItem
		var phase_delay: float = float(i) * RING_DOT_PHASE_SECONDS
		var tween: Tween = create_tween()
		tween.set_loops()
		if phase_delay > 0.0:
			tween.tween_interval(phase_delay)
		tween.tween_property(dot, "modulate:a", ui_burn_in_alpha, RING_DOT_FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(dot, "modulate:a", 1.0, RING_DOT_FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_ringing_dot_tweens.append(tween)


func _stop_ringing_dot_animation() -> void:
	for tween in _ringing_dot_tweens:
		tween.kill()
	_ringing_dot_tweens.clear()
	_set_ringing_dots_visible(false)


func _process(_delta: float) -> void:
	pass


func _run_random_flicker_loop() -> void:
	while true:
		var wait_seconds: float = randf_range(flicker_min_interval_seconds, flicker_max_interval_seconds)
		await get_tree().create_timer(wait_seconds).timeout
		_trigger_micro_flicker()


func _trigger_micro_flicker() -> void:
	if _flicker_tween:
		_flicker_tween.kill()
	var low_alpha: float = randf_range(flicker_min_alpha, flicker_max_alpha)
	_flicker_tween = create_tween()
	_flicker_tween.tween_method(_set_post_fx_alpha, post_fx_base_alpha, low_alpha, flicker_drop_duration_seconds)
	_flicker_tween.tween_method(_set_post_fx_alpha, low_alpha, post_fx_base_alpha, flicker_recover_duration_seconds)


func _set_post_fx_alpha(alpha_value: float) -> void:
	for mat in _pass_materials:
		mat.set_shader_parameter("overlay_alpha", alpha_value)


func _start_status_dot_pattern_idle() -> void:
	_stop_status_dot_pattern()
	_set_status_dot_alpha(1.0)
	_status_dot_tween = create_tween()
	_status_dot_tween.set_loops()
	_status_dot_tween.tween_interval(1.0)
	_status_dot_tween.tween_method(_set_status_dot_alpha, 1.0, status_dot_burn_in_alpha, 0.08)
	_status_dot_tween.tween_interval(0.42)
	_status_dot_tween.tween_method(_set_status_dot_alpha, status_dot_burn_in_alpha, 1.0, 0.08)


func _start_status_dot_pattern_ringing() -> void:
	_stop_status_dot_pattern()
	_set_status_dot_alpha(1.0)
	_status_dot_tween = create_tween()
	_status_dot_tween.set_loops()
	# Double-blink pulse pattern, never fully off.
	_status_dot_tween.tween_method(_set_status_dot_alpha, 1.0, status_dot_burn_in_alpha, 0.1)
	_status_dot_tween.tween_method(_set_status_dot_alpha, status_dot_burn_in_alpha, 1.0, 0.1)
	_status_dot_tween.tween_method(_set_status_dot_alpha, 1.0, status_dot_burn_in_alpha, 0.1)
	_status_dot_tween.tween_method(_set_status_dot_alpha, status_dot_burn_in_alpha, 1.0, 0.1)
	_status_dot_tween.tween_interval(0.6)


func _start_status_dot_pattern_live() -> void:
	_stop_status_dot_pattern()
	_set_status_dot_alpha(status_dot_burn_in_alpha)
	_status_dot_tween = create_tween()
	_status_dot_tween.set_loops()
	_status_dot_tween.tween_method(_set_status_dot_alpha, status_dot_burn_in_alpha, 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_status_dot_tween.tween_method(_set_status_dot_alpha, 1.0, status_dot_burn_in_alpha, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_status_dot_pattern() -> void:
	if _status_dot_tween:
		_status_dot_tween.kill()
		_status_dot_tween = null


func _set_status_dot_alpha(alpha_value: float) -> void:
	var c: Color = status_dot.modulate
	c.a = alpha_value
	status_dot.modulate = c


func _on_character_dialogue_response_selected(choice_id: String) -> void:
	character_dialogue_choice_selected.emit(choice_id)


func force_character_dialog_click(viewport_pos: Vector2) -> bool:
	if character_dialog_panel == null:
		return false
	if not character_dialog_panel.has_method("force_click_at"):
		return false
	var clicked: bool = bool(character_dialog_panel.call("force_click_at", viewport_pos))
	if debug_character_dialog_clicks:
		print("[IntercomUI] force_character_dialog_click pos=%s clicked=%s" % [viewport_pos, clicked])
	return clicked


func update_character_dialog_hover(viewport_pos: Vector2) -> bool:
	if character_dialog_panel == null:
		return false
	if not character_dialog_panel.has_method("force_hover_at"):
		return false
	var hovered: bool = bool(character_dialog_panel.call("force_hover_at", viewport_pos))
	if debug_character_dialog_clicks:
		print("[IntercomUI] update_character_dialog_hover pos=%s hovered=%s" % [viewport_pos, hovered])
	return hovered


func clear_character_dialog_hover() -> void:
	if character_dialog_panel == null:
		return
	if character_dialog_panel.has_method("clear_hover_state"):
		character_dialog_panel.call("clear_hover_state")


func is_character_dialogue_waiting_for_ack() -> bool:
	if character_dialog_panel == null:
		return false
	if not character_dialog_panel.has_method("is_waiting_for_ack_click"):
		return false
	return bool(character_dialog_panel.call("is_waiting_for_ack_click"))


func set_character_voice_profile(profile: Dictionary) -> void:
	if character_dialog_panel == null:
		return
	if character_dialog_panel.has_method("set_character_voice_profile"):
		character_dialog_panel.call("set_character_voice_profile", profile)


func map_mouse_uv_to_viewport_pos(screen_uv: Vector2) -> Vector2:
	# Offset from texture/UI center in pixels; applied 1:1 with no scale.
	var clamped_uv: Vector2 = Vector2(clampf(screen_uv.x, 0.0, 1.0), clampf(screen_uv.y, 0.0, 1.0))
	var texture_size: Vector2 = get_viewport_rect().size
	var offset_from_center: Vector2 = Vector2(
		clamped_uv.x * texture_size.x,
		clamped_uv.y * texture_size.y
	) - texture_size * 0.5
	var ui_size: Vector2 = size
	if ui_size.x < 1.0 or ui_size.y < 1.0:
		ui_size = texture_size
	var mapped: Vector2 = ui_size * 0.5 + offset_from_center
	if debug_character_dialog_clicks:
		print("[IntercomUI] map_mouse_uv_to_viewport_pos uv=%s offset=%s mapped=%s" % [
			clamped_uv, offset_from_center, mapped
		])
	return mapped
