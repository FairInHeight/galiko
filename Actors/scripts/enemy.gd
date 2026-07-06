class_name Enemy
extends Area2D

const EXPLOSION_SCENE = preload("res://explosion.tscn")

# ==========================================
# AUDIO PIPELINE ENGINE PRELOADS
# ==========================================
const DEFAULT_FIRE_SOUND = preload("res://Sounds/sfx/zap.wav")
const DEFAULT_HURT_SOUND = preload("res://Sounds/sfx/enemy_hurt.wav")

# ==========================================
# SYSTEM ENUMS
# ==========================================
enum AIMode {
	DEBUG = 0,
	IDLE = 1,
	SNIPE = 2,
	DIVE = 3,
	CHASE = 4,
	RETREAT = 5,
	REGROUP = 6
}

enum FireMode {
	HOLD_FIRE = 0,
	SEEDED_CHAOS = 1,
	MAX_OUTPUT = 2
}

# ==========================================
# CORE DATA (Populated by EnemyData packet)
# ==========================================
var enemy_name: String = "Base Enemy"
var enemy_max_health: int = 2
var enemy_speed: float = 150.0
var acceleration_weight: float = 10.0
var score_value: int = 100

# ==========================================
# ADVANCED TYPING & STATUS (Populated by EnemyData)
# ==========================================
var elemental_type: TypeManager.Type = TypeManager.Type.DEFAULT
var damage_type: TypeManager.Type = TypeManager.Type.DEFAULT
var effect_type: StatusManager.StatusEffect = StatusManager.StatusEffect.NONE
var effect_chance: float = 0.0

# ==========================================
# COMBAT & WEAPONS (Populated by EnemyData)
# ==========================================
var enemy_bullet_damage: int = 1
var enemy_fire_rate: float = 1.0        # Time in seconds between shots
var enemy_bullet_velocity: float = 300.0 # Speed of fired enemy projectiles

# ==========================================
# EXTERNAL AI STATE CONFIGURATION
# ==========================================
var ai_mode: AIMode = AIMode.IDLE
var fire_mode: FireMode = FireMode.HOLD_FIRE
var wrap_enabled: bool = true # Toggleable screen wrap setting

# ==========================================
# ASSET REFERENCES (Populated by EnemyData)
# ==========================================
var death_sound_stream: AudioStream
var enemy_fire_sound: AudioStream = DEFAULT_FIRE_SOUND  # Defaults cleanly out of the box
var enemy_hurt_sound: AudioStream = DEFAULT_HURT_SOUND  # Defaults cleanly out of the box
var enemy_texture: Texture2D

# State-Driven Ambient Audio Streams
var ambient_idle_sound: AudioStream = null    # Silent by default
var ambient_moving_sound: AudioStream = null  # Silent by default

# ==========================================
# STATE PARTICLE SCENES (Populated by EnemyData)
# ==========================================
var ambient_particles_scene: PackedScene
var hurt_particles_scene: PackedScene
var attack_particles_scene: PackedScene

# Internal node reference tracking for persistent particle loops
var active_ambient_node: Node2D = null

# ==========================================
# INTERNAL STATE TRACKING
# ==========================================
var enemy_current_health: int
var is_dying: bool = false
var explosion_momentum_mult: float = 1.0
var anchor_position: Vector2 = Vector2.ZERO # Initial grid slot coordinate anchor

# Persistent internal player dedicated to cycling looping ambient soundscapes
var active_loop_player: AudioStreamPlayer2D = null

# ==========================================
# GRID DATA COORD TRACKING (Assigned by Spawner)
# ==========================================
var grid_row: int = -1
var grid_column: int = -1

# ==========================================
# NODE REFERENCES
# ==========================================
@onready var sprite: Sprite2D = $Sprite2D
# Cached tracking reference for our incoming modular AI Brain script node
@onready var ai_brain: Node = get_node_or_null("EnemyBrain")


