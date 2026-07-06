class_name BaseWave
extends Node2D

## Signal emitted when all enemies are dead and the wave is fully cleared
signal wave_completed

# --- RUNTIME TRACKING ---
## Keeps track of active spawners we are waiting on to finish
var active_spawners: Array[Node] = []


func _ready() -> void:
	# Wait one frame to ensure children spawners are ready in the tree
	await get_tree().process_frame
	_initialize_and_start_spawners()


## Finds all spawners in the scene, links their signals, and triggers them
func _initialize_and_start_spawners() -> void:
	active_spawners.clear()
	
	# Look through children to find any node that acts as a spawner
	for child in get_children():
		if child.has_method("spawn_wave"):
			active_spawners.append(child)
			
			# 🟢 SEED INJECTION: Pass the deterministic RNG state down to the spawner 
			# so enemy attributes, lanes, and delays match the seed perfectly!
			if "rng" in child:
				child.rng = Global.arcade_rng
			
			# LINK 1: If it's a RowSpawner, connect to its wave_cleared signal
			if child.has_signal("wave_cleared"):
				child.wave_cleared.connect(_on_spawner_finished.bind(child))
			# LINK 2: Fallback for other custom spawners using tree_exited tracking
			elif child.has_signal("tree_exited"):
				child.tree_exited.connect(_on_spawner_finished.bind(child))
				
			# THE SPARK: Tell the spawner to build its matrix/spawn its units!
			child.spawn_wave()
			
	print("📊 BaseWave running. Orchestrating ", active_spawners.size(), " active spawners.")
	
	# Safety check: If a wave scene accidentally contains no spawners, clear it instantly
	if active_spawners.is_empty():
		_evaluate_wave_state()


## Fired automatically when an assigned spawner reports all its units are dead
func _on_spawner_finished(spawner_node: Node) -> void:
	if active_spawners.has(spawner_node):
		active_spawners.erase(spawner_node)
		print("✅ Spawner [", spawner_node.name, "] fully cleared.")
		_evaluate_wave_state()


## Verifies if all spawner assignments have completed successfully
func _evaluate_wave_state() -> void:
	if active_spawners.is_empty():
		print("🎉 All wave spawners cleared! Sending completion signal up to ArcadeModeManager...")
		wave_completed.emit()


# ==========================================
# CUSTOM TIMELINE HOOKS & UTILITIES
# ==========================================

## Virtual function to be overwritten by custom timeline scripts (like wave_1.gd)
func setup_wave_events() -> void:
	pass


## 🟢 STABILIZED CHECKER: Safely tracks enemy AI status without memory leaks
func are_all_enemies_stabilized() -> bool:
	for spawner in active_spawners:
		if is_instance_valid(spawner) and "living_enemies" in spawner:
			for enemy in spawner.living_enemies:
				# 🟢 CRITICAL STABILITY SHIELD: Skip completely if an enemy node was freed mid-combat
				if not is_instance_valid(enemy):
					continue
					
				if "ai_mode" in enemy:
					# If even ONE enemy is still diving, sniping, chasing, or retreating, the grid isn't stable
					if enemy.ai_mode != Enemy.AIMode.IDLE:
						return false
	return true
