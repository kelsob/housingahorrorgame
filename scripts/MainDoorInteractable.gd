extends Node3D

## Attach to MainDoor root. Add an Area3D child with CollisionShape3D for the raycast to hit.
## During work-unlocked morning flow, interact opens the apartment front door into hallway,
## then auto-closes after a delay (same pattern as PlayerRoomDoorInteractable).
##
## Scene structure (create manually if missing):
##   MainDoor
##   └─ DoorFrameCollision (Area3D)
##      └─ CollisionShape3D — box covering the doorway so auto-close waits while the player is in the frame

signal interact_requested

@export var work_dialogue_id: String = "door_work"
@export var debug: bool = true
@export var debug_open_action: String = "debug_front_door_open"
@export var open_blend_shape_value: float = 1.0
@export var auto_close_delay_seconds: float = 3.0
@export var auto_close_retry_seconds: float = 1.0
## Added to the player's interact_range for this object only (meters along look ray).
@export var interact_range_extra: float = 0.0

@export_group("Open Motion")
@export var hitch_delay_seconds: float = 0.08
@export var crack_progress: float = 0.05
@export var crack_duration_seconds: float = 0.22
@export var crack_hitch_seconds: float = 0.07
@export var sweep_progress: float = 0.95
@export var sweep_duration_seconds: float = 0.38
@export var settle_duration_seconds: float = 0.2
## Door collision stays solid until open progress reaches this (0-1).
@export_range(0.0, 1.0, 0.01) var traversable_at_progress: float = 0.9

@export_group("Door Screen")
@export var unit_number: String = ""
@export var occupant_code: String = ""
@export var lock_status: HallwayDoorScreenUI.LockStatus = HallwayDoorScreenUI.LockStatus.LOCKED


func get_interaction_prompt() -> String:
	return "Close door [E]" if _is_open else "Open door [E]"

const MAIN_DOOR_OPEN_SFX_PATH := "res://assets/sfx/door_front_open.ogg"
const MAIN_DOOR_OPEN_SFX_VOLUME_DB := -8.0
const MAIN_DOOR_OPEN_SFX_PITCH_SCALE := 1.5
const FRONT_DOOR_MESH_PATH := "door_new/front door NEW FRONT"
const FRONT_DOOR_COLLISION_PATH := "door_new/StaticBody3D/CollisionShape3D"
const FRONT_DOOR_BLEND_SHAPE_PROPERTY := "blend_shapes/Key 1"
const SCREEN_SURFACE_INDEX: int = 4

@onready var _front_door_mesh: MeshInstance3D = get_node(FRONT_DOOR_MESH_PATH) as MeshInstance3D
@onready var _front_door_collision: CollisionShape3D = get_node(FRONT_DOOR_COLLISION_PATH) as CollisionShape3D
@onready var door_frame_collider: Area3D = $DoorFrameCollision
@onready var _screen_viewport: SubViewport = $SubViewport
@onready var _screen_ui: HallwayDoorScreenUI = $SubViewport/HallwayDoorScreenUI

var _is_open: bool = false
var _open_cycle_id: int = 0
var _door_motion_tween: Tween = null
var _door_progress: float = 0.0


func _ready() -> void:
	door_frame_collider.monitoring = true
	door_frame_collider.monitorable = true
	GameStateManager.phase_changed.connect(_on_phase_changed)
	_set_door_open_state(false, true)
	_screen_ui.set_data(unit_number, occupant_code, lock_status)
	_apply_screen_material()


## Match hallway DoorScreen materials: unshaded so UI stays bright under world lights.
func _apply_screen_material() -> void:
	if _screen_viewport.size.x < 2 or _screen_viewport.size.y < 2:
		_screen_viewport.size = Vector2i(512, 256)
	_screen_viewport.transparent_bg = true
	_screen_viewport.handle_input_locally = false
	_screen_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var material := StandardMaterial3D.new()
	material.albedo_texture = _screen_viewport.get_texture()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_front_door_mesh.set_surface_override_material(SCREEN_SURFACE_INDEX, material)
	call_deferred("_settle_screen_render_mode")


