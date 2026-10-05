class_name LottaUI
extends Control
## Il ring clandestino. Due lottatori, due quote, una puntata. Chi ha occhio
## (Intuizione 3) o la soffiata giusta vede chi si è venduto. Ogni incontro
## dura mezz'ora di vita, per Sirio e per Sara.

signal chiuso

var ui
var s: ImperoState
var _inc: Dictionary
var _puntata := 2.0
var _lottatori: Array[TextureRect] = []
var _vite: Array[ProgressBar] = []
var _nomi: Array[Label] = []
var _lbl_puntata: Label
var _lbl_esito: Label
var _lbl_indizio: Label
var _bottoni: Array[Button] = []
var _in_corso := false
var _arena: Control


func avvia(interfaccia, stato: ImperoState) -> void:
	ui = interfaccia
	s = stato
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var velo := ColorRect.new()
	velo.color = Color(0.06, 0.03, 0.02, 0.92)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(velo)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_right = -24
	v.offset_top = 12
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(Stile.etichetta("IL RING", Stile.TITOLI, Stile.SABBIA))
	_arena = Control.new()
	_arena.custom_minimum_size = Vector2(0, 250)
	v.add_child(_arena)
	var ring := TextureRect.new()
	ring.texture = PixelMondo.oggetto("ring", [4, 4])
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_SCALE
	ring.size = Vector2(448, 252)
	ring.anchor_left = 0.5
	ring.anchor_right = 0.5
	ring.offset_left = -224
	ring.offset_right = 224
	ring.offset_bottom = 252
	_arena.add_child(ring)
	for i in 2:
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.size = Vector2(96, 144)
		t.position = Vector2(110.0 if i == 0 else 242.0, 40.0)
		ring.add_child(t)
		_lottatori.append(t)
		var col := VBoxContainer.new()
		col.anchor_left = 0.0 if i == 0 else 1.0
		col.anchor_right = col.anchor_left
		col.offset_left = 0.0 if i == 0 else -300.0
		col.offset_right = col.offset_left + 300.0
		col.offset_top = 10
		_arena.add_child(col)
		var n := Stile.etichetta("", 22, Stile.CHIARO)
		col.add_child(n)
		_nomi.append(n)
		var b := ProgressBar.new()
		b.show_percentage = false
		b.max_value = 100
		b.value = 100
		b.custom_minimum_size = Vector2(260, 14)
		b.add_theme_stylebox_override("fill", Stile.barra(Stile.ROSSO if i == 0 else Color("3080c0")))
		col.add_child(b)
		_vite.append(b)
	_lbl_indizio = Stile.etichetta("", 18, Color("6ab0f0"))
	_lbl_indizio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lbl_indizio)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	v.add_child(r1)
	for passo in [-5.0, -1.0, 1.0, 5.0]:
		var b := _b("%+.0fh" % passo, Stile.GRIGIO)
		b.pressed.connect(func():
			_puntata = clampf(_puntata + passo, 1.0, maxf(1.0, floorf(s.sirio - 1.0)))
			_aggiorna())
		r1.add_child(b)
	_lbl_puntata = Stile.etichetta("", 26, Stile.SABBIA)
	r1.add_child(_lbl_puntata)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 12)
	v.add_child(r2)
	for i in 2:
		var b := _b("", Stile.ROSSO if i == 0 else Color("3080c0"))
		b.custom_minimum_size.y = 80
		var idx := i
		b.pressed.connect(func(): punta(idx))
		r2.add_child(b)
		_bottoni.append(b)
	_lbl_esito = Stile.etichetta("", 19, Stile.CHIARO)
	_lbl_esito.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lbl_esito)
	var esci := _b("TORNARE IN SALA", Stile.GRIGIO)
	esci.pressed.connect(chiudi)
	v.add_child(esci)
	_puntata = clampf(_puntata, 1.0, maxf(1.0, floorf(s.sirio - 1.0)))
	_nuovo_incontro()


