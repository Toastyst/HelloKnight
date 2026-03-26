class_name PlayerStateMachine
extends "res://scripts/state_machine.gd"

enum State { IDLE, RUN, JUMP, FALL, ROLL, ATTACK_LIGHT, ATTACK_HEAVY, BLOCK, STAMINA, STAGGER, HURT, DIE }

const MOVEMENT_STATES = [State.IDLE, State.RUN, State.JUMP, State.FALL]
const COMBAT_STATES = [State.ATTACK_LIGHT, State.ATTACK_HEAVY, State.BLOCK, State.STAGGER, State.HURT]
const VULNERABLE_STATES = [State.IDLE, State.RUN, State.JUMP, State.FALL, State.STAGGER]
const ACTION_STATES = [State.ROLL, State.ATTACK_LIGHT, State.ATTACK_HEAVY]

const ANIM_MAP = {
    State.IDLE: "idle",
    State.RUN: "run",
    State.JUMP: "jump",
    State.FALL: "jump",
    State.ROLL: "roll",
    State.ATTACK_LIGHT: "attack",
    State.ATTACK_HEAVY: "attack",
    State.BLOCK: "idle",
    State.STAMINA: "idle",
    State.STAGGER: "idle",
    State.HURT: "hurt",
    State.DIE: "die"
}

func _ready():
    super()
    current_state = State.IDLE

func process_input(input_dir: Vector2, delta: float, is_on_floor: bool, velocity: Vector2, current_stamina: int) -> Variant:
    # If dead, no process
    if current_state == State.DIE: return null

    # Landing auto-roll
    if is_on_floor and current_state in [State.JUMP, State.FALL]:
        if Input.is_action_pressed("roll"):
            return State.ROLL
        else:
            return State.RUN if abs(velocity.x) > 20 else State.IDLE

    # Combat inputs (highest priority)
    if current_state in VULNERABLE_STATES or current_state == State.BLOCK:
        if Input.is_action_pressed("block"):
            return State.BLOCK
        elif current_state == State.BLOCK and not Input.is_action_pressed("block"):
            return State.IDLE
        elif Input.is_action_just_pressed("attack_light") and current_stamina >= 15:
            return State.ATTACK_LIGHT
        elif Input.is_action_just_pressed("attack_heavy") and current_stamina >= 25:
            return State.ATTACK_HEAVY

    # Movement inputs
    if current_state not in ACTION_STATES and current_state != State.BLOCK:
        if Input.is_action_just_pressed("jump") and is_on_floor:
            return State.JUMP
        if Input.is_action_just_pressed("roll") and is_on_floor and current_stamina >= 20:
            return State.ROLL

    # Auto transitions
    if is_on_floor and current_state in MOVEMENT_STATES:
        return State.RUN if abs(velocity.x) > 20 else State.IDLE
    elif not is_on_floor and current_state in MOVEMENT_STATES:
        return State.FALL if velocity.y > 0 else State.JUMP

    return null

func handle_animation_finished(state: int):
    match state:
        State.ROLL:
            attack_hitbox.monitoring = false
            # Return to movement
            var is_on_floor = body.is_on_floor()
            var velocity = body.velocity
            if is_on_floor:
                change_state(State.RUN if abs(velocity.x) > 20 else State.IDLE)
            else:
                change_state(State.FALL if velocity.y > 0 else State.JUMP)

        State.ATTACK_LIGHT, State.ATTACK_HEAVY:
            hurtbox.monitoring = true
            attack_hitbox.monitoring = false
            if attack_hitbox.has_method("reset_hit"):
                attack_hitbox.reset_hit()
            # Return to movement
            var is_on_floor = body.is_on_floor()
            var velocity = body.velocity
            if is_on_floor:
                change_state(State.RUN if abs(velocity.x) > 20 else State.IDLE)
            else:
                change_state(State.FALL if velocity.y > 0 else State.JUMP)

        State.HURT:
            change_state(State.IDLE)
            hurtbox.reenable_after_hurt()

        State.DIE:
            get_tree().reload_current_scene()

func change_state(new_state: int):
    super(new_state)
    # Handle collision for roll
    if new_state == State.ROLL:
        body.set_collision_mask_value(3, false)
    elif current_state == State.ROLL:
        body.set_collision_mask_value(3, true)

# Override getters
func get_state_name() -> String:
    return State.keys()[current_state]

func get_action_states() -> Array:
    return ACTION_STATES

func get_attack_states() -> Array:
    return [State.ATTACK_LIGHT, State.ATTACK_HEAVY]

func get_attack_type(state: int) -> String:
    return "light" if state == State.ATTACK_LIGHT else "heavy"

func get_anim_name(state: int) -> String:
    return ANIM_MAP.get(state, "idle")