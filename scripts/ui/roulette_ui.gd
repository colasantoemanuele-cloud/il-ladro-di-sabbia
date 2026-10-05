class_name RouletteUI
extends Control
## Il tavolo della roulette. Si punta sabbia vera (ore di Sirio), si sceglie
## rosso, nero, pari, dispari o un numero, la ruota gira. Ogni giro costa dieci
## minuti a Sirio e a Sara. Con Intuizione 4 si può leggere il croupier.

signal chiuso

const ORDINE := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]

var ui
var s: ImperoState
var _puntata := 2.0
var _scelta := "rosso"
var _numero := 17
var _ruota: TextureRect
var _pallina: ColorRect
var _lbl_puntata: Label
var _lbl_esito: Label
var _lbl_vita: Label
var _bottoni_scelta: Dictionary = {}
var _gira: Button
var _leggi: Button
var _in_giro := false


func avvia(interfaccia, stato: ImperoState) -> void:
	ui = interfaccia
	s = stato
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var velo := ColorRect.new()
	velo.color = Color(0.02, 0.05, 0.03, 0.9)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(velo)
	var riga := HBoxContainer.new()
	riga.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	riga.offset_left = 24
	riga.offset_right = -24
	riga.offset_top = 16
	riga.offset_bottom = -16
	riga.add_theme_constant_override("separation", 24)
	add_child(riga)
	var sinistra := CenterContainer.new()
	sinistra.custom_minimum_size = Vector2(420, 0)
	riga.add_child(sinistra)
	var tavolo := Control.new()
	tavolo.custom_minimum_size = Vector2(384, 384)
	sinistra.add_child(tavolo)
	_ruota = TextureRect.new()
	_ruota.texture = _texture_ruota()
	_ruota.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ruota.size = Vector2(384, 384)
	_ruota.pivot_offset = Vector2(192, 192)
	tavolo.add_child(_ruota)
	_pallina = ColorRect.new()
	_pallina.color = Color("f8f8f8")
	_pallina.size = Vector2(12, 12)
	_pallina.position = Vector2(186, 30)
	tavolo.add_child(_pallina)
	var destra := VBoxContainer.new()
	destra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destra.add_theme_constant_override("separation", 12)
	riga.add_child(destra)
	destra.add_child(Stile.etichetta("ROULETTE", Stile.TITOLI, Stile.SABBIA))
	_lbl_vita = Stile.etichetta("", 18, Stile.GRIGIO.lightened(0.35))
	destra.add_child(_lbl_vita)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	destra.add_child(r1)
	for passo in [-5.0, -1.0, 1.0, 5.0]:
		var b := _b("%+.0fh" % passo, Stile.GRIGIO, 64)
		b.pressed.connect(func():
			_puntata = clampf(_puntata + passo, 1.0, maxf(1.0, floorf(s.sirio - 1.0)))
			_aggiorna())
		r1.add_child(b)
	_lbl_puntata = Stile.etichetta("", 34, Stile.SABBIA)
	destra.add_child(_lbl_puntata)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 8)
	destra.add_child(r2)
	for def in [["rosso", "ROSSO", Color("c03030")], ["nero", "NERO", Color("2a2a2a")], ["pari", "PARI", Stile.GRIGIO], ["dispari", "DISPARI", Stile.GRIGIO]]:
		var b := _b(def[1], def[2], 72)
		var id: String = def[0]
		b.pressed.connect(func():
			_scelta = id
			_aggiorna())
		r2.add_child(b)
		_bottoni_scelta[id] = b
	var r3 := HBoxContainer.new()
	r3.add_theme_constant_override("separation", 8)
	destra.add_child(r3)
	var meno := _b("−", Stile.GRIGIO, 64)
	var num := _b("", Color("3d7a5a"), 64)
	var piu := _b("+", Stile.GRIGIO, 64)
	meno.pressed.connect(func():
		_numero = (_numero + 36) % 37
		_scelta = "numero:%d" % _numero
		_aggiorna())
	piu.pressed.connect(func():
		_numero = (_numero + 1) % 37
		_scelta = "numero:%d" % _numero
		_aggiorna())
	num.pressed.connect(func():
		_scelta = "numero:%d" % _numero
		_aggiorna())
	r3.add_child(meno)
	r3.add_child(num)
	r3.add_child(piu)
	_bottoni_scelta["numero"] = num
	_gira = _b("GIRA  · 10 min", Stile.ROSSO, 84)
	_gira.pressed.connect(gira)
	destra.add_child(_gira)
	if int(s.stat.get("intuizione", 1)) >= 4:
		_leggi = _b("[INTUIZIONE 4] Leggere il croupier  · 15 min", Color("6ab0f0"), 64)
		_leggi.pressed.connect(_leggi_croupier)
		destra.add_child(_leggi)
	else:
		var n := Stile.etichetta("Con Intuizione 4 potresti leggere la mano del croupier.", 16, Stile.GRIGIO)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		destra.add_child(n)
	_lbl_esito = Stile.etichetta("Il croupier aspetta. Il banco ha sempre un numero in più di te.", 19, Stile.CHIARO)
	_lbl_esito.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	destra.add_child(_lbl_esito)
	var esci := _b("ALZARSI DAL TAVOLO", Stile.GRIGIO, 64)
	esci.pressed.connect(chiudi)
	destra.add_child(esci)
	_puntata = clampf(_puntata, 1.0, maxf(1.0, floorf(s.sirio - 1.0)))
	_aggiorna()


