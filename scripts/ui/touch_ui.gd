class_name TouchUI
extends Control
## Interfaccia touch della demo: HUD a sinistra (320px), area di gioco al
## centro, barra di navigazione in basso. Non contiene regole di gioco: ogni
## decisione passa da GameState, come fa GameUI.

signal torna_al_titolo
signal nuova_partita

const LARGHEZZA_HUD := 320
const ALTEZZA_TAB := 72
const SOGLIA_ENDGAME_ORE := 24.0
const SOGLIA_PULSE_ORE := 4.0
const SOGLIA_CRITICA := 75.0
const SOGLIA_POCHE_ORE := 8.0

const RISORSE := [
	{"chiave": "polizia", "nome": "Polizia", "colore": Color("4a6fb0"), "min": 0.0},
	{"chiave": "rivalita", "nome": "Rivalità", "colore": Color("b04a4a"), "min": 0.0},
	{"chiave": "fama", "nome": "Fama", "colore": Color("d0a030"), "min": 0.0},
	{"chiave": "karma", "nome": "Karma", "colore": Color("8a8aa8"), "min": -100.0},
	{"chiave": "fede", "nome": "Fede", "colore": Color("c87830"), "min": 0.0},
]

var stato: GameState
var profilo: PlayerProfile
var audio: MusicEngine
var _e_seed_del_giorno := false

var _centro: Control
var _pagine: Dictionary = {}
var _tab_bottoni: Dictionary = {}
var _pagina_corrente := "azioni"
var _modale: Control = null
var _coda: Array = []
var _log: Array[String] = []
var _fine_mostrata := false

var _carte_azione: Dictionary = {}
var _sezioni_azione: Dictionary = {}
var _carte_traccia: Dictionary = {}
var _righe_traccia: Dictionary = {}
var _carte_sottotrama: Dictionary = {}
var _carta_cashin: CartaUI
var _lbl_sinergia: Label
var _lbl_ultimo: Label
var _lbl_diario: RichTextLabel
var _lbl_profilo: Label
var _slider_dono: HSlider
var _lbl_dono: Label
var _btn_dona: Button
var _toast: Label

# HUD
var _avatar: TextureRect
var _frame_avatar := 0
var _barra_sabbia: ProgressBar
var _barra_figlia: ProgressBar
var _lbl_sabbia: Label
var _lbl_figlia: Label
var _lbl_seed: Label
var _barre_risorse: Dictionary = {}
var _val_risorse: Dictionary = {}
var _righe_risorse: Dictionary = {}
var _lbl_traccia: Label
var _barra_traccia: ProgressBar
var _traccia_attiva := ""
var _critico_prima: Dictionary = {}
var _tween_pulse: Dictionary = {}
var _musica_corrente := ""


func avvia(stato_iniziale: GameState, profilo_iniziale: PlayerProfile, motore_audio: MusicEngine, e_seed_del_giorno: bool = false) -> void:
	stato = stato_iniziale
	profilo = profilo_iniziale
	audio = motore_audio
	_e_seed_del_giorno = e_seed_del_giorno
	if profilo != null:
		stato.karma = profilo.karma
	theme = Stile.tema()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_costruisci()
	_aggiorna_tutto()
	_scrivi_diario("Ledune, prima notte. Sara dorme. Il conto parte adesso.")
	_imposta_musica()
	_coda_bivio(TestiDemo.BIVIO_INIZIO)
	_esegui_coda()


func _s(nome: String) -> void:
	if audio != null:
		audio.sfx(nome)


# ------------------------------------------------------------ costruzione

func _costruisci() -> void:
	var fondo := ColorRect.new()
	fondo.color = Stile.NERO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var radice := VBoxContainer.new()
	radice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radice.add_theme_constant_override("separation", 0)
	add_child(radice)

	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 0)
	radice.add_child(corpo)

	corpo.add_child(_costruisci_hud())

	_centro = Control.new()
	_centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_centro.clip_contents = true
	corpo.add_child(_centro)

	_pagine["azioni"] = _costruisci_pagina_azioni()
	_pagine["tracce"] = _costruisci_pagina_tracce()
	_pagine["sottotrame"] = _costruisci_pagina_sottotrame()
	_pagine["profilo"] = _costruisci_pagina_profilo()
	for nome in _pagine:
		_centro.add_child(_pagine[nome])

	radice.add_child(_costruisci_tab_bar())

	_toast = Stile.etichetta("", 20, Stile.CHIARO)
	_toast.add_theme_stylebox_override("normal", Stile.box(Color("000000cc"), Stile.ROSSO, 2, 10))
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	add_child(_toast)

	_mostra_pagina("azioni")


