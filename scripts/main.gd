extends Control
## Entry point del gioco.
##
## Modalita' da riga di comando (dopo "--"):
##   (nessun argomento)  -> Fase 6: interfaccia grafica minima (Control/
##                          Label/Button), interattiva, non chiude da sola
##   --play              -> Fase 2 legacy: loop testuale da terminale, utile
##                          per verifiche headless senza display
##   --simulate=N        -> Fase 5: batch di N run automatiche (politiche
##                          greedy/greedy_no_free/random), report statistico
##   --test-ui           -> Fase 6: auto-test headless della UI (simula
##                          pressioni di bottoni senza display reale, utile
##                          da CI/terminale dove non si può vedere la finestra)
##   --test-save-write    -> Fase 7: scrive un Profilo Persistente di prova e
##                          termina (simula "chiudi il gioco")
##   --test-save-read     -> Fase 7: rilancio SEPARATO che ricarica quel
##                          profilo da disco e verifica che coincida (simula
##                          "riapri il gioco" — usare dopo --test-save-write)
##   --seed=N             -> Fase 8: forza il seed della run (con --play o
##                          in UI) per riprodurre una run specifica in debug
##                          invece di uno casuale
##
## Esempi:
##   godot --path .                          (gioco con la UI)
##   godot --headless --path . -- --play
##   godot --headless --path . -- --play --seed=12345
##   godot --headless --path . -- --simulate=5000
##   godot --headless --path . -- --test-ui
##   godot --headless --path . -- --test-save-write
##   godot --headless --path . -- --test-save-read

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var simulate_arg := ""
	var seed_arg := -1
	var altri_args: Array[String] = []
	for a in args:
		if a.begins_with("--simulate="):
			simulate_arg = a
		elif a.begins_with("--seed="):
			seed_arg = int(a.split("=")[1])
		else:
			altri_args.append(a)

	if not simulate_arg.is_empty():
		var n := int(simulate_arg.split("=")[1])
		_run_simulation(n)
		get_tree().quit()
	elif altri_args.has("--play"):
		_run_play_loop(seed_arg)
		get_tree().quit()
	elif altri_args.has("--test-ui"):
		_run_test_ui()
		get_tree().quit()
	elif altri_args.has("--test-save-write"):
		_run_test_save_write()
		get_tree().quit()
	elif altri_args.has("--test-save-read"):
		_run_test_save_read()
		get_tree().quit()
	elif altri_args.is_empty():
		_run_ui(seed_arg)
		# niente quit(): la UI resta aperta e interattiva finché l'utente non chiude la finestra
	else:
		print("Argomento non riconosciuto: %s" % ", ".join(altri_args))
		get_tree().quit()


## Valori di prova condivisi tra --test-save-write e --test-save-read: due
## invocazioni SEPARATE di Godot (due processi distinti), non lo stesso
## oggetto in memoria — simula davvero "salva, chiudi il gioco, riapri".
const _TEST_KARMA := 15.5
const _TEST_CONTATTI := ["boss_traccia_criminale"]
const _TEST_ACHIEVEMENT := ["primo_furto"]
const _TEST_DIFFICOLTA := 2
const _TEST_STATO_MONDO := "normale"


func _run_test_save_write() -> void:
	print("=== Fase 7: scrittura Profilo Persistente di prova ===")
	var profilo := PlayerProfile.new()
	profilo.karma = _TEST_KARMA
	profilo.rete_contatti_sbloccati = _TEST_CONTATTI
	profilo.achievement = _TEST_ACHIEVEMENT
	profilo.livello_difficolta = _TEST_DIFFICOLTA
	profilo.stato_mondo_senza_sabbia = _TEST_STATO_MONDO
	var ok := profilo.save()
	assert(ok)
	print("OK: profilo scritto in %s" % ProjectSettings.globalize_path(PlayerProfile.DEFAULT_PATH))


