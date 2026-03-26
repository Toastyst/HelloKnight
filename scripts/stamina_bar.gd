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
	if entity.has_signal("stamina_changed"):
		entity.stamina_changed.connect(_on_stamina_changed)
		# Set initial values
		if "max_stamina" in entity and "current_stamina" in entity:
			max_value = entity.max_stamina
			value = entity.current_stamina
		else:
			max_value = 100
			value = 100
	else:
		pass

func _on_stamina_changed(new_stamina: int, max_stamina: int):
	max_value = max_stamina
	value = new_stamina
