extends SceneTree
# Regression for the inclusive AudioStreamWAV loop endpoint on Android.
var checked := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	_check_tree(scene)
	if checked == 0:
		failures += 1
		print("FAIL no live looping WAV streams were checked")
	_stop_tree(scene)
	scene.free()
	await process_frame
	print("AUDIO BOUNDS %s: %d loops, %d failures" % ["PASS" if failures == 0 else "FAIL", checked, failures])
	quit(0 if failures == 0 else 1)

func _check_tree(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D:
		var stream: AudioStream = node.stream
		if stream is AudioStreamWAV and stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			var wav: AudioStreamWAV = stream
			var frames := int(round(wav.get_length() * wav.mix_rate))
			# Independently derive PCM frame count from bytes, including stereo.
			if wav.format in [AudioStreamWAV.FORMAT_8_BITS, AudioStreamWAV.FORMAT_16_BITS]:
				var bytes_per_frame: int = (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1)
				frames = int(wav.data.size() / bytes_per_frame)
			checked += 1
			if wav.loop_begin < 0 or wav.loop_end < wav.loop_begin or wav.loop_end >= frames:
				failures += 1
				print("FAIL loop bounds ", node.get_path(), " begin=", wav.loop_begin, " end=", wav.loop_end, " frames=", frames)
	for child in node.get_children():
		_check_tree(child)

func _stop_tree(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D:
		node.stop()
	for child in node.get_children():
		_stop_tree(child)

