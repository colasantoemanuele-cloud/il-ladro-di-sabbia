class_name GameUI
extends Control
## Fase 6: interfaccia Godot minima che sostituisce il loop testuale come
## modo principale di giocare. Solo nodi Control/Label/Button di base,
## nessun asset grafico. Non risolve l'affollamento schermo delle 60 azioni
## (decisione presa: è un problema di arte finale, Fase 13) — la lista è
## semplicemente scorrevole.
##
## Tutta la logica di gioco resta in GameState/DiceSystem: questo script
## legge lo stato e chiama i suoi metodi, non duplica alcuna regola.

var stato: GameState
var profilo: PlayerProfile

var lbl_tempo_figlia: Label
var lbl_sabbia_padre: Label
var lbl_seed: Label
var lbl_risorse: Label
var lbl_messaggio: RichTextLabel

var donazione_input: LineEdit
var donazione_button: Button

var spostamento_button: Button

var azioni_vbox: VBoxContainer
var bottoni_azione: Dictionary = {}  # nome azione -> Button

var bottoni_traccia: Dictionary = {}  # "traccia|rango" -> Button
var righe_traccia: Dictionary = {}    # "traccia|rango" -> TrackData

var bottoni_sottotrama: Dictionary = {}  # nome sottotrama -> Button


## `profilo_iniziale` e' opzionale: se omesso (es. --test-ui) la UI resta
## utilizzabile senza il Profilo Persistente (Fase 7), semplicemente non
## carica/salva karma tra le run.
func avvia(stato_iniziale: GameState, profilo_iniziale: PlayerProfile = null) -> void:
	stato = stato_iniziale
	profilo = profilo_iniziale
	if profilo != null:
		stato.karma = profilo.karma
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_costruisci_ui()
	_popola_azioni()
	_popola_tracce()
	_popola_sottotrame()
	_aggiorna_stato_ui()


func _costruisci_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# --- Doppio countdown, sempre visibile ---
	var status_bar := HBoxContainer.new()
	status_bar.add_theme_constant_override("separation", 24)
	root.add_child(status_bar)

	lbl_tempo_figlia = Label.new()
	status_bar.add_child(lbl_tempo_figlia)
	lbl_sabbia_padre = Label.new()
	status_bar.add_child(lbl_sabbia_padre)
	lbl_seed = Label.new()
	status_bar.add_child(lbl_seed)

	# --- Pannello risorse, sempre visibile (Fase 6: tutte fisse a 0) ---
	lbl_risorse = Label.new()
	lbl_risorse.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(lbl_risorse)

	root.add_child(HSeparator.new())

	# --- Spostamento: evento con esito incerto indipendente (Fase 8) ---
	var spostamento_bar := HBoxContainer.new()
	spostamento_bar.add_theme_constant_override("separation", 8)
	root.add_child(spostamento_bar)

	spostamento_button = Button.new()
	spostamento_button.text = "Spostati in città (durata variabile, rischio indipendente di incidente)"
	spostamento_button.pressed.connect(_on_spostamento_pressed)
	spostamento_bar.add_child(spostamento_button)

	root.add_child(HSeparator.new())

	# --- Donazione finale ---
	var dona_bar := HBoxContainer.new()
	dona_bar.add_theme_constant_override("separation", 8)
	root.add_child(dona_bar)

	var dona_label := Label.new()
	dona_label.text = "Dona alla figlia (ore, irreversibile):"
	dona_bar.add_child(dona_label)

	donazione_input = LineEdit.new()
	donazione_input.custom_minimum_size = Vector2(80, 0)
	donazione_input.placeholder_text = "ore"
	dona_bar.add_child(donazione_input)

	donazione_button = Button.new()
	donazione_button.text = "Dona"
	donazione_button.pressed.connect(_on_dona_pressed)
	dona_bar.add_child(donazione_button)

	root.add_child(HSeparator.new())

	# --- Messaggio / esito ultima azione / fine partita ---
	lbl_messaggio = RichTextLabel.new()
	lbl_messaggio.custom_minimum_size = Vector2(0, 80)
	lbl_messaggio.bbcode_enabled = true
	lbl_messaggio.fit_content = true
	lbl_messaggio.text = "Scegli un'azione dalla lista qui sotto."
	root.add_child(lbl_messaggio)

	root.add_child(HSeparator.new())

	# --- Lista azioni, scorrevole ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	azioni_vbox = VBoxContainer.new()
	azioni_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(azioni_vbox)


