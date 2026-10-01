class_name MondoUI
extends Control
## Interfaccia di gioco a luoghi. In alto lo stato di Sirio (orologi, fame,
## sonno, risorse). Al centro il luogo dove si trova e solo cio che si puo fare
## li. A destra il diario della settimana. In basso telefono, mappa, taccuino.
## Nessuna regola qui: tutto passa da MondoRun e GameState.

signal torna_al_titolo
signal nuova_partita

const ALTO := 96
const BASSO := 84
const LARGHEZZA_DIARIO := 380
const SOGLIA_ENDGAME_ORE := 24.0
const SOGLIA_PULSE_ORE := 4.0
const SOGLIA_POCHE_ORE := 8.0
const SOGLIA_CRITICA := 75.0

const RISORSE := [
	["polizia", "Polizia", "Attenzione della polizia. Sopra 50 i colpi diventano più difficili."],
	["rivalita", "Rivalità", "Quanto ti odiano i rivali di L'chen."],
	["fama", "Fama", "Quanto ti conosce la città. Pesa sui colpi se hai una posizione rispettabile."],
	["karma", "Karma", "Ti segue da una settimana all'altra. Cambia gli eventi e i patti che ti vengono offerti."],
	["fede", "Fede", "Fede del Culto o della Setta: serve per salire nelle strade religiose."],
]

var mondo: MondoRun
var stato: GameState
var profilo: PlayerProfile
var persistente: MondoPersistente
var audio: MusicEngine
var _e_seed_del_giorno := false

var _strato: Control
var _modale: Control = null
var _pannello: Control = null
var _rinfresca_pannello: Callable
var _coda: Array = []
var _fine_mostrata := false
var _controlla_occasione := false
var _musica := ""
var _prima: Dictionary = {}
var _chat: Dictionary = {}
var _toast_coda: Array[String] = []
var _toast_attivo := false

var _avatar: TextureRect
var _frame := 0
var _lbl_ora: Label
var _lbl_luogo: Label
var _lbl_padre: Label
var _bar_padre: ProgressBar
var _lbl_figlia: Label
var _bar_figlia: ProgressBar
var _lbl_sonno: Label
var _lbl_fame: Label
var _val_ris: Dictionary = {}
var _img_luogo: TextureRect
var _lbl_nome_luogo: Label
var _lbl_desc_luogo: Label
var _griglia: GridContainer
var _vuoto: Label
var _diario: VBoxContainer
var _btn_tel: Button
var _btn_mappa: Button
var _btn_taccuino: Button
var _critico_prima: Dictionary = {}
var _pulse: Dictionary = {}
var _toast: Label


func avvia(mondo_run: MondoRun, profilo_corrente: PlayerProfile, mondo_persistente: MondoPersistente, motore_audio: MusicEngine, e_seed_del_giorno: bool = false) -> void:
	mondo = mondo_run
	stato = mondo.stato
	profilo = profilo_corrente
	persistente = mondo_persistente
	audio = motore_audio
	_e_seed_del_giorno = e_seed_del_giorno
	if profilo != null:
		stato.karma = profilo.karma
	theme = Stile.tema()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_costruisci()
	_scrivi("Lunedì notte. Sara è nata da un'ora. Serena no.", Stile.SABBIA)
	_scrivi("Sei in ospedale. Ti restano 24 ore. A lei, una settimana.", Stile.CHIARO)
	_aggiorna()
	_imposta_musica()
	_coda_bivio(TestiDemo.BIVIO_INIZIO)
	_esegui_coda()


func _s(nome: String) -> void:
	if audio != null:
		audio.sfx(nome)


# =============================================================== costruzione

func _costruisci() -> void:
	var fondo := ColorRect.new()
	fondo.color = Stile.NERO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var radice := VBoxContainer.new()
	radice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radice.add_theme_constant_override("separation", 0)
	add_child(radice)
	radice.add_child(_costruisci_alto())

	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 0)
	radice.add_child(corpo)
	corpo.add_child(_costruisci_scena())
	corpo.add_child(_costruisci_diario())
	radice.add_child(_costruisci_basso())

	_strato = Control.new()
	_strato.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strato.offset_top = ALTO
	_strato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strato)

	_toast = Stile.etichetta("", 19, Stile.CHIARO)
	_toast.add_theme_stylebox_override("normal", Stile.box(Color(0.05, 0.05, 0.08, 0.95), Stile.GIALLO, 3, 12))
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.custom_minimum_size = Vector2(520, 0)
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)


func _costruisci_alto() -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, ALTO)
	p.add_theme_stylebox_override("panel", Stile.box(Color("101022"), Stile.GRIGIO, 3, 8))
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 18)
	p.add_child(riga)

	_avatar = TextureRect.new()
	_avatar.texture = PixelArt.avatar_frame(0)
	_avatar.custom_minimum_size = Vector2(48, 72)
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	riga.add_child(_avatar)
	var anim := create_tween().set_loops()
	anim.tween_interval(0.45)
	anim.tween_callback(func():
		_frame = (_frame + 1) % 4
		_avatar.texture = PixelArt.avatar_frame(_frame))

	var dove := VBoxContainer.new()
	dove.custom_minimum_size = Vector2(230, 0)
	dove.alignment = BoxContainer.ALIGNMENT_CENTER
	_lbl_ora = Stile.etichetta("", 24, Stile.SABBIA)
	_lbl_luogo = Stile.etichetta("", 17, Stile.GRIGIO.lightened(0.3))
	_lbl_luogo.clip_text = true
	dove.add_child(_lbl_ora)
	dove.add_child(_lbl_luogo)
	riga.add_child(dove)

	var orologi := _blocco_orologio("SIRIO", Stile.SABBIA)
	_lbl_padre = orologi[1]
	_bar_padre = orologi[2]
	riga.add_child(orologi[0])
	var orologi2 := _blocco_orologio("SARA", Stile.ROSSO)
	_lbl_figlia = orologi2[1]
	_bar_figlia = orologi2[2]
	riga.add_child(orologi2[0])

	var bisogni := VBoxContainer.new()
	bisogni.alignment = BoxContainer.ALIGNMENT_CENTER
	bisogni.custom_minimum_size = Vector2(170, 0)
	var r1 := HBoxContainer.new()
	r1.add_child(_icona(PixelArt.icona_ui("sonno"), 28))
	_lbl_sonno = Stile.etichetta("", 18, Stile.CHIARO)
	r1.add_child(_lbl_sonno)
	var r2 := HBoxContainer.new()
	r2.add_child(_icona(PixelArt.icona_ui("fame"), 28))
	_lbl_fame = Stile.etichetta("", 18, Stile.CHIARO)
	r2.add_child(_lbl_fame)
	bisogni.add_child(r1)
	bisogni.add_child(r2)
	riga.add_child(bisogni)

	var ris := GridContainer.new()
	ris.columns = 3
	ris.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ris.add_theme_constant_override("h_separation", 8)
	ris.add_theme_constant_override("v_separation", 0)
	for def in RISORSE:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 2)
		h.add_child(_icona(PixelArt.icona_risorsa(def[0]), 26))
		var v := Stile.etichetta("0", 18, Stile.CHIARO)
		v.custom_minimum_size = Vector2(38, 0)
		h.add_child(v)
		h.tooltip_text = def[2]
		ris.add_child(h)
		_val_ris[def[0]] = v
	riga.add_child(ris)

	var tocca := Button.new()
	tocca.flat = true
	tocca.focus_mode = Control.FOCUS_NONE
	tocca.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for n in ["normal", "hover", "pressed", "focus"]:
		tocca.add_theme_stylebox_override(n, StyleBoxEmpty.new())
	tocca.pressed.connect(func(): _apri_taccuino("stato"))
	p.add_child(tocca)
	return p


