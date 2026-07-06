extends EnemySpawner
class_name RowSpawner

# --- SIGNALS ---
## Emitted automatically when every single enemy spawned in this matrix has been destroyed!
signal wave_cleared

# --- GRID CONFIGURATION ---
@export_group("Grid Setup")
@export var grid_rows: int = 5
@export var grid_columns: int = 6
@export var vertical_spacing: float = 60.0
@export var horizontal_padding: float = 40.0

# --- THE DESIGNER'S PALETTE ---
@export_group("Enemy Registry Mapping")
@export var enemy_palette: Dictionary[String, EnemyData] = {}

# --- OVERRIDE CONFIGURATIONS ---
@export_group("Spawn Overrides")
@export var default_enemy_key: String = "default"
@export var row_overrides: Dictionary[int, String] = {}
@export var column_overrides: Dictionary[int, String] = {}
@export var slot_overrides: Dictionary[String, String] = {}

# --- RUNTIME TRACKING ---
# Keeps track of all currently living enemies spawned by this specific node
var living_enemies: Array[Node2D] = []


func spawn_wave() -> void:
	print("Row Spawner ticking! Generating matrix...")
	living_enemies.clear() # Clear out any old references just in case
	
	# Grab viewport width dynamically to keep formatting uniform across screen changes
	var screen_width: float = get_viewport_rect().size.x
	var usable_width: float = screen_width - (horizontal_padding * 2.0)
	
	var horizontal_spacing: float = 0.0
	if grid_columns > 1:
		horizontal_spacing = usable_width / (grid_columns - 1)
	
	for r in range(grid_rows):
		for c in range(grid_columns):
			var current_key: String = get_enemy_key_for_slot(r, c)
			
			if current_key == "none" or current_key.is_empty():
				continue
				
			var spawn_x: float = horizontal_padding + (c * horizontal_spacing)
			var spawn_y: float = global_position.y + (r * vertical_spacing)
			var spawn_pos := Vector2(spawn_x, spawn_y)
			
			spawn_enemy_at_slot(current_key, spawn_pos, r, c)
			
	print("Matrix fully deployed. Total enemies tracked: ", living_enemies.size())


func get_enemy_key_for_slot(row: int, col: int) -> String:
	var slot_key := str(row) + "," + str(col)
	if slot_overrides.has(slot_key): return slot_overrides[slot_key]
	if column_overrides.has(col): return column_overrides[col]
	if row_overrides.has(row): return row_overrides[row]
	return default_enemy_key


func spawn_enemy_at_slot(key: String, pos: Vector2, row: int, col: int) -> void:
	var selected_data: EnemyData = null
	var enemy_scene: PackedScene = null
	
	# Resolve our EnemyData and PackedScene from memory targets cleanly
	if key == "default" or not enemy_palette.has(key):
		selected_data = enemy_data as EnemyData
		if selected_data and selected_data.enemy_scene:
			enemy_scene = selected_data.enemy_scene
	else:
		selected_data = enemy_palette[key]
		if selected_data:
			enemy_scene = selected_data.enemy_scene
			
	if not enemy_scene:
		print("CRITICAL ERROR [RowSpawner]: Cannot resolve EnemyScene for key: ", key)
		return
		
	var enemy := enemy_scene.instantiate() as Enemy
	if not enemy: 
		return
	
	enemy.global_position = pos
	
	# Lock down their permanent base grid layout anchor for tracking or movement resets
	if "anchor_position" in enemy:
		enemy.anchor_position = pos
	
	if "grid_row" in enemy: enemy.grid_row = row
	if "grid_column" in enemy: enemy.grid_column = col
		
	if selected_data and enemy.has_method("init_from_data"):
		enemy.init_from_data(selected_data)
	else:
		inject_enemy_data(enemy)
		
	# --- ADD TO TRACKING SYSTEM ---
	living_enemies.append(enemy)
	
	# Connect safely to tree_exiting so the tracking removal script runs before erasure
	enemy.tree_exiting.connect(func(): _on_enemy_destroyed(enemy))
		
	get_parent().add_child(enemy)


# Called automatically whenever an enemy leaves the game world
func _on_enemy_destroyed(enemy: Node2D) -> void:
	if is_instance_valid(enemy) and living_enemies.has(enemy):
		living_enemies.erase(enemy)
	
	# Dynamic array filter scrub to eliminate any invalid node pointers safely
	living_enemies = living_enemies.filter(func(node): return is_instance_valid(node))
		
	# If the list is completely empty, the wave is cleanly defeated!
	if living_enemies.is_empty():
		print("🎉 All enemies destroyed! Wave cleared!")
		wave_cleared.emit()