func _b(testo: String, colore: Color) -> Button:
	var b := Button.new()
	b.text = testo
	b.custom_minimum_size = Vector2(0, 60)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 19)
	Stile.applica_bottone(b, colore)
	return b


func _nuovo_incontro() -> void:
	_inc = Minigiochi.incontro(s)
	for i in 2:
		_nomi[i].text = str(_inc.nomi[i]).capitalize()
		_vite[i].value = 100
		_lottatori[i].texture = PixelMondo.personaggio("lottatore%d" % (i + 1), 3 if i == 0 else 2, 0)
		_lottatori[i].modulate = Color.WHITE
	var ind := Minigiochi.indizio(s, _inc)
	_lbl_indizio.text = ind if ind != "" else "Due uomini si scaldano. Non sai leggere chi suda per finta. Intuizione 3 ti aiuterebbe."
	_aggiorna()


func _aggiorna() -> void:
	_lbl_puntata.text = "  Puntata: %s   (Sirio ha %s)" % [Stile.ore(_puntata), Stile.ore(s.sirio)]
	for i in 2:
		_bottoni[i].text = "PUNTA SU %s  · quota %.1f  · 30 min" % [str(_inc.nomi[i]).to_upper(), float(_inc.quote[i])]
		_bottoni[i].disabled = _in_corso


## Pubblica per i test.
func punta(scelta: int) -> void:
	if _in_corso:
		return
	var r := Minigiochi.lotta(s, _puntata, scelta)
	if r.get("rifiutata", false):
		ui.notifica(str(r.motivo))
		return
	_in_corso = true
	_aggiorna()
	_lbl_esito.text = "Suona la campana."
	var tw := create_tween()
	var vite := [100, 100]
	for c in r.colpi:
		var chi: int = c[0]
		var danno: int = c[1]
		var att := _lottatori[chi]
		var dif := _lottatori[1 - chi]
		var dx := 24.0 if chi == 0 else -24.0
		tw.tween_callback(func(): att.texture = PixelMondo.personaggio("lottatore%d" % (chi + 1), 3 if chi == 0 else 2, 1))
		tw.tween_property(att, "position:x", att.position.x + dx, 0.08)
		tw.tween_callback(func():
			vite[1 - chi] = maxi(0, vite[1 - chi] - danno)
			_vite[1 - chi].value = vite[1 - chi]
			dif.modulate = Color(1.5, 0.5, 0.5)
			ui._s("click"))
		tw.tween_property(att, "position:x", att.position.x, 0.1)
		tw.tween_callback(func():
			dif.modulate = Color.WHITE
			att.texture = PixelMondo.personaggio("lottatore%d" % (chi + 1), 3 if chi == 0 else 2, 0))
		tw.tween_interval(0.12)
	tw.tween_callback(func():
		var v: int = r.vincitore
		_lottatori[1 - v].modulate = Color(0.4, 0.4, 0.4)
		var nome := str(r.incontro.nomi[v]).capitalize()
		if r.vinto:
			_lbl_esito.text = "%s resta in piedi. Vinci %s." % [nome, Stile.ore(r.guadagno)]
			ui._s("guadagno")
		else:
			_lbl_esito.text = "%s resta in piedi. Perdi %s." % [nome, Stile.ore(-r.guadagno)]
			ui._s("perdita")
		ui.accoda_esito({"eventi": r.eventi, "notifiche": []}, "Ring: vince %s, %s" % [nome, ("vinte " + Stile.ore(r.guadagno)) if r.vinto else ("perse " + Stile.ore(-r.guadagno))])
		if s.is_over:
			chiudi()
			return
		var dopo := create_tween()
		dopo.tween_interval(1.4)
		dopo.tween_callback(func():
			_in_corso = false
			_puntata = clampf(_puntata, 1.0, maxf(1.0, floorf(s.sirio - 1.0)))
			_nuovo_incontro()))


func chiudi() -> void:
	if is_queued_for_deletion():
		return
	chiuso.emit()
	queue_free()