func _settle_screen_render_mode() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_screen_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func interact() -> void:
	if debug:
		print("[MainDoor] interact() called")
	_screen_ui.register_activity()
	if _is_open:
		_open_cycle_id += 1
		_set_door_open_state(false, false)
		if debug:
			print("[MainDoor] door closed by player")
		return
	var game: Node = get_tree().current_scene
	if game.handle_main_door_interaction():
		if debug:
			print("[MainDoor] interaction consumed by Game day-flow")
		return
	if GameStateManager.current_phase != GameStateManager.Phase.MORNING:
		if debug:
			print("[MainDoor] SKIP: not MORNING phase (current=%s)" % GameStateManager.current_phase)
		return
	if WorkManager.can_go_to_work():
		_open_for_hallway_exit()
		return
	if debug:
		print("[MainDoor] showing dialogue: ", work_dialogue_id)
	var disabled: Array[String] = []
	if not EnergyManager.can_afford(WorkManager.working_energy_cost):
		disabled.append("go")
	elif WorkManager.attended_this_period():
		disabled.append("go")
	DialogueManager.show_dialogue(work_dialogue_id, disabled)


func _unhandled_input(event: InputEvent) -> void:
	if not debug:
		return
	if debug_open_action.strip_edges().is_empty():
		return
	if not InputMap.has_action(debug_open_action):
		return
	if event.is_action_pressed(debug_open_action):
		_open_for_hallway_exit()


func _open_for_hallway_exit() -> void:
	if _is_open:
		return
	_screen_ui.register_activity()
	_set_door_open_state(true, false)
	_play_sfx(MAIN_DOOR_OPEN_SFX_PATH, MAIN_DOOR_OPEN_SFX_VOLUME_DB)
	_open_cycle_id += 1
	call_deferred("_attempt_auto_close_after_delay", _open_cycle_id)
	if debug:
		print("[MainDoor] door opened for hallway exit")


func _on_phase_changed(new_phase: int) -> void:
	if new_phase != GameStateManager.Phase.MORNING:
		_open_cycle_id += 1
		_set_door_open_state(false, true)


func _set_door_open_state(opened: bool, immediate: bool) -> void:
	_is_open = opened
	if _door_motion_tween:
		_door_motion_tween.kill()
		_door_motion_tween = null
	var target_progress: float = 1.0 if opened else 0.0
	if immediate:
		_set_door_progress(target_progress)
		return
	_door_motion_tween = create_tween()
	DoorHitchMotion.animate(
		_door_motion_tween,
		opened,
		_door_progress,
		_set_door_progress,
		hitch_delay_seconds,
		crack_progress,
		crack_duration_seconds,
		crack_hitch_seconds,
		sweep_progress,
		sweep_duration_seconds,
		settle_duration_seconds
	)


func _set_door_progress(progress: float) -> void:
	_door_progress = clampf(progress, 0.0, 1.0)
	_front_door_mesh.set(FRONT_DOOR_BLEND_SHAPE_PROPERTY, _door_progress * open_blend_shape_value)
	_front_door_collision.disabled = _door_progress >= traversable_at_progress


func _is_player_overlapping_door_frame() -> bool:
	for body in door_frame_collider.get_overlapping_bodies():
		if body is CharacterBody3D and body.name == "PlayerBody":
			return true
	return false


func _attempt_auto_close_after_delay(cycle_id: int) -> void:
	await get_tree().create_timer(auto_close_delay_seconds).timeout
	_attempt_auto_close_loop(cycle_id)


func _attempt_auto_close_loop(cycle_id: int) -> void:
	if cycle_id != _open_cycle_id:
		return
	if not _is_open:
		return
	if _is_player_overlapping_door_frame():
		if debug:
			print("[MainDoor] auto-close blocked: player overlapping DoorFrameCollision; retrying")
		await get_tree().create_timer(auto_close_retry_seconds).timeout
		_attempt_auto_close_loop(cycle_id)
		return
	_set_door_open_state(false, false)
	if debug:
		print("[MainDoor] auto-closed")


func _play_sfx(path: String, volume_db: float) -> void:
	if not ResourceLoader.exists(path):
		push_warning("[MainDoor] Missing SFX file: %s" % path)
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("[MainDoor] Failed to load SFX stream: %s" % path)
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = MAIN_DOOR_OPEN_SFX_PITCH_SCALE
	player.bus = "Master"
	call_deferred("_add_and_play_sfx_player", player)


func _add_and_play_sfx_player(player: AudioStreamPlayer3D) -> void:
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
