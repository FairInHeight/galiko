extends Control

# Guard flag to prevent the initial boot-up focus sound
var is_ready: bool = false
@onready var menu_music_player: AudioStreamPlayer = $MenuMusicPlayer

func _ready() -> void:
	# --- 1. FORCE CURSOR VISIBILITY & AUDIO/DELAY OVERRIDES ---
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("Main Menu Loaded: Mouse forced visible.")
	
	if has_node("QuitButton"): 
		$QuitButton.set_meta("custom_select", "res://Sounds/sfx/death.wav")
		$QuitButton.set_meta("select_delay", 0.4)

	# --- 2. THE UNIFIED BUTTON LOOP ---
	for child in get_children():
		if child is Button:
			child.focus_entered.connect(func(): if is_ready: UiManager.play_hover(child))
			child.mouse_entered.connect(func(): if is_ready: UiManager.play_hover(child))
			child.pressed.connect(func(): _on_button_pressed(child))
	
	# --- 3. INITIAL FOCUS ---
	if has_node("ArcadeButton"):
		$ArcadeButton.grab_focus()
	
	# --- FOOLPROOF PERSISTENT MUSIC CHECK ---
	if get_tree().root.has_meta("active_menu_music"):
		if menu_music_player:
			menu_music_player.queue_free()
		
		var existing_root_music = get_tree().root.get_node_or_null("MenuMusicPlayer")
		if existing_root_music:
			existing_root_music.get_parent().remove_child(existing_root_music)
			add_child(existing_root_music)
			menu_music_player = existing_root_music
	else:
		if menu_music_player and not menu_music_player.playing:
			menu_music_player.play()
			get_tree().root.set_meta("active_menu_music", true)
	
	is_ready = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start") or event.is_action_pressed("fire"):
		var focused_button = get_viewport().gui_get_focus_owner()
		if focused_button is Button and is_ancestor_of(focused_button):
			get_viewport().set_input_as_handled()
			focused_button.emit_signal("pressed")


# --- UNIFIED BUTTON HANDLER ---

func _on_button_pressed(button: Button) -> void:
	UiManager.play_select(button)
	
	if button.has_meta("select_delay"):
		await get_tree().create_timer(button.get_meta("select_delay")).timeout

	match button.name:
		"ArcadeButton":
			Global.setup_game_mode(Global.GameMode.ARCADE)
			load_character_select()
			
		"DebugButton":
			Global.setup_game_mode(Global.GameMode.DEBUG)
			load_character_select()
			
		"SettingsButton":
			pass
			
		"QuitButton":
			get_tree().quit()


# --- SCENE TRANSITIONS ---

func load_character_select() -> void:
	var character_select_scene := load("res://Menus/scenes/character_select.tscn") as PackedScene
	if character_select_scene:
		if menu_music_player:
			menu_music_player.get_parent().remove_child(menu_music_player)
			get_tree().root.add_child(menu_music_player)
			
		var next_scene = character_select_scene.instantiate()
		get_tree().root.add_child(next_scene)
		get_tree().current_scene = next_scene
		queue_free()
	else:
		print("Error: Could not find res://Menus/scenes/character_select.tscn via path string!")
