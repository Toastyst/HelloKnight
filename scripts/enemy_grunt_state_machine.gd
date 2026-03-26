class_name GruntStateMachine
extends "res://scripts/enemy_state_machine.gd"

# Patrol properties
var patrol_start_x: float
var patrol_target_x: float
var moving_right: bool = true
var idle_timer_active: bool = false

func _ready():
    super()
    # Initialize patrol
    patrol_start_x = body.global_position.x
    patrol_target_x = patrol_start_x + body.patrol_distance

func process_ai(delta: float, player_pos: Vector2, distance: float, can_see: bool) -> Variant:
    # First, check player detection
    if distance <= body.attack_range and can_see:
        return State.ATTACK
    elif distance <= body.detection_range and can_see:
        return State.CHASE

    # If not attacking, and in patrol, handle patrol logic
    if current_state == State.PATROL:
        # Patrol behavior
        var target_x = patrol_target_x if moving_right else patrol_start_x
        var direction = sign(target_x - body.global_position.x)
        body.velocity.x = move_toward(body.velocity.x, direction * body.patrol_speed, 100 * delta)

        # Check if reached patrol point
        if abs(body.global_position.x - target_x) < 5 and not idle_timer_active:
            idle_timer_active = true
            return State.IDLE
            # Longer pause before continuing patrol
            var timer = get_tree().create_timer(2.0)
            timer.timeout.connect(func():
                idle_timer_active = false
                moving_right = not moving_right
            )

    # Call super for other logic
    return super(delta, player_pos, distance, can_see)

func change_state(new_state: int):
    super(new_state)
    # For attack, randomize type
    if new_state == State.ATTACK:
        attack_hitbox.attack_type = ["light", "heavy"].pick_random()