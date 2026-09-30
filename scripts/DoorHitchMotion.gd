class_name DoorHitchMotion
extends RefCounted

## Multi-stage door progress (0 = closed, 1 = fully open).
## Open: delay → crack to ~5% → brief hitch → sweep to ~95% → ease to 100%.
## Close: exact reverse of that timeline.


static func animate(
	tween: Tween,
	opening: bool,
	from_progress: float,
	on_progress: Callable,
	hitch_delay_seconds: float,
	crack_progress: float,
	crack_duration_seconds: float,
	crack_hitch_seconds: float,
	sweep_progress: float,
	sweep_duration_seconds: float,
	settle_duration_seconds: float
) -> void:
	var crack: float = clampf(crack_progress, 0.0, 1.0)
	var sweep: float = clampf(sweep_progress, crack, 1.0)
	var from_value: float = clampf(from_progress, 0.0, 1.0)
	on_progress.call(from_value)

	if opening:
		if hitch_delay_seconds > 0.0 and from_value <= 0.0:
			tween.tween_interval(hitch_delay_seconds)
		if from_value < crack:
			_tween_progress(
				tween,
				on_progress,
				from_value,
				crack,
				_scaled_duration(crack_duration_seconds, from_value, crack, 0.0, crack),
				Tween.TRANS_SINE,
				Tween.EASE_OUT
			)
			from_value = crack
			if crack_hitch_seconds > 0.0:
				tween.tween_interval(crack_hitch_seconds)
		if from_value < sweep:
			_tween_progress(
				tween,
				on_progress,
				from_value,
				sweep,
				_scaled_duration(sweep_duration_seconds, from_value, sweep, crack, sweep),
				Tween.TRANS_QUAD,
				Tween.EASE_IN_OUT
			)
			from_value = sweep
		if from_value < 1.0:
			_tween_progress(
				tween,
				on_progress,
				from_value,
				1.0,
				_scaled_duration(settle_duration_seconds, from_value, 1.0, sweep, 1.0),
				Tween.TRANS_QUAD,
				Tween.EASE_OUT
			)
	else:
		if from_value > sweep:
			_tween_progress(
				tween,
				on_progress,
				from_value,
				sweep,
				_scaled_duration(settle_duration_seconds, from_value, sweep, 1.0, sweep),
				Tween.TRANS_QUAD,
				Tween.EASE_IN
			)
			from_value = sweep
		if from_value > crack:
			_tween_progress(
				tween,
				on_progress,
				from_value,
				crack,
				_scaled_duration(sweep_duration_seconds, from_value, crack, sweep, crack),
				Tween.TRANS_QUAD,
				Tween.EASE_IN_OUT
			)
			from_value = crack
			if crack_hitch_seconds > 0.0:
				tween.tween_interval(crack_hitch_seconds)
		if from_value > 0.0:
			_tween_progress(
				tween,
				on_progress,
				from_value,
				0.0,
				_scaled_duration(crack_duration_seconds, from_value, 0.0, crack, 0.0),
				Tween.TRANS_SINE,
				Tween.EASE_IN
			)
		if hitch_delay_seconds > 0.0:
			tween.tween_interval(hitch_delay_seconds)


static func _scaled_duration(
	full_duration_seconds: float,
	from_value: float,
	to_value: float,
	segment_start: float,
	segment_end: float
) -> float:
	var segment_span: float = absf(segment_end - segment_start)
	if segment_span <= 0.0001:
		return full_duration_seconds
	var remaining_span: float = absf(to_value - from_value)
	return full_duration_seconds * clampf(remaining_span / segment_span, 0.0, 1.0)


static func _tween_progress(
	tween: Tween,
	on_progress: Callable,
	from_value: float,
	to_value: float,
	duration_seconds: float,
	trans: Tween.TransitionType,
	ease: Tween.EaseType
) -> void:
	if duration_seconds <= 0.0 or is_equal_approx(from_value, to_value):
		tween.tween_callback(on_progress.bind(to_value))
		return
	tween.tween_method(on_progress, from_value, to_value, duration_seconds).set_trans(trans).set_ease(ease)
