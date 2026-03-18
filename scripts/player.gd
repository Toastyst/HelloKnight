extends CharacterBody2D

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

enum State {
	# Movement states
	IDLE, RUN, JUMP, FALL, ROLL,
	# Combat states
	ATTACK_LIGHT, ATTACK_HEAVY, BLOCK, STAMINA, STAGGER, HURT, DIE
}
var current_state: State = State.IDLE

# State categories for cleaner logic
const MOVEMENT_STATES = [State.IDLE, State.RUN, State.JUMP, State.FALL]
const COMBAT_STATES = [State.ATTACK_LIGHT, State.ATTACK_HEAVY, State.BLOCK, State.STAGGER, State.HURT]
const VULNERABLE_STATES = [State.IDLE, State.RUN, State.JUMP, State.FALL, State.STAGGER]  # States where player can be hit
const ACTION_STATES = [State.ROLL, State.ATTACK_LIGHT, State.ATTACK_HEAVY]  # States that disable hurtbox

var facing_dir: int = 1
var attack_cooldown_timer: Timer = null

func _ready():
	animated_sprite.animation_finished.connect(_on_animation_finished)
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

func _physics_process(delta):
	# If dead, don't process any input or state changes
	if current_state == State.DIE:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	var input_dir = Input.get_axis("move_left", "move_right")

	# ── LANDING + AUTO-ROLL IF SHIFT IS HELD ──
	if is_on_floor() and current_state in [State.JUMP, State.FALL]:
		if Input.is_action_pressed("roll"):   # ← NEW: roll instantly on landing if holding Shift
			start_roll()
		else:
			change_state(State.RUN if abs(velocity.x) > 20 else State.IDLE)

	# ── COMBAT INPUTS (highest priority) ──
	if current_state in VULNERABLE_STATES or current_state == State.BLOCK:
		# Block (hold to block)
		if Input.is_action_pressed("block"):
			change_state(State.BLOCK)
		elif current_state == State.BLOCK:
			# Exit block when released
			change_state(State.IDLE)
		# Light Attack
		elif Input.is_action_just_pressed("attack_light") and (not attack_cooldown_timer or attack_cooldown_timer.is_stopped()):
			start_attack_light()
		# Heavy Attack
		elif Input.is_action_just_pressed("attack_heavy") and (not attack_cooldown_timer or attack_cooldown_timer.is_stopped()):
			start_attack_heavy()

	# ── MOVEMENT INPUTS ──
	if current_state not in ACTION_STATES and current_state != State.BLOCK:
		# Jump
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity
			change_state(State.JUMP)
		# Roll
		if Input.is_action_just_pressed("roll") and is_on_floor():
			start_roll()

	# ── MOVEMENT EXECUTION ──
	if current_state not in ACTION_STATES and current_state != State.BLOCK:
		if input_dir != 0:
			velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * delta)
			facing_dir = sign(input_dir)
			animated_sprite.flip_h = facing_dir < 0
			# Update attack hitbox position based on facing direction
			if attack_hitbox:
				var hitbox_shape = attack_hitbox.get_node("CollisionShape2D2")
				if hitbox_shape:
					hitbox_shape.position.x = abs(hitbox_shape.position.x) * facing_dir
		else:
			velocity.x = move_toward(velocity.x, 0, friction * delta)

	move_and_slide()

	# ── AUTOMATIC STATE TRANSITIONS ──
	# Ground idle/run switching (when not in action states)
	if is_on_floor() and current_state in MOVEMENT_STATES:
		change_state(State.RUN if abs(velocity.x) > 20 else State.IDLE)
	# Air state switching
	elif not is_on_floor() and current_state in MOVEMENT_STATES:
		change_state(State.FALL if velocity.y > 0 else State.JUMP)

# ── STATE CHANGE ──
func change_state(new_state: State):
	# Handle collision layers for special abilities
	if new_state == State.ROLL:
		# During roll, disable collision with enemy bodies for pass-through
		set_collision_mask_value(3, false)  # Disable enemy body collision
	elif current_state == State.ROLL and new_state != State.ROLL:
		# Re-enable enemy body collision when exiting roll
		set_collision_mask_value(3, true)  # Re-enable enemy body collision

	# Re-enable hurtbox when exiting action states
	if current_state in ACTION_STATES and new_state not in ACTION_STATES:
		hurtbox.set_deferred("monitoring", true)

	# Disable hurtbox during actions that shouldn't be interrupted
	if new_state in ACTION_STATES:
		hurtbox.set_deferred("monitoring", false)
		if new_state in [State.ATTACK_LIGHT, State.ATTACK_HEAVY]:
			attack_hitbox.set_deferred("monitoring", true)
			# Set attack type for hitbox (will be used in CombatManager)
			attack_hitbox.attack_type = "light" if new_state == State.ATTACK_LIGHT else "heavy"
	if current_state == new_state: return
	current_state = new_state
	match current_state:
		State.IDLE:         animated_sprite.play("idle")
		State.RUN:          animated_sprite.play("run")
		State.JUMP:         animated_sprite.play("jump")
		State.FALL:         animated_sprite.play("jump")
		State.ROLL:         animated_sprite.play("roll")
		State.ATTACK_LIGHT: animated_sprite.play("attack")  # Use same animation for now
		State.ATTACK_HEAVY: animated_sprite.play("attack")  # Use same animation for now
		State.BLOCK:        animated_sprite.play("idle")    # Placeholder animation
		State.STAMINA:      animated_sprite.play("idle")    # Placeholder animation
		State.STAGGER:      animated_sprite.play("idle")    # Placeholder animation
		State.HURT:         animated_sprite.play("idle")    # Placeholder animation
		State.DIE:          animated_sprite.play("die")

