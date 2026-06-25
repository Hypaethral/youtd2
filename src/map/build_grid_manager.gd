class_name BuildGridManager
extends Node

@export var grid_data: BuildGridData

var ownership := {} # Vector2i -> int

func _ready():
	_build_runtime_lookup()

func _build_runtime_lookup():

	ownership.clear()

	for area in grid_data.build_areas:

		var cells = area.cells

		for cell in cells:
			ownership[cell] = area.player_id

func get_area_owner(cell: Vector2i) -> int:
	return ownership.get(cell, -1)

func is_area_owned_by(cell: Vector2i, player_id: int) -> bool:
	return ownership.get(cell, -1) == player_id

func get_owned_cells(player_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for cell in ownership.keys():
		if ownership[cell] == player_id:
			result.append(cell)

	return result
#
#func build_mask_texture(grid_cells: Array[Vector2i], cell_size: int) -> ImageTexture:
	#var img = Image.create(256, 256, false, Image.FORMAT_RF)
#
	#img.fill(Color.BLACK)
#
	#for cell in grid_cells:
		#var x = cell.x + 128
		#var y = cell.y + 128
		#img.set_pixel(x, y, Color.WHITE)
#
	#return ImageTexture.create_from_image(img)

#func build_mask_texture(cell_size: int = 1) -> ImageTexture:
	#var cells := ownership.keys()
#
	#if cells.is_empty():
		#return null
#
	## 1. find bounds
	#var min_x = INF
	#var min_y = INF
	#var max_x = -INF
	#var max_y = -INF
#
	#for c in cells:
		#min_x = min(min_x, c.x)
		#min_y = min(min_y, c.y)
		#max_x = max(max_x, c.x)
		#max_y = max(max_y, c.y)
#
	#var width = int(max_x - min_x + 1)
	#var height = int(max_y - min_y + 1)
#
	## 2. create image
	#var img := Image.create(width, height, false, Image.FORMAT_RF)
#
	#img.fill(Color(0, 0, 0))
#
	## 3. fill pixels
	#for c in cells:
		#var x = c.x - min_x
		#var y = c.y - min_y
		#img.set_pixel(x, y, Color(1, 1, 1))
#
	## 4. convert to texture
	#var tex := ImageTexture.create_from_image(img)
	#return tex
