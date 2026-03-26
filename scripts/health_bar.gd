extends ProgressBar
# Simple health bar UI component

@export var tracked_entity: Node = null  # Entity to track health (player or enemy)

func _ready():
	if tracked_entity:
		_connect_to_entity(tracked_entity)
	else:
		# Try to find player if no entity specified
		var player = get_tree().get_first_node_in_group("player")
		if player:
			_connect_to_entity(player)

func _connect_to_entity(entity: Node):
	if entity.has_signal("health_changed"):
		entity.health_changed.connect(_on_health_changed)
		# Set initial values
		if "max_health" in entity and "current_health" in entity:
			max_value = entity.max_health
			value = entity.current_health
		else:
			max_value = 100
			value = 100
	else:
		pass

func _on_health_changed(new_health: int, max_health: int):
	max_value = max_health
	value = new_health

# Optional: Add visual effects for damage
func flash_damage():
	# Quick red flash effect
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
