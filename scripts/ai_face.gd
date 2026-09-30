extends Node2D
class_name AIFace

## Controller for the AI "globe" face shown on the intercom screen.
##
## Design split (important):
##   - Per-state *sprites/frames* live in each component's SpriteFrames
##     resource (authored in the editor). The controller plays that state's
##     animation name on every face part. Empty frame lists hide the part.
##   - Per-state *behaviour* (vibrate, pitch pop, arm shake, gaze bias)
##     lives in code, triggered by the matching *_now() entry function.
##   - Face states are exclusive: each *_now() replaces the previous until
##     something else overrides it. Spin is the one exception that restores
##     the pre-spin state when it parks.
##
## Expected scene structure (build this in AIFace.tscn):
##   AIFace (Node2D)                     <- this script
##   ├─ FacePivot (Node2D)               <- sway / shake lives here
##   │  ├─ Landmass, Mouth, Blush, Eyes…
##   │  ├─ EyebrowLeft / EyebrowRight    <- feature-wrap material
##   │  └─ Feature                      <- feature-wrap material (vein / steam / etc.)
##   ├─ ArmLeft / HandLeft (Sprite2D)    <- same shoulder pivot; rotated together
##   ├─ ArmRight / HandRight (Sprite2D)
##   └─ Leg / foot sprites               <- authored in editor; code leaves them alone
##
## Feature wrap: SpriteFrames still drive animation (TEXTURE = current frame).

enum GazeMode { AUTO, FIXED, CENTER }
enum ArmBehavior { STILL, BOUNCE, WAVE, FLAP }

const FACE_ANIM_DEFAULT: StringName = &"default"
const FACE_ANIM_ANGRY: StringName = &"angry"
const FACE_ANIM_HOLDING_BACK_TEARS: StringName = &"holdingbacktears"
const FACE_ANIM_SURPRISED: StringName = &"surprised"
const FACE_ANIM_TALKING: StringName = &"talking"
const FACE_ANIM_TALKING_ANGRY: StringName = &"talking_angry"
const FACE_ANIM_TALKING_AGITATED: StringName = &"talking_agitated"
const FACE_ANIM_SPIN: StringName = &"spin"

signal state_changed(state: StringName)
signal talking_changed(is_talking: bool)
signal blinked()

# --- Idle motion ---------------------------------------------------------
@export_group("Idle Motion")
@export var idle_motion_enabled: bool = true
@export var sway_speed: float = 0.9
## Higher = snappier settle onto each state's motion target.
@export var motion_lerp_speed: float = 8.0

# --- Blinking ------------------------------------------------------------
@export_group("Blinking")
@export var blink_enabled: bool = true
@export var blink_interval_min: float = 2.4
@export var blink_interval_max: float = 5.5
@export var blink_close_time: float = 0.06
@export var blink_open_time: float = 0.09
## Eye vertical scale at the fully-closed point of a blink (0 = shut).
@export var blink_closed_scale: float = 0.08

# --- Gaze ----------------------------------------------------------------
@export_group("Gaze")
@export var gaze_mode: GazeMode = GazeMode.AUTO
## Max pupil travel from centre, in the pupil's local pixels.
@export var pupil_max_offset: Vector2 = Vector2(6.0, 4.0)
@export var gaze_lerp_speed: float = 6.0
@export var auto_dart_interval_min: float = 1.2
@export var auto_dart_interval_max: float = 3.8
## Chance an auto dart returns to centre instead of a new random point.
@export var auto_dart_return_chance: float = 0.4

# --- Talking -------------------------------------------------------------
@export_group("Talking")
## Extra vertical mouth scale added at peak speech level while talking.
@export var talk_mouth_scale_pop: float = 0.18
@export var talk_scale_lerp_speed: float = 18.0
## Conversational arm gesture: small intentional up/down from a slight bias pose.
@export var talk_arm_left_bias_degrees: float = 6.0
@export var talk_arm_right_bias_degrees: float = -10.0
@export var talk_arm_gesture_degrees: float = 7.0
@export var talk_arm_gesture_speed: float = 2.4
## Radians of phase lag so the hands don't move in lockstep.
@export var talk_arm_phase_offset: float = 0.85

# --- Angry motion --------------------------------------------------------
@export_group("Angry Motion")
## FacePivot positional jitter (pixels).
@export var angry_face_shake: float = 1.6
## High-frequency brow pitch noise while angry.
@export var angry_brow_pitch_jitter: float = 0.014
@export var angry_brow_jitter_speed: float = 42.0
## Feature vibrate as a fraction of brow jitter — applied to both pitch and yaw.
@export var angry_feature_jitter_scale: float = 0.25
@export var angry_feature_jitter_speed: float = 26.0
## Left arm: tight clenched vibrate around a held pose (degrees from rest).
@export var angry_arm_left_degrees: float = -25.0
@export var angry_arm_vibrate_degrees: float = 3.5
@export var angry_arm_vibrate_speed: float = 30.0
## Right arm: bigger angry shake around a held pose (degrees from rest).
@export var angry_arm_right_degrees: float = 25.0
@export var angry_arm_shake_degrees: float = 10.0
@export var angry_arm_shake_speed: float = 13.0

# --- Holding-back-tears motion -------------------------------------------
@export_group("Holding Back Tears")
## Soft UV wobble on the watery eyes (decal space).
@export var tears_eye_wobble_uv: Vector2 = Vector2(0.006, 0.016)
@export var tears_eye_wobble_speed: float = 5.5
@export var tears_gaze_bias: Vector2 = Vector2(0.0, 0.4)
## Gentle brow tremble (slower / softer than anger).
@export var tears_brow_pitch_jitter: float = 0.006
@export var tears_brow_jitter_speed: float = 7.0
## Arms held to chest (degrees from rest). Tune in the inspector.
@export var tears_arm_left_degrees: float = 35.0
@export var tears_arm_right_degrees: float = -35.0

# --- Surprised enter -----------------------------------------------------
@export_group("Surprised Motion")
## Instant brow pitch pop on enter (negative = up on the globe).
@export var surprised_brow_pitch_pop: float = -0.14
## Smaller eye pitch pop on enter.
@export var surprised_eye_pitch_pop: float = -0.045
## How fast brows/eyes fall back to rest pitch (state art stays surprised).
@export var surprised_pitch_settle_speed: float = 3.2
## Both arms snap up then fall (degrees from rest; mirror L/R).
@export var surprised_arm_left_degrees: float = 58.0
@export var surprised_arm_right_degrees: float = -58.0
@export var surprised_arm_raise_seconds: float = 0.07
@export var surprised_arm_hold_seconds: float = 0.06
@export var surprised_arm_fall_seconds: float = 0.32

