extends EnemySpawner
class_name InvasionSpawner

@export_group("Invasion Row Layout")
@export var enemies_per_row: int = 5
@export var spawn_width: float = 440.0 
@export var start_x: float = 50.0
@export var spawn_y_offset: float = 100.0

# --- RUNTIME TRACKING ---
# Dictionary tracking active slots: { slot_index (int): enemy_instance (Enemy) }
var active_slots: Dictionary = {}


## Overriding the base class function to implement our specific row spawning routine
func spawn_wave() -> void:
	print("Invasion Spawner ticking! Generating endless structured row...")
	active_slots.clear()
	
	for i in range(enemies_per_row):
		_spawn_enemy_in_slot(i)
		
	print("Initial invasion row deployed. Auto-replenishment active.")


## Helper function to spawn a specific enemy at a designated slot index
func _spawn_enemy_in_slot(slot_index: int) -> void:
	var selected_data: EnemyData = enemy_data as EnemyData
	var enemy_scene: PackedScene = null
	
	if selected_data:
		enemy_scene = selected_data.enemy_scene
		
	if not enemy_scene:
		print("CRITICAL ERROR [InvasionSpawner]: No valid EnemyScene assigned inside EnemyData!")
		return
		
	var spacing = spawn_width / (enemies_per_row - 1) if enemies_per_row > 1 else 0.0
	var spawn_x = start_x + (slot_index * spacing)
	var spawn_pos := Vector2(spawn_x, spawn_y_offset)
	
	var enemy := enemy_scene.instantiate() as Enemy
	if not enemy:
		return
		
	# Set positions and disable wrapping
	enemy.global_position = spawn_pos
	
	if "wrap_enabled" in enemy:
		enemy.wrap_enabled = false
		
	if "anchor_position" in enemy:
		enemy.anchor_position = spawn_pos
		
	# Inject stats and data packages
	if selected_data and enemy.has_method("init_from_data"):
		enemy.init_from_data(selected_data)
	else:
		inject_enemy_data(enemy)
		
	# Track the enemy in this specific slot index
	active_slots[slot_index] = enemy
	
	# Connect to tree_exited and bind the exact slot index so we know which anchor opened up!
	enemy.tree_exited.connect(_on_slot_enemy_destroyed.bind(slot_index))
	
	get_parent().add_child(enemy)


## Automatically called whenever an enemy leaves the game tree
func _on_slot_enemy_destroyed(slot_index: int) -> void:
	# Double-check that this script is still inside the scene tree before replacing units
	if is_inside_tree():
		print("🚨 Enemy in anchor slot ", slot_index, " destroyed! Deploying replacement unit...")
		_spawn_enemy_in_slot(slot_index)
