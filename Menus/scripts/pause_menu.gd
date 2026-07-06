extends Control

# Guard flag to prevent the initial focus sound when opening the menu
var is_ready: bool = false

# 🛑 INPUT LOCKOUT FLAG: Prevents input spam/double-clicks while waiting for actions
var is_processing_click: bool = false

@onready var pause_screen: Control = $PauseScreen
@onready var debug_menu: Control = $DebugMenu

func _ready() -> void:
	# 🟢 Forces the engine to natively process UI clicks, focus, and ui_accept when paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	hide()
	if debug_menu: debug_menu.hide()
	if pause_screen: pause_screen.show()
	
	set_anchors_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	
	# --- 1. DYNAMIC AUDIO OVERRIDES ---
	if has_node("PauseScreen/MainMenuButton"):
		$PauseScreen/MainMenuButton.set_meta("custom_select", "res://Sounds/sfx/explode.wav")
		
	# Automatically hide/show the Debug Button based on global mode
	if has_node("PauseScreen/DebugButton"):
		$PauseScreen/DebugButton.visible = (Global.current_game_mode == Global.GameMode.DEBUG)
	
	# --- 2. THE UNIFIED BUTTON LOOP ---
	if pause_screen:
		for child in pause_screen.get_children():
			if child is Button:
				child.focus_entered.connect(func(): if is_ready: UiManager.play_hover(child))
				child.mouse_entered.connect(func(): if is_ready: UiManager.play_hover(child))
				child.pressed.connect(func(): _on_button_pressed(child))
	
	# --- 3. INITIAL FOCUS ---
	if has_node("PauseScreen/ResumeButton"):
		$PauseScreen/ResumeButton.grab_focus()
		
	is_ready = true


# --- UNIFIED BUTTON HANDLER ---

func _on_button_pressed(button: Button) -> void:
	# Guard clause: stop execution immediately if we are already handling a click
	if is_processing_click:
		return
		
	is_processing_click = true
	UiManager.play_select(button)
	
	if button.name == "MainMenuButton":
		await get_tree().create_timer(0.4).timeout

	match button.name:
		"ResumeButton":
			toggle_pause()
			
		"MainMenuButton":
			if Global.has_method("reset_game"):
				Global.reset_game()
			get_tree().paused = false
			get_tree().change_scene_to_file("res://Menus/scenes/main_menu.tscn")
			
		"DebugButton":
			if pause_screen: pause_screen.hide() 
			if debug_menu: 
				debug_menu.show() 
				if debug_menu.has_method("open_menu"):
					debug_menu.open_menu() 

	# Release the click lock once the execution finishes
	is_processing_click = false


# --- INPUT & CORE LOGIC ---

func _unhandled_input(event: InputEvent) -> void:
	# 🛑 HARD LOCKOUT: Consumes all player inputs (keyboard/controller/mouse) while a button is processing
	if is_processing_click:
		get_viewport().set_input_as_handled()
		return

	if debug_menu and debug_menu.visible:
		return

	if event.is_action_pressed("start"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if Global.is_in_cutscene:
		return 
		
	get_tree().paused = !get_tree().paused
	show() if get_tree().paused else hide()
	
	if get_tree().paused:
		is_ready = false
		
		# Free and center mouse cursor
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		var center_position = get_viewport().get_visible_rect().size / 2.0
		get_window().warp_mouse(center_position)
		
		if debug_menu: debug_menu.hide()
		if pause_screen: pause_screen.show()
		
		if has_node("PauseScreen/ResumeButton"):
			$PauseScreen/ResumeButton.grab_focus()
		is_ready = true
	else:
		# Check mouse location when unpausing
		var window_mouse_pos = get_viewport().get_mouse_position()
		var window_size = get_viewport().get_visible_rect().size
		
		var is_mouse_inside_window = (
			window_mouse_pos.x >= 0 and window_mouse_pos.x <= window_size.x and
			window_mouse_pos.y >= 0 and window_mouse_pos.y <= window_size.y
		)
		
		if is_mouse_inside_window:
			Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
