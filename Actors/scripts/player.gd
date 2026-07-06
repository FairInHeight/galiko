extends Area2D

# --- SIGNALS ---
signal health_changed(new_health: int)
signal reload_progress_changed(progress: float)

# --- PRELOADS & SCENES ---
const BULLET_SCENE = preload("res://Actors/scenes/bullet.tscn")
const EXPLOSION_SCENE = preload("res://explosion.tscn") 

# ==========================================
# 🎵 AUDIO PIPELINE ENGINE PRELOADS
# ==========================================
var player_hurt_sound_stream: AudioStream = preload("res://Sounds/sfx/player_hurt.wav")
var hurt_sound_player: AudioStreamPlayer = null

# --- NODE REFERENCES ---
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var bullet_sound: AudioStreamPlayer = $FireSound
@onready var death_sound: AudioStreamPlayer = $DeathSound

# --- MOVEMENT SETTINGS ---
@export var mouse_tracking_weight: float = 0.05

# ==========================================
# 🌟 MULTI-TYPE FUTURE PROOFED DEFENSE PROFILE
# ==========================================
@export var defensive_typing: Array[TypeManager.Type] = [TypeManager.Type.DEFAULT]

# --- STATE & RUNTIME VARIABLES ---
var can_shoot: bool = true
var current_health: int = 3

# 🟢 OPTIMIZATION: Frame-perfect internal weapon fire tracking accumulator
var weapon_cooldown_accumulator: float = 0.0


func _ready() -> void:
	add_to_group("player")
	scale = Vector2(2.0, 2.0)
	position = Vector2(270, 850)
	
	current_health = Global.player_health
	print("🚀 Player spawned. Local Health assigned: ", current_health, " (Mode: ", Global.current_game_mode, ")")
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
	
	var new_texture = load(Global.selected_ship_texture)
	if new_texture and sprite_2d:
		sprite_2d.texture = new_texture
		
	get_window().warp_mouse(global_position)
	
	if player_hurt_sound_stream:
		hurt_sound_player = AudioStreamPlayer.new()
		hurt_sound_player.stream = player_hurt_sound_stream
		hurt_sound_player.bus = "SFX"
		add_child(hurt_sound_player)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		if get_tree().paused:
			return
		get_window().warp_mouse(global_position)
		print("🎯 Mouse entered window during gameplay! Synced cursor to player position.")


func _process(delta: float) -> void:
	if Global.is_in_cutscene: 
		return

	# 🟢 UNIFIED FIRE ENGINE: Process internal cooldown ticks sequentially on active game frames
	_process_weapon_cooldown(delta)

	var controller_input := get_input_direction()

	if controller_input.length() > 0:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CONFINED_HIDDEN:
			Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
		position += controller_input * Global.speed * delta
	else:
		var viewport := get_viewport()
		var window_mouse_pos := viewport.get_mouse_position()
		var window_size := viewport.get_visible_rect().size
		
		var is_mouse_inside_window := (
			window_mouse_pos.x >= 0 and window_mouse_pos.x <= window_size.x and
			window_mouse_pos.y >= 0 and window_mouse_pos.y <= window_size.y
		)
		
		if is_mouse_inside_window and Input.get_last_mouse_velocity().length() > 0:
			if Input.get_mouse_mode() != Input.MOUSE_MODE_CONFINED_HIDDEN:
				Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
			
			var target_pos := get_global_mouse_position()
			var max_distance_this_frame := Global.speed * delta
			position = position.move_toward(target_pos, max_distance_this_frame)
	
	position.x = clamp(position.x, 22, 520)
	position.y = clamp(position.y, 50, 864)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire") and can_shoot and not Global.is_in_cutscene:
		shoot_bullet()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


