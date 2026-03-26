extends Area2D

signal attack_hit(attacker: Node, target: Node, attack_data: Dictionary)

# Attack metadata
var attack_type: String = "light"  # "light" or "heavy"
var damage: int = 10  # Base damage
var attacker: Node = null  # Reference to the attacking entity
var has_hit: bool = false  # Prevent multiple hits per attack

func _ready():
	# Get reference to parent (usually the player or enemy)
	attacker = get_parent()
	# Set damage based on attack type
	if attack_type == "light":
		damage = 10
	elif attack_type == "heavy":
		damage = 20
	else:  # enemy
		damage = 15

	# Connect the area_entered signal
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D):
	"""
	Called when attack hitbox overlaps with a hurtbox.
	Emits attack_hit signal for CombatManager resolution.
	"""
	if not area:
		return  # Invalid area

	# Prevent multiple hits per attack
	if has_hit:
		return

	# Only process hurtboxes
	if area.name != "Hurtbox":
		return

	# Check if hurtbox is monitoring (i-frames/multi-hit prevention)
	if not area.monitoring:
		return

	# Don't hit self
	if area.get_parent() == attacker:
		return

	# Emit signal with attack data
	var target = area.get_parent()
	var attack_data = {"type": attack_type, "damage": damage}
	attack_hit.emit(attacker, target, attack_data)
	has_hit = true  # Mark as hit to prevent multiple damage

func reset_hit():
	"""
	Reset the hit flag for the next attack.
	"""
	has_hit = false
