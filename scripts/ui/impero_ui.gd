class_name ImperoUI
extends Control
## Interfaccia dell'impero di sabbia. In alto il tempo e lo stato di Sirio.
## Al centro il luogo che stai guardando e le cose che si possono fare lì: ogni
## cosa occupa una fascia di sei ore, poi la città gira. A destra il diario.
## In basso telefono, mappa, impero, taccuino. Nessuna regola qui: tutto passa
## da ImperoState.

signal torna_al_titolo
signal nuova_partita

const ALTO := 96
const BASSO := 84
const LARGHEZZA_DIARIO := 380
const SOGLIA_ENDGAME_ORE := 72.0
const SOGLIA_CRITICA := 75.0

const RISORSE := [
	["polizia", "Polizia", "Attenzione della polizia. Sale con bische, protezione e usura. Porta retate e rende più difficili i colpi."],
	["rivalita", "Rivalità", "Quanto ti odiano i rivali. Sale con la protezione e le bische. Porta assalti."],
	["fama", "Fama", "Quanto si parla di te. Sale col culto. Porta scandali."],
	["karma", "Karma", "Ti segue da una partita all'altra. Sotto -50 Dolce Volpe si fa viva."],
]

const CATEGORIA_TIPO := {
	"lavoro": "Lavoro", "colpo": "Furto", "recluta": "Crimine organizzato", "corrompi": "Corruzione",
	"tributo": "Relazioni", "informatore": "Corruzione", "dormi": "Bisogni", "mangia": "Bisogni",
	"visita": "Altruismo", "dona": "Altruismo", "liquida": "Compravendita", "riscuoti": "Crimine organizzato",
	"luogotenente": "Crimine organizzato", "mossa": "Grande colpo", "parla": "Relazioni",
}
const CATEGORIA_GIRO := {
	"usura": "Crimine organizzato", "protezione": "Minaccia 1 a 1", "bische": "Azzardo",
	"culto": "Narrativo", "cooperativa": "Lavoro",
}

var s: ImperoState
var profilo: PlayerProfile
var persistente: ImperoPersistente
var audio: MusicEngine
var _e_seed_del_giorno := false

var vista := "ospedale"
var _strato: Control
var _modale: Control = null
var _pannello: Control = null
var _rinfresca_pannello: Callable
var _coda: Array = []
var _fine_mostrata := false
var _musica := ""
var _chat: Dictionary = {}
var _toast_coda: Array[String] = []
var _toast_attivo := false

var _avatar: TextureRect
var _frame := 0
var _lbl_ora: Label
var _lbl_luogo: Label
var _lbl_sirio: Label
var _bar_sirio: ProgressBar
var _lbl_sara: Label
var _bar_sara: ProgressBar
var _lbl_sonno: Label
var _lbl_fame: Label
var _lbl_flusso: Label
var _val_ris: Dictionary = {}
var _img_luogo: TextureRect
var _lbl_nome_luogo: Label
var _lbl_desc_luogo: Label
var _lbl_viaggio: Label
var _griglia: GridContainer
var _vuoto: Label
var _diario: VBoxContainer
var _btn_tel: Button
var _critico_prima: Dictionary = {}
var _pulse: Dictionary = {}
var _toast: Label


func avvia(stato: ImperoState, profilo_corrente: PlayerProfile, impero_persistente: ImperoPersistente, motore_audio: MusicEngine, e_seed_del_giorno: bool = false) -> void:
	s = stato
	profilo = profilo_corrente
	persistente = impero_persistente
	audio = motore_audio
	_e_seed_del_giorno = e_seed_del_giorno
	vista = s.luogo
	theme = Stile.tema()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_costruisci()
	_scrivi("Lunedì notte. Sara è nata da un'ora. Serena no.", Stile.SABBIA)
	_scrivi("Ti restano poche ore e un anticipo di Rocco. A lei, tre settimane. Le ore si comprano dalle persone: chiama Rocco.", Stile.CHIARO)
	_aggiorna()
	_imposta_musica()


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
	riga.add_theme_constant_override("separation", 16)
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
	dove.custom_minimum_size = Vector2(290, 0)
	dove.alignment = BoxContainer.ALIGNMENT_CENTER
	_lbl_ora = Stile.etichetta("", 22, Stile.SABBIA)
	_lbl_luogo = Stile.etichetta("", 17, Stile.GRIGIO.lightened(0.3))
	_lbl_luogo.clip_text = true
	dove.add_child(_lbl_ora)
	dove.add_child(_lbl_luogo)
	riga.add_child(dove)

	var o1 := _blocco_orologio("SIRIO", Stile.SABBIA)
	_lbl_sirio = o1[1]
	_bar_sirio = o1[2]
	riga.add_child(o1[0])
	var o2 := _blocco_orologio("SARA", Stile.ROSSO)
	_lbl_sara = o2[1]
	_bar_sara = o2[2]
	riga.add_child(o2[0])

	var flusso := VBoxContainer.new()
	flusso.alignment = BoxContainer.ALIGNMENT_CENTER
	flusso.custom_minimum_size = Vector2(150, 0)
	flusso.add_child(Stile.etichetta("RETE / FASCIA", 15, Stile.GRIGIO.lightened(0.3)))
	_lbl_flusso = Stile.etichetta("", 22, Stile.CHIARO)
	flusso.add_child(_lbl_flusso)
	riga.add_child(flusso)

	var bisogni := VBoxContainer.new()
	bisogni.alignment = BoxContainer.ALIGNMENT_CENTER
	bisogni.custom_minimum_size = Vector2(150, 0)
	var r1 := HBoxContainer.new()
	r1.add_child(_icona(PixelArt.icona_ui("sonno"), 26))
	_lbl_sonno = Stile.etichetta("", 17, Stile.CHIARO)
	r1.add_child(_lbl_sonno)
	var r2 := HBoxContainer.new()
	r2.add_child(_icona(PixelArt.icona_ui("fame"), 26))
	_lbl_fame = Stile.etichetta("", 17, Stile.CHIARO)
	r2.add_child(_lbl_fame)
	bisogni.add_child(r1)
	bisogni.add_child(r2)
	riga.add_child(bisogni)

	var ris := GridContainer.new()
	ris.columns = 2
	ris.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ris.add_theme_constant_override("h_separation", 8)
	ris.add_theme_constant_override("v_separation", 0)
	for def in RISORSE:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 2)
		h.add_child(_icona(PixelArt.icona_risorsa(def[0]), 24))
		var v := Stile.etichetta("0", 17, Stile.CHIARO)
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
	tocca.pressed.connect(func():
		if _modale == null:
			_apri_impero())
	p.add_child(tocca)
	return p


