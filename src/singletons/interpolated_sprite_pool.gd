extends Node


# Object pool for the AnimatedSprite2D visual subtrees used by
# InterpolatedSprite (lightning-style effects drawn between units
# or points).
#
# Lifecycle contract lives in src/effects/interpolated_sprite.gd:
# - InterpolatedSprite._ready() calls acquire_visual() instead of
#   load()/instantiate()
# - InterpolatedSprite.dispose() (and the lifetime-timer timeout)
#   calls release_visual() before freeing the node
#
# NOTE: unlike ProjectilePool this pool intentionally does NOT pool
# the owning node or its ManualTimer. The InterpolatedSprite node is
# a bare Node2D (cheap), while ManualTimer draws from a shared static
# UID counter and registers in the sim-ticked "manual_timers" group.
# Keeping timer create/free exactly as before leaves the deterministic
# timer UID stream byte-identical - the pool only recycles the
# expensive scene instantiate.
#
# Determinism note: parked visuals are plain AnimatedSprite2D nodes
# with no sim-visible identity - no UID, not in any sim group, no unit
# references. The free-list order is irrelevant to lockstep and the
# pool must never read Globals.local_rng / any RNG.


# resolved sprite_scene_path -> Array of detached AnimatedSprite2D
var _visual_free_map: Dictionary = {}
# sprite_scene_path -> PackedScene (avoids the repeated ResourceLoader
# reparse; the scene ref was previously not retained, so every spawn
# re-read it from disk)
var _scene_cache: Dictionary = {}
# sprite_scene_path -> float (sprite width is scene-stable, computed once)
var _width_cache: Dictionary = {}


#########################
###       Public      ###
#########################

# Returns an AnimatedSprite2D for the given scene path, reusing a
# parked one if available. Returns null (after pushing an error) if
# the scene is not an AnimatedSprite2D. The caller adds it as a child.
func acquire_visual(sprite_scene_path: String) -> AnimatedSprite2D:
	var free_list: Array = _visual_free_map.get(sprite_scene_path, [])

	if !free_list.is_empty():
		return free_list.pop_back()

	var scene: PackedScene = _get_scene(sprite_scene_path)
	var instance: Node = scene.instantiate()

	if !instance is AnimatedSprite2D:
		push_error("InterpolatedSprite must receive a scene for AnimatedSprite2D type. Invalid scene: ", sprite_scene_path)
		instance.free()

		return null

	return instance as AnimatedSprite2D


func release_visual(sprite_scene_path: String, visual: AnimatedSprite2D) -> void:
	if !_visual_free_map.has(sprite_scene_path):
		_visual_free_map[sprite_scene_path] = []

	_visual_free_map[sprite_scene_path].push_back(visual)


# Returns the scene-stable sprite width (first frame texture width),
# computing it once per path. Matches the previous InterpolatedSprite
# ._get_sprite_width() behaviour, including the 0 fallbacks.
func get_sprite_width(sprite_scene_path: String, visual: AnimatedSprite2D) -> float:
	if _width_cache.has(sprite_scene_path):
		return _width_cache[sprite_scene_path]

	var width: float = _compute_sprite_width(visual)
	_width_cache[sprite_scene_path] = width

	return width


# Frees parked visuals on the new-game boundary so leftover nodes from
# a prior game don't accumulate. Keeps _scene_cache / _width_cache -
# PackedScenes and widths are shared, path-stable resources.
func reset() -> void:
	for sprite_scene_path in _visual_free_map:
		for visual in _visual_free_map[sprite_scene_path]:
			if is_instance_valid(visual):
				visual.free()

	_visual_free_map.clear()


#########################
###      Private      ###
#########################

func _get_scene(sprite_scene_path: String) -> PackedScene:
	if _scene_cache.has(sprite_scene_path):
		return _scene_cache[sprite_scene_path]

	var scene: PackedScene = load(sprite_scene_path)
	_scene_cache[sprite_scene_path] = scene

	return scene


func _compute_sprite_width(visual: AnimatedSprite2D) -> float:
	var sprite_frames: SpriteFrames = visual.sprite_frames
	var animation_list: Array = sprite_frames.get_animation_names()

	if animation_list.is_empty():
		return 0

	var animation: String = animation_list[0]
	var frame_count: int = sprite_frames.get_frame_count(animation)

	if frame_count == 0:
		return 0

	var texture: Texture2D = sprite_frames.get_frame_texture(animation, 0)
	var texture_width: float = texture.get_size().x

	return texture_width
