extends Node3D

const SUBVIEWPORT_PATH := "SubViewport"
const FEED_CAMERA_PATH := "SubViewport/FeedCamera"
const STREET_FEED_ANCHOR_PATH := "GameObjects/StreetLevel/StreetFeedAnchor"
const STREET_LEVEL_PATH := "GameObjects/StreetLevel"
const BUZZ_PLAYER_PATH := "AudioStreamPlayer3D"
const INTERCOM_BODY_PATH := "intercom2/StaticBody3D"
const INTERCOM_SCREEN_MESH_PATH := "intercom2/apartment_panel"
const INTERCOM_SCREEN_TOP_LEFT_MARKER_PATH := "intercom2/ScreenTopLeft"
const INTERCOM_SCREEN_BOTTOM_RIGHT_MARKER_PATH := "intercom2/ScreenBottomRight"
const INTERCOM_SCREEN_SURFACE_INDEX: int = 1

@export var feed_enabled_on_ready: bool = false
@export var track_anchor_each_frame: bool = true
@export var street_buzz_sfx_path: String = "res://assets/sfx/intercom_ring.mp3"
@export var street_buzz_volume_db: float = -6.0
@export var feed_camera_idle_fov: float = 75.0
@export var feed_camera_active_fov: float = 110.0
@export var dialogue_start_delay_seconds: float = 1.0
@export var debug: bool = true
@export var click_raycast_max_distance: float = 20.0
@export var debug_click_routing: bool = false
## Added to the player's interact_range for this object only (meters along look ray).
@export var interact_range_extra: float = 0.0
## Multiplies the Y offset from screen/UI center. >1 expands vertical hit thickness.
@export var screen_click_v_scale: float = 1.0
## Added to mapped UI Y after scale (pixels). Positive = lower on the UI.
@export var screen_click_v_offset: float = 0.0


func get_interaction_prompt() -> String:
	return "Use intercom [E]"

@onready var ui: Control = $SubViewport/IntercomUI

@onready var _subviewport: SubViewport = $SubViewport
@onready var _feed_camera: Camera3D = $SubViewport/FeedCamera
@onready var _buzz_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var _intercom_body: StaticBody3D = $intercom2/StaticBody3D
@onready var _intercom_screen_mesh: MeshInstance3D = $intercom2/apartment_panel
@onready var _screen_top_left_marker: Node3D = $intercom2/ScreenTopLeft
@onready var _screen_bottom_right_marker: Node3D = $intercom2/ScreenBottomRight
@onready var player_camera_position: Marker3D = $PlayerCameraPosition
@onready var _street_level: Node = get_tree().current_scene.get_node(STREET_LEVEL_PATH)
@onready var _street_feed_anchor: Node3D = get_tree().current_scene.get_node(STREET_FEED_ANCHOR_PATH) as Node3D


var _feed_enabled: bool = false
var _active_intercom_dialogue_id: String = ""
var _ui_input_mode_active: bool = false
var _last_pointer_viewport_pos: Vector2 = Vector2.ZERO
var _dialogue_start_cycle: int = 0
var _terminal_ack_pending: bool = false
var _pending_arrival_outcome: String = ""

signal ui_input_mode_changed(active: bool)


func _ready() -> void:
	_buzz_player.finished.connect(_on_buzz_player_finished)
	call_deferred("_finish_intercom_setup")


func _finish_intercom_setup() -> void:
	_subviewport.world_3d = get_viewport().world_3d
	_apply_unshaded_screen_material()
	_bind_street_level_signals()
	_bind_ui_signals()
	_set_feed_enabled(feed_enabled_on_ready)
	_sync_feed_camera_to_anchor()
	_set_ui_state("idle")
	ui.force_idle_dimmed_now()
	if debug:
		_print_screen_fit_debug()


func _print_screen_fit_debug() -> void:
	var vp_size: Vector2i = _subviewport.size
	var marker_delta: Vector3 = _screen_bottom_right_marker.global_position - _screen_top_left_marker.global_position
	var physical_aspect: float = absf(marker_delta.x) / maxf(absf(marker_delta.y), 0.0001)
	print("[Intercom] SubViewport size=%s | ui.size=%s | marker aspect=%.3f" % [
		vp_size, ui.size, physical_aspect
	])


