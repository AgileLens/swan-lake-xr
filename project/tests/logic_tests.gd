extends SceneTree
# Headless logic checks. Each is written to fail if the mechanic it names is broken.
# Run: godot --headless --path project --script res://tests/logic_tests.gd

const Logic := preload("res://scripts/conduct_logic.gd")
const Data := preload("res://scripts/program_data.gd")
const Presentation := preload("res://scripts/presentation.gd")

var failed := 0
var passed := 0

func check(name: String, ok: bool, detail := "") -> void:
	if ok:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		print("FAIL ", name, "  ", detail)

func _init() -> void:
	_test_ictus()
	_test_score()
	_test_tiers()
	_test_program_data()
	_test_clips()
	_test_rights()
	_test_accents()
	_test_presentation()
	print("LOGIC_RESULT passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _strokes(period: float, amp: float, seconds: float) -> int:
	var d := Logic.IctusDetector.new()
	var dt := 1.0 / 72.0
	var n := 0
	var t := 0.0
	while t < seconds:
		var y := 1.2 + sin(t * TAU / period) * amp
		if d.feed(t, y, dt) > 0.0:
			n += 1
		t += dt
	return n

func _test_ictus() -> void:
	# One downstroke per cycle. Counts must match the true number of beats.
	check("ictus counts a steady 60 bpm beat", abs(_strokes(1.0, 0.15, 20.0) - 20) <= 1, str(_strokes(1.0, 0.15, 20.0)))
	check("ictus counts a brisk 120 bpm beat", abs(_strokes(0.5, 0.10, 10.0) - 20) <= 2, str(_strokes(0.5, 0.10, 10.0)))
	check("ictus ignores a still hand", _strokes(1.0, 0.0, 10.0) == 0)
	check("ictus ignores tiny tremor", _strokes(0.5, 0.004, 10.0) == 0, str(_strokes(0.5, 0.004, 10.0)))
	var d := Logic.IctusDetector.new()
	var n := 0
	var t := 0.0
	while t < 5.0:
		if d.feed(t, 1.0 + t * 0.4, 1.0 / 72.0) > 0.0:
			n += 1
		t += 1.0 / 72.0
	check("ictus ignores a slow upward raise", n == 0, str(n))

func _test_score() -> void:
	var idle := Logic.MovementScore.new(200.0)
	check("doing nothing still earns the floor", is_equal_approx(idle.grade(), Logic.GRADE_FLOOR), str(idle.grade()))
	var s := Logic.MovementScore.new(200.0)
	var last := s.grade()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var monotonic := true
	for i in 2000:
		match rng.randi() % 4:
			0: s.add_active(0.05)
			1: s.add_beat(rng.randf() < 0.2)
			2: s.add_expressive(0.02)
			3: s.add_verb(0.001)
		if s.grade() < last - 0.00001:
			monotonic = false
		last = s.grade()
	check("nothing a player does can lower the grade", monotonic)
	var off := Logic.MovementScore.new(200.0)
	for i in 500:
		off.add_beat(false)
	check("off-beat gestures cost nothing", off.grade() >= idle.grade())
	var great := Logic.MovementScore.new(200.0)
	great.add_active(200.0); great.add_expressive(200.0); great.add_verb(1.0)
	for i in 100:
		great.add_beat(true)
	check("a full performance tops out at 1", great.grade() > 0.98, str(great.grade()))
	var lucky := Logic.MovementScore.new(200.0)
	for i in 300:
		lucky.add_beat(i % 3 == 0)
	check("scattered lucky hits don't count as keeping time", lucky.beats_on == 0.0, str(lucky.beats_on))
	var kept := Logic.MovementScore.new(200.0)
	for i in 30:
		kept.add_beat(true)
	check("a run of beats does count", kept.beats_on >= 28.0 and kept.grade() > idle.grade(), str(kept.beats_on))
	var verb_only := Logic.MovementScore.new(200.0)
	verb_only.add_verb(1.0)
	check("the movement's gesture moves the grade most", verb_only.grade() > idle.grade() + 0.2, str(verb_only.grade()))
	check("on-beat window accepts a near hit", Logic.is_on_beat(0.1))
	check("on-beat window rejects the far side", not Logic.is_on_beat(0.45))
	check("big gesture suits loud music", Logic.expressive_match(0.6, 1.0))
	check("big gesture does not suit silence", not Logic.expressive_match(0.9, 0.0))
	check("a still hand never counts as expressive", not Logic.expressive_match(0.01, 0.0))

func _test_tiers() -> void:
	check("the worst run still gets a tier", Logic.tier_for(0.0) == 0)
	check("tier rises with grace", Logic.tier_for(0.3) <= Logic.tier_for(0.5) and Logic.tier_for(0.5) <= Logic.tier_for(0.6) and Logic.tier_for(0.6) <= Logic.tier_for(0.8))
	check("top performance reaches the ovation", Logic.tier_for(0.9) == 3)
	var ok := true
	for t in Logic.TIERS:
		ok = ok and str(t["line"]).length() > 8 and int(t["barrage"]) >= 4
	check("every tier has a kind line and a fireworks barrage", ok)
	check("no tier scolds", _no_scold())
	check("empty program counts as the floor", is_equal_approx(Logic.overall([]), Logic.GRADE_FLOOR))

func _no_scold() -> bool:
	for t in Logic.TIERS:
		for w in ["fail", "wrong", "bad", "miss", "poor", "try again"]:
			if str(t["line"]).to_lower().contains(w) or str(t["name"]).to_lower().contains(w):
				return false
	return true

func _duration(id: String) -> float:
	var f := FileAccess.open("res://assets/music/%s.json" % id, FileAccess.READ)
	if f == null:
		return 0.0
	return float(JSON.parse_string(f.get_as_text())["duration"])

func _test_program_data() -> void:
	var total := 0.0
	var verbs := {}
	var moods := {}
	var starts := []
	for m in Data.MOVEMENTS:
		total += _duration(m["clip"]) + 6.5
		verbs[m["verb"]] = true
		for c in m["cues"]:
			if c.has("mood"):
				moods[c["mood"]] = true
		starts.append(str(m["cues"][0].get("mood", "?")))
	print("     program length ", snappedf(total / 60.0, 0.1), " min, ", Data.MOVEMENTS.size(), " movements, ", verbs.size(), " baton verbs, ", moods.size(), " stagings")
	check("program runs 15 to 25 minutes", total >= 15.0 * 60.0 and total <= 25.0 * 60.0, str(total / 60.0))
	check("several distinct movements", Data.MOVEMENTS.size() >= 6)
	check("the baton does different things", verbs.size() >= 6, str(verbs.keys()))
	check("the staging changes by movement", moods.size() >= 7, str(moods.keys()))
	var src := FileAccess.get_file_as_string("res://scripts/mood.gd")
	var ok := true
	for k in moods:
		ok = ok and src.contains('"%s":' % k)
	check("every staged mood exists", ok)
	var flock := FileAccess.get_file_as_string("res://scripts/flock.gd")
	ok = true
	for m in Data.MOVEMENTS:
		ok = ok and flock.contains('"%s"' % m["formation"])
	check("every formation has choreography", ok)
	var prog := FileAccess.get_file_as_string("res://scripts/program.gd")
	ok = true
	for m in Data.MOVEMENTS:
		ok = ok and prog.contains('"%s"' % m["verb"])
	check("every baton verb has a handler", ok)
	var last: Dictionary = Data.MOVEMENTS[-1]
	check("the program ends on a real finale", last["verb"] == "launch" and str(last["cues"]).contains("finale"))

func _test_clips() -> void:
	var ok := true
	var detail := ""
	for m in Data.MOVEMENTS:
		var id: String = m["clip"]
		var stream = load("res://assets/music/%s.mp3" % id)
		if stream == null:
			ok = false
			detail += " noaudio:" + id
			continue
		var len_a: float = stream.get_length()
		var len_b := _duration(id)
		if absf(len_a - len_b) > 1.0:
			ok = false
			detail += " len:%s(%.1f/%.1f)" % [id, len_a, len_b]
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/%s.json" % id))
		var beats: Array = data["beats"]
		if beats.size() < 20:
			ok = false
			detail += " beats:" + id
		var rising := true
		for i in range(1, beats.size()):
			rising = rising and float(beats[i]) > float(beats[i - 1])
		if not rising:
			ok = false
			detail += " order:" + id
		if float(data["key_ratio"]) < 0.6 or float(data["key_ratio"]) > 1.6:
			ok = false
			detail += " key:" + id
	check("every clip loads, with a matching length and sane beat map", ok, detail)

func _test_rights() -> void:
	var credits := FileAccess.get_file_as_string("res://../CREDITS.md")
	var ok := true
	var detail := ""
	for m in Data.MOVEMENTS:
		if not credits.contains("`%s`" % m["clip"]):
			ok = false
			detail += " " + m["clip"]
	check("every clip has a CREDITS entry", ok, detail)
	check("the EU-only recording is not in the program", not FileAccess.file_exists("res://assets/music/act2_scene.ogg"))
	var banned := ["Ballet Francaise", "Barbirolli", "Dorati"]
	var src := FileAccess.get_file_as_string("res://scripts/program_data.gd")
	ok = true
	for b in banned:
		ok = ok and not src.contains(b)
	check("no EU-only performer is credited in the program", ok)

func _test_accents() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/storm.json"))
	var script: GDScript = load("res://scripts/program.gd")
	var acc: PackedFloat32Array = script._find_accents(data)
	print("     storm accents ", acc.size())
	check("the storm has crashes to answer", acc.size() >= 4, str(acc.size()))
	var empty: PackedFloat32Array = script._find_accents({"env": [], "env_rate": 10})
	check("no envelope means no accents", empty.size() == 0)

func _test_presentation() -> void:
	check("five mobile-safe visual styles are named", Presentation.STYLE_NAMES.size() == 5)
	check("visual style cycling wraps", Presentation.next_style(4) == 0)
	check("volume cycling wraps", Presentation.next_volume(4) == 0)
	check("mute label is explicit", Presentation.volume_label(3, true) == "MUTED")
	check("real-hand camera compositing is honestly unsupported", not Presentation.real_hand_compositing_supported())