# --- Globe / landmass ----------------------------------------------------
@export_group("Globe")
## Slow continuous spin while idle (turns per second). 0 = parked.
@export var globe_idle_drift: float = 0.015
## How fast yaw chases the target when you call set_globe_yaw / spin.
@export var globe_yaw_lerp_speed: float = 4.0
@export var globe_pitch: float = 0.0
## When on, mouth/eyes/blush/brows/feature use spherical yaw wrap.
@export var feature_wrap_enabled: bool = true
## Gaze → UV scroll strength while features are wrapped (turns of the map).
@export var wrap_gaze_uv_strength: Vector2 = Vector2(0.03, 0.02)

@export_subgroup("Rest Pose")
## Face/land yaw rest offset in turns. Negative allowed; wrapped when applied to shaders.
@export_range(-1.0, 1.0, 0.001) var rest_yaw: float = 0.0
## Face/land pitch rest offset. Negative = look down / opposite of positive pop direction.
@export_range(-1.0, 1.0, 0.001) var rest_pitch: float = 0.0


@export_subgroup("Spin Burst")
## Shared starting spin rate for face + landmass (turns per second).
@export var spin_peak_speed: float = 2.8
## Face speed decay rate (higher = brakes harder). Keep slightly above land decel.
@export var spin_face_decel: float = 0.85
## Landmass speed decay rate toward idle drift.
@export var spin_land_decel: float = 0.55
## Decay floor for face speed (curve asymptote). Independent of when it may park.
@export var spin_face_min_speed: float = 0.015
## May stop on yaw 0 once speed <= min_speed + this. Raise to park earlier without changing the curve.
@export var spin_face_stop_threshold: float = 0.08
## Feature wrap radius while the face is still (speed 0).
@export var spin_warp_radius_idle: float = 0.732
## Feature wrap radius at spin_peak_speed; lerps by current face speed.
@export var spin_warp_radius_peak: float = 1.0

# --- Arms ----------------------------------------------------------------
@export_group("Arms")
@export var arms_enabled: bool = true
## How quickly poses ease toward their target (higher = snappier, still smooth).
@export var arm_smooth_speed: float = 7.0
@export var arm_behavior_duration_min: float = 2.5
@export var arm_behavior_duration_max: float = 5.5

@export_subgroup("Bounce")
@export var arm_bounce_degrees: float = 7.0
@export var arm_bounce_speed: float = 1.5
@export var arm_bounce_left_sign: float = 1.0
@export var arm_bounce_right_sign: float = -1.0

@export_subgroup("Wave")
@export var arm_wave_left_degrees: float = 22.0
@export var arm_wave_right_degrees: float = -40.0
@export var arm_wave_wiggle_degrees: float = 12.0
@export var arm_wave_wiggle_count: int = 3
@export var arm_wave_raise_seconds: float = 0.35
@export var arm_wave_wiggle_seconds: float = 0.16
@export var arm_wave_hold_seconds: float = 0.12

@export_subgroup("Flap")
@export var arm_flap_degrees: float = 18.0
@export var arm_flap_count_min: int = 3
@export var arm_flap_count_max: int = 5
@export var arm_flap_seconds: float = 0.14

@export_subgroup("Spin Pin")
## Arm angles (degrees from rest) when face spin is at peak speed. Ease back as speed drops.
@export var arm_spin_pin_left_degrees: float = 55.0
@export var arm_spin_pin_right_degrees: float = -55.0

# --- Instance behavior (per AIFace placement) -----------------------------
## Tune on each scene instance (BloodGod panel, dialogue, etc.).
@export_group("Instance Behavior")
## If on, apply idle expression + arm mood once in _ready (machine screens). Leave off for dialogue-driven faces.
@export var apply_idle_on_ready: bool = false
@export var idle_expression: StringName = FACE_ANIM_DEFAULT
## NORMAL = calm shuffle (still/bounce/flap/wave). EXCITED = no still, extra waves — greeter vibes.
@export_enum("NORMAL", "EXCITED") var idle_arm_mood: int = 0

@export_subgroup("Celebrate")
@export var celebrate_spin: bool = true
## Optional emotion held after the spin parks. Leave matching idle_expression to avoid a visible flash.
@export var celebrate_expression: StringName = FACE_ANIM_DEFAULT
## Extra hold after spin parks (or immediately if spin is off), then optional return to idle.
@export var celebrate_hold_seconds: float = 0.35
@export var celebrate_return_to_idle: bool = true

# --- Node references (hard-coded paths) ----------------------------------
@onready var face_pivot: Node2D = $FacePivot
@onready var landmass: Sprite2D = $FacePivot/Landmass
@onready var mouth: AnimatedSprite2D = $FacePivot/Mouth
@onready var blush: AnimatedSprite2D = $FacePivot/Blush
@onready var eye_left: Node2D = $FacePivot/EyeLeft
@onready var eye_right: Node2D = $FacePivot/EyeRight
@onready var eye_pupil_left: AnimatedSprite2D = $FacePivot/EyeLeft/EyePupilLeft
@onready var eye_pupil_right: AnimatedSprite2D = $FacePivot/EyeRight/EyePupilRight
@onready var eyebrow_left: AnimatedSprite2D = $FacePivot/EyebrowLeft
@onready var eyebrow_right: AnimatedSprite2D = $FacePivot/EyebrowRight
@onready var feature: AnimatedSprite2D = $FacePivot/Feature
@onready var arm_left: Sprite2D = $ArmLeft
@onready var arm_right: Sprite2D = $ArmRight
@onready var hand_left: Sprite2D = $HandLeft
@onready var hand_right: Sprite2D = $HandRight

var _land_material: ShaderMaterial
var _feature_wrap_materials: Array[ShaderMaterial] = []
var _brow_materials: Array[ShaderMaterial] = []
var _eye_materials: Array[ShaderMaterial] = []
var _other_feature_materials: Array[ShaderMaterial] = []
var _feature_material: ShaderMaterial
var _pupil_left_material: ShaderMaterial
var _pupil_right_material: ShaderMaterial
var _globe_yaw: float = 0.0
var _globe_yaw_target: float = 0.0
var _globe_spin_velocity: float = 0.0
var _land_spin_speed: float = 0.0
var _face_spin_speed: float = 0.0
var _face_yaw: float = 0.0
var _face_spinning: bool = false
var _spin_active: bool = false

## Every AnimatedSprite2D that plays face-state animations.
var _expressive_sprites: Array[AnimatedSprite2D] = []

var _face_state: StringName = FACE_ANIM_DEFAULT
## State to restore when a spin burst parks.
var _resume_state_after_spin: StringName = FACE_ANIM_DEFAULT
var _speech_level: float = 0.0
## When true, mouth frames advance only via advance_mouth_for_syllable().
var _syllable_mouth_sync: bool = false

