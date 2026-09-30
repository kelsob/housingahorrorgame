extends CharacterBody3D

## Canonical player controller for Game.tscn’s PlayerBody (CharacterBody3D).
## Attach this script to the CharacterBody3D root; keep Camera3D child named "PlayerCamera" with RayCast3D.
## When used on CharacterBody3D with Camera3D child named "PlayerCamera", pitch is applied to camera only.
@onready var _camera: Camera3D = $PlayerCamera
@onready var _raycast: RayCast3D = $PlayerCamera/RayCast3D
@onready var _intercom: Node = $"../PlayerApartment/Environment/Intercom"
@onready var _game_ui: Control = $"../CanvasLayer/UI"
@onready var _context_prompt: HoldConfirmPrompt = $"../CanvasLayer/UI/HoldConfirmPrompt"

const ACTION_INTERCOM_CLICK: StringName = &"intercom_click"
const ACTION_INTERCOM_EXIT: StringName = &"intercom_exit"
const ACTION_INTERCOM_ADVANCE: StringName = &"intercom_advance"
const ACTION_DOOR_LOCK: StringName = &"door_lock"
const INTERACTABLE_SCRIPT_PATHS: Array[String] = [
	"res://scripts/Intercom.gd",
	"res://scripts/MainDoorInteractable.gd",
	"res://scripts/HallwayDoorInteractable.gd",
	"res://scripts/PlayerRoomDoorInteractable.gd",
	"res://scripts/BedInteractable.gd",
	"res://scripts/BloodDonateButtonInteractable.gd",
	"res://scripts/BloodExtractor.gd",
	"res://scripts/FoodPelletInteractable.gd",
	"res://scripts/FoodDispenser.gd",
	"res://scripts/InteractableTest.gd",
	"res://scripts/WaterFeeder.gd"
]

## Interaction range. Objects may add interact_range_extra on top of this.
@export var interact_range: float = 1.2
## Extra ray length so objects with interact_range_extra can still be aimed at.
@export var interact_ray_extra_cap: float = 4.0
## Print to console when E is pressed (hit/miss, target name). Disable for release.
@export var debug_interaction: bool = true

## Horizontal movement speed (units per second).
@export var move_speed: float = 8.0
## Speed while holding the sprint action (Shift).
@export var sprint_speed: float = 10.5
## Mouse sensitivity for look.
@export var mouse_sensitivity: float = 0.002
## Vertical look limit in radians (prevents camera flip).
@export var pitch_limit: float = 1.4
@export var intercom_camera_tween_seconds: float = 0.35

var _mouse_captured: bool = true
var _intercom_ui_active: bool = false
var _camera_home_local_position: Vector3 = Vector3.ZERO
var _camera_home_local_rotation: Vector3 = Vector3.ZERO
var _intercom_camera_tween: Tween = null

func _ready() -> void:
	_bind_intercom_signals()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_raycast.target_position = Vector3(0, 0, -(interact_range + interact_ray_extra_cap))
	_raycast.collide_with_bodies = true
	_raycast.collide_with_areas = true
	_raycast.enabled = true
	_camera_home_local_position = _camera.position
	_camera_home_local_rotation = _camera.rotation
	if _intercom_ui_active:
		call_deferred("_tween_camera_to_intercom_marker")

func _input(event: InputEvent) -> void:
	if _intercom_ui_active:
		if _route_intercom_pointer_event(event):
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton:
			var button_event: InputEventMouseButton = event as InputEventMouseButton
			if button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT:
				if _try_acknowledge_intercom_terminal_dialogue():
					get_viewport().set_input_as_handled()
					return
				get_viewport().set_input_as_handled()
				return
		if InputMap.has_action(ACTION_INTERCOM_ADVANCE) and event.is_action_pressed(ACTION_INTERCOM_ADVANCE):
			if _try_acknowledge_intercom_terminal_dialogue():
				get_viewport().set_input_as_handled()
				return
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(ACTION_INTERCOM_EXIT) or event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("interact"):
		if _is_input_locked():
			return
		_try_interact()
	if event.is_action_pressed(ACTION_DOOR_LOCK):
		if _is_input_locked():
			return
		_try_toggle_aimed_door_lock()
	if event is InputEventMouseMotion and not _is_input_locked():
		_handle_mouse_look(event.relative)
	if event.is_action_pressed("ui_cancel"):
		_toggle_mouse_capture()


func _try_toggle_aimed_door_lock() -> void:
	var node: Node = get_aimed_interactable()
	if node is HallwayDoorInteractable:
		var door: HallwayDoorInteractable = node as HallwayDoorInteractable
		door.toggle_lock()


func _try_interact() -> void:
	if debug_interaction:
		print("[Interact] E pressed")
	var node: Node = get_aimed_interactable()
	if node == null:
		if debug_interaction:
			if not _raycast:
				print("[Interact] No raycast")
			elif not _raycast.is_colliding():
				print("[Interact] Raycast not hitting anything (look at an interactable)")
			else:
				print("[Interact] Hit out of range or non-interactable")
		return
	if debug_interaction:
		print("[Interact] Calling interact() on: ", node.name)
	node.interact()


