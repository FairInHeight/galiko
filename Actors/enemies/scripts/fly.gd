extends Enemy

# ==========================================
# LIFECYCLE INITIALIZATION
# ==========================================
func _ready() -> void:
	# 1. Run all base setup (links collisions, hooks signals, grabs EnemyBrain node, sets up elemental tint & audio loop)
	super._ready()
	
	# 2. Assign unique Fly archetype defaults
	# Hardcoding health to 1 for lightweight swarm scaling
	enemy_max_health = 1
	enemy_current_health = 1
	
	# NOTE: We leave score_value completely untouched here!
	# This ensures it pulls whatever default score value you set in the EnemyData resource panel.
	
	print("🪰 ", enemy_name, " initialized. Health locked to 1. Ready to swarm!")