# ── ACTIONS ──
func start_roll():
	# Consume stamina for roll
	if consume_stamina(20):  # Roll costs 20 stamina
		change_state(State.ROLL)
		velocity.x = facing_dir * roll_boost

func start_attack_light():
	# Consume stamina for light attack
	if consume_stamina(15):  # Light attack costs 15 stamina
		change_state(State.ATTACK_LIGHT)
		velocity.x *= 0.6  # Slow down during attack

func start_attack_heavy():
	# Consume stamina for heavy attack
	if consume_stamina(25):  # Heavy attack costs 25 stamina
		change_state(State.ATTACK_HEAVY)
		velocity.x *= 0.4  # Slower for heavy attack
	
# ── ANIMATION FINISHED ──
func _on_animation_finished():
	# Handle different animation finishes
	match current_state:
		State.ROLL:
			# Roll animation finished - exit roll state
			attack_hitbox.monitoring = false  # Make sure attack hitbox is disabled
			if is_on_floor():
				change_state(State.RUN if abs(velocity.x) > 20 else State.IDLE)
			else:
				change_state(State.FALL if velocity.y > 0 else State.JUMP)

		State.ATTACK_LIGHT, State.ATTACK_HEAVY:
			# Attack animations finished
			hurtbox.monitoring = true  # Re-enable hurtbox for attacks
			attack_hitbox.monitoring = false  # Disable attack hitbox
			# Reset hit flag for next attack
			if attack_hitbox.has_method("reset_hit"):
				attack_hitbox.reset_hit()

			# Start attack cooldown timer
			if not attack_cooldown_timer:
				attack_cooldown_timer = Timer.new()
				attack_cooldown_timer.one_shot = true
				attack_cooldown_timer.timeout.connect(_on_attack_cooldown_finished)
				add_child(attack_cooldown_timer)
			attack_cooldown_timer.start(0.3)  # 0.3 second cooldown between attacks

			# Return to movement state
			if is_on_floor():
				change_state(State.RUN if abs(velocity.x) > 20 else State.IDLE)
			else:
				change_state(State.FALL if velocity.y > 0 else State.JUMP)

		State.HURT:
			# Hurt animation finished - return to idle
			change_state(State.IDLE)
			# Re-enable hurtbox after hurt animation (multi-hit prevention)
			hurtbox.reenable_after_hurt()

		State.DIE:
			# Die animation finished - reload scene
			get_tree().reload_current_scene()
			
# -- GET STATE FUNCTION --
func get_state_name() -> String:
	return State.keys()[current_state]

# -- COMBAT METHODS --
func take_damage(amount: int, attacker: Node = null):
	"""
	Called when player takes damage.
	"""
	# Don't take damage if already dead
	if current_state == State.DIE:
		print("Player: Ignoring damage - already dead")
		return

	# Blocking reduces damage and drains stamina
	if current_state == State.BLOCK:
		amount = amount / 2  # Block reduces damage by half
		consume_stamina(15)  # Blocking drains 15 stamina

	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()
	else:
		change_state(State.HURT)
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
	change_state(State.STAGGER)
	if knockback:
		velocity.x = -facing_dir * 150  # Stronger knockback

	# Start timer to exit stagger
	var timer = get_tree().create_timer(0.5)  # 0.5 seconds stagger
	timer.timeout.connect(_exit_stagger)

func _exit_stagger():
	"""
	Exit stagger state after timer.
	"""
	if current_state == State.STAGGER:
		change_state(State.IDLE)

func _exit_hurt_state():
	"""
	Exit hurt state after timer (since hurt animation is looping).
	"""
	if current_state == State.HURT:
		change_state(State.IDLE)
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

	change_state(State.DIE)

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
		# Insufficient stamina - enter STAMINA state if not already in it
		if current_state != State.STAMINA:
			change_state(State.STAMINA)
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
		if current_state == State.STAMINA and current_stamina >= 20:  # Minimum threshold
			change_state(State.IDLE)
	else:
		# Full stamina - stop regen timer
		stamina_regen_timer.stop()
