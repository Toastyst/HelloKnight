extends CharacterBody2D

@export var speed: float = 60.0
@export var jump_velocity: float = -180.0
@export var roll_boost: float = 100.0
@export var acceleration: float = 1500.0
@export var friction: float = 1000.0

var anim_locked: bool = false
@export var damage: int = 10

var use_llsm: bool = true
@onready var llsm = get_node("/root/llsm")

# Health System
@export var max_health: int = 100
var current_health: int = max_health
signal health_changed(new_health: int, max_health: int)
signal died

# Stamina System (now handled by StaminaComponent)
var current_stamina: float = 100
var max_stamina: int = 100
signal stamina_changed(new_stamina: int, max_stamina: int)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox
var stamina_component: StaminaComponent
var current_state: String = "IDLE"

var facing_dir: int = 1
var attack_cooldown_timer: Timer = null

# Debug tracking for conditional prints
var prev_jump_pressed = false
var prev_roll_pressed = false
var prev_attack_pressed = false
var prev_input_dir = 0

func _ready():
	# Get stamina component
	stamina_component = $StaminaComponent as StaminaComponent
	if not stamina_component:
		push_error("StaminaComponent not found. Add a StaminaComponent node as a child of the Player node.")
		return

	# Connect stamina component signals
	stamina_component.stamina_changed.connect(_on_stamina_changed)
	stamina_component.exhaustion_entered.connect(_on_exhaustion_entered)
	stamina_component.exhaustion_exited.connect(_on_exhaustion_exited)

	# Load LLSM states
	llsm.load_states("res://data/states_config.json")

	# Connect animation finished
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)

func _start_attack_cooldown():
	if not attack_cooldown_timer:
		attack_cooldown_timer = Timer.new()
		attack_cooldown_timer.one_shot = true
		attack_cooldown_timer.timeout.connect(_on_attack_cooldown_finished)
		add_child(attack_cooldown_timer)
	attack_cooldown_timer.start(0.3)

func _physics_process(delta):
	if not stamina_component:
		return

	# print("--- PHYSICS DEBUG ---")
	# print("Current State: ", current_state)
	# print("Velocity Y: ", velocity.y)
	# print("Is On Floor: ", is_on_floor())

	# Apply Gravity
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	elif velocity.y > 0:
		velocity.y = 0 # Reset downward velocity when hitting floor

	var input_dir = Input.get_axis("move_left", "move_right")
	var attack_cooldown_stopped = not attack_cooldown_timer or attack_cooldown_timer.is_stopped()
	var is_exhausted = stamina_component.is_exhausted()
	var attack_ready = attack_cooldown_stopped
	var attack_pressed = Input.is_action_just_pressed("attack_light")
	var heavy_attack_pressed = Input.is_action_just_pressed("attack_heavy")
	var jump_pressed = Input.is_action_just_pressed("jump")
	var roll_pressed = Input.is_action_just_pressed("roll")

	# Conditional debug print for inputs
	if jump_pressed != prev_jump_pressed or roll_pressed != prev_roll_pressed or attack_pressed != prev_attack_pressed or input_dir != prev_input_dir:
		print("DEBUG INPUTS - input_dir:", input_dir, " | attack_pressed:", attack_pressed,
			  " | jump_pressed:", jump_pressed, " | roll_pressed:", roll_pressed)
		prev_jump_pressed = jump_pressed
		prev_roll_pressed = roll_pressed
		prev_attack_pressed = attack_pressed
		prev_input_dir = input_dir

	# Player-specific landing override (check before LLSM)
	if current_state == "JUMP" and is_on_floor() and velocity.y >= 0:
		execute_state("IDLE")
		anim_locked = false

	if not anim_locked and use_llsm:
		# LLSM Protocol
		var input = pack_context(input_dir, is_on_floor(), is_exhausted, attack_ready, attack_pressed, heavy_attack_pressed, jump_pressed, roll_pressed)
		var output = llsm.propose_state(input)
		var proposed = output.proposed_state
		# Player-specific overrides
		if proposed in ["BLOCK"] and not Input.is_action_pressed("block"):
			proposed = "IDLE"   # Player does not auto-block
		if can_transition_to(proposed):
			execute_state(proposed, output.bark)
		else:
			execute_state("IDLE")

	# Movement execution - allow limited air control
	if current_state not in ["ATTACK", "HEAVY_ATTACK", "ROLL", "BLOCK"]:
		var is_airborne = current_state in ["JUMP", "FALL"]
		var current_accel = acceleration
		if is_airborne:
			current_accel *= 0.6   # 60% air control
		var accel = current_accel
		var fric = friction
		if current_state == "BLOCK":
			accel *= 0.5
			fric *= 0.5
		var current_speed = speed
		if stamina_component.is_exhausted():
			current_speed *= 0.5
		if input_dir != 0:
			velocity.x = move_toward(velocity.x, input_dir * current_speed, accel * delta)
			facing_dir = sign(input_dir)
			animated_sprite.flip_h = facing_dir < 0
			# Update attack hitbox position based on facing direction
			if attack_hitbox:
				var hitbox_shape = attack_hitbox.get_node("CollisionShape2D2")
				if hitbox_shape:
					hitbox_shape.position.x = abs(hitbox_shape.position.x) * facing_dir
		else:
			velocity.x = move_toward(velocity.x, 0, fric * delta)

	# Set blocking for regen penalty
	stamina_component.set_blocking(current_state == "BLOCK")

	move_and_slide()

