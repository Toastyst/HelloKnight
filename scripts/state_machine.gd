class_name StateMachine
extends Node

signal state_changed(from: int, to: int)

var current_state: int
var body: Node  # Parent player/enemy
var animated_sprite: AnimatedSprite2D
var hurtbox: Area2D
var attack_hitbox: Area2D

func _ready():
	body = get_parent()
	animated_sprite = body.animated_sprite
	hurtbox = body.hurtbox
	attack_hitbox = body.attack_hitbox
	# Connect animation finished
	animated_sprite.animation_finished.connect(_on_animation_finished)

func change_state(new_state: int):
	if current_state == new_state: return
	var old = current_state
	current_state = new_state

	# Hurtbox/attackbox monitoring (subclasses define ACTION_STATES)
	if new_state in get_action_states():
		hurtbox.set_deferred("monitoring", false)
		if attack_hitbox and new_state in get_attack_states():
			attack_hitbox.set_deferred("monitoring", true)
			attack_hitbox.attack_type = get_attack_type(new_state)
	else:
		hurtbox.set_deferred("monitoring", true)
		if attack_hitbox:
			attack_hitbox.set_deferred("monitoring", false)

	# Play animation
	var anim_name = get_anim_name(new_state)
	animated_sprite.play(anim_name)

	state_changed.emit(old, new_state)

func get_state_name() -> String:
	return "UNKNOWN"  # Subclasses override

func _on_animation_finished():
	handle_animation_finished(current_state)

# Virtual methods for subclasses
func handle_animation_finished(state: int):
	pass

func process(delta: float) -> Variant:
	return null

# Virtual getters for subclasses
func get_action_states() -> Array:
	return []

func get_attack_states() -> Array:
	return []

func get_attack_type(state: int) -> String:
	return "light"

func get_anim_name(state: int) -> String:
	return "idle"