func _blocco_orologio(nome: String, colore: Color) -> Array:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(170, 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.add_child(Stile.etichetta(nome, 15, Stile.GRIGIO.lightened(0.3)))
	var l := Stile.etichetta("", 24, colore)
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
	_lbl_viaggio = Stile.etichetta("", 18, Stile.GRIGIO.lightened(0.3))
	_lbl_viaggio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_lbl_viaggio)
	_vuoto = Stile.etichetta("Qui non c'è niente per te, per ora. Apri la mappa o il telefono.", 19, Stile.GRIGIO.lightened(0.3))
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
	riga.add_child(_btn_tel)
	riga.add_child(_bottone_nav("MAPPA", "mappa", _apri_mappa))
	riga.add_child(_bottone_nav("IMPERO", "taccuino", _apri_impero))
	riga.add_child(_bottone_nav("TACCUINO", "taccuino", func(): _apri_taccuino("mosse")))
	return riga


func _bottone_nav(testo: String, icona: String, azione: Callable) -> Button:
	var b := Button.new()
	b.text = "  " + testo
	b.icon = ImageTexture.create_from_image(PixelArt.ingrandisci(PixelArt.icona_ui(icona).get_image(), 3))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 24)
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
	var n := s.messaggi_non_letti()
	var novita := 0
	for c in s.contatti_visibili():
		if s.ha_novita(c.id):
			novita += 1
	_btn_tel.text = "  TELEFONO" + ("  (%d)" % (n + novita) if n + novita > 0 else "")
	if n + novita > 0:
		Stile.applica_bottone(_btn_tel, Stile.GIALLO)
	else:
		for k in ["normal", "hover", "pressed", "disabled"]:
			_btn_tel.remove_theme_stylebox_override(k)


static func ore(v: float) -> String:
	if absf(v) >= 1000.0:
		return Stile.ore(v)
	return "%.1f ore" % v


func _aggiorna_alto() -> void:
	_lbl_ora.text = s.ora_testo()
	_lbl_luogo.text = "Sirio è: " + str(ImperoState.luogo_dati(s.luogo).get("nome", ""))
	_lbl_sirio.text = ore(s.sirio)
	_bar_sirio.max_value = maxf(100.0, s.sirio)
	_bar_sirio.value = s.sirio
	var giorni := s.giorni_sara()
	_lbl_sara.text = ("%.1f giorni" % giorni) if s.sara < 1000.0 else Stile.ore(s.sara)
	_bar_sara.max_value = maxf(float(ImperoState.par().giorni) * 24.0, s.sara)
	_bar_sara.value = s.sara
	_pulsa(_lbl_sirio, "sirio", s.sirio < 12.0 and not s.is_over)
	_pulsa(_lbl_sara, "sara", s.sara < 48.0 and not s.is_over)
	var netto := s.flusso_netto()
	_lbl_flusso.text = Stile.ore(netto, true)
	_lbl_flusso.add_theme_color_override("font_color", Stile.VERDE.lightened(0.35) if netto >= 0.0 else Stile.ROSSO)
	var sonno := s.stato_sonno()
	var fame := s.stato_fame()
	_lbl_sonno.text = " " + str(sonno[0])
	_lbl_fame.text = " " + str(fame[0])
	var colori := [Stile.CHIARO, Stile.GIALLO, Color("e08030"), Stile.ROSSO]
	_lbl_sonno.add_theme_color_override("font_color", colori[int(sonno[2])])
	_lbl_fame.add_theme_color_override("font_color", colori[int(fame[2])])
	var valori := {"polizia": s.polizia, "rivalita": s.rivalita, "fama": s.fama, "karma": s.karma}
	var critico := {}
	for k in valori:
		_val_ris[k].text = "%.0f" % valori[k]
		var c: bool = valori[k] <= -SOGLIA_CRITICA if k == "karma" else valori[k] >= SOGLIA_CRITICA
		critico[k] = c
		_val_ris[k].add_theme_color_override("font_color", Stile.ROSSO if c else Stile.CHIARO)
		if c and not _critico_prima.get(k, false):
			_scuoti(_val_ris[k].get_parent())
			_s("critica")
	_critico_prima = critico


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
	var l := ImperoState.luogo_dati(vista)
	_img_luogo.texture = PixelArt.scena_luogo(l.get("tipo", "casa"))
	_lbl_nome_luogo.text = str(l.get("nome", "")).to_upper()
	_lbl_desc_luogo.text = l.get("descrizione", "")
	if vista == s.luogo:
		_lbl_viaggio.text = "Sei qui. Ogni cosa occupa sei ore, poi la città gira."
	else:
		_lbl_viaggio.text = "Sirio è altrove. Venire qui prende %s della fascia: quello che fai rende il %d%%." % [ore(s.ore_viaggio(vista)), int(s.efficienza(vista) * 100.0)]
	for c in _griglia.get_children():
		c.queue_free()
	var voci := s.voci(vista)
	_vuoto.visible = voci.is_empty()
	for voce in voci:
		_griglia.add_child(_carta(voce))