# -- GET STATE FUNCTION --
func get_state_name() -> String:
	return current_state

# -- LLSM FUNCTIONS --
func pack_context(input_dir: float, _on_floor: bool, exhausted: bool, attack_ready: bool, attack_pressed: bool, heavy_attack_pressed: bool, jump_pressed: bool, roll_pressed: bool) -> Dictionary:
	var interaction_type = "IDLE"

	if anim_locked:
		interaction_type = "LOCKED"  # Hold current state
	elif jump_pressed:
		interaction_type = "JUMP"
	elif roll_pressed:           # Roll can happen anytime (not just when attack_ready)
		interaction_type = "ROLL"
	elif heavy_attack_pressed and attack_ready:
		interaction_type = "HEAVY_ATTACK"
	elif attack_pressed and attack_ready:
		interaction_type = "ATTACK_RANGE"
	elif input_dir != 0:
		interaction_type = "CHASE"
	else:
		interaction_type = "IDLE"

	# print("pack_context interaction_type: ", interaction_type)

	var context_state = "HEALTHY"
	if exhausted or stamina_component.current_stamina < 10:
		context_state = "LOW_STAMINA"
	if anim_locked:
		context_state = "STUNNED"

	return {
		"character_type": "PLAYER",
		"interaction_type": interaction_type,
		"context_state": context_state
	}

func can_transition_to(target_state: String) -> bool:
	if not llsm.states.has(target_state):
		return false
	var state_data = llsm.states[target_state]
	if stamina_component.current_stamina < state_data.stamina_cost:
		return false
	# Range check simplified for player (always true)
	if not state_data.interruptible and anim_locked:
		return false
	return true