# Captured editor-authored base transforms.
var _pivot_base_pos: Vector2 = Vector2.ZERO
var _pivot_base_scale: Vector2 = Vector2.ONE
var _eye_left_base_scale: Vector2 = Vector2.ONE
var _eye_right_base_scale: Vector2 = Vector2.ONE
var _pupil_left_base: Vector2 = Vector2.ZERO
var _pupil_right_base: Vector2 = Vector2.ZERO
var _mouth_base_scale: Vector2 = Vector2.ONE

# Smoothed procedural state.
var _time: float = 0.0
var _pivot_pos: Vector2 = Vector2.ZERO
var _pivot_rot: float = 0.0
var _pivot_scale: Vector2 = Vector2.ONE
var _gaze_current: Vector2 = Vector2.ZERO
var _gaze_target: Vector2 = Vector2.ZERO
var _mouth_scale_current: float = 1.0
var _brow_pitch: float = 0.0
var _eye_pitch: float = 0.0
var _feature_pitch: float = 0.0
var _feature_yaw_jitter: float = 0.0

# Additive gesture offsets (nod / shake head) that compose with idle motion.
var _gesture_offset_pos: Vector2 = Vector2.ZERO
var _gesture_offset_rot: float = 0.0

# Countdown timers.
var _blink_countdown: float = 0.0
var _dart_countdown: float = 0.0

var _blink_tween: Tween = null
var _gesture_tween: Tween = null

var _arm_left_base_rot: float = 0.0
var _arm_right_base_rot: float = 0.0
var _arm_left_pose: float = 0.0
var _arm_right_pose: float = 0.0
var _arm_left_target: float = 0.0
var _arm_right_target: float = 0.0
var _arm_behavior: ArmBehavior = ArmBehavior.STILL
var _arm_behavior_countdown: float = 0.0
var _arm_gesture_time: float = 0.0
var _arm_flap_total: int = 3
var _arm_gesture_start_left: float = 0.0
var _arm_gesture_start_right: float = 0.0
## Shuffle-bag of behaviors; refills only after every option has played once.
var _arm_behavior_queue: Array[ArmBehavior] = []
var _surprise_arm_active: bool = false
var _surprise_arm_time: float = 0.0
## Bumps when a new instance reaction starts so older awaits bail out.
var _behavior_token: int = 0


func _ready() -> void:
	_make_materials_instance_local()
	_land_material = landmass.material as ShaderMaterial
	_cache_feature_wrap_materials()
	_capture_base_transforms()
	_expressive_sprites = [
		mouth,
		blush,
		eye_pupil_left,
		eye_pupil_right,
		eyebrow_left,
		eyebrow_right,
		feature,
	]
	_pivot_pos = _pivot_base_pos
	_pivot_scale = _pivot_base_scale
	_blink_countdown = randf_range(blink_interval_min, blink_interval_max)
	_dart_countdown = randf_range(auto_dart_interval_min, auto_dart_interval_max)
	_refill_arm_behavior_queue()
	_begin_arm_behavior(_pick_arm_behavior())
	_land_spin_speed = globe_idle_drift
	set_feature_wrap_enabled(feature_wrap_enabled)
	_apply_globe_uniforms()
	_refresh_face_anims()
	if apply_idle_on_ready:
		apply_idle_behavior()


## PackedScene materials are shared across AIFace instances by default. Duplicate so
## rest_yaw / rest_pitch / spin on one face (e.g. DialoguePopup) cannot drive another (BloodGod).
func _make_materials_instance_local() -> void:
	landmass.material = landmass.material.duplicate()
	mouth.material = mouth.material.duplicate()
	blush.material = blush.material.duplicate()
	feature.material = feature.material.duplicate()
	var eye_mat: Material = eye_pupil_left.material.duplicate()
	eye_pupil_left.material = eye_mat
	eye_pupil_right.material = eye_mat
	var brow_mat: Material = eyebrow_left.material.duplicate()
	eyebrow_left.material = brow_mat
	eyebrow_right.material = brow_mat


func _cache_feature_wrap_materials() -> void:
	_pupil_left_material = eye_pupil_left.material as ShaderMaterial
	_pupil_right_material = eye_pupil_right.material as ShaderMaterial
	_feature_material = feature.material as ShaderMaterial
	var brow_left_mat: ShaderMaterial = eyebrow_left.material as ShaderMaterial
	var brow_right_mat: ShaderMaterial = eyebrow_right.material as ShaderMaterial
	var mouth_mat: ShaderMaterial = mouth.material as ShaderMaterial
	var blush_mat: ShaderMaterial = blush.material as ShaderMaterial

	_eye_materials.assign([_pupil_left_material, _pupil_right_material])
	_brow_materials.assign([brow_left_mat, brow_right_mat])
	_other_feature_materials.assign([mouth_mat, blush_mat])
	_feature_wrap_materials.assign([
		_pupil_left_material,
		_pupil_right_material,
		brow_left_mat,
		brow_right_mat,
		mouth_mat,
		blush_mat,
		_feature_material,
	])


func _capture_base_transforms() -> void:
	_pivot_base_pos = face_pivot.position
	_pivot_base_scale = face_pivot.scale
	_eye_left_base_scale = eye_left.scale
	_eye_right_base_scale = eye_right.scale
	_pupil_left_base = eye_pupil_left.position
	_pupil_right_base = eye_pupil_right.position
	_mouth_base_scale = mouth.scale
	_arm_left_base_rot = arm_left.rotation
	_arm_right_base_rot = arm_right.rotation


func _process(delta: float) -> void:
	_time += delta
	var smooth: float = 1.0 - exp(-motion_lerp_speed * delta)
	_update_pivot(smooth)
	_update_feature_pitch(delta)
	_update_gaze(delta)
	_update_blink(delta)
	_update_talk(delta)
	_update_globe(delta)
	_update_arms(delta)


# --- Pivot motion --------------------------------------------------------
func _update_pivot(smooth: float) -> void:
	var target_pos: Vector2 = _pivot_base_pos
	if idle_motion_enabled:
		target_pos.x += sin(_time * sway_speed) * _state_sway_amplitude()

	_pivot_pos = _pivot_pos.lerp(target_pos, smooth)
	_pivot_scale = _pivot_base_scale
	_pivot_rot = lerp_angle(_pivot_rot, deg_to_rad(_state_tilt_degrees()), smooth)

	var shake: Vector2 = Vector2.ZERO
	var shake_amount: float = _state_shake_amount()
	if shake_amount > 0.0:
		shake = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)

	face_pivot.position = _pivot_pos + shake + _gesture_offset_pos
	#face_pivot.rotation = _pivot_rot + _gesture_offset_rot
	face_pivot.scale = _pivot_scale


func _is_talk_state(state: StringName = _face_state) -> bool:
	return String(state).begins_with("talking")


func _state_sway_amplitude() -> float:
	if _is_talk_state():
		return 1.2
	match _face_state:
		FACE_ANIM_ANGRY:
			return 0.45
		FACE_ANIM_HOLDING_BACK_TEARS:
			return 0.7
		FACE_ANIM_SURPRISED:
			return 0.9
		FACE_ANIM_SPIN:
			return 0.0
		_:
			return 1.5


