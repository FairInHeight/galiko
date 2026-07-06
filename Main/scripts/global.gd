extends Node

# --- Game Modes Definition ---
enum GameMode { DEBUG, ARCADE, ENDLESS, RUSH }

# This is the path on the player's device where the save file lives
const SAVE_PATH = "user://save_game.tres"

# This variable will hold our persistent data (unlocks and high score)
var save_data: SavedData

# --- Deterministic Seed System ---
var current_seed: String = ""
var arcade_rng := RandomNumberGenerator.new()

# Gameplay configuration & state
var current_game_mode: GameMode = GameMode.ARCADE
var session_record: int = 0

# Match-specific stats (Reset every game)
var score: int = 0
var player_lives: int = 3
var current_wave: int = 1

# ==========================================
# 🚀 CORE PLAYER STAT BALANCE PROFILE
# ==========================================
var player_health: int = 3
var fire_rate: float = 0.25
var damage: int = 1
var speed: float = 400.0
## 🟢 NEW: Global player projectile velocity manager (Read by Player.gd)
var bullet_speed: float = 600.0

# Global flags:
var is_in_cutscene: bool = false

# Character sprite of the player (Kept separate from hard drive save)
var selected_ship_texture: String = "res://sprites/character_yellow.png"


func _ready() -> void:
	load_game()
	# Ensure the RNG engine is initialized with a baseline seed immediately on boot
	roll_new_seed()


## Call this function from your gameplay scripts instead of modifying score directly!
## Handles updating the score and cleanly processing high scores without a heavy frame loop.
func add_score(amount: int) -> void:
	score += amount
	
	if score > session_record:
		session_record = score
		
	if is_instance_valid(save_data) and score > save_data.high_score:
		save_data.high_score = score


## Generates a readable 8-character seed string or applies a custom string,
## then sets up the global RNG engine state seamlessly.
func roll_new_seed(custom_seed: String = "") -> void:
	if custom_seed.strip_edges().is_empty():
		# Create an isolated, temporary generator to pick clean characters
		var temp_rng = RandomNumberGenerator.new()
		temp_rng.randomize()
		
		var characters = "ABCDEFGHJKLMNOPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"
		var random_string = ""
		for i in range(8):
			var index = temp_rng.randi_range(0, characters.length() - 1)
			random_string += characters[index]
			
		current_seed = random_string
	else:
		current_seed = custom_seed
	
	# Anchor the master RNG book to our unique seed hash!
	arcade_rng.seed = current_seed.hash()
	print("🎲 Master Run Seed Seeded: [ ", current_seed, " ]")


## Call this from your main menu buttons to set up the chosen mode
func setup_game_mode(mode: GameMode) -> void:
	current_game_mode = mode
	
	# Automatically roll a brand new seed for this fresh run attempt
	roll_new_seed()
	
	# Reset standard match variables and cleanly apply mode stats
	reset_game()


## Reset variables back to their default starting values for a new match
func reset_game() -> void:
	score = 0
	current_wave = 1
	
	# Cleanly apply custom rules to core player stats based on the active mode
	match current_game_mode:
		GameMode.DEBUG:
			player_lives = 99
			player_health = 10
			fire_rate = 0.1
			bullet_speed = 1200.0 # 🟢 Lightning fast debug bullets
			print("Mode Switched: DEBUG (God mode enabled)")
			
		GameMode.ARCADE:
			player_lives = 3
			player_health = 3
			fire_rate = 0.25
			bullet_speed = 600.0  # 🟢 Standard balanced speed
			print("Mode Switched: ARCADE (Standard rules)")
			
		GameMode.ENDLESS:
			player_lives = 1
			player_health = 5
			fire_rate = 0.25
			bullet_speed = 600.0  # 🟢 Balanced speed for long survivals
			print("Mode Switched: ENDLESS (One life to survive)")
			
		GameMode.RUSH:
			player_lives = 3
			player_health = 3
			fire_rate = 0.1
			bullet_speed = 850.0  # 🟢 High velocity for tight boss encounters
			print("Mode Switched: BOSS RUSH (Prepare yourself!)")


# ==========================================
# 💾 DISK I/O FILESYSTEM INTERFACE
# ==========================================

## Call this whenever you want to write changes to disk (e.g., Global.save_game())
func save_game() -> void:
	if not save_data:
		save_data = SavedData.new()
		
	var error = ResourceSaver.save(save_data, SAVE_PATH)
	if error == OK:
		print("Game saved successfully!")
	else:
		print("Failed to save game. Error code: ", error)


## Automatically runs on startup to load the player's progress
func load_game() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		save_data = ResourceLoader.load(SAVE_PATH) as SavedData
		if is_instance_valid(save_data):
			print("Save file loaded! High Score: ", save_data.high_score)
			return
			
	print("No save file found. Creating a fresh one...")
	save_data = SavedData.new()
	save_data.high_score = 57500 
	save_game()


## Call this whenever you want to wipe the save file completely
func delete_save_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var error = DirAccess.remove_absolute(SAVE_PATH)
		if error == OK:
			print("Save file deleted successfully from GALIKO folder!")
			save_data = SavedData.new()
			save_data.high_score = 57500
		else:
			print("Failed to delete save file. Error code: ", error)
	else:
		print("No save file exists to delete.")

# ==========================================
# 💥 JUICE & SCREEN FX INTERFACE
# ==========================================

## Freezes or dramatically slows down the game visuals for a split second.
## 'duration' is in seconds (e.g., 0.05). 'slow_amount' is the target Engine.time_scale.
func hitstop(duration: float, slow_amount: float = 0.0) -> void:
	Engine.time_scale = slow_amount
	
	# CRITICAL: The last argument 'true' makes this timer run on real-world time,
	# preventing the game from freezing permanently when time_scale hits 0.
	await get_tree().create_timer(duration, true, false, true).timeout
	
	Engine.time_scale = 1.0
