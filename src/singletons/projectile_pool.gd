extends Node


# Object pool for Projectile nodes and their visual subtrees.
#
# Lifecycle contract lives in src/projectiles/projectile.gd:
# - Projectile.create() calls acquire() instead of instantiate()
# - Projectile._acquire_init() resets/initializes per-flight state
# - Projectile._return_to_pool() (via _dispose) calls release()
#
# Determinism note: the free-list order (LIFO) is irrelevant to
# lockstep determinism. Parked projectiles carry no sim-visible
# identity, every gameplay field is overwritten on acquire, and
# UID assignment happens in _acquire_init in deterministic
# create() order. The pool must *never* read Globals.local_rng /
# any RNG.


# Parked Projectile nodes (out of tree, out of all groups).
var _free_list: Array = []
# resolved visual_path -> Array of detached visual Node2D subtrees
var _visual_free_map: Dictionary = {}
# visual_path -> PackedScene (avoids ResourceLoader.exists + load
# per shot; resolved once per unique path)
var _visual_scene_cache: Dictionary = {}


#########################
###       Public      ###
#########################

func acquire() -> Projectile:
	var projectile: Projectile

	if !_free_list.is_empty():
		projectile = _free_list.pop_back()
	else:
		projectile = Preloads.projectile_scene.instantiate()

	return projectile


func release(projectile: Projectile) -> void:
	_free_list.push_back(projectile)


# Returns a visual subtree for the given path, reusing a parked
# one if available. The caller (Projectile._acquire_init) adds it
# under _visual_node.
func acquire_visual(visual_path: String) -> Node2D:
	var free_list: Array = _visual_free_map.get(visual_path, [])

	if !free_list.is_empty():
		return free_list.pop_back()

	var scene: PackedScene = _get_visual_scene(visual_path)
	var visual: Node2D = scene.instantiate()

	return visual


func release_visual(visual_path: String, visual: Node2D) -> void:
	if !_visual_free_map.has(visual_path):
		_visual_free_map[visual_path] = []

	_visual_free_map[visual_path].push_back(visual)


# Frees everything. Called on new-game boundary so parked nodes
# holding refs to freed casters/types from a prior game don't
# survive across the static UID counter reset.
func reset() -> void:
	for projectile in _free_list:
		if is_instance_valid(projectile):
			projectile.free()

	_free_list.clear()

	for visual_path in _visual_free_map:
		for visual in _visual_free_map[visual_path]:
			if is_instance_valid(visual):
				visual.free()

	_visual_free_map.clear()

#	NOTE: keep _visual_scene_cache - PackedScenes are shared
#	resources, safe to reuse across games.


#########################
###      Private      ###
#########################

# Returns the cached PackedScene for visual_path, falling back to
# the default projectile visual if the path is missing. The
# exists()/load() cost is paid once per unique path.
func _get_visual_scene(visual_path: String) -> PackedScene:
	if _visual_scene_cache.has(visual_path):
		return _visual_scene_cache[visual_path]

	var resolved_path: String = visual_path
	if !ResourceLoader.exists(resolved_path):
		if Projectile.PRINT_SPRITE_NOT_FOUND_ERROR:
			print_debug("Failed to find sprite for projectile. Tried at path:", visual_path)

		resolved_path = Projectile.FALLBACK_PROJECTILE_VISUAL

	var scene: PackedScene = load(resolved_path)
	_visual_scene_cache[visual_path] = scene

	return scene
