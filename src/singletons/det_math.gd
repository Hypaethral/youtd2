class_name DetMath


# Deterministic math primitives for multiplayer lockstep.
# add deterministic transcendental functions (pow/sin/cos/exp/log/...)
# based on integer fixed-point arithmetic and bit-shifts so the result
# is the same on every machine.

# Q.SHIFT fixed-point format used internally. SHIFT=30 keeps
# mantissa values (in [1,2)) below 2^31, so squaring them stays
# within signed 64-bit range (2^62 < 2^63). 30 fractional bits
# is ~9 decimal digits of precision, well below the game's centi
# (0.01) quantization.
const SHIFT: int = 30
const ONE: int = 1 << SHIFT  # 1.0 in Q.SHIFT

# Lazily-built table: _exp2_lut[i] = round(2^(2^-(i+1)) * ONE).
# Built once via deterministic sqrt(), so identical on all
# clients.
static var _exp2_lut: Array[int] = []


# base ^ exponent for INTEGER exponents. Exact, deterministic
# (uses only float multiply/divide). Exponentiation by squaring.
# Handles negative exponents via reciprocal.
static func ipow(base: float, exponent: int) -> float:
	if exponent < 0:
		var positive: float = ipow(base, -exponent)

		if positive == 0.0:
			return 0.0

		return 1.0 / positive

	var result: float = 1.0
	var b: float = base
	var e: int = exponent

	while e > 0:
		if e & 1:
			result *= b

		b *= b
		e >>= 1

	return result


# base ^ exponent for FRACTIONAL exponents, deterministic.
# Computed as exp2(exponent * log2(base)). base must be > 0
# (all simulation call sites pass positive bases).
static func powf(base: float, exponent: float) -> float:
	if base <= 0.0:
#		NOTE: negative/zero base with a fractional exponent is
#		undefined; simulation sites never hit this. Return 0 for
#		base==0, and a safe 0 otherwise rather than NaN.
		return 0.0

	if exponent == 0.0:
		return 1.0

	return _exp2(exponent * _log2(base))


# Integer square root (floor of sqrt) for n >= 0
static func isqrt(n: int) -> int:
	if n < 0:
		return 0

	if n < 2:
		return n

	var x: int = n
	var y: int = (x + 1) >> 1

	while y < x:
		x = y
		y = (x + n / x) >> 1

	return x

# log2(x) for x > 0, via integer fixed-point bit iteration.
static func _log2(x: float) -> float:
#	Normalize x into [1, 2): x = v * 2^e, v in [1,2).
#	Uses only exact *2 / *0.5 doubles, so deterministic.
	var e: int = 0
	var v: float = x

	while v >= 2.0:
		v *= 0.5
		e += 1

	while v < 1.0:
		v *= 2.0
		e -= 1

#	v in [1,2) -> fixed-point mantissa m in [ONE, 2*ONE).
	var m: int = int(v * float(ONE))

	var result_frac: int = 0
	var i: int = 0

	while i < SHIFT:
#		Square the mantissa. m in [ONE, 2*ONE) -> m*m in
#		[ONE^2, 4*ONE^2); shifting back gives [ONE, 4*ONE).
		m = (m * m) >> SHIFT
		result_frac <<= 1

		if m >= (ONE << 1):
#			m >= 2.0: record a 1 bit and renormalize to [1,2).
			m >>= 1
			result_frac |= 1

		i += 1

	return float(e) + float(result_frac) / float(ONE)


# 2^y, via integer fixed-point using the precomputed LUT.
static func _exp2(y: float) -> float:
	_ensure_init()

	var ei: int = floori(y)
	var f: float = y - float(ei)  # fractional part in [0,1)
	var frac_fp: int = int(f * float(ONE))

	var r: int = ONE  # 1.0 in Q.SHIFT, stays in [ONE, 2*ONE)
	var i: int = 0

	while i < SHIFT:
#		Test fractional bit i (MSB-first): the 2^-(i+1) bit.
		if frac_fp & (ONE >> (i + 1)):
			r = (r * _exp2_lut[i]) >> SHIFT

		i += 1

	var mantissa: float = float(r) / float(ONE)  # in [1,2)

	return mantissa * ipow(2.0, ei)


# Build the exp2 LUT once. _exp2_lut[i] = 2^(2^-(i+1)).
# 2^(2^-1)=sqrt(2), 2^(2^-2)=sqrt(sqrt(2))
static func _ensure_init() -> void:
	if !_exp2_lut.is_empty():
		return

	var lut: Array[int] = []
	var cur: float = sqrt(2.0)

	var i: int = 0
	while i < SHIFT:
		lut.append(int(round(cur * float(ONE))))
		cur = sqrt(cur)
		i += 1

	_exp2_lut = lut


#########################
###  Trigonometry     ###
#########################

