class_name Iterate


# Iterate is a wrapper over get_units_in_range() f-n which
# stores the resulting unit list and allows iterating over
# units.


var _next_list: Array[Unit] = []


func _init(caster: Unit, center_pos: Vector2, target_type: TargetType, radius: float):
	_next_list = Utils.get_units_in_range(caster, target_type, center_pos, radius)


# NOTE: Iterate.overUnitsInRangeOf() in JASS
static func over_units_in_range_of(caster: Unit, target_type: TargetType, center_pos: Vector2, radius: float) -> Iterate:
	var it: Iterate = Iterate.new(caster, center_pos, target_type, radius)

	return it


# NOTE: Iterate.overUnitsInRangeOfCaster() in JASS
static func over_units_in_range_of_caster(caster: Unit, target_type: TargetType, radius: float) -> Iterate:
	var center_pos: Vector2 = caster.get_position_wc3_2d()
	var it: Iterate = Iterate.new(caster, center_pos, target_type, radius)

	return it


# NOTE: Iterate.overUnitsInRangeOfUnit() in JASS
static func over_units_in_range_of_unit(caster: Unit, target_type: TargetType, center: Unit, radius: float) -> Iterate:
	var center_pos: Vector2 = center.get_position_wc3_2d()
	var it: Iterate = Iterate.new(caster, center_pos, target_type, radius)

	return it


static func over_corpses_in_range(caster: Unit, center_pos: Vector2, radius: float) -> Iterate:
	var it: Iterate = Iterate.new(caster, center_pos, TargetType.new(TargetType.CORPSES), radius)

	return it


# NOTE: iterate.next() in JASS
func next() -> Unit:
#	NOTE: pop from the front skipping invalid units instead of
#	filtering the whole list. This avoids the O(n) allocating
#	.filter() on every call (which made draining an Iterate
#	O(n^2)). Yields the same units in the same front-to-back
#	order as the old filter-then-pop_front.
	while !_next_list.is_empty():
		var candidate: Unit = _next_list.pop_front()

		if Utils.unit_is_valid(candidate):
			return candidate

	return null


# NOTE: iterate.nextRandom() in JASS
func next_random() -> Unit:
	_remove_invalid_units()
	
	var next_unit: Unit

	if !_next_list.is_empty():
		next_unit = Utils.pick_random(Globals.synced_rng, _next_list)
		_next_list.erase(next_unit)
	else:
		next_unit = null

	return next_unit


# NOTE: iterate.nextCorpse() in JASS
func next_corpse() -> Unit:
	var corpse: Unit = next()

	return corpse


# NOTE: iterate.destroy() in JASS
# JASS engine had this f-n but it's not needed in Godot
# engine - do not call it.
# func destroy():
	# pass


# NOTE: iterate.count() in JASS
func count() -> int:
	_remove_invalid_units()

	return _next_list.size()


# NOTE: need to remove invalid units before count() or
# next_random() because units may be killed or removed from
# the game while Iterate is used. next_random() needs an
# accurate size to pick deterministically and count() needs an
# accurate count.
#
# NOTE: compact in place (preserving order) instead of
# _next_list.filter() so we don't allocate a new array and
# invoke a lambda per element on every call.
func _remove_invalid_units():
	var write_idx: int = 0

	for read_idx in range(_next_list.size()):
		var unit: Unit = _next_list[read_idx]

		if Utils.unit_is_valid(unit):
			_next_list[write_idx] = unit
			write_idx += 1

	_next_list.resize(write_idx)
