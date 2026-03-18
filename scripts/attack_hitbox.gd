extends Area2D

# Attack metadata - simplified for direct damage
var attack_type: String = "light"  # "light" or "heavy"
var damage: int = 10  # Base damage
var attacker: Node = null  # Reference to the attacking entity
var has_hit: bool = false  # Prevent multiple hits per attack

func _ready():
	# Get reference to parent (usually the player or enemy)
	attacker = get_parent()
	# Set damage based on attack type
	damage = 10 if attack_type == "light" else 20

	# Connect the area_entered signal
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D):
	"""
	Called when attack hitbox overlaps with a hurtbox.
	Direct damage call for simplicity - no signals or complex resolution.
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

	# Direct damage call to the hurtbox owner
	var target = area.get_parent()
	if target.has_method("take_damage"):
		target.take_damage(damage, attacker)
		has_hit = true  # Mark as hit to prevent multiple damage

func reset_hit():
	"""
	Reset the hit flag for the next attack.
	"""
	has_hit = false