func _blocco_orologio(nome: String, colore: Color) -> Array:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(190, 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.add_child(Stile.etichetta(nome, 15, Stile.GRIGIO.lightened(0.3)))
	var l := Stile.etichetta("", 26, colore)
	v.add_child(l)
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 10)
	b.add_theme_stylebox_override("fill", Stile.barra(colore))
	v.add_child(b)
	return [v, l, b]


func _icona(t: Texture2D, lato: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.custom_minimum_size = Vector2(lato, lato)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _costruisci_scena() -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)

	var testa := Control.new()
	testa.custom_minimum_size = Vector2(0, 150)
	testa.clip_contents = true
	v.add_child(testa)
	_img_luogo = TextureRect.new()
	_img_luogo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_img_luogo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img_luogo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	testa.add_child(_img_luogo)
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.45)
	velo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	velo.offset_top = -66
	testa.add_child(velo)
	var testo := VBoxContainer.new()
	testo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	testo.offset_top = -66
	testo.offset_left = 16
	testo.offset_right = -16
	testo.add_theme_constant_override("separation", 0)
	_lbl_nome_luogo = Stile.etichetta("", Stile.TITOLI, Stile.SABBIA)
	_lbl_nome_luogo.add_theme_color_override("font_shadow_color", Color.BLACK)
	_lbl_nome_luogo.add_theme_constant_override("shadow_offset_x", 2)
	_lbl_nome_luogo.add_theme_constant_override("shadow_offset_y", 2)
	_lbl_desc_luogo = Stile.etichetta("", 17, Stile.CHIARO)
	_lbl_desc_luogo.clip_text = true
	testo.add_child(_lbl_nome_luogo)
	testo.add_child(_lbl_desc_luogo)
	testa.add_child(testo)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lato in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + lato, 12)
	scroll.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	m.add_child(col)
	col.add_child(Stile.etichetta("COSA PUOI FARE QUI", 18, Stile.GRIGIO.lightened(0.2)))
	_vuoto = Stile.etichetta("Qui non c'è altro da fare. Apri la mappa o il telefono.", 19, Stile.GRIGIO.lightened(0.3))
	_vuoto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_vuoto)
	_griglia = GridContainer.new()
	_griglia.columns = 2
	_griglia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_griglia.add_theme_constant_override("h_separation", 10)
	_griglia.add_theme_constant_override("v_separation", 10)
	col.add_child(_griglia)
	return v


