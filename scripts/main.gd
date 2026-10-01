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
##   --test-sinergie      -> Fase 9c: auto-test headless del sistema di
##                          sinergie tra tracce (cash-in, malus, esclusione
##                          delle sottotrame dal conteggio)
##   --test-fase10        -> Fase 10: auto-test headless delle 5 risorse
##                          (Attenzione Polizia/Rivalità Criminale/Fama
##                          Pubblica/Karma/Fede), del malus/Vantaggio-
##                          Svantaggio al tiro, del sistema di eventi
##                          casuali e del Patto con lo Stregatto
##   --difficolta=N       -> forza il livello di difficoltà crescente
##                          (design doc 12.5, con --play o in UI). Con
##                          --play il livello è applicato direttamente
##                          (strumento di debug, nessun gate). In UI è
##                          limitato a 0 finché il Profilo Persistente non
##                          ha traguardo_100_100_raggiunto = true.
##   --test-difficolta    -> auto-test headless della difficoltà crescente
##   --seed-del-giorno    -> forza il seed derivato dalla data corrente
##                          (design doc 12.6, con --play o in UI) invece
##                          di uno casuale — sovrascrive --seed= se
##                          presenti entrambi. A fine run il punteggio
##                          viene registrato nello storico locale del
##                          Profilo Persistente per la data odierna
##                          (nessun server/classifica condivisa)
##   --test-seed-del-giorno -> auto-test headless del Seed del Giorno
##   --test-narrativa     -> auto-test headless dei testi narrativi (Narrativa)
##   --test-impero        -> auto-test headless del motore dell'impero (ImperoState)
##   --test-bivi          -> auto-test headless dello scheletro tecnico
##                          dei bivi (design doc 12.2) — solo bivi
##                          segnaposto, nessun contenuto narrativo reale.
##                          In --play, comando 'bivio <id> <indice>'
##   --test-rete-contatti -> auto-test headless dello scheletro tecnico
##                          della Rete di contatti (design doc 12.3) —
##                          solo contatti segnaposto, nessun contenuto
##                          narrativo reale, nessun effetto sulle 62
##                          azioni vere
##
## Esempi:
##   godot --path .                          (gioco con la UI)
##   godot --headless --path . -- --play
##   godot --headless --path . -- --play --seed=12345
##   godot --headless --path . -- --play --seed-del-giorno
##   godot --headless --path . -- --simulate=5000
##   godot --headless --path . -- --test-ui
##   godot --headless --path . -- --test-save-write
##   godot --headless --path . -- --test-save-read
##   godot --headless --path . -- --test-sinergie

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var simulate_arg := ""
	var seed_arg := -1
	var difficolta_arg := 0
	var altri_args: Array[String] = []
	for a in args:
		if a.begins_with("--simulate="):
			simulate_arg = a
		elif a.begins_with("--seed="):
			seed_arg = int(a.split("=")[1])
		elif a.begins_with("--difficolta="):
			difficolta_arg = int(a.split("=")[1])
		else:
			altri_args.append(a)

	var usa_seed_del_giorno := altri_args.has("--seed-del-giorno")
	if usa_seed_del_giorno:
		altri_args.erase("--seed-del-giorno")
		seed_arg = SeedDelGiorno.seed_di_oggi()

	if not simulate_arg.is_empty():
		var n := int(simulate_arg.split("=")[1])
		_run_simulation(n)
		get_tree().quit()
	elif altri_args.has("--play"):
		_run_play_loop(seed_arg, difficolta_arg, usa_seed_del_giorno)
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
	elif altri_args.has("--test-sinergie"):
		_run_test_sinergie()
		get_tree().quit()
	elif altri_args.has("--test-fase10"):
		_run_test_fase10()
		get_tree().quit()
	elif altri_args.has("--test-difficolta"):
		_run_test_difficolta()
		get_tree().quit()
	elif altri_args.has("--test-seed-del-giorno"):
		_run_test_seed_del_giorno()
		get_tree().quit()
	elif altri_args.has("--test-narrativa"):
		_run_test_narrativa()
	elif altri_args.has("--test-impero"):
		ImperoTest.esegui()
		get_tree().quit()
	elif altri_args.has("--test-bivi"):
		_run_test_bivi()
		get_tree().quit()
	elif altri_args.has("--test-rete-contatti"):
		_run_test_rete_contatti()
		get_tree().quit()
	elif altri_args.is_empty():
		_run_ui(seed_arg, difficolta_arg, usa_seed_del_giorno)
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
const _TEST_TRAGUARDO := true
const _TEST_STATO_MONDO := "normale"


func _run_test_save_write() -> void:
	print("=== Fase 7: scrittura Profilo Persistente di prova ===")
	var profilo := PlayerProfile.new()
	profilo.karma = _TEST_KARMA
	profilo.rete_contatti_sbloccati = _TEST_CONTATTI
	profilo.achievement = _TEST_ACHIEVEMENT
	profilo.livello_difficolta = _TEST_DIFFICOLTA
	profilo.traguardo_100_100_raggiunto = _TEST_TRAGUARDO
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
	assert(profilo.traguardo_100_100_raggiunto == _TEST_TRAGUARDO)
	assert(profilo.stato_mondo_senza_sabbia == _TEST_STATO_MONDO)
	print("OK: profilo ricaricato da un processo Godot separato, tutti i campi coincidono.")
	print("TEST SALVATAGGIO OK")


func _run_test_ui() -> void:
	print("=== Fase 6: auto-test headless della UI ===")
	var ui := GameUI.new()
	add_child(ui)
	var stato := GameState.new()
	ui.avvia(stato)

	assert(ui.bottoni_azione.size() == 62)  # 60 core + 2 aggiunte in Fase 10 (Rivalità Criminale/Fama Pubblica)
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

	# Un solo tentativo: dalla correzione post-Fase-9a un fallimento blocca
	# la riga per sempre (stesso meccanismo delle azioni "Unica per run"),
	# quindi non ha più senso ritentare — verifichiamo entrambi gli esiti
	# possibili (il test di GameState dedicato, non qui, forza
	# deterministicamente successo/fallimento; qui verifichiamo solo che la
	# UI reagisca correttamente a quale che sia l'esito reale).
	bottone_lavoro1.pressed.emit()
	assert(bottone_lavoro1.disabled, "il Rango 1 tentato (successo o fallimento) deve sempre disabilitarsi")
	if stato.tracce_raggiunte.get("Lavoro", 0) == 1:
		assert("[RAGGIUNTO]" in bottone_lavoro1.text)
		assert(not bottone_lavoro2.disabled, "Rango 2 deve sbloccarsi nella UI dopo il successo al Rango 1")
		print("OK: successo al Rango 1 sblocca il Rango 2 nella UI.")
	else:
		assert("[FALLITA" in bottone_lavoro1.text)
		assert(bottone_lavoro2.disabled, "un fallimento al Rango 1 deve bloccare anche il Rango 2")
		print("OK: fallimento al Rango 1 blocca l'intera traccia nella UI.")

	# Fase 9b: le 10 sottotrame devono essere nella UI. "Il tesoro del
	# vecchio boss" ha un prerequisito (design doc 6.1) e deve partire
	# disabilitata; le altre 9 no.
	assert(ui.bottoni_sottotrama.size() == 10)
	var bottone_tesoro: Button = ui.bottoni_sottotrama["Il tesoro del vecchio boss"]
	var bottone_ultima_donazione: Button = ui.bottoni_sottotrama["L'ultima donazione"]
	assert(bottone_tesoro.disabled, "sottotrama con prerequisito non soddisfatto deve partire disabilitata")
	assert(not bottone_ultima_donazione.disabled, "sottotrama senza prerequisito deve partire disponibile")
	print("OK: 10 bottoni sottotrama creati, prerequisito di 'Il tesoro del vecchio boss' rispettato.")

	# Completare il prerequisito (qualunque esito) deve rivalutare il
	# bottone della sottotrama tramite la UI.
	var bottone_riattivare: Button = ui.bottoni_azione["Riattivare un vecchio contatto della rete criminale"]
	bottone_riattivare.pressed.emit()
	var riattivato_con_successo := stato.azione_completata_con_successo("Riattivare un vecchio contatto della rete criminale")
	assert(bottone_tesoro.disabled == not riattivato_con_successo,
		"il bottone della sottotrama deve riflettere l'esito del prerequisito dopo la pressione del bottone azione")
	print("OK: la UI rivaluta la sottotrama con prerequisito dopo l'azione richiesta (esito: %s)." % ("successo" if riattivato_con_successo else "fallimento"))

	# Fase 9c: il bottone cash-in deve abilitarsi quando 2+ tracce sono a
	# Rango 2, e la pressione deve applicare stato.applica_cash_in().
	var ui3 := GameUI.new()
	add_child(ui3)
	var stato3 := GameState.new()
	ui3.avvia(stato3)
	assert(ui3.cashin_button.disabled)
	stato3.tracce_raggiunte["Lavoro"] = 2
	stato3.tracce_raggiunte["Criminale"] = 2
	ui3._aggiorna_sinergia_ui()
	assert(not ui3.cashin_button.disabled, "il cash-in deve abilitarsi con 2 tracce a Rango 2")
	var turno_prima := stato3.turno
	ui3.cashin_button.pressed.emit()
	assert(stato3.turno == turno_prima + 1, "la pressione del bottone deve applicare il cash-in su GameState")
	assert(ui3.cashin_button.disabled, "il cash-in è una tantum, deve disabilitarsi dopo il tentativo")
	print("OK: bottone cash-in si abilita con 2 tracce a Rango 2 e applica il tentativo su GameState.")

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


