class_name ConductLogic
extends RefCounted
# The conducting judgment, kept free of any scene so tests can run it directly.
#
# The rule that shapes every number below: nothing a person does can lower their result, and
# doing nothing still earns the bow. Off-beat gestures just don't add. Scores are built only
# from things that accumulate, so wild flailing can't cost a beginner anything.

const GRADE_FLOOR := 0.22
const ON_BEAT := 0.24         # within this fraction of a beat counts as on the beat
const ICTUS_MIN_GAP := 0.22
const ICTUS_MIN_SPEED := 0.22 # m/s of downward motion before a turnaround counts as a beat

# Finds the ictus: the bottom of a downward stroke, where a conductor's beat actually lands.
class IctusDetector:
	var _vy := 0.0
	var _last_y := INF
	var _last_t := -100.0
	var _peak_down := 0.0

	func feed(t: float, y: float, dt: float) -> float:
		if _last_y == INF or dt <= 0.0:
			_last_y = y
			return 0.0
		var v := (y - _last_y) / dt
		_last_y = y
		_vy = lerpf(_vy, v, clampf(dt * 22.0, 0.0, 1.0))
		_peak_down = maxf(_peak_down, -_vy)
		if _vy > -0.02 and _peak_down > ICTUS_MIN_SPEED and t - _last_t > ICTUS_MIN_GAP:
			var strength := _peak_down
			_peak_down = 0.0
			_last_t = t
			return strength
		if _vy > 0.1:
			_peak_down = 0.0
		return 0.0

# Rolling size of the gesture, in meters, for matching big gestures to loud passages.
class GestureSize:
	var _samples: Array[Vector3] = []
	var _cursor := 0

	func feed(p: Vector3) -> void:
		if _samples.size() < 45:
			_samples.append(p)
		else:
			_samples[_cursor] = p
			_cursor = (_cursor + 1) % _samples.size()

	func size() -> float:
		if _samples.size() < 4:
			return 0.0
		var lo := _samples[0]
		var hi := _samples[0]
		for s in _samples:
			lo = lo.min(s)
			hi = hi.max(s)
		return (hi - lo).length()

# One movement's account.
class MovementScore:
	var duration := 1.0
	var active_time := 0.0
	var beats_on := 0.0
	var expressive_time := 0.0
	var verb := 0.0        # 0..1 progress on this movement's special gesture
	var beat_goal := 40.0

	func _init(dur := 60.0) -> void:
		duration = maxf(dur, 1.0)
		beat_goal = clampf(dur * 0.32, 10.0, 60.0)

	func add_active(dt: float) -> void:
		active_time += dt

	func add_beat(on_beat: bool) -> void:
		if on_beat:
			beats_on += 1.0

	func add_expressive(dt: float) -> void:
		expressive_time += dt

	func add_verb(amount: float) -> void:
		verb = minf(verb + amount, 1.0)

	func grade() -> float:
		var engage := clampf(active_time / (duration * 0.45), 0.0, 1.0)
		var timing := clampf(beats_on / beat_goal, 0.0, 1.0)
		var express := clampf(expressive_time / (duration * 0.3), 0.0, 1.0)
		return clampf(GRADE_FLOOR + 0.30 * verb + 0.20 * timing + 0.14 * express + 0.14 * engage, GRADE_FLOOR, 1.0)

# Does this gesture size suit this moment of the music? Quiet music wants a small hand.
static func expressive_match(gesture_m: float, env: float) -> bool:
	var want := lerpf(0.10, 0.65, clampf(env, 0.0, 1.0))
	return gesture_m > 0.04 and gesture_m > want * 0.45 and gesture_m < want * 2.6

static func is_on_beat(error: float) -> bool:
	return error <= ON_BEAT

# How the flock answers at the curtain. Every tier includes the bow.
const TIERS := [
	{"name": "A quiet night on the lake", "line": "The flock bows. The lake played beautifully for you.", "salute": 0.0, "barrage": 4},
	{"name": "Warm applause", "line": "They watched your hand. The flock bows, wings lifted.", "salute": 0.5, "barrage": 7},
	{"name": "Bravo", "line": "The whole corps rose for you. Bravo, maestro.", "salute": 0.8, "barrage": 10},
	{"name": "Standing ovation", "line": "Every wing on the lake is raised. Encore!", "salute": 1.0, "barrage": 14},
]

static func tier_for(grace: float) -> int:
	if grace >= 0.74:
		return 3
	if grace >= 0.56:
		return 2
	if grace >= 0.38:
		return 1
	return 0

static func overall(grades: Array) -> float:
	if grades.is_empty():
		return GRADE_FLOOR
	var s := 0.0
	for g in grades:
		s += float(g)
	return s / float(grades.size())
