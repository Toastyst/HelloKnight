extends CharacterBody2D
# Base template for combat enemies
# Provides health, states, and basic combat functionality

# Health System
@export var max_health: int = 50
var current_health: int = max_health
signal health_changed(new_health: int, max_health: int)
signal died

# Combat properties
@export var damage: int = 10
@export var attack_range: float = 15.0
@export var detection_range: float = 100.0  # Increased for easier testing
@export var move_speed: float = 30.0

# State machine
enum State {
	IDLE, PATROL, CHASE, ATTACK, HURT, DIE
}
var current_state: State = State.IDLE

# State categories
const VULNERABLE_STATES = [State.IDLE, State.PATROL, State.CHASE]
const ACTION_STATES = [State.ATTACK]

# References
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox

var player: Node = null
var facing_dir: int = 1
var startup_timer: Timer = null
var attack_cooldown_timer: Timer = null
var attack_cooldown: float = 1.5  # Seconds between attacks

func _ready():
	animated_sprite.animation_finished.connect(_on_animation_finished)
	# Find player
	player = get_tree().get_first_node_in_group("player")

	# Start a timer to transition to patrol if no player detected
	startup_timer = Timer.new()
	startup_timer.wait_time = 3.0  # 3 seconds to detect player
	startup_timer.one_shot = true
	startup_timer.timeout.connect(_on_startup_timeout)
	add_child(startup_timer)
	startup_timer.start()

func _physics_process(delta: float):
	if not player:
		return

	var distance_to_player = global_position.distance_to(player.global_position)
	var can_see = can_see_player()

	# Check for state transitions based on player detection
	# Only allow state changes when not in attack animation
	if current_state != State.ATTACK:
		if current_state in [State.IDLE, State.PATROL]:
			if distance_to_player <= detection_range and can_see:
				# Cancel startup timer if player detected
				if startup_timer and not startup_timer.is_stopped():
					startup_timer.stop()
				change_state(State.CHASE)
			elif distance_to_player <= attack_range and can_see:
				# Cancel startup timer if player detected
				if startup_timer and not startup_timer.is_stopped():
					startup_timer.stop()
				change_state(State.ATTACK)

	match current_state:
		State.IDLE:
			_idle_behavior(delta)
		State.PATROL:
			_patrol_behavior(delta)
		State.CHASE:
			_chase_behavior(delta, distance_to_player)
		State.ATTACK:
			_attack_behavior(delta)
		State.HURT:
			_hurt_behavior(delta)
		State.DIE:
			_die_behavior(delta)

	# Update facing direction
	if current_state in [State.CHASE, State.ATTACK]:
		# Face player when aggressive
		facing_dir = sign(player.global_position.x - global_position.x)
		if animated_sprite:
			animated_sprite.flip_h = facing_dir < 0
		# Update attack hitbox position based on facing direction
		if attack_hitbox:
			var hitbox_shape = attack_hitbox.get_node("CollisionShape2D2")
			if hitbox_shape:
				hitbox_shape.position.x = abs(hitbox_shape.position.x) * facing_dir
	elif current_state == State.PATROL:
		# Face movement direction when patrolling
		if velocity.x != 0:
			facing_dir = sign(velocity.x)
			if animated_sprite:
				animated_sprite.flip_h = facing_dir < 0

	# Apply movement
	move_and_slide()

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
	if distance <= attack_range and can_see and (not attack_cooldown_timer or attack_cooldown_timer.is_stopped()):
		change_state(State.ATTACK)
	elif distance <= detection_range and can_see:
		velocity.x = move_toward(velocity.x, facing_dir * move_speed , 200 * delta)
	else:
		change_state(State.PATROL)

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

# State management
func change_state(new_state: State):
	if current_state == new_state:
		return

	current_state = new_state

	# Handle hurtbox monitoring
	if new_state in ACTION_STATES:
		hurtbox.set_deferred("monitoring", false)
		if attack_hitbox:
			attack_hitbox.set_deferred("monitoring", true)
			attack_hitbox.attack_type = "enemy"  # For CombatManager
	else:
		hurtbox.set_deferred("monitoring", true)
		if attack_hitbox:
			attack_hitbox.set_deferred("monitoring", false)

	# Animation handling
	if animated_sprite:
		match current_state:
			State.IDLE:    animated_sprite.play("idle")
			State.PATROL:  animated_sprite.play("walk")
			State.CHASE:   animated_sprite.play("run")
			State.ATTACK:  animated_sprite.play("attack")
			State.HURT:    animated_sprite.play("hurt")
			State.DIE:     animated_sprite.play("die")

# Combat methods
func take_damage(amount: int, attacker: Node = null):
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()
	else:
		change_state(State.HURT)
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
	change_state(State.DIE)

# Animation finished handler
func _on_animation_finished():
	match current_state:
		State.ATTACK:
			# Immediately disable attack hitbox when attack animation finishes
			if attack_hitbox:
				attack_hitbox.set_deferred("monitoring", false)
				# Reset hit flag for next attack
				if attack_hitbox.has_method("reset_hit"):
					attack_hitbox.reset_hit()

			# Start attack cooldown timer with randomization
			if not attack_cooldown_timer:
				attack_cooldown_timer = Timer.new()
				attack_cooldown_timer.one_shot = true
				attack_cooldown_timer.timeout.connect(_on_attack_cooldown_finished)
				add_child(attack_cooldown_timer)

			# Add random timing variation (±0.5 seconds) to make enemy less predictable
			var random_variation = randf_range(-0.5, 0.5)
			var actual_cooldown = attack_cooldown + random_variation
			actual_cooldown = clamp(actual_cooldown, 0.8, 2.5)  # Keep between 0.8-2.5 seconds
			attack_cooldown_timer.start(actual_cooldown)

			# Return to appropriate state after attack
			var distance = global_position.distance_to(player.global_position) if player else 1000
			if distance <= detection_range:
				change_state(State.CHASE)
			else:
				change_state(State.IDLE)
		State.HURT:
			# Return to idle after hurt animation
			change_state(State.IDLE)
			# Re-enable hurtbox after hurt animation (multi-hit prevention)
			hurtbox.reenable_after_hurt()

# Startup timer handler - transition to patrol if no player detected
func _on_startup_timeout():
	if current_state == State.IDLE:
		change_state(State.PATROL)

# Attack cooldown finished handler
func _on_attack_cooldown_finished():
	pass

# Utility methods
func get_state_name() -> String:
	return State.keys()[current_state]

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