func _run_test_sinergie() -> void:
	print("=== Fase 9c: auto-test headless delle sinergie tra tracce ===")

	var s1 := GameState.new(1)
	assert(s1.combo_dimensione() == 0)
	assert(not s1.cash_in_disponibile())
	s1.tracce_raggiunte["Lavoro"] = 2
	assert(s1.combo_dimensione() == 1)
	assert(not s1.cash_in_disponibile())
	print("OK: nessuna sinergia con < 2 tracce a Rango 2.")

	var s2 := GameState.new(2)
	s2.tracce_raggiunte["Lavoro"] = 2
	s2.tracce_raggiunte["Criminale"] = 2
	assert(s2.combo_dimensione() == 2)
	assert(s2.cash_in_disponibile())
	var combo: Array = s2.combo_tracce()
	assert(combo.size() == 2 and "Lavoro" in combo and "Criminale" in combo)
	print("OK: sinergia coppia (2 tracce) rilevata correttamente.")

	# Il rischio del cash-in e' una costante fissa (CASH_IN_RISCHIO_PCT):
	# proviamo piu' seed finche' non troviamo un successo e un fallimento,
	# per verificare entrambi i rami deterministicamente.
	var trovato_successo := false
	var trovato_fallimento := false
	for tentativo_seed in range(3, 300):
		if trovato_successo and trovato_fallimento:
			break
		var s := GameState.new(tentativo_seed)
		s.tracce_raggiunte["Lavoro"] = 2
		s.tracce_raggiunte["Criminale"] = 2
		# Interpretazione B (Fase 10, confermata dall'autore): il bonus del
		# cash-in si basa solo sul valore di Rango 2 delle tracce coinvolte,
		# non su Rango1+Rango2 sommati — vedi GameState.applica_cash_in().
		var bonus_atteso: float = (s.valore_rango2_traccia("Lavoro") + s.valore_rango2_traccia("Criminale")) * 2.0
		var sabbia_prima := s.sabbia_padre_ore
		var r := s.applica_cash_in()

		if r.successo and not trovato_successo:
			assert(r.effetto_sabbia_padre_ore > 0)
			# ±20% di varianza sul guadagno (ActionVariance), stesso range delle azioni/tracce/sottotrame.
			assert(r.effetto_sabbia_padre_ore >= bonus_atteso * 0.75 and r.effetto_sabbia_padre_ore <= bonus_atteso * 1.25,
				"il bonus del cash-in deve essere ~(solo Rango2 x moltiplicatore x2), non (Rango1+Rango2) x3: atteso ~%.1f, ottenuto %.1f" % [bonus_atteso, r.effetto_sabbia_padre_ore])
			assert(r.moltiplicatore == 2.0)
			trovato_successo = true
			print("OK: cash-in riuscito applica (solo Rango2 delle tracce della combo) x moltiplicatore alla Sabbia-Padre.")

		elif not r.successo and not trovato_fallimento:
			assert(s.tracce_raggiunte.get("Lavoro", 0) == 0,
				"il fallimento del cash-in deve azzerare il progresso di TUTTE le tracce della combo")
			assert(s.tracce_raggiunte.get("Criminale", 0) == 0)
			var lavoro1 := TrackDatabase.get_riga("Lavoro", 1)
			var lavoro2 := TrackDatabase.get_riga("Lavoro", 2)
			assert(not s.traccia_disponibile(lavoro1),
				"dopo il fallimento del cash-in le righe delle tracce coinvolte devono essere bloccate")
			assert(not s.traccia_disponibile(lavoro2))
			trovato_fallimento = true
			print("OK: cash-in fallito azzera il progresso e blocca TUTTE le righe delle tracce della combo.")

	assert(trovato_successo, "nessun successo di cash-in trovato in 300 tentativi")
	assert(trovato_fallimento, "nessun fallimento di cash-in trovato in 300 tentativi")

	var s5 := GameState.new(2)
	s5.tracce_raggiunte["Lavoro"] = 2
	s5.tracce_raggiunte["Criminale"] = 2
	s5.applica_cash_in()
	assert(not s5.cash_in_disponibile())
	var r5b := s5.applica_cash_in()
	assert(r5b.has("rifiutata"))
	print("OK: il cash-in è una tantum per run.")

	var s6 := GameState.new(6)
	s6.azioni_uniche_usate["sottotrama:Il tesoro del vecchio boss"] = true
	assert(s6.combo_dimensione() == 0, "le sottotrame non devono mai contribuire al conteggio N della sinergia")
	print("OK: le sottotrame non contano per il conteggio della sinergia.")

	var s7 := GameState.new(7)
	assert(s7.malus_attivi().is_empty())
	s7.tracce_raggiunte["Religiosa (indulgenze)"] = 2
	s7.tracce_raggiunte["Occulto (setta satanica)"] = 2
	var malus: Array = s7.malus_attivi()
	assert(malus.size() == 1)
	assert(malus[0][0] == "Religiosa (indulgenze)" and malus[0][1] == "Occulto (setta satanica)")
	print("OK: combinazione malus Religiosa+Occulto rilevata correttamente.")

	var s8 := GameState.new(8)
	for nome in ["Lavoro", "Criminale", "Politica", "Azzardo", "Bancaria"]:
		s8.tracce_raggiunte[nome] = 2
	assert(s8.tracce_a_rango_2().size() == 5)
	assert(s8.combo_dimensione() == 4, "la combo deve limitarsi a 4 anche con 5 tracce qualificate")
	print("OK: con 5+ tracce a Rango 2 la combo si limita alle 4 di maggior valore.")

	print("TUTTI I TEST SINERGIE OK")


