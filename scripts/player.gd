extends CharacterBody2D

const PlayerStateMachine = preload("res://scripts/player_state_machine.gd")
const StaminaComponent = preload("res://scripts/stamina_component.gd")

@export var speed: float = 60.0
@export var jump_velocity: float = -180.0
@export var roll_boost: float = 100.0
@export var acceleration: float = 1500.0
@export var friction: float = 1000.0

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
@onready var state_machine: PlayerStateMachine
var stamina_component: StaminaComponent

var facing_dir: int = 1
var attack_cooldown_timer: Timer = null

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

	# Instantiate state machine
	state_machine = PlayerStateMachine.new()
	add_child(state_machine)
	state_machine.attack_finished.connect(_start_attack_cooldown)

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

	# DEBUG OVERLAY (Prints to console every frame)
	print("--- PHYSICS DEBUG ---")
	print("Current State: ", state_machine.get_state_name())
	print("Velocity Y: ", velocity.y)
	print("Is On Floor: ", is_on_floor())
	
	# Apply Gravity
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	elif velocity.y > 0:
		velocity.y = 0 # Reset downward velocity when hitting floor

	var input_dir = Input.get_axis("move_left", "move_right")
	var attack_cooldown_stopped = not attack_cooldown_timer or attack_cooldown_timer.is_stopped()
	var is_exhausted = stamina_component.is_exhausted()
	var attack_ready = attack_cooldown_stopped

	# Delegate to state_machine
	var suggested = state_machine.process_input(input_dir, delta, is_on_floor(), velocity, is_exhausted, attack_ready)
	if suggested != null:
		# Handle stamina consumption
		var can_do = true
		if suggested == PlayerStateMachine.State.ATTACK_LIGHT:
			can_do = stamina_component.consume(15)
		elif suggested == PlayerStateMachine.State.ATTACK_HEAVY:
			can_do = stamina_component.consume(25)
		elif suggested == PlayerStateMachine.State.ROLL:
			can_do = stamina_component.consume(20)
		if can_do:
			# Apply velocity changes (only on state transition)
			if suggested == PlayerStateMachine.State.JUMP and state_machine.current_state != PlayerStateMachine.State.JUMP:
				velocity.y = jump_velocity
			elif suggested == PlayerStateMachine.State.ROLL:
				velocity.x = facing_dir * roll_boost
			elif suggested == PlayerStateMachine.State.ATTACK_LIGHT:
				velocity.x *= 0.6
			elif suggested == PlayerStateMachine.State.ATTACK_HEAVY:
				velocity.x *= 0.4
			state_machine.change_state(suggested)
		else:
			state_machine.change_state(PlayerStateMachine.State.STAMINA)

	# Movement execution
	if state_machine.current_state not in state_machine.get_action_states():
		var accel = acceleration
		var fric = friction
		if state_machine.current_state == PlayerStateMachine.State.BLOCK:
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
	stamina_component.set_blocking(state_machine.current_state == PlayerStateMachine.State.BLOCK)

	move_and_slide()

# -- GET STATE FUNCTION --
func get_state_name() -> String:
	return state_machine.get_state_name()

# -- COMBAT METHODS --
func take_damage(amount: int, attacker: Node = null):
	"""
	Called when player takes damage.
	"""
	# Don't take damage if already dead
	if state_machine.current_state == PlayerStateMachine.State.DIE:
		print("Player: Ignoring damage - already dead")
		return

	# Blocking reduces damage and drains stamina
	if state_machine.current_state == PlayerStateMachine.State.BLOCK:
		amount = amount / 2  # Block reduces damage by half
		stamina_component.consume(15)  # Blocking drains 15 stamina

	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()
	else:
		state_machine.change_state(PlayerStateMachine.State.HURT)
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
	state_machine.change_state(PlayerStateMachine.State.STAGGER)
	if knockback:
		velocity.x = -facing_dir * 150  # Stronger knockback

	# Start timer to exit stagger
	var timer = get_tree().create_timer(0.5)  # 0.5 seconds stagger
	timer.timeout.connect(_exit_stagger)

func _exit_stagger():
	"""
	Exit stagger state after timer.
	"""
	if state_machine.current_state == PlayerStateMachine.State.STAGGER:
		state_machine.change_state(PlayerStateMachine.State.IDLE)

func _exit_hurt_state():
	"""
	Exit hurt state after timer (since hurt animation is looping).
	"""
	if state_machine.current_state == PlayerStateMachine.State.HURT:
		state_machine.change_state(PlayerStateMachine.State.IDLE)
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

	state_machine.change_state(PlayerStateMachine.State.DIE)

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

# -- STAMINA SYSTEM --
func _on_stamina_changed(new_stamina: float, max_stamina_val: int):
	current_stamina = new_stamina
	max_stamina = max_stamina_val
	stamina_changed.emit(new_stamina, max_stamina_val)

func _on_exhaustion_entered():
	pass

func _on_exhaustion_exited():
	if state_machine.current_state == PlayerStateMachine.State.STAMINA:
		state_machine.change_state(PlayerStateMachine.State.IDLE)
