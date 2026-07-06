extends Node

# Tier 1: Global Defaults
const SFX_HOVER = "res://Sounds/sfx/blip.wav"
const SFX_SELECT = "res://Sounds/sfx/fire.wav"
const SFX_CANCEL = "res://Sounds/sfx/cancel.wav" 

## --- AUTOMATIC GLOBAL CANCEL LISTENER ---
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var current_scene = get_tree().current_scene
		if is_instance_valid(current_scene):
			var scene_path = current_scene.scene_file_path
			
			# RULE: If the active scene path is NOT in your Menus folder, 
			# we are playing the game! Abort immediately so audio doesn't glitch.
			if not "Menus" in scene_path:
				return
				
			# If it's a UI/Menu screen, intercept and handle the sound automatically
			if current_scene is Control:
				play_cancel(current_scene)

## Global shortcuts supporting Tier 2 (Script/Menu overrides) and Tier 3 (Button Metadata overrides)
func play_hover(button_node: Button = null, menu_override: String = "") -> void:
	if button_node and button_node.has_meta("custom_hover"):
		play_sfx(button_node.get_meta("custom_hover"))
	elif menu_override != "":
		play_sfx(menu_override)
	else:
		play_sfx(SFX_HOVER)

func play_select(button_node: Button = null, menu_override: String = "") -> void:
	if button_node and button_node.has_meta("custom_select"):
		play_sfx(button_node.get_meta("custom_select"))
	elif menu_override != "":
		play_sfx(menu_override)
	else:
		play_sfx(SFX_SELECT)

## Cancel Shortcut supporting Tier 2 and Tier 3 overrides
func play_cancel(node: Node = null, menu_override: String = "") -> void:
	if is_instance_valid(node) and node.has_meta("custom_cancel"):
		play_sfx(node.get_meta("custom_cancel"))
	elif menu_override != "":
		play_sfx(menu_override)
	else:
		play_sfx(SFX_CANCEL)

## Play any sound effect by path safely (Your original logic completely unchanged!)
func play_sfx(sound_path: String) -> void:
	if not ResourceLoader.exists(sound_path):
		print("⚠️ [UIManager]: Sound file missing at: ", sound_path)
		return
		
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = load(sound_path)
	
	if "hover" in sound_path or "blip" in sound_path:
		var active_hovers = 0
		for child in get_children():
			if child is AudioStreamPlayer and child.playing:
				if "hover" in child.stream.resource_path or "blip" in child.stream.resource_path:
					active_hovers += 1
		
		if active_hovers >= 2:
			sfx_player.volume_db = -6.0
	
	add_child(sfx_player)
	sfx_player.play()
	
	sfx_player.finished.connect(func():
		sfx_player.queue_free()
)