func _costruisci_hud() -> Control:
	var pannello := PanelContainer.new()
	pannello.custom_minimum_size = Vector2(LARGHEZZA_HUD, 0)
	pannello.add_theme_stylebox_override("panel", Stile.box(Color("101022"), Stile.GRIGIO, 3, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pannello.add_child(v)

	var testa := HBoxContainer.new()
	testa.add_theme_constant_override("separation", 10)
	v.add_child(testa)
	_avatar = TextureRect.new()
	_avatar.texture = PixelArt.avatar_frame(0)
	_avatar.custom_minimum_size = Vector2(80, 120)
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	testa.add_child(_avatar)
	var nome_col := VBoxContainer.new()
	nome_col.alignment = BoxContainer.ALIGNMENT_CENTER
	testa.add_child(nome_col)
	nome_col.add_child(Stile.etichetta("SIRIO", Stile.TITOLI, Stile.SABBIA))
	_lbl_seed = Stile.etichetta("", 15, Stile.GRIGIO)
	_lbl_seed.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_lbl_seed.custom_minimum_size = Vector2(170, 0)
	nome_col.add_child(_lbl_seed)

	var anim := create_tween().set_loops()
	anim.tween_interval(0.45)
	anim.tween_callback(_avanza_avatar)

	_lbl_sabbia = Stile.etichetta("", Stile.VALORI, Stile.SABBIA)
	v.add_child(Stile.etichetta("Sabbia-Padre", 16, Stile.GRIGIO))
	v.add_child(_lbl_sabbia)
	_barra_sabbia = _nuova_barra(Stile.SABBIA, 18)
	v.add_child(_barra_sabbia)

	_lbl_figlia = Stile.etichetta("", Stile.VALORI, Stile.ROSSO)
	v.add_child(Stile.etichetta("Tempo-Figlia", 16, Stile.GRIGIO))
	v.add_child(_lbl_figlia)
	_barra_figlia = _nuova_barra(Stile.ROSSO, 18)
	v.add_child(_barra_figlia)

	v.add_child(HSeparator.new())

	for r in RISORSE:
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", 6)
		var icona := TextureRect.new()
		icona.texture = PixelArt.icona_risorsa(r.chiave)
		icona.custom_minimum_size = Vector2(32, 32)
		icona.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icona.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		riga.add_child(icona)
		var colonna := VBoxContainer.new()
		colonna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		colonna.add_theme_constant_override("separation", 0)
		var nome := Stile.etichetta(r.nome, 15, Stile.GRIGIO)
		colonna.add_child(nome)
		var barra := _nuova_barra(r.colore, 10)
		barra.min_value = r.min
		barra.max_value = 100.0
		colonna.add_child(barra)
		riga.add_child(colonna)
		var valore := Stile.etichetta("0", Stile.VALORI, Stile.CHIARO)
		valore.custom_minimum_size = Vector2(52, 0)
		valore.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		riga.add_child(valore)
		v.add_child(riga)
		_barre_risorse[r.chiave] = barra
		_val_risorse[r.chiave] = valore
		_righe_risorse[r.chiave] = riga

	v.add_child(HSeparator.new())
	v.add_child(Stile.etichetta("Traccia attiva", 16, Stile.GRIGIO))
	_lbl_traccia = Stile.etichetta("Nessuna", 18, Stile.CHIARO)
	_lbl_traccia.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lbl_traccia)
	_barra_traccia = _nuova_barra(Stile.VERDE, 10)
	_barra_traccia.max_value = 2.0
	v.add_child(_barra_traccia)
	return pannello


func _nuova_barra(colore: Color, altezza: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, altezza)
	b.add_theme_stylebox_override("fill", Stile.barra(colore))
	b.max_value = 100.0
	return b


func _avanza_avatar() -> void:
	_frame_avatar = (_frame_avatar + 1) % 4
	_avatar.texture = PixelArt.avatar_frame(_frame_avatar)


func _costruisci_tab_bar() -> Control:
	var barra := HBoxContainer.new()
	barra.custom_minimum_size = Vector2(0, ALTEZZA_TAB)
	barra.add_theme_constant_override("separation", 4)
	for def in [["azioni", "Azioni"], ["tracce", "Tracce"], ["sottotrame", "Sottotrame"], ["profilo", "Profilo"]]:
		var b := Button.new()
		b.text = " " + def[1]
		b.icon = _scalata(PixelArt.icona_tab(def[0]), 2)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_su_tab.bind(def[0]))
		barra.add_child(b)
		_tab_bottoni[def[0]] = b
	return barra


func _scalata(t: ImageTexture, f: int) -> ImageTexture:
	return ImageTexture.create_from_image(PixelArt.ingrandisci(t.get_image(), f))


func _su_tab(nome: String) -> void:
	_s("click")
	if _modale != null:
		return
	_mostra_pagina(nome)


func _mostra_pagina(nome: String) -> void:
	_pagina_corrente = nome
	for n in _pagine:
		_pagine[n].visible = n == nome
	for n in _tab_bottoni:
		var b: Button = _tab_bottoni[n]
		if n == nome:
			Stile.applica_bottone(b, Stile.ROSSO)
			b.add_theme_color_override("font_color", Stile.CHIARO)
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("hover")
			b.remove_theme_stylebox_override("pressed")
			b.remove_theme_stylebox_override("disabled")
			b.remove_theme_color_override("font_color")
	if nome == "profilo":
		_aggiorna_profilo()


func _nuova_pagina() -> Array:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margine := MarginContainer.new()
	margine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lato in ["left", "right", "top", "bottom"]:
		margine.add_theme_constant_override("margin_" + lato, 12)
	scroll.add_child(margine)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margine.add_child(v)
	return [scroll, v]


func _intestazione(testo: String) -> Label:
	var l := Stile.etichetta(testo.to_upper(), Stile.TITOLI, Stile.SABBIA)
	return l


func _griglia(colonne: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = colonne
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	return g


# ------------------------------------------------------------ pagina azioni

func _nome_categoria(c: String) -> String:
	return "Occasioni" if c == "Evento" else c


func _costruisci_pagina_azioni() -> Control:
	var p := _nuova_pagina()
	var v: VBoxContainer = p[1]

	_lbl_ultimo = Stile.etichetta("Scegli. Ogni azione costa ore di Sara.", 18, Stile.SABBIA)
	_lbl_ultimo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lbl_ultimo)

	var chips_scroll := ScrollContainer.new()
	chips_scroll.custom_minimum_size = Vector2(0, 68)
	chips_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	chips_scroll.add_child(chips)
	v.add_child(chips_scroll)

	var spost := CartaUI.new("Narrativo", "Spostarsi in città", "Durata incerta. Un imprevisto costa più ore.")
	spost.premuta.connect(_su_spostamento)
	v.add_child(spost)

	var categorie: Array[String] = []
	var per_categoria: Dictionary = {}
	for azione: ActionData in ActionDatabase.get_all():
		if azione.rischio_pct >= 1.0:
			continue
		if not per_categoria.has(azione.categoria):
			per_categoria[azione.categoria] = []
			categorie.append(azione.categoria)
		per_categoria[azione.categoria].append(azione)

	_aggiungi_chip(chips, "Tutte")
	for cat in categorie:
		_aggiungi_chip(chips, _nome_categoria(cat))
		var testa := Stile.etichetta(_nome_categoria(cat).to_upper(), 20, Stile.GRIGIO)
		v.add_child(testa)
		var griglia := _griglia(2)
		v.add_child(griglia)
		_sezioni_azione[_nome_categoria(cat)] = [testa, griglia]
		for azione: ActionData in per_categoria[cat]:
			var carta := CartaUI.new(azione.categoria, azione.nome, _dettaglio_azione(azione), azione.rischio_pct)
			if azione.unica_per_run:
				carta.imposta_badge("UNICA PER RUN", Stile.GIALLO)
			carta.premuta.connect(_su_azione.bind(azione))
			griglia.add_child(carta)
			_carte_azione[azione.nome] = carta
	return p[0]


