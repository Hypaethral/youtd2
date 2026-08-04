class_name CreepCategoryThemes extends Node

enum OSEnm {
	FINI,
	RUNE,
	JUNO,
	DREK,
	AIMI,
	SONI,
}

static func convert_to_creep_category(e: CreepCategoryThemes.OSEnm) -> CreepCategory.enm:
	return _os_creep_category_map[e]

static func convert_from_creep_category(e: CreepCategory.enm) -> CreepCategoryThemes.OSEnm:
	return _creep_category_os_map[e]

static func convert_to_string(e: CreepCategoryThemes.OSEnm) -> String:
	return _os_string_map[e]

static func convert_from_string(s: String) -> CreepCategoryThemes.OSEnm:
	return _string_os_map[s]

static var _os_creep_category_map: Dictionary = {
	CreepCategory.enm.UNDEAD: CreepCategoryThemes.OSEnm.RUNE,
	CreepCategory.enm.MAGIC: CreepCategoryThemes.OSEnm.FINI,
	CreepCategory.enm.NATURE: CreepCategoryThemes.OSEnm.JUNO,
	CreepCategory.enm.ORC: CreepCategoryThemes.OSEnm.DREK,
	CreepCategory.enm.HUMANOID: CreepCategoryThemes.OSEnm.AIMI,
	CreepCategory.enm.CHALLENGE: CreepCategoryThemes.OSEnm.SONI
}

static var _creep_category_os_map: Dictionary = {
	CreepCategoryThemes.OSEnm.RUNE: CreepCategory.enm.UNDEAD,
	CreepCategoryThemes.OSEnm.FINI: CreepCategory.enm.MAGIC,
	CreepCategoryThemes.OSEnm.JUNO: CreepCategory.enm.NATURE,
	CreepCategoryThemes.OSEnm.DREK: CreepCategory.enm.ORC,
	CreepCategoryThemes.OSEnm.AIMI: CreepCategory.enm.HUMANOID,
	CreepCategoryThemes.OSEnm.SONI: CreepCategory.enm.CHALLENGE,
}

static var _os_string_map: Dictionary = {
	CreepCategoryThemes.OSEnm.RUNE: "rune",
	CreepCategoryThemes.OSEnm.FINI: "fini",
	CreepCategoryThemes.OSEnm.JUNO: "juno",
	CreepCategoryThemes.OSEnm.DREK: "drek",
	CreepCategoryThemes.OSEnm.AIMI: "aimi",
	CreepCategoryThemes.OSEnm.SONI: "soni",
}

static var _string_os_map: Dictionary = {
	"rune": CreepCategoryThemes.OSEnm.RUNE,
	"fini": CreepCategoryThemes.OSEnm.FINI,
	"juno": CreepCategoryThemes.OSEnm.JUNO,
	"drek": CreepCategoryThemes.OSEnm.DREK,
	"aimi": CreepCategoryThemes.OSEnm.AIMI,
	"soni": CreepCategoryThemes.OSEnm.SONI,
}
