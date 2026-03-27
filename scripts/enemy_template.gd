extends CharacterBody2D
# Base template for combat enemies
# Provides health, states, and basic combat functionality

const LLSM = preload("res://scripts/llsm.gd")
const StaminaComponent = preload("res://scripts/stamina_component.gd")
const EnemyBarkManager = preload("res://scripts/enemy_bark_manager.gd")

# Health System
@export var max_health: int = 50
var current_health: int = max_health
signal health_changed(new_health: int, max_health: int)
signal died

# Stamina System (handled by StaminaComponent)

# Combat properties
@export var damage: int = 10
@export var attack_range: float = 15.0
@export var detection_range: float = 100.0  # Increased for easier testing
@export var move_speed: float = 30.0
@export var gravity: float = 980.0
@export var poise_max: int = 1
var poise_health: int = 1

# LLSM Protocol
@export var character_type: String = "GRUNT"
@onready var llsm: LLSM = LLSM.new()
var current_state: String = "IDLE"
var anim_locked: bool = false

# References
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox
var bark_label: Label = null
@onready var bark_timer: Timer = Timer.new()
var stamina_component: StaminaComponent
@onready var bark_manager: EnemyBarkManager = get_node_or_null("BarkManager")
@onready var poise_regen_timer: Timer = Timer.new()

var player: Node = null
var facing_dir: int = 1
var attack_cooldown_timer: Timer = null
var attack_cooldown: float = 1.5  # Seconds between attacks
var rolled_barks: Dictionary = {} # state -> bool

func _ready():
	add_child(bark_timer)
	add_child(poise_regen_timer)

	# Find player
	player = get_tree().get_first_node_in_group("player")

	set_collision_mask_value(3, true)

	# Instantiate LLSM
	add_child(llsm)
	llsm.load_states("res://data/states_config.json")

	# Connect animation finished
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)

	# Setup bark timer
	bark_timer.wait_time = 2.0
	bark_timer.one_shot = true
	bark_timer.timeout.connect(_on_bark_timeout)

	# Get bark label if exists
	bark_label = get_node_or_null("BarkLabel")
	# Hide bark initially
	if bark_label:
		bark_label.visible = false

	# Setup poise regen
	poise_regen_timer.timeout.connect(_on_poise_regen)
	poise_regen_timer.start(2.0)

	# Get stamina component
	stamina_component = get_node_or_null("StaminaComponent") as StaminaComponent
	if not stamina_component:
		push_error("StaminaComponent not found. Add a StaminaComponent node as a child of the Enemy node.")
		return

func _physics_process(delta: float):
	if not stamina_component:
		return
	if not player:
		return

	velocity.y += gravity * delta

	# LLSM Protocol: Propose and validate
	var input = pack_context()
	var output = llsm.propose_state(input)
	var proposed = output.proposed_state
	if can_transition_to(proposed):
		execute_state(proposed, output.bark)
	else:
		execute_state("IDLE")

	# Behaviors based on current state
	match current_state:
		"IDLE":
			_idle_behavior(delta)
		"PATROL":
			_patrol_behavior(delta)
		"CHASE":
			_chase_behavior(delta, global_position.distance_to(player.global_position))
		"ATTACK":
			_attack_behavior(delta)
		"HEAVY_ATTACK":
			_attack_behavior(delta)  # Same as light for now
		"BLOCK":
			_idle_behavior(delta)  # Stop moving while blocking
		"STAGGER":
			_hurt_behavior(delta)  # Similar to hurt
		"HURT":
			_hurt_behavior(delta)
		"DIE":
			_die_behavior(delta)

	# Update facing direction
	if current_state in ["CHASE", "ATTACK", "HEAVY_ATTACK"]:
		facing_dir = sign(player.global_position.x - global_position.x)
		if animated_sprite:
			animated_sprite.flip_h = facing_dir < 0
		if attack_hitbox:
			var hitbox_shape = attack_hitbox.get_node("CollisionShape2D2")
			if hitbox_shape:
				hitbox_shape.position.x = abs(hitbox_shape.position.x) * facing_dir
	elif current_state == "PATROL":
		if velocity.x != 0:
			facing_dir = sign(velocity.x)
			if animated_sprite:
				animated_sprite.flip_h = facing_dir < 0

	# Apply movement
	move_and_slide()

	# Set blocking for regen penalty
	stamina_component.set_blocking(current_state == "BLOCK")

# Override these methods in specific enemy scripts
func _idle_behavior(_delta: float):
	# Base behavior: just stop moving, let subclasses decide transitions
	velocity.x = move_toward(velocity.x, 0, 200 * _delta)

func _patrol_behavior(delta: float):
	# Default: simple patrol logic - override in subclasses
	pass

func _chase_behavior(delta: float, distance: float):
	# Check if player is still visible (line of sight)
	var can_see = can_see_player()

	# Move towards player if in range and visible
	if distance <= detection_range and can_see:
		var current_speed = move_speed
		if stamina_component.is_exhausted():
			current_speed *= 0.5
		velocity.x = move_toward(velocity.x, facing_dir * current_speed , 200 * delta)
	else:
		# SM will handle transition to PATROL
		pass

func _attack_behavior(delta: float):
	# Basic attack - override for specific attack patterns
	pass

func _hurt_behavior(_delta: float):
	# Knockback and recovery
	velocity.x = move_toward(velocity.x, 0, 300)

func _die_behavior(_delta: float):
	# Death animation and cleanup
	velocity.x = 0
	if animated_sprite and not animated_sprite.is_playing():
		queue_free()

