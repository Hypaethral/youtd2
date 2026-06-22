extends MainLoop


# Scans simulation scripts for transcendental function calls
# that are NOT guaranteed bit-identical across CPU architectures
# (pow/sin/cos/tan/exp/log/atan/atan2/.angle). These cause
# multiplayer desyncs between mixed native clients (x86 vs
# Apple-ARM). Use DetMath (src/singletons/det_math.gd) instead,
# or sqrt() (which IS correctly-rounded / deterministic).
#
# Run:  godot --headless --script tools/check_determinism.gd
#
# `pow/exp/log` should report ZERO hits in non-allowlisted files
# (they have been converted). Remaining `sin/cos/atan/.angle`
# hits are the geometry backlog (Tier-2): each must be triaged
# as simulation (convert to DetMath) vs visual (add to the
# allowlist).


const SCAN_ROOT: String = "src"

# Visual-only files/dirs, plus the deterministic math module
# itself. Transcendental calls here are allowed.
const ALLOWLIST_PREFIXES: Array = [
	"src/ui/",
	"src/effects/",
	"src/singletons/det_math.gd",
	"src/singletons/properties/tower_properties.gd",  # missile z-arc height (visual)
	"src/game_scene/camera_controller.gd",
]

# (regex, label). \b avoids matching ipow(/powf(/log_ability(.
const PATTERNS: Array = [
	["\\bpow\\(", "pow"],
	["\\bexp\\(", "exp"],
	["\\blog\\(", "log"],
	["\\bsin\\(", "sin"],
	["\\bcos\\(", "cos"],
	["\\btan\\(", "tan"],
	["\\batan2\\(", "atan2"],
	["\\batan\\(", "atan"],
	["\\.angle\\(", ".angle"],
	["\\.angle_to\\(", ".angle_to"],
	["\\.angle_to_point\\(", ".angle_to_point"],
]


var _regexes: Array = []
var _hit_count: int = 0


func _initialize():
	print("=== determinism lint ===")

	for entry in PATTERNS:
		var re: RegEx = RegEx.new()
		re.compile(entry[0])
		_regexes.append([re, entry[1]])

	_process_dir(SCAN_ROOT)

	print("=== %d transcendental call(s) in non-allowlisted files ===" % _hit_count)


func _process(_delta: float) -> bool:
	return true


func _process_dir(dir_path: String):
	for filename in DirAccess.get_files_at(dir_path):
		_process_file("%s/%s" % [dir_path, filename])

	for child_dir in DirAccess.get_directories_at(dir_path):
		_process_dir("%s/%s" % [dir_path, child_dir])


func _process_file(file_path: String):
	if !file_path.ends_with(".gd"):
		return

	for prefix in ALLOWLIST_PREFIXES:
		if file_path.begins_with(prefix):
			return

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return

	var line_number: int = 0

	while !file.eof_reached():
		var line: String = file.get_line()
		line_number += 1

#		Skip full-line comments so prose mentioning pow()/sin()
#		etc. is not flagged. Inline trailing comments are rare
#		and still correctly match the code portion of the line.
		if line.strip_edges().begins_with("#"):
			continue

		for entry in _regexes:
			var re: RegEx = entry[0]
			if re.search(line) != null:
				_hit_count += 1
				print("%s:%d  [%s]  %s" % [file_path, line_number, entry[1], line.strip_edges()])
