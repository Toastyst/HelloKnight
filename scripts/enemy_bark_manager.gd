extends Node
class_name EnemyBarkManager

enum BarkTier { COMMON, UNCOMMON, RARE, LEGENDARY }

@export var barks_path: String = "res://data/barks.json"

var barks: Dictionary = {}

func _ready():
	load_barks()

func load_barks():
	var file = FileAccess.open(barks_path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			barks = json.data
		else:
			push_error("Failed to parse barks.json")

func get_bark(enemy_type: String) -> Dictionary:
	var offset = 0
	match enemy_type:
		"TANK", "FAST": offset = 1
		"ELITE", "BOSS": offset = 2
	var roll = randi() % 4 + offset
	if roll >= 4:
		roll = 3
	var tier = BarkTier.keys()[roll]
	if offset >= 2 and tier == "COMMON":
		tier = BarkTier.UNCOMMON
	var texts = barks[tier]
	var text = texts[randi() % texts.size()]
	return {"text": text, "tier": tier}