func _state_tilt_degrees() -> float:
	return 0.0


func _state_shake_amount() -> float:
	if _face_state == FACE_ANIM_ANGRY:
		return angry_face_shake
	return 0.0


func _state_gaze_bias() -> Vector2:
	match _face_state:
		FACE_ANIM_ANGRY:
			return Vector2(0.0, -0.12)
		FACE_ANIM_HOLDING_BACK_TEARS:
			return tears_gaze_bias
		FACE_ANIM_SURPRISED:
			return Vector2(0.0, -0.2)
		_:
			return Vector2.ZERO


# --- Feature pitch (surprised pop / angry jitter / tears tremble) --------
func _update_feature_pitch(delta: float) -> void:
	match _face_state:
		FACE_ANIM_SURPRISED:
			var settle: float = 1.0 - exp(-surprised_pitch_settle_speed * delta)
			_brow_pitch = lerpf(_brow_pitch, 0.0, settle)
			_eye_pitch = lerpf(_eye_pitch, 0.0, settle)
			_feature_pitch = lerpf(_feature_pitch, 0.0, settle)
			_feature_yaw_jitter = lerpf(_feature_yaw_jitter, 0.0, settle)
		FACE_ANIM_ANGRY:
			_brow_pitch = (
				sin(_time * angry_brow_jitter_speed) * angry_brow_pitch_jitter
				+ randf_range(-angry_brow_pitch_jitter, angry_brow_pitch_jitter) * 0.35
			)
			_eye_pitch = 0.0
			var feature_amp: float = angry_brow_pitch_jitter * angry_feature_jitter_scale
			_feature_pitch = (
				sin(_time * angry_feature_jitter_speed) * feature_amp
				+ randf_range(-feature_amp, feature_amp) * 0.25
			)
			_feature_yaw_jitter = (
				sin(_time * angry_feature_jitter_speed * 1.17 + 1.3) * feature_amp
				+ randf_range(-feature_amp, feature_amp) * 0.25
			)
		FACE_ANIM_HOLDING_BACK_TEARS:
			_brow_pitch = sin(_time * tears_brow_jitter_speed) * tears_brow_pitch_jitter
			_eye_pitch = sin(_time * tears_eye_wobble_speed * 0.85) * tears_brow_pitch_jitter * 0.5
			_feature_pitch = 0.0
			_feature_yaw_jitter = 0.0
		_:
			var ease_out: float = 1.0 - exp(-surprised_pitch_settle_speed * delta)
			_brow_pitch = lerpf(_brow_pitch, 0.0, ease_out)
			_eye_pitch = lerpf(_eye_pitch, 0.0, ease_out)
			_feature_pitch = lerpf(_feature_pitch, 0.0, ease_out)
			_feature_yaw_jitter = lerpf(_feature_yaw_jitter, 0.0, ease_out)


# --- Arms / hands --------------------------------------------------------
func _update_arms(delta: float) -> void:
	if not arms_enabled:
		return
	if _surprise_arm_active:
		_surprise_arm_time += delta
		_compute_surprise_arm_targets()
		# Drive pose directly so the snap-up isn't dulled by arm_smooth_speed.
		_arm_left_pose = _arm_left_target
		_arm_right_pose = _arm_right_target
		_apply_arm_rotations()
		return
	if _face_state == FACE_ANIM_ANGRY:
		_compute_angry_arm_targets()
	elif _face_state == FACE_ANIM_HOLDING_BACK_TEARS:
		_arm_left_target = deg_to_rad(tears_arm_left_degrees)
		_arm_right_target = deg_to_rad(tears_arm_right_degrees)
	elif _is_talk_state():
		_compute_talk_arm_targets()
	elif _face_state == FACE_ANIM_SURPRISED:
		# After the enter raise/fall, stay parked at rest (no wave/bounce/flap).
		_arm_left_target = 0.0
		_arm_right_target = 0.0
	elif not _face_spinning:
		_advance_arm_behavior(delta)
		_compute_arm_targets()
	_apply_spin_arm_pin()
	var smooth: float = 1.0 - exp(-arm_smooth_speed * delta)
	_arm_left_pose = lerpf(_arm_left_pose, _arm_left_target, smooth)
	_arm_right_pose = lerpf(_arm_right_pose, _arm_right_target, smooth)
	_apply_arm_rotations()


func _compute_angry_arm_targets() -> void:
	# Hold at configured pose, vibrate around it (left tight, right bigger shake).
	_arm_left_target = (
		deg_to_rad(angry_arm_left_degrees)
		+ sin(_time * angry_arm_vibrate_speed) * deg_to_rad(angry_arm_vibrate_degrees)
	)
	_arm_right_target = (
		deg_to_rad(angry_arm_right_degrees)
		+ sin(_time * angry_arm_shake_speed) * deg_to_rad(angry_arm_shake_degrees)
	)


func _compute_talk_arm_targets() -> void:
	# Soft, intentional up/down around a slight “mid-gesture” bias — not idle bob.
	var phase_l: float = _time * talk_arm_gesture_speed * TAU
	var phase_r: float = phase_l + talk_arm_phase_offset
	var amp: float = deg_to_rad(talk_arm_gesture_degrees)
	_arm_left_target = deg_to_rad(talk_arm_left_bias_degrees) + _talk_gesture_wave(phase_l) * amp
	_arm_right_target = deg_to_rad(talk_arm_right_bias_degrees) + _talk_gesture_wave(phase_r) * amp


func _talk_gesture_wave(phase: float) -> float:
	# Punchier than raw sine: hangs near the extremes a bit (more “said with the hands”).
	var s: float = sin(phase)
	return signf(s) * pow(absf(s), 0.55)


func _compute_surprise_arm_targets() -> void:
	var left_up: float = deg_to_rad(surprised_arm_left_degrees)
	var right_up: float = deg_to_rad(surprised_arm_right_degrees)
	var raise_end: float = surprised_arm_raise_seconds
	var hold_end: float = raise_end + surprised_arm_hold_seconds
	var fall_end: float = hold_end + surprised_arm_fall_seconds
	var t: float = _surprise_arm_time

	if t < raise_end:
		# Ease-out: shoots up fast, eases into the peak.
		var u: float = _smoothstep01(t / maxf(raise_end, 0.001))
		u = 1.0 - (1.0 - u) * (1.0 - u)
		_arm_left_target = lerpf(_arm_gesture_start_left, left_up, u)
		_arm_right_target = lerpf(_arm_gesture_start_right, right_up, u)
	elif t < hold_end:
		_arm_left_target = left_up
		_arm_right_target = right_up
	elif t < fall_end:
		var u: float = _smoothstep01((t - hold_end) / maxf(surprised_arm_fall_seconds, 0.001))
		_arm_left_target = lerpf(left_up, 0.0, u)
		_arm_right_target = lerpf(right_up, 0.0, u)
	else:
		_surprise_arm_active = false
		_arm_left_target = 0.0
		_arm_right_target = 0.0