func _costruisci_diario() -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(LARGHEZZA_DIARIO, 0)
	p.add_theme_stylebox_override("panel", Stile.box(Color("0f0f1c"), Stile.GRIGIO, 3, 10))
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(Stile.etichetta("DIARIO", 20, Stile.GRIGIO.lightened(0.3)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_diario = VBoxContainer.new()
	_diario.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diario.add_theme_constant_override("separation", 8)
	scroll.add_child(_diario)
	return p


func _costruisci_basso() -> Control:
	var riga := HBoxContainer.new()
	riga.custom_minimum_size = Vector2(0, BASSO)
	riga.add_theme_constant_override("separation", 4)
	_btn_tel = _bottone_nav("TELEFONO", "telefono", _apri_telefono)
	_btn_mappa = _bottone_nav("MAPPA", "mappa", _apri_mappa)
	_btn_taccuino = _bottone_nav("TACCUINO", "taccuino", func(): _apri_taccuino("strade"))
	riga.add_child(_btn_tel)
	riga.add_child(_btn_mappa)
	riga.add_child(_btn_taccuino)
	return riga


func _bottone_nav(testo: String, icona: String, azione: Callable) -> Button:
	var b := Button.new()
	b.text = "  " + testo
	b.icon = ImageTexture.create_from_image(PixelArt.ingrandisci(PixelArt.icona_ui(icona).get_image(), 3))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(func():
		_s("click")
		if _modale == null:
			azione.call())
	return b


# =============================================================== aggiornamenti

func _aggiorna() -> void:
	_aggiorna_alto()
	_aggiorna_scena()
	_aggiorna_tel()
	if _pannello != null and _rinfresca_pannello.is_valid():
		_rinfresca_pannello.call()


func _aggiorna_tel() -> void:
	var n := mondo.messaggi_non_letti()
	_btn_tel.text = "  TELEFONO" + ("  (%d)" % n if n > 0 else "")
	if n > 0:
		Stile.applica_bottone(_btn_tel, Stile.GIALLO)
	else:
		for k in ["normal", "hover", "pressed", "disabled"]:
			_btn_tel.remove_theme_stylebox_override(k)


func _aggiorna_alto() -> void:
	_lbl_ora.text = mondo.ora_testo()
	_lbl_luogo.text = MondoRun.luogo_dati(mondo.luogo).get("nome", "")
	_lbl_padre.text = _ore(stato.sabbia_padre_ore)
	_bar_padre.max_value = maxf(GameState.SABBIA_PADRE_INIZIALE, stato.sabbia_padre_ore)
	_bar_padre.value = stato.sabbia_padre_ore
	_lbl_figlia.text = _ore(stato.tempo_figlia_ore)
	_bar_figlia.max_value = GameState.TEMPO_FIGLIA_INIZIALE
	_bar_figlia.value = stato.tempo_figlia_ore
	_pulsa(_lbl_padre, "padre", stato.sabbia_padre_ore < SOGLIA_PULSE_ORE and not stato.is_over)
	_pulsa(_lbl_figlia, "figlia", stato.tempo_figlia_ore < SOGLIA_PULSE_ORE and not stato.is_over)
	var sonno := mondo.stato_sonno()
	var fame := mondo.stato_fame()
	_lbl_sonno.text = " " + str(sonno[0])
	_lbl_fame.text = " " + str(fame[0])
	_lbl_sonno.add_theme_color_override("font_color", [Stile.CHIARO, Stile.GIALLO, Color("e08030"), Stile.ROSSO][int(sonno[2])])
	_lbl_fame.add_theme_color_override("font_color", [Stile.CHIARO, Stile.GIALLO, Color("e08030"), Stile.ROSSO][int(fame[2])])
	var valori := {"polizia": stato.attenzione_polizia, "rivalita": stato.rivalita_criminale, "fama": stato.fama_pubblica,
		"karma": stato.karma, "fede": maxf(stato.fede_culto, stato.fede_setta)}
	var critico := {}
	for k in valori:
		_val_ris[k].text = "%.0f" % valori[k]
		var c: bool = valori[k] <= -SOGLIA_CRITICA if k == "karma" else (k != "fede" and valori[k] >= SOGLIA_CRITICA)
		critico[k] = c
		_val_ris[k].add_theme_color_override("font_color", Stile.ROSSO if c else Stile.CHIARO)
		if c and not _critico_prima.get(k, false):
			_scuoti(_val_ris[k].get_parent())
			_s("critica")
	_critico_prima = critico


func _ore(v: float) -> String:
	if absf(v) >= 1000.0:
		return Stile.ore(v)
	return "%.1f ore" % v


func _pulsa(nodo: Control, chiave: String, attivo: bool) -> void:
	var tw: Tween = _pulse.get(chiave)
	if attivo:
		if tw != null and tw.is_valid():
			return
		nodo.pivot_offset = Vector2(0.0, nodo.size.y * 0.5)
		tw = create_tween().set_loops()
		tw.tween_property(nodo, "scale", Vector2(1.15, 1.15), 0.25)
		tw.tween_property(nodo, "scale", Vector2.ONE, 0.25)
		_pulse[chiave] = tw
	elif tw != null:
		tw.kill()
		_pulse.erase(chiave)
		nodo.scale = Vector2.ONE


func _scuoti(nodo: Control) -> void:
	var base := nodo.position
	var tw := create_tween()
	for i in 4:
		tw.tween_property(nodo, "position:x", base.x + (3.0 if i % 2 == 0 else -3.0), 0.025)
	tw.tween_property(nodo, "position:x", base.x, 0.025)


func _aggiorna_scena() -> void:
	var l := MondoRun.luogo_dati(mondo.luogo)
	_img_luogo.texture = PixelArt.scena_luogo(l.get("tipo", "casa"))
	_lbl_nome_luogo.text = str(l.get("nome", "")).to_upper()
	_lbl_desc_luogo.text = l.get("descrizione", "")
	for c in _griglia.get_children():
		c.queue_free()
	var voci := mondo.azioni_qui()
	_vuoto.visible = voci.is_empty()
	for voce in voci:
		_griglia.add_child(_carta(voce))


func _carta(voce: Dictionary) -> CartaUI:
	var carta: CartaUI
	match voce.tipo:
		"azione":
			var a: ActionData = voce.azione
			var netto := a.effetto_sabbia_padre_ore - a.costo_tempo_figlia_ore
			var det := "Dura %s   Rende %s\nPer Sirio, se riesce: %s" % [Stile.ore(a.costo_tempo_figlia_ore), Stile.ore(a.effetto_sabbia_padre_ore, true), Stile.ore(netto, true)]
			carta = CartaUI.new(a.categoria, a.nome, det, a.rischio_pct)
			if voce.nota != "":
				carta.imposta_badge(voce.nota, Stile.GRIGIO.lightened(0.3))
			elif a.costo_tempo_figlia_ore >= stato.sabbia_padre_ore:
				carta.imposta_badge("Ti restano %s: rischi di non arrivare in fondo" % Stile.ore(stato.sabbia_padre_ore), Stile.ROSSO)
			elif a.unica_per_run:
				carta.imposta_badge("Una sola volta a settimana", Stile.GIALLO)
		"speciale":
			var sp: Dictionary = voce.speciale
			var det2: String = sp.get("descrizione", "")
			if float(sp.get("ore", 0.0)) > 0.0:
				det2 += "\nDura %s" % Stile.ore(float(sp.ore))
			carta = CartaUI.new("Narrativo", sp.testo, det2)
		"sottotrama":
			var sub: SubplotData = voce.sottotrama
			carta = CartaUI.new("Grande colpo", TestiDemo.nome_sottotrama_visibile(sub.nome), "Dura %s   Rende %s" % [Stile.ore(sub.costo_tempo_figlia_ore), Stile.ore(sub.effetto_sabbia_padre_ore, true)], sub.rischio_pct)
			carta.imposta_badge(voce.nota if voce.nota != "" else "PISTA DEL TACCUINO", Stile.GIALLO)
		"dona":
			carta = CartaUI.new("Altruismo", "Donare a Sara", voce.speciale.descrizione)
			carta.imposta_badge("Puoi donare anche una sola ora", Stile.SABBIA)
		"cashin":
			var combo: Array = stato.combo_tracce()
			var molt: float = GameState.SINERGIA_MOLTIPLICATORI.get(combo.size(), GameState.SINERGIA_MOLTIPLICATORI[4])
			carta = CartaUI.new("Grande colpo", voce.speciale.testo, "%s\nStrade: %s. Moltiplicatore x%.0f. Se fallisce perdi tutti quei ranghi." % [voce.speciale.descrizione, ", ".join(combo), molt], GameState.CASH_IN_RISCHIO_PCT)
	carta.abilita(voce.disponibile and not stato.is_over)
	carta.premuta.connect(_su_voce.bind(voce))
	return carta


func _imposta_musica() -> void:
	if audio == null:
		return
	var voluta := "endgame" if stato.tempo_figlia_ore < SOGLIA_ENDGAME_ORE else "gameplay"
	if voluta != _musica:
		_musica = voluta
		audio.suona_musica(voluta)


func _scrivi(testo: String, colore: Color = Stile.CHIARO) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(Stile.etichetta(mondo.ora_testo(), 14, Stile.GRIGIO.lightened(0.2)))
	var l := Stile.etichetta(testo, 17, colore)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(LARGHEZZA_DIARIO - 40, 0)
	box.add_child(l)
	_diario.add_child(box)
	_diario.move_child(box, 0)
	while _diario.get_child_count() > 60:
		var ultimo := _diario.get_child(_diario.get_child_count() - 1)
		_diario.remove_child(ultimo)
		ultimo.queue_free()


func _notifica(testo: String) -> void:
	_scrivi(testo, Stile.GIALLO)
	_toast_coda.append(testo)
	_mostra_toast_successivo()


func _mostra_toast_successivo() -> void:
	if _toast_attivo or _toast_coda.is_empty():
		return
	_toast_attivo = true
	_toast.text = _toast_coda.pop_front()
	_toast.visible = true
	_toast.modulate.a = 0.0
	_toast.reset_size()
	_toast.position = Vector2(size.x - _toast.size.x - 20, ALTO + 12)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		_toast.visible = false
		_toast_attivo = false
		_mostra_toast_successivo())


# =============================================================== azioni

func _snapshot() -> Dictionary:
	return {"Polizia": stato.attenzione_polizia, "Rivalità": stato.rivalita_criminale, "Fama": stato.fama_pubblica,
		"Karma": stato.karma, "Fede del Culto": stato.fede_culto, "Fede della Setta": stato.fede_setta}


func _bloccato() -> bool:
	return _modale != null or stato.is_over


func _su_voce(voce: Dictionary) -> void:
	if _bloccato():
		return
	_s("click")
	_prima = _snapshot()
	match voce.tipo:
		"azione":
			var a: ActionData = voce.azione
			if a.costo_tempo_figlia_ore >= stato.sabbia_padre_ore:
				_conferma("Ne vale la pena?", "A Sirio restano %s. Questa azione ne chiede %s. Se va storta, non torna a casa." % [Stile.ore(stato.sabbia_padre_ore), Stile.ore(a.costo_tempo_figlia_ore)], "RISCHIO", func(): _esegui(mondo.esegui_azione(a.nome)))
			else:
				_esegui(mondo.esegui_azione(a.nome))
		"speciale":
			_esegui(mondo.esegui_speciale(voce.speciale.id))
		"sottotrama":
			_esegui(mondo.esegui_sottotrama(voce.sottotrama.nome))
		"dona":
			_apri_donazione()
		"cashin":
			_esegui(mondo.esegui_cashin())


## Punto unico in cui arriva l'esito di ogni scelta del giocatore.
func _esegui(esito: Dictionary, cerca_occasioni: bool = true) -> void:
	if esito.has("rifiutata"):
		_mostra_avviso(str(esito.motivo))
		return
	_gestisci_esito(esito)
	if cerca_occasioni:
		_controlla_occasione = true
	_aggiorna()
	_esegui_coda()


func _gestisci_esito(esito: Dictionary) -> void:
	var dopo := _snapshot()
	for t in esito.get("testi", []):
		if str(t) != "":
			_scrivi(str(t))
	var risultati: Array = esito.get("risultati", [])
	for i in risultati.size():
		var ris: Dictionary = risultati[i]
		var r: Dictionary = ris.r
		var ok := bool(r.get("successo", false))
		_scrivi("%s. %s" % [ris.titolo, ris.testo], Stile.VERDE.lightened(0.35) if ok else Stile.ROSSO.lightened(0.2))
		var righe := PackedStringArray()
		var costo: float = r.get("costo_tempo_figlia_ore", 0.0)
		var effetto: float = r.get("effetto_sabbia_padre_ore", 0.0)
		if costo > 0.0:
			righe.append("Passano %s per entrambi" % Stile.ore(costo))
		if effetto != 0.0:
			righe.append("Sabbia %s" % Stile.ore(effetto, true))
		if i == risultati.size() - 1:
			for k in dopo:
				var d: float = dopo[k] - float(_prima.get(k, dopo[k]))
				if absf(d) >= 0.5:
					righe.append("%s %+.0f" % [k, d])
		if effetto > costo:
			_s("guadagno")
		elif costo > 0.0:
			_s("perdita")
		var titolo: String = ris.titolo
		var testo: String = ris.testo
		var deltas := "\n".join(righe)
		_coda.append(func(): _mostra_dado(titolo, r.get("roll"), ok, testo, deltas))
		var ev = r.get("evento_casuale")
		if ev != null and not ev.is_empty():
			_coda.append(func(): _mostra_evento(ev))
		if ok and str(ris.titolo).contains(": ") and r.has("roll") and stato.bivio_disponibile(TestiDemo.BIVIO_AGGANCIO) and not stato.tracce_raggiunte.is_empty():
			_coda_bivio(TestiDemo.BIVIO_AGGANCIO)
	_prima = dopo
	for n in esito.get("notifiche", []):
		_notifica(str(n))
	while not mondo.notifiche.is_empty():
		_notifica(mondo.notifiche.pop_front())


func _coda_bivio(id: String) -> void:
	if stato.bivio_disponibile(id):
		_coda.append(func(): _mostra_bivio(id))


func _esegui_coda() -> void:
	if _modale != null:
		return
	if _coda.is_empty():
		_dopo_coda()
		return
	var passo: Callable = _coda.pop_front()
	passo.call()


func _dopo_coda() -> void:
	_aggiorna()
	_imposta_musica()
	if stato.is_over:
		_mostra_fine()
		return
	if _controlla_occasione:
		_controlla_occasione = false
		var oc := mondo.cerca_occasione(false)
		if not oc.is_empty():
			_mostra_occasione(oc)
			return
	if stato.sabbia_padre_ore < SOGLIA_POCHE_ORE and stato.bivio_disponibile(TestiDemo.BIVIO_POCHE_ORE):
		_coda_bivio(TestiDemo.BIVIO_POCHE_ORE)
		_esegui_coda()


# =============================================================== modali

func _nuovo_modale(larghezza: float = 760.0) -> VBoxContainer:
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.8)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	_strato.add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)
	var pannello := PanelContainer.new()
	pannello.custom_minimum_size = Vector2(minf(larghezza, size.x - 40.0), 0)
	pannello.add_theme_stylebox_override("panel", Stile.box(Color("12122a"), Stile.SABBIA, 4, 20))
	centro.add_child(pannello)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pannello.add_child(v)
	_modale = fondo
	return v


