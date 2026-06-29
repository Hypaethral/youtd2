extends Node


# Provides lookup for nodes via uid. Note that uid ranges
# can be different for each group.
#
# Also serves as the authoritative, deterministically-ordered
# registry for the per-tick simulation groups (creeps, towers,
# projectiles, manual_timers). get_ordered() returns nodes in
# ascending-UID order without scraping the scene tree or
# re-sorting every tick - the order is cached and only
# recomputed when the group's membership changes. This replaces
# the old "get_nodes_in_group() + sort_custom(get_uid)" hotspot.


# group_name -> { uid -> Node }
var _group_map: Dictionary = {}
# group_name -> bool : true when the cached order is stale
var _group_dirty: Dictionary = {}
# group_name -> Array[int] : cached ascending-uid key order
var _sorted_keys_cache: Dictionary = {}


#########################
###       Public      ###
#########################

func add(group_name: String, node: Node, uid: int):
	node.add_to_group(group_name)

	if !_group_map.has(group_name):
		_group_map[group_name] = {}

	_group_map[group_name][uid] = node
	_group_dirty[group_name] = true

# Remove a node from a group by uid. Idempotent and safe to
# call while the node is being freed (the uid is passed in
# instead of read via get_uid() for exactly this reason).
func remove(group_name: String, uid: int):
	if !_group_map.has(group_name):
		return

	if _group_map[group_name].erase(uid):
		_group_dirty[group_name] = true


func get_by_uid(group_name: String, uid: int) -> Node:
	if !_group_map.has(group_name):
		print_verbose("ERR: get_by_uid no items group for %s" % group_name)
		return null

	if !_group_map[group_name].has(uid):
		print_verbose("ERR: get_by_uid uid=%s not in groupname=%s" % [uid, group_name])
		return null

	var is_valid: bool = is_instance_valid(_group_map[group_name][uid])

	if !is_valid:
		print_verbose("ERR: get_by_uid item uid=%s not valid group" % uid)
		return

	var node: Node = _group_map[group_name][uid]

	if node.is_queued_for_deletion():
		print_verbose("ERR: get_by_uid item uid=%s queued for deletion" % uid)
		return null

	return node


# Returns a freshly allocated array of the group's LIVE nodes in
# canonical ascending-UID order. The array is a snapshot -
# callers may iterate and mutate the group during iteration
# safely.
#
# Nodes that are still valid but pending deletion (queue_free'd this tick)
# are returned -- the caller's is_queued_for_deletion()/is_inside_tree() guard
# handles them
func get_ordered(group_name: String) -> Array:
	if !_group_map.has(group_name):
		return []

	var by_uid: Dictionary = _group_map[group_name]

	if _group_dirty.get(group_name, true):
		var keys: Array = by_uid.keys()
		keys.sort()
		_sorted_keys_cache[group_name] = keys
		_group_dirty[group_name] = false

	var sorted_keys: Array = _sorted_keys_cache[group_name]
	var result: Array = []
	var dead_keys: Array = []

	for key in sorted_keys:
		if (by_uid.get(key) == null):
			dead_keys.append(key)
		else:
			var node: Node = by_uid.get(key)
			if !is_instance_valid(node):
				dead_keys.append(key)
				continue
			result.append(node)

#	Self-heal: drop any entries whose node was freed, so they
#	don't linger, accumulate, or crash the update loop.
	if !dead_keys.is_empty():
		for key in dead_keys:
			by_uid.erase(key)

		_sorted_keys_cache[group_name] = by_uid.keys()
		_sorted_keys_cache[group_name].sort()

	return result


func reset():
	_group_map = {}
	_group_dirty = {}
	_sorted_keys_cache = {}