# LLSM Protocol Functions
func pack_context() -> Dictionary:
	var dist = global_position.distance_to(player.global_position)
	var interaction_type = "IDLE"
	if dist > detection_range:
		interaction_type = "FAR"
	elif not can_see_player():
		interaction_type = "PATROL"
	elif dist > attack_range:
		interaction_type = "CHASE"
	else:
		interaction_type = "ATTACK_RANGE"

	var health_percent = float(current_health) / max_health
	var context_state = "HEALTHY"
	if health_percent < 0.2:
		context_state = "CRITICAL"
	elif health_percent < 0.5:
		context_state = "WOUNDED"

	# Add defensive states
	if stamina_component.current_stamina < 10:
		context_state = "LOW_STAMINA"
	if anim_locked:
		context_state = "STUNNED"

	return {
		"character_type": character_type,
		"interaction_type": interaction_type,
		"context_state": context_state
	}

func can_transition_to(target_state: String) -> bool:
	if not llsm.states.has(target_state):
		return false
	var state_data = llsm.states[target_state]
	if stamina_component.current_stamina < state_data.stamina_cost:
		return false
	var dist = global_position.distance_to(player.global_position)
	if dist < state_data.range_min or dist > state_data.range_max:
		return false
	if not state_data.interruptible and anim_locked:
		return false
	return true

func execute_state(state: String, bark: String = ""):
	if not llsm.states.has(state):
		return
		
	if current_state != state:
		current_state = state
		var anim = llsm.states[state].animation
		if animated_sprite and animated_sprite.animation != anim:
			animated_sprite.play(anim)
			
		stamina_component.consume(llsm.states[state].stamina_cost)
		anim_locked = not llsm.states[state].interruptible
		if state == "ATTACK":
			if attack_hitbox:
				attack_hitbox.monitoring = true
		elif state == "HEAVY_ATTACK":
			if attack_hitbox:
				attack_hitbox.monitoring = true
				attack_hitbox.damage = int(damage * 1.5)
				emit_signal("camera_shake_requested", 2.0, 0.5)
		elif state == "KNOCKDOWN":
			stamina_component.current_stamina += 10
			hurtbox.disable_during_hurt()
			var timer = get_tree().create_timer(1.0)
			timer.timeout.connect(func(): hurtbox.reenable_after_hurt())
		else:
			if attack_hitbox:
				attack_hitbox.monitoring = false

	# Show bark
	if bark != "" and bark_label:
		bark_label.text = bark
		bark_label.visible = true
		bark_timer.start()

	# Trigger bark on state entry
	if bark_manager and state in ["IDLE", "CHASE", "STAGGER", "KNOCKDOWN"] and not has_rolled_bark(state):
		mark_rolled(state)
		var bark_data = bark_manager.get_bark(character_type)
		show_bark(bark_data.text, bark_data.tier)

func _on_animation_finished():
	anim_locked = false
	if attack_hitbox:
		attack_hitbox.monitoring = false

func _on_bark_timeout():
	if bark_label:
		bark_label.visible = false

func _on_poise_regen():
	poise_health = min(poise_max, poise_health + 1)

func has_rolled_bark(state: String) -> bool:
	return rolled_barks.get(state, false)

func mark_rolled(state: String):
	rolled_barks[state] = true

func show_bark(text: String, tier: String):
	if not bark_label:
		return
	bark_label.text = text
	bark_label.modulate = get_tier_color(tier)
	bark_label.visible = true
	bark_timer.start()

func get_tier_color(tier: String) -> Color:
	match tier:
		"COMMON": return Color.WHITE
		"UNCOMMON": return Color.GREEN
		"RARE": return Color.BLUE
		"LEGENDARY": return Color.ORANGE
	return Color.WHITE

# Combat methods
func take_damage(amount: int, attacker: Node = null):
	# Block reduces damage
	if current_state == "BLOCK":
		amount = int(amount * 0.5)
		stamina_component.consume(15)

	# Poise damage
	poise_health -= 1
	if poise_health <= 0:
		execute_state("STAGGER")
		return

	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()
	else:
		# Knockdown if exhausted
		if stamina_component.is_exhausted():
			execute_state("KNOCKDOWN")
		else:
			# Stagger if stamina depleted
			if stamina_component.current_stamina <= 0 and can_transition_to("STAGGER"):
				execute_state("STAGGER")
			else:
				if can_transition_to("HURT"):
					execute_state("HURT")
				else:
					execute_state("IDLE")
		# Disable hurtbox during hurt animation (multi-hit prevention)
		hurtbox.disable_during_hurt()
		# Knockback away from attacker
		if attacker:
			var knockback_dir = sign(global_position.x - attacker.global_position.x)
			velocity.x = knockback_dir * 100
		else:
			velocity.x = -facing_dir * 100

func die():
	died.emit()
	execute_state("DIE")

# Attack cooldown finished handler
func _on_attack_cooldown_finished():
	pass

# Utility methods
func get_state_name() -> String:
	return current_state

func is_player_in_range(range_distance: float) -> bool:
	if not player:
		return false
	return global_position.distance_to(player.global_position) <= range_distance

# Enhanced player detection with line-of-sight
func can_see_player() -> bool:
	if not player:
		return false

	var distance = global_position.distance_to(player.global_position)
	if distance > detection_range:
		return false

	# Check line of sight using raycast
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)  # Only check world layer
	var result = space_state.intersect_ray(query)

	# If ray hits something before reaching player, player is not visible
	if result and result.collider != player:
		return false

	return true