func _chiudi_modale() -> void:
	if _modale != null:
		_modale.queue_free()
		_modale = null
	_aggiorna()
	_esegui_coda()


func _grande(testo: String, colore: Color, altezza: float = 96.0) -> Button:
	var b := Button.new()
	b.text = testo
	b.custom_minimum_size = Vector2(0, altezza)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22)
	Stile.applica_bottone(b, colore)
	return b


func _testo(testo: String, dimensione: int = 20, colore: Color = Stile.CHIARO) -> Label:
	var l := Stile.etichetta(testo, dimensione, colore)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _mostra_avviso(testo: String) -> void:
	_notifica(testo)


func _conferma(titolo: String, testo: String, si: String, azione: Callable) -> void:
	var v := _nuovo_modale(680.0)
	v.add_child(Stile.etichetta(titolo.to_upper(), Stile.TITOLI, Stile.ROSSO))
	v.add_child(_testo(testo))
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 14)
	v.add_child(riga)
	var b1 := _grande(si, Stile.ROSSO)
	var b2 := _grande("LASCIA STARE", Stile.GRIGIO)
	riga.add_child(b1)
	riga.add_child(b2)
	b2.pressed.connect(func():
		_s("click")
		_chiudi_modale())
	b1.pressed.connect(func():
		_s("click")
		_modale.queue_free()
		_modale = null
		azione.call())


func _mostra_dado(titolo: String, roll, successo: bool, testo: String, deltas: String) -> void:
	var v := _nuovo_modale()
	var t := _testo(titolo, Stile.TITOLI, Stile.SABBIA)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var dado := TextureRect.new()
	dado.custom_minimum_size = Vector2(150, 150)
	dado.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dado.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dado.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dado.texture = PixelArt.dado_frame(0)
	dado.pivot_offset = Vector2(75, 75)
	dado.visible = roll != null
	v.add_child(dado)
	var lbl_tiro := _testo(_descrivi_tiro(roll), 18)
	lbl_tiro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var critico: bool = roll != null and (roll.successo_critico or roll.fallimento_critico)
	var lbl_esito := Stile.etichetta(("SUCCESSO" if successo else "FALLIMENTO") + (" CRITICO" if critico else ""), 34, Stile.VERDE.lightened(0.3) if successo else Stile.ROSSO)
	lbl_esito.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lbl_testo := _testo(testo)
	lbl_testo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lbl_delta := _testo(deltas, 19, Stile.SABBIA)
	lbl_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for n in [lbl_tiro, lbl_esito, lbl_testo, lbl_delta]:
		n.modulate.a = 0.0
		v.add_child(n)
	var btn := _grande("CONTINUA", Stile.SABBIA)
	btn.disabled = true
	btn.pressed.connect(func():
		_s("click")
		_chiudi_modale())
	v.add_child(btn)
	var numero := -1
	if roll != null and not roll.senza_tiro:
		numero = roll.naturale
	var tw := create_tween()
	if roll != null:
		_s("dado")
		for i in 11:
			tw.tween_callback(func(): dado.texture = PixelArt.dado_frame(i % 5))
			tw.tween_interval(0.08)
		tw.tween_callback(func():
			dado.texture = PixelArt.dado_frame(5, numero, Color("3d7a5a") if successo else Stile.ROSSO)
			dado.scale = Vector2(1.3, 1.3)
			create_tween().tween_property(dado, "scale", Vector2.ONE, 0.2))
	for n in [lbl_tiro, lbl_esito, lbl_testo, lbl_delta]:
		tw.tween_property(n, "modulate:a", 1.0, 0.18)
	tw.tween_callback(func(): btn.disabled = false)


func _descrivi_tiro(roll) -> String:
	if roll == null:
		return ""
	if roll.senza_tiro:
		return "Nessun tiro: l'esito era scritto."
	var mod := ""
	var m := mondo.malus_bisogni()
	if int(m.modificatore) < 0:
		mod = "  (fame e sonno: %d)" % int(m.modificatore)
	if roll.dadi.size() == 1:
		return "Tiro %d, modificatore %+d: %d contro %d%s" % [roll.dadi[0], roll.modificatore, roll.totale, roll.cd, mod]
	return "Dadi %s, tenuto %d, modificatore %+d: %d contro %d%s" % [str(roll.dadi), roll.naturale, roll.modificatore, roll.totale, roll.cd, mod]