func _aggiungi_chip(contenitore: HBoxContainer, nome: String) -> void:
	var b := Button.new()
	b.text = nome
	b.custom_minimum_size = Vector2(0, 60)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(_filtra_categoria.bind(nome))
	contenitore.add_child(b)


func _filtra_categoria(nome: String) -> void:
	_s("click")
	for cat in _sezioni_azione:
		var visibile: bool = nome == "Tutte" or nome == cat
		_sezioni_azione[cat][0].visible = visibile
		_sezioni_azione[cat][1].visible = visibile


func _dettaglio_azione(a: ActionData) -> String:
	return "Costo %s   Resa %s" % [Stile.ore(a.costo_tempo_figlia_ore), Stile.ore(a.effetto_sabbia_padre_ore, true)]


# ------------------------------------------------------------ pagina tracce

func _costruisci_pagina_tracce() -> Control:
	var p := _nuova_pagina()
	var v: VBoxContainer = p[1]
	v.add_child(_intestazione("Tracce"))
	var sotto := Stile.etichetta("Strade lunghe. Si sale per gradi. Un passo falso chiude la porta.", 17, Stile.GRIGIO)
	sotto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sotto)

	for nome_traccia in TrackDatabase.get_nomi_tracce_normali():
		v.add_child(Stile.etichetta(str(nome_traccia).to_upper(), 20, Stile.GRIGIO))
		var griglia := _griglia(2)
		v.add_child(griglia)
		for rango in [1, 2]:
			var riga := TrackDatabase.get_riga(nome_traccia, rango)
			if riga == null:
				continue
			var chiave := "%s|%d" % [nome_traccia, rango]
			var carta := CartaUI.new(_categoria_traccia(nome_traccia), "Rango %d: %s" % [rango, riga.nome_rango], _dettaglio_traccia(riga), riga.rischio_pct)
			carta.premuta.connect(_su_traccia.bind(riga))
			griglia.add_child(carta)
			_carte_traccia[chiave] = carta
			_righe_traccia[chiave] = riga

	v.add_child(HSeparator.new())
	v.add_child(_intestazione("Sinergie"))
	_lbl_sinergia = Stile.etichetta("", 18, Stile.SABBIA)
	_lbl_sinergia.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lbl_sinergia)
	_carta_cashin = CartaUI.new("Grande colpo", "Incassare la combo", "Una sola volta. Se il tiro fallisce, perdi tutti i ranghi coinvolti.", GameState.CASH_IN_RISCHIO_PCT)
	_carta_cashin.premuta.connect(_su_cashin)
	v.add_child(_carta_cashin)

	var bonus := TrackDatabase.get_tracce_bonus()
	if not bonus.is_empty():
		v.add_child(Stile.etichetta("SIGILLATE", 20, Stile.GRIGIO))
		var g := _griglia(3)
		v.add_child(g)
		for b: TrackBonusData in bonus:
			var c := CartaUI.new("Mendicare", b.traccia, "Non ancora aperta.")
			c.abilita(false)
			g.add_child(c)
	return p[0]


func _categoria_traccia(nome: String) -> String:
	var mappa := {"Lavoro": "Lavoro", "Criminale": "Crimine", "Politica": "Corruzione", "Azzardo": "Azzardo", "Bancaria": "Acquisto", "Religiosa": "Altruismo", "Occulto": "Tradimento"}
	return mappa.get(str(nome).split(" ")[0], "Narrativo")


func _dettaglio_traccia(r: TrackData) -> String:
	return "Costo %s   Resa %s" % [Stile.ore(r.costo_tempo_figlia_ore), Stile.ore(r.effetto_sabbia_padre_ore, true)]


# ------------------------------------------------------------ pagina sottotrame

func _costruisci_pagina_sottotrame() -> Control:
	var p := _nuova_pagina()
	var v: VBoxContainer = p[1]
	v.add_child(_intestazione("Sottotrame"))
	var sotto := Stile.etichetta("Occasioni rare, una sola volta per run. Il tentativo si brucia anche se fallisce.", 17, Stile.GRIGIO)
	sotto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sotto)
	var griglia := _griglia(2)
	v.add_child(griglia)
	for sub: SubplotData in SubplotDatabase.get_all():
		var det := "Costo %s   Resa %s" % [Stile.ore(sub.costo_tempo_figlia_ore), Stile.ore(sub.effetto_sabbia_padre_ore, true)]
		if sub.prerequisito != "":
			det += "\nRichiede: " + sub.prerequisito
		var carta := CartaUI.new("Grande colpo", TestiDemo.nome_sottotrama_visibile(sub.nome), det, sub.rischio_pct)
		carta.premuta.connect(_su_sottotrama.bind(sub))
		griglia.add_child(carta)
		_carte_sottotrama[sub.nome] = carta
	return p[0]


# ------------------------------------------------------------ pagina profilo

