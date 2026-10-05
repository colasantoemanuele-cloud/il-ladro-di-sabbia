class_name ImperoUI
extends Control
## Interfaccia di gioco. In alto il tempo e lo stato di Sirio. Al centro il
## mondo: una stanza da esplorare a piedi o la mappa di Ledune, che si apre da
## sola quando Sirio esce da un luogo. In basso telefono, impero, taccuino.
## Il tempo scorre davvero: un secondo nel mondo è un minuto di vita per Sirio
## e per Sara, e ogni gesto (parlare, giocare, esaminare, viaggiare) costa
## minuti. Nessuna regola qui: tutto passa da ImperoState, DialogoSystem e
## Minigiochi.

signal torna_al_titolo
signal nuova_partita

const ALTO := 96
const BASSO := 72
const SOGLIA_ENDGAME_ORE := 72.0
const SOGLIA_CRITICA := 75.0
const SECONDI_PER_MINUTO := 1.0
const STANZA_INIZIALE := "ospedale/reparto"

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
	"luogotenente": "Crimine organizzato", "mossa": "Grande colpo",
}
const CATEGORIA_GIRO := {
	"usura": "Crimine organizzato", "protezione": "Minaccia 1 a 1", "bische": "Azzardo",
	"culto": "Narrativo", "cooperativa": "Lavoro",
}
const TITOLI_EVENTO := {"retata": "RETATA", "assalto": "ASSALTO", "scandalo": "SCANDALO",
	"tradimento": "TRADIMENTO", "crisi": "SARA", "debito": "ROCCO"}

var s: ImperoState
var profilo: PlayerProfile
var persistente: ImperoPersistente
var audio: MusicEngine
var _e_seed_del_giorno := false

var stanza_id := ""
var esplorazione: Esplorazione
var mappa: MappaMondo
var _palco: Control
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
var _diario: Array = []
var _accumulo := 0.0
var tempo_reale := true

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
var _btn_tel: Button
var _critico_prima: Dictionary = {}
var _pulse: Dictionary = {}
var _toast: Label


func avvia(stato: ImperoState, profilo_corrente: PlayerProfile, impero_persistente: ImperoPersistente, motore_audio: MusicEngine, e_seed_del_giorno: bool = false, con_intro: bool = true) -> void:
	s = stato
	profilo = profilo_corrente
	persistente = impero_persistente
	audio = motore_audio
	_e_seed_del_giorno = e_seed_del_giorno
	theme = Stile.tema()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_costruisci()
	_scrivi("Lunedì notte. Sara è nata da un'ora. Serena no.")
	_scrivi("Ti restano poche ore e un anticipo di Rocco. A lei, tre settimane. Le ore si comprano dalle persone: vai all'osteria, o chiama Rocco.")
	entra_stanza(STANZA_INIZIALE, [9, 6])
	_aggiorna()
	if con_intro:
		cutscene(CutsceneUI.INTRO)


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
	_palco = Control.new()
	_palco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palco.clip_contents = true
	radice.add_child(_palco)
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
	_avatar.texture = PixelMondo.ritratto("sirio", "neutro")
	_avatar.custom_minimum_size = Vector2(72, 72)
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	riga.add_child(_avatar)
	var dove := VBoxContainer.new()
	dove.custom_minimum_size = Vector2(300, 0)
	dove.alignment = BoxContainer.ALIGNMENT_CENTER
	_lbl_ora = Stile.etichetta("", 24, Stile.SABBIA)
	_lbl_luogo = Stile.etichetta("", 16, Stile.GRIGIO.lightened(0.3))
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
	flusso.custom_minimum_size = Vector2(130, 0)
	flusso.add_child(Stile.etichetta("RETE / 6 ORE", 15, Stile.GRIGIO.lightened(0.3)))
	_lbl_flusso = Stile.etichetta("", 22, Stile.CHIARO)
	flusso.add_child(_lbl_flusso)
	riga.add_child(flusso)
	var bisogni := VBoxContainer.new()
	bisogni.alignment = BoxContainer.ALIGNMENT_CENTER
	bisogni.custom_minimum_size = Vector2(140, 0)
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
			_apri_taccuino("stato"))
	p.add_child(tocca)
	return p


