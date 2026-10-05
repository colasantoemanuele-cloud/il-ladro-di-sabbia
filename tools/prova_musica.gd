extends SceneTree
## Rende i brani in WAV per ascoltarli fuori dal gioco e misura i tempi:
## godot --headless --path . --script tools/prova_musica.gd -- --out=DIR

func _init() -> void:
	var out := "/tmp"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
	var m := MusicEngine.new()
	for nome in MusicEngine.BRANI:
		var t0 := Time.get_ticks_msec()
		var buf := m.render_per_test(nome)
		var picco := 0.0
		for v in buf:
			picco = maxf(picco, absf(v))
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = MusicEngine.SR_LOOP
		w.data = m._a_pcm(buf)
		w.save_to_wav("%s/%s.wav" % [out, nome])
		print("%-10s %5.1fs audio  %5d ms  picco %.2f" % [nome, buf.size() / float(MusicEngine.SR_LOOP), Time.get_ticks_msec() - t0, picco])
	m.free()
	quit()
