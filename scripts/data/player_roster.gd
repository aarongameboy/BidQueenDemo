extends Node
## 玩家出战角色（持久化）

const RosterConfigScript = preload("res://scripts/data/roster_config.gd")
const SAVE_PATH := "user://player_roster.json"

var selected_character_id: String = "aria_lionheart"


func _ready() -> void:
	RosterConfigScript.ensure_loaded()
	load_data()
	if not RosterConfigScript.has_character(selected_character_id):
		selected_character_id = RosterConfigScript.get_default_id()


func set_selected(character_id: String) -> void:
	RosterConfigScript.ensure_loaded()
	if not RosterConfigScript.has_character(character_id):
		return
	selected_character_id = character_id
	save_data()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		selected_character_id = RosterConfigScript.get_default_id()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var cid: String = str(parsed.get("selected_character_id", ""))
	if RosterConfigScript.has_character(cid):
		selected_character_id = cid


func save_data() -> void:
	var data := {"selected_character_id": selected_character_id}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