func _costruisci_pagina_profilo() -> Control:
	var p := _nuova_pagina()
	var v: VBoxContainer = p[1]
	v.add_child(_intestazione("Profilo"))
	_lbl_profilo = Stile.etichetta("", 18, Stile.CHIARO)
	_lbl_profilo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lbl_profilo)

	v.add_child(HSeparator.new())
	v.add_child(_intestazione("Donazione"))
	var nota := Stile.etichetta("Una volta sola. Irreversibile. La run finisce qui.", 17, Stile.GRIGIO)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nota)
	_slider_dono = HSlider.new()
	_slider_dono.custom_minimum_size = Vector2(0, 56)
	_slider_dono.step = 0.1
	_slider_dono.value_changed.connect(func(_x): _aggiorna_dono())
	v.add_child(_slider_dono)
	_lbl_dono = Stile.etichetta("", Stile.VALORI, Stile.SABBIA)
	v.add_child(_lbl_dono)
	_btn_dona = Button.new()
	_btn_dona.text = "DONARE A SARA"
	_btn_dona.custom_minimum_size = Vector2(0, 96)
	Stile.applica_bottone(_btn_dona, Stile.ROSSO)
	_btn_dona.pressed.connect(_su_dona)
	v.add_child(_btn_dona)

	v.add_child(HSeparator.new())
	v.add_child(_intestazione("Audio"))
	for def in [["Volume generale", "volume_master"], ["Musica", "volume_musica"], ["Effetti", "volume_effetti"]]:
		v.add_child(Stile.etichetta(def[0], 17, Stile.GRIGIO))
		var s := HSlider.new()
		s.custom_minimum_size = Vector2(0, 48)
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = audio.get(def[1]) if audio != null else 0.8
		s.value_changed.connect(_su_volume.bind(def[1]))
		v.add_child(s)

	v.add_child(HSeparator.new())
	v.add_child(_intestazione("Diario"))
	_lbl_diario = RichTextLabel.new()
	_lbl_diario.bbcode_enabled = true
	_lbl_diario.fit_content = true
	_lbl_diario.scroll_active = false
	v.add_child(_lbl_diario)

	var esci := Button.new()
	esci.text = "TORNA AL TITOLO"
	esci.custom_minimum_size = Vector2(0, 96)
	esci.pressed.connect(_su_esci)
	v.add_child(esci)
	return p[0]


func _su_volume(valore: float, proprieta: String) -> void:
	if audio != null:
		audio.set(proprieta, valore)


func _aggiorna_profilo() -> void:
	var karma_persistente := profilo.karma if profilo != null else 0.0
	var contatti := profilo.rete_contatti_sbloccati.size() if profilo != null else 0
	var righe := PackedStringArray()
	righe.append("Turno: %d" % stato.turno)
	righe.append("Seed: %d" % stato.seed_run)
	righe.append("Difficoltà: %d" % stato.livello_difficolta)
	righe.append("Karma di questa run: %.0f   Karma salvato: %.0f" % [stato.karma, karma_persistente])
	righe.append("Contatti nella rete: %d" % contatti)
	righe.append("Fede del Culto: %.0f   Fede della Setta: %.0f" % [stato.fede_culto, stato.fede_setta])
	_lbl_profilo.text = "\n".join(righe)
	var massimo := maxf(stato.sabbia_padre_ore, 0.1)
	_slider_dono.min_value = 0.0
	_slider_dono.max_value = massimo
	_slider_dono.editable = not stato.donation_made and not stato.is_over
	if _slider_dono.value > massimo:
		_slider_dono.value = massimo
	_aggiorna_dono()
	_lbl_diario.text = "\n".join(_log.slice(maxi(_log.size() - 40, 0)))


func _aggiorna_dono() -> void:
	_lbl_dono.text = "Dono: %s su %s" % [Stile.ore(_slider_dono.value), Stile.ore(stato.sabbia_padre_ore)]
	_btn_dona.disabled = stato.donation_made or stato.is_over or _slider_dono.value < 0.1


func _scrivi_diario(testo: String) -> void:
	_log.append("[color=#c8a97e]%d.[/color] %s" % [stato.turno, testo])


# ------------------------------------------------------------ aggiornamenti

func _aggiorna_tutto() -> void:
	_aggiorna_hud()
	_aggiorna_carte()


func _aggiorna_hud() -> void:
	_lbl_seed.text = "Seed %d\nDifficoltà %d" % [stato.seed_run, stato.livello_difficolta]
	_barra_sabbia.max_value = maxf(GameState.SABBIA_PADRE_INIZIALE, stato.sabbia_padre_ore)
	_barra_sabbia.value = stato.sabbia_padre_ore
	_lbl_sabbia.text = "%s" % _testo_ore(stato.sabbia_padre_ore)
	_barra_figlia.max_value = GameState.TEMPO_FIGLIA_INIZIALE
	_barra_figlia.value = stato.tempo_figlia_ore
	_lbl_figlia.text = "%s" % _testo_ore(stato.tempo_figlia_ore)
	_pulse(_lbl_sabbia, "sabbia", stato.sabbia_padre_ore < SOGLIA_PULSE_ORE and not stato.is_over)
	_pulse(_lbl_figlia, "figlia", stato.tempo_figlia_ore < SOGLIA_PULSE_ORE and not stato.is_over)

	var valori := {
		"polizia": stato.attenzione_polizia, "rivalita": stato.rivalita_criminale,
		"fama": stato.fama_pubblica, "karma": stato.karma, "fede": maxf(stato.fede_culto, stato.fede_setta),
	}
	var critico_ora := {}
	for k in valori:
		_barre_risorse[k].value = valori[k]
		_val_risorse[k].text = "%.0f" % valori[k]
		var critica: bool = valori[k] <= -SOGLIA_CRITICA if k == "karma" else (k != "fede" and valori[k] >= SOGLIA_CRITICA)
		critico_ora[k] = critica
		_val_risorse[k].add_theme_color_override("font_color", Stile.ROSSO if critica else Stile.CHIARO)
		if critica and not _critico_prima.get(k, false):
			_scuoti(_righe_risorse[k])
			_s("critica")
	_critico_prima = critico_ora

	if _traccia_attiva != "":
		var rango: int = stato.tracce_raggiunte.get(_traccia_attiva, 0)
		_lbl_traccia.text = "%s, rango %d su 2" % [_traccia_attiva.split(" ")[0], rango]
		_barra_traccia.value = rango
	else:
		_lbl_traccia.text = "Nessuna"
		_barra_traccia.value = 0


