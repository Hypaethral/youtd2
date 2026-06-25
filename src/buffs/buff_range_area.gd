class_name BuffRangeArea
extends Node2D

# BuffRangeArea emits a signal when a unit that matches the
# defined target type comes in range. Used by buffs to
# implement the "unit comes in range" event.

signal unit_came_in_range(handler: Callable, unit: Unit)


var _target_type: TargetType
var _handler: Callable
var _radius: float
var _buff: Buff
var _prev_units_in_range: Array = []


#########################
###     Callbacks     ###
#########################

func _on_manual_timer_timeout():
	var buffed_unit: Unit = _buff.get_buffed_unit()

	if buffed_unit == null:
		return

	var caster: Unit = _buff.get_caster()
	var buffed_unit_pos: Vector2 = buffed_unit.get_position_wc3_2d()
#	NOTE: get_units_in_range() already filters by _target_type
#	(via type.match), so all returned units match - no need to
#	re-check here.
	var matching_units: Array = Utils.get_units_in_range(caster, _target_type, buffed_unit_pos, _radius)

#	NOTE: build a membership set of the previous frame's units
#	so the "just came in range" check is O(1) instead of an
#	O(n) Array.has() per unit.
	var prev_set: Dictionary = {}
	for unit in _prev_units_in_range:
		prev_set[unit] = true

	for unit in matching_units:
		var unit_just_came_in_range: bool = !prev_set.has(unit)

		if unit_just_came_in_range:
			unit_came_in_range.emit(_handler, unit)

	_prev_units_in_range = matching_units


#########################
###       Static      ###
#########################

static func make(radius: float, target_type: TargetType, handler: Callable, buff: Buff) -> BuffRangeArea:
	var buff_range_area: BuffRangeArea = Preloads.buff_range_area_scene.instantiate()
	buff_range_area._radius = radius
	buff_range_area._target_type = target_type
	buff_range_area._handler = handler
	buff_range_area._buff = buff

	return buff_range_area