func _begin_surprise_arm_raise() -> void:
	_surprise_arm_active = true
	_surprise_arm_time = 0.0
	_arm_gesture_start_left = _arm_left_pose
	_arm_gesture_start_right = _arm_right_pose


func _apply_spin_arm_pin() -> void:
	var peak: float = maxf(spin_peak_speed, 0.001)
	var pin_t: float = clampf(_face_spin_speed / peak, 0.0, 1.0)
	if pin_t <= 0.0:
		return
	var pin_left: float = deg_to_rad(arm_spin_pin_left_degrees)
	var pin_right: float = deg_to_rad(arm_spin_pin_right_degrees)
	_arm_left_target = lerpf(_arm_left_target, pin_left, pin_t)
	_arm_right_target = lerpf(_arm_right_target, pin_right, pin_t)


func _advance_arm_behavior(delta: float) -> void:
	_arm_gesture_time += delta
	match _arm_behavior:
		ArmBehavior.STILL, ArmBehavior.BOUNCE:
			_arm_behavior_countdown -= delta
			if _arm_behavior_countdown <= 0.0:
				_begin_arm_behavior(_pick_arm_behavior())
		ArmBehavior.WAVE:
			if _arm_gesture_time >= _wave_total_seconds():
				_begin_arm_behavior(_pick_arm_behavior())
		ArmBehavior.FLAP:
			if _arm_gesture_time >= _flap_total_seconds():
				_begin_arm_behavior(_pick_arm_behavior())


func _begin_arm_behavior(behavior: ArmBehavior) -> void:
	_arm_behavior = behavior
	_arm_gesture_time = 0.0
	_arm_gesture_start_left = _arm_left_pose
	_arm_gesture_start_right = _arm_right_pose
	match behavior:
		ArmBehavior.STILL, ArmBehavior.BOUNCE:
			var dur_min: float = arm_behavior_duration_min
			var dur_max: float = arm_behavior_duration_max
			if idle_arm_mood == 1:
				dur_min *= 0.55
				dur_max *= 0.65
			_arm_behavior_countdown = randf_range(dur_min, dur_max)
		ArmBehavior.FLAP:
			_arm_flap_total = randi_range(arm_flap_count_min, arm_flap_count_max)
		ArmBehavior.WAVE:
			pass


func _refill_arm_behavior_queue() -> void:
	var next_queue: Array[ArmBehavior] = []
	if idle_arm_mood == 1:
		# Excited greeter: keep moving — bounce, flap, and wave a lot. No still.
		next_queue = [
			ArmBehavior.BOUNCE,
			ArmBehavior.WAVE,
			ArmBehavior.FLAP,
			ArmBehavior.WAVE,
			ArmBehavior.BOUNCE,
		]
	else:
		next_queue = [
			ArmBehavior.STILL,
			ArmBehavior.BOUNCE,
			ArmBehavior.FLAP,
		]
		# No waving while talking / angry / holding back tears.
		if (
			not _is_talk_state()
			and _face_state != FACE_ANIM_ANGRY
			and _face_state != FACE_ANIM_HOLDING_BACK_TEARS
		):
			next_queue.append(ArmBehavior.WAVE)
	for i in range(next_queue.size() - 1, 0, -1):
		var j: int = randi_range(0, i)
		var tmp: ArmBehavior = next_queue[i]
		next_queue[i] = next_queue[j]
		next_queue[j] = tmp
	# Don't start a fresh cycle on the same behavior we just finished.
	if next_queue.size() > 1 and next_queue[0] == _arm_behavior:
		var swap_i: int = randi_range(1, next_queue.size() - 1)
		var swap_tmp: ArmBehavior = next_queue[0]
		next_queue[0] = next_queue[swap_i]
		next_queue[swap_i] = swap_tmp
	_arm_behavior_queue = next_queue


func _pick_arm_behavior() -> ArmBehavior:
	if _arm_behavior_queue.is_empty():
		_refill_arm_behavior_queue()
	return _arm_behavior_queue.pop_front()


func _compute_arm_targets() -> void:
	match _arm_behavior:
		ArmBehavior.STILL:
			_arm_left_target = 0.0
			_arm_right_target = 0.0
		ArmBehavior.BOUNCE:
			var bob: float = sin(_time * arm_bounce_speed) * deg_to_rad(arm_bounce_degrees)
			_arm_left_target = bob * arm_bounce_left_sign
			_arm_right_target = bob * arm_bounce_right_sign
		ArmBehavior.WAVE:
			_compute_wave_targets()
		ArmBehavior.FLAP:
			_compute_flap_targets()


func _compute_wave_targets() -> void:
	var left_pose: float = deg_to_rad(arm_wave_left_degrees)
	var right_pose: float = deg_to_rad(arm_wave_right_degrees)
	var wiggle: float = deg_to_rad(arm_wave_wiggle_degrees)
	var t: float = _arm_gesture_time
	var raise_end: float = arm_wave_raise_seconds
	var wiggle_end: float = raise_end + float(arm_wave_wiggle_count) * arm_wave_wiggle_seconds
	var hold_end: float = wiggle_end + arm_wave_hold_seconds
	if t < raise_end:
		# Blend from whatever pose we were in — no dip to zero.
		var u: float = _smoothstep01(t / maxf(raise_end, 0.001))
		_arm_left_target = lerpf(_arm_gesture_start_left, left_pose, u)
		_arm_right_target = lerpf(_arm_gesture_start_right, right_pose, u)
	elif t < wiggle_end:
		_arm_left_target = left_pose
		var wig_t: float = t - raise_end
		var idx: int = int(wig_t / maxf(arm_wave_wiggle_seconds, 0.001))
		var local_u: float = fposmod(wig_t, arm_wave_wiggle_seconds) / maxf(arm_wave_wiggle_seconds, 0.001)
		var swing: float = sin(local_u * PI) * wiggle
		if idx % 2 == 1:
			swing = -swing
		_arm_right_target = right_pose + swing
	elif t < hold_end:
		_arm_left_target = left_pose
		_arm_right_target = right_pose
	else:
		# Soft return home; outer exponential lerp kills the old hard jolt.
		_arm_left_target = 0.0
		_arm_right_target = 0.0


func _wave_total_seconds() -> float:
	return (
		arm_wave_raise_seconds
		+ float(arm_wave_wiggle_count) * arm_wave_wiggle_seconds
		+ arm_wave_hold_seconds
		+ (3.0 / maxf(arm_smooth_speed, 0.1))
	)


