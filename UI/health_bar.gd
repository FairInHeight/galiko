extends ProgressBar

## Internal tracking handle to safely manage and override active transitions
var blend_tween: Tween = null


func _ready() -> void:
	# 🟢 Establish the baseline limits immediately on boot
	max_value = Global.player_health
	value = Global.player_health
	print("📊 UI Health Bar Initialized! Max Value set to: ", max_value)


## 🟢 CALLED BY WORLD: Handles smoothly interpolating the bar up or down
func update_health(new_health: int) -> void:
	# 1. Kill any active tween so they don't fight each other if you take rapid hits
	if blend_tween and blend_tween.is_valid():
		blend_tween.kill()
		
	# 2. Create a clean, lightweight interpolation tween
	blend_tween = create_tween()
	
	# 3. Smoothly slide the progress bar value to the new health pool over 0.25 seconds
	# Using TRANS_CUBIC and EASE_OUT gives it a snappy, responsive deceleration effect!
	blend_tween.tween_property(self, "value", new_health, 0.5)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
