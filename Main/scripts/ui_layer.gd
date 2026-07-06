extends CanvasLayer
class_name UILayer

# --- Node Anchors ---
@onready var score_label: Label = $ScoreLabel
@onready var session_record_label: Label = $SessionRecord
@onready var health_bar: ProgressBar = $HealthBar
@onready var lives_label: HBoxContainer = $LivesLabel

# 🟢 SIMPLIFIED: Swapped from TextureProgressBar to your custom ReloadBar class script
@onready var reload_bar: ReloadBar = $ReloadBar
@onready var danger_indicator: TextureRect = $DangerIndicator


func _ready() -> void:
	print("🎛️ UI Layer Master Controller Initialized.")
	configure_mode_visibility()


func configure_mode_visibility() -> void:
	var mode = Global.current_game_mode
	match mode:
		Global.GameMode.DEBUG:
			if is_instance_valid(lives_label): lives_label.visible = false
			if is_instance_valid(session_record_label): session_record_label.visible = false
		Global.GameMode.ARCADE, Global.GameMode.ENDLESS, Global.GameMode.RUSH:
			if is_instance_valid(lives_label): lives_label.visible = true
			if is_instance_valid(session_record_label): session_record_label.visible = true


## 🟢 CENTRALIZED METRIC LINK: Updates our smooth internal tracking slider values
func update_reload_meter(progress_factor: float) -> void:
	if is_instance_valid(reload_bar):
		reload_bar.set_reload_percentage(progress_factor)


## 🟢 HYBRID TRACKER: Draws individual icons up to 3, then switches to "Icon x A"
func refresh_lives_counter() -> void:
	if not is_instance_valid(lives_label): 
		return
		
	# 1. Clear out the previous layout completely
	for child in lives_label.get_children():
		child.queue_free()
		
	# 2. Grab the live texture from the active player
	var active_texture: Texture2D = null
	var world_node = get_tree().current_scene as World
	
	if is_instance_valid(world_node) and "active_player" in world_node:
		var player = world_node.active_player
		if is_instance_valid(player):
			var sprite = player.get_node_or_null("Sprite2D") as Sprite2D
			if is_instance_valid(sprite):
				active_texture = sprite.texture

	# 🟢 FIXED: Swapped 'Global.lives' to your correct profile name 'Global.player_lives'
	var current_lives = Global.player_lives if "player_lives" in Global else 3
	
	# Fallback if no lives left
	if current_lives <= 0:
		return

	# 3. Apply Hybrid Layout Rules
	if current_lives <= 3:
		# --- STANDARD SYSTEM: Draw 1, 2, or 3 separate ship icons ---
		for i in range(current_lives):
			_create_and_add_icon(active_texture)
	else:
		# --- ARCADE HYBRID SYSTEM: Draw exactly 1 icon + "x A" text text string ---
		_create_and_add_icon(active_texture)
		
		var text_counter := Label.new()
		text_counter.text = " x " + str(current_lives)
		text_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		lives_label.add_child(text_counter)


## Helper function to keep our instantiation settings uniform
func _create_and_add_icon(tex: Texture2D) -> void:
	var icon = TextureRect.new()
	if tex:
		icon.texture = tex
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE 
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lives_label.add_child(icon)
