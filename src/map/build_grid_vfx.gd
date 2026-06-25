class_name BuildAreaVFX
extends TileMapLayer

const COLOR := Color8(0, 255, 255, 36)
const MIN_A := 0.1
const MAX_A := 0.2
const PERIOD := 1.0

var _build_grid: BuildGridManager
@export var player_id: int

#func _ready():
	#visible = true
	#z_index = 100
	#modulate = Color(1, 1, 1, 1)
#
#func _process(delta):
	#var mat := get_material() as ShaderMaterial
	#mat.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
#
func set_grid(g: BuildGridManager):
	_build_grid = g
#
#func rebuild():
	#
	#set_cell(Vector2i.ZERO, 0, Vector2i.ZERO)
	#if _build_grid == null:
		#return
#
	#var mat := material as ShaderMaterial
	#if mat == null:
		#push_warning("No ShaderMaterial on " + name)
		#return
#
	#var tex := _build_grid.build_mask_texture()
	#if tex == null:
		#return
#
	#mat.set_shader_parameter("mask_tex", tex)

func rebuild():
	clear()
	var cells = _build_grid.get_owned_cells(player_id)
	for c in cells:
		set_cell(c, 0, Vector2i(3, 0))
	_play_pulse()

func _play_pulse():
	modulate = COLOR

	var tween = create_tween()
	tween.tween_property(self, "modulate",
		Color(COLOR, MIN_A),
		PERIOD * 0.5)

	tween.tween_property(self, "modulate",
		Color(COLOR, MAX_A),
		PERIOD * 0.5).set_delay(PERIOD * 0.5)

	tween.set_loops()
