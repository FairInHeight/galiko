extends Node

# Reference to the master enemy script (our parent)
@onready var parent: Enemy = get_parent() as Enemy

# Internal tracking timers for weapon cooldowns
var fire_cooldown_timer: float = 0.0

# Cached player reference
var cached_player: Node2D = null

# ==========================================
# ANIMATION TRACKING ENGINE
# ==========================================
var anim_timer: float = 0.0
var current_frame_index: int = 0
var current_anim_name: String = ""
var is_playing_one_shot: bool = false

# Master local configuration cache built strictly out of parent data properties
var anim_config: Dictionary = {}


func _ready() -> void:
	if not parent:
		set_physics_process(false)
		return
	
	fire_cooldown_timer = Global.arcade_rng.randf_range(0.0, parent.enemy_fire_rate)
	
	# 🟢 FORCE BACKUP SYNC: If the parent already has metadata loaded, grab it immediately!
	sync_with_enemy_data()


func _physics_process(delta: float) -> void:
	if parent.is_dying:
		return
		
	_process_firing_logic(delta)
	_process_animation_ticking(delta)


## DATA SYNCHRONIZATION INTERFACE: Maps sequence indices securely without altering definitions
func sync_with_enemy_data() -> void:
	if not is_instance_valid(parent):
		return
		
	fire_cooldown_timer = parent.enemy_fire_rate
	
	# Cleaned up and streamlined fallback tree dictionary allocation
	anim_config = {
		"idle":   _build_anim_profile("idle", 0, 0, 8.0, true),
		"walk":   _build_anim_profile("walk", 0, 0, 12.0, true),
		"attack": _build_anim_profile("attack", 0, 0, 10.0, false),
		"hurt":   _build_anim_profile("hurt", 0, 0, 15.0, false)
	}
	
	play_animation("idle")


## Helper compilation routine optimizing structural meta polling lookup times
func _build_anim_profile(key: String, def_start: int, def_end: int, def_fps: float, def_loop: bool) -> Dictionary:
	var start_frame: int = parent.get_meta(key + "_start_frame") if parent.has_meta(key + "_start_frame") else (parent.get(key + "_start_frame") if key + "_start_frame" in parent else def_start)
	var end_frame: int = parent.get_meta(key + "_end_frame") if parent.has_meta(key + "_end_frame") else (parent.get(key + "_end_frame") if key + "_end_frame" in parent else def_end)
	var anim_fps: float = parent.get_meta(key + "_fps") if parent.has_meta(key + "_fps") else (parent.get(key + "_fps") if key + "_fps" in parent else def_fps)
	var anim_loop: bool = parent.get_meta(key + "_loop") if parent.has_meta(key + "_loop") else (parent.get(key + "_loop") if key + "_loop" in parent else def_loop)
	
	return { "start": start_frame, "end": end_frame, "fps": anim_fps, "loop": anim_loop }


## Entry hook to update current frame states cleanly
func play_animation(anim_name: String, forced_one_shot: bool = false) -> void:
	if not anim_config.has(anim_name) or not is_instance_valid(parent.sprite):
		return
		
	if is_playing_one_shot and not forced_one_shot:
		return
		
	if current_anim_name == anim_name and not forced_one_shot:
		return
		
	current_anim_name = anim_name
	is_playing_one_shot = forced_one_shot
	
	var config = anim_config[anim_name]
	current_frame_index = config["start"]
	anim_timer = 0.0
	parent.sprite.frame = current_frame_index


## Math frame counter driver evaluated every physics cycle
func _process_animation_ticking(delta: float) -> void:
	if not anim_config.has(current_anim_name) or not is_instance_valid(parent.sprite):
		return
		
	if parent.sprite.hframes == 1 and parent.sprite.vframes == 1:
		parent.sprite.frame = 0
		return
		
	var config = anim_config[current_anim_name]
	var fps = max(config["fps"], 1.0)
	var frame_duration = 1.0 / fps
	
	anim_timer += delta
	if anim_timer >= frame_duration:
		anim_timer = 0.0
		current_frame_index += 1
		
		if current_frame_index > config["end"]:
			if config["loop"]:
				current_frame_index = config["start"]
			else:
				current_frame_index = config["end"]
				if is_playing_one_shot:
					is_playing_one_shot = false
					_evaluate_movement_animation()
					
		parent.sprite.frame = current_frame_index


## Evaluates current flight behavior parameters to update background loops
func _evaluate_movement_animation() -> void:
	match parent.ai_mode:
		Enemy.AIMode.IDLE, Enemy.AIMode.SNIPE:
			play_animation("idle")
		_:
			play_animation("walk")