func _mostra_evento(ev: Dictionary) -> void:
	if ev.get("tipo", "") == "patto_stregatto_proposto":
		_mostra_patto(ev)
		return
	var nome: String = ev.get("azione", "Evento")
	var ok := bool(ev.get("successo", false))
	var eff: float = ev.get("effetto_sabbia_padre_ore", 0.0)
	_scrivi("Imprevisto: %s" % nome, Stile.GIALLO)
	_mostra_dado("Imprevisto: " + nome, ev.get("roll"), ok, TestiDemo.esito_azione(nome, ok), ("Sabbia %s" % Stile.ore(eff, true)) if eff != 0.0 else "")


func _mostra_patto(ev: Dictionary) -> void:
	_s("critica")
	var v := _nuovo_modale(860.0)
	v.add_child(Stile.etichetta("DOLCE VOLPE", Stile.TITOLI, Stile.ROSSO))
	v.add_child(_testo(str(ev.get("testo", ""))))
	var prezzo: float = ev.get("prezzo_ore", 0.0)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 14)
	v.add_child(riga)
	var si := _grande("ACCETTO\nPrezzo %s, Karma +%.0f" % [Stile.ore(prezzo), GameState.STREGATTO_KARMA_EFFETTO], Stile.ROSSO, 120.0)
	var no := _grande("RIFIUTO\nIl Karma resta com'è", Stile.GRIGIO, 120.0)
	riga.add_child(si)
	riga.add_child(no)
	si.pressed.connect(func():
		_s("click")
		var r := stato.risolvi_patto_stregatto(true)
		_scrivi(Narrativa.patto_accettato(r.get("prezzo_ore", prezzo), r.get("karma_ottenuto", 0.0), stato.karma), Stile.ROSSO)
		_chiudi_modale())
	no.pressed.connect(func():
		_s("click")
		stato.risolvi_patto_stregatto(false)
		_scrivi(Narrativa.patto_rifiutato(), Stile.GRIGIO.lightened(0.3))
		_chiudi_modale())


func _mostra_bivio(id: String) -> void:
	var bivio := TestiDemo.bivio(id)
	var v := _nuovo_modale(940.0)
	v.add_child(Stile.etichetta(bivio.trigger.to_upper(), Stile.TITOLI, Stile.SABBIA))
	v.add_child(_testo(TestiDemo.TESTO_BIVIO.get(id, "")))
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 14)
	v.add_child(riga)
	for i in bivio.opzioni.size():
		var o: BivioSystem.Opzione = bivio.opzioni[i]
		var b := _grande("%s\n\n%s" % [o.nome.to_upper(), o.descrizione], [Stile.VERDE, Stile.ROSSO, Stile.GRIGIO][i % 3], 190.0)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func():
			_s("click")
			_prima = _snapshot()
			stato.applica_bivio(bivio, i)
			TestiDemo.applica_effetti_bivio(stato, id, i)
			_prima = _snapshot()
			_scrivi("%s: %s." % [bivio.trigger, o.nome], Stile.SABBIA)
			_chiudi_modale())
		riga.add_child(b)


func _mostra_occasione(oc: Dictionary) -> void:
	_s("critica")
	var v := _nuovo_modale(880.0)
	v.add_child(Stile.etichetta(str(oc.titolo).to_upper(), Stile.TITOLI, Stile.GIALLO))
	v.add_child(_testo(str(oc.testo)))
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 14)
	v.add_child(riga)
	var scelte: Array = oc.scelte
	for i in scelte.size():
		var b := _grande(str(scelte[i].testo).to_upper(), [Stile.SABBIA, Stile.ROSSO, Stile.GRIGIO][i % 3], 110.0)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func():
			_s("click")
			_modale.queue_free()
			_modale = null
			_prima = _snapshot()
			_scrivi("%s: %s." % [oc.titolo, scelte[i].testo], Stile.GIALLO)
			_esegui(mondo.risolvi_occasione(oc.id, i), false))
		riga.add_child(b)


# =============================================================== donazione

func _apri_donazione() -> void:
	var massimo := stato.sabbia_padre_ore
	var valore := [minf(1.0, massimo)]
	var v := _nuovo_modale(760.0)
	v.add_child(Stile.etichetta("DONARE A SARA", Stile.TITOLI, Stile.ROSSO))
	v.add_child(_testo("Quanta della tua sabbia vuoi darle? Puoi donare anche una sola ora. Si fa una volta sola: dopo, la settimana finisce.", 19))
	var lbl := Stile.etichetta("", 44, Stile.SABBIA)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl)
	var info := Stile.etichetta("", 18, Stile.GRIGIO.lightened(0.3))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var aggiorna := func():
		lbl.text = Stile.ore(valore[0])
		info.text = "Sirio resterebbe con %s. Sara arriverebbe a %s." % [Stile.ore(massimo - valore[0]), Stile.ore(stato.tempo_figlia_ore + valore[0])]
	aggiorna.call()
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 8)
	v.add_child(riga)
	for passo in [-10.0, -1.0, 1.0, 10.0]:
		var b := _grande("%+.0f" % passo, Stile.GRIGIO, 80.0)
		b.pressed.connect(func():
			_s("click")
			valore[0] = clampf(snappedf(valore[0] + passo, 0.1), minf(0.1, massimo), massimo)
			aggiorna.call())
		riga.add_child(b)
	var riga2 := HBoxContainer.new()
	riga2.add_theme_constant_override("separation", 8)
	v.add_child(riga2)
	for def in [["UN'ORA", 1.0], ["METÀ", 0.5], ["TUTTO", -1.0]]:
		var b := _grande(def[0], Stile.SABBIA, 72.0)
		b.pressed.connect(func():
			_s("click")
			if def[1] < 0.0:
				valore[0] = massimo
			elif def[1] == 0.5:
				valore[0] = snappedf(massimo * 0.5, 0.1)
			else:
				valore[0] = minf(1.0, massimo)
			aggiorna.call())
		riga2.add_child(b)
	var riga3 := HBoxContainer.new()
	riga3.add_theme_constant_override("separation", 14)
	v.add_child(riga3)
	var dona := _grande("DONO", Stile.ROSSO)
	var annulla := _grande("ANCORA NO", Stile.GRIGIO)
	riga3.add_child(dona)
	riga3.add_child(annulla)
	annulla.pressed.connect(func():
		_s("click")
		_chiudi_modale())
	dona.pressed.connect(func():
		_s("click")
		var esito := mondo.dona(valore[0])
		_modale.queue_free()
		_modale = null
		if not esito.get("successo", false):
			_mostra_avviso(str(esito.get("motivo", "")))
			_esegui_coda()
			return
		_scrivi("Hai donato %s a Sara." % Stile.ore(valore[0]), Stile.SABBIA)
		_esegui_coda())


# =============================================================== pannelli

func _apri_pannello(titolo: String) -> VBoxContainer:
	_chiudi_pannello()
	var fondo := ColorRect.new()
	fondo.color = Color("08080f")
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	_strato.add_child(fondo)
	_pannello = fondo
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lato in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + lato, 12)
	fondo.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	var testa := HBoxContainer.new()
	v.add_child(testa)
	var t := Stile.etichetta(titolo, Stile.TITOLI, Stile.SABBIA)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	testa.add_child(t)
	var chiudi := Button.new()
	chiudi.text = "CHIUDI"
	chiudi.custom_minimum_size = Vector2(160, 64)
	chiudi.pressed.connect(func():
		_s("click")
		_chiudi_pannello())
	testa.add_child(chiudi)
	return v


func _chiudi_pannello() -> void:
	if _pannello != null:
		_pannello.queue_free()
		_pannello = null
	_rinfresca_pannello = Callable()


