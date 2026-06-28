extends MainLoop
# Validates DetMath against libm and prints golden values.
#
# Run:  godot --headless --script tools/test_det_math.gd
#
# Two things to check:
#   1. ACCURACY  - DetMath.* must be close to libm over the
#      input ranges actually used in the simulation (printed as
#      max relative error). Balance tolerance: well under the
#      game's centi (0.01) quantization.
#   2. DETERMINISM - the "GOLDEN" block prints exact values.
#      Run this on x86 and on Apple-ARM and diff the output;
#      the GOLDEN lines must be byte-identical.

var DetMath = load("res://src/singletons/det_math.gd")

func _initialize():
	print("=== DetMath validation ===")
	_test_ipow()
	_test_powf()
	_test_isqrt()
	_test_trig()
	_print_golden()
	print("=== done ===")

func _process(_delta: float) -> bool:
	return true  # end main loop

func _test_ipow():
	var max_rel: float = 0.0

	for base_i in range(1, 400):
		var base: float = base_i / 100.0  # 0.01 .. 3.99
		for e in range(0, 8):
			var got: float = DetMath.ipow(base, e)
			var ref: float = pow(base, e)
			max_rel = max(max_rel, _rel_err(got, ref))

	# negative exponents (e.g. plagued_crypt 1.1^-level)
	for level in range(0, 25):
		var got: float = DetMath.ipow(1.1, -level)
		var ref: float = pow(1.1, -level)
		max_rel = max(max_rel, _rel_err(got, ref))

	print("ipow   max relative error vs libm: %s" % max_rel)


func _test_powf():
	var max_rel: float = 0.0
	var samples: Array = [
		# [base, exponent] pairs from the converted sites
		[1.7, 0.66], [3.0, 0.66], [10.0, 0.66],    # unit.gd:1217
		[1.0, 1.6], [1.6, 1.6],                    # unit.gd:1219
		[3.0, -1.0], [3.0, 0.0], [3.0, 1.0],       # unit.gd:1723 base 3
		[1.0001, 50.0], [1.0001, 500.0],           # wave.gd:280
		[200.0, 0.6], [800.0, 0.6], [1500.0, 0.6], # wand_of_mana_zap
	]

	for pair in samples:
		var got: float = DetMath.powf(pair[0], pair[1])
		var ref: float = pow(pair[0], pair[1])
		var rel: float = _rel_err(got, ref)
		max_rel = max(max_rel, rel)
		print("  powf(%s, %s) = %s   libm=%s   rel=%s" % [pair[0], pair[1], got, ref, rel])

	# dense sweep over base for the 0.66 exponent
	for b_i in range(1, 2000):
		var base: float = b_i / 100.0
		max_rel = max(max_rel, _rel_err(DetMath.powf(base, 0.66), pow(base, 0.66)))

	print("powf   max relative error vs libm: %s" % max_rel)


func _test_isqrt():
	var bad: int = 0

	for n in range(0, 100000):
		var r: int = DetMath.isqrt(n)
		if r * r > n or (r + 1) * (r + 1) <= n:
			bad += 1

	print("isqrt  incorrect results in [0,100000): %d" % bad)


func _test_trig():
	var max_sin: float = 0.0
	var max_cos: float = 0.0

#	Sweep the full [-2pi, 2pi] range (projectile directions come
#	from deg_to_rad of angles normalized to [-360, 360]).
	for i in range(-6283, 6284):
		var rad: float = i / 1000.0
		max_sin = max(max_sin, absf(DetMath.sin(rad) - sin(rad)))
		max_cos = max(max_cos, absf(DetMath.cos(rad) - cos(rad)))

	print("sin    max abs error vs libm: %s" % max_sin)
	print("cos    max abs error vs libm: %s" % max_cos)

	var max_atan: float = 0.0

	for yi in range(-50, 51):
		for xi in range(-50, 51):
			var y: float = yi * 20.0
			var x: float = xi * 20.0
			if x == 0.0 and y == 0.0:
				continue
			var got: float = DetMath.atan2(y, x)
			var ref: float = atan2(y, x)
#			Compare as a wrapped difference so +-pi doesn't read
#			as a huge error.
			var d: float = fmod(got - ref + PI + TAU, TAU) - PI
			max_atan = max(max_atan, absf(d))

	print("atan2  max abs error vs libm: %s" % max_atan)


# Golden reference values, captured on ARM (Godot 4.3)
# TODO: consider making this a realtime check that gates multiplayer connections (or prints a warning)
func _golden_cases() -> Array:
	return [
		["powf(1.7,0.66)",     DetMath.powf(1.7, 0.66),     0x3FF6B5BF98C00000],
		["powf(3.0,-1.0)",     DetMath.powf(3.0, -1.0),     0x3FD5555553000000],
		["powf(1.0001,500.0)", DetMath.powf(1.0001, 500.0), 0x3FF0D1FE5D000000],
		["powf(800.0,0.6)",    DetMath.powf(800.0, 0.6),    0x404B983741000000],
		["ipow(0.97,5)",       DetMath.ipow(0.97, 5),       0x3FEB7ABFC78B016B],
		["ipow(1.1,-10)",      DetMath.ipow(1.1, -10),      0x3FD8ACBDC2D2B1C5],
		["sin(0.7)",           DetMath.sin(0.7),            0x3FE49D6E60000000],
		["cos(0.7)",           DetMath.cos(0.7),            0x3FE8799660000000],
		["sin(2.5)",           DetMath.sin(2.5),            0x3FE326AF00000000],
		["cos(-3.0)",          DetMath.cos(-3.0),           -0x401051FB40000000],
		["atan2(3,4)",         DetMath.atan2(3.0, 4.0),     0x3FE4978FA3800000],
		["atan2(-5,-2)",       DetMath.atan2(-5.0, -2.0),   -0x4000C776D0C00000],
	]


# Raw 64-bit IEEE-754 representation of a double, as an int.
func _float_bits(v: float) -> int:
	return PackedFloat64Array([v]).to_byte_array().decode_u64(0)


func _print_golden():
	print("--- GOLDEN (exact cross-architecture check) ---")

	var failures: int = 0

	for case in _golden_cases():
		var label: String = case[0]
		var got: float = case[1]
		var want_bits: int = case[2]
		var got_bits: int = _float_bits(got)
		var ok: bool = got_bits == want_bits

		if !ok:
			failures += 1

		print("GOLDEN %s %s=%.17f  bits=0x%016X  want=0x%016X" % [
			"PASS" if ok else "FAIL", label, got, got_bits, want_bits])

	if failures == 0:
		print("GOLDEN: all %d values match reference (deterministic)" % _golden_cases().size())
	else:
		print("GOLDEN: %d value(s) DIVERGED from reference -- determinism broken!" % failures)


func _rel_err(got: float, ref: float) -> float:
	if ref == 0.0:
		return absf(got)

	return absf(got - ref) / absf(ref)
