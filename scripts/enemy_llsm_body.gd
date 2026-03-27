extends "res://scripts/enemy_template.gd"
# Reference implementation of full LLSM protocol integration
# Extends enemy_template.gd with example behaviors

func _ready():
	super._ready()
	# Additional setup if needed

# Example override for specific enemy type
func _patrol_behavior(delta: float):
	# Implement patrol logic here
	# For now, just stop
	velocity.x = move_toward(velocity.x, 0, 200 * delta)

# This script demonstrates the complete LLSM integration:
# - pack_context() categorizes situation
# - can_transition_to() validates proposals
# - execute_state() handles animations/hitboxes
# - _physics_process() runs the protocol loop