# ==========================================
# LIFECYCLE METHODS
# ==========================================
func _ready() -> void:
	enemy_current_health = enemy_max_health
	area_entered.connect(_on_area_entered)
	
	# Cache original spawn position as our structural retreat anchor point
	anchor_position = global_position
	
	_update_sprite_setup()
	_apply_elemental_modulation()
	_initialize_ambient_particles()
	_initialize_ambient_audio()


func _physics_process(delta: float) -> void:
	if is_dying:
		return
		
	# THE DYNAMIC AUTOPILOT: If it's missing from the hierarchy tree, spawn it programmatically!
	if not is_instance_valid(ai_brain):
		ai_brain = get_node_or_null("EnemyBrain")
		
		if not ai_brain:
			var brain_script = load("res://Actors/scenes/enemy_brain.gd")
			if brain_script:
				var new_brain = Node.new()
				new_brain.set_script(brain_script)
				new_brain.name = "EnemyBrain"
				add_child(new_brain)
				ai_brain = new_brain
				
				if ai_brain.has_method("sync_with_enemy_data"):
					ai_brain.sync_with_enemy_data()
				print("🧠 [Dynamic Component]: Successfully generated missing EnemyBrain child node for ", name)
		
	# 1. DELEGATE VECTOR GENERATION TO THE AI BRAIN
	var velocity := Vector2.ZERO
	if is_instance_valid(ai_brain) and ai_brain.has_method("get_movement_velocity"):
		velocity = ai_brain.get_movement_velocity(delta)
		
		# DIAGNOSTIC MONITOR: Prints movement feedback if an enemy is told to attack/dive
		if ai_mode != AIMode.IDLE and ai_mode != AIMode.DEBUG:
			print("🧠 [Brain Active] ", enemy_name, " (Row:", grid_row, " Col:", grid_column, ") processing AI Mode: ", ai_mode, " | Outgoing Velocity: ", velocity)
	
	global_position += velocity * delta
	
	# 2. OPTIMIZED WRAP AND SCREEN LIMIT RULES
	_handle_screen_boundaries()


## Manages boundary checks dynamically based on the wrap_enabled flag status.
func _handle_screen_boundaries() -> void:
	var screen_size := get_viewport_rect().size
	var half_width := 32.0 # Adjust size buffer padding value as needed for sprites
	
	if wrap_enabled:
		# Warp edges instantly across X axis boundaries
		if global_position.x < -half_width:
			global_position.x = screen_size.x + half_width
		elif global_position.x > screen_size.x + half_width:
			global_position.x = -half_width
			
		# Silently clean up if an enemy completely falls past the bottom floor line
		if global_position.y > screen_size.y + 64.0:
			queue_free()
	else:
		# Instantly delete entity when completely exiting visual arena space
		if (global_position.x < -half_width or 
			global_position.x > screen_size.x + half_width or 
			global_position.y < -64.0 or 
			global_position.y > screen_size.y + 64.0):
				queue_free()