func _run_test_fase10() -> void:
	print("=== Fase 10: auto-test headless delle 5 risorse ===")

	# --- Formula comune malus/Svantaggio -----------------------------------
	var sf := GameState.new(1)
	assert(sf._malus_risorsa(0.0) == 0)
	assert(sf._malus_risorsa(19.0) == 0)
	assert(sf._malus_risorsa(20.0) == -1)
	assert(sf._malus_risorsa(39.0) == -1)
	assert(sf._malus_risorsa(40.0) == -2)
	assert(sf._malus_risorsa(100.0) == -5)
	assert(not sf._svantaggio_da_risorsa(50.0), "50 non deve ancora dare Svantaggio (soglia: valore > 50)")
	assert(sf._svantaggio_da_risorsa(51.0))
	print("OK: formula malus graduale -floor(valore/20) e soglia Svantaggio a 50 (esclusivo) corrette.")

	# --- Ambito Attenzione Polizia / Fama Pubblica --------------------------
	var sap := GameState.new(2)
	sap.attenzione_polizia = 60.0  # malus -3, Svantaggio
	var azione_furto: ActionData = ActionDatabase.get_by_categoria("Furto")[0]
	var mod_furto := sap._modificatore_polizia_fama(azione_furto)
	assert(mod_furto.modificatore == -3 and mod_furto.svantaggio)
	var azione_lavoro: ActionData = ActionDatabase.find_by_nome("Turno di lavoro onesto (8h, salario mediano)")
	var mod_lavoro := sap._modificatore_polizia_fama(azione_lavoro)
	assert(mod_lavoro.modificatore == 0 and not mod_lavoro.svantaggio, "categorie fuori ambito non devono subire il malus")
	print("OK: Attenzione Polizia modifica il tiro solo nelle 7 categorie in ambito.")

	sap.fama_pubblica = 60.0
	var mod_senza_fama := sap._modificatore_polizia_fama(azione_furto)
	assert(mod_senza_fama.modificatore == -3, "Fama Pubblica non deve pesare senza un Rango 2 legittimo raggiunto")
	sap.tracce_raggiunte["Lavoro"] = 2
	var mod_con_fama := sap._modificatore_polizia_fama(azione_furto)
	assert(mod_con_fama.modificatore == -6, "con un Rango 2 legittimo, Fama Pubblica deve sommarsi al malus")
	print("OK: Fama Pubblica si applica solo dopo un Rango 2 legittimo raggiunto in questa run.")

	# --- Peso Karma ----------------------------------------------------------
	assert(sf._peso_karma("Estrema") == -5.0)
	assert(sf._peso_karma("Ambigua (costo emotivo)") == -1.0, "un suffisso tra parentesi deve contare come l'etichetta base")
	assert(sf._peso_karma("Pulita/altruista") == 2.0)
	assert(sf._peso_karma("Neutra") == 0.0)
	assert(sf._peso_karma("Pericoloso") == 0.0)
	print("OK: pesi Karma per etichetta Moralità corretti, incluse le varianti con suffisso.")

	# --- Attenzione Polizia sale su fallimento, scende con la corruzione ----
	var trovato_fallimento_polizia := false
	var trovato_corruzione := false
	for seed_t in range(1, 500):
		if trovato_fallimento_polizia and trovato_corruzione:
			break
		if not trovato_fallimento_polizia:
			var s := GameState.new(seed_t)
			var r := s.applica_azione_con_dado(azione_furto)
			if not r.successo:
				var atteso: float = GameState.ATTENZIONE_POLIZIA_INCREMENTO_FALLIMENTO_CRITICO if r.roll.fallimento_critico else GameState.ATTENZIONE_POLIZIA_INCREMENTO_FALLIMENTO
				assert(s.attenzione_polizia == atteso)
				trovato_fallimento_polizia = true
		if not trovato_corruzione:
			var s2 := GameState.new(seed_t + 10000)
			s2.attenzione_polizia = 50.0
			var azione_corr := ActionDatabase.find_by_nome(GameState.AZIONE_DECREMENTO_ATTENZIONE_POLIZIA)
			var r2 := s2.applica_azione_con_dado(azione_corr)
			if r2.successo:
				assert(s2.attenzione_polizia == 50.0 - GameState.ATTENZIONE_POLIZIA_DECREMENTO_CORRUZIONE)
				trovato_corruzione = true
	assert(trovato_fallimento_polizia and trovato_corruzione)
	print("OK: Attenzione Polizia sale su un fallimento in ambito e scende con 'Corrompere un poliziotto' riuscita.")

	# --- Karma si aggiorna sempre, successo o fallimento ---------------------
	var sk := GameState.new(3)
	var azione_ambigua := ActionDatabase.find_by_nome(GameState.AZIONE_DECREMENTO_RIVALITA_CRIMINALE)
	assert(azione_ambigua.moralita == "Ambigua")
	var karma_prima_k := sk.karma
	sk.applica_azione_con_dado(azione_ambigua)
	assert(sk.karma == karma_prima_k - 1.0)
	print("OK: Karma si aggiorna dal peso Moralità dell'azione indipendentemente dall'esito.")

	# --- Cadenza eventi casuali: ogni 6 turni --------------------------------
	var se := GameState.new(4)
	var azione_ripetibile := ActionDatabase.find_by_nome("Turno di lavoro onesto (8h, salario mediano)")
	var eventi_visti := 0
	for i in 6:
		var r := se.applica_azione_con_dado(azione_ripetibile)
		if r.get("evento_casuale") != null:
			eventi_visti += 1
			assert(i == 5, "l'evento deve scattare esattamente al 6° turno, non prima")
	assert(eventi_visti == 1)
	print("OK: un evento casuale scatta esattamente ogni 6 turni risolti.")

	# --- Fede del Culto/Setta -------------------------------------------------
	var riga_culto_1 := TrackDatabase.get_riga("Religiosa (indulgenze)", 1)
	var sfe := GameState.new(5)
	sfe.fede_setta = 15.0
	sfe._aggiorna_fede_dopo_traccia(riga_culto_1)
	assert(sfe.fede_culto == 40.0)
	assert(sfe.fede_setta == 5.0, "il Rango 1 dell'una deve abbassare l'altra di 10")
	print("OK: completare il Rango 1 di Religiosa alza Fede del Culto di 40 e abbassa Fede della Setta di 10.")

	var riga_culto_2 := TrackDatabase.get_riga("Religiosa (indulgenze)", 2)
	var sfe2 := GameState.new(6)
	assert(not sfe2.traccia_disponibile(riga_culto_2), "Rango 2 deve restare bloccato senza il Rango 1")
	sfe2.tracce_raggiunte["Religiosa (indulgenze)"] = 1
	assert(not sfe2.traccia_disponibile(riga_culto_2), "Rango 2 deve restare bloccato con Fede < %.0f" % GameState.FEDE_SOGLIA_RANGO2)
	assert(sfe2.traccia_bloccata_da_fede(riga_culto_2))
	sfe2.fede_culto = GameState.FEDE_SOGLIA_RANGO2
	assert(sfe2.traccia_disponibile(riga_culto_2), "Rango 2 deve sbloccarsi con Fede >= soglia e Rango 1 già raggiunto")
	assert(not sfe2.traccia_bloccata_da_fede(riga_culto_2))
	print("OK: il Rango 2 di Religiosa/Occulto richiede sia il Rango 1 sia Fede corrispondente >= %.0f." % GameState.FEDE_SOGLIA_RANGO2)

	# Correzione confermata dall'autore dopo la Fase 10: la soglia è stata
	# abbassata da 50 a 40 esattamente perché un singolo Rango 1 riuscito dà
	# +40 Fede — deve bastare da solo, senza bisogno di altre fonti.
	var sfe3 := GameState.new(7)
	sfe3._aggiorna_fede_dopo_traccia(TrackDatabase.get_riga("Religiosa (indulgenze)", 1))
	sfe3.tracce_raggiunte["Religiosa (indulgenze)"] = 1
	assert(sfe3.fede_culto == 40.0)
	assert(sfe3.traccia_disponibile(riga_culto_2),
		"un singolo Rango 1 riuscito (Fede 40) deve bastare da solo a sbloccare il Rango 2, senza altre fonti di Fede")
	print("OK: un singolo Rango 1 riuscito su una traccia religiosa sblocca da solo il Rango 2 della stessa traccia (soglia 40).")

	# --- Rivalità Criminale: traccia Criminale, sottotrame, tributo ----------
	var riga_crim_1 := TrackDatabase.get_riga("Criminale", 1)
	var trovato_rivalita_su := false
	var trovato_rivalita_giu := false
	for seed_t2 in range(1, 500):
		if trovato_rivalita_su and trovato_rivalita_giu:
			break
		if not trovato_rivalita_su:
			var s := GameState.new(seed_t2)
			var r := s.applica_traccia(riga_crim_1)
			if r.get("successo", false):
				assert(s.rivalita_criminale == GameState.RIVALITA_CRIMINALE_INCREMENTO_RANGO1)
				trovato_rivalita_su = true
		if not trovato_rivalita_giu:
			var s2 := GameState.new(seed_t2 + 10000)
			s2.rivalita_criminale = 50.0
			var azione_tributo := ActionDatabase.find_by_nome(GameState.AZIONE_DECREMENTO_RIVALITA_CRIMINALE)
			var r2 := s2.applica_azione_con_dado(azione_tributo)
			if r2.successo:
				assert(s2.rivalita_criminale == 50.0 - GameState.RIVALITA_CRIMINALE_DECREMENTO_TRIBUTO)
				trovato_rivalita_giu = true
	assert(trovato_rivalita_su and trovato_rivalita_giu)
	print("OK: Rivalità Criminale sale con la traccia Criminale e scende con 'Pagare un tributo ai rivali' riuscita.")

	# --- Patto con lo Stregatto ------------------------------------------------
	var patto_trovato := false
	for seed_p in range(1, 400):
		var sp := GameState.new(seed_p)
		sp.karma_inizio_run = -60.0
		sp._karma_inizio_run_catturato = true
		var ev := sp._pesca_evento_casuale()
		if ev.get("tipo") == "patto_stregatto_proposto":
			patto_trovato = true
			assert(not sp.patto_in_sospeso.is_empty())
			var prezzo_atteso := roundf(sp.sabbia_padre_ore * 0.5)
			assert(ev.prezzo_ore == prezzo_atteso)

			var r_bloccato := sp.applica_azione_con_dado(azione_lavoro)
			assert(r_bloccato.has("rifiutata"), "nessun'altra azione deve poter procedere col patto in sospeso")

			var karma_prima_p := sp.karma
			var sabbia_prima_p := sp.sabbia_padre_ore
			var r_accetta := sp.risolvi_patto_stregatto(true)
			assert(r_accetta.accettato)
			assert(is_equal_approx(sp.sabbia_padre_ore, sabbia_prima_p - prezzo_atteso))
			assert(is_equal_approx(sp.karma, minf(karma_prima_p + 30.0, 100.0)))
			assert(sp.patto_in_sospeso.is_empty())
			break
	assert(patto_trovato, "nessuna proposta di patto trovata in 400 tentativi (atteso ~15% con Karma iniziale <= -50)")
	print("OK: il Patto con lo Stregatto viene proposto solo con Karma <= -50 a inizio run, blocca altre azioni finché non risolto, applica prezzo/effetto se accettato.")

	var sp2 := GameState.new(1)
	sp2.karma_inizio_run = 0.0
	sp2._karma_inizio_run_catturato = true
	var mai_proposto := true
	for i in 200:
		var ev2 := sp2._pesca_evento_casuale()
		if ev2.get("tipo") == "patto_stregatto_proposto":
			mai_proposto = false
			break
	assert(mai_proposto, "il patto non deve mai essere proposto con Karma iniziale > -50")
	print("OK: nessun patto proposto quando il Karma a inizio run non è <= -50.")

	print("TUTTI I TEST FASE 10 OK")


