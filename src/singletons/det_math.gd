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
