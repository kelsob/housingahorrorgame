class_name HallwayDoorInteractable
extends MeshInstance3D

## One interactable for every hallway unit door. Player-owned doors can lock/unlock
## and show occupied + the player's unit/occupant on the screen. Neighbor doors
## stay locked unless you set locked=false.
##
## Required children:
##   hallway_door_* (this script)
##   └─ DoorFrameCollision (StaticBody3D)
##      └─ CollisionShape3D — closed door slab (thickness ≥ 0.2)

@export var debug: bool = false
@export var open_blend_shape_value: float = 1.0
@export var auto_close_delay_seconds: float = 3.0
@export var auto_close_retry_seconds: float = 1.0
## If true and not player-owned, interact does not open the door.
@export var locked: bool = false
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

const DOOR_OPEN_SFX_PATH := "res://assets/sfx/door_front_open.ogg"
const DOOR_OPEN_SFX_VOLUME_DB := -8.0
const DOOR_OPEN_SFX_PITCH_SCALE := 1.5
const BLEND_SHAPE_PROPERTY := "blend_shapes/Key 1"

@onready var _door_body: StaticBody3D = $DoorFrameCollision
@onready var _door_collision: CollisionShape3D = $DoorFrameCollision/CollisionShape3D

var _is_open: bool = false
var _open_cycle_id: int = 0
var _door_motion_tween: Tween = null
var _door_progress: float = 0.0
var _screen_ui: HallwayDoorScreenUI = null
var _player_owned: bool = false


func bind_screen_ui(ui: HallwayDoorScreenUI) -> void:
	_screen_ui = ui


func is_player_owned() -> bool:
	return _player_owned


func configure_player_owned(unit_number: String, occupant_code: String) -> void:
	_player_owned = true
	locked = false
	if _screen_ui != null:
		_screen_ui.set_data(unit_number, occupant_code, HallwayDoorScreenUI.LockStatus.UNLOCKED)


func toggle_lock() -> void:
	if not _player_owned:
		return
	_set_locked(not locked)


func get_interaction_prompt() -> String:
	if _is_open:
		return "Close door [E]" if _player_owned else ""
	if locked and not _player_owned:
		return "Door locked"
	return "Open door [E]"


func _ready() -> void:
	_set_door_open_state(false, true)


func interact() -> void:
	if debug:
		print("[HallwayDoor] interact() on %s owned=%s locked=%s" % [name, _player_owned, locked])
	_screen_ui.register_activity()
	if _is_open:
		if not _player_owned:
			return
		_open_cycle_id += 1
		_set_door_open_state(false, false)
		return
	if locked and not _player_owned:
		return
	_open_door()


func _set_locked(is_locked: bool) -> void:
	locked = is_locked
	if _screen_ui == null:
		return
	var status: HallwayDoorScreenUI.LockStatus = (
		HallwayDoorScreenUI.LockStatus.LOCKED if locked else HallwayDoorScreenUI.LockStatus.UNLOCKED
	)
	_screen_ui.set_data(_screen_ui.unit_number, _screen_ui.occupant_code, status)
	_screen_ui.register_activity()


func _open_door() -> void:
	_set_door_open_state(true, false)
	_play_sfx(DOOR_OPEN_SFX_PATH, DOOR_OPEN_SFX_VOLUME_DB)
	_open_cycle_id += 1
	call_deferred("_attempt_auto_close_after_delay", _open_cycle_id)
	if debug:
		print("[HallwayDoor] opened: %s" % name)


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
	set(BLEND_SHAPE_PROPERTY, _door_progress * open_blend_shape_value)
	_door_collision.disabled = _door_progress >= traversable_at_progress


func _is_player_overlapping_door_frame() -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _door_collision.shape
	params.transform = _door_collision.global_transform
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [_door_body.get_rid()]
	var hits: Array[Dictionary] = space.intersect_shape(params, 16)
	for hit in hits:
		var collider: Object = hit["collider"] as Object
		if collider is CharacterBody3D and collider.name == "PlayerBody":
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
			print("[HallwayDoor] auto-close blocked by frame overlap; retrying")
		await get_tree().create_timer(auto_close_retry_seconds).timeout
		_attempt_auto_close_loop(cycle_id)
		return
	_set_door_open_state(false, false)
	if debug:
		print("[HallwayDoor] auto-closed: %s" % name)


func _play_sfx(path: String, volume_db: float) -> void:
	if not ResourceLoader.exists(path):
		push_warning("[HallwayDoor] Missing SFX file: %s" % path)
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("[HallwayDoor] Failed to load SFX stream: %s" % path)
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = DOOR_OPEN_SFX_PITCH_SCALE
	player.bus = "Master"
	call_deferred("_add_and_play_sfx_player", player)


func _add_and_play_sfx_player(player: AudioStreamPlayer3D) -> void:
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