func _run_test_difficolta() -> void:
	print("=== Batch tecnico: auto-test headless della difficoltà crescente ===")

	var s0 := GameState.new(1, 0)
	assert(s0.sabbia_padre_ore == GameState.SABBIA_PADRE_INIZIALE)
	print("OK: livello 0 non altera la Sabbia-Padre iniziale (%.1fh)." % s0.sabbia_padre_ore)

	var s2 := GameState.new(1, 2)
	assert(s2.sabbia_padre_ore == GameState.SABBIA_PADRE_INIZIALE - 2 * GameState.SABBIA_PADRE_RIDUZIONE_PER_LIVELLO)
	print("OK: livello 2 riduce la Sabbia-Padre iniziale a %.1fh (24h - 2x4h)." % s2.sabbia_padre_ore)

	var s_alto := GameState.new(1, 50)
	assert(s_alto.sabbia_padre_ore == GameState.SABBIA_PADRE_MINIMA_DIFFICOLTA)
	print("OK: livelli molto alti clampano la Sabbia-Padre iniziale al floor di %.1fh, mai a 0 o negativa." % GameState.SABBIA_PADRE_MINIMA_DIFFICOLTA)

	assert(s0._rischio_con_difficolta(0.20) == 0.20)
	assert(is_equal_approx(s2._rischio_con_difficolta(0.20), 0.30))
	assert(s2._rischio_con_difficolta(0.95) == 1.0, "il rischio deve clampare a 100%%, mai superarlo")
	print("OK: il rischio base sale del +5%% per livello (clampato a 100%%).")

	var azione_furto: ActionData = ActionDatabase.get_by_categoria("Furto")[0]
	var trovato_fallimento_soltanto_a_difficolta_alta := false
	for seed_t in range(1, 500):
		var s_base := GameState.new(seed_t, 0)
		var s_diff := GameState.new(seed_t, 4)  # stesso seed: stessa sequenza di dadi, rischio diverso
		var r_base := s_base.applica_azione_con_dado(azione_furto)
		var r_diff := s_diff.applica_azione_con_dado(azione_furto)
		if r_base.successo and not r_diff.successo:
			trovato_fallimento_soltanto_a_difficolta_alta = true
			break
	assert(trovato_fallimento_soltanto_a_difficolta_alta,
		"nessun seed trovato in cui la difficoltà più alta trasforma un successo in fallimento (stesso seed, stessa azione)")
	print("OK: a parità di seed, una difficoltà più alta può trasformare un successo in un fallimento (rischio applicato davvero al dado).")

	# Il gate (profilo senza traguardo -> livello forzato a 0) è testato
	# direttamente sull'helper di main.gd, senza serializzazione.
	var profilo_bloccato := PlayerProfile.new()
	assert(_livello_difficolta_effettivo(3, profilo_bloccato) == 0,
		"senza traguardo_100_100_raggiunto, qualunque livello richiesto deve essere forzato a 0")
	profilo_bloccato.traguardo_100_100_raggiunto = true
	assert(_livello_difficolta_effettivo(3, profilo_bloccato) == 3,
		"con traguardo_100_100_raggiunto, il livello richiesto deve essere concesso")
	print("OK: il gate 'sbloccato dopo il primo 100+100' forza il livello a 0 finché il profilo non lo conferma raggiunto.")

	print("TUTTI I TEST DIFFICOLTÀ OK")


