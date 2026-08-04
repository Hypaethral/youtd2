extends Node


# Stores preloaded resources, such as scenes and textures.
# Need to preload scenes here instead of directly in scripts
# to prevent cyclic references. Note that not all of these
# scenes cause cyclic references.


const title_screen_scene: PackedScene = preload("res://src/ui/title_screen/title_screen.tscn")
const game_scene_scene: PackedScene = preload("res://src/game_scene/game_scene.tscn")
const item_button_scene: PackedScene = preload("res://src/ui/buttons/item_button.tscn")
const tower_button_scene: PackedScene = preload("res://src/ui/buttons/tower_button.tscn")
const floating_text_scene: PackedScene = preload("res://src/ui/hud/floating_text.tscn")
const projectile_scene: PackedScene = preload("res://src/projectiles/projectile.tscn")
const aura_scene: PackedScene = preload("res://src/buffs/aura.tscn")
const buff_range_area_scene: PackedScene = preload("res://src/buffs/buff_range_area.tscn")
const corpse_scene: PackedScene = preload("res://src/creeps/creep_corpse.tscn")
const blood_pool_scene: PackedScene = preload("res://src/creeps/creep_blood_pool.tscn")
const flying_item_scene: PackedScene = preload("res://src/ui/hud/flying_item.tscn")
const autocast_button_scene: PackedScene = preload("res://src/ui/buttons/autocast_button.tscn")
const autocast_scene: PackedScene = preload("res://src/towers/autocast.tscn")
const placeholder_effect_scene: PackedScene = preload("res://src/effects/placeholder.tscn")
const empty_slot_button_scene: PackedScene = preload("res://src/ui/buttons/empty_unit_button.tscn")
const range_indicator_scene: PackedScene = preload("res://src/towers/range_indicator.tscn")
const outline_shader: Material = preload("res://resources/shaders/glowing_outline.material")
const player_scene: PackedScene = preload("res://src/player/player.tscn")
const team_scene: PackedScene = preload("res://src/player/team.tscn")
const tower_preview_scene: PackedScene = preload("res://src/towers/tower_preview.tscn")
const tower_scene: PackedScene = preload("res://src/towers/tower.tscn")
const buff_display_scene: PackedScene = preload("res://src/ui/unit_menu/buff_display.tscn")
const fallback_buff_icon: Texture = preload("res://resources/icons/generic_icons/egg.tres")
const builder_button_scene: PackedScene = preload("res://src/ui/buttons/builder_button.tscn")
const ability_button_scene: PackedScene = preload("res://src/ui/buttons/ability_button.tscn")
const inventory_slot_button_scene: PackedScene = preload("res://src/ui/buttons/inventory_slot_button.tscn")
const mission_card: PackedScene = preload("res://src/ui/title_screen/missions_menu/mission_card.tscn")
const mission_track_indicator_scene: PackedScene = preload("res://src/ui/hud/mission_track_indicator.tscn")
const noto_sans_chinese_font: Font = preload("res://assets/fonts/NotoSansSC-Medium.ttf")
const friz_font: Font = preload("res://assets/fonts/Friz Quadrata Std Medium.otf")


const element_icons: Dictionary = {
	Element.enm.ICE: preload("res://resources/icons/elements/ice.tres"),
	Element.enm.NATURE: preload("res://resources/icons/elements/nature.tres"),
	Element.enm.ASTRAL: preload("res://resources/icons/elements/astral.tres"),
	Element.enm.DARKNESS: preload("res://resources/icons/elements/darkness.tres"),
	Element.enm.FIRE: preload("res://resources/icons/elements/fire.tres"),
	Element.enm.IRON: preload("res://resources/icons/elements/iron.tres"),
	Element.enm.STORM: preload("res://resources/icons/elements/storm.tres"),
}

# todo: clone creep scenes for each creep upsidedown smileyface
# each creep scene will be loaded dynamically from creep_spawner.gd (Wave.get_scene_name_for_creep_type(creep_size, creep_race))
const creep_scenes: Dictionary = {
	"OrcChampion": preload("res://src/creeps/instances/orc/orc_champion_creep.tscn"),
	"OrcAir": preload("res://src/creeps/instances/orc/orc_air_creep.tscn"),
	"OrcBoss": preload("res://src/creeps/instances/orc/orc_boss_creep.tscn"),
	"OrcMass": preload("res://src/creeps/instances/orc/orc_mass_creep.tscn"),
	"OrcNormal": preload("res://src/creeps/instances/orc/orc_normal_creep.tscn"),
	"ChallengeBoss": preload("res://src/creeps/instances/challenge/challenge_boss_creep.tscn"),
	"ChallengeMass": preload("res://src/creeps/instances/challenge/challenge_mass_creep.tscn"),

	"AimiAir": preload("res://src/creeps/instances/aimi/aimi_air_creep.tscn"),
	"AimiChampion": preload("res://src/creeps/instances/aimi/aimi_champion_creep.tscn"),
	"AimiBoss": preload("res://src/creeps/instances/aimi/aimi_boss_creep.tscn"),
	"AimiMass": preload("res://src/creeps/instances/aimi/aimi_mass_creep.tscn"),
	"AimiNormal": preload("res://src/creeps/instances/aimi/aimi_normal_creep.tscn"),

	"DrekAir": preload("res://src/creeps/instances/drek/drek_air_creep.tscn"),
	"DrekChampion": preload("res://src/creeps/instances/drek/drek_champion_creep.tscn"),
	"DrekBoss": preload("res://src/creeps/instances/drek/drek_boss_creep.tscn"),
	"DrekMass": preload("res://src/creeps/instances/drek/drek_mass_creep.tscn"),
	"DrekNormal": preload("res://src/creeps/instances/drek/drek_normal_creep.tscn"),

	"FiniAir": preload("res://src/creeps/instances/fini/fini_air_creep.tscn"),
	"FiniChampion": preload("res://src/creeps/instances/fini/fini_champion_creep.tscn"),
	"FiniBoss": preload("res://src/creeps/instances/fini/fini_boss_creep.tscn"),
	"FiniMass": preload("res://src/creeps/instances/fini/fini_mass_creep.tscn"),
	"FiniNormal": preload("res://src/creeps/instances/fini/fini_normal_creep.tscn"),

	"JunoAir": preload("res://src/creeps/instances/juno/juno_air_creep.tscn"),
	"JunoChampion": preload("res://src/creeps/instances/juno/juno_champion_creep.tscn"),
	"JunoBoss": preload("res://src/creeps/instances/juno/juno_boss_creep.tscn"),
	"JunoMass": preload("res://src/creeps/instances/juno/juno_mass_creep.tscn"),
	"JunoNormal": preload("res://src/creeps/instances/juno/juno_normal_creep.tscn"),

	"RuneAir": preload("res://src/creeps/instances/rune/rune_air_creep.tscn"),
	"RuneChampion": preload("res://src/creeps/instances/rune/rune_champion_creep.tscn"),
	"RuneBoss": preload("res://src/creeps/instances/rune/rune_boss_creep.tscn"),
	"RuneMass": preload("res://src/creeps/instances/rune/rune_mass_creep.tscn"),
	"RuneNormal": preload("res://src/creeps/instances/rune/rune_normal_creep.tscn"),

	"SoniBoss": preload("res://src/creeps/instances/soni/soni_boss_creep.tscn"),
	"SoniMass": preload("res://src/creeps/instances/soni/soni_mass_creep.tscn"),
}