## Match hallway DoorScreen materials: unshaded so UI stays bright under room lights.
## Idle dimming still comes from IntercomUI.modulate.
func _apply_unshaded_screen_material() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = _subviewport.get_texture()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_intercom_screen_mesh.set_surface_override_material(INTERCOM_SCREEN_SURFACE_INDEX, material)


func _process(_delta: float) -> void:
	if not track_anchor_each_frame:
		return
	if not _feed_enabled:
		return
	_sync_feed_camera_to_anchor()


func _set_feed_enabled(enabled: bool) -> void:
	_feed_enabled = enabled
	# Keep SubViewport rendering even when feed is off so IntercomUI remains visible.
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_WHEN_VISIBLE
	_feed_camera.current = enabled
	_feed_camera.fov = feed_camera_active_fov if enabled else feed_camera_idle_fov
	ui.set_feed_visible(enabled)
	if debug:
		print("[Intercom] feed enabled: %s" % enabled)


func _sync_feed_camera_to_anchor() -> void:
	_feed_camera.global_position = _street_feed_anchor.global_position
	_feed_camera.global_rotation = _street_feed_anchor.global_rotation


func play_street_buzz() -> void:
	_set_ui_state("ringing")
	ui.register_intercom_activity()
	if street_buzz_sfx_path.strip_edges().is_empty():
		if debug:
			print("[Intercom] street buzz requested but street_buzz_sfx_path is empty")
		return
	if not ResourceLoader.exists(street_buzz_sfx_path):
		push_warning("[Intercom] Missing buzz SFX file: %s" % street_buzz_sfx_path)
		return
	var stream: AudioStream = load(street_buzz_sfx_path) as AudioStream
	if stream == null:
		push_warning("[Intercom] Failed to load buzz SFX stream: %s" % street_buzz_sfx_path)
		return
	_buzz_player.stop()
	_buzz_player.stream = stream
	_buzz_player.volume_db = street_buzz_volume_db
	_buzz_player.play()


func interact() -> void:
	ui.register_intercom_activity()
	open_active_arrival_dialogue()


func open_active_arrival_dialogue() -> bool:
	var opened_dialogue: bool = on_intercom_interacted()
	if opened_dialogue:
		_set_ui_state("chatting")
		_stop_buzz()
		_set_ui_input_mode_active(true)
	return opened_dialogue


func on_accept_button_pressed() -> void:
	_street_level.accept_current_arrival()
	ui.call("hide_character_dialogue")


func on_intercom_interacted() -> bool:
	if not bool(_street_level.has_active_arrival()):
		return false
	_active_intercom_dialogue_id = str(_street_level.get_active_arrival_dialogue_id())
	if _active_intercom_dialogue_id.strip_edges().is_empty():
		return false
	_set_feed_enabled(true)
	_sync_feed_camera_to_anchor()
	_dialogue_start_cycle += 1
	call_deferred("_show_current_arrival_dialogue_after_delay", _dialogue_start_cycle)
	return true


func on_reject_button_pressed() -> void:
	_street_level.reject_current_arrival()
	ui.call("hide_character_dialogue")


func _bind_street_level_signals() -> void:
	_street_level.arrival_spawned.connect(_on_street_arrival_spawned)
	_street_level.arrival_resolved.connect(_on_street_arrival_resolved)
	_street_level.queue_exhausted.connect(_on_street_arrival_queue_exhausted)


func _on_street_arrival_spawned(_dialogue_id: String) -> void:
	# Feed stays off until the player interacts during the call.
	pass


func _on_street_arrival_resolved(_dialogue_id: String, _accepted: bool) -> void:
	_dialogue_start_cycle += 1
	_active_intercom_dialogue_id = ""
	_terminal_ack_pending = false
	_pending_arrival_outcome = ""
	ui.call("hide_character_dialogue")
	ui.register_intercom_activity()
	_set_ui_input_mode_active(false)
	_stop_buzz()
	var still_active: bool = bool(_street_level.has_active_arrival())
	if still_active:
		return
	_set_feed_enabled(false)
	_set_ui_state("idle")


func _on_street_arrival_queue_exhausted() -> void:
	_dialogue_start_cycle += 1
	_active_intercom_dialogue_id = ""
	_terminal_ack_pending = false
	_pending_arrival_outcome = ""
	ui.call("hide_character_dialogue")
	_set_ui_input_mode_active(false)
	_stop_buzz()
	_set_feed_enabled(false)
	_set_ui_state("idle")


func _on_buzz_player_finished() -> void:
	if _has_pending_arrival():
		_buzz_player.play()