func _run_test_save_read() -> void:
	print("=== Fase 7: rilettura Profilo Persistente (processo separato) ===")
	var profilo := PlayerProfile.load()
	assert(profilo.karma == _TEST_KARMA, "karma atteso %s, trovato %s" % [_TEST_KARMA, profilo.karma])
	assert(profilo.rete_contatti_sbloccati == _TEST_CONTATTI)
	assert(profilo.achievement == _TEST_ACHIEVEMENT)
	assert(profilo.livello_difficolta == _TEST_DIFFICOLTA)
	assert(profilo.stato_mondo_senza_sabbia == _TEST_STATO_MONDO)
	print("OK: profilo ricaricato da un processo Godot separato, tutti i campi coincidono.")
	print("TEST SALVATAGGIO OK")


func _run_test_ui() -> void:
	print("=== Fase 6: auto-test headless della UI ===")
	var ui := GameUI.new()
	add_child(ui)
	var stato := GameState.new()
	ui.avvia(stato)

	assert(ui.bottoni_azione.size() == 60)
	print("OK: %d bottoni azione creati." % ui.bottoni_azione.size())

	var nome_azione := "Turno di lavoro onesto (8h, salario mediano)"
	var bottone: Button = ui.bottoni_azione[nome_azione]
	var tempo_prima := stato.tempo_figlia_ore
	bottone.pressed.emit()
	assert(stato.turno == 1)
	# Fase 8: il costo ora ha varianza ±15% (ActionVariance), non è più
	# esattamente 8.0h — verifichiamo che sia nel range atteso.
	var costo_applicato := tempo_prima - stato.tempo_figlia_ore
	assert(costo_applicato >= 8.0 * 0.85 - 0.01 and costo_applicato <= 8.0 * 1.15 + 0.01,
		"costo fuori range varianza: %.3f" % costo_applicato)
	print("OK: pressione bottone applica l'azione su GameState (costo variato: %.2fh)." % costo_applicato)

	var azione_unica_nome := "Lotteria clandestina della sabbia (jackpot raro)"
	var bottone_unico: Button = ui.bottoni_azione[azione_unica_nome]
	assert(not bottone_unico.disabled)
	bottone_unico.pressed.emit()
	assert(bottone_unico.disabled)
	assert("GIÀ USATA" in bottone_unico.text)
	print("OK: azione unica disabilitata nella UI dopo un tentativo.")

	var tempo_prima_spostamento := stato.tempo_figlia_ore
	ui.spostamento_button.pressed.emit()
	assert(stato.tempo_figlia_ore < tempo_prima_spostamento)
	print("OK: bottone Spostamento consuma Tempo-Figlia tramite la UI.")

	# Fase 9a: le 14 righe di rango (7 tracce x 2) devono essere nella UI,
	# con il Rango 2 inizialmente disabilitato finché non si raggiunge il
	# Rango 1 della stessa traccia.
	assert(ui.bottoni_traccia.size() == 14)
	var bottone_lavoro1: Button = ui.bottoni_traccia["Lavoro|1"]
	var bottone_lavoro2: Button = ui.bottoni_traccia["Lavoro|2"]
	assert(not bottone_lavoro1.disabled)
	assert(bottone_lavoro2.disabled, "Rango 2 deve partire disabilitato")
	print("OK: 14 bottoni traccia creati, Rango 2 disabilitato finché non si raggiunge il Rango 1.")

	# Tentiamo il Rango 1 di Lavoro finché non riesce (rischio 15%, pochi
	# tentativi attesi) per verificare che il successo sblocchi il Rango 2
	# nella UI reale.
	var tentativi := 0
	while stato.tracce_raggiunte.get("Lavoro", 0) < 1 and tentativi < 200 and not stato.is_over:
		bottone_lavoro1.pressed.emit()
		tentativi += 1
	assert(not stato.is_over, "la run non deve finire durante il test (rischio 15%%, atteso successo entro pochi tentativi)")
	assert(stato.tracce_raggiunte.get("Lavoro", 0) == 1, "Rango 1 di Lavoro non raggiunto in %d tentativi" % tentativi)
	assert(bottone_lavoro1.disabled, "Rango 1 raggiunto deve disabilitarsi")
	assert(not bottone_lavoro2.disabled, "Rango 2 deve sbloccarsi nella UI dopo il successo al Rango 1")
	print("OK: successo al Rango 1 sblocca il Rango 2 nella UI (in %d tentativi)." % tentativi)

	ui.donazione_input.text = "5"
	ui.donazione_button.pressed.emit()
	assert(stato.is_over)
	assert(stato.donation_made)
	assert(ui.donazione_button.disabled)
	assert(bottone.disabled)
	print("OK: donazione tramite UI termina la run e disabilita i controlli.")

	# Fase 7: la UI deve caricare il karma dal Profilo Persistente all'avvio
	# della run e riscriverlo su disco alla fine.
	var profilo_prova := PlayerProfile.new()
	profilo_prova.karma = 42.0
	profilo_prova.save()

	var profilo_ricaricato := PlayerProfile.load()
	var ui2 := GameUI.new()
	add_child(ui2)
	var stato2 := GameState.new()
	ui2.avvia(stato2, profilo_ricaricato)
	assert(stato2.karma == 42.0, "GameState deve ereditare il karma dal profilo caricato")

	ui2.donazione_input.text = "3"
	ui2.donazione_button.pressed.emit()
	assert(stato2.is_over)

	var profilo_su_disco := PlayerProfile.load()
	assert(profilo_su_disco.karma == 42.0, "il profilo salvato a fine run deve conservare il karma")
	print("OK: la UI carica il karma dal Profilo Persistente e lo risalva a fine run.")

	print("TUTTI I TEST UI OK")


