class_name EnemyStateMachine
extends "res://scripts/state_machine.gd"

enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DIE }

const VULNERABLE_STATES = [State.IDLE, State.PATROL, State.CHASE]
const ACTION_STATES = [State.ATTACK]

const ANIM_MAP = {
    State.IDLE: "idle",
    State.PATROL: "walk",
    State.CHASE: "run",
    State.ATTACK: "attack",
    State.HURT: "hurt",
    State.DIE: "die"
}

func _ready():
    super()
    current_state = State.IDLE

func process_ai(delta: float, player_pos: Vector2, distance: float, can_see: bool) -> Variant:
    if not body.player: return null

    # Transitions
    if current_state != State.ATTACK:
        if distance <= body.attack_range and can_see:
            return State.ATTACK
        elif distance <= body.detection_range and can_see:
            return State.CHASE
        elif current_state in [State.IDLE, State.PATROL]:
            if distance <= body.detection_range and can_see:
                return State.CHASE
            else:
                return State.PATROL

    if current_state == State.CHASE:
        if distance > body.detection_range or not can_see:
            return State.PATROL
        elif distance <= body.attack_range and can_see and (not body.attack_cooldown_timer or body.attack_cooldown_timer.is_stopped()):
            return State.ATTACK
    elif current_state == State.PATROL:
        if distance <= body.detection_range and can_see:
            return State.CHASE

    return null

func handle_animation_finished(state: int):
    match state:
        State.ATTACK:
            attack_hitbox.monitoring = false
            if attack_hitbox.has_method("reset_hit"):
                attack_hitbox.reset_hit()
            # Start cooldown
            if not body.attack_cooldown_timer:
                body.attack_cooldown_timer = Timer.new()
                body.attack_cooldown_timer.one_shot = true
                body.attack_cooldown_timer.timeout.connect(body._on_attack_cooldown_finished)
                body.add_child(body.attack_cooldown_timer)
            var random_variation = randf_range(-0.5, 0.5)
            var actual_cooldown = body.attack_cooldown + random_variation
            actual_cooldown = clamp(actual_cooldown, 0.8, 2.5)
            body.attack_cooldown_timer.start(actual_cooldown)
            # Return to appropriate state
            var distance = body.global_position.distance_to(body.player.global_position) if body.player else 1000
            if distance <= body.detection_range:
                change_state(State.CHASE)
            else:
                change_state(State.IDLE)

        State.HURT:
            change_state(State.IDLE)
            hurtbox.reenable_after_hurt()

# Override getters
func get_state_name() -> String:
    return State.keys()[current_state]

func get_action_states() -> Array:
    return ACTION_STATES

func get_attack_states() -> Array:
    return [State.ATTACK]

func get_attack_type(state: int) -> String:
    return "enemy"

func get_anim_name(state: int) -> String:
    return ANIM_MAP.get(state, "idle")