func _blocco_orologio(nome: String, colore: Color) -> Array:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(160, 0)
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


func _costruisci_basso() -> Control:
	var riga := HBoxContainer.new()
	riga.custom_minimum_size = Vector2(0, BASSO)
	riga.add_theme_constant_override("separation", 4)
	_btn_tel = _bottone_nav("TELEFONO", "telefono", _apri_telefono)
	riga.add_child(_btn_tel)
	riga.add_child(_bottone_nav("IMPERO", "taccuino", _apri_impero))
	riga.add_child(_bottone_nav("TACCUINO", "taccuino", func(): _apri_taccuino("mosse")))
	return riga


func _bottone_nav(testo: String, icona: String, azione: Callable) -> Button:
	var b := Button.new()
	b.text = "  " + testo
	b.icon = ImageTexture.create_from_image(PixelArt.ingrandisci(PixelArt.icona_ui(icona).get_image(), 3))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func():
		_s("click")
		if _modale == null:
			azione.call())
	return b


# =============================================================== mondo

static func stanza_dati(id: String) -> Dictionary:
	for st in DialogoSystem.dati().get("stanze", []):
		if st.id == id:
			return st
	return {}


static func stanza_ingresso(luogo: String) -> Dictionary:
	for st in DialogoSystem.dati().get("stanze", []):
		if st.luogo == luogo and st.has("entrata"):
			return st
	return {}


func _svuota_palco() -> void:
	for c in _palco.get_children():
		c.queue_free()
	esplorazione = null
	mappa = null


## Entra in una stanza (stesso luogo o all'arrivo da un viaggio).
func entra_stanza(id: String, arrivo: Array) -> void:
	var st := stanza_dati(id)
	if st.is_empty():
		return
	_svuota_palco()
	stanza_id = id
	esplorazione = Esplorazione.new()
	esplorazione.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_palco.add_child(esplorazione)
	esplorazione.carica(st, arrivo, s.oggetti.has("lanterna"))
	esplorazione.oggetto_toccato.connect(_su_oggetto)
	esplorazione.persona_toccata.connect(_su_persona)
	esplorazione.porta_toccata.connect(_su_porta)
	_aggiorna()
	_imposta_musica()
	if st.luogo == "catacombe" and not s.ricordato("visto_cripta"):
		s.ricorda("visto_cripta")
		cutscene(CutsceneUI.CRIPTA)


func entra_luogo(luogo: String) -> void:
	var st := stanza_ingresso(luogo)
	entra_stanza(st.id, st.entrata)
	_scrivi("Arrivi: %s." % ImperoState.luogo_dati(luogo).nome)


func apri_mappa_mondo() -> void:
	_svuota_palco()
	stanza_id = ""
	mappa = MappaMondo.new()
	_palco.add_child(mappa)
	mappa.avvia(s)
	mappa.parti.connect(_viaggia)
	mappa.resta.connect(func(): entra_luogo(s.luogo))
	_aggiorna()
	_imposta_musica()


func _viaggia(dest: String) -> void:
	var r := s.viaggia(dest)
	if r.get("rifiutata", false):
		notifica(str(r.motivo))
		return
	_s("click")
	accoda_esito({"eventi": r.eventi, "notifiche": []}, "")
	if s.is_over:
		_esegui_coda()
		return
	entra_luogo(dest)
	_esegui_coda()


func _su_porta(p: Dictionary) -> void:
	if _bloccato():
		return
	if p.verso == "@mappa":
		_s("click")
		apri_mappa_mondo()
		return
	var alternative: Array = p.get("richiede", [])
	if not alternative.is_empty():
		var aperta := false
		for alt in alternative:
			if s.vale(alt):
				aperta = true
		if not aperta:
			var serve: Dictionary = alternative[0]
			if serve.get("oggetto", "") == "lanterna":
				notifica("Il buio sotto è totale. Senza una lanterna non si scende.")
			else:
				notifica("La porta è chiusa. Serve una chiave, o l'invito di qualcuno.")
			return
	_s("click")
	var ev := s.attendi(float(ImperoState.par().minuti_stanza))
	accoda_esito({"eventi": ev, "notifiche": []}, "")
	if s.is_over:
		_esegui_coda()
		return
	var arrivo: Array = p.get("arrivo", [2, 2])
	var dissolvenza := ColorRect.new()
	dissolvenza.color = Color.BLACK
	dissolvenza.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dissolvenza.modulate.a = 0.0
	dissolvenza.mouse_filter = Control.MOUSE_FILTER_STOP
	_palco.add_child(dissolvenza)
	var tw := create_tween()
	tw.tween_property(dissolvenza, "modulate:a", 1.0, 0.18)
	tw.tween_callback(func():
		entra_stanza(p.verso, arrivo)
		_esegui_coda())