func _popola_azioni() -> void:
	var categoria_corrente := ""
	for azione: ActionData in ActionDatabase.get_all():
		if azione.categoria != categoria_corrente:
			categoria_corrente = azione.categoria
			var header := Label.new()
			header.text = "— %s —" % categoria_corrente
			azioni_vbox.add_child(header)

		var bottone := Button.new()
		bottone.text = _testo_bottone(azione)
		bottone.pressed.connect(_on_azione_pressed.bind(azione))
		azioni_vbox.add_child(bottone)
		bottoni_azione[azione.nome] = bottone


## Fase 9a: le 7 tracce normali (Rango 1 + Rango 2, dipendenza solo interna
## alla stessa traccia — nessun aggancio comune tra tracce diverse) e le 3
## tracce bonus (solo dati + placeholder narrativo, nessuna logica: il
## contenuto vero arriva quando l'autore avrà scritto i testi).
func _popola_tracce() -> void:
	var header_sezione := Label.new()
	header_sezione.text = "═══ TRACCE ═══"
	azioni_vbox.add_child(header_sezione)

	for nome_traccia in TrackDatabase.get_nomi_tracce_normali():
		var header := Label.new()
		header.text = "— %s —" % nome_traccia
		azioni_vbox.add_child(header)

		for rango in [1, 2]:
			var riga := TrackDatabase.get_riga(nome_traccia, rango)
			if riga == null:
				continue
			var chiave := "%s|%d" % [nome_traccia, rango]
			var bottone := Button.new()
			bottone.text = _testo_bottone_traccia(riga)
			bottone.pressed.connect(_on_traccia_pressed.bind(riga))
			azioni_vbox.add_child(bottone)
			bottoni_traccia[chiave] = bottone
			righe_traccia[chiave] = riga

	var header_bonus := Label.new()
	header_bonus.text = "— Tracce bonus (narrative) —"
	azioni_vbox.add_child(header_bonus)

	for bonus: TrackBonusData in TrackDatabase.get_tracce_bonus():
		var bottone := Button.new()
		bottone.text = "%s — contenuto narrativo non ancora scritto" % bonus.traccia
		bottone.disabled = true
		bottone.tooltip_text = bonus.descrizione
		azioni_vbox.add_child(bottone)

	_aggiorna_bottoni_traccia()


func _testo_bottone_traccia(riga: TrackData) -> String:
	return "Rango %d — %s — costo %.0fh, effetto %+.1fh, rischio %d%%" % [
		riga.rango, riga.nome_rango, riga.costo_tempo_figlia_ore, riga.effetto_sabbia_padre_ore, roundi(riga.rischio_pct * 100)
	]


## Riabilita/disabilita ogni bottone di traccia in base al progresso attuale:
## va richiamato dopo OGNI tentativo di traccia (che sblocca o meno il
## rango successivo), non solo per il proprio.
func _aggiorna_bottoni_traccia() -> void:
	for chiave in bottoni_traccia:
		var riga: TrackData = righe_traccia[chiave]
		var bottone: Button = bottoni_traccia[chiave]
		var progresso: int = stato.tracce_raggiunte.get(riga.traccia, 0)
		var gia_tentata: bool = stato.azioni_uniche_usate.has(chiave)
		if progresso >= riga.rango:
			bottone.disabled = true
			bottone.text = _testo_bottone_traccia(riga) + " [RAGGIUNTO]"
		elif gia_tentata:
			bottone.disabled = true
			bottone.text = _testo_bottone_traccia(riga) + " [FALLITA — non più tentabile]"
		else:
			bottone.disabled = not stato.traccia_disponibile(riga)


