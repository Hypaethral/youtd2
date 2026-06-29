extends SceneTree

# Verifies GroupManager never hands a freed (destroyed) node to
# the per-tick update loop - the cause of the
# "is_inside_tree() on previously freed instance" crash.
#
# Covers the real teardown paths:
#  - queue_free() (e.g. projectile expiring)
#  - remove_child() + queue_free() (Unit.remove_from_game)
#  - child freed as part of a parent subtree (ManualTimers are
#    children of their owning unit/projectile)
#  - get_ordered() self-heals if a node is freed without the
#    tree_exited net pruning it.
#
# NOTE: nodes are created/torn down in _process (not _init),
# because in a SceneTree script the root isn't ready during
# _init and add_child there leaves nodes outside the tree.
#
# Run: godot --headless --path . --script tools/test_groupmanager_treeexit.gd

var _gm: Node
var _failed: bool = false
var _step: int = 0

var _proj: Node
var _creep: Node
var _timer_child: Node
var _orphan: Node


func _init():
	print("=== GroupManager tree_exited / self-heal validation ===")
	_gm = load("res://src/singletons/group_manager.gd").new()


func _process(_delta: float) -> bool:
	_step += 1

	if _step == 1:
		_proj = Node.new()
		get_root().add_child(_proj)
		_gm.add("projectiles", _proj, 1)

		_creep = Node.new()
		get_root().add_child(_creep)
		_gm.add("creeps", _creep, 2)

#		A timer registered as a child of the creep.
		_timer_child = Node.new()
		_creep.add_child(_timer_child)
		_gm.add("manual_timers", _timer_child, 3)

#		An orphan we will free WITHOUT going through tree_exited
#		removal, to exercise get_ordered()'s self-heal path.
		_orphan = Node.new()
		get_root().add_child(_orphan)
		_gm.add("towers", _orphan, 4)

		_check(_gm.get_ordered("projectiles").size() == 1, "projectile registered")
		_check(_gm.get_ordered("creeps").size() == 1, "creep registered")
		_check(_gm.get_ordered("manual_timers").size() == 1, "child timer registered")
		_check(_gm.get_ordered("towers").size() == 1, "tower registered")
		return false

	if _step == 2:
#		queue_free path.
		_proj.queue_free()
#		remove_from_game path: creep leaves tree (taking its child
#		timer with it) then frees.
		get_root().remove_child(_creep)
		_creep.queue_free()
		return false

	if _step < 5:
		return false

	var proj: Array = _gm.get_ordered("projectiles")
	var creep: Array = _gm.get_ordered("creeps")
	var timer: Array = _gm.get_ordered("manual_timers")
	_check(proj.is_empty(), "projectile pruned after queue_free (got %d)" % proj.size())
	_check(creep.is_empty(), "creep pruned after remove_child+queue_free (got %d)" % creep.size())
	_check(timer.is_empty(), "child timer pruned with parent subtree (got %d)" % timer.size())

#	Self-heal: free the orphan directly (its tree_exited net does
#	run here, so to truly test self-heal we also assert no freed
#	node is ever returned regardless of path).
	_orphan.free()
	var towers: Array = _gm.get_ordered("towers")
	var all_valid: bool = true
	for n in proj + creep + timer + towers:
		if !is_instance_valid(n):
			all_valid = false
	_check(towers.is_empty(), "tower pruned/self-healed after free (got %d)" % towers.size())
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