func _su_oggetto(o: Dictionary) -> void:
	if _bloccato():
		return
	_s("click")
	if o.has("minigioco"):
		if o.minigioco == "roulette":
			var r := RouletteUI.new()
			_apri_sovrapposto(r)
			r.avvia(self, s)
		else:
			var l := LottaUI.new()
			_apri_sovrapposto(l)
			l.avvia(self, s)
		return
	var voci := voci_oggetto(o)
	if voci.is_empty():
		esamina(o)
		return
	_menu_oggetto(o, voci)


func voci_oggetto(o: Dictionary) -> Array:
	var out: Array = []
	var ids: Array = o.get("voci", [])
	for v in s.voci(s.luogo):
		if ids.has(v.id):
			out.append(v)
	return out


func _menu_oggetto(o: Dictionary, voci: Array) -> void:
	var v := _nuovo_modale(820.0)
	v.add_child(Stile.etichetta(str(o.nome).to_upper(), Stile.TITOLI, Stile.SABBIA))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, mini(440, 132 * voci.size() + 10))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 8)
	sc.add_child(lista)
	for voce in voci:
		lista.add_child(_carta(voce))
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 12)
	v.add_child(riga)
	if o.has("esamina"):
		var e := _grande("ESAMINARE  · %d min" % int(ImperoState.par().minuti_esamina), Stile.GRIGIO, 72.0)
		e.pressed.connect(func():
			_modale.queue_free()
			_modale = null
			esamina(o))
		riga.add_child(e)
	var no := _grande("LASCIA STARE", Stile.GRIGIO, 72.0)
	no.pressed.connect(func():
		_s("click")
		_chiudi_modale())
	riga.add_child(no)


static func durata_testo(ore: float) -> String:
	if ore <= 0.0:
		return "subito"
	var m := int(roundf(ore * 60.0))
	if m < 60:
		return "%d min" % m
	if m % 60 == 0:
		return "%dh" % (m / 60)
	return "%dh %02dm" % [m / 60, m % 60]


func _categoria(voce: Dictionary) -> String:
	var tipo: String = voce.tipo
	if tipo == "cresci":
		return CATEGORIA_GIRO.get(str(voce.id).split(":")[1], "Crimine organizzato")
	if tipo == "colpo" and voce.id in ["rapina", "furgone"]:
		return "Crimine"
	return CATEGORIA_TIPO.get(tipo, "Narrativo")


func _carta(voce: Dictionary) -> CartaUI:
	var det: String = "%s\nDura %s." % [voce.descrizione, durata_testo(float(voce.durata))]
	var carta := CartaUI.new(_categoria(voce), voce.nome, det, float(voce.rischio))
	if voce.nota != "":
		carta.imposta_badge(voce.nota, Stile.GRIGIO.lightened(0.3))
	elif voce.tipo == "mossa":
		carta.imposta_badge("GRANDE MOSSA, UNA SOLA OCCASIONE", Stile.GIALLO)
	elif voce.tipo == "dona":
		carta.imposta_badge("Puoi donare anche una sola ora", Stile.SABBIA)
	elif float(voce.durata) >= s.sirio:
		carta.imposta_badge("A Sirio restano %s: potrebbe non finirla" % ore(s.sirio), Stile.ROSSO)
	carta.abilita(voce.disponibile and not s.is_over)
	carta.premuta.connect(_su_voce.bind(voce))
	return carta


