class_name DebugWave
extends Node2D

signal wave_completed

var active_spawners: Array[Node] = []
# 🟢 Master safety switch: Enemies check this before they start shooting
var weapons_are_hot: bool = false


func _ready() -> void:
	await get_tree().process_frame
	_initialize_and_override_sandbox()


func _initialize_and_override_sandbox() -> void:
	active_spawners.clear()
	for child in get_children():
		if child.has_method("spawn_wave"):
			active_spawners.append(child)
			# Hook into node entry so we can manipulate settings from the outside
			self.child_entered_tree.connect(_on_enemy_spawned_in_sandbox)
			child.spawn_wave()


func _on_enemy_spawned_in_sandbox(node: Node) -> void:
	if node is Enemy:
		# 🟢 WAIT ONE FRAME: Allow the spawner to finish running init_from_data() first!
		await get_tree().process_frame
		
		# Guard against the enemy dying or leaving on the exact frame it spawned
		if not is_instance_valid(node): 
			return
			
		# Force behavioral override for the sandbox environment
		node.ai_mode = Enemy.AIMode.DEBUG
		
		if weapons_are_hot:
			node.fire_mode = Enemy.FireMode.SEEDED_CHAOS
			# Sync the brain's internal clock right now
			if is_instance_valid(node.ai_brain) and node.ai_brain.has_method("sync_with_enemy_data"):
				node.ai_brain.sync_with_enemy_data()
		else:
			node.fire_mode = Enemy.FireMode.HOLD_FIRE
			
		print("🛠️ [Sandbox Override]: Successfully configured ", node.name, " to DEBUG behavior.")


## 🟢 THE "GO!" HOOK: Called explicitly by the DebugModeManager when the cutscene ends
func activate_all_weapons() -> void:
	weapons_are_hot = true
	print("🔥 [DebugWave]: Safety switch disengaged! Arming all active units!")
	
	# Wake up any enemies that already spawned during the countdown
	var active_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in active_enemies:
		if enemy is Enemy:
			enemy.ai_mode = Enemy.AIMode.DEBUG
			enemy.fire_mode = Enemy.FireMode.SEEDED_CHAOS
			
			# Force-sync the brain components
			if is_instance_valid(enemy.ai_brain) and enemy.ai_brain.has_method("sync_with_enemy_data"):
				enemy.ai_brain.sync_with_enemy_data()
