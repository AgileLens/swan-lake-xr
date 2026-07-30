# NOTE: no class_name — main instantiates this via load().new() so it never
# depends on the global script-class cache (which only refreshes on an editor pass).
extends Node
# Per-hand arbitration between held controllers and bare-hand tracking, so the
# conductor's baton, the aim ray and the reticle all come from ONE value
# regardless of how the player is holding (or not holding) anything.
#
# Pattern lifted from Tank Commander VR, where getting this right took several
# rounds — see KB godot-quest-hand-mesh-and-controller-model.md and
# godot-openxr-pose-names-vs-action-names.md. Three lessons carried over:
#
#  1. Check the HAND TRACKER first, and require an UNOBSTRUCTED source. With the
#     controller data source enabled the runtime synthesizes a controller-shaped
#     pose on the same tracker, so has_tracking_data alone cannot distinguish a
#     real controller from a synthesized hand. (We also disable that data source
#     in project.godot, so this is belt and braces.)
#  2. A held controller wins outright. Quest-class devices run hand tracking
#     CONCURRENTLY with controllers, and letting the hand path win hijacked the
#     menu ray there ("pointed up instead of out").
#  3. XRController3D.pose takes ENGINE names ("aim"/"grip"), never action-map
#     names ("aim_pose"). A wrong string silently yields no pose forever while
#     buttons keep working. Bare-hand poses here are computed from joint
#     transforms instead, which sidesteps pose-name strings entirely.

enum Src { NONE, CONTROLLER, HANDS }

const HANDS := ["left", "right"]
const PINCH_ON := 0.7
const PINCH_OFF := 0.45  # hysteresis: a held pinch must not chatter

var main  # SwanLakeMain
var source := {"left": Src.NONE, "right": Src.NONE}
var pinch := {"left": 0.0, "right": 0.0}
var _held := {"left": false, "right": false}
var _edge := {"left": false, "right": false}
# Whether the runtime ever hands us a hand tracker is the one thing we can't
# verify off-device: PICO's AAR declares no hand-tracking permission (Meta's
# equivalent requires com.oculus.permission.HAND_TRACKING), so tracking may simply
# never arrive. Log each transition once so a logcat grab settles it.
var _logged := {"left": "", "right": ""}

func setup(m) -> void:
	main = m

func tracker_path(hand: String) -> String:
	return "/user/hand_tracker/%s" % hand

func hand_tracker(hand: String) -> XRHandTracker:
	return XRServer.get_tracker(tracker_path(hand)) as XRHandTracker

func controller(hand: String) -> XRController3D:
	for c in main.controllers:
		if c.tracker == "%s_hand" % hand:
			return c
	return null

func bare(hand: String) -> bool:
	return source[hand] == Src.HANDS

func source_name(hand: String) -> String:
	match source[hand]:
		Src.CONTROLLER: return "controller"
		Src.HANDS: return "hands"
		_: return "none"

func _real_hands(hand: String) -> bool:
	var t := hand_tracker(hand)
	if t == null or not t.has_tracking_data:
		return false
	# reject a hand pose the runtime synthesized from a controller
	return t.hand_tracking_source == XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED

func _resolve(hand: String) -> void:
	var c := controller(hand)
	# a genuinely tracked controller wins outright (lesson 2)
	if c and c.get_has_tracking_data():
		source[hand] = Src.CONTROLLER
	elif _real_hands(hand):
		source[hand] = Src.HANDS
	else:
		source[hand] = Src.NONE

func _joint(hand: String, j: int) -> Transform3D:
	var t := hand_tracker(hand)
	if t == null:
		return Transform3D()
	# joint transforms are relative to the tracking origin
	return main.origin.global_transform * t.get_hand_joint_transform(j)

# Pose whose -Z points where the hand is pointing: origin at the index tip,
# aimed along the finger. Used for both the visual baton and the aim ray so they
# can never disagree (Tank Commander: a debug visual driven by a different value
# than the real check reads as a hitbox bug even when the logic is fine).
func pose(hand: String) -> Transform3D:
	if source[hand] == Src.CONTROLLER:
		var c := controller(hand)
		if c:
			return c.global_transform
	elif source[hand] == Src.HANDS:
		var tip := _joint(hand, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP)
		var prox := _joint(hand, XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL)
		var fwd: Vector3 = tip.origin - prox.origin
		if fwd.length() > 0.001:
			var up: Vector3 = tip.basis.y
			if absf(fwd.normalized().dot(up.normalized())) > 0.98:
				up = Vector3.UP
			return Transform3D(Basis.looking_at(fwd, up), tip.origin)
	return Transform3D()

func active(hand: String) -> bool:
	return source[hand] != Src.NONE

func pinch_pressed(hand: String) -> bool:
	return _held[hand]

func pinch_just_pressed(hand: String) -> bool:
	return _edge[hand]

func _update_pinch(hand: String) -> void:
	var p := 0.0
	if source[hand] == Src.HANDS:
		var t := hand_tracker(hand)
		if t:
			var a := t.get_hand_joint_transform(XRHandTracker.HAND_JOINT_THUMB_TIP)
			var b := t.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP)
			p = clampf(remap((a.origin - b.origin).length(), 0.075, 0.02, 0.0, 1.0), 0.0, 1.0)
	pinch[hand] = p
	var was: bool = _held[hand]
	if p > PINCH_ON:
		_held[hand] = true
	elif p < PINCH_OFF:
		_held[hand] = false
	_edge[hand] = _held[hand] and not was

func _process(_d: float) -> void:
	if not main.xr_active:
		return
	for hand in HANDS:
		_resolve(hand)
		_update_pinch(hand)
		var s: String = source_name(hand)
		if _logged[hand] != s:
			_logged[hand] = s
			var t := hand_tracker(hand)
			print("[handinput] ", hand, " -> ", s,
				" (tracker=", "yes" if t else "MISSING",
				" data=", t.has_tracking_data if t else false,
				" src=", t.hand_tracking_source if t else -1, ")")
