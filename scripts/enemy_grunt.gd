extends "res://scripts/enemy_template.gd"
# Basic enemy grunt - patrols and attacks on sight

const GruntStateMachine = preload("res://scripts/enemy_grunt_state_machine.gd")

# Patrol properties
@export var patrol_distance: float = 50.0
@export var patrol_speed: float = 20.0
@export var jump_velocity: float = -150.0

func _ready():
	super._ready()
	# Override state machine
	state_machine = GruntStateMachine.new()
	add_child(state_machine)

func _attack_behavior(_delta: float):
	# Idle in place during attack - don't move towards player
	var distance = global_position.distance_to(player.global_position)

	# If player moved out of attack range during attack, SM will handle return to chase
	if distance > attack_range:
		return

	# Stop movement during attack
	velocity.x = move_toward(velocity.x, 0, 200)

func _chase_behavior(delta: float, distance: float):
	# Enhanced chase with line-of-sight checking
	var can_see = can_see_player()

	if distance <= detection_range and can_see:
		# Move towards player
		velocity.x = move_toward(velocity.x, facing_dir * move_speed, 200 * delta)
		# Jump if distance > 30 and on floor
		if distance > 30 and is_on_floor():
			velocity.y = jump_velocity
