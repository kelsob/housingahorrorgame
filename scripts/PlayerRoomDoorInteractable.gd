extends Node3D

## Attach to PlayerRoomDoor root. Interact to open/close the bedroom door (slides on X).
## Requires collision on door or a child for raycast to hit.
## Structure: root has "door" child (Node3D) — we slide it on the X-axis.

@export var door_pivot_path: NodePath = ^"door"
@export var open_offset_x: float = 0.705
@export var open_close_duration: float = 0.6
@export var debug: bool = true

var _is_open: bool = false
var _closed_position: Vector3
var _open_position: Vector3


func _ready() -> void:
	var pivot := get_node_or_null(door_pivot_path) as Node3D
	if pivot:
		_closed_position = pivot.position
		_open_position = _closed_position + Vector3(open_offset_x, 0, 0)


func interact() -> void:
	if debug:
		print("[PlayerRoomDoor] interact()")
	_toggle_door()


func _toggle_door() -> void:
	var pivot := get_node_or_null(door_pivot_path) as Node3D
	if not pivot:
		if debug:
			push_warning("[PlayerRoomDoor] door pivot not found: %s" % door_pivot_path)
		return
	_is_open = not _is_open
	var target_pos := _open_position if _is_open else _closed_position
	var tween := create_tween()
	tween.tween_property(pivot, "position", target_pos, open_close_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if debug:
		print("[PlayerRoomDoor] %s" % ["open" if _is_open else "closed"])
