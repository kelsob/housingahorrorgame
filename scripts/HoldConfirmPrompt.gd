class_name HoldConfirmPrompt
extends Control

## Contextual interaction prompt under the crosshair.
## Used for look-at hints ("Buy food pellet for $5?") and hold-to-confirm (bed sleep).
##
## Scene structure (under UI.tscn):
##   HoldConfirmPrompt (Control) — prefer centered under Crosshair; mouse_filter = Ignore
##   ├─ PromptLabel (Label)
##   └─ ProgressBar (ProgressBar) — max_value = 1; hidden unless holding

@onready var prompt_label: Label = $PromptLabel
@onready var progress_bar: ProgressBar = $ProgressBar

var _hold_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0
	progress_bar.visible = false
	hide()


## Look-at / tap prompt. No progress bar. Ignored while a hold session owns the prompt.
func show_context(prompt_text: String) -> void:
	if _hold_active:
		return
	var text: String = prompt_text.strip_edges()
	if text.is_empty():
		clear()
		return
	prompt_label.text = text
	progress_bar.visible = false
	progress_bar.value = 0.0
	show()


## Hold-to-confirm session (e.g. bed). Shows progress bar.
func begin(prompt_text: String) -> void:
	_hold_active = true
	prompt_label.text = prompt_text.strip_edges()
	progress_bar.visible = true
	progress_bar.value = 0.0
	show()


func set_progress(ratio: float) -> void:
	if not _hold_active:
		return
	progress_bar.value = clampf(ratio, 0.0, 1.0)


func end() -> void:
	_hold_active = false
	progress_bar.value = 0.0
	progress_bar.visible = false
	hide()


func clear() -> void:
	if _hold_active:
		return
	progress_bar.value = 0.0
	progress_bar.visible = false
	hide()