## Returns the interactable under the crosshair within that object's effective range, or null.
func get_aimed_interactable() -> Node:
	if not _raycast or not _raycast.is_colliding():
		return null
	var node: Variant = _raycast.get_collider()
	while node and not _is_interactable_node(node):
		node = node.get_parent()
	if node == null:
		return null
	if not _is_within_interact_range(node as Node):
		return null
	return node as Node


func _is_within_interact_range(interactable: Node) -> bool:
	var extra: float = 0.0
	if "interact_range_extra" in interactable:
		extra = float(interactable.get("interact_range_extra"))
	var max_dist: float = interact_range + maxf(extra, 0.0)
	var hit_dist: float = _raycast.get_collision_point().distance_to(_raycast.global_position)
	return hit_dist <= max_dist


func _update_context_prompt() -> void:
	if _is_input_locked():
		_context_prompt.clear()
		return
	var aimed: Node = get_aimed_interactable()
	if aimed == null:
		_context_prompt.clear()
		return
	_context_prompt.show_context(aimed.get_interaction_prompt())


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_update_context_prompt()


func _handle_movement(delta: float) -> void:
	if _is_input_locked():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_back"):
		input_dir.y += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0

	if input_dir == Vector2.ZERO:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	input_dir = input_dir.normalized()

	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var move_dir := (forward * -input_dir.y + right * input_dir.x).normalized()
	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else move_speed
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	velocity.y = 0.0
	move_and_slide()


func _handle_mouse_look(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	if _camera:
		_camera.rotate_object_local(Vector3.RIGHT, -relative.y * mouse_sensitivity)
		var euler := _camera.rotation
		euler.x = clampf(euler.x, -pitch_limit, pitch_limit)
		_camera.rotation = euler
	else:
		rotate_object_local(Vector3.RIGHT, -relative.y * mouse_sensitivity)
		var euler := rotation
		euler.x = clampf(euler.x, -pitch_limit, pitch_limit)
		rotation = euler


func _toggle_mouse_capture() -> void:
	_mouse_captured = not _mouse_captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE


func _is_input_locked() -> bool:
	if _intercom_ui_active:
		return true
	var game: Variant = get_tree().current_scene
	return bool(game.is_door_interaction_active())


func _bind_intercom_signals() -> void:
	_intercom.ui_input_mode_changed.connect(_on_intercom_ui_input_mode_changed)
	_intercom_ui_active = bool(_intercom.is_ui_input_mode_active())


func _on_intercom_ui_input_mode_changed(active: bool) -> void:
	_intercom_ui_active = active
	_game_ui.set_crosshair_visible(not active)
	if _intercom_ui_active:
		_tween_camera_to_intercom_marker()
		# Keep absolute mouse coords for screen raycasts, but hide the OS cursor.
		# IntercomUI $Mouse is the only visible pointer.
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		return
	_tween_camera_to_home_pose()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _route_intercom_pointer_event(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		return bool(_intercom.route_screen_mouse_motion(_camera, motion_event))
	if event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event as InputEventMouseButton
		if button_event.button_index != MOUSE_BUTTON_LEFT:
			return false
		if InputMap.has_action(ACTION_INTERCOM_CLICK) and not button_event.is_action(ACTION_INTERCOM_CLICK):
			return false
		return bool(_intercom.route_screen_mouse_button(_camera, button_event))
	return false


func _cancel_intercom_ui_mode() -> void:
	_intercom.cancel_ui_input_mode()


func _try_acknowledge_intercom_terminal_dialogue() -> bool:
	return bool(_intercom.try_acknowledge_terminal_dialogue_click())


func _tween_camera_to_intercom_marker() -> void:
	var marker: Marker3D = _intercom.player_camera_position
	_kill_intercom_camera_tween_if_active()
	_intercom_camera_tween = create_tween()
	_intercom_camera_tween.tween_property(
		_camera,
		"global_position",
		marker.global_position,
		intercom_camera_tween_seconds
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_intercom_camera_tween.parallel().tween_property(
		_camera,
		"global_rotation",
		marker.global_rotation,
		intercom_camera_tween_seconds
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _tween_camera_to_home_pose() -> void:
	_kill_intercom_camera_tween_if_active()
	_intercom_camera_tween = create_tween()
	_intercom_camera_tween.tween_property(
		_camera,
		"position",
		_camera_home_local_position,
		intercom_camera_tween_seconds
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_intercom_camera_tween.parallel().tween_property(
		_camera,
		"rotation",
		_camera_home_local_rotation,
		intercom_camera_tween_seconds
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _kill_intercom_camera_tween_if_active() -> void:
	if _intercom_camera_tween:
		_intercom_camera_tween.kill()
		_intercom_camera_tween = null


func _is_interactable_node(node: Variant) -> bool:
	var script_ref: Variant = node.get_script()
	if script_ref == null:
		return false
	var script_path: String = str(script_ref.resource_path)
	return script_path in INTERACTABLE_SCRIPT_PATHS