func _categoria(voce: Dictionary) -> String:
	var tipo: String = voce.tipo
	if tipo == "cresci":
		return CATEGORIA_GIRO.get(str(voce.id).split(":")[1], "Crimine organizzato")
	if tipo == "colpo" and voce.id in ["rapina", "furgone"]:
		return "Crimine"
	return CATEGORIA_TIPO.get(tipo, "Narrativo")


func _carta(voce: Dictionary) -> CartaUI:
	var det: String = voce.descrizione
	if voce.rapida:
		det += "\nSubito, non occupa la fascia."
	var carta := CartaUI.new(_categoria(voce), voce.nome, det, float(voce.rischio))
	if voce.nota != "":
		carta.imposta_badge(voce.nota, Stile.GRIGIO.lightened(0.3))
	elif voce.tipo == "mossa":
		carta.imposta_badge("GRANDE MOSSA, UNA SOLA OCCASIONE", Stile.GIALLO)
	elif voce.tipo == "dona":
		carta.imposta_badge("Puoi donare anche una sola ora", Stile.SABBIA)
	elif not voce.rapida and s.sirio <= float(ImperoState.par().ore_fascia) + s.costi_fissi() - s.flusso_lordo():
		carta.imposta_badge("A Sirio restano %s: la fascia potrebbe essere l'ultima" % ore(s.sirio), Stile.ROSSO)
	carta.abilita(voce.disponibile and not s.is_over)
	carta.premuta.connect(_su_voce.bind(voce))
	return carta


func _imposta_musica() -> void:
	if audio == null:
		return
	var voluta := "endgame" if s.sara < SOGLIA_ENDGAME_ORE else "gameplay"
	if voluta != _musica:
		_musica = voluta
		audio.suona_musica(voluta)


func _scrivi(testo: String, colore: Color = Stile.CHIARO) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(Stile.etichetta(s.ora_testo(), 14, Stile.GRIGIO.lightened(0.2)))
	var l := Stile.etichetta(testo, 17, colore)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(LARGHEZZA_DIARIO - 40, 0)
	box.add_child(l)
	_diario.add_child(box)
	_diario.move_child(box, 0)
	while _diario.get_child_count() > 80:
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

func _bloccato() -> bool:
	return _modale != null or s.is_over


func _su_voce(voce: Dictionary) -> void:
	if _bloccato():
		return
	_s("click")
	if voce.tipo == "dona":
		_apri_donazione()
		return
	if voce.tipo == "liquida":
		_conferma("Vendere tutto", "Vendi la rete in una notte. Se va bene incassi molto, ma da domani non entra più niente.", "VENDI", func(): esegui(voce.id))
		return
	if not voce.rapida and s.sirio <= float(ImperoState.par().ore_fascia) + s.costi_fissi() - s.flusso_lordo():
		_conferma("Ne vale la pena?", "A Sirio restano %s. Una fascia ne costa sei, più gli uomini da pagare. Se la rete non rende abbastanza, non arriva in fondo." % ore(s.sirio), "VAI LO STESSO", func(): esegui(voce.id))
		return
	esegui(voce.id)


## Esegue una voce nel luogo che stai guardando. Pubblica per i test.
func esegui(id: String) -> void:
	var prima := s.fascia
	var sirio_prima := s.sirio
	var esito := s.esegui(id, vista)
	if esito.get("rifiutata", false):
		_notifica(str(esito.motivo))
		return
	if s.fascia > prima:
		vista = s.luogo
	_gestisci_esito(esito, s.fascia > prima, sirio_prima)
	_aggiorna()
	_esegui_coda()


