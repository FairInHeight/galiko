class_name EnemyData
extends Resource

@export_group("Identity & Typing")
@export var enemy_name: String = "New Enemy"
## The elemental archetype of this enemy
@export var elemental_type: TypeManager.Type = TypeManager.Type.DEFAULT
@export var icon: Texture2D            # For your dynamic debug scrolling menu
@export var enemy_scene: PackedScene  

@export_group("Core Stats")
@export var enemy_max_health: int = 2
@export var enemy_speed: float = 150.0
@export var acceleration_weight: float = 10.0 # Control LERP responsiveness for AI paths
@export var score_value: int = 100

@export_group("Combat Stats")
@export var enemy_bullet_damage: int = 1
@export var enemy_fire_rate: float = 1.5        # Time in seconds between shots
@export var enemy_bullet_velocity: float = 300.0 # Speed of fired enemy projectiles
## The elemental type assigned to this enemy's attacks
@export var damage_type: TypeManager.Type = TypeManager.Type.DEFAULT
## The status condition inflicted on a successful status roll
@export var effect_type: StatusManager.StatusEffect = StatusManager.StatusEffect.NONE
## Percentage chance (0.0 to 1.0) for the status effect to apply on impact
@export_range(0.0, 1.0) var effect_chance: float = 0.15

@export_group("AI & Behavioral Directives")
@export var default_ai_mode: int = 1 # Maps cleanly to your AIMode.IDLE index
@export var default_fire_mode: int = 0 # Maps cleanly to your FireMode.HOLD_FIRE index
@export var screen_wrap_default: bool = true

@export_group("Audio Customization")
@export var death_sound_stream: AudioStream = preload("res://Sounds/sfx/explode.wav")
## Weapon fire sound effect for this archetype. Safe if left null.
@export var enemy_fire_sound: AudioStream
## 🟢 NEW: Impact sound effect triggered when taking damage. Safe if left null.
@export var enemy_hurt_sound: AudioStream
## Looping background engine hum when idling/sniping. Safe if left null.
@export var ambient_idle_sound: AudioStream
## Looping background engine hum when chasing/diving. Safe if left null.
@export var ambient_moving_sound: AudioStream

@export_group("Visual Sheet Dimensions")
@export var enemy_texture: Texture2D = preload("res://Sprites/placeholder_enemy.png")
## Backward Compatible Default: 1 column for standard single-image PNGs
@export var sheet_hframes: int = 1 
## Backward Compatible Default: 1 row for standard single-image PNGs
@export var sheet_vframes: int = 1 

@export_group("State Particle Customization")
## Optional: Particles that emit constantly while the enemy is alive. Safe if left null.
@export var ambient_particles: PackedScene
## Optional: Particles that burst out a single time when taking damage. Safe if left null.
@export var hurt_particles: PackedScene
## Optional: Particles that emit specifically when the enemy attacks. Safe if left null.
@export var attack_particles: PackedScene

@export_group("Animation Sequencer: Idle")
@export var idle_start_frame: int = 0
@export var idle_end_frame: int = 0
@export var idle_fps: float = 8.0
@export var idle_loop: bool = true

@export_group("Animation Sequencer: Walk/Move")
@export var walk_start_frame: int = 0
@export var walk_end_frame: int = 0
@export var walk_fps: float = 12.0
@export var walk_loop: bool = true

@export_group("Animation Sequencer: Attack")
@export var attack_start_frame: int = 0
@export var attack_end_frame: int = 0
@export var attack_fps: float = 10.0
@export var attack_loop: bool = false

@export_group("Animation Sequencer: Hurt")
@export var hurt_start_frame: int = 0
@export var hurt_end_frame: int = 0
@export var hurt_fps: float = 15.0
@export var hurt_loop: bool = false
