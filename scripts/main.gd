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
##
## Esempi:
##   godot --path .                          (gioco con la UI)
##   godot --headless --path . -- --play
##   godot --headless --path . -- --simulate=5000
##   godot --headless --path . -- --test-ui

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var simulate_arg := ""
	for a in args:
		if a.begins_with("--simulate="):
			simulate_arg = a
			break

	if not simulate_arg.is_empty():
		var n := int(simulate_arg.split("=")[1])
		_run_simulation(n)
		get_tree().quit()
	elif args.has("--play"):
		_run_play_loop()
		get_tree().quit()
	elif args.has("--test-ui"):
		_run_test_ui()
		get_tree().quit()
	elif args.is_empty():
		_run_ui()
		# niente quit(): la UI resta aperta e interattiva finché l'utente non chiude la finestra
	else:
		print("Argomento non riconosciuto: %s" % ", ".join(args))
		get_tree().quit()


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
	assert(stato.tempo_figlia_ore == tempo_prima - 8.0)
	print("OK: pressione bottone applica l'azione su GameState.")

	var azione_unica_nome := "Lotteria clandestina della sabbia (jackpot raro)"
	var bottone_unico: Button = ui.bottoni_azione[azione_unica_nome]
	assert(not bottone_unico.disabled)
	bottone_unico.pressed.emit()
	assert(bottone_unico.disabled)
	assert("GIÀ USATA" in bottone_unico.text)
	print("OK: azione unica disabilitata nella UI dopo un tentativo.")

	ui.donazione_input.text = "5"
	ui.donazione_button.pressed.emit()
	assert(stato.is_over)
	assert(stato.donation_made)
	assert(ui.donazione_button.disabled)
	assert(bottone.disabled)
	print("OK: donazione tramite UI termina la run e disabilita i controlli.")

	print("TUTTI I TEST UI OK")


func _run_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var ui := GameUI.new()
	add_child(ui)
	ui.avvia(GameState.new())


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


func _run_play_loop() -> void:
	print("=== IL LADRO DI SABBIA — prototipo testuale ===")
	print("La figlia ha 168 ore di vita, tu (il padre) ne hai 24.")
	print("Scegli azioni per raccogliere sabbia prima che uno dei due countdown arrivi a zero.")
	print("")

	var stato := GameState.new()

	while not stato.is_over:
		_stampa_stato(stato)
		var azioni := ActionDatabase.get_all()
		_stampa_azioni(azioni, stato)
		print("")
		print("Scrivi il numero di un'azione, 'donare <ore>' per la donazione finale (unica, irreversibile), oppure 'esci' per interrompere la run.")
		print("> ")

		var input := OS.read_string_from_stdin().strip_edges()

		if input == "esci" or input == "quit":
			print("")
			print("Run interrotta manualmente (nessuna donazione effettuata).")
			_stampa_punteggio(stato)
			return

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