func _gestisci_esito(esito: Dictionary, fascia_passata: bool, sirio_prima: float) -> void:
	for ris in esito.risultati:
		var ok: bool = ris.successo
		_scrivi("%s. %s" % [ris.titolo, ris.testo], Stile.VERDE.lightened(0.35) if ok else Stile.ROSSO.lightened(0.2))
		var righe: Array = ris.righe.duplicate()
		if ris.roll != null:
			_s("guadagno" if ok else "perdita")
			var titolo: String = ris.titolo
			var testo: String = ris.testo
			var roll = ris.roll
			var deltas := "\n".join(righe)
			_coda.append(func(): _mostra_dado(titolo, roll, ok, testo, deltas))
		elif not righe.is_empty():
			_scrivi("  " + ", ".join(righe), Stile.SABBIA)
	if fascia_passata:
		var incasso := s.ultimo_incasso
		if absf(incasso) >= 0.1:
			_scrivi("La rete ha reso %s. Le sei ore della fascia le paghi tu." % Stile.ore(incasso, true), Stile.GRIGIO.lightened(0.4))
		_scrivi("Sirio: %s in questa fascia." % Stile.ore(s.sirio - sirio_prima, true), Stile.GRIGIO.lightened(0.4))
	for ev in esito.eventi:
		if ev.tipo == "patto":
			_coda.append(func(): _mostra_patto(ev))
		elif ev.grave:
			_scrivi(str(ev.testo), Stile.ROSSO)
			_coda.append(func(): _mostra_evento(ev))
		else:
			_scrivi(str(ev.testo), Stile.SABBIA)
	for n in esito.notifiche:
		_notifica(str(n))
	var nuovi := s.messaggi_non_letti()
	if fascia_passata and nuovi > 0 and s.fascia % 4 == 0:
		_notifica("Un messaggio della dottoressa Venti.")


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
	if s.is_over:
		_mostra_fine()


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
	v.add_child(dado)
	var lbl_tiro := _testo(_descrivi_tiro(roll), 18)
	lbl_tiro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var critico: bool = roll.successo_critico or roll.fallimento_critico
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
	if not roll.senza_tiro:
		numero = roll.naturale
	var tw := create_tween()
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
	if roll.senza_tiro:
		return "Nessun tiro: l'esito era scritto."
	var mod := ""
	var m := s.malus()
	if int(m.modificatore) < 0:
		mod = "  (fame e sonno: %d)" % int(m.modificatore)
	if roll.dadi.size() == 1:
		return "Tiro %d, modificatore %+d: %d contro %d%s" % [roll.dadi[0], roll.modificatore, roll.totale, roll.cd, mod]
	return "Dadi %s, tenuto %d, modificatore %+d: %d contro %d%s" % [str(roll.dadi), roll.naturale, roll.modificatore, roll.totale, roll.cd, mod]


const TITOLI_EVENTO := {"retata": "RETATA", "assalto": "ASSALTO", "scandalo": "SCANDALO",
	"tradimento": "TRADIMENTO", "crisi": "SARA", "debito": "ROCCO"}


func _mostra_evento(ev: Dictionary) -> void:
	_s("critica")
	var v := _nuovo_modale(720.0)
	v.add_child(Stile.etichetta(TITOLI_EVENTO.get(ev.tipo, "IMPREVISTO"), Stile.TITOLI, Stile.ROSSO))
	v.add_child(_testo(str(ev.testo)))
	var b := _grande("CONTINUA", Stile.GRIGIO)
	b.pressed.connect(func():
		_s("click")
		_chiudi_modale())
	v.add_child(b)


func _mostra_patto(ev: Dictionary) -> void:
	_s("critica")
	var v := _nuovo_modale(860.0)
	v.add_child(Stile.etichetta("DOLCE VOLPE", Stile.TITOLI, Stile.ROSSO))
	v.add_child(_testo(str(ev.testo)))
	var prezzo: float = s.patto_in_sospeso.get("prezzo", 0.0)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 14)
	v.add_child(riga)
	var si := _grande("ACCETTO\nPrezzo %s, Karma +%.0f" % [Stile.ore(prezzo), float(ImperoState.par().patto.karma)], Stile.ROSSO, 120.0)
	var no := _grande("RIFIUTO\nIl Karma resta com'è", Stile.GRIGIO, 120.0)
	riga.add_child(si)
	riga.add_child(no)
	si.pressed.connect(func():
		_s("click")
		var karma_prima := s.karma
		var r := s.risolvi_patto(true)
		_scrivi(Narrativa.patto_accettato(r.get("prezzo", prezzo), s.karma - karma_prima, s.karma), Stile.ROSSO)
		_chiudi_modale())
	no.pressed.connect(func():
		_s("click")
		s.risolvi_patto(false)
		_scrivi(Narrativa.patto_rifiutato(), Stile.GRIGIO.lightened(0.3))
		_chiudi_modale())


# =============================================================== donazione