func _run_test_seed_del_giorno() -> void:
	print("=== Batch tecnico: auto-test headless del Seed del Giorno ===")

	var data_str := "2026-08-29"
	var s1 := SeedDelGiorno.seed_da_data(data_str)
	var s2 := SeedDelGiorno.seed_da_data(data_str)
	assert(s1 == s2, "stessa data deve dare sempre lo stesso seed")
	assert(s1 >= 0, "il seed derivato dalla data deve essere sempre non negativo")
	print("OK: SeedDelGiorno.seed_da_data() è deterministico e non negativo (data %s -> seed %d)." % [data_str, s1])

	var s_domani := SeedDelGiorno.seed_da_data("2026-08-30")
	assert(s_domani != s1, "giorni diversi devono (con probabilità overwhelming) dare seed diversi")
	print("OK: date diverse danno seed diversi (%d vs %d)." % [s1, s_domani])

	var oggi := SeedDelGiorno.data_di_oggi_stringa()
	assert(oggi.length() == 10 and oggi[4] == "-" and oggi[7] == "-", "formato atteso YYYY-MM-DD, trovato %s" % oggi)
	assert(SeedDelGiorno.seed_di_oggi() == SeedDelGiorno.seed_da_data(oggi))
	print("OK: seed_di_oggi() usa la data odierna nel formato YYYY-MM-DD (%s)." % oggi)

	# Due run con lo stesso seed del giorno devono essere identiche (stessa
	# proprietà già garantita da GameState per qualunque seed — verificata
	# qui specificamente per il path SeedDelGiorno, non ridondante: prova
	# che seed_da_data() produce davvero un intero utilizzabile da
	# GameState, non solo un valore plausibile).
	var stato_a := GameState.new(s1)
	var stato_b := GameState.new(s1)
	var azione := ActionDatabase.get_by_index(0)
	var ra := stato_a.applica_azione_con_dado(azione)
	var rb := stato_b.applica_azione_con_dado(azione)
	assert(ra.costo_tempo_figlia_ore == rb.costo_tempo_figlia_ore and ra.successo == rb.successo)
	print("OK: il seed derivato è un seed valido per GameState, riproducibile turno per turno.")

	# Storico locale nel Profilo Persistente.
	var profilo := PlayerProfile.new()
	assert(profilo.tentativi_seed_del_giorno(data_str).is_empty())
	var punteggio_finto := {"punteggio_totale_anni": 42.0, "padre_anni": 20.0, "figlia_anni": 22.0, "vittoria_100_100": false}
	profilo.registra_punteggio_seed_del_giorno(data_str, punteggio_finto)
	profilo.registra_punteggio_seed_del_giorno(data_str, punteggio_finto)
	var tentativi: Array = profilo.tentativi_seed_del_giorno(data_str)
	assert(tentativi.size() == 2, "due registrazioni devono accumularsi, non sovrascriversi")
	assert(tentativi[0].totale_anni == 42.0)
	assert(tentativi[0].has("timestamp_unix"))
	print("OK: PlayerProfile.registra_punteggio_seed_del_giorno() accumula lo storico per data, non sovrascrive.")

	# Round-trip su disco (nessun processo separato qui: il round-trip vero
	# tra processi è già coperto da --test-save-write/read).
	assert(PlayerProfile.from_dict(profilo.to_dict()).tentativi_seed_del_giorno(data_str).size() == 2)
	print("OK: storico_seed_del_giorno sopravvive a to_dict()/from_dict() (serializzazione JSON).")

	print("TUTTI I TEST SEED DEL GIORNO OK")


func _run_test_narrativa() -> void:
	print("=== TEST NARRATIVA ===")
	assert(Narrativa.frase_serena(0.0) != Narrativa.frase_serena(-30.0))
	assert(Narrativa.frase_serena(-80.0) == "L'ho vista in te, oggi. Non voltarti.")
	assert(Narrativa.frase_serena(80.0) == "Non ti giudico più. Guardo solo.")
	var pulito := Narrativa.epilogo(true, true, true, 40.0)
	var ambiguo := Narrativa.epilogo(true, true, true, 0.0)
	var sporco := Narrativa.epilogo(true, true, true, -70.0)
	assert(pulito != ambiguo and ambiguo != sporco and pulito != sporco)
	assert(Narrativa.epilogo(false, false, true, 0.0) == Narrativa.epilogo(true, false, true, 90.0))
	assert(Narrativa.epilogo(false, true, true, 0.0) != ambiguo)
	assert(not Narrativa.patto_proposta(12.0).contains("PLACEHOLDER"))
	assert(Narrativa.patto_proposta(12.0).contains("12.0"))
	print("TUTTI I TEST NARRATIVA OK")
	get_tree().quit()


func _run_test_bivi() -> void:
	print("=== Batch tecnico: auto-test headless dello scheletro dei bivi (design doc 12.2) ===")

	var bivi := BivioSystem.get_bivi_segnaposto()
	assert(bivi.size() == 3, "attesi 3 bivi segnaposto")
	for b in bivi:
		assert(b.opzioni.size() == 2 or b.opzioni.size() == 3, "ogni bivio deve avere 2-3 opzioni")
	print("OK: %d bivi segnaposto caricati, ciascuno con 2-3 opzioni." % bivi.size())

	var stato := GameState.new(1)
	var bivio: BivioSystem.Bivio = bivi[0]

	assert(stato.bivio_disponibile(bivio.id))
	assert(stato.opzione_scelta(bivio.id) == -1)
	print("OK: un bivio non ancora risolto è disponibile e non ha un'opzione scelta.")

	var r_fuori_range := stato.applica_bivio(bivio, 99)
	assert(r_fuori_range.has("rifiutata"), "un indice fuori range deve essere rifiutato")
	assert(stato.bivio_disponibile(bivio.id), "un tentativo rifiutato non deve consumare il bivio")
	print("OK: un indice opzione fuori range viene rifiutato senza consumare il bivio.")

	var turno_prima := stato.turno
	var r := stato.applica_bivio(bivio, 1)
	assert(not r.has("rifiutata"))
	assert(r.opzione_indice == 1)
	assert(r.opzione_nome == bivio.opzioni[1].nome)
	assert(stato.turno == turno_prima, "un bivio non deve consumare un turno")
	print("OK: applica_bivio() applica la scelta senza consumare un turno.")

	assert(not stato.bivio_disponibile(bivio.id), "il bivio deve risultare risolto dopo la scelta")
	assert(stato.opzione_scelta(bivio.id) == 1)
	var r_ripetuto := stato.applica_bivio(bivio, 0)
	assert(r_ripetuto.has("rifiutata"), "un bivio già risolto non deve poter essere ririsolto")
	assert(stato.opzione_scelta(bivio.id) == 1, "la scelta originale non deve cambiare dopo un tentativo rifiutato")
	print("OK: un bivio risolto preclude tutte le opzioni (anche quella già scelta) per il resto della run.")

	var bivio2: BivioSystem.Bivio = bivi[1]
	assert(stato.bivio_disponibile(bivio2.id), "bivi diversi devono restare indipendenti l'uno dall'altro")
	print("OK: risolvere un bivio non influenza la disponibilità degli altri bivi nella stessa run.")

	var stato_nuovo := GameState.new(2)
	assert(stato_nuovo.bivio_disponibile(bivio.id), "una nuova run (nuovo GameState) deve ripartire con tutti i bivi disponibili")
	print("OK: i bivi sono per-run (nessuna persistenza tra run diverse in questo scheletro tecnico).")

	print("TUTTI I TEST BIVI OK")


