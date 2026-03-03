extends CharacterBody3D

## When used on CharacterBody3D with Camera3D child named "PlayerCamera", pitch is applied to camera only.
@onready var _camera: Camera3D = $PlayerCamera if has_node("PlayerCamera") else null
@onready var _raycast: RayCast3D = $PlayerCamera/RayCast3D if has_node("PlayerCamera/RayCast3D") else null

## Interaction range. Raycast target_position is set to this at ready.
@export var interact_range: float = 3.0
## Print to console when E is pressed (hit/miss, target name). Disable for release.
@export var debug_interaction: bool = true

## Horizontal movement speed (units per second).
@export var move_speed: float = 8.0
## Mouse sensitivity for look.
@export var mouse_sensitivity: float = 0.002
## Vertical look limit in radians (prevents camera flip).
@export var pitch_limit: float = 1.4

var _mouse_captured: bool = true
var _dialogue_open: bool = false

func _ready() -> void:
	DialogueManager.dialogue_opened.connect(_on_dialogue_opened)
	DialogueManager.dialogue_closed.connect(_on_dialogue_closed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _raycast:
		_raycast.target_position = Vector3(0, 0, -interact_range)
		_raycast.enabled = true

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _dialogue_open:
			return
		_try_interact()
	if event is InputEventMouseMotion and not _dialogue_open:
		_handle_mouse_look(event.relative)
	if event.is_action_pressed("ui_cancel"):
		if _dialogue_open:
			DialogueManager.close_dialogue()
		else:
			_toggle_mouse_capture()


func _on_dialogue_opened() -> void:
	_dialogue_open = true


func _on_dialogue_closed() -> void:
	_dialogue_open = false


func _try_interact() -> void:
	if debug_interaction:
		print("[Interact] E pressed")
	if not _raycast:
		if debug_interaction:
			print("[Interact] No raycast")
		return
	if not _raycast.is_colliding():
		if debug_interaction:
			print("[Interact] Raycast not hitting anything (look at an interactable)")
		return
	var node: Node = _raycast.get_collider()
	while node:
		if node.has_method("interact"):
			if debug_interaction:
				print("[Interact] Calling interact() on: ", node.name)
			node.interact()
			return
		node = node.get_parent()
	if debug_interaction:
		print("[Interact] Hit something but no interact() found in parent chain: ", _raycast.get_collider().name)

func _physics_process(delta: float) -> void:
	_handle_movement(delta)


func _handle_movement(delta: float) -> void:
	if _dialogue_open:
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
	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed
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