func _on_traccia_pressed(riga: TrackData) -> void:
	if stato.is_over:
		return

	var risultato := stato.applica_traccia(riga)

	if risultato.has("rifiutata"):
		lbl_messaggio.text = "[b]Rango non disponibile:[/b] %s" % risultato.motivo
		return

	lbl_messaggio.text = _descrivi_risultato_traccia(riga, risultato)
	_aggiorna_bottoni_traccia()
	_aggiorna_stato_ui()

	if stato.is_over:
		_fine_partita()


func _descrivi_risultato_traccia(riga: TrackData, risultato: Dictionary) -> String:
	var roll: DiceSystem.RollResult = risultato.roll
	var esito := "SUCCESSO" if risultato.successo else "FALLIMENTO"
	if roll.successo_critico or roll.fallimento_critico:
		esito += " CRITICO"

	var riga_tiro: String
	if roll.senza_tiro:
		riga_tiro = "Nessun tiro (rischio estremo 0%/100%)."
	elif roll.dadi.size() == 1:
		riga_tiro = "Tiro: %d + mod %d = %d (CD %d)" % [roll.dadi[0], roll.modificatore, roll.totale, roll.cd]
	else:
		riga_tiro = "Tiro: %s -> tenuto %d + mod %d = %d (CD %d)" % [roll.dadi, roll.naturale, roll.modificatore, roll.totale, roll.cd]

	return "[b]%s — Rango %d: %s[/b]\n%s -> %s\nCosto Tempo-Figlia: -%.1fh | Effetto Sabbia-Padre: %+.1fh" % [
		riga.traccia, riga.rango, riga.nome_rango, riga_tiro, esito, risultato.costo_tempo_figlia_ore, risultato.effetto_sabbia_padre_ore
	]


## Fase 9b: le 10 sottotrame endgame, ciascuna un'azione una tantum (stesso
## meccanismo delle azioni "Unica per run"). "Il tesoro del vecchio boss"
## ha un prerequisito esplicito (design doc 6.1): richiede di aver già
## completato con successo "Riattivare un vecchio contatto della rete
## criminale" in questa run.
func _popola_sottotrame() -> void:
	var header_sezione := Label.new()
	header_sezione.text = "═══ SOTTOTRAME ═══"
	azioni_vbox.add_child(header_sezione)

	for sub: SubplotData in SubplotDatabase.get_all():
		var bottone := Button.new()
		bottone.text = _testo_bottone_sottotrama(sub)
		if sub.nota != "":
			bottone.tooltip_text = sub.nota
		bottone.pressed.connect(_on_sottotrama_pressed.bind(sub))
		azioni_vbox.add_child(bottone)
		bottoni_sottotrama[sub.nome] = bottone

	_aggiorna_bottoni_sottotrama()


func _testo_bottone_sottotrama(sub: SubplotData) -> String:
	var etichetta_prereq := " [richiede: %s]" % sub.prerequisito if sub.prerequisito != "" else ""
	return "%s — costo %.0fh, effetto %+.1fh, rischio %d%%%s" % [
		sub.nome, sub.costo_tempo_figlia_ore, sub.effetto_sabbia_padre_ore, roundi(sub.rischio_pct * 100), etichetta_prereq
	]


func _aggiorna_bottoni_sottotrama() -> void:
	for nome in bottoni_sottotrama:
		var sub: SubplotData = null
		for s: SubplotData in SubplotDatabase.get_all():
			if s.nome == nome:
				sub = s
				break
		var bottone: Button = bottoni_sottotrama[nome]
		var gia_tentata: bool = stato.azioni_uniche_usate.has("sottotrama:%s" % nome)
		if gia_tentata:
			bottone.disabled = true
			# Non possiamo distinguere qui "riuscita" da "fallita" senza rileggere
			# lo storico: il messaggio dell'ultima azione mostra già l'esito.
			if not "[RAGGIUNTA]" in bottone.text and not "[FALLITA" in bottone.text:
				bottone.text = _testo_bottone_sottotrama(sub) + " [già tentata]"
		else:
			bottone.disabled = not stato.sottotrama_disponibile(sub)


