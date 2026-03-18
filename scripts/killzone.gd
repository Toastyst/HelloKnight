extends Area2D

@onready var timer: Timer = $Timer


func _on_body_entered(body):
	if body.has_method("die"):  # Check if it's a player/enemy with die method
		body.die()  # Trigger proper death state
		timer.start()  # Start scene reload timer

func _on_timer_timeout() -> void:
	Engine.time_scale = 1
	get_tree().reload_current_scene() #Reload the level
