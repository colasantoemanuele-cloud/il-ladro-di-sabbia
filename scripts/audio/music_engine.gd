class_name MusicEngine
extends Node
## Sintesi chiptune interamente via codice: onde quadre, triangolari, rumore.
## I campioni vengono generati in memoria e inseriti in AudioStreamWAV con
## loop. Scelta tecnica rispetto ad AudioStreamGenerator: il generatore
## richiede di riempire il buffer a ogni frame, con rischio di buchi
## sonori su un telefono sotto carico; il campione pre-renderizzato costa
## zero CPU in riproduzione e il loop e perfetto. I brani lunghi vengono
## generati in un thread e messi in cache su disco al primo avvio.

signal brano_pronto(nome: String)

const VERSIONE_CACHE := "v1"
const SR_LOOP := 16000
const SR_BREVE := 22050

const NOTE_SEMITONI := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

## Ordine di generazione al primo avvio (il brano richiesto passa avanti).
const BRANI := ["titolo", "ospedale", "citta", "osteria", "casa", "bisca", "chiesa", "cripta", "endgame", "gameplay"]

## Il tema di Sara: otto battute in La minore che tornano in ogni luogo,
## travestite (carillon in ospedale, lo-fi a casa, swing in bisca, eco nella
## cripta). È il filo che lega la colonna sonora.
const TEMA := "A4:1 C5:1 E5:2 D5:1 C5:1 B4:2 A4:1 B4:1 C5:1 E5:1 D5:3 R:1 F5:1 E5:1 D5:2 C5:1 B4:1 A4:2 G#4:1 A4:1 B4:1 E4:1 A4:3 R:1"
const ACCORDI_TEMA := [["A2", "m"], ["F2", "M"], ["C3", "M"], ["E2", "M"], ["D3", "m"], ["A2", "m"], ["E2", "M"], ["A2", "m"]]

var volume_master: float = 1.0 : set = _set_volume_master
var volume_musica: float = 0.8 : set = _set_volume_musica
var volume_effetti: float = 0.9 : set = _set_volume_effetti

var _flussi: Dictionary = {}
var _thread: Thread
var _mutex := Mutex.new()
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _player_attivo: AudioStreamPlayer
var _player_fx: Array[AudioStreamPlayer] = []
var _brano_corrente: String = ""
var _brano_richiesto: String = ""
var _bus_musica := "Musica"
var _bus_effetti := "Effetti"


func _ready() -> void:
	_prepara_bus()
	_player_a = _nuovo_player(_bus_musica)
	_player_b = _nuovo_player(_bus_musica)
	_player_attivo = _player_a
	for i in 4:
		_player_fx.append(_nuovo_player(_bus_effetti))
	_applica_volumi()
	for nome in ["click", "dado", "critica", "guadagno", "perdita", "vittoria", "sconfitta"]:
		_flussi[nome] = _genera_breve(nome)
	_thread = Thread.new()
	_thread.start(_genera_loop_in_thread)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _prepara_bus() -> void:
	for nome in [_bus_musica, _bus_effetti]:
		if AudioServer.get_bus_index(nome) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, nome)
			AudioServer.set_bus_send(idx, "Master")


func _nuovo_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _db(v: float) -> float:
	return linear_to_db(maxf(v, 0.0001))


func _applica_volumi() -> void:
	AudioServer.set_bus_volume_db(0, _db(volume_master))
	var im := AudioServer.get_bus_index(_bus_musica)
	var ie := AudioServer.get_bus_index(_bus_effetti)
	if im >= 0:
		AudioServer.set_bus_volume_db(im, _db(volume_musica))
	if ie >= 0:
		AudioServer.set_bus_volume_db(ie, _db(volume_effetti))


func _set_volume_master(v: float) -> void:
	volume_master = clampf(v, 0.0, 1.0)
	if is_inside_tree():
		_applica_volumi()


func _set_volume_musica(v: float) -> void:
	volume_musica = clampf(v, 0.0, 1.0)
	if is_inside_tree():
		_applica_volumi()


func _set_volume_effetti(v: float) -> void:
	volume_effetti = clampf(v, 0.0, 1.0)
	if is_inside_tree():
		_applica_volumi()


# ------------------------------------------------------------ riproduzione