func _compute_flap_targets() -> void:
	var amp: float = deg_to_rad(arm_flap_degrees)
	var period: float = maxf(arm_flap_seconds, 0.001)
	var t: float = _arm_gesture_time
	var active_end: float = float(_arm_flap_total) * period
	if t >= active_end:
		_arm_left_target = 0.0
		_arm_right_target = 0.0
		return
	# Symmetric flaps: both sides mirror, soft sine per beat.
	var local_u: float = fposmod(t, period) / period
	var flap: float = sin(local_u * PI) * amp
	_arm_left_target = flap
	_arm_right_target = -flap


func _flap_total_seconds() -> float:
	return float(_arm_flap_total) * maxf(arm_flap_seconds, 0.001) + (3.0 / maxf(arm_smooth_speed, 0.1))


func _smoothstep01(x: float) -> float:
	var t: float = clampf(x, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _apply_arm_rotations() -> void:
	var left_rot: float = _arm_left_base_rot + _arm_left_pose
	var right_rot: float = _arm_right_base_rot + _arm_right_pose
	arm_left.rotation = left_rot
	hand_left.rotation = left_rot
	arm_right.rotation = right_rot
	hand_right.rotation = right_rot


## Force a wave gesture (smoothly interrupts the current behavior).
func wave_now() -> void:
	if not arms_enabled:
		return
	if (
		_is_talk_state()
		or _face_state == FACE_ANIM_ANGRY
		or _face_state == FACE_ANIM_HOLDING_BACK_TEARS
		or _face_spinning
	):
		return
	_begin_arm_behavior(ArmBehavior.WAVE)


## Force a flap burst.
func flap_now() -> void:
	if not arms_enabled or _face_state == FACE_ANIM_ANGRY:
		return
	_begin_arm_behavior(ArmBehavior.FLAP)


func _update_gaze(delta: float) -> void:
	match gaze_mode:
		GazeMode.CENTER:
			_gaze_target = Vector2.ZERO
		GazeMode.AUTO:
			_dart_countdown -= delta
			if _dart_countdown <= 0.0:
				_dart_countdown = randf_range(auto_dart_interval_min, auto_dart_interval_max)
				if randf() < auto_dart_return_chance:
					_gaze_target = Vector2.ZERO
				else:
					_gaze_target = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		GazeMode.FIXED:
			pass  # _gaze_target is driven externally via set_gaze / look_at_global.

	var biased_target: Vector2 = (_gaze_target + _state_gaze_bias())
	biased_target.x = clampf(biased_target.x, -1.0, 1.0)
	biased_target.y = clampf(biased_target.y, -1.0, 1.0)
	var smooth: float = 1.0 - exp(-gaze_lerp_speed * delta)
	_gaze_current = _gaze_current.lerp(biased_target, smooth)

	var tears_wobble: Vector2 = Vector2.ZERO
	if _face_state == FACE_ANIM_HOLDING_BACK_TEARS:
		tears_wobble = Vector2(
			sin(_time * tears_eye_wobble_speed * 1.15) * tears_eye_wobble_uv.x,
			sin(_time * tears_eye_wobble_speed) * tears_eye_wobble_uv.y
		)

	if feature_wrap_enabled:
		# Wrapped pupils are full-globe quads; gaze scrolls UV instead of moving nodes.
		eye_pupil_left.position = _pupil_left_base
		eye_pupil_right.position = _pupil_right_base
		var uv_scroll: Vector2 = Vector2(
			_gaze_current.x * wrap_gaze_uv_strength.x,
			_gaze_current.y * wrap_gaze_uv_strength.y
		) + tears_wobble
		_pupil_left_material.set_shader_parameter("uv_offset", uv_scroll)
		_pupil_right_material.set_shader_parameter("uv_offset", uv_scroll)
	else:
		var offset: Vector2 = Vector2(
			_gaze_current.x * pupil_max_offset.x,
			_gaze_current.y * pupil_max_offset.y
		)
		eye_pupil_left.position = _pupil_left_base + offset
		eye_pupil_right.position = _pupil_right_base + offset
		_pupil_left_material.set_shader_parameter("uv_offset", tears_wobble)
		_pupil_right_material.set_shader_parameter("uv_offset", tears_wobble)


# --- Blinking ------------------------------------------------------------
## Blinks work in every face state (idle / talking / spin / expression).
func _update_blink(delta: float) -> void:
	if not blink_enabled:
		return
	_blink_countdown -= delta
	if _blink_countdown <= 0.0:
		_blink_countdown = randf_range(blink_interval_min, blink_interval_max)
		blink_now()


func blink_now() -> void:
	if not blink_enabled:
		return
	if _blink_tween != null and _blink_tween.is_running():
		return
	_blink_tween = create_tween()
	_blink_tween.tween_method(_set_eye_openness, 1.0, blink_closed_scale, blink_close_time)
	_blink_tween.tween_method(_set_eye_openness, blink_closed_scale, 1.0, blink_open_time)
	blinked.emit()


func _set_eye_openness(value: float) -> void:
	eye_left.scale = Vector2(_eye_left_base_scale.x, _eye_left_base_scale.y * value)
	eye_right.scale = Vector2(_eye_right_base_scale.x, _eye_right_base_scale.y * value)


# --- Talking mouth scale -------------------------------------------------
func _update_talk(delta: float) -> void:
	if feature_wrap_enabled:
		mouth.scale = _mouth_base_scale
		return
	var target: float = 1.0
	if _is_talk_state():
		target = 1.0 + _speech_level * talk_mouth_scale_pop
	var smooth: float = 1.0 - exp(-talk_scale_lerp_speed * delta)
	_mouth_scale_current = lerpf(_mouth_scale_current, target, smooth)
	mouth.scale = Vector2(_mouth_base_scale.x, _mouth_base_scale.y * _mouth_scale_current)


func _refresh_face_anims() -> void:
	_play_face_anim(_face_state)


## Play `anim_name` on every face part. Empty SpriteFrames lists hide the part.
func _play_face_anim(anim_name: StringName) -> void:
	for sprite in _expressive_sprites:
		_play_part_anim(sprite, anim_name)


func _play_part_anim(sprite: AnimatedSprite2D, anim_name: StringName) -> void:
	var frames: SpriteFrames = sprite.sprite_frames
	if frames.get_frame_count(anim_name) <= 0:
		sprite.visible = false
		return
	sprite.visible = true
	sprite.play(anim_name)
	if sprite == mouth and _syllable_mouth_sync:
		mouth.pause()
		mouth.frame = 0


# --- Globe / landmass ----------------------------------------------------
func _update_globe(delta: float) -> void:
	if _spin_active:
		_update_spin_burst(delta)
	else:
		# Direct integrate — never chase-lerp idle drift (that looked like a full stop).
		if _globe_spin_velocity != 0.0:
			_land_spin_speed = _globe_spin_velocity
		else:
			_land_spin_speed = globe_idle_drift
		_globe_yaw = fposmod(_globe_yaw + _land_spin_speed * delta, 1.0)
		_globe_yaw_target = _globe_yaw
	_apply_globe_uniforms()


func _update_spin_burst(delta: float) -> void:
	var idle_speed: float = globe_idle_drift

	# Landmass: same peak start, slower decay, floor at idle drift.
	var land_decay: float = 1.0 - exp(-spin_land_decel * delta)
	_land_spin_speed = lerpf(_land_spin_speed, idle_speed, land_decay)
	_land_spin_speed = maxf(_land_spin_speed, idle_speed)
	_globe_yaw = fposmod(_globe_yaw + _land_spin_speed * delta, 1.0)
	_globe_yaw_target = _globe_yaw

	if _face_spinning:
		_update_face_spin(delta)

	if not _face_spinning:
		_spin_active = false
		_globe_spin_velocity = 0.0
		_land_spin_speed = maxf(_land_spin_speed, idle_speed)


func _update_face_spin(delta: float) -> void:
	var min_speed: float = maxf(spin_face_min_speed, 0.0)
	# Decay toward min speed (faster than land), never below min while spinning.
	var face_decay: float = 1.0 - exp(-spin_face_decel * delta)
	_face_spin_speed = lerpf(_face_spin_speed, min_speed, face_decay)
	_face_spin_speed = maxf(_face_spin_speed, min_speed)

	var step: float = _face_spin_speed * delta
	var prev_yaw: float = _face_yaw

	# Park on the next yaw-0 crossing once we're close enough to min speed.
	# Threshold is separate from min_speed so you can retune the stop without reshaping the curve.
	var can_park: bool = _face_spin_speed <= min_speed + maxf(spin_face_stop_threshold, 0.0)
	if can_park and prev_yaw + step >= 1.0:
		_face_yaw = 0.0
		_face_spin_speed = 0.0
		_face_spinning = false
		_set_face_state(_resume_state_after_spin, false)
		return

	_face_yaw = fposmod(prev_yaw + step, 1.0)


func _apply_globe_uniforms() -> void:
	var yaw_face: float = fposmod(_face_yaw + rest_yaw, 1.0)
	var yaw_land: float = fposmod(_globe_yaw + rest_yaw, 1.0)
	_land_material.set_shader_parameter("yaw", yaw_land)
	_land_material.set_shader_parameter("pitch", globe_pitch + rest_pitch)
	var warp_radius: float = _face_warp_radius_for_speed()
	for mat in _other_feature_materials:
		mat.set_shader_parameter("yaw", yaw_face)
		mat.set_shader_parameter("pitch", rest_pitch)
		mat.set_shader_parameter("warp_radius", warp_radius)
	_feature_material.set_shader_parameter(
		"yaw",
		fposmod(_face_yaw + _feature_yaw_jitter + rest_yaw, 1.0)
	)
	_feature_material.set_shader_parameter("pitch", rest_pitch + _feature_pitch)
	_feature_material.set_shader_parameter("warp_radius", warp_radius)
	for mat in _brow_materials:
		mat.set_shader_parameter("yaw", yaw_face)
		mat.set_shader_parameter("pitch", rest_pitch + _brow_pitch)
		mat.set_shader_parameter("warp_radius", warp_radius)
	for mat in _eye_materials:
		mat.set_shader_parameter("yaw", yaw_face)
		mat.set_shader_parameter("pitch", rest_pitch + _eye_pitch)
		mat.set_shader_parameter("warp_radius", warp_radius)


func _face_warp_radius_for_speed() -> float:
	var peak: float = maxf(spin_peak_speed, 0.001)
	var t: float = clampf(_face_spin_speed / peak, 0.0, 1.0)
	return lerpf(spin_warp_radius_idle, spin_warp_radius_peak, t)


# =========================================================================
# Public API — face states (exclusive, no-arg entry)
# =========================================================================

func _set_face_state(state: StringName, play_enter_fx: bool) -> void:
	var was_talking: bool = _is_talk_state(_face_state)
	var same_state: bool = state == _face_state

	if state != FACE_ANIM_SPIN:
		_cancel_face_spin()

	if same_state and not play_enter_fx:
		_refresh_face_anims()
		return

	_face_state = state
	_speech_level = 0.0

	if play_enter_fx and state == FACE_ANIM_SURPRISED:
		_brow_pitch = surprised_brow_pitch_pop
		_eye_pitch = surprised_eye_pitch_pop
		_feature_pitch = 0.0
		_feature_yaw_jitter = 0.0
		_begin_surprise_arm_raise()
	elif state != FACE_ANIM_SURPRISED and state != FACE_ANIM_ANGRY and state != FACE_ANIM_HOLDING_BACK_TEARS:
		_brow_pitch = 0.0
		_eye_pitch = 0.0
		_feature_pitch = 0.0
		_feature_yaw_jitter = 0.0

	if state != FACE_ANIM_SURPRISED:
		_surprise_arm_active = false

	if state == FACE_ANIM_ANGRY or _is_talk_state(state) or state == FACE_ANIM_HOLDING_BACK_TEARS:
		_arm_behavior_queue.clear()
		if _arm_behavior == ArmBehavior.WAVE:
			_begin_arm_behavior(_pick_arm_behavior())

	_refresh_face_anims()
	_apply_globe_uniforms()
	state_changed.emit(state)

	var now_talking: bool = _is_talk_state(state)
	if now_talking != was_talking:
		talking_changed.emit(now_talking)


func _cancel_face_spin() -> void:
	if not _face_spinning and not _spin_active:
		return
	_face_spinning = false
	_spin_active = false
	_face_spin_speed = 0.0
	_face_yaw = 0.0


func default_now() -> void:
	_set_face_state(FACE_ANIM_DEFAULT, true)


func angry_now() -> void:
	_set_face_state(FACE_ANIM_ANGRY, true)


func holding_back_tears_now() -> void:
	_set_face_state(FACE_ANIM_HOLDING_BACK_TEARS, true)


func surprised_now() -> void:
	_set_face_state(FACE_ANIM_SURPRISED, true)


## Play a talking SpriteFrames anim. `style` must be `talking` or `talking_*`.
func talk_now(style: StringName = FACE_ANIM_TALKING) -> void:
	var anim: StringName = style
	if not _is_talk_state(anim):
		anim = FACE_ANIM_TALKING
	_set_face_state(anim, true)


## Non-talking pose / emotion (e.g. angry, agitated, default).
func expression_now(state: StringName) -> void:
	if _is_talk_state(state):
		talk_now(state)
		return
	_set_face_state(state, true)


## Face + landmass share one peak speed, then decay separately.
## Landmass → idle drift. Face → min speed, coasts, stops on next yaw 0.
## When the face parks, the pre-spin state is restored (without replaying enter FX).
func spin_now() -> void:
	if _face_state != FACE_ANIM_SPIN:
		_resume_state_after_spin = _face_state
	_spin_active = true
	_face_spinning = true
	_face_yaw = 0.0
	_face_spin_speed = spin_peak_speed
	_land_spin_speed = spin_peak_speed
	_globe_spin_velocity = 0.0
	_set_face_state(FACE_ANIM_SPIN, true)


## Apply this instance's configured idle expression and arm mood.
func apply_idle_behavior() -> void:
	expression_now(idle_expression)
	_arm_behavior_queue.clear()
	_refill_arm_behavior_queue()
	if idle_arm_mood == 1 and arms_enabled:
		_begin_arm_behavior(ArmBehavior.WAVE)
	else:
		_begin_arm_behavior(_pick_arm_behavior())


## One-shot celebration using Instance Behavior → Celebrate exports.
## Spins from idle so parking restores the greeter face (not a surprise flash).
## If celebrate_expression differs from idle, that pose is used only for the post-spin hold.
func celebrate() -> void:
	_behavior_token += 1
	var token: int = _behavior_token
	# Spin remembers the pre-spin face and restores it when it parks.
	expression_now(idle_expression)
	if celebrate_spin:
		spin_now()
	_run_celebrate_sequence(token)


func _run_celebrate_sequence(token: int) -> void:
	if celebrate_spin:
		while token == _behavior_token and _face_spinning:
			await get_tree().process_frame
	if token != _behavior_token:
		return
	if celebrate_expression != idle_expression:
		expression_now(celebrate_expression)
	if celebrate_hold_seconds > 0.0:
		await get_tree().create_timer(celebrate_hold_seconds).timeout
	if token != _behavior_token:
		return
	if celebrate_return_to_idle:
		apply_idle_behavior()


func get_face_state() -> StringName:
	return _face_state


func is_talking() -> bool:
	return _is_talk_state()


func is_spinning() -> bool:
	return _spin_active


## Toggle spherical yaw wrap on face parts. SpriteFrames keep animating either way.
func set_feature_wrap_enabled(enabled: bool) -> void:
	feature_wrap_enabled = enabled
	for mat in _feature_wrap_materials:
		mat.set_shader_parameter("wrap_enabled", enabled)
	if enabled:
		eye_left.scale = _eye_left_base_scale
		eye_right.scale = _eye_right_base_scale
		mouth.scale = _mouth_base_scale
		eye_pupil_left.position = _pupil_left_base
		eye_pupil_right.position = _pupil_right_base
	if not _spin_active:
		_face_yaw = 0.0
		_apply_globe_uniforms()


func is_feature_wrap_enabled() -> bool:
	return feature_wrap_enabled


## Feed 0..1 loudness while talking to make the mouth react to volume.
func set_speech_level(level: float) -> void:
	_speech_level = clampf(level, 0.0, 1.0)


## Pause mouth autoplay so frames step only on voice syllables.
## Disabling does not resume talking autoplay — caller should set the face state.
func set_syllable_mouth_sync(enabled: bool) -> void:
	_syllable_mouth_sync = enabled
	if enabled:
		if mouth.sprite_frames != null and mouth.sprite_frames.get_frame_count(mouth.animation) > 0:
			mouth.pause()
			mouth.frame = 0
		return
	mouth.pause()


## Advance the mouth one SpriteFrames frame (wraps). Call on each voiced syllable.
func advance_mouth_for_syllable() -> void:
	if not _syllable_mouth_sync:
		return
	var frames: SpriteFrames = mouth.sprite_frames
	if frames == null:
		return
	var anim: StringName = mouth.animation
	var count: int = frames.get_frame_count(anim)
	if count <= 0:
		return
	mouth.pause()
	mouth.frame = (mouth.frame + 1) % count


## Direct gaze in normalized space; x/y in -1..1. Switches to FIXED gaze.
func set_gaze(direction: Vector2) -> void:
	gaze_mode = GazeMode.FIXED
	_gaze_target = Vector2(clampf(direction.x, -1.0, 1.0), clampf(direction.y, -1.0, 1.0))


## Aim the eyes at a world point (e.g. the player). Switches to FIXED gaze.
func look_at_global(world_point: Vector2) -> void:
	var local: Vector2 = to_local(world_point)
	set_gaze(Vector2(
		clampf(local.x / pupil_max_offset.x, -1.0, 1.0),
		clampf(local.y / pupil_max_offset.y, -1.0, 1.0)
	))


func set_gaze_mode(mode: GazeMode) -> void:
	gaze_mode = mode


func set_idle_motion_enabled(enabled: bool) -> void:
	idle_motion_enabled = enabled


## Absolute globe spin in 0..1 (1.0 = full 360°). Idle drift continues from here.
func set_globe_yaw(amount: float) -> void:
	_globe_yaw_target = fposmod(amount, 1.0)
	_globe_spin_velocity = 0.0


func get_globe_yaw() -> float:
	return _globe_yaw


## Nudge the globe by a relative amount (e.g. 0.25 = quarter turn).
func spin_globe_by(delta_yaw: float) -> void:
	_globe_yaw_target = fposmod(_globe_yaw_target + delta_yaw, 1.0)
	_globe_spin_velocity = 0.0


## Continuous spin rate in turns/sec. Pass 0 to stop and resume idle drift.
func set_globe_spin_velocity(turns_per_second: float) -> void:
	_globe_spin_velocity = turns_per_second


func set_globe_pitch(amount: float) -> void:
	globe_pitch = clampf(amount, -1.0, 1.0)


func set_rest_pose(yaw: float, pitch: float) -> void:
	rest_yaw = yaw
	rest_pitch = pitch
	_apply_globe_uniforms()


# --- Quick gestures (compose on top of idle motion) ----------------------
func nod() -> void:
	_kill_gesture_tween()
	_gesture_tween = create_tween()
	_gesture_tween.tween_property(self, "_gesture_offset_pos:y", 6.0, 0.12).set_trans(Tween.TRANS_SINE)
	_gesture_tween.tween_property(self, "_gesture_offset_pos:y", 0.0, 0.16).set_trans(Tween.TRANS_SINE)


func shake_head() -> void:
	_kill_gesture_tween()
	var swing: float = deg_to_rad(7.0)
	_gesture_tween = create_tween()
	_gesture_tween.tween_property(self, "_gesture_offset_rot", -swing, 0.09).set_trans(Tween.TRANS_SINE)
	_gesture_tween.tween_property(self, "_gesture_offset_rot", swing, 0.14).set_trans(Tween.TRANS_SINE)
	_gesture_tween.tween_property(self, "_gesture_offset_rot", 0.0, 0.09).set_trans(Tween.TRANS_SINE)


func _kill_gesture_tween() -> void:
	if _gesture_tween != null and _gesture_tween.is_running():
		_gesture_tween.kill()