func _scroll_in(v: VBoxContainer) -> VBoxContainer:
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(s)
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 10)
	s.add_child(c)
	return c


func _svuota(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


# ------------------------------------------------------------- telefono

func _apri_telefono() -> void:
	var v := _apri_pannello("TELEFONO")
	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 12)
	v.add_child(corpo)
	var sinistra := VBoxContainer.new()
	sinistra.custom_minimum_size = Vector2(380, 0)
	corpo.add_child(sinistra)
	var lista := _scroll_in(sinistra)
	var schermo := PanelContainer.new()
	schermo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	schermo.add_theme_stylebox_override("panel", Stile.box(Color("0a0a14"), Color("2a2a3a"), 6, 12))
	corpo.add_child(schermo)
	var destra := VBoxContainer.new()
	destra.add_theme_constant_override("separation", 10)
	schermo.add_child(destra)
	var selezionato := [""]
	var mostra_lista := func():
		_svuota(lista)
		var n := mondo.messaggi_non_letti()
		var bm := _riga_telefono("Messaggi", "%d non letti" % n if n > 0 else "Nessuno nuovo", n > 0)
		bm.pressed.connect(func():
			_s("click")
			selezionato[0] = "@messaggi"
			_rinfresca_pannello.call())
		lista.add_child(bm)
		lista.add_child(Stile.etichetta("RUBRICA", 17, Stile.GRIGIO.lightened(0.3)))
		for c in mondo.contatti_visibili():
			var novita := false
			for o in mondo.opzioni_contatto(c.id):
				if not o.get("ripetibile", false):
					novita = true
			var b := _riga_telefono(c.nome, c.ruolo, novita)
			var cid: String = c.id
			b.pressed.connect(func():
				_s("click")
				selezionato[0] = cid
				_rinfresca_pannello.call())
			lista.add_child(b)
	var mostra_schermo := func():
		_svuota(destra)
		if selezionato[0] == "":
			destra.add_child(_testo("Scegli un contatto. Chi conosci decide cosa puoi fare a Ledune. Il pallino giallo indica qualcuno che ha qualcosa di nuovo da dirti.", 19, Stile.GRIGIO.lightened(0.3)))
		elif selezionato[0] == "@messaggi":
			_vista_messaggi(destra)
		else:
			_vista_chat(destra, selezionato[0])
	_rinfresca_pannello = func():
		mostra_lista.call()
		mostra_schermo.call()
	_rinfresca_pannello.call()


func _riga_telefono(titolo: String, sotto: String, novita: bool) -> Button:
	var b := Button.new()
	b.text = ("● " if novita else "   ") + titolo + "\n   " + sotto
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 84)
	b.add_theme_font_size_override("font_size", 19)
	if novita:
		b.add_theme_color_override("font_color", Stile.GIALLO)
	return b


func _vista_messaggi(destra: VBoxContainer) -> void:
	destra.add_child(Stile.etichetta("MESSAGGI", 22, Stile.SABBIA))
	var c := _scroll_in(destra)
	if mondo.messaggi.is_empty():
		c.add_child(_testo("Nessun messaggio.", 19, Stile.GRIGIO))
	for i in range(mondo.messaggi.size() - 1, -1, -1):
		var m: Dictionary = mondo.messaggi[i]
		var nome: String = MondoRun.contatto_dati(m.da).get("nome", m.da)
		c.add_child(_fumetto(nome + "\n" + str(m.testo), false, not m.letto))
	mondo.segna_letti()
	_aggiorna_tel()


func _fumetto(testo: String, mio: bool, evidenza: bool = false) -> Control:
	var riga := HBoxContainer.new()
	var spazio := Control.new()
	spazio.custom_minimum_size = Vector2(60, 0)
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var colore := Color("3a2e1e") if mio else Color("1a2440")
	p.add_theme_stylebox_override("panel", Stile.box(colore, Stile.GIALLO if evidenza else colore.lightened(0.2), 2, 12))
	p.add_child(_testo(testo, 19, Stile.CHIARO))
	if mio:
		riga.add_child(spazio)
		riga.add_child(p)
	else:
		riga.add_child(p)
		riga.add_child(spazio)
	return riga


func _vista_chat(destra: VBoxContainer, cid: String) -> void:
	var c := MondoRun.contatto_dati(cid)
	destra.add_child(Stile.etichetta("%s  ·  %s" % [c.nome, c.ruolo], 22, Stile.SABBIA))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	destra.add_child(scroll)
	var bolle := VBoxContainer.new()
	bolle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bolle.add_theme_constant_override("separation", 8)
	scroll.add_child(bolle)
	if not _chat.has(cid):
		_chat[cid] = [[false, str(c.saluto)]]
	for voce in _chat[cid]:
		if voce[0] is String:
			bolle.add_child(_testo(str(voce[1]), 17, Stile.GIALLO))
		else:
			bolle.add_child(_fumetto(str(voce[1]), bool(voce[0])))
	var opzioni := mondo.opzioni_contatto(cid)
	if opzioni.is_empty():
		bolle.add_child(_testo("Non avete altro da dirvi, per ora.", 17, Stile.GRIGIO.lightened(0.2)))
	for o in opzioni:
		var b := Button.new()
		b.text = str(o.testo)
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.custom_minimum_size = Vector2(0, 76)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 19)
		Stile.applica_bottone(b, Stile.SABBIA)
		var oid: String = o.id
		b.pressed.connect(func(): _su_opzione(cid, oid, str(o.testo)))
		bolle.add_child(b)
	scroll.call_deferred("set_v_scroll", 100000)


func _su_opzione(cid: String, oid: String, testo: String) -> void:
	if _bloccato():
		return
	_s("click")
	_prima = _snapshot()
	var esito := mondo.scegli_opzione(cid, oid)
	if esito.has("rifiutata"):
		_mostra_avviso(str(esito.motivo))
		return
	_chat[cid].append([true, testo])
	_chat[cid].append([false, str(esito.get("risposta", ""))])
	for ris in esito.risultati:
		_chat[cid].append(["", "%s: %s" % [ris.titolo, "riuscito" if ris.r.successo else "andato male"]])
	for n in esito.notifiche:
		_chat[cid].append(["", str(n)])
	_scrivi("Telefonata con %s." % MondoRun.contatto_dati(cid).nome, Stile.GRIGIO.lightened(0.3))
	_esegui(esito)


# ------------------------------------------------------------- mappa