func _on_sottotrama_pressed(sub: SubplotData) -> void:
	if stato.is_over:
		return

	var risultato := stato.applica_sottotrama(sub)

	if risultato.has("rifiutata"):
		lbl_messaggio.text = "[b]Sottotrama non disponibile:[/b] %s" % risultato.motivo
		return

	lbl_messaggio.text = _descrivi_risultato_sottotrama(sub, risultato)

	var bottone: Button = bottoni_sottotrama.get(sub.nome)
	if bottone:
		bottone.disabled = true
		bottone.text = _testo_bottone_sottotrama(sub) + (" [RAGGIUNTA]" if risultato.successo else " [FALLITA — non più tentabile]")

	_aggiorna_stato_ui()

	if stato.is_over:
		_fine_partita()


func _descrivi_risultato_sottotrama(sub: SubplotData, risultato: Dictionary) -> String:
	var roll: DiceSystem.RollResult = risultato.roll
	var esito := "SUCCESSO" if risultato.successo else "FALLIMENTO"
	if roll.successo_critico or roll.fallimento_critico:
		esito += " CRITICO"

	var riga_tiro: String
	if roll.senza_tiro:
		riga_tiro = "Nessun tiro (rischio estremo 0%/100%)."
	elif roll.dadi.size() == 1:
		riga_tiro = "Tiro: %d + mod %d = %d (CD %d)" % [roll.dadi[0], roll.modificatore, roll.totale, roll.cd]
	else:
		riga_tiro = "Tiro: %s -> tenuto %d + mod %d = %d (CD %d)" % [roll.dadi, roll.naturale, roll.modificatore, roll.totale, roll.cd]

	return "[b]%s[/b]\n%s -> %s\nCosto Tempo-Figlia: -%.1fh | Effetto Sabbia-Padre: %+.1fh" % [
		sub.nome, riga_tiro, esito, risultato.costo_tempo_figlia_ore, risultato.effetto_sabbia_padre_ore
	]


func _testo_bottone(azione: ActionData) -> String:
	var etichetta_unica := " [unica]" if azione.unica_per_run else ""
	return "%s — costo %.0fh, effetto %+.1fh, rischio %d%%%s" % [
		azione.nome, azione.costo_tempo_figlia_ore, azione.effetto_sabbia_padre_ore,
		roundi(azione.rischio_pct * 100), etichetta_unica
	]


func _on_azione_pressed(azione: ActionData) -> void:
	if stato.is_over:
		return

	var risultato := stato.applica_azione_con_dado(azione)

	if risultato.has("rifiutata"):
		lbl_messaggio.text = "[b]Azione non disponibile:[/b] %s" % risultato.motivo
		return

	lbl_messaggio.text = _descrivi_risultato(azione, risultato)

	if azione.unica_per_run:
		var bottone: Button = bottoni_azione.get(azione.nome)
		if bottone:
			bottone.disabled = true
			bottone.text = _testo_bottone(azione) + " [GIÀ USATA]"

	# Un'azione core completata con successo può sbloccare il prerequisito
	# di una sottotrama (es. "Il tesoro del vecchio boss" — design doc 6.1).
	_aggiorna_bottoni_sottotrama()
	_aggiorna_stato_ui()

	if stato.is_over:
		_fine_partita()


func _descrivi_risultato(azione: ActionData, risultato: Dictionary) -> String:
	var roll: DiceSystem.RollResult = risultato.roll
	var esito := "SUCCESSO" if risultato.successo else "FALLIMENTO"
	if roll.successo_critico:
		esito += " CRITICO"
	elif roll.fallimento_critico:
		esito += " CRITICO"

	var riga_tiro: String
	if roll.senza_tiro:
		riga_tiro = "Nessun tiro (rischio estremo 0%/100%)."
	elif roll.dadi.size() == 1:
		riga_tiro = "Tiro: %d + mod %d = %d (CD %d)" % [roll.dadi[0], roll.modificatore, roll.totale, roll.cd]
	else:
		riga_tiro = "Tiro: %s -> tenuto %d + mod %d = %d (CD %d)" % [roll.dadi, roll.naturale, roll.modificatore, roll.totale, roll.cd]

	return "[b]%s[/b]\n%s -> %s\nCosto Tempo-Figlia: -%.1fh | Effetto Sabbia-Padre: %+.1fh" % [
		azione.nome, riga_tiro, esito, risultato.costo_tempo_figlia_ore, risultato.effetto_sabbia_padre_ore
	]