func _run_ui(seed_arg: int = -1) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var ui := GameUI.new()
	add_child(ui)
	ui.avvia(GameState.new(seed_arg), PlayerProfile.load())


func _run_simulation(n: int) -> void:
	print("=== IL LADRO DI SABBIA — Fase 5: validazione bilanciamento (%d run per politica) ===" % n)
	print("")
	for politica in ["greedy", "greedy_no_free", "random"]:
		var stats := BalanceSimulator.esegui_batch(n, politica)
		_stampa_report_batch(stats)
		print("")


func _stampa_report_batch(s: Dictionary) -> void:
	print("--- Politica: %s (%d run) ---" % [s.politica, s.n_run])
	print("Punteggio totale (padre+figlia, anni): media=%.2f mediana=%.2f min=%.2f max=%.2f" % [
		s.totale_anni_media, s.totale_anni_mediana, s.totale_anni_min, s.totale_anni_max
	])
	print("Anni medi accumulati dal solo padre: %.2f" % s.padre_anni_media)
	print("Probabilità vittoria 100+100 anni: %.2f%%" % (s.prob_vittoria_100_100 * 100.0))
	print("Probabilità di superare soglie di punteggio totale:")
	for soglia in s.prob_soglie:
		print("  >= %d anni: %.2f%%" % [int(soglia), s.prob_soglie[soglia] * 100.0])
	print("Turni medi per run: %.1f" % s.turni_medi)
	if s.prob_cap_turni_raggiunto > 0.0:
		print("ATTENZIONE: %.2f%% delle run ha raggiunto il tetto di sicurezza di %d turni senza esaurire naturalmente il tempo o le azioni utili — sintomo dello sfruttamento di azioni a costo 0h (vedi tools/balance_ceiling.py)." % [
			s.prob_cap_turni_raggiunto * 100.0, BalanceSimulator.MAX_TURNI
		])
	print("Motivi di fine run (0=nessuno/cap, 1=figlia morta, 2=padre morto, 3=donazione): %s" % s.end_reasons)