func _run_test_rete_contatti() -> void:
	print("=== Batch tecnico: auto-test headless dello scheletro della Rete di contatti (design doc 12.3) ===")

	var contatti := ContactNetwork.get_contatti_segnaposto()
	assert(contatti.size() == 3, "attesi 3 contatti segnaposto")
	print("OK: %d contatti segnaposto caricati." % contatti.size())

	# --- Trigger: sottotrama completata ---
	var c_sottotrama := ContactNetwork.get_contatto("contatto_segnaposto_sottotrama")
	var sub: SubplotData = null
	for candidato: SubplotData in SubplotDatabase.get_all():
		if candidato.nome == c_sottotrama.trigger_parametro:
			sub = candidato
			break
	assert(sub != null, "sottotrama trigger '%s' non trovata in SubplotDatabase" % c_sottotrama.trigger_parametro)
	var trovato_successo_sub := false
	for seed_t in range(10, 300):
		var s := GameState.new(seed_t)
		var r := s.applica_sottotrama(sub)
		if r.get("successo", false):
			assert(s.azione_completata_con_successo(c_sottotrama.trigger_parametro))
			var profilo_test := PlayerProfile.new()
			var nuovi := ContactNetwork.valuta_sblocchi(s, profilo_test)
			assert(nuovi.has(c_sottotrama.id), "il contatto deve sbloccarsi dopo il successo della sottotrama trigger")
			assert(profilo_test.contatto_sbloccato(c_sottotrama.id))
			trovato_successo_sub = true
			break
	assert(trovato_successo_sub, "nessun successo trovato per la sottotrama trigger in 300 tentativi")
	print("OK: trigger SOTTOTRAMA_COMPLETATA sblocca il contatto quando la sottotrama riesce.")

	# --- Trigger: rango di traccia raggiunto ---
	var c_traccia := ContactNetwork.get_contatto("contatto_segnaposto_traccia")
	var s2 := GameState.new(20)
	var profilo2 := PlayerProfile.new()
	assert(ContactNetwork.valuta_sblocchi(s2, profilo2).is_empty(), "senza il rango richiesto il contatto non deve sbloccarsi")
	var parti := c_traccia.trigger_parametro.split("|")
	s2.tracce_raggiunte[parti[0]] = int(parti[1])
	var nuovi2 := ContactNetwork.valuta_sblocchi(s2, profilo2)
	assert(nuovi2.has(c_traccia.id))
	print("OK: trigger TRACCIA_RANGO_RAGGIUNTO sblocca il contatto quando il rango è raggiunto.")

	# --- Idempotenza: un contatto già sbloccato non viene ri-segnalato ---
	var nuovi2_bis := ContactNetwork.valuta_sblocchi(s2, profilo2)
	assert(nuovi2_bis.is_empty(), "un contatto già sbloccato non deve essere ri-segnalato come nuovo")
	print("OK: valuta_sblocchi() è idempotente — un contatto sbloccato non si ri-sblocca.")

	# --- Effetto: riduzione costo/rischio, aggregazione, nessun effetto se inattivo ---
	var bersaglio := c_sottotrama.bersaglio_effetto
	var mod_senza := ContactNetwork.modificatore_per_azione(bersaglio, [])
	assert(mod_senza.riduzione_costo == 0.0 and mod_senza.riduzione_rischio == 0.0)
	var mod_con: Array[String] = [c_sottotrama.id]
	var mod := ContactNetwork.modificatore_per_azione(bersaglio, mod_con)
	assert(is_equal_approx(mod.riduzione_costo, c_sottotrama.valore_effetto))
	print("OK: modificatore_per_azione() restituisce 0 senza il contatto attivo, il valore atteso con il contatto attivo.")

	# --- Effetto: sblocco azione invisibile ---
	var c_sblocco := ContactNetwork.get_contatto("contatto_segnaposto_sblocco")
	assert(not ContactNetwork.azione_visibile(c_sblocco.bersaglio_effetto, []), "senza il contatto, l'azione bersaglio deve restare invisibile")
	assert(ContactNetwork.azione_visibile(c_sblocco.bersaglio_effetto, [c_sblocco.id]), "col contatto attivo, l'azione bersaglio deve diventare visibile")
	print("OK: azione_visibile() nasconde/mostra il bersaglio SBLOCCO_AZIONE in base al contatto.")

	# --- Nessuna delle 62 azioni reali è toccata (regressione di sicurezza) ---
	var tutte_azioni := ActionDatabase.get_all()
	var nessuna_reale_bersagliata := true
	for a: ActionData in tutte_azioni:
		for c in contatti:
			if c.bersaglio_effetto == a.nome:
				nessuna_reale_bersagliata = false
	assert(nessuna_reale_bersagliata, "nessun contatto segnaposto deve bersagliare un'azione reale del gioco")
	var s3 := GameState.new(30)
	var azione_test: ActionData = tutte_azioni[0]
	assert(s3.azione_disponibile(azione_test), "senza contatti attivi un'azione reale deve restare disponibile come sempre")
	s3.contatti_attivi = [c_sblocco.id, c_traccia.id, c_sottotrama.id]
	assert(s3.azione_disponibile(azione_test), "con QUALUNQUE contatto segnaposto attivo, un'azione reale deve restare disponibile come sempre")
	print("OK: nessuna delle 62 azioni reali è bersagliata dai contatti segnaposto (nessun effetto sul gioco reale).")

	# --- Persistenza tra run diverse (il punto richiesto esplicitamente dal task) ---
	# Run 1: profilo vuoto, un GameState sblocca il contatto sottotrama.
	var profilo_run1 := PlayerProfile.new()
	assert(not profilo_run1.contatto_sbloccato(c_sottotrama.id))
	profilo_run1.sblocca_contatto(c_sottotrama.id)
	# Simula "chiudi il gioco, riapri": round-trip completo attraverso JSON,
	# non solo to_dict()/from_dict() in memoria (--test-save-write/read
	# copre già il round-trip vero tra PROCESSI separati per gli altri
	# campi; qui basta provare che la serializzazione stessa sia fedele).
	var salvato := JSON.stringify(profilo_run1.to_dict())
	var profilo_run2 := PlayerProfile.from_dict(JSON.parse_string(salvato))
	assert(profilo_run2.contatto_sbloccato(c_sottotrama.id), "il contatto sbloccato deve sopravvivere alla serializzazione JSON")

	# Run 2: un GameState NUOVO (run diversa) nasce con contatti_attivi
	# popolato dal profilo appena ricaricato — esattamente il collegamento
	# che main.gd fa in _run_ui().
	var stato_run2 := GameState.new(40)
	var contatti_run2: Array[String] = []
	for id in profilo_run2.rete_contatti_sbloccati:
		contatti_run2.append(str(id))
	stato_run2.contatti_attivi = contatti_run2
	var mod_run2 := ContactNetwork.modificatore_per_azione(c_sottotrama.bersaglio_effetto, stato_run2.contatti_attivi)
	assert(is_equal_approx(mod_run2.riduzione_costo, c_sottotrama.valore_effetto),
		"l'effetto del contatto sbloccato in una run precedente deve essere attivo in una run NUOVA e diversa")
	print("OK: uno sblocco ottenuto in una run persiste (via PlayerProfile) e ha effetto in una run successiva diversa.")

	print("TUTTI I TEST RETE DI CONTATTI OK")


