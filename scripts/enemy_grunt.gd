extends "res://scripts/enemy_template.gd"
# Basic enemy grunt - patrols and attacks on sight

# Patrol properties
@export var patrol_distance: float = 50.0
@export var patrol_speed: float = 20.0
@export var jump_velocity: float = -150.0

var patrol_start_x: float
var patrol_target_x: float
var moving_right: bool = true
var idle_timer_active: bool = false

func _ready():
	super._ready()
	# Initialize patrol
	patrol_start_x = global_position.x
	patrol_target_x = patrol_start_x + patrol_distance

func _patrol_behavior(delta: float):
	# Simple back-and-forth patrol
	var target_x = patrol_target_x if moving_right else patrol_start_x
	var direction = sign(target_x - global_position.x)
	velocity.x = move_toward(velocity.x, direction * patrol_speed, 100 * delta)

	# Check if reached patrol point
	if abs(global_position.x - target_x) < 5 and not idle_timer_active:
		idle_timer_active = true
		change_state(State.IDLE)
		# Longer pause before continuing patrol
		var timer = get_tree().create_timer(2.0)  # 2 second idle
		timer.timeout.connect(func():
			idle_timer_active = false
			moving_right = not moving_right
			change_state(State.PATROL)
		)

func _attack_behavior(_delta: float):
	# Idle in place during attack - don't move towards player
	var distance = global_position.distance_to(player.global_position)

	# If player moved out of attack range during attack, return to chase
	if distance > attack_range:
		change_state(State.CHASE)
		return

	# Stop movement during attack
	velocity.x = move_toward(velocity.x, 0, 200)

	# Randomize attack type
	if attack_hitbox:
		attack_hitbox.attack_type = ["light", "heavy"].pick_random()

	# Attack hitbox is enabled/disabled in change_state() based on ACTION_STATES

func _chase_behavior(delta: float, distance: float):
	# Enhanced chase with line-of-sight checking
	var can_see = can_see_player()

	if distance <= attack_range and can_see and (not attack_cooldown_timer or attack_cooldown_timer.is_stopped()):
		change_state(State.ATTACK)
	elif distance <= detection_range and can_see:
		# Move towards player
		velocity.x = move_toward(velocity.x, facing_dir * move_speed, 200 * delta)
		# Jump if distance > 30 and on floor
		if distance > 30 and is_on_floor():
			velocity.y = jump_velocity
	else:
		# Return to patrol if player out of range or not visible
		change_state(State.PATROL)

func _idle_behavior(_delta: float):
	# Stop movement
	velocity.x = move_toward(velocity.x, 0, 200 * _delta)

	# Only transition to patrol if we have a timer active (meaning we reached a patrol point)
	# Initial startup should stay in IDLE to allow player detection
	if idle_timer_active:
		# Timer is active, stay idle until it completes
		pass
	else:
		# No timer active - this could be initial startup OR timer just completed
		# Let the base class handle player detection transitions
		pass