## Evento con esito incerto indipendente (design doc 12.1, vedi
## scripts/core/spostamento.gd): non è una delle 60 azioni core, non ha
## Rischio%/CD né la varianza ±15%/±20% di ActionVariance — è un meccanismo
## a parte, con la propria durata variabile e la propria probabilità di
## incidente.
func _on_spostamento_pressed() -> void:
	if stato.is_over:
		return

	var risultato := stato.applica_spostamento()
	var esito: Spostamento.Esito = risultato.spostamento

	if esito.incidente:
		lbl_messaggio.text = "[b]Spostamento in città — INCIDENTE![/b]\nDurata base %.1fh + ritardo %.1fh = %.1fh totali." % [
			esito.durata_base_ore, esito.ritardo_extra_ore, esito.durata_totale_ore
		]
	else:
		lbl_messaggio.text = "[b]Spostamento in città[/b]\nNessun imprevisto. Durata: %.1fh." % esito.durata_totale_ore

	_aggiorna_stato_ui()

	if stato.is_over:
		_fine_partita()


func _on_dona_pressed() -> void:
	if stato.is_over:
		return
	if not donazione_input.text.is_valid_float():
		lbl_messaggio.text = "[b]Donazione:[/b] inserisci un numero di ore valido."
		return

	var esito := stato.dona(float(donazione_input.text))
	if not esito.successo:
		lbl_messaggio.text = "[b]Donazione rifiutata:[/b] %s" % esito.motivo
		return

	lbl_messaggio.text = "[b]Hai donato %.1fh alla figlia. Donazione irreversibile.[/b]" % esito.quantita_ore
	_aggiorna_stato_ui()
	_fine_partita()


func _aggiorna_stato_ui() -> void:
	var giorni_figlia := stato.tempo_figlia_ore / 24.0
	var anni_padre := stato.sabbia_padre_ore / GameState.ORE_PER_ANNO
	lbl_tempo_figlia.text = "Tempo-Figlia: %.1fh (~%.1f giorni)" % [stato.tempo_figlia_ore, giorni_figlia]
	lbl_sabbia_padre.text = "Sabbia-Padre: %.1fh (~%.4f anni)" % [stato.sabbia_padre_ore, anni_padre]
	lbl_seed.text = "Seed: %d" % stato.seed_run
	lbl_risorse.text = "Attenzione Polizia: %.0f  |  Rivalità Criminale: %.0f  |  Fama Pubblica: %.0f  |  Karma: %.0f  |  Fede: %.0f" % [
		stato.attenzione_polizia, stato.rivalita_criminale, stato.fama_pubblica, stato.karma, stato.fede
	]


func _fine_partita() -> void:
	for bottone: Button in bottoni_azione.values():
		bottone.disabled = true
	for bottone: Button in bottoni_traccia.values():
		bottone.disabled = true
	for bottone: Button in bottoni_sottotrama.values():
		bottone.disabled = true
	donazione_button.disabled = true
	donazione_input.editable = false
	spostamento_button.disabled = true

	var p := stato.calcola_punteggio()
	var testo := "[b]%s[/b]\n\n[b]PUNTEGGIO FINALE[/b]\nPadre: %.1fh (~%.2f anni)\nFiglia: %.1fh (~%.2f anni)\nTotale: ~%.2f anni" % [
		stato.end_reason_testo(), p.padre_ore, p.padre_anni, p.figlia_ore, p.figlia_anni, p.punteggio_totale_anni
	]
	if p.vittoria_100_100:
		testo += "\n\n[b]*** TRAGUARDO RAGGIUNTO: 100+100 anni per entrambi! ***[/b]"
	lbl_messaggio.text = testo

	if profilo != null:
		profilo.karma = stato.karma
		profilo.save()