func _testo_ore(v: float) -> String:
	return "%s ore" % ("%.1f" % v) if absf(v) < 1000.0 else Stile.ore(v)


func _pulse(nodo: Control, chiave: String, attivo: bool) -> void:
	var esistente: Tween = _tween_pulse.get(chiave)
	if attivo:
		if esistente != null and esistente.is_valid():
			return
		nodo.pivot_offset = Vector2(0.0, nodo.size.y * 0.5)
		var tw := create_tween().set_loops()
		tw.tween_property(nodo, "scale", Vector2(1.15, 1.15), 0.25)
		tw.tween_property(nodo, "scale", Vector2.ONE, 0.25)
		tw.tween_interval(0.0)
		_tween_pulse[chiave] = tw
	elif esistente != null:
		esistente.kill()
		_tween_pulse.erase(chiave)
		nodo.scale = Vector2.ONE


func _scuoti(nodo: Control) -> void:
	var base := nodo.position
	var tw := create_tween()
	for i in 4:
		var dx := 3.0 if i % 2 == 0 else -3.0
		tw.tween_property(nodo, "position:x", base.x + dx, 0.025)
	tw.tween_property(nodo, "position:x", base.x, 0.025)


func _aggiorna_carte() -> void:
	for nome in _carte_azione:
		var carta: CartaUI = _carte_azione[nome]
		var azione := _azione_per_nome(nome)
		var ok := true
		if azione != null:
			ok = stato.azione_disponibile(azione)
			if azione.unica_per_run and not ok:
				carta.imposta_badge("GIÀ USATA", Stile.GRIGIO)
		carta.abilita(ok and not stato.is_over)

	for chiave in _carte_traccia:
		var riga: TrackData = _righe_traccia[chiave]
		var carta: CartaUI = _carte_traccia[chiave]
		var progresso: int = stato.tracce_raggiunte.get(riga.traccia, 0)
		var tentata: bool = stato.azioni_uniche_usate.has(chiave)
		var attivo := false
		if progresso >= riga.rango:
			carta.imposta_badge("RAGGIUNTO", Stile.VERDE)
		elif tentata:
			carta.imposta_badge("FALLITA, CHIUSA", Stile.ROSSO)
		elif stato.traccia_bloccata_da_fede(riga):
			var chiave_fede: String = GameState.FEDE_TRACCE[riga.traccia]
			carta.imposta_badge("Serve Fede %.0f (ora %.0f)" % [GameState.FEDE_SOGLIA_RANGO2, stato._fede(chiave_fede)], Stile.GIALLO)
		else:
			attivo = stato.traccia_disponibile(riga)
			carta.imposta_badge("" if attivo else "Serve il rango 1", Stile.GRIGIO)
		carta.abilita(attivo and not stato.is_over)

	for nome in _carte_sottotrama:
		var carta: CartaUI = _carte_sottotrama[nome]
		var sub := _sottotrama_per_nome(nome)
		var tentata: bool = stato.azioni_uniche_usate.has("sottotrama:%s" % nome)
		if tentata:
			carta.imposta_badge("GIÀ TENTATA", Stile.GRIGIO)
		carta.abilita(sub != null and stato.sottotrama_disponibile(sub) and not tentata and not stato.is_over)

	var combo: Array = stato.combo_tracce()
	if combo.is_empty():
		_lbl_sinergia.text = "Nessuna combo. Serve il rango 2 in almeno due tracce diverse."
	else:
		var molt: float = GameState.SINERGIA_MOLTIPLICATORI.get(combo.size(), GameState.SINERGIA_MOLTIPLICATORI[4])
		_lbl_sinergia.text = "Combo su %d tracce: %s. Moltiplicatore x%.0f." % [combo.size(), ", ".join(combo), molt]
	var malus: Array = stato.malus_attivi()
	if not malus.is_empty():
		var parti: Array[String] = []
		for coppia in malus:
			parti.append("%s e %s" % [coppia[0], coppia[1]])
		_lbl_sinergia.text += "\nTensione tematica attiva: " + ", ".join(parti) + "."
	_carta_cashin.abilita(stato.cash_in_disponibile() and not stato.is_over)


func _azione_per_nome(nome: String) -> ActionData:
	for a: ActionData in ActionDatabase.get_all():
		if a.nome == nome:
			return a
	return null


func _sottotrama_per_nome(nome: String) -> SubplotData:
	for s: SubplotData in SubplotDatabase.get_all():
		if s.nome == nome:
			return s
	return null


func _imposta_musica() -> void:
	if audio == null:
		return
	var voluta := "endgame" if stato.tempo_figlia_ore < SOGLIA_ENDGAME_ORE else "gameplay"
	if voluta != _musica_corrente:
		_musica_corrente = voluta
		audio.suona_musica(voluta)


func _mostra_toast(testo: String) -> void:
	_toast.text = " " + testo + " "
	_toast.visible = true
	_toast.position = Vector2((size.x - _toast.size.x) * 0.5, size.y - ALTEZZA_TAB - 70)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(func(): _toast.visible = false)


# ------------------------------------------------------------ azioni di gioco

func _snapshot() -> Dictionary:
	return {
		"polizia": stato.attenzione_polizia, "rivalita": stato.rivalita_criminale,
		"fama": stato.fama_pubblica, "karma": stato.karma,
		"fede_culto": stato.fede_culto, "fede_setta": stato.fede_setta,
	}


func _bloccato() -> bool:
	return _modale != null or stato.is_over


func _su_azione(azione: ActionData) -> void:
	if _bloccato():
		return
	_s("click")
	var prima := _snapshot()
	var r := stato.applica_azione_con_dado(azione)
	if r.has("rifiutata"):
		_mostra_toast(str(r.motivo))
		return
	var testo := TestiDemo.esito_azione(azione.nome, r.successo)
	_dopo_risoluzione(azione.nome, testo, r, prima)


