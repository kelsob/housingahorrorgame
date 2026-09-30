extends Node3D

## Attach to PlayerRoomDoor root. Interact to open/close the bedroom door (slides on X).
## Requires collision on door or a child for raycast to hit.
## Structure: root has "door" child (Node3D) — we slide it on the X-axis.

@export var open_offset_x: float = 0.705
@export var auto_close_delay_seconds: float = 3.0
@export var auto_close_retry_seconds: float = 1.0
@export var debug: bool = true
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

@onready var door: Node3D = $door
@onready var door_frame_collider: Area3D = $DoorFrameCollision

const ROOM_DOOR_SLIDE_OPEN_SFX_PATH := "res://assets/sfx/door_room_slide_open.ogg"
const ROOM_DOOR_SLIDE_CLOSE_SFX_PATH := "res://assets/sfx/door_room_slide_close.ogg"
const ROOM_DOOR_SLIDE_SFX_VOLUME_DB := -10.0
const ROOM_DOOR_SLIDE_SFX_PITCH_SCALE := 1.5

var _is_open: bool = false
var _closed_position: Vector3
var _open_position: Vector3
var _open_cycle_id: int = 0
var _door_motion_tween: Tween = null
var _door_progress: float = 0.0


func get_interaction_prompt() -> String:
	return "Close door [E]" if _is_open else "Open door [E]"


func _ready() -> void:
	if not door:
		push_warning("[PlayerRoomDoor] Missing required child node: door")
		return
	if door_frame_collider:
		door_frame_collider.monitoring = true
		door_frame_collider.monitorable = true
	_closed_position = door.position
	_open_position = _closed_position + Vector3(open_offset_x, 0, 0)


func interact() -> void:
	if debug:
		print("[PlayerRoomDoor] interact()")
	if not _is_open and _is_player_overlapping_door_frame():
		if debug:
			print("[PlayerRoomDoor] blocked: player overlapping doorframecollider")
		return
	_toggle_door()


func _toggle_door() -> void:
	if not door:
		if debug:
			push_warning("[PlayerRoomDoor] Missing required child node: door")
		return
	_is_open = not _is_open
	if _door_motion_tween:
		_door_motion_tween.kill()
		_door_motion_tween = null
	_door_motion_tween = create_tween()
	DoorHitchMotion.animate(
		_door_motion_tween,
		_is_open,
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
	var sfx_path := ROOM_DOOR_SLIDE_OPEN_SFX_PATH if _is_open else ROOM_DOOR_SLIDE_CLOSE_SFX_PATH
	_play_sfx(sfx_path, ROOM_DOOR_SLIDE_SFX_VOLUME_DB)
	if _is_open:
		_open_cycle_id += 1
		call_deferred("_attempt_auto_close_after_delay", _open_cycle_id)
	if debug:
		print("[PlayerRoomDoor] %s" % ["open" if _is_open else "closed"])


func _set_door_progress(progress: float) -> void:
	_door_progress = clampf(progress, 0.0, 1.0)
	door.position = _closed_position.lerp(_open_position, _door_progress)


func _play_sfx(path: String, volume_db: float) -> void:
	if not ResourceLoader.exists(path):
		push_warning("[PlayerRoomDoor] Missing SFX file: %s" % path)
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("[PlayerRoomDoor] Failed to load SFX stream: %s" % path)
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = ROOM_DOOR_SLIDE_SFX_PITCH_SCALE
	player.bus = "Master"
	call_deferred("_add_and_play_sfx_player", player)


func _add_and_play_sfx_player(player: AudioStreamPlayer3D) -> void:
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _is_player_overlapping_door_frame() -> bool:
	if not door_frame_collider:
		return false
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
			print("[PlayerRoomDoor] auto-close blocked: player overlapping doorframecollider; retrying")
		await get_tree().create_timer(auto_close_retry_seconds).timeout
		_attempt_auto_close_loop(cycle_id)
		return
	_toggle_door()


## Silent reset used by sleep/day transitions (no tween, no SFX).
func reset_to_closed_silent() -> void:
	if not door:
		return
	_open_cycle_id += 1
	_is_open = false
	if _door_motion_tween:
		_door_motion_tween.kill()
		_door_motion_tween = null
	_set_door_progress(0.0)
