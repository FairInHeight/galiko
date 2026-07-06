extends EnemySpawner
class_name SoloSpawner

## Spawns a single enemy at the spawner's exact location
func spawn_wave() -> void:
	print("Solo Spawner ticking! Spawning single target...")
	
	# 1. Pull the data package cleanly from our inherited master class variables
	var selected_data: EnemyData = enemy_data as EnemyData
	var enemy_scene: PackedScene = null
	
	if selected_data:
		enemy_scene = selected_data.enemy_scene
		
	# 2. Fast fallback safety check using memory-cached data instead of disk searches
	if not enemy_scene:
		print("CRITICAL ERROR [SoloSpawner]: No valid EnemyScene assigned inside EnemyData!")
		return
		
	var enemy := enemy_scene.instantiate() as Enemy
	if not enemy:
		return
		
	# 3. Align position directly to the spawner node's coordinates
	enemy.global_position = global_position
	
	# 🟢 CRITICAL SYSTEM LINK: Set its home anchor right where it spawns in the scene
	if "anchor_position" in enemy:
		enemy.anchor_position = global_position
	
	# 4. Inject the modular data package properties smoothly
	if selected_data and enemy.has_method("init_from_data"):
		enemy.init_from_data(selected_data)
	else:
		inject_enemy_data(enemy)
		
	get_parent().add_child(enemy)