func _apri_donazione() -> void:
	var massimo := s.sirio
	var valore := [minf(1.0, massimo)]
	var v := _nuovo_modale(760.0)
	v.add_child(Stile.etichetta("DONARE A SARA", Stile.TITOLI, Stile.ROSSO))
	v.add_child(_testo("Quanta della tua sabbia vuoi darle? Anche un'ora sola. Si fa una volta: dopo, la partita finisce. Prima doni, più rischi di lasciare ore sul tavolo. Più aspetti, più rischi una crisi.", 19))
	var lbl := Stile.etichetta("", 44, Stile.SABBIA)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl)
	var info := Stile.etichetta("", 18, Stile.GRIGIO.lightened(0.3))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	var aggiorna := func():
		lbl.text = Stile.ore(valore[0])
		info.text = "Sirio resterebbe con %s. Sara arriverebbe a %s." % [Stile.ore(massimo - valore[0]), Stile.ore(s.sara + valore[0])]
	aggiorna.call()
	var passi := [-10.0, -1.0, 1.0, 10.0]
	if massimo > 500.0:
		passi = [-100.0, -10.0, 10.0, 100.0]
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 8)
	v.add_child(riga)
	for passo in passi:
		var b := _grande("%+.0f" % passo, Stile.GRIGIO, 80.0)
		b.pressed.connect(func():
			_s("click")
			valore[0] = clampf(snappedf(valore[0] + passo, 0.1), minf(0.1, massimo), massimo)
			aggiorna.call())
		riga.add_child(b)
	var riga2 := HBoxContainer.new()
	riga2.add_theme_constant_override("separation", 8)
	v.add_child(riga2)
	for def in [["UN'ORA", 1.0], ["METÀ", 0.5], ["TUTTO TRANNE UN GIORNO", 0.9], ["TUTTO", -1.0]]:
		var b := _grande(def[0], Stile.SABBIA, 72.0)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(func():
			_s("click")
			if def[1] < 0.0:
				valore[0] = massimo
			elif def[1] == 0.5:
				valore[0] = snappedf(massimo * 0.5, 0.1)
			elif def[1] == 0.9:
				valore[0] = maxf(minf(1.0, massimo), massimo - 24.0)
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
		_modale.queue_free()
		_modale = null
		dona_ore(valore[0]))


## Pubblica per i test.
func dona_ore(quante: float) -> void:
	var esito := s.dona(quante, "ospedale")
	if not esito.get("successo", false):
		_notifica(str(esito.get("motivo", "")))
		_esegui_coda()
		return
	_scrivi("Hai donato %s a Sara." % Stile.ore(quante), Stile.SABBIA)
	_esegui_coda()


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
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 10)
	sc.add_child(c)
	return c