## Difficoltà crescente (design doc 12.5): "sbloccabili DOPO il primo
## traguardo 100+100" letto come un gate binario (non un percorso
## sequenziale alla Ascension/Slay the Spire, che il design doc cita solo
## come ispirazione di genere) — finché il profilo non ha
## traguardo_100_100_raggiunto, qualunque livello richiesto viene forzato
## a 0. Nessun tetto massimo esplicito al livello una volta sbloccato (non
## specificato): GameState clampa comunque la Sabbia-Padre iniziale a un
## floor di 1h, quindi livelli molto alti restano teoricamente selezionabili
## ma sempre più ingiocabili, mai a costo/crash negativo.
func _livello_difficolta_effettivo(richiesto: int, profilo: PlayerProfile) -> int:
	if richiesto <= 0:
		return 0
	if not profilo.traguardo_100_100_raggiunto:
		print("Difficoltà %d richiesta ma non ancora sbloccata (serve prima un traguardo 100+100): uso livello 0." % richiesto)
		return 0
	return richiesto


func _run_ui(seed_arg: int = -1, difficolta_arg: int = 0, usa_seed_del_giorno: bool = false) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var ui := GameUI.new()
	add_child(ui)
	var profilo := PlayerProfile.load()
	var livello := _livello_difficolta_effettivo(difficolta_arg, profilo)
	if usa_seed_del_giorno:
		var precedenti: Array = profilo.tentativi_seed_del_giorno()
		if not precedenti.is_empty():
			print("Seed del giorno %s: %d tentativi precedenti oggi (record %.2f anni)." % [
				SeedDelGiorno.data_di_oggi_stringa(), precedenti.size(), _record_tentativi(precedenti)
			])
	var stato := GameState.new(seed_arg, livello)
	var contatti: Array[String] = []
	for id in profilo.rete_contatti_sbloccati:
		contatti.append(str(id))
	stato.contatti_attivi = contatti
	ui.avvia(stato, profilo, usa_seed_del_giorno)


func _record_tentativi(tentativi: Array) -> float:
	var migliore := 0.0
	for t in tentativi:
		migliore = maxf(migliore, t.totale_anni)
	return migliore


func _run_simulation(n: int) -> void:
	print("=== IL LADRO DI SABBIA — Fase 5: validazione bilanciamento (%d run per politica) ===" % n)
	print("")
	for politica in ["greedy", "greedy_no_free", "random"]:
		var stats := BalanceSimulator.esegui_batch(n, politica)
		_stampa_report_batch(stats)
		print("")

	print("--- Sequenza scriptata: tripletta storica (Azzardo+Bancaria+Religiosa, %d run) ---" % n)
	print("Nessuna politica euristica sceglie mai spontaneamente questa strategia (valore atteso più basso della strategia prudente, design doc 7.4) — sequenza forzata per misurarne la probabilità reale col dado.")
	var tripletta := BalanceSimulator.simula_tripletta_storica(n)
	print("Probabilità di successo dell'INTERA catena (6 climb + cash-in): %.2f%%" % (tripletta.prob_successo_catena * 100.0))
	print("Punteggio medio totale (padre+figlia) quando la catena riesce: %.2f anni" % tripletta.punteggio_medio_se_successo)
	print("Punteggio medio totale su TUTTI i tentativi (riusciti e falliti): %.2f anni" % tripletta.punteggio_medio_totale)
	print("Riferimento storico design doc: 16,8%% deterministico -> 8,4%% con varianza Monte Carlo (sezione 7.4/12.7).")
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
	print("Cash-in sinergia tentato in %.2f%% delle run; tra queste, successo nel %.2f%% dei casi." % [
		s.prob_cashin_tentato * 100.0, s.prob_cashin_riuscito_se_tentato * 100.0
	])


func _run_play_loop(seed_arg: int = -1, difficolta_arg: int = 0, usa_seed_del_giorno: bool = false) -> void:
	print("=== IL LADRO DI SABBIA — prototipo testuale ===")
	print(Narrativa.INTRO)
	print("Scegli azioni per raccogliere sabbia prima che uno dei due countdown arrivi a zero.")
	print("")

	# --play e' uno strumento di debug/test (non usa il Profilo Persistente,
	# vedi CLAUDE.md): il livello di difficolta' viene applicato SENZA il
	# gate del traguardo 100+100 che si applica invece alla UI reale, e il
	# Seed del Giorno forza solo il valore del seed, senza registrare nulla
	# nello storico (il Profilo Persistente resta non toccato da --play).
	var stato := GameState.new(seed_arg, difficolta_arg)
	if usa_seed_del_giorno:
		print("Seed del giorno (%s): %d" % [SeedDelGiorno.data_di_oggi_stringa(), stato.seed_run])
	print("Seed di questa run: %d (rilancia con --play --seed=%d per riprodurla)" % [stato.seed_run, stato.seed_run])
	if difficolta_arg > 0:
		print("Difficoltà forzata (debug, nessun gate): livello %d (Sabbia-Padre iniziale %.1fh, rischio +%.0f%%)" % [
			difficolta_arg, stato.sabbia_padre_ore, difficolta_arg * GameState.RISCHIO_AUMENTO_PER_LIVELLO * 100.0
		])
	print("")

	var tracce := TrackDatabase.get_tracce_normali()
	var sottotrame := SubplotDatabase.get_all()

	while not stato.is_over:
		_stampa_stato(stato)
		var azioni := ActionDatabase.get_all()
		_stampa_azioni(azioni, stato)
		_stampa_tracce(tracce, stato, azioni.size())
		_stampa_sottotrame(sottotrame, stato, azioni.size() + tracce.size())
		_stampa_sinergia(stato)
		_stampa_bivi(stato)
		print("")
		print("Scrivi il numero di un'azione, riga di traccia o sottotrama, 'spostati' per un evento di spostamento, 'cashin' per la sinergia (se disponibile), 'bivio <id> <indice>' per risolvere un bivio (vedi sopra), 'donare <ore>' per la donazione finale (unica, irreversibile), oppure 'esci' per interrompere la run.")
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
			_gestisci_evento_casuale(stato, r.get("evento_casuale"))
			continue

		if input.begins_with("bivio "):
			var parti := input.split(" ", false)
			if parti.size() < 3 or not parti[2].is_valid_int():
				print("Uso: 'bivio <id> <indice>', es. 'bivio bivio_inizio_run_segnaposto 0'.")
				print("")
				continue
			var bivio := BivioSystem.get_bivio(parti[1])
			if bivio == null:
				print("Bivio non trovato: %s" % parti[1])
				print("")
				continue
			var r := stato.applica_bivio(bivio, int(parti[2]))
			print("")
			if r.has("rifiutata"):
				print("Bivio non risolvibile: %s" % r.motivo)
				print("")
				continue
			print("-> Bivio '%s' risolto: %s" % [bivio.id, r.opzione_nome])
			print("   %s" % r.opzione_descrizione)
			print("")
			continue

		if input == "cashin":
			var r := stato.applica_cash_in()
			print("")
			if r.has("rifiutata"):
				print("Cash-in non disponibile: %s" % r.motivo)
				print("")
				continue
			print("-> %s" % r.azione)
			print("   Esito: %s | Costo Tempo-Figlia: -%.1fh | Effetto Sabbia-Padre: %+.1fh" % [
				"SUCCESSO" if r.successo else "FALLIMENTO (tutti i ranghi della combo sono persi)",
				r.costo_tempo_figlia_ore, r.effetto_sabbia_padre_ore
			])
			print("")
			_gestisci_evento_casuale(stato, r.get("evento_casuale"))
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

		if indice >= azioni.size() + tracce.size():
			var indice_sub := indice - azioni.size() - tracce.size()
			if indice_sub < 0 or indice_sub >= sottotrame.size():
				print("Numero fuori range: %s." % input)
				print("")
				continue
			var sub: SubplotData = sottotrame[indice_sub]
			var r := stato.applica_sottotrama(sub)
			print("")
			if r.has("rifiutata"):
				print("Sottotrama non disponibile: %s" % r.motivo)
				print("")
				continue
			var roll_s: DiceSystem.RollResult = r.roll
			print("-> %s (CD %d)" % [sub.nome, roll_s.cd])
			if roll_s.dadi.size() == 1:
				print("   Tiro: %d + mod %d = %d" % [roll_s.dadi[0], roll_s.modificatore, roll_s.totale])
			else:
				print("   Tiro: %s -> tenuto %d + mod %d = %d" % [roll_s.dadi, roll_s.naturale, roll_s.modificatore, roll_s.totale])
			print("   Esito: %s | Costo Tempo-Figlia: -%.1fh | Effetto Sabbia-Padre: %+.1fh" % [
				"SUCCESSO" if r.successo else "FALLIMENTO", r.costo_tempo_figlia_ore, r.effetto_sabbia_padre_ore
			])
			print("")
			_gestisci_evento_casuale(stato, r.get("evento_casuale"))
			continue

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
			_gestisci_evento_casuale(stato, r.get("evento_casuale"))
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
		_gestisci_evento_casuale(stato, risultato.get("evento_casuale"))

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
	print("")
	print(Narrativa.epilogo(stato.donation_made, stato.tempo_figlia_ore > 0.0, stato.sabbia_padre_ore > 0.0, stato.karma))
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
	print("Attenzione Polizia: %.0f/100 | Rivalità Criminale: %.0f/100 | Fama Pubblica: %.0f/100 | Karma (persistente): %.0f" % [
		stato.attenzione_polizia, stato.rivalita_criminale, stato.fama_pubblica, stato.karma
	])
	print("Fede del Culto: %.0f/100 | Fede della Setta: %.0f/100" % [stato.fede_culto, stato.fede_setta])
	print("--------------------------------------------------")