# ==========================================
# DATA INJECTION HOOK
# ==========================================
func init_from_data(data: EnemyData) -> void:
	if not data:
		print("⚠️ Warning: Passed null data packet to ", name)
		return
		
	enemy_name = data.enemy_name
	elemental_type = data.elemental_type
	enemy_max_health = data.enemy_max_health
	enemy_current_health = enemy_max_health
	enemy_speed = data.enemy_speed
	acceleration_weight = data.acceleration_weight
	score_value = data.score_value
	
	# Advanced Typings and Effects
	damage_type = data.damage_type
	effect_type = data.effect_type
	effect_chance = data.effect_chance
	
	enemy_bullet_damage = data.enemy_bullet_damage
	enemy_fire_rate = data.enemy_fire_rate
	enemy_bullet_velocity = data.enemy_bullet_velocity
	
	# Behavior Fallback Overrides
	ai_mode = data.default_ai_mode as AIMode
	fire_mode = data.default_fire_mode as FireMode
	wrap_enabled = data.screen_wrap_default
	
	# ==========================================
	# STREAMLINED DATA OVERWRITE ROUTINES
	# ==========================================
	death_sound_stream = data.death_sound_stream
	
	if "enemy_fire_sound" in data and data.enemy_fire_sound: 
		enemy_fire_sound = data.enemy_fire_sound
	if "enemy_hurt_sound" in data and data.enemy_hurt_sound: 
		enemy_hurt_sound = data.enemy_hurt_sound
	if "ambient_idle_sound" in data and data.ambient_idle_sound: 
		ambient_idle_sound = data.ambient_idle_sound
	if "ambient_moving_sound" in data and data.ambient_moving_sound: 
		ambient_moving_sound = data.ambient_moving_sound
	
	enemy_texture = data.enemy_texture
	
	# Particle Scene Transference
	ambient_particles_scene = data.ambient_particles
	hurt_particles_scene = data.hurt_particles
	attack_particles_scene = data.attack_particles
	
	if not sprite:
		await ready
		
	if sprite and data:
		sprite.hframes = data.sheet_hframes
		sprite.vframes = data.sheet_vframes
		
	# 🟢 METALINK DATA TUNNEL: Transfer animation properties securely to meta-storage
	# This ensures your parent.get() script queries inside EnemyBrain pull data seamlessly!
	set_meta("idle_start_frame", data.idle_start_frame)
	set_meta("idle_end_frame", data.idle_end_frame)
	set_meta("idle_fps", data.idle_fps)
	set_meta("idle_loop", data.idle_loop)
	
	set_meta("walk_start_frame", data.walk_start_frame)
	set_meta("walk_end_frame", data.walk_end_frame)
	set_meta("walk_fps", data.walk_fps)
	set_meta("walk_loop", data.walk_loop)
	
	set_meta("attack_start_frame", data.attack_start_frame)
	set_meta("attack_end_frame", data.attack_end_frame)
	set_meta("attack_fps", data.attack_fps)
	set_meta("attack_loop", data.attack_loop)
	
	set_meta("hurt_start_frame", data.hurt_start_frame)
	set_meta("hurt_end_frame", data.hurt_end_frame)
	set_meta("hurt_fps", data.hurt_fps)
	set_meta("hurt_loop", data.hurt_loop)
		
	_update_sprite_setup()
	_apply_elemental_modulation()
	_initialize_ambient_particles()
	_initialize_ambient_audio()

	# Ensure the dynamic search check passes even if initialization occurs pre-ready frame
	if not is_instance_valid(ai_brain):
		ai_brain = get_node_or_null("EnemyBrain")

	# THE AGNOSTIC HOOKUP: Let the modular brain know data tracking parameters have loaded
	if is_instance_valid(ai_brain) and ai_brain.has_method("sync_with_enemy_data"):
		ai_brain.sync_with_enemy_data()


## Helper utility ensuring sprite rendering configurations apply uniformly
func _update_sprite_setup() -> void:
	if sprite and enemy_texture:
		sprite.texture = enemy_texture


