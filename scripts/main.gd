extends Node
## Entry point del gioco.
##
## Modalita' da riga di comando (dopo "--"):
##   (nessun argomento) o --play   -> loop testuale giocabile da terminale
##
## Esempio: godot --headless --path . -- --play

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--play") or args.is_empty():
		_run_play_loop()
	else:
		print("Argomento non riconosciuto: %s" % ", ".join(args))
	get_tree().quit()


func _run_play_loop() -> void:
	print("=== IL LADRO DI SABBIA — prototipo testuale ===")
	print("La figlia ha 168 ore di vita, tu (il padre) ne hai 24.")
	print("Scegli azioni per raccogliere sabbia prima che uno dei due countdown arrivi a zero.")
	print("")

	var stato := GameState.new()

	while not stato.is_over:
		_stampa_stato(stato)
		var azioni := ActionDatabase.get_all()
		_stampa_azioni(azioni)
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
		var roll: DiceSystem.RollResult = risultato.roll
		print("")
		print("-> %s (CD %d)" % [azione.nome, roll.cd])
		if roll.dadi.size() == 1:
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


func _stampa_azioni(azioni: Array[ActionData]) -> void:
	var categoria_corrente := ""
	for i in azioni.size():
		var a := azioni[i]
		if a.categoria != categoria_corrente:
			categoria_corrente = a.categoria
			print("[%s]" % categoria_corrente)
		print("  %2d) %-55s costo=%5.1fh  effetto=%+8.1fh  rischio=%3d%%" % [
			i + 1, a.nome, a.costo_tempo_figlia_ore, a.effetto_sabbia_padre_ore, roundi(a.rischio_pct * 100)
		])