# Deterministic sin/cos/atan2 via integer fixed-point CORDIC.
#
# Godot's sin()/cos()/atan2() (and the Vector2 helpers built on
# them: rotated(), angle(), angle_to(), from_angle()) are NOT
# bit-identical across platforms - the C standard places no
# accuracy bound on transcendentals, so libm/SIMD/x87 differ
# between machines. Any simulation code that feeds their output
# back into game state (notably homing-projectile movement, which
# re-runs trig every tick) will desync host vs clients.
#
# CORDIC uses only integer adds, arithmetic shifts and a hardcoded
# table of arctangents, so it is exact-reproducible on every
# machine. The constants below are precomputed in Q.SHIFT (the
# atan table is baked as literals rather than built from atan() at
# runtime, since atan() itself is non-deterministic). Accuracy is
# ~1e-8 rad, far below the game's centi (0.01) quantization.

const PI_FP: int = 3373259426       # pi in Q.SHIFT
const TWO_PI_FP: int = 6746518852   # 2*pi in Q.SHIFT
const HALF_PI_FP: int = 1686629713  # pi/2 in Q.SHIFT

# CORDIC gain-corrected initial x: prod(1/sqrt(1+2^-2i)) in Q.SHIFT.
const CORDIC_K_FP: int = 652032874

# _ATAN_FP[i] = atan(2^-i) in Q.SHIFT, for i in [0, SHIFT).
const _ATAN_FP: Array[int] = [
	843314857, 497837829, 263043837, 133525159, 67021687,
	33543516, 16775851, 8388437, 4194283, 2097149,
	1048576, 524288, 262144, 131072, 65536,
	32768, 16384, 8192, 4096, 2048,
	1024, 512, 256, 128, 64,
	32, 16, 8, 4, 2,
]


# Returns Vector2(cos(rad), sin(rad)) - both at once, since one
# CORDIC pass produces them together. Drop-in for
# Vector2.from_angle(rad).
static func sincos(rad: float) -> Vector2:
#	Convert to fixed-point and range-reduce to [-pi, pi]. Inputs
#	are bounded (angles derived from normalized directions /
#	atan2 outputs), so this loops at most a couple of times.
	var z: int = roundi(rad * float(ONE))

	while z > PI_FP:
		z -= TWO_PI_FP
	while z < -PI_FP:
		z += TWO_PI_FP

#	Reduce to [-pi/2, pi/2] (CORDIC convergence range). cos is
#	odd about +-pi/2 so its sign flips; sin stays correct.
	var cos_sign: int = 1
	if z > HALF_PI_FP:
		z = PI_FP - z
		cos_sign = -1
	elif z < -HALF_PI_FP:
		z = -PI_FP - z
		cos_sign = -1

	var x: int = CORDIC_K_FP
	var y: int = 0

	var i: int = 0
	while i < SHIFT:
		var dx: int = x >> i
		var dy: int = y >> i

		if z >= 0:
			x -= dy
			y += dx
			z -= _ATAN_FP[i]
		else:
			x += dy
			y -= dx
			z += _ATAN_FP[i]

		i += 1

	return Vector2(float(cos_sign * x) / float(ONE), float(y) / float(ONE))


static func sin(rad: float) -> float:
	return sincos(rad).y


static func cos(rad: float) -> float:
	return sincos(rad).x


# Deterministic atan2(y, x), result in radians in (-pi, pi].
# Drop-in for Vector2(x, y).angle().
static func atan2(y: float, x: float) -> float:
	var xfp: int = roundi(x * float(ONE))
	var yfp: int = roundi(y * float(ONE))

	if xfp == 0 && yfp == 0:
		return 0.0

#	CORDIC vectoring in the first quadrant on |x|, |y|: rotate the
#	vector onto the +x axis, accumulating the angle in z. This
#	yields atan(|y|/|x|) in [0, pi/2]; map back via the signs.
	var vx: int = absi(xfp)
	var vy: int = absi(yfp)
	var z: int = 0

	var i: int = 0
	while i < SHIFT:
		var dx: int = vx >> i
		var dy: int = vy >> i

		if vy > 0:
			vx += dy
			vy -= dx
			z += _ATAN_FP[i]
		else:
			vx -= dy
			vy += dx
			z -= _ATAN_FP[i]

		i += 1

	var base: float = float(z) / float(ONE)

	if xfp >= 0:
		if yfp >= 0:
			return base
		else:
			return -base
	else:
		var pi: float = float(PI_FP) / float(ONE)
		if yfp >= 0:
			return pi - base
		else:
			return -(pi - base)


# Deterministic Vector2.rotated(rad).
static func rotated(v: Vector2, rad: float) -> Vector2:
	var cs: Vector2 = sincos(rad)
	var c: float = cs.x
	var s: float = cs.y

	return Vector2(v.x * c - v.y * s, v.x * s + v.y * c)


# Deterministic Vector2.from_angle(rad).
static func from_angle(rad: float) -> Vector2:
	return sincos(rad)


# Deterministic Vector2(v).angle() == atan2(v.y, v.x).
static func vector_angle(v: Vector2) -> float:
	return atan2(v.y, v.x)


# Deterministic a.angle_to(b): signed angle from a to b, in
# (-pi, pi]. Built from cross/dot (exact float mul/add) + atan2.
static func angle_between(a: Vector2, b: Vector2) -> float:
	var cross: float = a.x * b.y - a.y * b.x
	var dot: float = a.x * b.x + a.y * b.y

	return atan2(cross, dot)