## Master Class owns visual presentation: Maps unique visual styles per archetype
func _apply_elemental_modulation() -> void:
	if not sprite:
		return
		
	match elemental_type:
		TypeManager.Type.FIRE:
			sprite.self_modulate = Color(1.8, 0.2, 0.2, 1.0)  # Blazing Crimson Red
		
		TypeManager.Type.ICE:
			sprite.self_modulate = Color(0.4, 1.3, 1.8, 1.0)  # Frozen Cyan Blue
		
		TypeManager.Type.ELECTRIC:
			sprite.self_modulate = Color(1.8, 1.6, 0.1, 1.0)  # High-Voltage Bright Yellow
		
		TypeManager.Type.TOXIC:
			sprite.self_modulate = Color(1.1, 0.1, 1.4, 1.0)  # Acidic Deep Purple
		
		TypeManager.Type.NUCLEAR:
			sprite.self_modulate = Color(1.2, 1.8, 0.1, 1.0)  # Gamma Neon Lime Green
		
		TypeManager.Type.PLASMA:
			sprite.self_modulate = Color(1.6, 0.5, 0.1, 1.0)  # Radiant Superheated Orange
		
		TypeManager.Type.CYBER:
			sprite.self_modulate = Color(0.1, 0.7, 1.8, 1.0)  # Cyberpunk Electric Teal
		
		TypeManager.Type.BIO:
			sprite.self_modulate = Color(0.2, 1.4, 0.5, 1.0)  # Organic Moss Green
		
		TypeManager.Type.PSYCHIC:
			sprite.self_modulate = Color(1.6, 0.2, 1.1, 1.0)  # Astral Neon Magenta / Pink
		
		TypeManager.Type.VOID:
			sprite.self_modulate = Color(0.4, 0.1, 0.6, 1.0)  # Dark Abyssal Violet
			
		_:
			sprite.self_modulate = Color.WHITE              # Standard Vanilla / Base Sheet Look


## Handles programmatic startup generation for looping ambient emitters
func _initialize_ambient_particles() -> void:
	if not is_inside_tree():
		await ready
		
	if is_instance_valid(active_ambient_node):
		active_ambient_node.queue_free()
		
	if ambient_particles_scene:
		var particles = ambient_particles_scene.instantiate()
		add_child(particles)
		active_ambient_node = particles as Node2D


## Instantiates the persistent engine loop node
func _initialize_ambient_audio() -> void:
	if not is_inside_tree():
		await ready
		
	if is_instance_valid(active_loop_player):
		return
		
	active_loop_player = AudioStreamPlayer2D.new()
	active_loop_player.max_distance = 800.0
	active_loop_player.attenuation = 1.5
	active_loop_player.bus = "SFX"
	add_child(active_loop_player)
	
	# Default initialize on the base idle stream if provided
	if ambient_idle_sound:
		active_loop_player.stream = ambient_idle_sound
		active_loop_player.play()


## Engine room interface invoked smoothly by the animation brain ticker
func update_ambient_loop_variant(animation_state: String) -> void:
	if not is_instance_valid(active_loop_player):
		return
		
	var target_stream: AudioStream = null
	
	match animation_state:
		"walk", "attack":
			target_stream = ambient_moving_sound if ambient_moving_sound else ambient_idle_sound
		_:
			target_stream = ambient_idle_sound

	# Seamless change check: Only touch playback if transitioning to a completely different sound block
	if active_loop_player.stream != target_stream:
		var current_playback_pos = active_loop_player.get_playback_position()
		active_loop_player.stream = target_stream
		if target_stream:
			active_loop_player.play(current_playback_pos) # Retains rhythm patterns across track variations
		else:
			active_loop_player.stop()


# ==========================================
# 🟢 OPTIMIZED WEAPON FIRING PIPELINE
# ==========================================
## Spawns an archetype projectile and stamps it completely with our status/damage configurations.
func fire_projectile(bullet_scene: PackedScene, spawn_global_pos: Vector2) -> void:
	if not bullet_scene or is_dying:
		return
		
	var bullet = bullet_scene.instantiate()
	# Add projectile to main world space so it flies independently of moving enemy grids
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = spawn_global_pos
	
	# Play muzzle blast sound effect
	if enemy_fire_sound:
		var fire_sfx = AudioStreamPlayer2D.new()
		fire_sfx.stream = enemy_fire_sound
		fire_sfx.bus = "SFX"
		get_tree().current_scene.add_child(fire_sfx)
		fire_sfx.play()
		fire_sfx.finished.connect(func(): fire_sfx.queue_free())
		
	# Stamp data attributes directly onto the bullet instance
	if bullet.has_method("setup_projectile"):
		bullet.setup_projectile(
			damage_type,
			effect_type,
			effect_chance,
			enemy_bullet_damage,
			enemy_bullet_velocity
		)


