extends Node
# --clip=<name>: private dev-diary footage. Run under --write-movie at 1080p30 by tools/clips.sh.
# Plays a piece of a real movement from a wearer's position, with a scripted baton standing in
# for a hand. This is desktop footage of the scene. It isn't a recording from a headset.
var main
var clip := "regatta"
var _t := 0.0
var _dur := 26.0
var rig: Node3D

func setup(m) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--clip="):
			clip = a.substr(7)
	main.perf.enabled = false
	main.title.skip_intro()
	main.title.fade_mat.albedo_color.a = 0.0
	rig = main.get_node("PreviewRig")
	rig.position = Vector3(0, 1.72, 0.6)
	rig.pitch = -0.06
	var prog = main.program
	match clip:
		"regatta":
			_enter("regatta", 8.0, "morning", "breeze")
			main.flock.lead_point = Vector3(-6, 0, -7)
		"finale":
			_enter("finale", 186.0, "gala", "clear")
			main.megaflock.request_level(2)
			main.music.act4_active = true
			main.megaflock.chorus = 1.0
			main.fireworks.start_show()
			rig.pitch = 0.10
		"storm":
			_enter("storm", 20.0, "storm", "rain")
	main.flock.snap = true
	get_tree().create_timer(1.0).timeout.connect(func(): main.flock.snap = false)
	print("[clip] ", clip)

func _enter(id: String, at: float, mood: String, weather: String) -> void:
	var prog = main.program
	main.title.cards_enabled = false
	prog._begin(ProgramData.index_of(id))
	prog.state = ConductorsProgram.State.PLAY
	main.music.play_clip(prog.movement["clip"], 0.3, at)
	prog._cue_i = 0
	prog._run_cues(at)
	main.mood.apply(mood, true)
	main.weather.set_weather(weather)
	main.stand.root.visible = false

func _process(delta: float) -> void:
	_t += delta
	if _t > _dur:
		print("CLIP_DONE")
		get_tree().quit()
		return
	var phase: float = main.music.beat_phase()
	var stroke := (0.5 - absf(0.5 - phase)) * 2.0 * 0.20
	var head: Vector3 = main.head_transform().origin
	var sweep := sin(_t * 0.42) * 0.42
	main.conductor.desktop_tip = head + Vector3(sweep, -0.02 + stroke, -1.0)
	rig.yaw = -sweep * 0.30
