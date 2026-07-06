class_name World
extends Node2D

# --- Dynamic Scene Preloads ---
const PLAYER_SCENE = preload("res://Actors/scenes/player.tscn") 

# --- Core Node References ---
@onready var level_container: Node2D = $LevelContainer
@onready var arcade_mode_manager: ArcadeModeManager = $ArcadeModeManager
@onready var debug_mode_manager: DebugModeManager = $DebugModeManager

# --- UI / Notification Systems ---
@onready var notification_label: RichTextLabel = $NotifLayer/NotifBanner/NotifLabel
@onready var audio_player: AudioStreamPlayer = $NotifLayer/NotifBanner/NotifSound

# --- UILayer Node Anchors ---
@onready var ui_layer: UILayer = $UILayer as UILayer
@onready var score_label: Label = $UILayer/ScoreLabel
@onready var session_record_label: Label = $UILayer/SessionRecord
@onready var health_bar: ProgressBar = $UILayer/HealthBar

# 🟢 AUTOMATED POINTER: Looks inside UILayer natively. 
# Works out of the box with TextureRect, ColorRect, or any generic Control setup.
@onready var danger_ui: Control = $UILayer/DangerIndicator as Control

# --- Runtime Engine Memory Properties ---
var danger_tween: Tween = null
var active_player: Node2D = null


func _ready() -> void:
	print("🌍 World Stage Initializing...")
	
	# Cache incoming state context before zeroing out runtime score sheets
	var incoming_mode = Global.current_game_mode
	Global.reset_game()
	Global.current_game_mode = incoming_mode
	
	# 1. Clean container layout
	if is_instance_valid(level_container):
		for child in level_container.get_children():
			child.queue_free()
		
	# 2. Deploy dynamic player ship & prepare UI starting visuals
	spawn_modular_player()
	initialize_static_hud()
		
	# 3. Mode Management Configuration
	match Global.current_game_mode:
		Global.GameMode.DEBUG:
			print("🛠️ Entering Sandbox Mode...")
			if is_instance_valid(arcade_mode_manager): arcade_mode_manager.queue_free()
			if is_instance_valid(debug_mode_manager): debug_mode_manager.initialize(self)
			
		Global.GameMode.ARCADE, Global.GameMode.ENDLESS, Global.GameMode.RUSH:
			print("🕹️ Entering Arcade Mode...")
			if is_instance_valid(debug_mode_manager): debug_mode_manager.queue_free()
			if is_instance_valid(arcade_mode_manager): arcade_mode_manager.initialize(self)


## EVENT DRIVEN UPDATES: Call this explicitly when scores change
func update_score_displays() -> void:
	if is_instance_valid(score_label):
		if score_label.has_method("update_display"):
			score_label.update_display(Global.score)
		else:
			score_label.text = "SCORE: " + str(Global.score)
			
	if is_instance_valid(session_record_label):
		if session_record_label.has_method("update_display"):
			session_record_label.update_display(Global.session_record)
		else:
			session_record_label.text = "HI-SCORE: " + str(Global.session_record)


## EVENT DRIVEN UPDATES: Call this from managers to synchronize the custom graphical lives display
func update_lives_display() -> void:
	if is_instance_valid(ui_layer) and ui_layer.has_method("refresh_lives_counter"):
		ui_layer.refresh_lives_counter()


## Setup initial values on boot
func initialize_static_hud() -> void:
	update_score_displays()
	update_lives_display()
	
	if is_instance_valid(ui_layer) and ui_layer.has_method("configure_mode_visibility"):
		ui_layer.configure_mode_visibility()


## Handles dynamic player deployment completely uncoupled from your level layouts
func spawn_modular_player() -> void:
	if is_instance_valid(active_player):
		active_player.queue_free()
		active_player = null
		
	active_player = PLAYER_SCENE.instantiate() as Node2D
	
	if is_instance_valid(level_container):
		level_container.add_child(active_player)
		
	active_player.position = Vector2(270, 850)
	
	# CONNECT HUD ROUTING CHANNELS:
	if active_player.has_signal("health_changed"):
		active_player.health_changed.connect(_on_player_health_changed)
		
	# Links player fire tracking to UILayer directly with zero string-lookups
	if active_player.has_signal("reload_progress_changed"):
		if is_instance_valid(ui_layer) and ui_layer.has_method("update_reload_meter"):
			active_player.reload_progress_changed.connect(ui_layer.update_reload_meter)
	
	# Sync health visuals with new instance pool
	_on_player_health_changed(Global.player_health)
	update_lives_display()
	print("🛸 Modular Player dynamically injected and avalanche signal tunnels mapped.")


## SIGNAL CATCH: Fired instantly down the mountain by Player.gd when hit
func _on_player_health_changed(new_health: int) -> void:
	if is_instance_valid(health_bar):
		health_bar.max_value = Global.player_health
		if health_bar.has_method("update_health"):
			health_bar.update_health(new_health)
		else:
			health_bar.value = new_health
		
	# DANGER OVERLAY HANDLING
	trigger_danger_state(new_health == 1)


## ANIMATION TWEEN: Handles smooth fade-in/out pulsing loops for low health without frame overhead
func trigger_danger_state(activate: bool) -> void:
	if not is_instance_valid(danger_ui): 
		return
	
	if activate:
		if danger_tween and danger_tween.is_valid(): 
			return # Already playing
		danger_ui.visible = true
		
		# 🟢 FIXED: Guarded with ResourceLoader check to prevent errors if file doesn't exist
		var path = "res://Sounds/sfx/warning_beep.wav"
		var warning_sfx: AudioStream = null
		if ResourceLoader.exists(path):
			warning_sfx = load(path) as AudioStream
			
		display_notification_stream("", Color.WHITE, 0, warning_sfx)
		
		danger_tween = create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		danger_tween.tween_property(danger_ui, "modulate:a", 0.6, 0.5)
		danger_tween.tween_property(danger_ui, "modulate:a", 0.1, 0.5)
	else:
		if danger_tween and danger_tween.is_valid():
			danger_tween.kill()
		danger_ui.visible = false
		danger_ui.modulate.a = 0.0


## Centralized system to push banners, text alerts, and preloaded audio cues directly to the screen
func display_notification_stream(text: String, text_color: Color = Color.WHITE, font_size: int = 48, sfx: AudioStream = null) -> void:
	if not is_instance_valid(notification_label): 
		return
		
	notification_label.add_theme_color_override("default_color", text_color)
	notification_label.add_theme_font_size_override("normal_font_size", font_size)
	notification_label.text = text
	notification_label.visible = text != ""
	
	if sfx and is_instance_valid(audio_player):
		audio_player.stream = sfx
		audio_player.play()


func clear_notification() -> void:
	if is_instance_valid(notification_label):
		notification_label.visible = false


## Hook triggered whenever the player character dies
func handle_player_death() -> void:
	print("💀 Player has been destroyed! Preparing death presentation...")
	trigger_danger_state(false)
	
	# Swapped to a real-time scene timer so player death sequences don't freeze on impact
	await get_tree().create_timer(1.0, true, false, true).timeout
	
	# Route death lifestyle execution to your selected mode managers
	if Global.current_game_mode == Global.GameMode.DEBUG and is_instance_valid(debug_mode_manager):
		debug_mode_manager.restart_mode()
	elif is_instance_valid(arcade_mode_manager):
		arcade_mode_manager.restart_mode()
		
	update_lives_display()
