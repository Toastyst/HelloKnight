extends CharacterBody2D

const PlayerStateMachine = preload("res://scripts/player_state_machine.gd")

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

# Stamina System
@export var max_stamina: int = 100
var current_stamina: int = max_stamina
@export var stamina_regen_rate: float = 20.0  # Stamina per second
@export var stamina_regen_delay: float = 2.0  # Seconds before regen starts
var stamina_regen_timer: Timer = null
var stamina_exhaustion_timer: Timer = null
signal stamina_changed(new_stamina: int, max_stamina: int)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var state_machine: PlayerStateMachine

var facing_dir: int = 1
var attack_cooldown_timer: Timer = null

func _ready():
	# Emit initial stamina value
	stamina_changed.emit(current_stamina, max_stamina)

	# Setup stamina regeneration timer
	stamina_regen_timer = Timer.new()
	stamina_regen_timer.timeout.connect(_on_stamina_regen_tick)
	add_child(stamina_regen_timer)

	# Setup stamina exhaustion timer (delays regen after use)
	stamina_exhaustion_timer = Timer.new()
	stamina_exhaustion_timer.one_shot = true
	stamina_exhaustion_timer.timeout.connect(_start_stamina_regen)
	add_child(stamina_exhaustion_timer)

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
	# Gravity
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	var input_dir = Input.get_axis("move_left", "move_right")
	var attack_cooldown_stopped = not attack_cooldown_timer or attack_cooldown_timer.is_stopped()

	# Delegate to state_machine
	var suggested = state_machine.process_input(input_dir, delta, is_on_floor(), velocity, current_stamina, attack_cooldown_stopped)
	if suggested != null:
		# Handle stamina consumption
		var can_do = true
		if suggested == PlayerStateMachine.State.ATTACK_LIGHT:
			can_do = consume_stamina(15)
		elif suggested == PlayerStateMachine.State.ATTACK_HEAVY:
			can_do = consume_stamina(25)
		elif suggested == PlayerStateMachine.State.ROLL:
			can_do = consume_stamina(20)
		if can_do:
			state_machine.change_state(suggested)
			# Apply velocity changes
			if suggested == PlayerStateMachine.State.JUMP:
				velocity.y = jump_velocity
			elif suggested == PlayerStateMachine.State.ROLL:
				velocity.x = facing_dir * roll_boost
			elif suggested == PlayerStateMachine.State.ATTACK_LIGHT:
				velocity.x *= 0.6
			elif suggested == PlayerStateMachine.State.ATTACK_HEAVY:
				velocity.x *= 0.4
		else:
			state_machine.change_state(PlayerStateMachine.State.STAMINA)

	# Movement execution
	if state_machine.current_state not in state_machine.get_action_states():
		var accel = acceleration
		var fric = friction
		if state_machine.current_state == PlayerStateMachine.State.BLOCK:
			accel *= 0.5
			fric *= 0.5
		if input_dir != 0:
			velocity.x = move_toward(velocity.x, input_dir * speed, accel * delta)
			facing_dir = sign(input_dir)
			animated_sprite.flip_h = facing_dir < 0
			# Update attack hitbox position based on facing direction
			if attack_hitbox:
				var hitbox_shape = attack_hitbox.get_node("CollisionShape2D2")
				if hitbox_shape:
					hitbox_shape.position.x = abs(hitbox_shape.position.x) * facing_dir
		else:
			velocity.x = move_toward(velocity.x, 0, fric * delta)

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
		consume_stamina(15)  # Blocking drains 15 stamina

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
func consume_stamina(amount: int) -> bool:
	"""
	Consume stamina. Returns true if successful, false if insufficient stamina.
	"""
	if current_stamina >= amount:
		current_stamina -= amount
		stamina_changed.emit(current_stamina, max_stamina)

		# Stop regeneration and start exhaustion delay
		stamina_regen_timer.stop()
		stamina_exhaustion_timer.start(stamina_regen_delay)
		return true
	else:
		# Insufficient stamina - enter STAMINA state
		state_machine.change_state(PlayerStateMachine.State.STAMINA)
		return false

func _start_stamina_regen():
	"""
	Start stamina regeneration after exhaustion delay.
	"""
	stamina_regen_timer.start(0.1)  # Tick every 0.1 seconds for smooth regen

func _on_stamina_regen_tick():
	"""
	Regenerate stamina over time.
	"""
	if current_stamina < max_stamina:
		current_stamina = min(max_stamina, current_stamina + (stamina_regen_rate * 0.1))
		stamina_changed.emit(current_stamina, max_stamina)

		# Exit STAMINA state if we have enough stamina
		if state_machine.current_state == PlayerStateMachine.State.STAMINA and current_stamina >= 20:  # Minimum threshold
			state_machine.change_state(PlayerStateMachine.State.IDLE)
	else:
		# Full stamina - stop regen timer
		stamina_regen_timer.stop()
