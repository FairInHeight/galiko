class_name DebugModeManager
extends Node

# Handled explicitly by the parent World node once initialized
var world: Node

# Internal tracking for the active testing sandbox instance
var current_sandbox_node: Node = null


func _ready() -> void:
	# Guard: If we are not explicitly in debug mode, shut down instantly
	if Global.current_game_mode != Global.GameMode.DEBUG:
		queue_free()
		return


## Called by world.gd once the parent is fully loaded and ready
func initialize(world_reference: Node) -> void:
	world = world_reference
	print("🛠️ Debug Sandbox Mode Manager Initialized Safely.")
	_start_debug_session()


## Wrapper to kick off the session sequence cleanly
func _start_debug_session() -> void:
	_load_sandbox_canvas()
	
	# Ask World to dynamically drop the player into the clean stage frame
	if _is_world_valid() and world.has_method("spawn_modular_player"):
		world.spawn_modular_player()
	
	run_debug_intro()


## Instantiates your main testing sandbox environment into the level container
func _load_sandbox_canvas() -> void:
	if is_instance_valid(current_sandbox_node):
		current_sandbox_node.queue_free()
		
	var sandbox_path := "res://Game Modes/debug waves/debug_sandbox.tscn"
	if not ResourceLoader.exists(sandbox_path):
		print("⚠️ [DebugMode]: Missing 'debug_sandbox.tscn'. Creating empty playground.")
		return
		
	var sandbox_scene = load(sandbox_path) as PackedScene
	current_sandbox_node = sandbox_scene.instantiate()
	
	if _is_world_valid() and is_instance_valid(world.level_container):
		world.level_container.add_child(current_sandbox_node)


## Elegant, retro intro execution
func run_debug_intro() -> void:
	Global.is_in_cutscene = true
	
	if _is_world_valid():
		# 1. Show READY...
		world.display_notification("[color=yellow]READY...[/color]", Color.WHITE, 48, "res://Sounds/sfx/ring.wav")
		
		await get_tree().create_timer(1.5).timeout
		if not _is_world_valid(): return # 🛑 CRASH SHIELD
		
		# 2. Show GO!
		world.display_notification("[color=green]GO![/color]", Color.WHITE, 48, "res://Sounds/sfx/beep.wav")
		
		# 🟢 THE COUPLING-FREE TRIGGER: Signal the sandbox scene that the match is active.
		# This allows the sandbox container to weaponize any existing or future spawned units.
		if is_instance_valid(current_sandbox_node) and current_sandbox_node.has_method("activate_all_weapons"):
			current_sandbox_node.activate_all_weapons()
		
		await get_tree().create_timer(1.5).timeout
		if not _is_world_valid(): return # 🛑 CRASH SHIELD
		
		# 3. Clear text layer
		world.clear_notification()
	
	Global.is_in_cutscene = false
	print("Debug Cutscene Finished: Player Released into Sandbox!")


## External hook requested by world.gd's player death sequence
func restart_mode() -> void:
	print("🔄 Resetting Debug Sandbox environment...")
	
	# Clean out all entities, projectiles, and nodes inside the level container
	if _is_world_valid() and is_instance_valid(world.level_container):
		for child in world.level_container.get_children():
			child.queue_free()
			
	_start_debug_session()


## Lightweight internal guard helper to avoid redundant code chunks
func _is_world_valid() -> bool:
	return is_inside_tree() and is_instance_valid(world)
