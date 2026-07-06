extends Node2D

# This will hold the speed vector passed in by the player right before they died
var velocity: Vector2 = Vector2.ZERO

# How fast the explosion slows down to a stop
var friction: float = 3.0 

func _ready() -> void:
	# Immediately play the shared explosion animation
	$AnimatedSprite2D.play("explosion")
	
	# Automatically delete this scene from memory the exact moment the animation ends
	$AnimatedSprite2D.animation_finished.connect(queue_free)

func _process(delta: float) -> void:
	# Move the explosion through space based on its assigned momentum
	position += velocity * delta
	
	# Bleed off the speed linearly over time so it drifts to a satisfying halt
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta * 100.0)
