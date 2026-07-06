extends BaseWave

# Timers to drive our automated AI events deterministically
var dive_bomb_timer: Timer
var grid_roulette_timer: Timer

# Cache a reference to our spawner for easy data-scraping
@onready var row_spawner: RowSpawner = $RowSpawner


func setup_wave_events() -> void:
	print("🚀 Wave 1 Timeline Running with Seeded Orchestration!")
	
	# 1. Main Dive Bomb Timer (Fires every 5 seconds to select a runner)
	dive_bomb_timer = Timer.new()
	dive_bomb_timer.wait_time = 5.0
	dive_bomb_timer.autostart = true
	dive_bomb_timer.timeout.connect(_on_dive_bomb_trigger)
	add_child(dive_bomb_timer)
	
	# 2. Grid Fire Roulette Timer (Fires every 2.5 seconds to flash chaotic fire)
	grid_roulette_timer = Timer.new()
	grid_roulette_timer.wait_time = 2.5
	grid_roulette_timer.autostart = true
	grid_roulette_timer.timeout.connect(_on_grid_roulette_trigger)
	add_child(grid_roulette_timer)


## PHASE 1: GRID FIRE ROULETTE (Passive Chaos)
func _on_grid_roulette_trigger() -> void:
	# 🚨 CUTSCENE GUARD: Do not activate roulette fire if the player is dead/respawning
	if Global.is_in_cutscene:
		return
		
	var target_enemy = _get_random_enemy_from_spawner()
	
	# Only affect enemies currently sitting passively in formation
	if target_enemy and target_enemy.ai_mode == Enemy.AIMode.IDLE:
		# Engage our custom 2% frame-by-frame chaotic logic
		target_enemy.fire_mode = Enemy.FireMode.SEEDED_CHAOS
		
		# Roll how long this enemy keeps shooting (between 1.0 and 2.5 seconds, seed-dependent)
		var burst_duration = Global.arcade_rng.randf_range(1.0, 2.5)
		
		await get_tree().create_timer(burst_duration).timeout
		
		# If they survived their burst window and haven't been broken into a dive state, cool down weapons
		if is_instance_valid(target_enemy) and target_enemy.ai_mode == Enemy.AIMode.IDLE:
			target_enemy.fire_mode = Enemy.FireMode.HOLD_FIRE


## PHASE 2 & 3: THE DIVE BOMB & POST-DIVE ROUTETTE MATRICES
func _on_dive_bomb_trigger() -> void:
	# 🚨 CUTSCENE GUARD: Do not launch a new dive bomb run if the player is dead/respawning
	if Global.is_in_cutscene:
		return
		
	var attacker = _get_random_enemy_from_spawner()
	
	if attacker and attacker.ai_mode == Enemy.AIMode.IDLE:
		print("🎯 Director selects enemy: [", attacker.enemy_name, "] to DIVE BOMB!")
		
		# Break out of rank and go all-out aggressive
		attacker.ai_mode = Enemy.AIMode.DIVE
		attacker.fire_mode = Enemy.FireMode.MAX_OUTPUT
		
		# SEEDED DIVE WINDOW: Instead of 3 seconds flat, roll between 2.0 and 4.0 seconds
		var attack_run_time = Global.arcade_rng.randf_range(2.0, 4.0)
		await get_tree().create_timer(attack_run_time).timeout
		
		# Check if they survived the initial dive run before assigning post-dive behavior
		if not is_instance_valid(attacker) or attacker.is_dying:
			return
			
		# --- UPDATED 50/30/20 BRANCHING DECISION ENGINE ---
		var roll = Global.arcade_rng.randf()
		
		if roll <= 0.50:
			# 🟢 CHANCE A (50%): Traditional Retreat
			print("🛡️ [50% Roll] Ordering fallback to formation...")
			_send_to_retreat(attacker)
			
		elif roll <= 0.80:
			# 🔵 CHANCE B (30%): Smooth Stop & Hover Snipe
			print("🎯 [30% Roll] Halting attacker! Engaging Hover Snipe phase...")
			attacker.ai_mode = Enemy.AIMode.SNIPE
			attacker.fire_mode = Enemy.FireMode.MAX_OUTPUT
			
			# Linger as an omnidirectional turret for a seeded duration
			var snipe_window = Global.arcade_rng.randf_range(2.5, 4.0)
			await get_tree().create_timer(snipe_window).timeout
			
			if is_instance_valid(attacker) and not attacker.is_dying:
				print("🛡️ Snipe window expired. Recalling to base.")
				_send_to_retreat(attacker)
				
		else:
			# 🔴 CHANCE C (20%): Aggressive Player Chase
			print("🔥 [20% Roll] CRITICAL AGGRESSION! Engaging direct player CHASE pathing...")
			attacker.ai_mode = Enemy.AIMode.CHASE
			attacker.fire_mode = Enemy.FireMode.MAX_OUTPUT
			
			# Hunt player coordinates directly for 1.5 seconds
			await get_tree().create_timer(1.5).timeout
			
			if is_instance_valid(attacker) and not attacker.is_dying:
				print("🛡️ Chase window expired. Ordering immediate fallback.")
				_send_to_retreat(attacker)


## Helper clean transition function to ensure rules drop properly on retreat orders
func _send_to_retreat(enemy: Enemy) -> void:
	if is_instance_valid(enemy):
		enemy.ai_mode = Enemy.AIMode.RETREAT
		enemy.fire_mode = Enemy.FireMode.HOLD_FIRE


## Helper to safely pull a random live target using our seeded RNG engine
func _get_random_enemy_from_spawner() -> Enemy:
	if not is_instance_valid(row_spawner) or row_spawner.living_enemies.is_empty():
		return null
		
	var index = Global.arcade_rng.randi() % row_spawner.living_enemies.size()
	return row_spawner.living_enemies[index] as Enemy
