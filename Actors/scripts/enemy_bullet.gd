extends Area2D

# ==========================================
# ADVANCED TYPING & STATUS (Stamped by Enemy)
# ==========================================
var damage_type: TypeManager.Type = TypeManager.Type.DEFAULT
var effect_type: StatusManager.StatusEffect = StatusManager.StatusEffect.NONE
var effect_chance: float = 0.0

# ==========================================
# CORE COMBAT RUNTIME PARAMETERS
# ==========================================
var enemy_bullet_damage: float = 1.0
var enemy_bullet_speed: float = 300.0

# Stores the normalized unit flight vector
var direction: Vector2 = Vector2.DOWN

# ==========================================
# 🎵 AUDIO PIPELINE ENGINE
# ==========================================
var collision_sound_stream: AudioStream = preload("res://Sounds/sfx/bullet_collision.wav")

# ==========================================
# 🟢 COMPATIBILITY BRIDGE: ENGINE VECTOR METRICS
# ==========================================
## Restores legacy velocity mapping properties if referenced by external tools.
var velocity: Vector2:
	get:
		return direction * enemy_bullet_speed
	set(value):
		if value != Vector2.ZERO:
			direction = value.normalized()
			enemy_bullet_speed = value.length()
			_sync_visual_rotation()


# ==========================================
# LIFECYCLE INITIALIZATION
# ==========================================
func _ready() -> void:
	# 🟢 SAFETY GATE: Prevents crashing if the engine auto-wired this via the Editor UI Node Tab
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	
	# Fallback aim routing: If an external system spawned this without calling 
	# initialization hooks, establish trajectory parameters instantly at birth.
	if direction == Vector2.DOWN:
		_calculate_aim_trajectory()


# ==========================================
# 🚀 THE UNIFIED DATA PIPELINE HIGHWAY
# ==========================================
## Master setup API called by Enemy.fire_projectile() to stamp properties in a single frame.
func setup_projectile(p_damage_type: TypeManager.Type, p_effect_type: StatusManager.StatusEffect, p_effect_chance: float, p_damage: float, p_speed: float) -> void:
	damage_type = p_damage_type
	effect_type = p_effect_type
	effect_chance = p_effect_chance
	enemy_bullet_damage = p_damage
	enemy_bullet_speed = p_speed
	
	# Lock down final vector trajectories right here
	_calculate_aim_trajectory()


## Legacy Initializer Bridge: Keeps your older systems operational if they call init_bullet()
func init_bullet(firing_enemy: Enemy) -> void:
	if is_instance_valid(firing_enemy):
		enemy_bullet_speed = firing_enemy.enemy_bullet_velocity
		enemy_bullet_damage = firing_enemy.enemy_bullet_damage
		_calculate_aim_trajectory()


# ==========================================
# INTERNAL UTILITIES & PHYSICS ENGINE
# ==========================================
## Processes player target positioning once to lock in a static unit direction vector.
func _calculate_aim_trajectory() -> void:
	var player_nodes := get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		var player = player_nodes[0] as Node2D
		if is_instance_valid(player):
			direction = (player.global_position - global_position).normalized()
	else:
		direction = Vector2.DOWN
		
	_sync_visual_rotation()


## Orients the visual sprite frame exactly to match its calculated movement trajectory.
func _sync_visual_rotation() -> void:
	rotation = direction.angle() + deg_to_rad(90.0)


func _physics_process(delta: float) -> void:
	# Ultra-fast directional translation matrix
	global_position += direction * (enemy_bullet_speed * delta)
	
	# Strict Screen Boundaries Cleanup
	if global_position.y > 935.0 or global_position.y < -50.0 or global_position.x < -50.0 or global_position.x > 600.0:
		queue_free()


# ==========================================
# COLLISION & INTERACTION PIPELINE
# ==========================================
func _on_area_entered(area: Area2D) -> void:
	# 1. Projectile Phasing / Mutual Destruction
	if area.is_in_group("player_bullets") or area.is_in_group("enemy_bullets"):
		# AUDIO CLASH: Fire off the independent sound node before destruction
		_play_clash_sound_detached()
		
		area.queue_free()
		queue_free()
		return

	# 2. Player Impact Processing Hook
	if area.is_in_group("player"):
		# 🌟 BACKWARD COMPATIBLE SYSTEM HANDSHAKE:
		# If the player script has been upgraded to read structural components, pass everything.
		# If it's still using the old health system, pass the base float damage directly.
		if area.has_method("take_damage_complex"):
			area.take_damage_complex(enemy_bullet_damage, damage_type, effect_type, effect_chance)
		elif area.has_method("take_damage"):
			area.take_damage(int(enemy_bullet_damage))
			
		queue_free()


# ==========================================
# 🎨 AUDIO RENDERING PIPELINE
# ==========================================
## Instantiates an independent audio node in the main scene tree.
## This prevents the sound from cutting out when this specific bullet is queue_freed!
func _play_clash_sound_detached() -> void:
	if not collision_sound_stream:
		return
		
	var temp_player := AudioStreamPlayer.new()
	temp_player.stream = collision_sound_stream
	temp_player.bus = "SFX"
	
	# Add it to the world layer (the bullet's parent) so it stays alive
	get_parent().add_child(temp_player)
	temp_player.play()
	
	# Clean up the audio player node completely once the sound finishes playing
	temp_player.finished.connect(temp_player.queue_free)
