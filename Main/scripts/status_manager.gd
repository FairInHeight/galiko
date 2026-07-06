class_name StatusManager
extends Node

enum StatusEffect {
	NONE,
	BURN,       # Damage over time + percentage decrease to fire rate
	POISON,     # Faster damage over time for shorter durations
	FREEZE,     # Slows movement speed temporarily
	STUN,       # Briefly stops the player from moving or firing
	RADIATION,  # Decreases max health temporarily (indicated by secondary bar overlay)
	CONFUSE     # Reverse inputs temporarily + scramble the HUD
}
