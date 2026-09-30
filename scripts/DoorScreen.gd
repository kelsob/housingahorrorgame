class_name DoorScreen
extends SubViewport

## Generic SubViewport → door-screen material.
## Put any Control UI as a child (e.g. HallwayDoorScreenUI). This script does not
## know about that UI — it only exposes the viewport texture as a material.
##
## Prefer instancing DoorScreen.tscn (already has HallwayDoorScreenUI), or:
##   DoorScreenNeighbor (this script)
##   └─ HallwayDoorScreenUI

@export var screen_size: Vector2i = Vector2i(512, 256)


func _ready() -> void:
	if size.x < 2 or size.y < 2:
		size = screen_size
	transparent_bg = true
	handle_input_locally = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Drop to once-per after the first frames so the UI child can draw.
	call_deferred("_settle_render_mode")


func _settle_render_mode() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	render_target_update_mode = SubViewport.UPDATE_ONCE


## Build a screen material backed by this viewport's live texture.
func build_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = get_texture()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material