## Fase 10: stampa e risolve un evento casuale (o Patto con lo Stregatto)
## restituito da _avanza_turno() dentro `evento_info` — chiamata dopo OGNI
## turno risolto (azione, traccia, sottotrama, cash-in). Se propone il
## patto, blocca il loop testuale finché il giocatore non risponde: la
## logica di gioco stessa rifiuta ogni altra azione mentre
## `patto_in_sospeso` non è vuoto (vedi GameState._patto_in_sospeso_blocca).
func _gestisci_evento_casuale(stato: GameState, evento) -> void:
	if evento == null or evento.is_empty():
		return
	if evento.tipo == "patto_stregatto_proposto":
		print("")
		print("*** EVENTO RARO ***")
		print(evento.testo)
		print("Prezzo: %.1fh di Sabbia-Padre (metà di quella posseduta ora) in cambio di Karma +30." % evento.prezzo_ore)
		while true:
			print("Accetti il patto? (si/no) > ")
			var risposta := OS.read_string_from_stdin().strip_edges().to_lower()
			if risposta == "si" or risposta == "s":
				var r := stato.risolvi_patto_stregatto(true)
				print(Narrativa.patto_accettato(r.prezzo_ore, r.karma_ottenuto, stato.karma))
				break
			elif risposta == "no" or risposta == "n":
				stato.risolvi_patto_stregatto(false)
				print(Narrativa.patto_rifiutato())
				break
			else:
				print("Rispondi 'si' o 'no'.")
		print("")
		return

	print("")
	print("*** EVENTO CASUALE *** -> %s" % evento.azione)
	print("   Esito: %s | Effetto Sabbia-Padre: %+.1fh" % [
		"SUCCESSO" if evento.successo else "FALLIMENTO", evento.effetto_sabbia_padre_ore
	])
	print("")


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
		elif stato.azioni_uniche_usate.has("%s|%d" % [t.traccia, t.rango]):
			etichetta = " [FALLITA - non più tentabile]"
		elif stato.traccia_bloccata_da_fede(t):
			var chiave_fede: String = GameState.FEDE_TRACCE[t.traccia]
			etichetta = " [richiede Fede %s >= %.0f, attuale %.0f]" % [chiave_fede, GameState.FEDE_SOGLIA_RANGO2, stato._fede(chiave_fede)]
		elif not stato.traccia_disponibile(t):
			etichetta = " [richiede rango precedente]"
		print("  %2d) %s Rango %d - %-40s costo=%5.1fh  effetto=%+9.1fh  rischio=%3d%%%s" % [
			offset + i + 1, t.traccia, t.rango, t.nome_rango, t.costo_tempo_figlia_ore, t.effetto_sabbia_padre_ore, roundi(t.rischio_pct * 100), etichetta
		])


func _stampa_sottotrame(sottotrame: Array[SubplotData], stato: GameState, offset: int) -> void:
	print("[SOTTOTRAME]")
	for i in sottotrame.size():
		var s := sottotrame[i]
		var etichetta := ""
		if stato.azioni_uniche_usate.has("sottotrama:%s" % s.nome):
			etichetta = " [già tentata]"
		elif s.prerequisito != "" and not stato.azione_completata_con_successo(s.prerequisito):
			etichetta = " [richiede: %s]" % s.prerequisito
		print("  %2d) %-45s costo=%5.1fh  effetto=%+10.1fh  rischio=%3d%%%s" % [
			offset + i + 1, s.nome, s.costo_tempo_figlia_ore, s.effetto_sabbia_padre_ore, roundi(s.rischio_pct * 100), etichetta
		])


func _stampa_sinergia(stato: GameState) -> void:
	var combo: Array = stato.combo_tracce()
	if combo.is_empty():
		return
	print("[SINERGIA]")
	if stato.cash_in_disponibile():
		var moltiplicatore: float = GameState.SINERGIA_MOLTIPLICATORI.get(combo.size(), GameState.SINERGIA_MOLTIPLICATORI[4])
		print("  Combo attiva su %d tracce (%s) — 'cashin' disponibile, moltiplicatore x%.0f, rischio %d%%." % [
			combo.size(), ", ".join(combo), moltiplicatore, roundi(GameState.CASH_IN_RISCHIO_PCT * 100)
		])
	else:
		print("  Cash-in già tentato in questa run.")
	var malus: Array = stato.malus_attivi()
	if not malus.is_empty():
		var parti: Array[String] = []
		for coppia in malus:
			parti.append("%s + %s" % [coppia[0], coppia[1]])
		print("  Tensione tematica attiva: %s" % ", ".join(parti))


## Design doc 12.2, scheletro tecnico (Batch tecnico): mostra i bivi ancora
## risolvibili in questa run. Tutti i bivi qui sono SEGNAPOSTO (vedi
## BivioSystem) — nessun contenuto narrativo reale.
func _stampa_bivi(stato: GameState) -> void:
	print("[BIVI — scheletro tecnico, contenuto segnaposto]")
	for bivio in BivioSystem.get_bivi_segnaposto():
		if not stato.bivio_disponibile(bivio.id):
			var scelta: BivioSystem.Opzione = bivio.opzioni[stato.opzione_scelta(bivio.id)]
			print("  %s [RISOLTO: %s]" % [bivio.id, scelta.nome])
			continue
		print("  %s — %s" % [bivio.id, bivio.trigger])
		for i in bivio.opzioni.size():
			print("    %d) %s" % [i, bivio.opzioni[i].nome])
