extends CharacterBody3D

## FPS-style movement with collision. Move the CharacterBody3D; camera is a child for look.
## Scene structure: CharacterBody3D (this) > CollisionShape3D (CapsuleShape3D), Camera3D (PlayerCamera)

@onready var camera: Camera3D = $PlayerCamera

## Horizontal movement speed (units per second).
@export var move_speed: float = 8.0
## Mouse sensitivity for look.
@export var mouse_sensitivity: float = 0.002
## Vertical look limit in radians (prevents camera flip).
@export var pitch_limit: float = 1.4

var _mouse_captured: bool = true


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_look(event.relative)
	if event.is_action_pressed("ui_cancel"):
		_toggle_mouse_capture()


func _physics_process(delta: float) -> void:
	_handle_movement(delta)


func _handle_movement(delta: float) -> void:
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
	if camera:
		camera.rotate_object_local(Vector3.RIGHT, -relative.y * mouse_sensitivity)
		var euler := camera.rotation
		euler.x = clampf(euler.x, -pitch_limit, pitch_limit)
		camera.rotation = euler


func _toggle_mouse_capture() -> void:
	_mouse_captured = not _mouse_captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE
