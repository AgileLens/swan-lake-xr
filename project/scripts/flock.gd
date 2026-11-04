class_name SwanFlock
extends Node3D
# Owns the swans + cygnet, roam-anchor drift, gather choreography, flyby scheduling.

const STYLES := ["res://assets/swan/swan_hero.glb", "res://assets/swan_style0.glb"]
# The modeled bird is the default. Origami stays as a playful alternate on the orbs. The
# metaball tiers are gone from the picker: those were the "balloon animals".
const STYLE_NAMES := ["swan", "origami"]

var main  # SwanLakeMain (untyped: avoids cyclic class_name resolution)
var style_idx := 0
var swans: Array[Swan] = []
var roam_anchor := Vector3(0, 0, -9)
var attract_active := false
var attract_point := Vector3.ZERO
var gather_on := false
var t := 0.0
var flyby_timer := 250.0

# ---------------------------------------------------------------- the choreography
# Named formations the program calls by movement. Each one writes per-swan slots and
# pose targets every frame, and the swan's own steering does the swimming.
var formation := "free"
var lead_point := Vector3(0, 0, -7)
var warmth := 0.3
var _trail: Array[Vector3] = []
var _trail_t := 0.0
var _wake_order := 0
var _flourish_t := 0.0
var _salute := 0.0
var _bow_wave_t := -1.0
var snap := false  # stills only: land everyone on their marks, so a shot doesn't wait on swimming

func spawn(count: int) -> void:
	var scene: PackedScene = load(STYLES[style_idx])
	for i in count:
		var s := Swan.new()
		var model: Node3D = scene.instantiate()
		add_child(s)
		s.setup(main, self, model, float(i) * 1.618)
		var a := TAU * float(i) / count
		s.global_position = main.LAKE_CENTER + Vector3(cos(a) * randf_range(3, 7), 0, sin(a) * randf_range(3, 7))
		# Real flocks vary. The prima is the largest, and nobody is a copy of anyone else.
		s.scale = Vector3.ONE * (1.10 if i == 0 else randf_range(0.92, 1.03))
		swans.append(s)

func spawn_cygnet(at: Vector3) -> void:
	var scene: PackedScene = load(STYLES[style_idx])
	var s := Swan.new()
	var model: Node3D = scene.instantiate()
	_tint_gray(model)
	add_child(s)
	s.setup(main, self, model, 9.9)
	s.is_cygnet = true
	s.scale = Vector3.ONE * 0.42
	s.global_position = at
	s.follow_target = swans[0]
	swans.append(s)

func _tint_gray(node: Node) -> void:
	for ch in node.get_children():
		_tint_gray(ch)
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			return
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				var m2: StandardMaterial3D = m.duplicate()
				m2.albedo_color = m2.albedo_color * Color(0.80, 0.82, 0.85, 1.0)
				mi.set_surface_override_material(i, m2)

func set_gather(on: bool, point: Vector3) -> void:
	gather_on = on
	if not on and formation != "free":
		set_formation(formation)
		return
	if on:
		var n := 0
		for s in swans:
			if not s.flying and not s.is_cygnet:
				n += 1
		var user: Vector3 = main.user_position()
		var to_user: Vector3 = (user - point)
		to_user.y = 0
		var base_ang: float = atan2(to_user.x, to_user.z)
		var k := 0
		for s in swans:
			if s.flying or s.is_cygnet:
				continue
			var frac := float(k) / maxf(n - 1, 1)
			var ang := base_ang + (frac - 0.5) * TAU * 0.78
			var rad := 2.2 if k > 0 else 1.2
			s.gather_slot = point + Vector3(sin(ang) * rad, 0, cos(ang) * rad)
			s.want_bow = true
			s.face_point = user
			s.trigger_flap()
			k += 1
	else:
		for s in swans:
			s.gather_slot = Vector3.INF
			s.arrived = false

func style_name() -> String:
	return STYLE_NAMES[style_idx]

func cycle_style() -> void:
	style_idx = (style_idx + 1) % STYLES.size()
	var scene: PackedScene = load(STYLES[style_idx])
	for s in swans:
		var model: Node3D = scene.instantiate()
		if s.is_cygnet:
			_tint_gray(model)
		s.swap_model(model)

func request_flyby() -> void:
	for s in swans:
		if not s.flying and not s.is_cygnet and s.gather_slot == Vector3.INF:
			s.start_flyby()
			return

func set_formation(name: String) -> void:
	formation = name
	_trail.clear()
	for s in swans:
		s.tgt_heart = 0.0
		s.tgt_tall = 0.0
		s.tgt_wing = 0.0
		s.want_bow = false
		s.gather_slot = Vector3.INF
		s.arrived = false
		if name != "sleep":
			s.tgt_sleep = 0.0