## Avvia (o sostituisce con crossfade) un brano in loop. Se il brano non e
## ancora stato generato, parte appena pronto.
func suona_musica(nome: String, crossfade: float = 1.0) -> void:
	_brano_richiesto = nome
	if nome == _brano_corrente:
		return
	_mutex.lock()
	var flusso: AudioStream = _flussi.get(nome)
	_mutex.unlock()
	if flusso == null:
		return
	_brano_corrente = nome
	var entrante := _player_b if _player_attivo == _player_a else _player_a
	var uscente := _player_attivo
	entrante.stream = flusso
	entrante.volume_db = -60.0
	entrante.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(entrante, "volume_db", 0.0, crossfade)
	if uscente.playing:
		tw.tween_property(uscente, "volume_db", -60.0, crossfade)
		tw.chain().tween_callback(uscente.stop)
	_player_attivo = entrante


func ferma_musica(dissolvenza: float = 1.0) -> void:
	_brano_richiesto = ""
	_brano_corrente = ""
	if _player_attivo.playing:
		var p := _player_attivo
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, dissolvenza)
		tw.tween_callback(p.stop)


func sfx(nome: String) -> void:
	_mutex.lock()
	var flusso: AudioStream = _flussi.get(nome)
	_mutex.unlock()
	if flusso == null:
		return
	for p in _player_fx:
		if not p.playing:
			p.stream = flusso
			p.play()
			return
	_player_fx[0].stream = flusso
	_player_fx[0].play()


## Jingle di fine run: abbassa la musica di sottofondo e lo riproduce una volta.
func jingle(nome: String) -> void:
	ferma_musica(0.4)
	sfx(nome)


func brano_disponibile(nome: String) -> bool:
	_mutex.lock()
	var ok := _flussi.has(nome)
	_mutex.unlock()
	return ok


# ------------------------------------------------------------ generazione

func _genera_loop_in_thread() -> void:
	var restanti: Array = BRANI.duplicate()
	while not restanti.is_empty():
		_mutex.lock()
		var richiesto := _brano_richiesto
		_mutex.unlock()
		var nome: String = richiesto if restanti.has(richiesto) else restanti[0]
		restanti.erase(nome)
		var flusso := _carica_cache(nome)
		if flusso == null:
			var dati := _render_brano(nome)
			flusso = _a_flusso(dati, SR_LOOP, true)
			_salva_cache(nome, dati)
		_mutex.lock()
		_flussi[nome] = flusso
		_mutex.unlock()
		call_deferred("_brano_generato", nome)


func _brano_generato(nome: String) -> void:
	brano_pronto.emit(nome)
	if nome == _brano_richiesto and nome != _brano_corrente:
		suona_musica(nome)


func _percorso_cache(nome: String) -> String:
	return "user://cache_audio_%s/%s.pcm" % [VERSIONE_CACHE, nome]


func _carica_cache(nome: String) -> AudioStreamWAV:
	var f := FileAccess.open(_percorso_cache(nome), FileAccess.READ)
	if f == null:
		return null
	var dati := f.get_buffer(f.get_length())
	if dati.size() < 1000:
		return null
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR_LOOP
	w.stereo = false
	w.data = dati
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = dati.size() / 2
	return w