func _apri_mappa() -> void:
	var v := _apri_pannello("MAPPA DI LEDUNE")
	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 12)
	v.add_child(corpo)
	var area := Control.new()
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.clip_contents = true
	corpo.add_child(area)
	var img := TextureRect.new()
	img.texture = PixelArt.mappa_ledune()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	area.add_child(img)
	var scheda := PanelContainer.new()
	scheda.custom_minimum_size = Vector2(340, 0)
	scheda.add_theme_stylebox_override("panel", Stile.box(Color("12122a"), Stile.GRIGIO, 3, 14))
	corpo.add_child(scheda)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 12)
	scheda.add_child(info)
	var pin: Dictionary = {}
	var selezionato := [mondo.luogo]
	var mostra_info := func():
		_svuota(info)
		var l := MondoRun.luogo_dati(selezionato[0])
		info.add_child(_testo(str(l.nome).to_upper(), 24, Stile.SABBIA))
		info.add_child(_testo(str(l.descrizione), 18))
		var n_azioni: int = l.get("azioni", []).size()
		if n_azioni > 0:
			info.add_child(_testo("Qui puoi fare %d cose, se hai i contatti giusti." % n_azioni, 17, Stile.GRIGIO.lightened(0.3)))
		if selezionato[0] == mondo.luogo:
			info.add_child(_testo("Sei qui.", 20, Stile.ROSSO))
		else:
			var ore := mondo.stima_viaggio(selezionato[0])
			var mezzo := "in macchina" if mondo.auto and mondo.benzina > 0 else "a piedi e coi mezzi"
			info.add_child(_testo("Circa %s %s. Costa a Sirio e a Sara." % [Stile.ore(ore), mezzo], 18, Stile.CHIARO))
			var vai := _grande("VAI", Stile.ROSSO)
			var dest: String = selezionato[0]
			vai.pressed.connect(func(): _viaggia(dest))
			info.add_child(vai)
		if mondo.auto:
			info.add_child(_testo("Benzina per %d viaggi." % mondo.benzina, 16, Stile.GRIGIO.lightened(0.3)))
	var disponi := func():
		var s := area.size
		var scala := minf(s.x / 160.0, s.y / 100.0)
		var dim := Vector2(160, 100) * scala
		var origine := (s - dim) * 0.5
		img.position = origine
		img.size = dim
		for id in pin:
			var l := MondoRun.luogo_dati(id)
			var p: Vector2 = origine + Vector2(float(l.pos[0]) / 100.0 * dim.x, float(l.pos[1]) / 100.0 * dim.y)
			pin[id].position = p - Vector2(40, 52)
	for l in mondo.luoghi_visibili():
		var nodo := VBoxContainer.new()
		nodo.custom_minimum_size = Vector2(80, 80)
		nodo.add_theme_constant_override("separation", 0)
		var b := TextureButton.new()
		b.texture_normal = PixelArt.pin_luogo(str(l.tipo), l.id == mondo.luogo)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(80, 52)
		var lid: String = l.id
		b.pressed.connect(func():
			_s("click")
			selezionato[0] = lid
			mostra_info.call())
		nodo.add_child(b)
		var qui: bool = l.id == mondo.luogo
		var nome := Stile.etichetta(("SEI QUI\n" if qui else "") + str(l.nome), 13, Stile.ROSSO if qui else Stile.CHIARO)
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nome.add_theme_color_override("font_shadow_color", Color.BLACK)
		nome.add_theme_constant_override("shadow_offset_x", 1)
		nome.add_theme_constant_override("shadow_offset_y", 1)
		nome.custom_minimum_size = Vector2(80, 0)
		nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nodo.add_child(nome)
		area.add_child(nodo)
		pin[l.id] = nodo
	area.resized.connect(disponi)
	disponi.call_deferred()
	mostra_info.call()
	_rinfresca_pannello = Callable()


func _viaggia(dest: String) -> void:
	_chiudi_pannello()
	_s("click")
	var nome: String = MondoRun.luogo_dati(dest).nome
	var v := _nuovo_modale(600.0)
	var l := _testo("In viaggio verso %s..." % nome, 24, Stile.SABBIA)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_callback(func():
		_modale.queue_free()
		_modale = null
		_prima = _snapshot()
		var r := mondo.viaggia(dest)
		if r.has("rifiutata"):
			_mostra_avviso(str(r.motivo))
			return
		_scrivi("%s (%s)" % [r.testo, Stile.ore(r.ore)], Stile.CHIARO)
		var blocco := mondo.cerca_occasione(true)
		if not blocco.is_empty():
			_coda.append(func(): _mostra_occasione(blocco))
		_controlla_occasione = true
		_aggiorna()
		_esegui_coda())


# ------------------------------------------------------------- taccuino

func _apri_taccuino(scheda: String) -> void:
	var v := _apri_pannello("TACCUINO")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	var contenuto := _scroll_in(v)
	var corrente := [scheda]
	var bottoni := {}
	for def in [["strade", "Strade"], ["piste", "Piste"], ["stato", "Stato"], ["obiettivi", "Obiettivi"], ["opzioni", "Opzioni"]]:
		var b := Button.new()
		b.text = def[1]
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = def[0]
		b.pressed.connect(func():
			_s("click")
			corrente[0] = id
			_rinfresca_pannello.call())
		tabs.add_child(b)
		bottoni[id] = b
	_rinfresca_pannello = func():
		for id in bottoni:
			if id == corrente[0]:
				Stile.applica_bottone(bottoni[id], Stile.ROSSO)
			else:
				for k in ["normal", "hover", "pressed", "disabled"]:
					bottoni[id].remove_theme_stylebox_override(k)
		_svuota(contenuto)
		match corrente[0]:
			"strade":
				_scheda_strade(contenuto)
			"piste":
				_scheda_piste(contenuto)
			"stato":
				_scheda_stato(contenuto)
			"obiettivi":
				_scheda_obiettivi(contenuto)
			_:
				_scheda_opzioni(contenuto)
	_rinfresca_pannello.call()


func _scheda_strade(c: VBoxContainer) -> void:
	c.add_child(_testo("Le strade sono carriere lunghe. Non si scelgono da un elenco: te le offre qualcuno, quando hai dimostrato di valere. Due strade al rango più alto si possono incassare insieme, a casa.", 18, Stile.GRIGIO.lightened(0.3)))
	var chi := {"Lavoro": "gaetano", "Criminale": "shen", "Politica": "conti", "Azzardo": "marisa", "Bancaria": "bassi", "Religiosa (indulgenze)": "anselmo", "Occulto (setta satanica)": "morgana"}
	for nome in TrackDatabase.get_nomi_tracce_normali():
		var rango: int = stato.tracce_raggiunte.get(nome, 0)
		var cid: String = chi.get(nome, "")
		var noto: bool = mondo.contatti_noti.has(cid)
		var stato_testo := "Rango %d su 2" % rango
		for r in [1, 2]:
			if stato.azioni_uniche_usate.has("%s|%d" % [nome, r]) and rango < r:
				stato_testo += ", porta chiusa al rango %d" % r
		var chi_testo: String = ("Te la può aprire: %s" % MondoRun.contatto_dati(cid).nome) if noto else "Non conosci ancora chi può aprirtela."
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Stile.box(Color("14142a"), Stile.VERDE if rango > 0 else Stile.GRIGIO, 3, 12))
		var v := VBoxContainer.new()
		p.add_child(v)
		v.add_child(Stile.etichetta(str(nome).split(" (")[0].to_upper(), 22, Stile.SABBIA))
		v.add_child(_testo(stato_testo, 18))
		v.add_child(_testo(chi_testo, 17, Stile.GRIGIO.lightened(0.3)))
		c.add_child(p)
	var combo: Array = stato.combo_tracce()
	if not combo.is_empty():
		c.add_child(_testo("Puoi giocare insieme: %s. Torna a casa per mettere insieme i pezzi." % ", ".join(combo), 19, Stile.GIALLO))
	var malus: Array = stato.malus_attivi()
	if not malus.is_empty():
		var parti: Array[String] = []
		for coppia in malus:
			parti.append("%s e %s" % [coppia[0], coppia[1]])
		c.add_child(_testo("Tensione tra le tue strade: " + ", ".join(parti) + ".", 18, Stile.ROSSO))