func _run_play_loop(seed_arg: int = -1) -> void:
	print("=== IL LADRO DI SABBIA — prototipo testuale ===")
	print("La figlia ha 168 ore di vita, tu (il padre) ne hai 24.")
	print("Scegli azioni per raccogliere sabbia prima che uno dei due countdown arrivi a zero.")
	print("")

	var stato := GameState.new(seed_arg)
	print("Seed di questa run: %d (rilancia con --play --seed=%d per riprodurla)" % [stato.seed_run, stato.seed_run])
	print("")

	var tracce := TrackDatabase.get_tracce_normali()

	while not stato.is_over:
		_stampa_stato(stato)
		var azioni := ActionDatabase.get_all()
		_stampa_azioni(azioni, stato)
		_stampa_tracce(tracce, stato, azioni.size())
		print("")
		print("Scrivi il numero di un'azione o riga di traccia, 'spostati' per un evento di spostamento (durata variabile, rischio indipendente di incidente), 'donare <ore>' per la donazione finale (unica, irreversibile), oppure 'esci' per interrompere la run.")
		print("> ")

		var input := OS.read_string_from_stdin().strip_edges()

		if input == "esci" or input == "quit":
			print("")
			print("Run interrotta manualmente (nessuna donazione effettuata).")
			_stampa_punteggio(stato)
			return

		if input == "spostati":
			var r := stato.applica_spostamento()
			var esito: Spostamento.Esito = r.spostamento
			print("")
			print("-> Spostamento in città")
			if esito.incidente:
				print("   INCIDENTE! Durata base %.1fh + ritardo %.1fh = %.1fh totali." % [
					esito.durata_base_ore, esito.ritardo_extra_ore, esito.durata_totale_ore
				])
			else:
				print("   Nessun imprevisto. Durata: %.1fh." % esito.durata_totale_ore)
			print("")
			continue

		if input.begins_with("donare"):
			var parti := input.split(" ", false)
			if parti.size() < 2 or not parti[1].is_valid_float():
				print("Uso: 'donare <ore>', es. 'donare 50'.")
				print("")
				continue
			var esito := stato.dona(float(parti[1]))
			print("")
			if not esito.successo:
				print("Donazione rifiutata: %s" % esito.motivo)
				print("")
				continue
			print("Hai donato %.1fh di Sabbia-Padre alla figlia. La donazione è irreversibile." % esito.quantita_ore)
			break

		if not input.is_valid_int():
			print("Input non valido: '%s'. Scrivi un numero, 'donare <ore>' o 'esci'." % input)
			print("")
			continue

		var indice := int(input) - 1

		if indice >= azioni.size():
			var indice_traccia := indice - azioni.size()
			if indice_traccia < 0 or indice_traccia >= tracce.size():
				print("Numero fuori range: %s." % input)
				print("")
				continue
			var riga: TrackData = tracce[indice_traccia]
			var r := stato.applica_traccia(riga)
			print("")
			if r.has("rifiutata"):
				print("Rango non disponibile: %s" % r.motivo)
				print("")
				continue
			var roll_t: DiceSystem.RollResult = r.roll
			print("-> %s — Rango %d: %s (CD %d)" % [riga.traccia, riga.rango, riga.nome_rango, roll_t.cd])
			if roll_t.dadi.size() == 1:
				print("   Tiro: %d + mod %d = %d" % [roll_t.dadi[0], roll_t.modificatore, roll_t.totale])
			else:
				print("   Tiro: %s -> tenuto %d + mod %d = %d" % [roll_t.dadi, roll_t.naturale, roll_t.modificatore, roll_t.totale])
			print("   Esito: %s | Costo Tempo-Figlia: -%.1fh | Effetto Sabbia-Padre: %+.1fh" % [
				"SUCCESSO" if r.successo else "FALLIMENTO", r.costo_tempo_figlia_ore, r.effetto_sabbia_padre_ore
			])
			print("")
			continue

		var azione := ActionDatabase.get_by_index(indice)
		if azione == null:
			print("Numero fuori range: %s." % input)
			print("")
			continue

		var risultato := stato.applica_azione_con_dado(azione)
		if risultato.has("rifiutata"):
			print("")
			print("Azione non disponibile: %s" % risultato.motivo)
			print("")
			continue
		var roll: DiceSystem.RollResult = risultato.roll
		print("")
		print("-> %s (CD %d)" % [azione.nome, roll.cd])
		if roll.senza_tiro:
			print("   Nessun tiro: rischio estremo (0% o 100%), esito automatico.")
		elif roll.dadi.size() == 1:
			print("   Tiro: %d (naturale %d) + mod %d = %d" % [roll.dadi[0], roll.naturale, roll.modificatore, roll.totale])
		else:
			print("   Tiro: %s -> tenuto %d + mod %d = %d" % [roll.dadi, roll.naturale, roll.modificatore, roll.totale])
		if roll.successo_critico:
			print("   SUCCESSO CRITICO (naturale 20)!")
		elif roll.fallimento_critico:
			print("   FALLIMENTO CRITICO (naturale 1)!")
		print("   Esito: %s | Costo Tempo-Figlia: -%.1fh | Effetto Sabbia-Padre: %+.1fh" % [
			"SUCCESSO" if risultato.successo else "FALLIMENTO",
			risultato.costo_tempo_figlia_ore,
			risultato.effetto_sabbia_padre_ore
		])
		print("")

	_stampa_stato(stato)
	print("")
	print(stato.end_reason_testo())
	_stampa_punteggio(stato)


