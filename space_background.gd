extends ParallaxBackground

# How fast the stars move downward (pixels per second)
@export var scroll_speed: float = 150.0

func _process(delta: float) -> void:
	# Add to the vertical offset to make it scroll downwards
	scroll_base_offset.y += scroll_speed * delta
