extends MainLoop

# Validates the deterministic-ordering contract of GroupManager,
# which now backs the per-tick simulation update loop (creeps,
# towers, projectiles, manual_timers) instead of the old
# get_nodes_in_group() + sort_custom(get_uid) scrape.
#
# The contract:
#  - get_ordered() returns live nodes in ascending-UID order
#    regardless of the order they were add()ed.
#  - remove() drops entries and keeps the order correct.
#  - the cached order is only recomputed when membership changes
#    (the dirty flag), and reset() fully clears state.
#
# This is the pure, dependency-free piece. The full cross-client
# byte-identical checksum guarantee is validated by a live
# 2-client playtest (see tools/test_resync_determinism.gd note).
#
# Run:  godot --headless --path . --script tools/test_groupmanager_ordering.gd

var _failed: bool = false
var _nodes: Array[Node] = []


func _initialize():
	print("=== GroupManager ordering validation ===")
	_test_ascending_order_from_scrambled_adds()
	_test_remove_keeps_order()
	_test_dirty_flag_cache()
	_test_reset_clears_state()
	_free_nodes()

	if _failed:
		print("=== RESULT: FAIL ===")
	else:
		print("=== RESULT: PASS ===")


func _process(_delta: float) -> bool:
	return true


func _check(condition: bool, label: String):
	if condition:
		print("  PASS: ", label)
	else:
		_failed = true
		print("  FAIL: ", label)


func _make_gm() -> Node:
	return load("res://src/singletons/group_manager.gd").new()


# A bare node tracked so we can free it at the end. The registry
# keys on the uid we pass in, so the node needs no get_uid().
func _node() -> Node:
	var n: Node = Node.new()
	_nodes.append(n)
	return n


func _uids_of(node_list: Array) -> Array:
	var out: Array = []
	for n in node_list:
		out.append(n.get_meta("uid"))
	return out


func _add(gm: Node, group: String, uid: int):
	var n: Node = _node()
	n.set_meta("uid", uid)
	gm.add(group, n, uid)


# Adding in scrambled order must still read back ascending by UID.
func _test_ascending_order_from_scrambled_adds():
	print("- scrambled adds read back in ascending-UID order")

	var gm: Node = _make_gm()
	for uid in [5, 1, 9, 3, 7, 2]:
		_add(gm, "creeps", uid)

	var ordered: Array = _uids_of(gm.get_ordered("creeps"))
	_check(ordered == [1, 2, 3, 5, 7, 9], "ordered ascending: %s" % str(ordered))
	_check(gm.get_ordered("nonexistent_group") == [], "unknown group returns empty array")

	gm.free()


# Removing an entry must drop it and preserve ascending order.
func _test_remove_keeps_order():
	print("- remove() drops entries and preserves order")

	var gm: Node = _make_gm()
	for uid in [10, 20, 30, 40]:
		_add(gm, "towers", uid)

	gm.remove("towers", 20)
	gm.remove("towers", 40)
	var ordered: Array = _uids_of(gm.get_ordered("towers"))
	_check(ordered == [10, 30], "after removal: %s" % str(ordered))

#	Idempotent: removing a missing uid is a harmless no-op.
	gm.remove("towers", 999)
	gm.remove("towers", 20)
	ordered = _uids_of(gm.get_ordered("towers"))
	_check(ordered == [10, 30], "redundant/missing removes are no-ops: %s" % str(ordered))

	gm.free()


# A new add after a read must invalidate the cache so the next
# read reflects it; a read with no mutation must be stable.
func _test_dirty_flag_cache():
	print("- cache invalidates on mutation, stable otherwise")

	var gm: Node = _make_gm()
	for uid in [2, 4, 6]:
		_add(gm, "projectiles", uid)

	var first: Array = _uids_of(gm.get_ordered("projectiles"))
	var second: Array = _uids_of(gm.get_ordered("projectiles"))
	_check(first == [2, 4, 6] && second == [2, 4, 6], "repeated read stable: %s" % str(second))

	_add(gm, "projectiles", 1)
	_add(gm, "projectiles", 5)
	var third: Array = _uids_of(gm.get_ordered("projectiles"))
	_check(third == [1, 2, 4, 5, 6], "read reflects new adds: %s" % str(third))

	gm.free()


func _test_reset_clears_state():
	print("- reset() clears all groups")

	var gm: Node = _make_gm()
	_add(gm, "creeps", 1)
	_add(gm, "towers", 2)
	gm.get_ordered("creeps")

	gm.reset()
	_check(gm.get_ordered("creeps") == [], "creeps empty after reset")
	_check(gm.get_ordered("towers") == [], "towers empty after reset")

	gm.free()


func _free_nodes():
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