# ==========================================
# CORE HEALTH LOGIC
# ==========================================
func take_damage(amount: int) -> void:
	if is_dying: 
		return
	
	enemy_current_health -= amount
	flash_sprite(Color.RED)
	_trigger_hurt_particles()
	
	# DYNAMIC IMPACT AUDIO ROUTING
	if enemy_hurt_sound and enemy_current_health > 0:
		var hit_sfx = AudioStreamPlayer.new()
		hit_sfx.stream = enemy_hurt_sound
		hit_sfx.bus = "SFX"
		get_tree().current_scene.add_child(hit_sfx)
		hit_sfx.play()
		hit_sfx.finished.connect(func(): hit_sfx.queue_free())
		
		# 🟢 HITSTOP: Tiny micro-slowdown for non-lethal ticks (20% speed for 0.02 seconds)
		Global.hitstop(0.02, 0.2)
	
	if enemy_current_health <= 0:
		explode()


func heal(amount: int) -> void:
	if is_dying: 
		return
	enemy_current_health = min(enemy_current_health + amount, enemy_max_health)
	flash_sprite(Color.WHITE)


func flash_sprite(flash_color: Color) -> void:
	if not sprite: 
		return
		
	if flash_color == Color.RED:
		sprite.modulate = Color(5.0, 0.2, 0.2, 1.0) # Bright HDR Red
	else:
		sprite.modulate = flash_color
		
	# 🟢 OPTIMIZATION: Runs on real-time so color states reset cleanly during active hitstops
	await get_tree().create_timer(0.1, true, false, true).timeout
	
	if is_instance_valid(sprite): 
		sprite.modulate = Color.WHITE


## Programmatically spawns one-shot hurt particle instances
func _trigger_hurt_particles() -> void:
	if hurt_particles_scene:
		var inst = hurt_particles_scene.instantiate()
		get_parent().add_child(inst)
		inst.global_position = global_position
		
		if "one_shot" in inst:
			inst.one_shot = true
			inst.emitting = true
			inst.finished.connect(func(): inst.queue_free())


# ==========================================
# DEATH & CLEANUP
# ==========================================
func explode() -> void:
	is_dying = true
	
	# 💥 JUICE: Hard visual engine freeze frame right on the lethal blow
	Global.hitstop(0.06, 0.0)
	
	# Silence looping ambient engine noise instantly upon breakdown
	if is_instance_valid(active_loop_player):
		active_loop_player.stop()
	
	Global.add_score(score_value)
	
	var world_node = get_tree().current_scene as World
	if is_instance_valid(world_node) and world_node.has_method("update_score_displays"):
		world_node.update_score_displays()
	
	var collision = get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", true)
	
	# 🟢 OPTIMIZATION: Appended to scene tree root instead of parent to prevent audio dropouts
	if death_sound_stream:
		var temp_audio_player = AudioStreamPlayer.new()
		temp_audio_player.stream = death_sound_stream
		temp_audio_player.bus = "SFX"
		get_tree().current_scene.add_child(temp_audio_player)
		temp_audio_player.play()
		temp_audio_player.finished.connect(func(): temp_audio_player.queue_free())
	
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.position = position
	if "velocity" in explosion:
		explosion.velocity = Vector2.DOWN * (enemy_speed * explosion_momentum_mult)
	get_parent().add_child(explosion)
	
	queue_free()


# ==========================================
# COLLISION LOGIC CALL TARGET
# ==========================================
func _on_area_entered(area: Area2D) -> void:
	if is_dying: 
		return
	
	if area.is_in_group("player"):
		var player_impact_damage = int(Global.player_health)
		
		if area.has_method("take_damage"):
			area.take_damage(int(enemy_current_health))
			
		take_damage(player_impact_damage)
