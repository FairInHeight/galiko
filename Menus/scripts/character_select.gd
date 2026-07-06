extends Control

# Guard flag to prevent the initial boot-up focus sound
var is_ready: bool = false

# Dictionary to map button names to their corresponding ship textures cleanly
const SHIP_TEXTURES = {
	"RedShip": "res://Sprites/players/character_red.png",
	"BlueShip": "res://Sprites/players/character_blue.png",
	"GreenShip": "res://Sprites/players/character_green.png",
	"YellowShip": "res://Sprites/players/character_yellow.png",
	"PurpleShip": "res://Sprites/players/character_purple.png",
	"WhiteShip": "res://Sprites/players/character_white.png",
	"OrangeShip": "res://Sprites/players/character_orange.png",
	"CyanShip": "res://Sprites/players/character_cyan.png",
	"PinkShip": "res://Sprites/players/character_pink.png",
	"BlackShip": "res://Sprites/players/character_black.png"
}

func _ready() -> void:
	# --- 1. THE UNIFIED BUTTON LOOP ---
	for child in get_children():
		if child is Button:
			# Pass 'child' so UiManager checks for metadata overrides
			child.focus_entered.connect(func(): if is_ready: UiManager.play_hover(child))
			child.mouse_entered.connect(func(): if is_ready: UiManager.play_hover(child))
			child.pressed.connect(func(): _on_button_pressed(child))
	
	# --- 2. INITIAL FOCUS ---
	if has_node("WhiteShip"):
		$WhiteShip.grab_focus()
	
	is_ready = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start") or event.is_action_pressed("fire"):
		var focused_button = get_viewport().gui_get_focus_owner()
		if focused_button is Button and is_ancestor_of(focused_button):
			get_viewport().set_input_as_handled()
			focused_button.emit_signal("pressed")
			
	elif event.is_action_pressed("ui_cancel"):
		# REMOVED set_input_as_handled() so UiManager can hear it!
		go_back_to_main_menu()


# --- UNIFIED BUTTON HANDLER ---

func _on_button_pressed(button: Button) -> void:
	UiManager.play_select(button)
	
	# Truly dynamic delay check via metadata
	if button.has_meta("select_delay"):
		await get_tree().create_timer(button.get_meta("select_delay")).timeout

	# Handle ship selection dynamically using our dictionary lookup
	if button.name in SHIP_TEXTURES:
		Global.selected_ship_texture = SHIP_TEXTURES[button.name]
		launch_game()


# --- SCENE TRANSITIONS ---

func launch_game() -> void:
	# Hunt down the player node stored at the root tree level and clean it out
	var music = get_tree().root.get_node_or_null("MenuMusicPlayer")
	if music:
		music.stop()
		music.queue_free()
	
	# Clear out the metadata flag completely so next time we boot to main menu it starts fresh
	if get_tree().root.has_meta("active_menu_music"):
		get_tree().root.remove_meta("active_menu_music")

	# BOOT DIRECTLY INTO THE WORLD STAGE
	# Make sure this string matches the exact path to your main world file!
	get_tree().change_scene_to_file("res://Main/scenes/world.tscn")

func go_back_to_main_menu() -> void:
	# DO NOT stop or kill the music player here. 
	# Leave it alive on the root window so the main menu can grab it and keep it playing!
	get_tree().change_scene_to_file("res://Menus/scenes/main_menu.tscn")
