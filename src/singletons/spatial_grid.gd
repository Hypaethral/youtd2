extends Node


# Uniform spatial hash grid used to accelerate
# Utils.get_units_in_range(). Instead of scanning an entire
# node group on every range query, units are bucketed into
# fixed-size cells so a query only needs to look at the cells
# overlapping the query disc.
#
# DETERMINISM: the grid is a purely local acceleration index
# derived from already-synced state (unit positions and UIDs,
# which are identical on every client at a given tick). A range
# query enumerates the same cells in the same order, gathers the
# same candidate set, and Utils.get_units_in_range() then applies
# the exact same predicate chain + UID sort as before. So the
# returned list is byte-identical to the old brute-force scan.
# The grid itself never enters the game-state checksum.
#
# Only units in the "creeps", "towers" and "corpses" groups are
# tracked (those are the only groups queried by
# get_units_in_range). Tracking is driven by Unit lifecycle:
# - add() is called when a unit joins its group (in the subclass
#   _ready)
# - update_position() is called from Unit.set_position_wc3 (the
#   single chokepoint for all position writes)
# - remove() is called from Unit.remove_from_game and on
#   tree_exited as a safety net


# Cell edge length in WC3 units. 256 = 2 tiles. Most queries
# (radii in the low hundreds) touch a 3x3-4x4 block of cells.
# Tunable - smaller cells mean fewer candidates per cell but more
# cells to visit per query.
const CELL_SIZE: float = 256.0


# group_name -> { Vector2i cell -> { uid -> Unit } }
var _grids: Dictionary = {
	"creeps": {},
	"towers": {},
	"corpses": {},
}


#########################
###       Public      ###
#########################

# Register a unit into the grid for the given group. Connects
# tree_exited so the unit is removed even if remove_from_game()
# is bypassed.
func add(group_name: String, unit: Unit):
	if !_grids.has(group_name):
		push_error("SpatialGrid.add() called with unknown group: %s" % group_name)
		return

	var cell: Vector2i = _cell_for_position(unit.get_position_wc3_2d())

	unit._grid_group = group_name
	unit._grid_cell = cell

	_insert(group_name, cell, unit)

	var remove_callable: Callable = remove.bind(unit)
	if !unit.tree_exited.is_connected(remove_callable):
		unit.tree_exited.connect(remove_callable)


# Remove a unit from the grid. Safe to call multiple times and
# safe to call while the unit is being freed.
func remove(unit: Unit):
	if unit == null || !is_instance_valid(unit):
		return

	var group_name: String = unit._grid_group

	if group_name == "":
		return

	_erase(group_name, unit._grid_cell, unit.get_uid())

	unit._grid_group = ""


# Move a tracked unit to a new cell if its position changed cells.
# Called from Unit.set_position_wc3 on every position write.
func update_position(unit: Unit):
	var group_name: String = unit._grid_group

	if group_name == "":
		return

	var new_cell: Vector2i = _cell_for_position(unit.get_position_wc3_2d())

	if new_cell == unit._grid_cell:
		return

	_erase(group_name, unit._grid_cell, unit.get_uid())
	unit._grid_cell = new_cell
	_insert(group_name, new_cell, unit)


# Returns a candidate list of units in the given group whose cell
# overlaps the bounding box of the query disc. This is a superset
# of the true in-range set - the caller is responsible for the
# exact distance/type filtering. May contain units that are out
# of range or queued for deletion.
func query_candidates(group_name: String, center: Vector2, radius: float) -> Array:
	var result: Array = []

	var grid: Dictionary = _grids.get(group_name, {})

	if grid.is_empty():
		return result

	var min_cx: int = floori((center.x - radius) / CELL_SIZE)
	var max_cx: int = floori((center.x + radius) / CELL_SIZE)
	var min_cy: int = floori((center.y - radius) / CELL_SIZE)
	var max_cy: int = floori((center.y + radius) / CELL_SIZE)

	for cx in range(min_cx, max_cx + 1):
		for cy in range(min_cy, max_cy + 1):
			var cell: Dictionary = grid.get(Vector2i(cx, cy), {})

			for uid in cell:
				result.append(cell[uid])

	return result


# Clears the entire grid. Call when a game ends / restarts.
func reset():
	for group_name in _grids:
		_grids[group_name] = {}


#########################
###      Private      ###
#########################

func _cell_for_position(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.y / CELL_SIZE))


func _insert(group_name: String, cell: Vector2i, unit: Unit):
	var grid: Dictionary = _grids[group_name]

	if !grid.has(cell):
		grid[cell] = {}

	grid[cell][unit.get_uid()] = unit


func _erase(group_name: String, cell: Vector2i, uid: int):
	var grid: Dictionary = _grids[group_name]

	if !grid.has(cell):
		return

	var bucket: Dictionary = grid[cell]
	bucket.erase(uid)

	if bucket.is_empty():
		grid.erase(cell)