func execute_state(state: String, bark: String = ""):
	if current_state != state:
		current_state = state
		print("Player state change: ", state)
		# Apply velocity changes
		if state == "JUMP":
			velocity.y = jump_velocity
		elif state == "ROLL":
			velocity.x = facing_dir * roll_boost
		elif state == "ATTACK":
			velocity.x *= 0.6
		elif state == "HEAVY_ATTACK":
			velocity.x *= 0.4
		elif state == "IDLE":
			velocity.x = 0
		

	# Play animation if different
	var anim = llsm.states[state].animation
	if animated_sprite and animated_sprite.animation != anim:
		print("Playing animation: ", anim)
		animated_sprite.play(anim)

	# Consume stamina
	if state in ["ATTACK", "HEAVY_ATTACK", "ROLL"]:
		stamina_component.consume(llsm.states[state].stamina_cost)

	# Toggle hitbox
	if state == "ATTACK":
		if attack_hitbox:
			attack_hitbox.monitoring = true
			print("Attack hitbox monitoring: true for ", state)
	elif state == "HEAVY_ATTACK":
		if attack_hitbox:
			attack_hitbox.monitoring = true
			attack_hitbox.damage = int(damage * 1.5)
			print("Attack hitbox monitoring: true for ", state)
	else:
		if attack_hitbox:
			attack_hitbox.monitoring = false
			print("Attack hitbox monitoring: false")

	print("Attack hitbox monitoring: ", attack_hitbox.monitoring if attack_hitbox else "no hitbox")

	# Start attack cooldown for attack states
	if state in ["ATTACK", "HEAVY_ATTACK"]:
		_start_attack_cooldown()

	# Show bark (print for now)
	print("Player bark: ", bark)

	# Protect one-shot actions so they aren't immediately overridden
	if state in ["JUMP", "ROLL", "ATTACK", "HEAVY_ATTACK"]:
		anim_locked = true
	# Reset lock on forced landing
	if state == "IDLE" and current_state == "JUMP":
		anim_locked = false



# -- COMBAT METHODS --
func take_damage(amount: int, attacker: Node = null):
	"""
	Called when player takes damage.
	"""
	# Don't take damage if already dead
	if current_state == "DIE":
		print("Player: Ignoring damage - already dead")
		return

	# Blocking reduces damage and drains stamina
	if current_state == "BLOCK":
		amount = amount / 2  # Block reduces damage by half
		stamina_component.consume(15)  # Blocking drains 15 stamina

	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()
	else:
		execute_state("HURT")
		# Disable hurtbox during hurt animation (multi-hit prevention)
		hurtbox.disable_during_hurt()
		# Apply knockback away from attacker
		if attacker:
			var knockback_dir = sign(global_position.x - attacker.global_position.x)
			velocity.x = knockback_dir * 100
		else:
			# Fallback to facing direction if no attacker specified
			velocity.x = -facing_dir * 100

		# Start hurt recovery timer (since hurt animation is looping "idle")
		var hurt_timer = get_tree().create_timer(0.8)  # 0.8 seconds hurt duration
		hurt_timer.timeout.connect(_exit_hurt_state)

func stagger(knockback: bool = false):
	"""
	Called when player is staggered.
	"""
	execute_state("STAGGER")
	if knockback:
		velocity.x = -facing_dir * 150  # Stronger knockback

	# Start timer to exit stagger
	var timer = get_tree().create_timer(0.5)  # 0.5 seconds stagger
	timer.timeout.connect(_exit_stagger)

func _exit_stagger():
	"""
	Exit stagger state after timer.
	"""
	if current_state == "STAGGER":
		execute_state("IDLE")

func _exit_hurt_state():
	"""
	Exit hurt state after timer (since hurt animation is looping).
	"""
	if current_state == "HURT":
		execute_state("IDLE")
		# Re-enable hurtbox after hurt animation (multi-hit prevention)
		hurtbox.reenable_after_hurt()

func die():
	"""
	Called when player dies.
	"""
	died.emit()

	# Death slow motion effect
	Engine.time_scale = 0.3  # Slow down time
	var slow_timer = get_tree().create_timer(1.0)  # 1 second of slow motion
	slow_timer.timeout.connect(_end_slow_motion)

	execute_state("DIE")

func _end_slow_motion():
	"""
	End slow motion and freeze time completely.
	"""
	Engine.time_scale = 0.0  # Freeze time completely

func _on_attack_cooldown_finished():
	"""
	Called when attack cooldown timer expires.
	"""
	pass

func _on_animation_finished():
	print("Animation finished: ", animated_sprite.animation)
	anim_locked = false

# -- STAMINA SYSTEM --
func _on_stamina_changed(new_stamina: float, max_stamina_val: int):
	current_stamina = new_stamina
	max_stamina = max_stamina_val
	stamina_changed.emit(new_stamina, max_stamina_val)

func _on_exhaustion_entered():
	pass

func _on_exhaustion_exited():
	if current_state == "STAMINA":
		execute_state("IDLE")