func _su_traccia(riga: TrackData) -> void:
	if _bloccato():
		return
	_s("click")
	var prima := _snapshot()
	var r := stato.applica_traccia(riga)
	if r.has("rifiutata"):
		_mostra_toast(str(r.motivo))
		return
	if r.successo:
		_traccia_attiva = riga.traccia
	var titolo := "%s, rango %d: %s" % [str(riga.traccia).split(" ")[0], riga.rango, riga.nome_rango]
	_dopo_risoluzione(titolo, TestiDemo.esito_traccia(riga.traccia, riga.nome_rango, r.successo), r, prima)
	if r.successo and stato.bivio_disponibile(TestiDemo.BIVIO_AGGANCIO):
		_coda_bivio(TestiDemo.BIVIO_AGGANCIO)


func _su_sottotrama(sub: SubplotData) -> void:
	if _bloccato():
		return
	_s("click")
	var prima := _snapshot()
	var r := stato.applica_sottotrama(sub)
	if r.has("rifiutata"):
		_mostra_toast(str(r.motivo))
		return
	_dopo_risoluzione(TestiDemo.nome_sottotrama_visibile(sub.nome), TestiDemo.esito_sottotrama(sub.nome, r.successo), r, prima)


func _su_cashin() -> void:
	if _bloccato():
		return
	_s("click")
	var prima := _snapshot()
	var r := stato.applica_cash_in()
	if r.has("rifiutata"):
		_mostra_toast(str(r.motivo))
		return
	var testo := "La combo si chiude in un solo colpo. Ledune tace un momento." if r.successo else "La combo salta. Tutto quello che avevi costruito è fumo."
	_dopo_risoluzione("Incassare la combo", testo, r, prima)


func _su_spostamento() -> void:
	if _bloccato():
		return
	_s("click")
	var prima := _snapshot()
	var r := stato.applica_spostamento()
	if r.has("rifiutata"):
		_mostra_toast(str(r.motivo))
		return
	var esito: Spostamento.Esito = r.spostamento
	var testo := "Un imprevisto sul percorso. Il tragitto dura più del dovuto." if esito.incidente else "La città scorre. Nessun intoppo."
	var r2 := r.duplicate()
	r2["successo"] = not esito.incidente
	r2.erase("roll")
	_dopo_risoluzione("Spostarsi in città", testo, r2, prima)


## Registra l'esito, accoda le schermate successive (dado, evento casuale, bivi)
## e le esegue in ordine.
func _dopo_risoluzione(titolo: String, testo: String, r: Dictionary, prima: Dictionary) -> void:
	var deltas := _testo_deltas(r, prima)
	_scrivi_diario("%s: %s" % [titolo, "ok" if r.get("successo", false) else "andata male"])
	_lbl_ultimo.text = "%s. %s" % [titolo, testo]
	_aggiorna_tutto()
	var passi: Array = []
	passi.append(func(): _mostra_dado(titolo, r.get("roll"), bool(r.get("successo", false)), testo, deltas))
	var ev = r.get("evento_casuale")
	if ev != null and not ev.is_empty():
		passi.append(func(): _mostra_evento(ev))
	_coda = passi + _coda
	_esegui_coda()


func _testo_deltas(r: Dictionary, prima: Dictionary) -> String:
	var righe := PackedStringArray()
	var costo: float = r.get("costo_tempo_figlia_ore", 0.0)
	var effetto: float = r.get("effetto_sabbia_padre_ore", 0.0)
	if costo != 0.0:
		righe.append("Tempo-Figlia %s" % Stile.ore(-costo, true))
	if effetto != 0.0:
		righe.append("Sabbia-Padre %s" % Stile.ore(effetto, true))
	var nomi := {"polizia": "Polizia", "rivalita": "Rivalità", "fama": "Fama", "karma": "Karma", "fede_culto": "Fede del Culto", "fede_setta": "Fede della Setta"}
	var dopo := _snapshot()
	for k in nomi:
		var d: float = dopo[k] - prima[k]
		if absf(d) >= 0.5:
			righe.append("%s %+.0f" % [nomi[k], d])
	if effetto > 0.0:
		_s("guadagno")
	elif effetto < 0.0 or (costo > 0.0 and effetto == 0.0 and not r.get("successo", true)):
		_s("perdita")
	return "   ".join(righe)


# ------------------------------------------------------------ coda schermate

func _coda_bivio(id: String) -> void:
	if not stato.bivio_disponibile(id):
		return
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
	_aggiorna_tutto()
	_imposta_musica()
	if stato.is_over:
		_mostra_fine()
		return
	if stato.sabbia_padre_ore < SOGLIA_POCHE_ORE and stato.bivio_disponibile(TestiDemo.BIVIO_POCHE_ORE):
		_coda_bivio(TestiDemo.BIVIO_POCHE_ORE)
		_esegui_coda()


func _chiudi_modale() -> void:
	if _modale != null:
		_modale.queue_free()
		_modale = null
	_aggiorna_tutto()
	_esegui_coda()


func _nuovo_modale(larghezza: float = 760.0) -> VBoxContainer:
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.82)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	_centro.add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)
	var pannello := PanelContainer.new()
	pannello.custom_minimum_size = Vector2(minf(larghezza, maxf(size.x - LARGHEZZA_HUD - 40.0, 300.0)), 0)
	pannello.add_theme_stylebox_override("panel", Stile.box(Color("12122a"), Stile.SABBIA, 4, 20))
	centro.add_child(pannello)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pannello.add_child(v)
	_modale = fondo
	return v


func _bottone_grande(testo: String, colore: Color, altezza: float = 96.0) -> Button:
	var b := Button.new()
	b.text = testo
	b.custom_minimum_size = Vector2(0, altezza)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22)
	Stile.applica_bottone(b, colore)
	return b


# ------------------------------------------------------------ dado