func _has_pending_arrival() -> bool:
	return bool(_street_level.has_active_arrival())


func _stop_buzz() -> void:
	if _buzz_player.playing:
		_buzz_player.stop()


func _set_ui_state(state_name: String) -> void:
	ui.call("set_state_by_name", state_name)


func _bind_ui_signals() -> void:
	ui.character_dialogue_choice_selected.connect(_on_character_dialogue_choice_selected)


func _show_current_arrival_dialogue() -> void:
	if _active_intercom_dialogue_id.strip_edges().is_empty():
		return
	_terminal_ack_pending = false
	_pending_arrival_outcome = ""
	var payload: Dictionary = DialogueManager.get_dialogue_payload(_active_intercom_dialogue_id)
	if payload.is_empty():
		push_warning("[Intercom] Missing arrival dialogue payload: %s" % _active_intercom_dialogue_id)
		return
	var text: String = str(payload.get("text", ""))
	var speaker: String = str(payload.get("speaker", ""))
	var choices_variant: Variant = payload.get("choices", [])
	var choices: Array = choices_variant if choices_variant is Array else []
	var voice_profile: Dictionary = _build_voice_profile_from_payload(payload)
	ui.set_character_voice_profile(voice_profile)
	ui.call("show_character_dialogue", text, speaker, choices)


func _show_current_arrival_dialogue_after_delay(cycle_id: int) -> void:
	var delay_seconds: float = max(dialogue_start_delay_seconds, 0.0)
	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds).timeout
	if cycle_id != _dialogue_start_cycle:
		return
	if _active_intercom_dialogue_id.strip_edges().is_empty():
		return
	_show_current_arrival_dialogue()


func _on_character_dialogue_choice_selected(choice_id: String) -> void:
	if _active_intercom_dialogue_id.strip_edges().is_empty():
		return
	var payload: Dictionary = DialogueManager.get_dialogue_payload(_active_intercom_dialogue_id)
	var selected_choice: Dictionary = _find_choice_by_id(payload, choice_id)
	var next_dialogue_id: String = str(selected_choice.get("next", "")).strip_edges()
	if not next_dialogue_id.is_empty() and DialogueManager.has_dialogue(next_dialogue_id):
		_active_intercom_dialogue_id = next_dialogue_id
		_show_current_arrival_dialogue()
		return
	var outcome: String = str(selected_choice.get("outcome", "")).strip_edges()
	if outcome.is_empty():
		return
	_pending_arrival_outcome = outcome
	_terminal_ack_pending = true
	_show_terminal_response(payload, selected_choice, outcome)


func _show_terminal_response(current_payload: Dictionary, selected_choice: Dictionary, outcome: String) -> void:
	var final_text: String = str(selected_choice.get("final_text", "")).strip_edges()
	var final_speaker: String = str(selected_choice.get("final_speaker", "")).strip_edges()
	if final_speaker.is_empty():
		final_speaker = str(current_payload.get("speaker", "")).strip_edges()
	if final_text.is_empty():
		if outcome == "let_in":
			final_text = "Thanks. I'm coming up now."
		else:
			final_text = "Fine. I'll go."
	ui.call("show_character_dialogue", final_text, final_speaker, [])


func try_acknowledge_terminal_dialogue_click() -> bool:
	if not _terminal_ack_pending:
		return false
	var can_ack: bool = bool(ui.is_character_dialogue_waiting_for_ack())
	if not can_ack:
		return false
	_resolve_pending_arrival_outcome()
	return true


func _resolve_pending_arrival_outcome() -> void:
	if _pending_arrival_outcome.is_empty():
		_terminal_ack_pending = false
		return
	var outcome: String = _pending_arrival_outcome
	_pending_arrival_outcome = ""
	_terminal_ack_pending = false
	if outcome == "let_in":
		_street_level.accept_current_arrival()
	else:
		_street_level.reject_current_arrival()


func _find_choice_by_id(payload: Dictionary, choice_id: String) -> Dictionary:
	var choices_variant: Variant = payload.get("choices", [])
	if choices_variant is Array:
		for raw_choice in choices_variant:
			if raw_choice is Dictionary:
				var choice_data: Dictionary = raw_choice
				if str(choice_data.get("id", "")).strip_edges() == choice_id:
					return choice_data
	return {}


