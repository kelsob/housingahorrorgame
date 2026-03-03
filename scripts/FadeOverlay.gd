extends CanvasLayer

## Full-screen fade overlay. Run transition before work/sleep.
## Scene: CanvasLayer (layer 100) with ColorRect child named "ColorRect", full rect, color black.
## Add to Game as sibling of existing CanvasLayer. Add to group "fade_overlay".

@onready var color_rect: ColorRect = $ColorRect

@export var fade_duration: float = 0.25
@export var pause_duration: float = 0.4


func _ready() -> void:
	add_to_group("fade_overlay")
	if color_rect:
		color_rect.color = Color(0, 0, 0, 0)


## Fade to black, run action, pause, fade back. Action runs when fully black.
func run_transition(action: Callable) -> void:
	if not color_rect:
		action.call()
		return
	var tween := create_tween()
	tween.tween_property(color_rect, "color", Color(0, 0, 0, 1), fade_duration)
	tween.tween_callback(action)
	tween.tween_interval(pause_duration)
	tween.tween_property(color_rect, "color", Color(0, 0, 0, 0), fade_duration)