## This is called every frame by the parent enemy's _physics_process loop.
func get_movement_velocity(_delta: float) -> Vector2:
	var target_velocity := Vector2.ZERO
	var player = _get_player_reference()
	
	match parent.ai_mode:
		Enemy.AIMode.DEBUG:
			target_velocity = Vector2.DOWN * parent.enemy_speed
			_evaluate_movement_animation()
			
		Enemy.AIMode.IDLE:
			target_velocity = _calculate_seek_vector(parent.anchor_position, 10.0)
			_evaluate_movement_animation()
			
		Enemy.AIMode.SNIPE:
			var active_vel = parent.velocity if "velocity" in parent else target_velocity
			target_velocity = active_vel.lerp(Vector2.ZERO, 0.1)
			_evaluate_movement_animation()
			
		Enemy.AIMode.DIVE:
			target_velocity.y = parent.enemy_speed
			_evaluate_movement_animation()
			
			if player:
				var x_diff = player.global_position.x - parent.global_position.x
				var distance_scale = clamp(abs(x_diff) / 250.0, 0.1, 1.0)
				target_velocity.x = sign(x_diff) * (parent.enemy_speed * distance_scale)
			else:
				# 🟢 SEEDED FIX: Handed random boundary drift directly over to Master RNG
				target_velocity.x = Global.arcade_rng.randf_range(-20.0, 20.0)
				
		Enemy.AIMode.CHASE:
			_evaluate_movement_animation()
			if player:
				target_velocity = (player.global_position - parent.global_position).normalized() * parent.enemy_speed
			else:
				target_velocity = Vector2.DOWN * parent.enemy_speed
				
		Enemy.AIMode.RETREAT:
			_evaluate_movement_animation()
			target_velocity = _calculate_seek_vector(parent.anchor_position, 1.5 * parent.enemy_speed)
			if parent.global_position.distance_to(parent.anchor_position) < 5.0:
				parent.global_position = parent.anchor_position
				parent.ai_mode = Enemy.AIMode.IDLE
				
		Enemy.AIMode.REGROUP:
			_broadcast_regroup_order()
			parent.ai_mode = Enemy.AIMode.RETREAT
			
	return target_velocity


# ==========================================
# WEAPON LOGIC MANAGEMENT
# ==========================================
func _process_firing_logic(delta: float) -> void:
	if parent.fire_mode == Enemy.FireMode.HOLD_FIRE:
		return
		
	if fire_cooldown_timer > 0.0:
		fire_cooldown_timer -= delta
		return
		
	var can_shoot := false
	
	match parent.fire_mode:
		Enemy.FireMode.MAX_OUTPUT:
			can_shoot = true
			
		Enemy.FireMode.SEEDED_CHAOS:
			# 🟢 SEEDED: Checked securely using global run seed random tracking rolls
			if Global.arcade_rng.randf() <= 0.02:
				can_shoot = true
			else:
				fire_cooldown_timer = 0.0 
				return

	if can_shoot:
		_execute_attack_unified()
		play_animation("attack", true)
		fire_cooldown_timer = parent.enemy_fire_rate


## UNIFIED ATTACK EXECUTION ENGINE: Controls visual muzzle indicators and passes task to parent spawn loop
func _execute_attack_unified() -> void:
	var spawn_offset := Vector2.DOWN * 20.0
	var bullet_spawn_pos = parent.global_position + spawn_offset

	# 1. VISUAL FX: Spawn muzzle flash particles
	if parent.attack_particles_scene:
		var flash = parent.attack_particles_scene.instantiate()
		get_tree().current_scene.add_child(flash)
		flash.global_position = bullet_spawn_pos
		if "one_shot" in flash:
			flash.one_shot = true
			flash.emitting = true
			flash.finished.connect(func(): flash.queue_free())

	# 2. ENTITY DELEGATION: Hand project compilation completely over to the parent node setup API
	var projectile_scene = load("res://Actors/scenes/enemy_bullet.tscn") as PackedScene
	if not projectile_scene:
		return
		
	# Spawning, muzzle sfx players, and data transmission are entirely run by the parent script!
	parent.fire_projectile(projectile_scene, bullet_spawn_pos)


# ==========================================
# HELPER CALCULATIONS & SIGNALS
# ==========================================

func _get_player_reference() -> Node2D:
	if is_instance_valid(cached_player):
		return cached_player
		
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		cached_player = player_nodes[0] as Node2D
		return cached_player
	return null


func _calculate_seek_vector(target_pos: Vector2, speed_factor: float) -> Vector2:
	var distance_to_target = parent.global_position.distance_to(target_pos)
	if distance_to_target < 2.0:
		return Vector2.ZERO
	return (target_pos - parent.global_position).normalized() * min(distance_to_target * 10.0, speed_factor)


func _broadcast_regroup_order() -> void:
	print("📢 Commander Unit ordered a full REGROUP!")
	var all_enemies = get_tree().get_nodes_in_group("enemies") 
	for enemy in all_enemies:
		if enemy is Enemy and enemy != parent:
			if enemy.ai_mode != Enemy.AIMode.DEBUG:
				enemy.ai_mode = Enemy.AIMode.RETREAT