func _build_voice_profile_from_payload(payload: Dictionary) -> Dictionary:
	return {
		"enabled": bool(payload.get("voice_enabled", true)),
		"alphabet_pitch": str(payload.get("voice_alphabet_pitch", "med")),
		"main_pitch_scale": float(payload.get("voice_main_pitch_scale", 1.0)),
		"random_pitch": float(payload.get("voice_random_pitch", 1.0)),
		"random_volume_offset_db": float(payload.get("voice_random_volume_offset_db", 0.0))
	}


func is_ui_input_mode_active() -> bool:
	return _ui_input_mode_active


func cancel_ui_input_mode() -> void:
	if _active_intercom_dialogue_id.strip_edges().is_empty() == false:
		return
	if _terminal_ack_pending:
		return
	_dialogue_start_cycle += 1
	_set_ui_input_mode_active(false)
	ui.call("hide_character_dialogue")
	if _has_pending_arrival():
		_set_ui_state("ringing")
	else:
		_set_feed_enabled(false)
		_set_ui_state("idle")


func route_screen_mouse_button(camera: Camera3D, event: InputEventMouseButton) -> bool:
	if camera == null or event == null:
		return false
	var hit: Dictionary = _intersect_intercom_hit_from_camera(camera, event.position)
	if hit.is_empty():
		if debug_click_routing and event.pressed:
			print("[IntercomClick] miss raycast screen=%s" % [event.position])
		return false
	var hit_world: Vector3 = hit["position"]
	var screen_uv: Vector2 = _map_world_hit_to_screen_uv(hit_world)
	if screen_uv.x < 0.0:
		if debug_click_routing and event.pressed:
			print("[IntercomClick] hit but failed UV mapping world=%s" % [hit_world])
		return false
	var viewport_pos: Vector2 = _map_screen_uv_to_viewport_pos(screen_uv)
	if viewport_pos.x < 0.0:
		if debug_click_routing and event.pressed:
			print("[IntercomClick] hit but outside mapped screen world=%s" % [hit_world])
		ui.clear_character_dialog_hover()
		return false
	_push_mouse_motion(viewport_pos)
	ui.set_screen_cursor_position(viewport_pos)
	ui.update_character_dialog_hover(viewport_pos)
	if event.pressed:
		ui.register_intercom_activity()
	var direct_clicked: bool = false
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		direct_clicked = bool(ui.force_character_dialog_click(viewport_pos))
	var click_event := InputEventMouseButton.new()
	click_event.button_index = event.button_index
	click_event.pressed = event.pressed
	click_event.double_click = event.double_click
	click_event.canceled = event.canceled
	click_event.button_mask = event.button_mask
	click_event.position = viewport_pos
	click_event.global_position = viewport_pos
	_subviewport.push_input(click_event)
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not direct_clicked:
		if try_acknowledge_terminal_dialogue_click():
			direct_clicked = true
	if debug_click_routing and event.button_index == MOUSE_BUTTON_LEFT:
		print(
			"[IntercomClick] screen=%s world=%s uv=%s viewport=%s pressed=%s direct_button=%s" % [
				event.position,
				hit_world,
				screen_uv,
				viewport_pos,
				event.pressed,
				direct_clicked
			]
		)
	return true


func route_screen_mouse_motion(camera: Camera3D, event: InputEventMouseMotion) -> bool:
	if camera == null or event == null:
		return false
	var hit: Dictionary = _intersect_intercom_hit_from_camera(camera, event.position)
	if hit.is_empty():
		return false
	var hit_world: Vector3 = hit["position"]
	var screen_uv: Vector2 = _map_world_hit_to_screen_uv(hit_world)
	if screen_uv.x < 0.0:
		if debug_click_routing:
			print("[IntercomMove] failed UV mapping world=%s" % [hit_world])
		return false
	var viewport_pos: Vector2 = _map_screen_uv_to_viewport_pos(screen_uv)
	if viewport_pos.x < 0.0:
		if debug_click_routing:
			print("[IntercomMove] outside mapped screen world=%s" % [hit_world])
		ui.clear_character_dialog_hover()
		return false
	_push_mouse_motion(viewport_pos)
	ui.set_screen_cursor_position(viewport_pos)
	ui.update_character_dialog_hover(viewport_pos)
	if debug_click_routing:
		print("[IntercomMove] screen=%s world=%s uv=%s viewport=%s" % [event.position, hit_world, screen_uv, viewport_pos])
	return true


