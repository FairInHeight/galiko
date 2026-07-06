extends Label

func _ready() -> void:
	# Establish the starting record baseline on boot
	text = "HI-SCORE: " + str(Global.session_record)
	print("🏆 Session Record Label Initialized.")


## 🟢 CALLED BY WORLD: Updates the text instantly when a new high score is written
func update_display(new_record: int) -> void:
	text = "HI-SCORE: " + str(new_record)
