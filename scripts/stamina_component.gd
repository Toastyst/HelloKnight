extends Node
class_name StaminaComponent

@export var max_stamina: int = 100
var current_stamina: float = max_stamina
@export var regen_rate: float = 20.0
@export var regen_delay: float = 2.0
var regen_timer: Timer
var exhaustion_timer: Timer
var is_blocking: bool = false
var exhaustion_threshold: int = 0
var recovery_threshold: int = 20
var negative_cap: int = -50

signal stamina_changed(new_stamina: float, max_stamina: int)
signal exhaustion_entered
signal exhaustion_exited

func _ready():
	current_stamina = max_stamina
	stamina_changed.emit(current_stamina, max_stamina)
	regen_timer = Timer.new()
	regen_timer.timeout.connect(_on_regen_tick)
	add_child(regen_timer)
	exhaustion_timer = Timer.new()
	exhaustion_timer.one_shot = true
	exhaustion_timer.timeout.connect(_start_regen)
	add_child(exhaustion_timer)

func consume(amount: int) -> bool:
	if current_stamina >= amount:
		current_stamina -= amount
		stamina_changed.emit(current_stamina, max_stamina)
		_stop_regen()
		exhaustion_timer.start(regen_delay)
		return true
	else:
		var new_stamina = current_stamina - amount
		if new_stamina >= negative_cap:
			current_stamina = new_stamina
			stamina_changed.emit(current_stamina, max_stamina)
			_stop_regen()
			exhaustion_timer.start(regen_delay)
			return true
		else:
			return false

func _stop_regen():
	regen_timer.stop()

func _start_regen():
	regen_timer.start(0.1)

func _on_regen_tick():
	var rate = regen_rate * (0.2 if is_blocking else 1.0)
	current_stamina = min(max_stamina, current_stamina + rate * 0.1)
	stamina_changed.emit(current_stamina, max_stamina)
	if current_stamina >= recovery_threshold and is_exhausted():
		exhaustion_exited.emit()

func is_exhausted() -> bool:
	return current_stamina <= exhaustion_threshold

func set_blocking(blocking: bool):
	is_blocking = blocking
