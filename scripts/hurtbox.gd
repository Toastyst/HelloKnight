extends Area2D
# Hurtbox script for handling incoming attacks
# Connects attack signals to CombatManager for resolution

@onready var owner_entity = get_parent()  # Usually the player or enemy
var combat_manager: Node = null  # Reference to CombatManager

func _ready():
	# Find CombatManager in the scene
	combat_manager = get_tree().get_first_node_in_group("combat_manager")
	if not combat_manager:
		# If no CombatManager, create one or find alternative
		pass

	set_deferred("monitoring", true)

func _on_area_entered(area: Area2D):
	"""
	Called when an attack hitbox enters the hurtbox.
	"""
	if area.has_signal("attack_hit"):
		# Connect to attack hit signal if not already connected
		if not area.is_connected("attack_hit", _on_attack_hit):
			area.attack_hit.connect(_on_attack_hit)

func _on_attack_hit(attacker: Node, target: Node, attack_data: Dictionary):
	"""
	Handles attack hit resolution through CombatManager.
	"""
	if target != owner_entity:
		return  # Not targeting this entity

	if combat_manager and combat_manager.has_method("resolve_combat"):
		combat_manager.resolve_combat(attacker, owner_entity, attack_data.get("type", "light"))
	else:
		# Fallback: direct damage application (should not happen)
		if owner_entity.has_method("take_damage"):
			owner_entity.take_damage(attack_data.get("damage", 10))

# Multi-hit prevention: disable during hurt animation
func disable_during_hurt():
	set_deferred("monitoring", false)

# Re-enable after hurt animation finishes
func reenable_after_hurt():
	set_deferred("monitoring", true)