func put_to_sleep() -> void:
	# Prelude: the whole flock is asleep near the dock, heads back, drifting.
	_wake_order = 0
	formation = "sleep"
	var i := 0
	for s in swans:
		if s.is_cygnet:
			continue
		var a := -1.2 + 2.4 * float(i) / maxf(float(swans.size() - 1), 1.0)
		var r := 4.0 + 2.6 * fposmod(float(i) * 0.618, 1.0)
		var p: Vector3 = Vector3(sin(a) * r, 0, -1.2 - cos(a) * r)
		s.global_position = p
		s.heading = randf() * TAU
		s.tgt_sleep = 1.0
		s.pose_sleep = 1.0
		s.dance_gain = 0.0
		i += 1

func wake_next() -> void:
	var i := 0
	for s in swans:
		if s.is_cygnet:
			continue
		if i == _wake_order:
			s.tgt_sleep = 0.0
			s.tgt_tall = 0.0
			s.dance_gain = 1.0
			s.stretch(2.8)
			main.ripples.add(s.global_position, 0.10)
			main.audio.harp(s.global_position, i, -13.0)
			break
		i += 1
	_wake_order += 1

func awake_count() -> int:
	var n := 0
	for s in swans:
		if not s.is_cygnet and s.tgt_sleep < 0.5:
			n += 1
	return n

func react(grade: float) -> void:
	# End of a movement: the flock turns to you. Everyone gets the nod. A warmer one for more.
	for s in swans:
		s.nod(0.6 + grade * 0.8)
		if grade > 0.55:
			s.flourish(grade)

func answer_beat(on_beat: bool) -> void:
	# A beat that lands gets a small, immediate answer from whichever swan is nearest the baton.
	var tip: Vector3 = main.conductor.tip_position()
	var best: Swan = null
	var best_d := 1e9
	for s in swans:
		var d: float = s.global_position.distance_to(tip)
		if d < best_d:
			best_d = d
			best = s
	if best:
		best.nod(0.5 if on_beat else 0.25)

func startle() -> void:
	for s in swans:
		s.flourish(0.6)

func curtain_call(salute: float) -> void:
	_salute = salute
	_bow_wave_t = 0.0