func _stampa_punteggio(stato: GameState) -> void:
	var p := stato.calcola_punteggio()
	print("")
	print("=== PUNTEGGIO FINALE ===")
	print("Padre:  %.1fh (~%.2f anni)" % [p.padre_ore, p.padre_anni])
	print("Figlia: %.1fh (~%.2f anni)" % [p.figlia_ore, p.figlia_anni])
	print("Totale: ~%.2f anni" % p.punteggio_totale_anni)
	if p.vittoria_100_100:
		print("")
		print("*** TRAGUARDO RAGGIUNTO: 100+100 anni per entrambi! ***")
		print("(le modalità di gioco aggiuntive che questo sblocca non sono ancora implementate)")


func _stampa_stato(stato: GameState) -> void:
	var giorni_figlia := stato.tempo_figlia_ore / 24.0
	var anni_padre := stato.sabbia_padre_ore / ActionDatabase.ore_per_anno
	print("--------------------------------------------------")
	print("Turno %d | Tempo-Figlia: %.1fh (~%.1f giorni) | Sabbia-Padre: %.1fh (~%.4f anni)" % [
		stato.turno, stato.tempo_figlia_ore, giorni_figlia, stato.sabbia_padre_ore, anni_padre
	])
	print("--------------------------------------------------")


func _stampa_azioni(azioni: Array[ActionData], stato: GameState) -> void:
	var categoria_corrente := ""
	for i in azioni.size():
		var a := azioni[i]
		if a.categoria != categoria_corrente:
			categoria_corrente = a.categoria
			print("[%s]" % categoria_corrente)
		var etichetta_unica := ""
		if a.unica_per_run:
			etichetta_unica = " [GIÀ USATA]" if not stato.azione_disponibile(a) else " [unica]"
		print("  %2d) %-55s costo=%5.1fh  effetto=%+8.1fh  rischio=%3d%%%s" % [
			i + 1, a.nome, a.costo_tempo_figlia_ore, a.effetto_sabbia_padre_ore, roundi(a.rischio_pct * 100), etichetta_unica
		])


func _stampa_tracce(tracce: Array[TrackData], stato: GameState, offset: int) -> void:
	print("[TRACCE]")
	var traccia_corrente := ""
	for i in tracce.size():
		var t := tracce[i]
		if t.traccia != traccia_corrente:
			traccia_corrente = t.traccia
			print("  -- %s --" % traccia_corrente)
		var progresso: int = stato.tracce_raggiunte.get(t.traccia, 0)
		var etichetta := ""
		if progresso >= t.rango:
			etichetta = " [RAGGIUNTO]"
		elif not stato.traccia_disponibile(t):
			etichetta = " [richiede rango precedente]"
		print("  %2d) %s Rango %d - %-40s costo=%5.1fh  effetto=%+9.1fh  rischio=%3d%%%s" % [
			offset + i + 1, t.traccia, t.rango, t.nome_rango, t.costo_tempo_figlia_ore, t.effetto_sabbia_padre_ore, roundi(t.rischio_pct * 100), etichetta
		])
