extends Node2D
class_name EnemySpawner

@onready var timer: Timer = $Timer

# --- EXPORTED CONFIGURATION ---
@export_group("Spawner Control")
## Toggle whether this spawner runs its own automatic timer loop.
@export var is_active: bool = false

@export_group("Spawner Pulse")
## How often (in seconds) this spawner will automatically trigger a new wave.
@export var spawn_rate: float = 3.0

@export_group("Resources")
## 🟢 PRESERVED AS FALLBACK: Raw path tracking if resources aren't fully set up yet
@export_file("*.tscn") var enemy_scene_path: String = "res://Actors/enemies/scenes/debug_enemy.tscn"
## 🟢 PRIMARY TARGET: Safe data packet configuration 
@export var enemy_data: EnemyData = preload("res://Actors/enemies/enemydata/debug_enemy.tres")

func _ready() -> void:
	# If it's a timer-based spawner, set up the internal clock loop
	if timer:
		timer.wait_time = spawn_rate
		timer.timeout.connect(_on_timer_timeout)
		
		if is_active:
			if timer.autostart or timer.is_stopped():
				timer.start()
			print_spawner_status()
		else:
			timer.stop()
			print("⏹️ Spawner [", name, "] timer is paused. Standing by for manual triggers.")


func _on_timer_timeout() -> void:
	# Automatic waves only fire if the spawner is actively loop-enabled
	if is_active:
		spawn_wave()


## ABSTRACT FUNCTION: Overridden by child classes (like RowSpawner)
func spawn_wave() -> void:
	pass


func inject_enemy_data(enemy: Node) -> void:
	if enemy_data and enemy.has_method("init_from_data"):
		enemy.init_from_data(enemy_data)
	else:
		print("⚠️ Warning [", name, "]: Could not inject data resource.")


func print_spawner_status() -> void:
	print("--- SPAWNER BOOTED: ", name, " ---")
	print("Auto-Loop Status: ", is_active)
	print("Spawn Rate Configured: ", spawn_rate, "s")
	print("---------------------------------------")
