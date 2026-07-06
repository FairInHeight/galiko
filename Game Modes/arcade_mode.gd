class_name ArcadeModeManager
extends Node

# Use the generic Node type to break any cyclic compilation loops
var world: Node

# Internal tracking for the currently loaded wave node instance
var current_wave_node: Node = null

# 🟢 OPTIMIZATION: Preload audio resources to prevent I/O disk stutters at 120 FPS
var sfx_ring: AudioStream = preload("res://Sounds/sfx/ring.wav")
var sfx_beep: AudioStream = preload("res://Sounds/sfx/beep.wav")
var jingle_game_over: AudioStream = preload("res://Sounds/jingles/gamve_over.wav")


func _ready() -> void:
	# Guard: If we aren't in gameplay mode, clear this manager out instantly
	if Global.current_game_mode == Global.GameMode.DEBUG:
		queue_free()
		return
		
	# ARCADE GLOBAL ENFORCER: Listen to everything entering the active engine tree
	get_tree().node_added.connect(_on_node_added_global)


## Called explicitly by world.gd once the parent stage is completely ready
func initialize(world_reference: Node) -> void:
	world = world_reference
	print("Base safe initialization complete. Starting Arcade Mode...")
	start_arcade_run()


## Starts the progression loop from Wave 1
func start_arcade_run() -> void:
	Global.current_wave = 1
	start_wave_sequence()


## Handles the countdown presentation before launching the wave layout
func start_wave_sequence() -> void:
	Global.is_in_cutscene = true
	
	if is_instance_valid(world):
		world.display_notification_stream("[color=yellow]READY...[/color]", Color.WHITE, 48, sfx_ring)
		
		await get_tree().create_timer(1.5).timeout
		if not is_inside_tree() or not is_instance_valid(world): return # 🛑 CRASH SHIELD
		
		world.display_notification_stream("[color=green]GO![/color]", Color.WHITE, 48, sfx_beep)
		
		await get_tree().create_timer(1.5).timeout
		if not is_inside_tree() or not is_instance_valid(world): return # 🛑 CRASH SHIELD
		
		# Clear the text right as gameplay starts
		world.clear_notification()
	
	Global.is_in_cutscene = false
	_load_wave_scene(Global.current_wave)


## Clears old layouts and drops the specified wave scene file into the LevelContainer
func _load_wave_scene(wave_num: int) -> void:
	var wave_path := "res://Game Modes/arcade waves/wave_" + str(wave_num) + ".tscn"
	
	if not ResourceLoader.exists(wave_path):
		_handle_victory()
		return
		
	var wave_scene = load(wave_path) as PackedScene
	current_wave_node = wave_scene.instantiate()
	
	if is_instance_valid(world) and is_instance_valid(world.level_container):
		world.level_container.add_child(current_wave_node)
	
	if current_wave_node.has_signal("wave_completed"):
		current_wave_node.wave_completed.connect(_on_wave_completed)
		
	if current_wave_node.has_method("setup_wave_events"):
		current_wave_node.setup_wave_events()


## Called automatically when the active BaseWave script emits "wave_completed"
func _on_wave_completed() -> void:
	if not is_inside_tree() or get_tree() == null: 
		return
		
	print("Wave ", Global.current_wave, " Cleared!")
	
	Global.is_in_cutscene = true
	Global.current_wave += 1
	
	if is_instance_valid(world):
		world.display_notification_stream("[color=cyan]WAVE CLEARED![/color]", Color.WHITE, 48, sfx_ring)
	
	if get_tree():
		await get_tree().create_timer(2.0).timeout
		
	if not is_inside_tree(): return 
	
	if is_instance_valid(current_wave_node):
		current_wave_node.queue_free()
		
	start_wave_sequence()


# COORDINDATED ARCADE RESPAWN MANAGEMENT WITH BULLET CHECKING
func restart_mode() -> void:
	Global.player_lives -= 1
	print("📉 Player lost a life. Remaining Lives: ", Global.player_lives)
	
	if Global.player_lives > 0:
		print("🔄 Initiating coordinated grid and projectile stabilization sequence...")
		Global.is_in_cutscene = true
		
		if is_instance_valid(world):
			world.display_notification_stream("[color=yellow]READY...[/color]", Color.WHITE, 48, sfx_ring)
		
		# --- GLOBAL FIRE LOCKDOWN & REGROUP COMMAND ---
		var active_enemies = get_tree().get_nodes_in_group("enemies")
		
		for enemy in active_enemies:
			if is_instance_valid(enemy) and "fire_mode" in enemy:
				enemy.fire_mode = Enemy.FireMode.HOLD_FIRE

		if not active_enemies.is_empty():
			var commander = active_enemies[0]
			if is_instance_valid(commander) and "ai_mode" in commander:
				print("🚨 Player down! Forcing tactical retreat broadcast across enemy grid.")
				commander.ai_mode = Enemy.AIMode.REGROUP
		
		await get_tree().create_timer(1.5).timeout
		if not is_inside_tree(): return
		
		# --- THE DOUBLE-GATEKEEPER LOOP ---
		if is_instance_valid(current_wave_node) and current_wave_node.has_method("are_all_enemies_stabilized"):
			print("⏳ Waiting for all enemies to return safely and all projectiles to clear...")
			
			while true:
				var enemies_stable = current_wave_node.are_all_enemies_stabilized()
				var bullets_cleared = get_tree().get_nodes_in_group("enemy_bullets").is_empty()
				
				if enemies_stable and bullets_cleared:
					break
					
				await get_tree().physics_frame
				
				if not is_instance_valid(current_wave_node):
					break
					
		print("🏁 Arena completely sanitized! Deploying fresh player ship.")
		
		if is_instance_valid(world):
			world.clear_notification()
			if world.has_method("spawn_modular_player"):
				world.spawn_modular_player()
				
		Global.is_in_cutscene = false
	else:
		# OUT OF LIVES: True Permanent Game Over
		print("💀 Game Over! No lives remaining.")
		Global.is_in_cutscene = true
		
		if is_instance_valid(world):
			world.display_notification_stream("[color=red]GAME OVER[/color]", Color.RED, 64, jingle_game_over)
		
		await get_tree().create_timer(4.0).timeout
		if not is_inside_tree(): return
		
		get_tree().change_scene_to_file("res://Menus/scenes/main_menu.tscn")


## Handles the win state when no more wave files are left in the directory
func _handle_victory() -> void:
	print("🏆 No more wave scenes found. Player wins Arcade Mode!")
	if is_instance_valid(world):
		world.display_notification_stream("[color=gold]VICTORY! YOU WIN![/color]", Color.WHITE, 64, sfx_ring)
	
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree(): return 
	
	get_tree().change_scene_to_file("res://Menus/scenes/main_menu.tscn")


# ==========================================
# ARCADE CONFIGURATION HOOKS
# ==========================================

# 🟢 FIXED: Re-added the missing engine interceptor method down scope!
## INTERCEPTOR: Fires instantly when any node spawns into the game tree
func _on_node_added_global(node: Node) -> void:
	if node is Enemy:
		node.wrap_enabled = true
