class_name RosterConfig
extends RefCounted
## 出战角色表：config/characters.json

const CONFIG_PATH := "res://config/characters.json"
const AVATAR_CROP_TOP_RATIO: float = 0.035

static var _loaded: bool = false
static var _default_id: String = "aria_lionheart"
static var _by_id: Dictionary = {}


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_by_id.clear()
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("RosterConfig: missing %s" % CONFIG_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("RosterConfig: invalid JSON")
		return
	_default_id = str(parsed.get("default_character_id", "aria_lionheart"))
	for row in parsed.get("characters", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var cid: String = str(row.get("id", ""))
		if cid.is_empty():
			continue
		_by_id[cid] = row


static func get_default_id() -> String:
	ensure_loaded()
	return _default_id


static func all_ids() -> Array[String]:
	ensure_loaded()
	var out: Array[String] = []
	for k in _by_id.keys():
		out.append(str(k))
	out.sort()
	return out


static func has_character(character_id: String) -> bool:
	ensure_loaded()
	return _by_id.has(character_id)


static func get_row(character_id: String) -> Dictionary:
	ensure_loaded()
	if _by_id.has(character_id):
		return _by_id[character_id].duplicate(true)
	return {}


static func get_display_name(character_id: String) -> String:
	var row: Dictionary = get_row(character_id)
	if row.is_empty():
		return character_id
	return str(row.get("display_name", character_id))


static func get_role_title(character_id: String) -> String:
	var row: Dictionary = get_row(character_id)
	if row.is_empty():
		return "收藏家"
	return str(row.get("title", row.get("role", "收藏家")))


static func get_skill_id(character_id: String) -> String:
	var row: Dictionary = get_row(character_id)
	return str(row.get("skill_id", ""))


static func get_skill_name(character_id: String) -> String:
	var row: Dictionary = get_row(character_id)
	return str(row.get("skill_name", ""))


static func get_skill_desc(character_id: String) -> String:
	var row: Dictionary = get_row(character_id)
	return str(row.get("skill_desc", ""))


static func get_portrait_path(character_id: String) -> String:
	var row: Dictionary = get_row(character_id)
	var path: String = str(row.get("portrait", ""))
	if ResourceLoader.exists(path):
		return path
	var standing_path: String = str(row.get("standing", ""))
	if ResourceLoader.exists(standing_path):
		return standing_path
	return "res://assets/ui/avatars/avatar_0.png"


static func get_standing_path(character_id: String) -> String:
	var row: Dictionary = get_row(character_id)
	var path: String = str(row.get("standing", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		return path
	return get_portrait_path(character_id)


static func get_background_path(character_id: String) -> String:
	var row: Dictionary = get_row(character_id)
	var path: String = str(row.get("background", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		return path
	return ""


static func get_avatar_source_path(character_id: String) -> String:
	var row: Dictionary = get_row(character_id)
	var path: String = str(row.get("avatar", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		return path
	return get_standing_path(character_id)


static func get_avatar_texture(character_id: String) -> Texture2D:
	var row: Dictionary = get_row(character_id)
	var avatar_path: String = str(row.get("avatar", ""))
	if not avatar_path.is_empty() and ResourceLoader.exists(avatar_path):
		return load(avatar_path) as Texture2D
	var standing_path: String = str(row.get("standing", ""))
	if not standing_path.is_empty() and ResourceLoader.exists(standing_path):
		var standing_tex: Texture2D = load(standing_path) as Texture2D
		return _make_avatar_crop(standing_tex)
	var portrait_path: String = get_portrait_path(character_id)
	if ResourceLoader.exists(portrait_path):
		return load(portrait_path) as Texture2D
	return null


static func _make_avatar_crop(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var w: int = tex.get_width()
	var h: int = tex.get_height()
	if w <= 0 or h <= 0:
		return tex
	var side: int = mini(w, h)
	var y: int = clampi(int(float(h) * AVATAR_CROP_TOP_RATIO), 0, maxi(h - side, 0))
	var x: int = maxi(int((w - side) * 0.5), 0)
	var crop := AtlasTexture.new()
	crop.atlas = tex
	crop.region = Rect2(float(x), float(y), float(side), float(side))
	return crop


static func get_bot_cfg(character_id: String) -> Dictionary:
	var row: Dictionary = get_row(character_id)
	if row.is_empty():
		return {"id": character_id}
	return {
		"id": character_id,
		"aggression": float(row.get("aggression", 0.45)),
		"raise_tendency": float(row.get("raise_tendency", 0.5)),
		"valuation_bias": float(row.get("valuation_bias", 0.0)),
		"bluff_rate": float(row.get("bluff_rate", 0.1)),
		"max_chase_ratio": float(row.get("max_chase_ratio", 1.25)),
	}


## 兼容旧 Bot 估值管线（warehouse.get_intel_summary archetype）
static func get_archetype_for_intel(character_id: String) -> int:
	const CharacterDataScript = preload("res://scripts/data/character_data.gd")
	var skill: String = get_skill_id(character_id)
	match skill:
		"night_raven_peek", "holy_bell_shake", "iron_pact", "art_golden_eye", "keen_sight", "final_seizure":
			return CharacterDataScript.SkillArchetype.INTEL
		"star_chart_valuation", "court_announce", "amber_scale":
			return CharacterDataScript.SkillArchetype.VALUATION
		"black_rose_pressure":
			return CharacterDataScript.SkillArchetype.BLOCKER
		_:
			return CharacterDataScript.SkillArchetype.VALUATION
