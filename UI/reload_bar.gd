class_name ReloadBar
extends ProgressBar

@export_group("Juice Appearance")
## Controls how fast the visual meter catches up to the player's true reload step.
@export var smooth_speed: float = 22.0

## The active progress tint applied when your weapon is completely charged and ready to fire.
@export var ready_color: Color = Color("#ffffff") # Pure Arcade White

## The progress tint applied while the weapon is cycling through its fire rate cooldown.
@export var reloading_color: Color = Color("#555555") # Muted Dark Grey

## The burst flash color injected the exact moment the weapon finishes charging.
@export var flash_color: Color = Color("#ffcc00") # Vibrant Yellow Flash

# Internal tracking registers
var _target_value: float = 100.0
var _was_fully_charged: bool = true
var _flash_tween: Tween = null


func _ready() -> void:
	min_value = 0.0
	max_value = 100.0
	step = 0.01
	
	# Default initialize weapons as hot, full, and white
	value = max_value
	_target_value = max_value
	modulate = ready_color


func _process(delta: float) -> void:
	# UNLOCKED RESOLUTION LERPING: Evaluates on unscaled processing steps.
	value = lerp(value, _target_value, smooth_speed * delta)
	
	var is_currently_charged: bool = value >= max_value - 0.5
	
	# 🟢 THE FLASH GATEWAY: Detect the exact frame the reload finishes
	if is_currently_charged and not _was_fully_charged:
		trigger_completion_flash()
	
	# Only manage the baseline tint shifting if a juice flash animation isn't actively playing
	if not (_flash_tween and _flash_tween.is_valid()):
		if is_currently_charged:
			modulate = ready_color
		else:
			modulate = reloading_color
			
	_was_fully_charged = is_currently_charged


## Fires an isolated, real-time visual flash that snaps to yellow and fades instantly to white
func trigger_completion_flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
		
	# Snap immediately to our high-visibility yellow alert color
	modulate = flash_color
	
	# Create a rapid, smooth fade back to white that ignores hitstop time adjustments
	_flash_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_flash_tween.tween_property(self, "modulate", ready_color, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Primary API method called cleanly down the signal routing tree by UILayer.gd
func set_reload_percentage(percentage_factor: float) -> void:
	_target_value = clamp(percentage_factor * max_value, 0.0, max_value)
