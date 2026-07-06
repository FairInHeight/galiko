extends Label

func _ready() -> void:
	# Establish the starting text baseline immediately on boot
	text = "SCORE: " + str(Global.score)
	print("🎯 Score Label Initialized.")


## 🟢 CALLED BY WORLD: Updates the text instantly when score events happen
func update_display(new_score: int) -> void:
	text = "SCORE: " + str(new_score)