func _su_voce(voce: Dictionary) -> void:
	if s.is_over:
		return
	_s("click")
	if _modale != null:
		_modale.queue_free()
		_modale = null
	if voce.tipo == "dona":
		_apri_donazione()
		return
	if voce.tipo == "liquida":
		_conferma("Vendere tutto", "Vendi la rete in una notte. Se va bene incassi molto, ma da domani non entra più niente.", "VENDI", func(): esegui(voce.id))
		return
	if float(voce.durata) >= s.sirio:
		_conferma("Ne vale la pena?", "A Sirio restano %s. Questa cosa ne chiede %s." % [ore(s.sirio), durata_testo(float(voce.durata))], "VAI LO STESSO", func(): esegui(voce.id))
		return
	esegui(voce.id)


## Esegue una voce nel luogo dove si trova Sirio. Pubblica per i test.
func esegui(id: String) -> void:
	var prima := s.ora_testo()
	var minuti_prima := s.tempo_min
	var esito := s.esegui(id, s.luogo)
	if esito.get("rifiutata", false):
		notifica(str(esito.motivo))
		_esegui_coda()
		return
	if esplorazione != null:
		esplorazione.ferma()
	for ris in esito.risultati:
		var ok: bool = ris.successo
		_scrivi("%s. %s" % [ris.titolo, ris.testo])
		if ris.roll != null:
			var titolo: String = ris.titolo
			var testo: String = ris.testo
			var roll = ris.roll
			var deltas := "\n".join(ris.righe)
			_coda.append(func(): _mostra_dado(titolo, roll, ok, testo, deltas))
		elif not ris.righe.is_empty():
			notifica("%s: %s" % [ris.titolo, ", ".join(ris.righe)])
	var passati := s.tempo_min - minuti_prima
	if passati >= 60.0 and not s.is_over:
		_coda.push_front(func(): _mostra_tempo(prima, s.ora_testo(), passati))
	accoda_esito({"eventi": esito.eventi, "notifiche": esito.notifiche}, "")
	_aggiorna()
	_esegui_coda()


## Schermata breve che fa vedere le ore passare.
func _mostra_tempo(da: String, a: String, minuti: float) -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.0)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	_strato.add_child(fondo)
	_modale = fondo
	var l := Stile.etichetta(da, 40, Stile.SABBIA)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.offset_left = -400
	l.offset_right = 400
	l.offset_top = -40
	l.offset_bottom = 40
	fondo.add_child(l)
	var sotto := Stile.etichetta("Passano %s. Per Sirio e per Sara." % durata_testo(minuti / 60.0), 20, Stile.GRIGIO.lightened(0.3))
	sotto.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sotto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sotto.offset_left = -400
	sotto.offset_right = 400
	sotto.offset_top = 40
	sotto.offset_bottom = 80
	fondo.add_child(sotto)
	var tw := create_tween()
	tw.tween_property(fondo, "color:a", 0.85, 0.25)
	tw.tween_interval(0.35)
	tw.tween_callback(func(): l.text = a)
	tw.tween_interval(0.7)
	tw.tween_property(fondo, "color:a", 0.0, 0.2)
	tw.tween_callback(func():
		if _modale == fondo:
			_modale = null
		fondo.queue_free()
		_aggiorna()
		_esegui_coda())


## Esaminare un oggetto: un testo, qualche minuto, a volte un oggetto o un
## ricordo (solo la prima volta).
func esamina(o: Dictionary) -> void:
	var ev := s.attendi(float(ImperoState.par().minuti_esamina))
	var chiave := "esaminato:%s/%s" % [stanza_id, o.id]
	var esito := {"risultati": [], "eventi": ev, "notifiche": []}
	if not s.ricordato(chiave):
		s.ricorda(chiave)
		for e in o.get("effetti", []):
			s.applica_effetto(e, esito)
	var v := _nuovo_modale(720.0)
	v.add_child(Stile.etichetta(str(o.nome).to_upper(), 24, Stile.SABBIA))
	v.add_child(_testo(str(o.get("esamina", "Niente di utile.")), 21))
	var b := _grande("CONTINUA", Stile.GRIGIO, 72.0)
	b.pressed.connect(func():
		_s("click")
		_chiudi_modale())
	v.add_child(b)
	accoda_esito(esito, "")
	_aggiorna()