func _formation_tick(delta: float) -> void:
	var n := 0
	for s in swans:
		if not s.is_cygnet and not s.flying:
			n += 1
	var k := 0
	var user: Vector3 = main.user_position()
	match formation:
		"free":
			return
		"sleep":
			for s in swans:
				if s.tgt_sleep > 0.5:
					s.speed = 0.02
		"regatta", "wedge":
			_trail_t += delta
			if _trail_t > 0.12 or _trail.is_empty():
				_trail_t = 0.0
				_trail.push_front(lead_point)
				if _trail.size() > 300:
					_trail.pop_back()
			for s in swans:
				if s.is_cygnet or s.flying:
					continue
				var slot: Vector3
				if formation == "regatta":
					slot = _trail_at(1.2 + float(k) * 1.45)
				else:
					# A V: alternate sides, each rank back along the trail and out to the side.
					var rank := (k + 1) / 2
					var side := 0.0 if k == 0 else (1.0 if k % 2 == 0 else -1.0)
					var base := _trail_at(1.0 + float(rank) * 1.3)
					var ahead := _trail_at(float(rank) * 1.3)
					var dir := (ahead - base)
					var off: Vector3 = Vector3(-dir.z, 0, dir.x).normalized() if dir.length() > 0.01 else Vector3.RIGHT
					slot = base + off * side * float(rank) * 1.05
				s.gather_slot = _keep_off_dock(slot)
				s.face_point = Vector3.INF
				s.tgt_tall = 0.5
				s.tgt_wing = 0.14 + 0.16 * warmth
				k += 1
		"huddle":
			for s in swans:
				if s.is_cygnet or s.flying:
					continue
				# A close arc in the lee of the dock, turned into the weather.
				var a := -1.15 + 2.3 * float(k) / maxf(float(n - 1), 1.0)
				var r := 3.1 + 0.7 * float(k % 2)
				s.gather_slot = Vector3(sin(a) * r, 0, -1.0 - cos(a) * r)
				s.face_point = Vector3(0, 0, -40)
				s.tgt_wing = 0.42
				s.tgt_tall = 0.0
				k += 1
		"fan":
			for s in swans:
				if s.is_cygnet or s.flying:
					continue
				var a := -1.1 + 2.2 * float(k) / maxf(float(n - 1), 1.0)
				s.gather_slot = Vector3(sin(a) * 6.5, 0, -1.2 - cos(a) * 6.5)
				s.face_point = user
				var wave: float = 0.5 + 0.5 * sin(main.t - float(k) * 0.8)
				s.tgt_wing = 0.25 + 0.75 * wave * wave * (0.5 + warmth * 0.5)
				s.tgt_tall = 0.6
				k += 1
		"solo", "pair":
			var pair: bool = formation == "pair"
			for s in swans:
				if s.is_cygnet or s.flying:
					continue
				if k == 0 or (pair and k == 1):
					if pair:
						# They close to face each other, necks arched. The heart.
						var center: Vector3 = Vector3(lead_point.x * 0.6, 0, clampf(lead_point.z, -6.2, -4.4))
						var sgn: float = -1.0 if k == 0 else 1.0
						s.gather_slot = center + Vector3(sgn * 0.70, 0, 0)
						s.face_point = center
						s.tgt_heart = 1.0
						s.slot_radius = 0.12
						s.tgt_wing = 0.34
					else:
						s.gather_slot = lead_point
						s.face_point = user
						s.slot_radius = 0.35
						s.tgt_tall = 0.35 + 0.3 * (0.5 + 0.5 * sin(main.t * 0.5))
						s.tgt_wing = 0.34 * (0.5 + 0.5 * sin(main.t * 0.6))
				else:
					var a := -1.5 + 3.0 * float(k) / maxf(float(n - 1), 1.0)
					s.gather_slot = Vector3(sin(a) * 9.5, 0, -2.5 - cos(a) * 9.5)
					s.face_point = lead_point
					s.tgt_tall = 0.2
					s.tgt_wing = 0.0
				k += 1
		"ring", "corps":
			var big: bool = formation == "corps"
			for s in swans:
				if s.is_cygnet or s.flying:
					continue
				var a: float = main.t * (0.035 if not big else 0.09) + TAU * float(k) / maxf(float(n), 1.0)
				var r := 7.2 if not big else 8.5
				s.gather_slot = Vector3(sin(a) * r, 0, -8.5 + cos(a) * r * 0.62)
				s.face_point = Vector3.INF
				s.tgt_tall = 0.5
				var w: float = 0.5 + 0.5 * sin(main.t * 0.9 + float(k))
				s.tgt_wing = (0.18 + 0.20 * w) if not big else (0.34 + 0.66 * w * main.music.energy)
				k += 1
		"curtain":
			_bow_wave_t += delta
			for s in swans:
				if s.is_cygnet or s.flying:
					continue
				var f := float(k) / maxf(float(n - 1), 1.0)
				s.gather_slot = Vector3(lerpf(-5.6, 5.6, f), 0, -4.8 - 1.1 * sin(f * PI))
				s.face_point = user
				s.tgt_tall = 0.4
				# The bow runs along the line like a wave, and repeats.
				var ph := fposmod(_bow_wave_t * 0.55 - f * 0.6, 1.0)
				s.want_bow = ph < 0.35
				var sal: float = _salute * (0.55 + 0.45 * sin(main.t * 1.4 + float(k)))
				s.tgt_wing = maxf(sal, 0.12)
				k += 1

func _trail_at(dist: float) -> Vector3:
	# A point this many meters back along the path the lead has drawn.
	if _trail.is_empty():
		return lead_point
	var left := dist
	var prev: Vector3 = _trail[0]
	for i in range(1, _trail.size()):
		var seg: float = prev.distance_to(_trail[i])
		if seg >= left:
			return prev.lerp(_trail[i], left / maxf(seg, 0.001))
		left -= seg
		prev = _trail[i]
	return prev

func _keep_off_dock(p: Vector3) -> Vector3:
	p.y = 0
	if absf(p.x) < 2.0 and p.z > -2.6:
		p.z = -2.6
	return p

func music_energy() -> float:
	return main.music.energy if main.music else 0.0

func _process(delta: float) -> void:
	t += delta
	roam_anchor = main.LAKE_CENTER + Vector3(sin(t * 0.05) * 4.0, 0, cos(t * 0.037) * 3.0)
	if not gather_on:
		flyby_timer -= delta
		if flyby_timer <= 0.0:
			flyby_timer = randf_range(240.0, 330.0)
			request_flyby()
	if not gather_on:
		_formation_tick(delta)
	if snap:
		for s in swans:
			if s.gather_slot != Vector3.INF and not s.flying:
				s.global_position = s.gather_slot
				s.arrived = true
	for s in swans:
		s.update_swan(delta, t)
