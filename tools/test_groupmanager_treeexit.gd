extends SceneTree

# Validates GroupManager's reparent-safe lifecycle:
#  1. A registered node that is REPARENTED (leaves+re-enters the
#     tree without being freed) MUST stay in the registry. This
#     is the items/timers bug: tree_exited-based removal wrongly
#     evicted reparented nodes (which never re-register because
#     _ready does not re-run).
#  2. get_ordered() self-heals: a freed node in a per-tick group
#     is pruned (covers creeps/towers/projectiles/manual_timers).
#  3. NOTIFICATION_PREDELETE removal: lookup-only types remove
#     themselves on real deletion (never on reparent), so those
#     groups don't accumulate. Exercised here with a Probe node
#     that mimics the _notification(PREDELETE) -> remove pattern.
#
# NOTE: nodes are created/torn down in _process (not _init),
# because in a SceneTree script the root isn't ready during
# _init and add_child there leaves nodes outside the tree.
#
# Run: godot --headless --path . --script tools/test_groupmanager_treeexit.gd

var _gm: Node
var _failed: bool = false
var _step: int = 0

var _parent_a: Node
var _parent_b: Node
var _timer: Node      # per-tick group node, reparented then freed
var _lookup: Node     # lookup-only node using PREDELETE removal


# Mimics the _notification(NOTIFICATION_PREDELETE) -> GroupManager.remove
# pattern added to Unit/Item/Autocast/ItemContainer.
class PredeleteProbe extends Node:
	var gm: Node
	var uid: int
	func _notification(what: int):
		if what == NOTIFICATION_PREDELETE && gm != null:
			gm.remove("items", uid)


func _init():
	print("=== GroupManager reparent-safe lifecycle validation ===")
	_gm = load("res://src/singletons/group_manager.gd").new()


func _process(_delta: float) -> bool:
	_step += 1

	if _step == 1:
		_parent_a = Node.new()
		_parent_b = Node.new()
		get_root().add_child(_parent_a)
		get_root().add_child(_parent_b)

#		A per-tick-group node (manual_timers) as a child of A.
		_timer = Node.new()
		_parent_a.add_child(_timer)
		_gm.add("manual_timers", _timer, 1)

#		A lookup-only node (items) using PREDELETE removal.
		var probe := PredeleteProbe.new()
		probe.gm = _gm
		probe.uid = 2
		_lookup = probe
		_parent_a.add_child(_lookup)
		_gm.add("items", _lookup, 2)

		_check(_gm.get_ordered("manual_timers").size() == 1, "timer registered")
		_check(_gm.get_by_uid("items", 2) != null, "lookup item registered")
		return false

	if _step == 2:
#		THE KEY CASE: reparent both nodes. They must NOT be evicted.
		_timer.reparent(_parent_b)
		_lookup.reparent(_parent_b)
		return false

	if _step == 3:
		_check(_gm.get_ordered("manual_timers").size() == 1, "timer STILL registered after reparent")
		_check(_gm.get_by_uid("items", 2) != null, "lookup item STILL findable after reparent")

#		Now actually free them.
		_timer.queue_free()       # per-tick: pruned by get_ordered self-heal
		_lookup.queue_free()      # lookup-only: pruned by PREDELETE -> remove
		return false

	if _step < 7:
		return false

	var timers: Array = _gm.get_ordered("manual_timers")
	_check(timers.is_empty(), "timer self-healed after free (got %d)" % timers.size())
	_check(_gm.get_by_uid("items", 2) == null, "lookup item removed via PREDELETE after free")
	_check(_gm._group_map.get("items", {}).is_empty(), "items group did not accumulate (size %d)" % _gm._group_map.get("items", {}).size())

	var all_valid: bool = true
	for n in timers:
		if !is_instance_valid(n):
			all_valid = false
	_check(all_valid, "get_ordered never returns a freed instance")

	if _failed:
		print("=== RESULT: FAIL ===")
	else:
		print("=== RESULT: PASS ===")

	_gm.free()
	return true


func _check(condition: bool, label: String):
	if condition:
		print("  PASS: ", label)
	else:
		_failed = true
		print("  FAIL: ", label)
