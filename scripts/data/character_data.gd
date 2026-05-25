class_name CharacterData
extends RefCounted
## 兼容层：Bot 估值 archetype + 名称回退

const RosterConfigScript = preload("res://scripts/data/roster_config.gd")

enum SkillArchetype {
	INTEL,
	VALUATION,
	DISRUPT,
	BLOCKER,
}

const DEFINITIONS: Dictionary = {
	"ethan": {
		"display_name": "伊森",
		"archetype": SkillArchetype.VALUATION,
		"description": "看仓深，按格数估值",
	},
	"old_man": {
		"display_name": "老头",
		"archetype": SkillArchetype.VALUATION,
		"description": "早期获知紫/金件数",
	},
	"weilong": {
		"display_name": "威龙",
		"archetype": SkillArchetype.BLOCKER,
		"description": "抬价阻止捡漏",
	},
	"raven": {
		"display_name": "拉文",
		"archetype": SkillArchetype.INTEL,
		"description": "跟价与末轮收割",
	},
}


static func get_display_name(character_id: String) -> String:
	if RosterConfigScript.has_character(character_id):
		return RosterConfigScript.get_display_name(character_id)
	if DEFINITIONS.has(character_id):
		return DEFINITIONS[character_id]["display_name"]
	return character_id


static func get_archetype(character_id: String) -> SkillArchetype:
	if RosterConfigScript.has_character(character_id):
		return RosterConfigScript.get_archetype_for_intel(character_id)
	if DEFINITIONS.has(character_id):
		return DEFINITIONS[character_id]["archetype"]
	return SkillArchetype.VALUATION
