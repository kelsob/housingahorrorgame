extends CanvasGroup

## Put this on a CanvasGroup that parents an AIFace instance.
##
## Scene structure (DialogPopup example):
##   DialogPopup (Control)
##   ├─ AIFaceFocus (CanvasGroup)  <- this script
##   │  └─ AIFace (instance)
##   └─ DialogueText (RichTextLabel)

const FOCUS_SHADER: Shader = preload("res://shaders/ai_face_focus_circle.gdshader")

@onready var ai_face: AIFace = $AIFace

@export_group("Focus Mask")
## Target radius when fully open.
@export_range(1.0, 512.0, 0.5) var focus_radius_px: float = 72.0

@export_range(0.0, 128.0, 0.5) var focus_feather_px: float = 10.0:
	set(value):
		focus_feather_px = value
		_push_static_params()

@export_range(0.0, 1.0, 0.001) var opacity: float = 1.0:
	set(value):
		opacity = value
		_push_static_params()

## Extra offset from AIFace origin, in screen pixels.
@export var focus_center_offset_px: Vector2 = Vector2.ZERO

@export_group("Focus Animation")
@export_range(0.0, 2.0, 0.01) var open_duration: float = 0.25
@export_range(0.0, 2.0, 0.01) var close_duration: float = 0.35

var _current_radius_px: float = 0.0
var _radius_tween: Tween


func _ready() -> void:
	_ensure_material()
	_current_radius_px = 0.0
	_push_static_params()
	_push_radius()


func _process(_delta: float) -> void:
	_push_center()


func expand_focus() -> void:
	_tween_radius_to(focus_radius_px, open_duration)


func shrink_focus(duration: float = -1.0) -> void:
	var use_duration: float = close_duration if duration < 0.0 else duration
	_tween_radius_to(0.0, use_duration)


func reset_focus() -> void:
	if _radius_tween:
		_radius_tween.kill()
		_radius_tween = null
	_current_radius_px = 0.0
	_push_radius()


func _tween_radius_to(target_radius: float, duration: float) -> void:
	if _radius_tween:
		_radius_tween.kill()
	if duration <= 0.0:
		_current_radius_px = target_radius
		_push_radius()
		return
	_radius_tween = create_tween()
	_radius_tween.tween_method(
		_set_current_radius,
		_current_radius_px,
		target_radius,
		duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _set_current_radius(radius: float) -> void:
	_current_radius_px = radius
	_push_radius()


func _ensure_material() -> void:
	var shader_mat := material as ShaderMaterial
	if shader_mat == null or shader_mat.shader != FOCUS_SHADER:
		shader_mat = ShaderMaterial.new()
		shader_mat.shader = FOCUS_SHADER
		material = shader_mat


func _push_static_params() -> void:
	var shader_mat := material as ShaderMaterial
	if shader_mat == null:
		return
	shader_mat.set_shader_parameter("focus_feather_px", focus_feather_px)
	shader_mat.set_shader_parameter("opacity", opacity)
	_push_radius()


func _push_radius() -> void:
	var shader_mat := material as ShaderMaterial
	if shader_mat == null:
		return
	shader_mat.set_shader_parameter("focus_radius_px", _current_radius_px)
	var radius_alpha: float = 0.0
	if focus_radius_px > 0.0:
		radius_alpha = clampf(_current_radius_px / focus_radius_px, 0.0, 1.0)
	var mod := modulate
	mod.a = radius_alpha
	modulate = mod


func _push_center() -> void:
	var shader_mat := material as ShaderMaterial
	if shader_mat == null or ai_face == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var center_px: Vector2 = (
		ai_face.get_global_transform_with_canvas().origin + focus_center_offset_px
	)
	var center_uv := Vector2(center_px.x / viewport_size.x, center_px.y / viewport_size.y)
	shader_mat.set_shader_parameter("focus_center_screen_uv", center_uv)