func _mostra_dado(titolo: String, roll, successo: bool, testo: String, deltas: String) -> void:
	var v := _nuovo_modale()
	var t := Stile.etichetta(titolo, Stile.TITOLI, Stile.SABBIA)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)

	var dado := TextureRect.new()
	dado.custom_minimum_size = Vector2(160, 160)
	dado.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dado.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dado.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dado.texture = PixelArt.dado_frame(0)
	dado.pivot_offset = Vector2(80, 80)
	v.add_child(dado)

	var lbl_tiro := Stile.etichetta(_descrivi_tiro(roll), 19, Stile.CHIARO)
	lbl_tiro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_tiro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_tiro.modulate.a = 0.0
	v.add_child(lbl_tiro)

	var critico: bool = roll != null and (roll.successo_critico or roll.fallimento_critico)
	var esito_testo := "SUCCESSO" if successo else "FALLIMENTO"
	if critico:
		esito_testo += " CRITICO"
	var lbl_esito := Stile.etichetta(esito_testo, 36, Stile.VERDE.lightened(0.3) if successo else Stile.ROSSO)
	lbl_esito.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_esito.modulate.a = 0.0
	v.add_child(lbl_esito)

	var lbl_testo := Stile.etichetta(testo, 20, Stile.CHIARO)
	lbl_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_testo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_testo.modulate.a = 0.0
	v.add_child(lbl_testo)

	var lbl_delta := Stile.etichetta(deltas, 20, Stile.SABBIA)
	lbl_delta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_delta.modulate.a = 0.0
	v.add_child(lbl_delta)

	var btn := _bottone_grande("CONTINUA", Stile.SABBIA)
	btn.disabled = true
	btn.pressed.connect(func():
		_s("click")
		_chiudi_modale())
	v.add_child(btn)

	var numero := -1
	if roll != null and not roll.senza_tiro:
		numero = roll.naturale
	var senza_dado: bool = roll == null
	dado.visible = not senza_dado

	var tw := create_tween()
	if not senza_dado:
		_s("dado")
		for i in 11:
			tw.tween_callback(func(): dado.texture = PixelArt.dado_frame(i % 5))
			tw.tween_interval(0.09)
		tw.tween_callback(func():
			dado.texture = PixelArt.dado_frame(5, numero, Stile.ROSSO if not successo else Color("3d7a5a"))
			var s2 := create_tween()
			dado.scale = Vector2(1.3, 1.3)
			s2.tween_property(dado, "scale", Vector2.ONE, 0.2))
	tw.tween_property(lbl_tiro, "modulate:a", 1.0, 0.2)
	tw.tween_property(lbl_esito, "modulate:a", 1.0, 0.2)
	tw.tween_property(lbl_testo, "modulate:a", 1.0, 0.25)
	tw.tween_property(lbl_delta, "modulate:a", 1.0, 0.2)
	tw.tween_callback(func(): btn.disabled = false)


func _descrivi_tiro(roll) -> String:
	if roll == null:
		return ""
	if roll.senza_tiro:
		return "Nessun tiro. Il rischio è agli estremi."
	if roll.dadi.size() == 1:
		return "Tiro %d, modificatore %+d: totale %d contro CD %d" % [roll.dadi[0], roll.modificatore, roll.totale, roll.cd]
	return "Dadi %s, tenuto %d, modificatore %+d: totale %d contro CD %d" % [str(roll.dadi), roll.naturale, roll.modificatore, roll.totale, roll.cd]


# ------------------------------------------------------------ eventi

func _mostra_evento(ev: Dictionary) -> void:
	if ev.get("tipo", "") == "patto_stregatto_proposto":
		_mostra_patto(ev)
		return
	var nome: String = ev.get("azione", "Evento")
	var testo := TestiDemo.esito_azione(nome, bool(ev.get("successo", false)))
	var delta := ""
	var eff: float = ev.get("effetto_sabbia_padre_ore", 0.0)
	if eff != 0.0:
		delta = "Sabbia-Padre %s" % Stile.ore(eff, true)
	_scrivi_diario("Evento: %s" % nome)
	_mostra_dado("Evento: " + nome, ev.get("roll"), bool(ev.get("successo", false)), testo, delta)


func _mostra_patto(ev: Dictionary) -> void:
	_s("critica")
	var v := _nuovo_modale(860.0)
	v.add_child(Stile.etichetta("DOLCE VOLPE", Stile.TITOLI, Stile.ROSSO))
	var corpo := Stile.etichetta(str(ev.get("testo", "")), 20, Stile.CHIARO)
	corpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(corpo)
	var prezzo: float = ev.get("prezzo_ore", 0.0)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 14)
	v.add_child(riga)
	var si := _bottone_grande("ACCETTO\nPrezzo %s, Karma +%.0f" % [Stile.ore(prezzo), GameState.STREGATTO_KARMA_EFFETTO], Stile.ROSSO, 120.0)
	var no := _bottone_grande("RIFIUTO\nIl Karma resta com'è", Stile.GRIGIO, 120.0)
	riga.add_child(si)
	riga.add_child(no)
	si.pressed.connect(func():
		_s("click")
		var r := stato.risolvi_patto_stregatto(true)
		_scrivi_diario("Patto accettato con Dolce Volpe.")
		_lbl_ultimo.text = Narrativa.patto_accettato(r.get("prezzo_ore", prezzo), r.get("karma_ottenuto", 0.0), stato.karma)
		_chiudi_modale())
	no.pressed.connect(func():
		_s("click")
		stato.risolvi_patto_stregatto(false)
		_scrivi_diario("Patto rifiutato.")
		_lbl_ultimo.text = Narrativa.patto_rifiutato()
		_chiudi_modale())


func _mostra_bivio(id: String) -> void:
	var bivio := TestiDemo.bivio(id)
	var v := _nuovo_modale(900.0)
	v.add_child(Stile.etichetta(bivio.trigger.to_upper(), Stile.TITOLI, Stile.SABBIA))
	var corpo := Stile.etichetta(TestiDemo.TESTO_BIVIO.get(id, ""), 20, Stile.CHIARO)
	corpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(corpo)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 14)
	v.add_child(riga)
	for i in bivio.opzioni.size():
		var o: BivioSystem.Opzione = bivio.opzioni[i]
		var b := _bottone_grande("%s\n%s" % [o.nome.to_upper(), o.descrizione], [Stile.VERDE, Stile.ROSSO, Stile.GRIGIO][i % 3], 200.0)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func():
			_s("click")
			stato.applica_bivio(bivio, i)
			TestiDemo.applica_effetti_bivio(stato, id, i)
			_scrivi_diario("%s: %s" % [bivio.trigger, o.nome])
			_lbl_ultimo.text = "%s. %s" % [bivio.trigger, o.nome]
			_chiudi_modale())
		riga.add_child(b)


