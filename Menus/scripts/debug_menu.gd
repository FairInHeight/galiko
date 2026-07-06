extends Control

func _ready() -> void:
	# Hide the sandbox tools on startup until explicitly called
	hide()

# Called by the parent Pause Menu when the user clicks "DebugButton"
func open_menu() -> void:
	# If you add buttons inside a container later, you can grab focus to the first button here.
	# For now, it just prints confirmation to the console.
	print("🛠️ [Debug Menu]: Active and ready.")

func _unhandled_input(event: InputEvent) -> void:
	# If this menu is open and the player hits Escape / Back / B button
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled() # Consume the input
		hide() # Make this debug overlay vanish
		
		# Pull back the standard pause screen and restore button focus
		var parent_menu = get_parent()
		if parent_menu:
			if parent_menu.has_node("PauseScreen"):
				parent_menu.get_node("PauseScreen").show()
			if parent_menu.has_node("PauseScreen/ResumeButton"):
				parent_menu.get_node("PauseScreen/ResumeButton").grab_focus()
