extends Area2D

# ==========================================
# ADVANCED TYPING (Stamped by Player Launcher)
# ==========================================
## The elemental archetype of this projectile
@export var damage_type: TypeManager.Type = TypeManager.Type.DEFAULT

# ==========================================
# CORE COMBAT RUNTIME PARAMETERS
# ==========================================
@export var speed: float = 600.0
@export var damage: int = 1


func _ready() -> void:
	# 🟢 SAFETY GATE: Prevents duplicate connection errors if auto-wired by the Editor
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	# Move upward (negative Y is up in 2D)
	global_position.y -= speed * delta
	
	# Destroy the bullet if it flies off the top of the screen
	if global_position.y < -50.0:
		queue_free()


# ==========================================
# COLLISION & INTERACTION PIPELINE
# ==========================================
func _on_area_entered(area: Area2D) -> void:
	# NEW SECURITY GATE: If we accidentally touch ourselves or another player instance, ignore completely!
	if area.is_in_group("player"):
		return

	# 1. Check if we hit an enemy bullet (Cancel out!)
	if area.is_in_group("enemy_bullets"):
		area.queue_free() # Destroy the enemy bullet
		queue_free()      # Destroy this player bullet
		return            

	# 2. Check if the thing we hit is an enemy
	if area.is_in_group("enemies") or area.has_method("take_damage"):
		var final_damage: int = damage
		
		# THE CALCULATION BRIDGE:
		if "elemental_type" in area:
			var enemy_type = area.elemental_type
			
			# Run the math directly via our optimized pure-static calculation engine
			var multiplier = TypeManager.get_damage_multiplier(damage_type, enemy_type)
			final_damage = clamped_integer_calculation(damage, multiplier)
			
			print("🎯 Player Hit: ", TypeManager.Type.keys()[damage_type], " vs Enemy ", TypeManager.Type.keys()[enemy_type], " -> Mult: ", multiplier, "x | Final: ", final_damage)

		# Apply the dynamically scaled calculation directly to the enemy script
		area.take_damage(final_damage)
		
		# Destroy the bullet itself so it doesn't pierce through
		queue_free()


## Helper tool to convert floats safely to integer changes without causing 0 damage round-downs
func clamped_integer_calculation(base: float, mult: float) -> int:
	var result = base * mult
	if result > 0.0 and result < 1.0:
		return 1 # Ensure highly resistant targets still take a minimum of 1 chip damage
	return int(round(result))
