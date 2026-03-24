extends ProgressBar

@export var tracked_entity: Node = null  # Entity to track stamina (player)

func _ready():
	if tracked_entity:
		_connect_to_entity(tracked_entity)
	else:
		# Try to find player if no entity specified
		var player = get_tree().get_first_node_in_group("player")
		if player:
			_connect_to_entity(player)

func _connect_to_entity(entity: Node):
	print("StaminaBar: Connecting to entity ", entity.name)
	if entity.has_signal("stamina_changed"):
		entity.stamina_changed.connect(_on_stamina_changed)
		print("StaminaBar: Connected to stamina_changed signal")
		# Set initial values
		if "max_stamina" in entity and "current_stamina" in entity:
			max_value = entity.max_stamina
			value = entity.current_stamina
			print("StaminaBar: Set initial values - max: ", max_value, " current: ", value)
		else:
			max_value = 100
			value = 100
			print("StaminaBar: Using default values")
	else:
		print("StaminaBar: Entity has no stamina_changed signal")

func _on_stamina_changed(new_stamina: int, max_stamina: int):
	max_value = max_stamina
	value = new_stamina
