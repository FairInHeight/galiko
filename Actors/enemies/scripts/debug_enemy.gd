extends Enemy

# ==========================================
# LIFECYCLE INITIALIZATION
# ==========================================
func _ready() -> void:
	# 1. Run all base setup (links collisions, hooks signals, grabs EnemyBrain node, sets up elemental tint & audio loop)
	super._ready()
	
	# 2. Assign fallback identity metadata if not already filled out by data packets
	if enemy_name == "Base Enemy":
		enemy_name = "Debug Drone"
	if score_value == 100:
		score_value = 250
	
	# NOTE: We no longer force ai_mode or fire_mode here! 
	# This leaves the drone completely open to being controlled externally 
	# by DebugWave or Arcade timelines.
	
	print("🛠️ ", enemy_name, " initialized. Subclass awaiting system orders.")