# ------------------------------------------------------------ donazione e fine

func _su_dona() -> void:
	if _bloccato():
		return
	_s("click")
	var quantita := snappedf(_slider_dono.value, 0.1)
	var v := _nuovo_modale(720.0)
	v.add_child(Stile.etichetta("DONARE A SARA", Stile.TITOLI, Stile.ROSSO))
	var corpo := Stile.etichetta("Stai per cedere %s. Si fa una volta sola e non si torna indietro. La run finisce qui." % Stile.ore(quantita), 20, Stile.CHIARO)
	corpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(corpo)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 14)
	v.add_child(riga)
	var si := _bottone_grande("DONO", Stile.ROSSO)
	var no := _bottone_grande("ANCORA NO", Stile.GRIGIO)
	riga.add_child(si)
	riga.add_child(no)
	no.pressed.connect(func():
		_s("click")
		_chiudi_modale())
	si.pressed.connect(func():
		_s("click")
		var esito := stato.dona(quantita)
		if not esito.successo:
			_chiudi_modale()
			_mostra_toast(str(esito.motivo))
			return
		_scrivi_diario("Donazione di %s a Sara." % Stile.ore(quantita))
		_chiudi_modale())


func _su_esci() -> void:
	if _modale != null:
		return
	_s("click")
	var v := _nuovo_modale(640.0)
	v.add_child(Stile.etichetta("TORNARE AL TITOLO", Stile.TITOLI, Stile.SABBIA))
	var corpo := Stile.etichetta("La run in corso va persa. Non si salva a metà.", 20, Stile.CHIARO)
	corpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(corpo)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 14)
	v.add_child(riga)
	var si := _bottone_grande("ESCI", Stile.ROSSO)
	var no := _bottone_grande("RESTO", Stile.GRIGIO)
	riga.add_child(si)
	riga.add_child(no)
	no.pressed.connect(_chiudi_modale)
	si.pressed.connect(func():
		_modale.queue_free()
		_modale = null
		torna_al_titolo.emit())


func gestisci_indietro() -> void:
	if _modale != null:
		return
	if _pagina_corrente != "profilo":
		_mostra_pagina("profilo")
	else:
		_su_esci()


func _mostra_fine() -> void:
	if _fine_mostrata:
		return
	_fine_mostrata = true
	if _modale != null:
		_modale.queue_free()
		_modale = null
	var p := stato.calcola_punteggio()
	var salvato := _salva_profilo(p)
	var vittoria := stato.donation_made and stato.tempo_figlia_ore > 0.0
	if audio != null:
		audio.jingle("vittoria" if vittoria else "sconfitta")

	var titolo := "DONAZIONE COMPIUTA"
	if stato.end_reason == GameState.EndReason.FIGLIA_MORTA:
		titolo = "SARA NON CE L'HA FATTA"
	elif stato.end_reason == GameState.EndReason.PADRE_MORTO:
		titolo = "SIRIO SI SPEGNE"

	var v := _nuovo_modale(860.0)
	v.add_child(Stile.etichetta(titolo, Stile.TITOLI, Stile.ROSSO if not vittoria else Stile.SABBIA))
	var epilogo := Stile.etichetta(Narrativa.epilogo(stato.donation_made, stato.tempo_figlia_ore > 0.0, stato.sabbia_padre_ore > 0.0, stato.karma), 20, Stile.CHIARO)
	epilogo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(epilogo)
	v.add_child(HSeparator.new())
	var punteggio := Stile.etichetta("Sirio: %.1f anni\nSara: %.1f anni\nTotale: %.1f anni" % [p.padre_anni, p.figlia_anni, p.punteggio_totale_anni], Stile.VALORI, Stile.SABBIA)
	v.add_child(punteggio)
	if p.vittoria_100_100:
		var tr := Stile.etichetta("Cento anni a testa. Succede di rado, e non assolve nessuno.", 20, Stile.GIALLO)
		tr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tr)
	for riga in salvato:
		var l := Stile.etichetta(str(riga), 18, Stile.GRIGIO)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var riga_b := HBoxContainer.new()
	riga_b.add_theme_constant_override("separation", 14)
	v.add_child(riga_b)
	var nuova := _bottone_grande("NUOVA PARTITA", Stile.ROSSO)
	var titolo_b := _bottone_grande("TITOLO", Stile.GRIGIO)
	riga_b.add_child(nuova)
	riga_b.add_child(titolo_b)
	nuova.pressed.connect(func():
		_s("click")
		nuova_partita.emit())
	titolo_b.pressed.connect(func():
		_s("click")
		torna_al_titolo.emit())


## Stessa tubatura di GameUI._fine_partita: Karma, livello, traguardo,
## storico del seed del giorno, sblocchi della rete di contatti.
func _salva_profilo(p: Dictionary) -> Array:
	var note: Array = []
	if profilo == null:
		return note
	profilo.karma = stato.karma
	profilo.livello_difficolta = stato.livello_difficolta
	if p.vittoria_100_100:
		profilo.traguardo_100_100_raggiunto = true
	if _e_seed_del_giorno:
		profilo.registra_punteggio_seed_del_giorno(SeedDelGiorno.data_di_oggi_stringa(), p)
		note.append("Seed del giorno registrato.")
	var nuovi := ContactNetwork.valuta_sblocchi(stato, profilo)
	if not nuovi.is_empty():
		note.append("Nuovi contatti nella rete: %s" % ", ".join(nuovi))
	profilo.save()
	return note