func _scheda_piste(c: VBoxContainer) -> void:
	if mondo.piste.is_empty():
		c.add_child(_testo("Nessuna pista. Le storie grosse di Ledune si scoprono parlando con le persone giuste e girando per la città.", 19, Stile.GRIGIO.lightened(0.3)))
		return
	for nome in mondo.piste:
		var dove := ""
		for l in MondoRun.dati().luoghi:
			if l.get("sottotrame", []).has(nome):
				dove = l.nome
		var tentata: bool = stato.azioni_uniche_usate.has("sottotrama:%s" % nome)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Stile.box(Color("14142a"), Stile.GRIGIO if tentata else Stile.GIALLO, 3, 12))
		var v := VBoxContainer.new()
		p.add_child(v)
		v.add_child(Stile.etichetta(TestiDemo.nome_sottotrama_visibile(nome).to_upper(), 21, Stile.SABBIA))
		v.add_child(_testo("Dove: %s" % dove, 18))
		v.add_child(_testo("Già tentata" if tentata else "Da tentare. Una sola occasione.", 17, Stile.GRIGIO.lightened(0.3)))
		c.add_child(p)


func _scheda_stato(c: VBoxContainer) -> void:
	var sonno := mondo.stato_sonno()
	var fame := mondo.stato_fame()
	var m := mondo.malus_bisogni()
	c.add_child(Stile.etichetta("BISOGNI", 22, Stile.SABBIA))
	c.add_child(_testo("Sveglio da %s: %s.   Ultimo pasto %s fa: %s." % [Stile.ore(mondo.ore_sveglio), sonno[0], Stile.ore(mondo.ore_digiuno), fame[0]], 19))
	var effetto := "Nessun effetto sui tiri." if int(m.modificatore) == 0 else "Malus ai tiri: %d%s." % [int(m.modificatore), " e svantaggio" if m.modo == DiceSystem.RollMode.SVANTAGGIO else ""]
	c.add_child(_testo(effetto + " Una notte in bianco o un giorno senza mangiare si reggono. Due cominciano a pesare. Si dorme a casa, si mangia a casa, in piazza o alla stazione.", 18, Stile.GRIGIO.lightened(0.3)))
	c.add_child(HSeparator.new())
	c.add_child(Stile.etichetta("RISORSE", 22, Stile.SABBIA))
	var valori := {"polizia": stato.attenzione_polizia, "rivalita": stato.rivalita_criminale, "fama": stato.fama_pubblica, "karma": stato.karma, "fede": maxf(stato.fede_culto, stato.fede_setta)}
	for def in RISORSE:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		r.add_child(_icona(PixelArt.icona_risorsa(def[0]), 32))
		var t := _testo("%s %.0f. %s" % [def[1], valori[def[0]], def[2]], 18)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(t)
		c.add_child(r)
	c.add_child(HSeparator.new())
	c.add_child(_testo("Seed %d. Difficoltà %d. Giorno %d di 7." % [stato.seed_run, stato.livello_difficolta, mondo.giorno()], 17, Stile.GRIGIO.lightened(0.3)))


func _scheda_obiettivi(c: VBoxContainer) -> void:
	c.add_child(_testo("Ogni settimana ricomincia da capo. Quello che impari resta: certi traguardi ti lasciano un contatto o un luogo per le settimane successive.", 18, Stile.GRIGIO.lightened(0.3)))
	for ob in MondoRun.dati().get("obiettivi", []):
		var fatto: bool = persistente != null and persistente.obiettivi.has(ob.id)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Stile.box(Color("14142a"), Stile.VERDE if fatto else Stile.GRIGIO, 3, 12))
		var v := VBoxContainer.new()
		p.add_child(v)
		v.add_child(Stile.etichetta(("FATTO  " if fatto else "") + str(ob.testo), 20, Stile.SABBIA if fatto else Stile.CHIARO))
		v.add_child(_testo(str(ob.get("nota", "")) if fatto else "Ricompensa: ???", 17, Stile.GRIGIO.lightened(0.3)))
		c.add_child(p)


func _scheda_opzioni(c: VBoxContainer) -> void:
	for def in [["Volume generale", "volume_master"], ["Musica", "volume_musica"], ["Effetti", "volume_effetti"]]:
		c.add_child(Stile.etichetta(def[0], 18, Stile.GRIGIO.lightened(0.3)))
		var s := HSlider.new()
		s.custom_minimum_size = Vector2(0, 56)
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = audio.get(def[1]) if audio != null else 0.8
		var prop: String = def[1]
		s.value_changed.connect(func(x):
			if audio != null:
				audio.set(prop, x))
		c.add_child(s)
	var esci := _grande("TORNA AL TITOLO", Stile.GRIGIO)
	esci.pressed.connect(func():
		_s("click")
		_chiudi_pannello()
		_conferma("Tornare al titolo", "La settimana in corso va persa. Non si salva a metà.", "ESCI", func(): torna_al_titolo.emit()))
	c.add_child(esci)


func gestisci_indietro() -> void:
	if _modale != null:
		return
	if _pannello != null:
		_chiudi_pannello()
	else:
		_apri_taccuino("opzioni")


# =============================================================== fine

func _mostra_fine() -> void:
	if _fine_mostrata:
		return
	_fine_mostrata = true
	_chiudi_pannello()
	if _modale != null:
		_modale.queue_free()
		_modale = null
	var p := stato.calcola_punteggio()
	var note := _salva(p)
	var vittoria := stato.donation_made and stato.tempo_figlia_ore > 0.0
	if audio != null:
		audio.jingle("vittoria" if vittoria else "sconfitta")
	var titolo := "DONAZIONE COMPIUTA"
	if stato.end_reason == GameState.EndReason.FIGLIA_MORTA:
		titolo = "SARA NON CE L'HA FATTA"
	elif stato.end_reason == GameState.EndReason.PADRE_MORTO:
		titolo = "SIRIO SI SPEGNE"
	var v := _nuovo_modale(900.0)
	v.add_child(Stile.etichetta(titolo, Stile.TITOLI, Stile.SABBIA if vittoria else Stile.ROSSO))
	v.add_child(_testo(Narrativa.epilogo(stato.donation_made, stato.tempo_figlia_ore > 0.0, stato.sabbia_padre_ore > 0.0, stato.karma)))
	v.add_child(HSeparator.new())
	v.add_child(Stile.etichetta("Sirio: %.2f anni     Sara: %.2f anni     Totale: %.2f anni" % [p.padre_anni, p.figlia_anni, p.punteggio_totale_anni], 21, Stile.SABBIA))
	if p.vittoria_100_100:
		v.add_child(_testo("Cento anni a testa. Succede di rado, e non assolve nessuno.", 19, Stile.GIALLO))
	for n in note:
		v.add_child(_testo(str(n), 18, Stile.GIALLO))
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 14)
	v.add_child(riga)
	var nuova := _grande("NUOVA SETTIMANA", Stile.ROSSO)
	var tit := _grande("TITOLO", Stile.GRIGIO)
	riga.add_child(nuova)
	riga.add_child(tit)
	nuova.pressed.connect(func():
		_s("click")
		nuova_partita.emit())
	tit.pressed.connect(func():
		_s("click")
		torna_al_titolo.emit())


func _salva(p: Dictionary) -> Array:
	var note: Array = []
	if persistente != null:
		for n in mondo.valuta_obiettivi(persistente):
			note.append("Per le prossime settimane: " + str(n))
		persistente.salva()
	if profilo == null:
		return note
	profilo.karma = stato.karma
	profilo.livello_difficolta = stato.livello_difficolta
	if p.vittoria_100_100:
		profilo.traguardo_100_100_raggiunto = true
	if _e_seed_del_giorno:
		profilo.registra_punteggio_seed_del_giorno(SeedDelGiorno.data_di_oggi_stringa(), p)
	ContactNetwork.valuta_sblocchi(stato, profilo)
	profilo.save()
	return note