func _b(testo: String, colore: Color, alto: int) -> Button:
	var b := Button.new()
	b.text = testo
	b.custom_minimum_size = Vector2(0, alto)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 19)
	Stile.applica_bottone(b, colore)
	return b


func _aggiorna() -> void:
	_lbl_puntata.text = "Puntata: %s" % Stile.ore(_puntata)
	_lbl_vita.text = "Sirio ha %s. Vinci il doppio su colore e parità, 36 volte su un numero." % Stile.ore(s.sirio)
	_bottoni_scelta.numero.text = "N. %d" % _numero
	for id in _bottoni_scelta:
		var attivo: bool = _scelta == id or (id == "numero" and _scelta.begins_with("numero:"))
		_bottoni_scelta[id].modulate = Color.WHITE if attivo else Color(0.55, 0.55, 0.55)


func _texture_ruota() -> ImageTexture:
	var lato := 96
	var img := Image.create(lato, lato, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(lato / 2.0, lato / 2.0)
	for y in lato:
		for x in lato:
			var d := Vector2(x + 0.5, y + 0.5) - c
			var r := d.length()
			if r > 47:
				continue
			var col := Color("5a3420")
			if r < 41 and r > 26:
				var ang := fposmod(atan2(d.y, d.x) + PI / 2.0, TAU)
				var i := int(ang / TAU * 37.0) % 37
				var n: int = ORDINE[i]
				col = Color("3d7a5a") if n == 0 else (Color("b02828") if Minigiochi.colore(n) == "rosso" else Color("151515"))
				if r > 39:
					col = col.lightened(0.15)
			elif r <= 26 and r > 12:
				col = Color("7a5234")
			elif r <= 12:
				col = Color("c8a040") if r > 4 else Color("e8d080")
			if r > 45:
				col = Color("2a1810")
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _leggi_croupier() -> void:
	if _in_giro:
		return
	var r := Minigiochi.leggi_croupier(s)
	ui.accoda_esito({"eventi": r.eventi, "notifiche": []}, "")
	_lbl_esito.text = "Le dita del croupier, il polso, lo sguardo. Ti sembra che uscirà il %s." % r.presagio
	_leggi.disabled = true
	_aggiorna()
	if s.is_over:
		chiudi()


## Pubblica per i test.
func gira() -> void:
	if _in_giro:
		return
	var r := Minigiochi.roulette(s, _puntata, _scelta)
	if r.get("rifiutata", false):
		ui.notifica(str(r.motivo))
		return
	_in_giro = true
	_gira.disabled = true
	ui._s("dado")
	var idx: int = ORDINE.find(r.numero)
	var giri := 5.0 * TAU
	var fine := -(float(idx) + 0.5) / 37.0 * TAU
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_ruota, "rotation", _ruota.rotation + giri + fposmod(fine - _ruota.rotation, TAU), 2.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var orbita := create_tween()
	orbita.tween_method(func(k: float):
		var a := -k * 7.0 * TAU - PI / 2.0
		var raggio := lerpf(176.0, 140.0, minf(k * 1.2, 1.0))
		_pallina.position = Vector2(192, 192) + Vector2(cos(a), sin(a)) * raggio - Vector2(6, 6), 0.0, 1.0, 2.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	orbita.tween_callback(func():
		_pallina.position = Vector2(186, 192 - 140 - 6)
		var nome: String = "%d %s" % [r.numero, r.colore]
		if r.vinto:
			_lbl_esito.text = "Esce il %s. Vinci %s. Il croupier non alza gli occhi." % [nome, Stile.ore(r.guadagno)]
			ui._s("guadagno")
		else:
			_lbl_esito.text = "Esce il %s. Perdi %s. La ruota non ricorda niente." % [nome, Stile.ore(-r.guadagno)]
			ui._s("perdita")
		ui.accoda_esito({"eventi": r.eventi, "notifiche": r.note}, "Roulette: %s, %s" % [nome, ("vinte " + Stile.ore(r.guadagno)) if r.vinto else ("perse " + Stile.ore(-r.guadagno))])
		_in_giro = false
		_gira.disabled = false
		_puntata = clampf(_puntata, 1.0, maxf(1.0, floorf(s.sirio - 1.0)))
		_aggiorna()
		if s.is_over:
			chiudi())


func chiudi() -> void:
	if is_queued_for_deletion():
		return
	chiuso.emit()
	queue_free()