## Evaluates weapon downtime natively inside our primary execution frame loops
func _process_weapon_cooldown(delta: float) -> void:
	if can_shoot:
		return
		
	weapon_cooldown_accumulator += delta
	
	# Calculate precision layout ratio factor (0.0 -> 1.0)
	var ratio = clamp(weapon_cooldown_accumulator / max(Global.fire_rate, 0.001), 0.0, 1.0)
	reload_progress_changed.emit(ratio)
	
	if weapon_cooldown_accumulator >= Global.fire_rate:
		can_shoot = true
		weapon_cooldown_accumulator = 0.0


func shoot_bullet() -> void:
	can_shoot = false
	weapon_cooldown_accumulator = 0.0 # Clear tracking register completely
	bullet_sound.play()
	
	var bullet = BULLET_SCENE.instantiate()
	bullet.position = position
	
	if "damage" in bullet:
		bullet.damage = Global.damage
	if "speed" in bullet:
		bullet.speed = Global.bullet_speed
	if "damage_type" in bullet:
		bullet.damage_type = TypeManager.Type.DEFAULT
		
	get_parent().add_child(bullet)
	
	# Instantly let listeners know weapon capacity dropped to zero
	reload_progress_changed.emit(0.0)


# ==========================================
# 🚀 COMPLEX INTERACTION DAMAGE GATEWAY
# ==========================================
func take_damage_complex(base_damage: float, attack_type: TypeManager.Type, effect_type: StatusManager.StatusEffect, effect_chance: float) -> void:
	var multiplier = TypeManager.get_damage_multiplier(attack_type, defensive_typing)
	var final_damage = clamped_integer_calculation(base_damage, multiplier)
	
	print("🛡️ Element Match: ", TypeManager.Type.keys()[attack_type], " vs Player Array -> Mult: ", multiplier, "x | Final: ", final_damage)
	_apply_health_reduction(final_damage)


func take_damage(amount: int) -> void:
	_apply_health_reduction(amount)


func _apply_health_reduction(final_amount: int) -> void:
	current_health -= final_amount
	print("💥 Player health modified! Local Runtime Health: ", current_health)
	
	_flash_sprite(Color(1.0, 0.2, 0.2, 1.0))
	
	health_changed.emit(current_health)
	
	if current_health <= 0:
		player_die()
	else:
		if is_instance_valid(hurt_sound_player):
			hurt_sound_player.play()


func clamped_integer_calculation(base: float, mult: float) -> int:
	var result = base * mult
	if result > 0.0 and result < 1.0:
		return 1 
	return int(round(result))


# ==========================================
# 🎨 VISUAL RENDERING ENHANCEMENTS
# ==========================================
func _flash_sprite(flash_color: Color) -> void:
	if not is_instance_valid(sprite_2d):
		return
		
	sprite_2d.self_modulate = flash_color
	
	# 🟢 HITSTOP COMPATIBLE: Evaluates on unscaled absolute real-time
	await get_tree().create_timer(0.08, true, false, true).timeout
	
	if is_instance_valid(sprite_2d):
		sprite_2d.self_modulate = Color.WHITE


# ==========================================
# DEATH & CLEANUP
# ==========================================
func player_die() -> void:
	if not can_shoot and not visible: 
		return
	can_shoot = false
	print("💀 Player Destroyed! Entering death presentation mode...")
	
	if death_sound:
		bullet_sound.stop()
		death_sound.play()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	hide()
	set_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.position = position
	explosion.scale = Vector2(2.0, 2.0)
	
	var final_velocity := get_input_direction()
	if final_velocity.length() > 0:
		explosion.velocity = final_velocity * Global.speed
		
	get_parent().add_child(explosion)
	
	var world_node = get_tree().current_scene as World
	if is_instance_valid(world_node) and world_node.has_method("handle_player_death"):
		world_node.handle_player_death()


func get_input_direction() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_right"): dir.x += 1
	if Input.is_action_pressed("move_left"):  dir.x -= 1
	if Input.is_action_pressed("move_down"):  dir.y += 1
	if Input.is_action_pressed("move_up"):    dir.y -= 1
	return dir.normalized()
