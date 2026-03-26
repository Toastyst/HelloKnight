extends Node
# CombatManager handles resolving combat interactions between attackers and defenders
# Based on their states, positions, and timing for rock-paper-scissors style outcomes

# Signal emitted when combat is resolved
signal combat_resolved(attacker, defender, outcome)

# Combat outcome definitions
enum Outcome { DAMAGE, STAGGER, BLOCK, CLASH, MISS }

func _ready():
	# Connect to global combat events if needed
	pass

# Main function to resolve combat between two entities
func resolve_combat(attacker: Node, defender: Node, _attack_type: String = "light") -> Dictionary:
	"""
	Resolves combat based on attacker and defender states.
	Returns a dictionary with outcome details.
	"""
	var attacker_state = attacker.state_machine.get_state_name() if attacker.has_method("get_state_name") else "UNKNOWN"
	var defender_state = defender.state_machine.get_state_name() if defender.has_method("get_state_name") else "UNKNOWN"

	var outcome = _calculate_outcome(attacker_state, defender_state, _attack_type)
	var result = _apply_outcome(attacker, defender, outcome)

	combat_resolved.emit(attacker, defender, result)
	return result

# Calculate the outcome based on state combinations
func _calculate_outcome(attacker_state: String, defender_state: String, attack_type: String) -> Dictionary:
	# Rock-paper-scissors style combat outcomes
	match [attacker_state, defender_state]:
		# Player Light attacks
		["ATTACK_LIGHT", "IDLE"], ["ATTACK_LIGHT", "PATROL"], ["ATTACK_LIGHT", "CHASE"]:
			return {"type": Outcome.DAMAGE, "damage": 10, "stagger": false}
		["ATTACK_LIGHT", "BLOCK"]:
			return {"type": Outcome.BLOCK, "damage": 0, "stagger": false}
		["ATTACK_LIGHT", "ATTACK"]:
			return {"type": Outcome.CLASH, "damage": 0, "stagger": false, "clash_winner": _random_clash()}

		# Player Heavy attacks
		["ATTACK_HEAVY", "IDLE"], ["ATTACK_HEAVY", "PATROL"], ["ATTACK_HEAVY", "CHASE"]:
			return {"type": Outcome.DAMAGE, "damage": 20, "stagger": true}
		["ATTACK_HEAVY", "BLOCK"]:
			return {"type": Outcome.STAGGER, "damage": 0, "stagger": true, "knockback": true}
		["ATTACK_HEAVY", "ATTACK"]:
			return {"type": Outcome.CLASH, "damage": 0, "stagger": false, "clash_winner": _random_clash()}

		# Enemy attacks
		["ATTACK", "IDLE"], ["ATTACK", "RUN"], ["ATTACK", "JUMP"], ["ATTACK", "FALL"], ["ATTACK", "STAGGER"]:
			return {"type": Outcome.DAMAGE, "damage": 15, "stagger": false}
		["ATTACK", "BLOCK"]:
			return {"type": Outcome.BLOCK, "damage": 0, "stagger": false}
		["ATTACK", "ATTACK_LIGHT"], ["ATTACK", "ATTACK_HEAVY"]:
			return {"type": Outcome.CLASH, "damage": 0, "stagger": false, "clash_winner": _random_clash()}

		# Attacks vs other attacks (simplified)
		["ATTACK_LIGHT", "ATTACK_HEAVY"]:
			return {"type": Outcome.STAGGER, "damage": 5, "stagger": true}
		["ATTACK_HEAVY", "ATTACK_LIGHT"]:
			return {"type": Outcome.DAMAGE, "damage": 15, "stagger": false}

		# Default case
		_:
			return {"type": Outcome.MISS, "damage": 0, "stagger": false}

# Apply the calculated outcome to the entities
func _apply_outcome(attacker: Node, defender: Node, outcome: Dictionary) -> Dictionary:
	match outcome.type:
		Outcome.DAMAGE:
			if defender.has_method("take_damage"):
				defender.take_damage(outcome.damage, attacker)
		Outcome.STAGGER:
			if defender.has_method("stagger"):
				defender.stagger(outcome.get("knockback", false))
		Outcome.CLASH:
			# Both get staggered or one wins
			if outcome.get("clash_winner", "attacker") == "attacker":
				if defender.has_method("stagger"):
					defender.stagger()
			else:
				if attacker.has_method("stagger"):
					attacker.stagger()
		Outcome.BLOCK:
			# Maybe play block effect
			pass
		Outcome.MISS:
			# Maybe play miss effect
			pass

	return outcome

# Helper function for random clash resolution
func _random_clash() -> String:
	return "attacker" if randi() % 2 == 0 else "defender"
