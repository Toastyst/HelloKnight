extends CharacterBody2D
# Base template for combat enemies
# Provides health, states, and basic combat functionality

const EnemyStateMachine = preload("res://scripts/enemy_state_machine.gd")

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
@export var gravity: float = 980.0

# References
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var state_machine: EnemyStateMachine

var player: Node = null
var facing_dir: int = 1
var attack_cooldown_timer: Timer = null
var attack_cooldown: float = 1.5  # Seconds between attacks

func _ready():
	# Find player
	player = get_tree().get_first_node_in_group("player")

	set_collision_mask_value(3, true)

	# Instantiate state machine
	state_machine = EnemyStateMachine.new()
	add_child(state_machine)

func _physics_process(delta: float):
	if not player:
		return

	velocity.y += gravity * delta

	var distance_to_player = global_position.distance_to(player.global_position)
	var can_see = can_see_player()

	# Delegate to state_machine
	var suggested = state_machine.process_ai(delta, player.global_position, distance_to_player, can_see)
	if suggested != null:
		state_machine.change_state(suggested)

	# Behaviors
	match state_machine.current_state:
		EnemyStateMachine.State.IDLE:
			_idle_behavior(delta)
		EnemyStateMachine.State.PATROL:
			_patrol_behavior(delta)
		EnemyStateMachine.State.CHASE:
			_chase_behavior(delta, distance_to_player)
		EnemyStateMachine.State.ATTACK:
			_attack_behavior(delta)
		EnemyStateMachine.State.HURT:
			_hurt_behavior(delta)
		EnemyStateMachine.State.DIE:
			_die_behavior(delta)

	# Update facing direction
	if state_machine.current_state in [EnemyStateMachine.State.CHASE, EnemyStateMachine.State.ATTACK]:
		# Face player when aggressive
		facing_dir = sign(player.global_position.x - global_position.x)
		if animated_sprite:
			animated_sprite.flip_h = facing_dir < 0
		# Update attack hitbox position based on facing direction
		if attack_hitbox:
			var hitbox_shape = attack_hitbox.get_node("CollisionShape2D2")
			if hitbox_shape:
				hitbox_shape.position.x = abs(hitbox_shape.position.x) * facing_dir
	elif state_machine.current_state == EnemyStateMachine.State.PATROL:
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
	if distance <= detection_range and can_see:
		velocity.x = move_toward(velocity.x, facing_dir * move_speed , 200 * delta)
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

# State management removed, handled by state_machine

# Combat methods
func take_damage(amount: int, attacker: Node = null):
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()
	else:
		state_machine.change_state(EnemyStateMachine.State.HURT)
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
	state_machine.change_state(EnemyStateMachine.State.DIE)

# Attack cooldown finished handler
func _on_attack_cooldown_finished():
	pass

# Utility methods
func get_state_name() -> String:
	return state_machine.get_state_name()

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
