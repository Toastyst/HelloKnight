extends Node
class_name LLSM

# LLSM (LLM State Machine) - General: Proposes states and barks based on context
# Wraps TinySprite ONNX model (mock rule-based until ONNX ready)

var states: Dictionary = {}

func _ready():
	# Load states on init if path provided, but for now manual
	pass

func load_states(json_path: String) -> void:
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_text)
		if error == OK:
			states = json.data
		else:
			push_error("Failed to parse states_config.json")
	else:
		push_error("Failed to open states_config.json")

func propose_state(input: Dictionary) -> Dictionary:
	# Mock rule-based proposer until ONNX model ready
	# Input: {"character_type": String, "interaction_type": String, "context_state": String}
	# Output: {"proposed_state": String, "bark": String}

	var proposed_state = "IDLE"
	var bark = "Hmm..."

	var char_type = input.get("character_type", "GRUNT")
	var interaction = input.get("interaction_type", "IDLE")
	var context = input.get("context_state", "HEALTHY")

	# Defensive states override
	if context == "LOW_STAMINA":
		proposed_state = "BLOCK"
		bark = "Need to rest..."
	elif context == "STUNNED":
		proposed_state = "IDLE"
		bark = "Can't move..."
	else:
		# Normal rules
		if interaction == "ATTACK_RANGE":
			proposed_state = "ATTACK"
			bark = "Die!"
		elif interaction == "CHASE":
			proposed_state = "CHASE"
			bark = "You can't escape!"
		elif interaction == "PATROL":
			proposed_state = "PATROL"
			bark = "Patrolling..."
		else:
			proposed_state = "IDLE"
			bark = "Standing by."

	# Adjust for health context
	if context == "WOUNDED":
		bark += " (wounded)"
	elif context == "CRITICAL":
		bark += " (dying)"

	return {"proposed_state": proposed_state, "bark": bark}

# Future: Replace propose_state with ONNX inference
# func load_model(path: String) -> void:
#     # Load TinySprite ONNX
#     pass
#
# func run_inference(input: Dictionary) -> Dictionary:
#     # ONNX session run
#     pass