func _su_persona(p: Dictionary) -> void:
	if _bloccato():
		return
	_s("click")
	if p.has("contatto") and s.incontra(p.contatto):
		notifica("Nuovo contatto in rubrica: %s" % ImperoState.contatto_dati(p.contatto).nome)
	if p.has("dialogo"):
		var d := DialogoUI.new()
		_apri_sovrapposto(d)
		d.avvia(self, s, p)
		return
	var battute: Array = p.get("battute", [])
	var n := int(s.flag.get("battute/" + str(p.id), 0))
	s.flag["battute/" + str(p.id)] = n + 1
	var riga: String = battute[(s.variante(str(p.id), battute.size()) + n) % battute.size()]
	var ev := s.attendi(2.0)
	var v := _nuovo_modale(760.0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var r := TextureRect.new()
	r.texture = PixelMondo.ritratto(p.aspetto, "neutro")
	r.custom_minimum_size = Vector2(144, 144)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(r)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	col.add_child(Stile.etichetta(str(p.nome).to_upper(), 22, Stile.SABBIA))
	var t := _testo("«%s»" % riga, 21)
	col.add_child(t)
	var b := _grande("CONTINUA", Stile.GRIGIO, 64.0)
	b.pressed.connect(func():
		_s("click")
		_chiudi_modale())
	v.add_child(b)
	accoda_esito({"eventi": ev, "notifiche": []}, "")


## Mette un'interfaccia a tutto campo (dialogo, roulette, ring) sopra il mondo.
func _apri_sovrapposto(c: Control) -> void:
	_strato.add_child(c)
	_modale = c
	if esplorazione != null:
		esplorazione.ferma()
	c.connect("chiuso", func():
		if _modale == c:
			_modale = null
		_aggiorna()
		_esegui_coda())


func cutscene(pannelli: Array) -> void:
	var c := CutsceneUI.new()
	add_child(c)
	c.avvia(pannelli)
	var precedente := _modale
	_modale = c
	c.finita.connect(func():
		if _modale == c:
			_modale = precedente if precedente != null and is_instance_valid(precedente) else null
		_aggiorna()
		_esegui_coda())


# =============================================================== tempo reale

func _process(delta: float) -> void:
	if s == null or s.is_over or not tempo_reale:
		return
	if esplorazione == null or _modale != null or _pannello != null:
		_accumulo = 0.0
		return
	_accumulo += delta
	if _accumulo >= SECONDI_PER_MINUTO:
		_accumulo -= SECONDI_PER_MINUTO
		var ev := s.passa_tempo(1.0)
		if not ev.is_empty():
			accoda_esito({"eventi": ev, "notifiche": []}, "")
			_esegui_coda()
		_aggiorna_alto()
		if s.is_over:
			_esegui_coda()


# =============================================================== esiti ed eventi

## Raccoglie notifiche ed eventi prodotti da qualunque gesto: le notifiche
## diventano avvisi, gli eventi gravi entrano in coda come schermate.
func accoda_esito(esito: Dictionary, riga_diario: String) -> void:
	if riga_diario != "":
		_scrivi(riga_diario)
	for n in esito.get("notifiche", []):
		notifica(str(n))
	for ev in esito.get("eventi", []):
		match ev.tipo:
			"patto":
				_coda.append(func(): cutscene(CutsceneUI.VOLPE))
				_coda.append(func(): _mostra_patto(ev))
			"incasso":
				_scrivi(str(ev.testo))
				if float(ev.get("ore", 0.0)) >= 1.0:
					notifica(str(ev.testo))
			"messaggio":
				notifica(str(ev.testo))
			_:
				_scrivi(str(ev.testo))
				if ev.grave:
					_coda.append(func(): _mostra_evento(ev))
				else:
					notifica(str(ev.testo))
	_aggiorna()


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


func _bloccato() -> bool:
	return _modale != null or _pannello != null or s.is_over


# =============================================================== aggiornamenti

func _aggiorna() -> void:
	_aggiorna_alto()
	_aggiorna_tel()
	if esplorazione != null:
		esplorazione.attiva = _modale == null and _pannello == null and not s.is_over
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
	var dove := str(ImperoState.luogo_dati(s.luogo).get("nome", ""))
	if stanza_id != "" and stanza_dati(stanza_id).nome != dove:
		dove += " · " + str(stanza_dati(stanza_id).nome)
	elif stanza_id == "":
		dove = "In strada, " + dove
	_lbl_luogo.text = dove
	_lbl_sirio.text = ore(s.sirio)
	_bar_sirio.max_value = maxf(100.0, s.sirio)
	_bar_sirio.value = s.sirio
	_lbl_sara.text = ("%.1f giorni" % s.giorni_sara()) if s.sara < 1000.0 else Stile.ore(s.sara)
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
	var espr := "neutro"
	if int(sonno[2]) >= 2 or int(fame[2]) >= 2:
		espr = "stanco"
	elif s.sara < 72.0:
		espr = "triste"
	_avatar.texture = PixelMondo.ritratto("sirio", espr)
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


func _imposta_musica() -> void:
	if audio == null:
		return
	var voluta := "citta"
	if s.sara < SOGLIA_ENDGAME_ORE and not s.is_over:
		voluta = "endgame"
	elif stanza_id != "":
		voluta = str(stanza_dati(stanza_id).get("musica", "citta"))
	if voluta != _musica:
		_musica = voluta
		audio.suona_musica(voluta)


func _scrivi(testo: String, _colore: Color = Stile.CHIARO) -> void:
	_diario.push_front([s.ora_testo() if s != null else "", testo])
	if _diario.size() > 120:
		_diario.pop_back()


func notifica(testo: String) -> void:
	_scrivi(testo)
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
		notifica(str(esito.get("motivo", "")))
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
	if esplorazione != null and s != null:
		esplorazione.attiva = _modale == null and not s.is_over


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
		lista.add_child(_testo("Ogni telefonata costa cinque minuti, a Sirio e a Sara.", 16, Stile.GRIGIO.lightened(0.2)))
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
		notifica(str(esito.motivo))
		return
	if not _chat.has(cid):
		_chat[cid] = [[false, str(ImperoState.contatto_dati(cid).saluto)]]
	_chat[cid].append([true, testo])
	_chat[cid].append([false, str(esito.get("risposta", ""))])
	for n in esito.notifiche:
		_chat[cid].append(["", str(n)])
	accoda_esito({"eventi": esito.eventi, "notifiche": esito.notifiche}, "Telefonata con %s." % ImperoState.contatto_dati(cid).nome)
	_esegui_coda()




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
	conti.add_child(Stile.etichetta("CONTI DI SEI ORE", 22, Stile.SABBIA))
	var righe := ["La rete rende %s" % Stile.ore(s.flusso_lordo(), true)]
	if s.uomini > 0:
		righe.append("%d uomini da pagare: %s" % [s.uomini, Stile.ore(-s.uomini * float(p.paga_uomo), true)])
	if s.rate_debito > 0:
		righe.append("Rata a Rocco: %s (ne mancano %d)" % [Stile.ore(-float(p.anticipo.rata), true), s.rate_debito])
	righe.append("Sei ore che passano: %s" % Stile.ore(-float(p.ore_fascia), true))
	righe.append("Netto: %s ogni sei ore" % Stile.ore(s.flusso_netto(), true))
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
		var info := "%d %s.  Rendono %s ogni sei ore.  Controllo %d%%." % [int(st.persone), d.persone, Stile.ore(s.tributo(g)), int(float(st.controllo) * 100.0)]
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
	cal.add_child(_testo("Polizia %.0f: retata %.1f%% ogni sei ore.\nRivali %.0f: assalto %.1f%% ogni sei ore.\nFama %.0f: scandalo %.1f%% ogni sei ore.\nUomini: %d." % [
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
	for def in [["mosse", "Grandi mosse"], ["stato", "Sirio"], ["diario", "Diario"], ["obiettivi", "Obiettivi"], ["opzioni", "Opzioni"]]:
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
			"diario":
				_scheda_diario(contenuto)
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
	var testa := HBoxContainer.new()
	testa.add_theme_constant_override("separation", 16)
	c.add_child(testa)
	testa.add_child(_icona(PixelMondo.ritratto("sirio", "neutro"), 144))
	var stat := VBoxContainer.new()
	stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	testa.add_child(stat)
	stat.add_child(Stile.etichetta("SIRIO", 24, Stile.SABBIA))
	for nome in ImperoState.dati().stat:
		var d: Dictionary = ImperoState.dati().stat[nome]
		var val := int(s.stat.get(nome, 1))
		stat.add_child(_testo("%s %s  %d   %s" % [d.nome.rpad(11), "■".repeat(val) + "□".repeat(5 - val), val, d.descrizione], 18))
	stat.add_child(_testo("Le statistiche aprono risposte nei dialoghi e aiutano i tiri. Crescono con quello che fai.", 16, Stile.GRIGIO.lightened(0.3)))
	c.add_child(HSeparator.new())
	c.add_child(Stile.etichetta("IN TASCA", 22, Stile.SABBIA))
	if s.oggetti.is_empty():
		c.add_child(_testo("Niente, a parte le chiavi di casa.", 18, Stile.GRIGIO.lightened(0.3)))
	for o in s.oggetti:
		var d: Dictionary = ImperoState.dati().oggetti[o]
		c.add_child(_testo("%s. %s" % [d.nome, d.descrizione], 18))
	c.add_child(HSeparator.new())
	var sonno := s.stato_sonno()
	var fame := s.stato_fame()
	var m := s.malus()
	c.add_child(Stile.etichetta("BISOGNI", 22, Stile.SABBIA))
	c.add_child(_testo("Sveglio da %dh: %s.   Ultimo pasto %dh fa: %s." % [int(s.sveglio), sonno[0], int(s.digiuno), fame[0]], 19))
	var effetto := "Nessun effetto sui tiri." if int(m.modificatore) == 0 else "Malus ai tiri: %d%s." % [int(m.modificatore), " e svantaggio" if m.modo == DiceSystem.RollMode.SVANTAGGIO else ""]
	c.add_child(_testo(effetto + " Si dorme a casa, in camera. Si mangia in cucina, all'osteria, in piazza, alla stazione o all'Aurora.", 18, Stile.GRIGIO.lightened(0.3)))
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
	c.add_child(_testo("Seed %d. Difficoltà %d. Giorno %d di %d. Un secondo nel mondo è un minuto di vita." % [s.seed_run, s.livello_difficolta, s.giorno(), int(ImperoState.par().giorni)], 17, Stile.GRIGIO.lightened(0.3)))


func _scheda_diario(c: VBoxContainer) -> void:
	if _diario.is_empty():
		c.add_child(_testo("Niente da ricordare, per ora.", 18, Stile.GRIGIO))
	for voce in _diario:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.add_child(Stile.etichetta(str(voce[0]), 14, Stile.GRIGIO.lightened(0.2)))
		box.add_child(_testo(str(voce[1]), 18))
		c.add_child(box)


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
		if _modale is DialogoUI or _modale is RouletteUI or _modale is LottaUI:
			_modale.chiudi()
		elif _modale is CutsceneUI:
			_modale.fine()
		return
	if _pannello != null:
		_chiudi_pannello()
	elif mappa != null:
		entra_luogo(s.luogo)
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
	if esplorazione != null:
		esplorazione.attiva = false
	var finale := [["tomba", "Sirio si siede su un gradino e non si rialza. La città continua a piovere."]]
	if s.fine == "dono":
		finale = [["incubatrice", "Sirio appoggia la mano sul vetro. La sabbia passa da lui a lei come un respiro."], ["alba", Narrativa.epilogo(true, s.sara > 0.0, s.sirio > 0.0, s.karma)]]
	elif s.fine == "sara":
		finale = [["culla", "La culla resta vuota. Sirio aveva ancora sabbia in tasca."]]
	var c := CutsceneUI.new()
	add_child(c)
	c.avvia(finale)
	c.finita.connect(_mostra_fine_riepilogo)


func _mostra_fine_riepilogo() -> void:
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
		v.add_child(_testo("Picco della rete: %s ogni sei ore. Giorno %d di %d." % [Stile.ore(s.picco_flusso), s.giorno(), int(ImperoState.par().giorni)], 18, Stile.GRIGIO.lightened(0.3)))
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