func _svuota(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _scheda(bordo: Color) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Stile.box(Color("14142a"), bordo, 3, 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	return v


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
		var n := s.messaggi_non_letti()
		var bm := _riga_telefono("Messaggi", "%d non letti" % n if n > 0 else "Nessuno nuovo", n > 0)
		bm.pressed.connect(func():
			_s("click")
			selezionato[0] = "@messaggi"
			_rinfresca_pannello.call())
		lista.add_child(bm)
		lista.add_child(Stile.etichetta("RUBRICA", 17, Stile.GRIGIO.lightened(0.3)))
		for c in s.contatti_visibili():
			var b := _riga_telefono(c.nome, c.ruolo, s.ha_novita(c.id))
			var cid: String = c.id
			b.pressed.connect(func():
				_s("click")
				selezionato[0] = cid
				_rinfresca_pannello.call())
			lista.add_child(b)
		lista.add_child(_testo("Telefonare non occupa la fascia.", 16, Stile.GRIGIO.lightened(0.2)))
	var mostra_schermo := func():
		_svuota(destra)
		if selezionato[0] == "":
			destra.add_child(_testo("A Ledune la sabbia si cede solo di propria volontà. Un impero è fatto di persone che te la cedono ogni giorno. Chi conosci decide in quali giri puoi entrare. Il pallino giallo indica chi ha qualcosa di nuovo da dirti.", 19, Stile.GRIGIO.lightened(0.3)))
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
	if s.messaggi.is_empty():
		c.add_child(_testo("Nessun messaggio.", 19, Stile.GRIGIO))
	for i in range(s.messaggi.size() - 1, -1, -1):
		var m: Dictionary = s.messaggi[i]
		var nome: String = ImperoState.contatto_dati(m.da).get("nome", m.da)
		c.add_child(_fumetto(nome + "\n" + str(m.testo), false, not m.letto))
		m.letto = true
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
	var c := ImperoState.contatto_dati(cid)
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
	var opzioni := s.opzioni_contatto(cid)
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
		b.pressed.connect(func(): scegli_opzione(cid, oid))
		bolle.add_child(b)
	scroll.call_deferred("set_v_scroll", 100000)


## Pubblica per i test.
func scegli_opzione(cid: String, oid: String) -> void:
	if _bloccato():
		return
	_s("click")
	var testo := ""
	for o in s.opzioni_contatto(cid):
		if o.id == oid:
			testo = o.testo
	var esito := s.scegli_opzione(cid, oid)
	if esito.get("rifiutata", false):
		_notifica(str(esito.motivo))
		return
	if not _chat.has(cid):
		_chat[cid] = [[false, str(ImperoState.contatto_dati(cid).saluto)]]
	_chat[cid].append([true, testo])
	_chat[cid].append([false, str(esito.get("risposta", ""))])
	for n in esito.notifiche:
		_chat[cid].append(["", str(n)])
	_scrivi("Telefonata con %s." % ImperoState.contatto_dati(cid).nome, Stile.GRIGIO.lightened(0.3))
	for n in esito.notifiche:
		_notifica(str(n))
	_aggiorna()


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
	var selezionato := [vista]
	var mostra_info := func():
		_svuota(info)
		var l := ImperoState.luogo_dati(selezionato[0])
		info.add_child(_testo(str(l.nome).to_upper(), 24, Stile.SABBIA))
		info.add_child(_testo(str(l.descrizione), 18))
		var n := 0
		for voce in s.voci(selezionato[0]):
			if voce.disponibile:
				n += 1
		info.add_child(_testo("Ci sono %d cose che puoi fare." % n if n > 0 else "Per ora non c'è niente per te.", 17, Stile.GRIGIO.lightened(0.3)))
		if selezionato[0] == s.luogo:
			info.add_child(_testo("Sirio è qui.", 20, Stile.ROSSO))
		else:
			info.add_child(_testo("Arrivarci prende %s della fascia: quello che fai lì rende il %d%%." % [ore(s.ore_viaggio(selezionato[0])), int(s.efficienza(selezionato[0]) * 100.0)], 18))
		var vai := _grande("GUARDA COSA C'È", Stile.ROSSO)
		var dest: String = selezionato[0]
		vai.pressed.connect(func(): guarda(dest))
		info.add_child(vai)
	var disponi := func():
		var dim_area := area.size
		var scala := minf(dim_area.x / 160.0, dim_area.y / 100.0)
		var dim := Vector2(160, 100) * scala
		var origine := (dim_area - dim) * 0.5
		img.position = origine
		img.size = dim
		for id in pin:
			var l := ImperoState.luogo_dati(id)
			var p: Vector2 = origine + Vector2(float(l.pos[0]) / 100.0 * dim.x, float(l.pos[1]) / 100.0 * dim.y)
			pin[id].position = p - Vector2(40, 52)
	for l in s.luoghi_visibili():
		var nodo := VBoxContainer.new()
		nodo.custom_minimum_size = Vector2(80, 80)
		nodo.add_theme_constant_override("separation", 0)
		var b := TextureButton.new()
		b.texture_normal = PixelArt.pin_luogo(str(l.tipo), l.id == s.luogo)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(80, 52)
		var lid: String = l.id
		b.pressed.connect(func():
			_s("click")
			selezionato[0] = lid
			mostra_info.call())
		nodo.add_child(b)
		var qui: bool = l.id == s.luogo
		var nome := Stile.etichetta(("SIRIO\n" if qui else "") + str(l.nome), 13, Stile.ROSSO if qui else Stile.CHIARO)
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


## Guarda un luogo: non costa niente. Il viaggio si paga quando ci fai qualcosa.
func guarda(dest: String) -> void:
	_s("click")
	_chiudi_pannello()
	vista = dest
	_aggiorna()


# ------------------------------------------------------------- impero

func _apri_impero() -> void:
	var v := _apri_pannello("IL TUO IMPERO")
	var c := _scroll_in(v)
	_rinfresca_pannello = func():
		_svuota(c)
		_scheda_impero(c)
	_rinfresca_pannello.call()


func _scheda_impero(c: VBoxContainer) -> void:
	var p := ImperoState.par()
	var conti := _scheda(Stile.SABBIA)
	conti.add_child(Stile.etichetta("CONTI DI UNA FASCIA", 22, Stile.SABBIA))
	var righe := ["La rete rende %s" % Stile.ore(s.flusso_lordo(), true)]
	if s.uomini > 0:
		righe.append("%d uomini da pagare: %s" % [s.uomini, Stile.ore(-s.uomini * float(p.paga_uomo), true)])
	if s.rate_debito > 0:
		righe.append("Rata a Rocco: %s (ne mancano %d)" % [Stile.ore(-float(p.anticipo.rata), true), s.rate_debito])
	righe.append("Sei ore che passano: %s" % Stile.ore(-float(p.ore_fascia), true))
	righe.append("Netto: %s a fascia" % Stile.ore(s.flusso_netto(), true))
	conti.add_child(_testo("\n".join(righe), 19))
	if s.informatore:
		conti.add_child(_testo("Hai un informatore in questura: la polizia ti scalda più piano.", 17, Stile.GRIGIO.lightened(0.3)))
	c.add_child(conti.get_parent())

	for g in ImperoState.dati().giri:
		var d: Dictionary = ImperoState.dati().giri[g]
		var aperto := s.giri_aperti.has(g)
		var st: Dictionary = s.giri[g]
		var box := _scheda(Stile.VERDE if aperto and st.persone > 0.0 else Stile.GRIGIO)
		if not aperto:
			box.add_child(Stile.etichetta("???", 22, Stile.GRIGIO.lightened(0.3)))
			box.add_child(_testo("Un giro che non conosci ancora. Qualcuno a Ledune sa come entrarci.", 17, Stile.GRIGIO.lightened(0.3)))
			c.add_child(box.get_parent())
			continue
		box.add_child(Stile.etichetta(str(d.nome).to_upper(), 22, Stile.SABBIA))
		box.add_child(_testo(str(d.descrizione), 17, Stile.GRIGIO.lightened(0.4)))
		var info := "%d %s.  Rendono %s a fascia.  Controllo %d%%." % [int(st.persone), d.persone, Stile.ore(s.tributo(g)), int(float(st.controllo) * 100.0)]
		box.add_child(_testo(info, 19))
		var dettagli: Array[String] = ["Si allarga a %s." % ImperoState.luogo_dati(d.sede).nome]
		if st.luogotenente:
			dettagli.append("Ha un luogotenente: cresce da solo, trattiene la sua parte.")
		var per: int = int(d.uomini_per)
		if per > 0:
			dettagli.append("Ogni uomo tiene in riga %d %s: oltre %d non rendono." % [per, d.persone, s.uomini * per + per])
		var calore: Array[String] = []
		if float(d.polizia) > 0.0:
			calore.append("polizia")
		if float(d.rivali) > 0.0:
			calore.append("rivali")
		if float(d.fama) > 0.0:
			calore.append("fama")
		if not calore.is_empty():
			dettagli.append("Scalda: %s." % ", ".join(calore))
		box.add_child(_testo(" ".join(dettagli), 17, Stile.GRIGIO.lightened(0.3)))
		c.add_child(box.get_parent())

	var cal := _scheda(Stile.ROSSO)
	cal.add_child(Stile.etichetta("CALORE", 22, Stile.ROSSO))
	var pc: Dictionary = p.calore
	cal.add_child(_testo("Polizia %.0f: retata %.1f%% a fascia.\nRivali %.0f: assalto %.1f%% a fascia.\nFama %.0f: scandalo %.1f%% a fascia.\nUomini: %d." % [
		s.polizia, minf(100.0, s.polizia / float(pc.retata) * 100.0), s.rivalita, minf(100.0, s.rivalita / float(pc.assalto) * 100.0),
		s.fama, minf(100.0, s.fama / float(pc.scandalo) * 100.0), s.uomini], 19))
	cal.add_child(_testo("La polizia si raffredda in questura, i rivali al bar Aurora. Con tre uomini un assalto si può respingere.", 17, Stile.GRIGIO.lightened(0.3)))
	c.add_child(cal.get_parent())


# ------------------------------------------------------------- taccuino

func _apri_taccuino(scheda: String) -> void:
	var v := _apri_pannello("TACCUINO")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	var contenuto := _scroll_in(v)
	var corrente := [scheda]
	var bottoni := {}
	for def in [["mosse", "Grandi mosse"], ["stato", "Stato"], ["obiettivi", "Obiettivi"], ["opzioni", "Opzioni"]]:
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
			"mosse":
				_scheda_mosse(contenuto)
			"stato":
				_scheda_stato(contenuto)
			"obiettivi":
				_scheda_obiettivi(contenuto)
			_:
				_scheda_opzioni(contenuto)
	_rinfresca_pannello.call()


func _scheda_mosse(c: VBoxContainer) -> void:
	if s.piste.is_empty():
		c.add_child(_testo("Nessuna grande mossa in vista. Le occasioni grosse di Ledune arrivano a chi ha già qualcosa: un giro avviato, uomini, gli amici giusti.", 19, Stile.GRIGIO.lightened(0.3)))
		return
	for m in s.piste:
		var md: Dictionary = ImperoState.dati().mosse[m]
		var tentata := s.mosse_tentate.has(m)
		var box := _scheda(Stile.GRIGIO if tentata else Stile.GIALLO)
		box.add_child(Stile.etichetta(str(md.nome).to_upper(), 21, Stile.SABBIA))
		box.add_child(_testo("Dove: %s. Rischio %d%%." % [ImperoState.luogo_dati(md.luogo).nome, int(float(md.rischio) * 100.0)], 18))
		var voce := s.voce_per_id("mossa:" + m)
		var stato_m := "Già tentata." if tentata else ("Pronta." if not voce.is_empty() and voce.disponibile else str(voce.get("nota", "Non ancora.")) + ".")
		box.add_child(_testo(stato_m, 17, Stile.GRIGIO.lightened(0.3)))
		c.add_child(box.get_parent())


func _scheda_stato(c: VBoxContainer) -> void:
	var sonno := s.stato_sonno()
	var fame := s.stato_fame()
	var m := s.malus()
	c.add_child(Stile.etichetta("BISOGNI", 22, Stile.SABBIA))
	c.add_child(_testo("Sveglio da %d fasce: %s.   Ultimo pasto %d fasce fa: %s." % [s.sveglio, sonno[0], s.digiuno, fame[0]], 19))
	var effetto := "Nessun effetto sui tiri." if int(m.modificatore) == 0 else "Malus ai tiri: %d%s." % [int(m.modificatore), " e svantaggio" if m.modo == DiceSystem.RollMode.SVANTAGGIO else ""]
	c.add_child(_testo(effetto + " Si dorme a casa. Si mangia a casa, all'osteria, in piazza, alla stazione o all'Aurora: mangiare non occupa la fascia.", 18, Stile.GRIGIO.lightened(0.3)))
	c.add_child(HSeparator.new())
	c.add_child(Stile.etichetta("RISORSE", 22, Stile.SABBIA))
	var valori := {"polizia": s.polizia, "rivalita": s.rivalita, "fama": s.fama, "karma": s.karma}
	for def in RISORSE:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		r.add_child(_icona(PixelArt.icona_risorsa(def[0]), 32))
		var t := _testo("%s %.0f. %s" % [def[1], valori[def[0]], def[2]], 18)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(t)
		c.add_child(r)
	c.add_child(HSeparator.new())
	c.add_child(_testo("Seed %d. Difficoltà %d. Giorno %d di %d." % [s.seed_run, s.livello_difficolta, s.giorno(), int(ImperoState.par().giorni)], 17, Stile.GRIGIO.lightened(0.3)))


func _scheda_obiettivi(c: VBoxContainer) -> void:
	c.add_child(_testo("Ogni partita ricomincia da capo. Quello che impari resta: certi traguardi ti lasciano un contatto, un luogo o una pista per le partite successive.", 18, Stile.GRIGIO.lightened(0.3)))
	if persistente != null and persistente.record_anni > 0.0:
		c.add_child(_testo("Il tuo record: %s donati a Sara." % Stile.ore(persistente.record_anni * ImperoState.ORE_ANNO), 19, Stile.SABBIA))
	for ob in ImperoState.dati().obiettivi:
		var fatto: bool = persistente != null and persistente.obiettivi.has(ob.id)
		var box := _scheda(Stile.VERDE if fatto else Stile.GRIGIO)
		box.add_child(Stile.etichetta(("FATTO  " if fatto else "") + str(ob.testo), 20, Stile.SABBIA if fatto else Stile.CHIARO))
		box.add_child(_testo(str(ob.nota) if fatto else "Ricompensa: ???", 17, Stile.GRIGIO.lightened(0.3)))
		c.add_child(box.get_parent())


func _scheda_opzioni(c: VBoxContainer) -> void:
	for def in [["Volume generale", "volume_master"], ["Musica", "volume_musica"], ["Effetti", "volume_effetti"]]:
		c.add_child(Stile.etichetta(def[0], 18, Stile.GRIGIO.lightened(0.3)))
		var sl := HSlider.new()
		sl.custom_minimum_size = Vector2(0, 56)
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = audio.get(def[1]) if audio != null else 0.8
		var prop: String = def[1]
		sl.value_changed.connect(func(x):
			if audio != null:
				audio.set(prop, x))
		c.add_child(sl)
	var esci := _grande("TORNA AL TITOLO", Stile.GRIGIO)
	esci.pressed.connect(func():
		_s("click")
		_chiudi_pannello()
		_conferma("Tornare al titolo", "La partita in corso va persa. Non si salva a metà.", "ESCI", func(): torna_al_titolo.emit()))
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
	var p := s.punteggio()
	var note := _salva()
	var vittoria := s.fine == "dono" and s.sara > 0.0
	if audio != null:
		audio.jingle("vittoria" if vittoria else "sconfitta")
	var titolo := "DONAZIONE COMPIUTA"
	if s.fine == "sara":
		titolo = "SARA NON CE L'HA FATTA"
	elif s.fine == "sirio":
		titolo = "SIRIO SI SPEGNE"
	var v := _nuovo_modale(900.0)
	v.add_child(Stile.etichetta(titolo, Stile.TITOLI, Stile.SABBIA if vittoria else Stile.ROSSO))
	v.add_child(_testo(Narrativa.epilogo(s.fine == "dono", s.sara > 0.0, s.sirio > 0.0, s.karma)))
	v.add_child(HSeparator.new())
	if vittoria:
		v.add_child(Stile.etichetta("Sara: %s di vita.  %s." % [Stile.ore(s.sara), p.traguardo], 24, Stile.SABBIA))
		v.add_child(_testo("Picco della rete: %s a fascia. Giorno %d di %d." % [Stile.ore(s.picco_flusso), s.giorno(), int(ImperoState.par().giorni)], 18, Stile.GRIGIO.lightened(0.3)))
	for n in note:
		v.add_child(_testo(str(n), 18, Stile.GIALLO))
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 14)
	v.add_child(riga)
	var nuova := _grande("NUOVA PARTITA", Stile.ROSSO)
	var tit := _grande("TITOLO", Stile.GRIGIO)
	riga.add_child(nuova)
	riga.add_child(tit)
	nuova.pressed.connect(func():
		_s("click")
		nuova_partita.emit())
	tit.pressed.connect(func():
		_s("click")
		torna_al_titolo.emit())


func _salva() -> Array:
	var note: Array = []
	if persistente != null:
		for n in s.valuta_obiettivi(persistente):
			note.append("Per le prossime partite: " + str(n))
		persistente.salva()
	if profilo == null:
		return note
	var p := s.punteggio()
	profilo.karma = s.karma
	profilo.livello_difficolta = s.livello_difficolta
	if p.vittoria_100_100:
		profilo.traguardo_100_100_raggiunto = true
	if _e_seed_del_giorno:
		profilo.registra_punteggio_seed_del_giorno(SeedDelGiorno.data_di_oggi_stringa(), {"punteggio_totale_anni": p.sara_anni, "figlia_anni": p.sara_anni, "padre_anni": 0.0})
	profilo.save()
	return note