func _intersect_intercom_hit_from_camera(camera: Camera3D, screen_pos: Vector2) -> Dictionary:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_normal: Vector3 = camera.project_ray_normal(screen_pos)
	var to: Vector3 = origin + (ray_normal * click_raycast_max_distance)
	var query := PhysicsRayQueryParameters3D.create(origin, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var hit: Dictionary = state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider_variant: Variant = hit.get("collider")
	var collider_node: Node = collider_variant as Node
	if collider_node == null:
		return {}
	if _intercom_body and collider_node == _intercom_body:
		return hit
	if _intercom_body and _intercom_body.is_ancestor_of(collider_node):
		return hit
	if self.is_ancestor_of(collider_node):
		return hit
	if debug_click_routing:
		print("[IntercomClick] ray hit non-intercom collider=%s" % [collider_node.name])
	return {}


func _map_world_hit_to_screen_uv(hit_world: Vector3) -> Vector2:
	if _screen_top_left_marker and _screen_bottom_right_marker and _intercom_body:
		var local_hit_marker: Vector3 = _intercom_body.to_local(hit_world)
		var marker_tl: Vector3 = _intercom_body.to_local(_screen_top_left_marker.global_position)
		var marker_br: Vector3 = _intercom_body.to_local(_screen_bottom_right_marker.global_position)
		return _map_local_hit_to_uv(local_hit_marker, marker_tl, marker_br)
	if _intercom_screen_mesh and _intercom_screen_mesh.mesh:
		var local_hit_mesh: Vector3 = _intercom_screen_mesh.to_local(hit_world)
		var aabb: AABB = _intercom_screen_mesh.mesh.get_aabb()
		var tl_mesh: Vector3 = Vector3(aabb.position.x, aabb.position.y, 0.0)
		var br_mesh: Vector3 = Vector3(aabb.end.x, aabb.end.y, 0.0)
		return _map_local_hit_to_uv(local_hit_mesh, tl_mesh, br_mesh)
	return Vector2(-1.0, -1.0)


func _map_local_hit_to_uv(local_hit: Vector3, top_left: Vector3, bottom_right: Vector3) -> Vector2:
	var width: float = bottom_right.x - top_left.x
	var height: float = bottom_right.y - top_left.y
	if is_zero_approx(width) or is_zero_approx(height):
		return Vector2(-1.0, -1.0)
	var u: float = (local_hit.x - top_left.x) / width
	var v: float = (local_hit.y - top_left.y) / height
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return Vector2(-1.0, -1.0)
	return Vector2(u, v)


func _map_screen_uv_to_viewport_pos(screen_uv: Vector2) -> Vector2:
	# a) Offset in pixels from the center of the SubViewport texture.
	# b) Apply that same offset from IntercomUI's center — X unscaled; Y uses v_scale/v_offset.
	var clamped_uv: Vector2 = Vector2(clampf(screen_uv.x, 0.0, 1.0), clampf(screen_uv.y, 0.0, 1.0))
	var texture_size: Vector2 = Vector2(_subviewport.size)
	var texture_center: Vector2 = texture_size * 0.5
	var click_on_texture: Vector2 = Vector2(clamped_uv.x * texture_size.x, clamped_uv.y * texture_size.y)
	var offset_from_center: Vector2 = click_on_texture - texture_center
	offset_from_center.y = offset_from_center.y * screen_click_v_scale + screen_click_v_offset

	var ui_size: Vector2 = ui.size
	if ui_size.x < 1.0 or ui_size.y < 1.0:
		ui_size = texture_size
	var ui_center: Vector2 = ui_size * 0.5
	var mapped: Vector2 = ui_center + offset_from_center
	if debug_click_routing:
		print("[Intercom] uv=%s offset_from_center=%s -> ui_pos=%s (v_scale=%s v_offset=%s)" % [
			clamped_uv, offset_from_center, mapped, screen_click_v_scale, screen_click_v_offset
		])
	return mapped


func _push_mouse_motion(viewport_pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = viewport_pos
	motion.global_position = viewport_pos
	motion.relative = viewport_pos - _last_pointer_viewport_pos
	motion.button_mask = Input.get_mouse_button_mask()
	_last_pointer_viewport_pos = viewport_pos
	_subviewport.push_input(motion)


func _set_ui_input_mode_active(active: bool) -> void:
	if _ui_input_mode_active == active:
		return
	_ui_input_mode_active = active
	ui.set_screen_cursor_active(active)
	ui_input_mode_changed.emit(active)