func _salva_cache(nome: String, dati: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute("user://cache_audio_%s" % VERSIONE_CACHE)
	var f := FileAccess.open(_percorso_cache(nome), FileAccess.WRITE)
	if f != null:
		f.store_buffer(dati)


func _a_flusso(dati: PackedByteArray, sr: int, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = sr
	w.stereo = false
	w.data = dati
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = dati.size() / 2
	return w


func _render_brano(nome: String) -> PackedByteArray:
	return _a_pcm(render_per_test(nome))


func render_per_test(nome: String) -> PackedFloat32Array:
	match nome:
		"titolo":
			return _render(_voci_titolo(), 64.0, 90.0, SR_LOOP, true)
		"gameplay":
			return _render(_voci_gameplay(), 64.0, 110.0, SR_LOOP, true)
		"ospedale":
			return _render(_voci_ospedale(), 64.0, 70.0, SR_LOOP, true, 0.43, 0.32)
		"casa":
			return _render(_voci_casa(), 64.0, 76.0, SR_LOOP, true, 0.2, 0.15)
		"citta":
			return _render(_voci_citta(), 64.0, 96.0, SR_LOOP, true)
		"osteria":
			return _render(_voci_osteria(), 64.0, 104.0, SR_LOOP, true)
		"bisca":
			return _render(_voci_bisca(), 64.0, 132.0, SR_LOOP, true)
		"chiesa":
			return _render(_voci_chiesa(), 32.0, 60.0, SR_LOOP, true, 0.5, 0.35)
		"cripta":
			return _render(_voci_cripta(), 32.0, 54.0, SR_LOOP, true, 0.62, 0.45)
		_:
			return _render(_voci_endgame(), 64.0, 130.0, SR_LOOP, true)


# ------------------------------------------------------------ note e pattern

static func midi(nome: String) -> int:
	var lettera := nome[0]
	var i := 1
	var alt := 0
	if nome.length() > i and nome[i] == "#":
		alt = 1
		i += 1
	elif nome.length() > i and nome[i] == "b":
		alt = -1
		i += 1
	var ottava := int(nome.substr(i))
	return 12 * (ottava + 1) + NOTE_SEMITONI[lettera] + alt


static func frequenza(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


## "A4:2 C5:1 R:1" -> [[midi, inizio, durata], ...]; le pause avanzano il tempo.
static func sequenza(testo: String, inizio: float = 0.0) -> Array:
	var eventi: Array = []
	var t := inizio
	for tok in testo.split(" ", false):
		var parti := tok.split(":")
		var dur := float(parti[1])
		if parti[0] != "R":
			eventi.append([midi(parti[0]), t, dur])
		t += dur
	return eventi


static func _concat(a: Array, b: Array) -> Array:
	var out := a.duplicate()
	out.append_array(b)
	return out


func _voce(onda: String, vol: float, eventi: Array, duty: float = 0.5, adsr: Array = [0.005, 0.08, 0.7, 0.06]) -> Dictionary:
	return {"onda": onda, "vol": vol, "note": eventi, "duty": duty, "adsr": adsr}


static func trasponi(eventi: Array, semitoni: int, scala: float = 1.0, inizio: float = 0.0) -> Array:
	var out: Array = []
	for e in eventi:
		out.append([e[0] + semitoni, inizio + e[1] * scala, e[2] * scala])
	return out


static func triade(radice: String, tipo: String) -> Array:
	var r := midi(radice)
	var terza := 3 if tipo == "m" else 4
	return [r, r + terza, r + 7]


func _voci_ospedale() -> Array:
	var tema := sequenza(TEMA)
	var melodia := _concat(trasponi(tema, 12), trasponi(tema, 12, 1.0, 32.0))
	var seconda := trasponi(tema, 8, 1.0, 32.0)
	var arp: Array = []
	for giro in 2:
		for b in 8:
			var acc := triade(ACCORDI_TEMA[b][0], ACCORDI_TEMA[b][1])
			for k in 8:
				arp.append([acc[k % 3] + 24 + (12 if k >= 6 else 0), giro * 32.0 + b * 4.0 + k * 0.5, 0.45])
	var sabbia: Array = []
	for b in 8:
		sabbia.append([0, b * 8.0, 8.0])
	return [
		_voce("tri", 0.3, melodia, 0.5, [0.002, 0.25, 0.15, 0.5]),
		_voce("tri", 0.12, seconda, 0.5, [0.002, 0.25, 0.15, 0.5]),
		_voce("quadra", 0.035, arp, 0.125, [0.002, 0.12, 0.1, 0.2]),
		_voce("sabbia", 0.03, sabbia),
	]


func _voci_casa() -> Array:
	var tema := sequenza(TEMA)
	var accordi: Array = []
	var basso: Array = []
	var kick: Array = []
	var hat: Array = []
	for giro in 2:
		for b in 8:
			var t := giro * 32.0 + b * 4.0
			var acc := triade(ACCORDI_TEMA[b][0], ACCORDI_TEMA[b][1])
			for n in acc:
				accordi.append([n + 12, t, 3.8])
			basso.append([acc[0] - 12, t, 1.5])
			basso.append([acc[0] - 12 + 7, t + 2.5, 1.0])
			kick.append([0, t, 0.2])
			kick.append([0, t + 2.5, 0.2])
			for k in 4:
				hat.append([0, t + k + 0.62, 0.06])
	return [
		_voce("quadra", 0.1, tema, 0.5, [0.03, 0.2, 0.5, 0.25]),
		_voce("tri", 0.26, trasponi(tema, 0, 1.0, 32.0), 0.5, [0.02, 0.15, 0.7, 0.2]),
		_voce("quadra", 0.035, accordi, 0.5, [0.15, 0.4, 0.6, 0.6]),
		_voce("tri", 0.24, basso, 0.5, [0.01, 0.1, 0.7, 0.1]),
		_voce("kick", 0.22, kick),
		_voce("hat", 0.045, hat),
		_voce("sabbia", 0.025, [[0, 0.0, 32.0], [0, 32.0, 32.0]]),
	]


func _voci_citta() -> Array:
	var tema := sequenza(TEMA)
	var lead := _concat(trasponi(tema, 5), trasponi(tema, 17, 1.0, 32.0))
	var basso: Array = []
	var kick: Array = []
	var hat: Array = []
	for giro in 2:
		for b in 8:
			var t := giro * 32.0 + b * 4.0
			var r: int = triade(ACCORDI_TEMA[b][0], ACCORDI_TEMA[b][1])[0] + 5 - 12
			for k in 8:
				basso.append([r + [0, 0, 7, 0, 12, 7, 0, 7][k], t + k * 0.5, 0.42])
			kick.append([0, t, 0.2])
			kick.append([0, t + 2.0, 0.2])
			for k in 8:
				hat.append([0, t + k * 0.5, 0.05])
	return [
		_voce("quadra", 0.17, lead, 0.25, [0.004, 0.08, 0.6, 0.06]),
		_voce("quadra", 0.15, basso, 0.5, [0.003, 0.05, 0.6, 0.03]),
		_voce("kick", 0.28, kick),
		_voce("hat", 0.07, hat),
	]


func _voci_osteria() -> Array:
	var tema := sequenza(TEMA)
	var tremolo: Array = []
	for e in _concat(tema, trasponi(tema, 0, 1.0, 32.0)):
		var n := int(e[2] / 0.25)
		for k in n:
			tremolo.append([e[0], e[1] + k * 0.25, 0.22])
	var basso: Array = []
	var accordi: Array = []
	for giro in 2:
		for b in 8:
			var t := giro * 32.0 + b * 4.0
			var acc := triade(ACCORDI_TEMA[b][0], ACCORDI_TEMA[b][1])
			basso.append([acc[0] - 12, t, 0.9])
			basso.append([acc[2] - 12, t + 2.0, 0.9])
			for k in [1.0, 3.0]:
				for n in acc:
					accordi.append([n + 12, t + k, 0.4])
	return [
		_voce("quadra", 0.11, tremolo, 0.125, [0.002, 0.05, 0.4, 0.04]),
		_voce("tri", 0.3, basso, 0.5, [0.005, 0.1, 0.6, 0.06]),
		_voce("quadra", 0.03, accordi, 0.25, [0.003, 0.08, 0.3, 0.05]),
	]


func _voci_bisca() -> Array:
	var progressione := [["A2", [0, 3, 7, 10]], ["D3", [0, 3, 7, 10]], ["E2", [0, 4, 7, 10]], ["A2", [0, 3, 7, 10]],
		["F2", [0, 4, 7, 11]], ["B2", [0, 3, 6, 10]], ["E2", [0, 4, 7, 10]], ["A2", [0, 3, 7, 10]]]
	var basso: Array = []
	var comp: Array = []
	var hat: Array = []
	var kick: Array = []
	for giro in 2:
		for b in 8:
			var t := giro * 32.0 + b * 4.0
			var r := midi(progressione[b][0])
			var prossimo := midi(progressione[(b + 1) % 8][0])
			var iv: Array = progressione[b][1]
			var passi := [r, r + iv[1], r + iv[2], prossimo + (1 if prossimo < r + iv[2] else -1)]
			for k in 4:
				basso.append([passi[k], t + k, 0.9])
			for k in [1.66, 3.66]:
				for n in iv:
					comp.append([r + 12 + n, t + k, 0.3])
			for k in 4:
				hat.append([0, t + k, 0.08])
				if k % 2 == 1:
					hat.append([0, t + k + 0.66, 0.05])
			kick.append([0, t, 0.2])
	var swing := "A4:0.66 C5:0.34 E5:1 Eb5:0.66 D5:0.34 C5:1 A4:0.66 G4:0.34 A4:2 R:1 " \
		+ "C5:0.66 D5:0.34 Eb5:0.66 E5:0.34 G5:1 E5:0.66 D5:0.34 C5:1 D5:2 R:2 " \
		+ "E5:0.66 G5:0.34 A5:1 G5:0.66 Eb5:0.34 E5:1 D5:0.66 C5:0.34 B4:2 R:1 " \
		+ "G#4:0.66 B4:0.34 D5:1 C5:0.66 B4:0.34 A4:3 R:1"
	var lead := _concat(sequenza(swing), trasponi(sequenza(TEMA), 0, 1.0, 32.0))
	return [
		_voce("quadra", 0.14, lead, 0.25, [0.004, 0.08, 0.55, 0.06]),
		_voce("tri", 0.34, basso, 0.5, [0.004, 0.08, 0.6, 0.05]),
		_voce("quadra", 0.03, comp, 0.5, [0.003, 0.06, 0.2, 0.04]),
		_voce("hat", 0.06, hat),
		_voce("kick", 0.16, kick),
	]


func _voci_chiesa() -> Array:
	var organo: Array = []
	for b in 8:
		var acc := triade(ACCORDI_TEMA[b][0], ACCORDI_TEMA[b][1])
		for n in acc:
			organo.append([n + 12, b * 4.0, 4.0])
		organo.append([acc[0], b * 4.0, 4.0])
	var tema := sequenza(TEMA)
	var lenta: Array = []
	for e in tema:
		if e[1] < 16.0:
			lenta.append([e[0], e[1] * 2.0, e[2] * 2.0])
	return [
		_voce("quadra", 0.045, organo, 0.5, [0.3, 0.3, 0.9, 0.8]),
		_voce("tri", 0.22, lenta, 0.5, [0.08, 0.2, 0.8, 0.4]),
	]


func _voci_cripta() -> Array:
	var drone := [[midi("A1"), 0.0, 16.0], [midi("A1"), 16.0, 16.0], [midi("E2"), 4.0, 12.0], [midi("F2"), 20.0, 12.0]]
	var eco := sequenza("A3:4 Bb3:2 A3:2 R:4 E4:3 F4:1 E4:4 R:4 C4:2 B3:2 Bb3:4 A3:4")
	return [
		_voce("tri", 0.3, drone, 0.5, [1.5, 1.0, 0.8, 2.0]),
		_voce("quadra", 0.06, eco, 0.125, [0.2, 0.5, 0.4, 1.0]),
		_voce("sabbia", 0.08, [[0, 0.0, 16.0], [0, 16.0, 16.0]]),
	]


func _voci_titolo() -> Array:
	var melodia := "E5:2 C5:1 D5:1 C5:2 A4:2 E5:1.5 G5:0.5 E5:2 D5:2 B4:1 G4:1 " \
		+ "C5:1 E5:1 A5:2 G5:1 F5:1 E5:1 C5:1 D5:2 F5:1 A4:1 E5:2 B4:1 G#4:1 " \
		+ "A4:1 C5:1 E5:1 A5:1 G5:2 D5:1 B4:1 A5:1.5 G5:0.5 F5:1 C5:1 B4:2 G#4:1 B4:1 " \
		+ "F5:2 D5:1 A4:1 E5:2 C5:1 A4:1 G#4:1 B4:1 D5:1 B4:1 E5:3 R:1"
	var radici := ["A2", "F2", "C3", "G2", "A2", "F2", "D3", "E2", "A2", "G2", "F2", "E2", "D3", "A2", "E2", "E2"]
	var quinte := [7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7]
	var basso: Array = []
	for b in 16:
		var r := midi(radici[b])
		var t := b * 4.0
		basso.append([r, t, 2.0])
		basso.append([r + quinte[b], t + 2.0, 1.0])
		basso.append([r, t + 3.0, 1.0])
	var sabbia: Array = []
	for b in 8:
		sabbia.append([0, b * 8.0, 8.0])
	return [
		_voce("tri", 0.34, sequenza(melodia), 0.5, [0.02, 0.1, 0.8, 0.12]),
		_voce("quadra", 0.13, basso, 0.5, [0.01, 0.1, 0.6, 0.08]),
		_voce("sabbia", 0.05, sabbia),
	]


func _voci_gameplay() -> Array:
	var melodia := "D5:0.5 R:0.5 F5:0.5 A5:1 F5:0.5 D5:1 C5:0.5 D5:0.5 R:0.5 F5:1.5 E5:0.5 D5:0.5 " \
		+ "Bb4:0.5 D5:0.5 R:0.5 F5:1 D5:0.5 Bb4:1 A4:0.5 C#5:0.5 E5:1 R:0.5 A5:1 G5:0.5 " \
		+ "D5:0.5 F5:0.5 A5:0.5 R:0.5 A5:1 G5:0.5 F5:0.5 E5:1 D5:0.5 R:0.5 F5:1 E5:0.5 D5:0.5 " \
		+ "G5:0.5 Bb5:0.5 R:0.5 D6:1 C6:0.5 Bb5:1 A5:1.5 E5:0.5 C#5:1 E5:1 " \
		+ "D5:0.5 R:0.5 A5:1 F5:0.5 D5:0.5 F5:1 F5:1 A5:0.5 C6:1 A5:0.5 F5:1 " \
		+ "E5:0.5 G5:0.5 R:0.5 C6:1.5 G5:0.5 E5:0.5 C#5:1 E5:0.5 A5:0.5 G5:1 E5:0.5 C#5:0.5 " \
		+ "D5:0.5 F5:0.5 Bb5:1 A5:0.5 F5:0.5 D5:1 G5:1 D5:0.5 Bb4:0.5 D5:1 G5:1 " \
		+ "A5:0.5 G5:0.5 E5:0.5 C#5:0.5 A4:1 R:0.5 C#5:0.5 E5:2 A4:1 R:1"
	var radici := ["D2", "D2", "Bb1", "A1", "D2", "D2", "G1", "A1", "D2", "F2", "C2", "A1", "Bb1", "G1", "A1", "A1"]
	var salto := [7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7]
	var basso: Array = []
	var kick: Array = []
	var hat: Array = []
	for b in 16:
		var r := midi(radici[b])
		var t := b * 4.0
		basso.append([r, t, 1.0])
		basso.append([r, t + 1.5, 0.5])
		basso.append([r, t + 2.5, 0.5])
		basso.append([r + salto[b], t + 3.0, 1.0])
		kick.append([0, t, 0.2])
		kick.append([0, t + 2.0, 0.2])
		for k in 8:
			hat.append([0, t + k * 0.5, 0.1])
	return [
		_voce("quadra", 0.2, sequenza(melodia), 0.25, [0.004, 0.06, 0.65, 0.05]),
		_voce("quadra", 0.2, basso, 0.5, [0.004, 0.08, 0.6, 0.04]),
		_voce("kick", 0.34, kick),
		_voce("hat", 0.1, hat),
	]


func _voci_endgame() -> Array:
	var accordi := [
		["E3", 0, 3, 7, 12], ["C3", 0, 4, 7, 12], ["D3", 0, 4, 7, 12], ["B2", 0, 4, 7, 12],
		["E3", 0, 3, 7, 12], ["C3", 0, 4, 7, 12], ["D3", 0, 4, 7, 12], ["B2", 0, 4, 7, 12],
		["A2", 0, 3, 7, 12], ["C3", 0, 4, 7, 12], ["D3", 0, 4, 7, 12], ["B2", 0, 4, 7, 12],
		["C3", 0, 4, 7, 12], ["D3", 0, 4, 7, 12], ["B2", 0, 4, 7, 12], ["B2", 0, 4, 7, 12],
	]
	var minori := {"Em": 1}
	var melodia := "B5:2 G5:1 E5:1 C6:2 B5:1 G5:1 A5:2 F#5:1 D5:1 D#5:2 F#5:1 B5:1 " \
		+ "E6:2 D6:1 B5:1 C6:2 G5:1 E5:1 F#5:2 A5:1 D6:1 D#6:1 B5:1 F#5:2 " \
		+ "A5:2 C6:1 E6:1 G6:2 E6:1 C6:1 F#6:2 D6:1 A5:1 B5:3 R:1 " \
		+ "E6:2 G5:2 F#5:2 A5:2 D#5:2 F#5:2 B5:3 R:1"
	var basso: Array = []
	var arp: Array = []
	var kick: Array = []
	var hat: Array = []
	var ordine := [0, 1, 2, 3, 2, 1, 2, 3, 0, 1, 2, 3, 2, 1, 3, 2]
	for b in 16:
		var ac: Array = accordi[b]
		var r := midi(ac[0])
		var t := b * 4.0
		for k in 8:
			var nota := r - 12 if k % 2 == 0 else r
			basso.append([nota, t + k * 0.5, 0.45])
		for k in 16:
			arp.append([r + 12 + ac[1 + ordine[k] % 4], t + k * 0.25, 0.22])
		for k in 4:
			kick.append([0, t + k, 0.2])
			hat.append([0, t + k + 0.5, 0.08])
	return [
		_voce("tri", 0.3, sequenza(melodia), 0.5, [0.01, 0.1, 0.8, 0.1]),
		_voce("quadra", 0.1, arp, 0.25, [0.003, 0.04, 0.5, 0.03]),
		_voce("quadra", 0.27, basso, 0.5, [0.003, 0.05, 0.7, 0.03]),
		_voce("kick", 0.34, kick),
		_voce("hat", 0.09, hat),
	]


# ------------------------------------------------------------ sintesi

func _render(voci: Array, battiti: float, bpm: float, sr: int, ciclico: bool, eco_s: float = 0.0, eco_fb: float = 0.0) -> PackedFloat32Array:
	var sec_battito := 60.0 / bpm
	var totale := int(battiti * sec_battito * sr)
	var buf := PackedFloat32Array()
	buf.resize(totale)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for voce in voci:
		var onda: String = voce.onda
		var vol: float = voce.vol
		var duty: float = voce.duty
		var env: Array = voce.adsr
		for ev in voce.note:
			var inizio := int(ev[1] * sec_battito * sr)
			var dur_s: float = ev[2] * sec_battito
			match onda:
				"kick":
					_nota_kick(buf, inizio, vol, sr, ciclico)
				"hat":
					_nota_rumore(buf, inizio, dur_s, vol, sr, rng, ciclico)
				"sabbia":
					_nota_sabbia(buf, inizio, dur_s, vol, sr, rng, ciclico)
				_:
					_nota_tonale(buf, inizio, ev[0], dur_s, vol, duty, onda == "tri", env, sr, ciclico)
	return buf


func _scrivi(buf: PackedFloat32Array, indice: int, v: float, ciclico: bool) -> void:
	var n := buf.size()
	if indice >= n:
		if not ciclico:
			return
		indice = indice % n
	buf[indice] += v


func _nota_tonale(buf: PackedFloat32Array, inizio: int, nota: float, dur_s: float, vol: float, duty: float, triangolo: bool, env: Array, sr: int, ciclico: bool) -> void:
	var inc := frequenza(nota) / float(sr)
	var a: float = env[0]
	var d: float = env[1]
	var s: float = env[2]
	var r: float = env[3]
	var n_on := int(dur_s * sr)
	var n_tot := n_on + int(r * sr)
	var ph := 0.0
	var livello_off := s
	if dur_s < a:
		livello_off = dur_s / a
	elif dur_s < a + d:
		livello_off = 1.0 - (1.0 - s) * (dur_s - a) / d
	var n_rel := maxi(n_tot - n_on, 1)
	var inv_sr := 1.0 / float(sr)
	for i in n_tot:
		var amp: float
		if i < n_on:
			var t := i * inv_sr
			if t < a:
				amp = t / a
			elif t < a + d:
				amp = 1.0 - (1.0 - s) * (t - a) / d
			else:
				amp = s
		else:
			amp = livello_off * (1.0 - float(i - n_on) / float(n_rel))
		ph += inc
		if ph >= 1.0:
			ph -= 1.0
		var w: float
		if triangolo:
			w = floorf((4.0 * absf(ph - 0.5) - 1.0) * 8.0) / 8.0
		else:
			w = 1.0 if ph < duty else -1.0
		_scrivi(buf, inizio + i, w * amp * vol, ciclico)


func _nota_kick(buf: PackedFloat32Array, inizio: int, vol: float, sr: int, ciclico: bool) -> void:
	var n := int(0.16 * sr)
	var ph := 0.0
	for i in n:
		var t := float(i) / sr
		var f := 45.0 + 130.0 * exp(-t * 32.0)
		ph += TAU * f / sr
		_scrivi(buf, inizio + i, sin(ph) * exp(-t * 16.0) * vol, ciclico)


func _nota_rumore(buf: PackedFloat32Array, inizio: int, dur_s: float, vol: float, sr: int, rng: RandomNumberGenerator, ciclico: bool) -> void:
	var n := int(maxf(dur_s, 0.04) * sr)
	for i in n:
		var t := float(i) / sr
		var v := rng.randf_range(-1.0, 1.0)
		_scrivi(buf, inizio + i, v * exp(-t * 55.0) * vol, ciclico)


## Texture di sabbia: rumore passa-basso lento, modulato da un respiro.
func _nota_sabbia(buf: PackedFloat32Array, inizio: int, dur_s: float, vol: float, sr: int, rng: RandomNumberGenerator, ciclico: bool) -> void:
	var n := int(dur_s * sr)
	var y := 0.0
	var tenuto := 0.0
	for i in n:
		if i % 6 == 0:
			tenuto = rng.randf_range(-1.0, 1.0)
		y += (tenuto - y) * 0.25
		var respiro := 0.55 + 0.45 * sin(TAU * float(i) / float(sr) * 0.25)
		_scrivi(buf, inizio + i, y * respiro * vol, ciclico)


func _a_pcm(buf: PackedFloat32Array) -> PackedByteArray:
	var media := 0.0
	for v in buf:
		media += v
	media /= maxf(float(buf.size()), 1.0)
	var picco := 0.0001
	for i in buf.size():
		buf[i] -= media
		picco = maxf(picco, absf(buf[i]))
	var g := 0.88 / picco if picco > 0.88 else 1.0
	var out := PackedByteArray()
	out.resize(buf.size() * 2)
	for i in buf.size():
		out.encode_s16(i * 2, int(clampf(buf[i] * g, -1.0, 1.0) * 32000.0))
	return out


# ------------------------------------------------------------ suoni brevi

func _genera_breve(nome: String) -> AudioStreamWAV:
	var sr := SR_BREVE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var buf: PackedFloat32Array
	match nome:
		"click":
			buf = _tono_breve(880.0, 0.03, 0.35, 0.5, sr)
		"dado":
			buf = _dado_rumore(sr, rng)
		"critica":
			buf = PackedFloat32Array()
			buf.resize(int(0.5 * sr))
			for k in 3:
				var b := _tono_breve(220.0, 0.07, 0.4, 0.5, sr)
				for i in b.size():
					buf[int((k * 0.14) * sr) + i] += b[i]
		"guadagno":
			buf = _concatena([_tono_breve(frequenza(72), 0.07, 0.35, 0.5, sr), _tono_breve(frequenza(79), 0.11, 0.35, 0.5, sr)])
		"perdita":
			buf = _concatena([_tono_breve(frequenza(67), 0.07, 0.35, 0.5, sr), _tono_breve(frequenza(59), 0.13, 0.35, 0.5, sr)])
		"vittoria":
			buf = _jingle_vittoria(sr)
		"sconfitta":
			buf = _jingle_sconfitta(sr)
		_:
			buf = PackedFloat32Array()
			buf.resize(100)
	return _a_flusso(_a_pcm(buf), sr, false)


func _concatena(parti: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parti:
		out.append_array(p)
	return out


func _tono_breve(freq: float, dur: float, vol: float, duty: float, sr: int) -> PackedFloat32Array:
	var n := int(dur * sr)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in n:
		ph += freq / sr
		if ph >= 1.0:
			ph -= 1.0
		var amp := exp(-3.5 * float(i) / float(n))
		buf[i] = (1.0 if ph < duty else -1.0) * amp * vol
	return buf


func _dado_rumore(sr: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(0.15 * sr)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var tenuto := 0.0
	var contatore := 0
	for i in n:
		var t := float(i) / float(n)
		var periodo := 1 + int(t * 9.0)
		if contatore <= 0:
			tenuto = rng.randf_range(-1.0, 1.0)
			contatore = periodo
		contatore -= 1
		buf[i] = tenuto * (1.0 - t) * 0.45
	return buf


func _jingle_vittoria(sr: int) -> PackedFloat32Array:
	var voci := [
		_voce("tri", 0.32, sequenza("E5:1 D5:1 B4:1 D5:1 C5:1 Ab4:1 C5:3"), 0.5, [0.01, 0.1, 0.8, 0.25]),
		_voce("quadra", 0.07, sequenza("C4:2 E4:0 G4:0 G3:2 B3:0 D4:0 F3:2 Ab3:0 C4:0 C3:3.5"), 0.5, [0.01, 0.1, 0.6, 0.3]),
	]
	var accordi: Array = []
	for acc in [[48, 52, 55, 0.0, 2.0], [43, 47, 50, 2.0, 2.0], [41, 44, 48, 4.0, 2.0], [48, 52, 55, 6.0, 2.0]]:
		for k in 3:
			accordi.append([acc[k], acc[3], acc[4]])
	voci[1].note = accordi
	return _render(voci, 8.0, 120.0, sr, false)


func _jingle_sconfitta(sr: int) -> PackedFloat32Array:
	var disc := "E5:0.7 Eb5:0.7 D5:0.7 Db5:0.7 C5:0.7 B4:0.7 Bb4:0.7 A4:2"
	var voci := [
		_voce("tri", 0.4, sequenza(disc), 0.5, [0.01, 0.1, 0.7, 0.4]),
		_voce("quadra", 0.07, sequenza("A2:7.5"), 0.5, [0.2, 0.3, 0.5, 1.5]),
	]
	return _render(voci, 11.0, 160.0, sr, false)
