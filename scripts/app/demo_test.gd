class_name DemoTest
extends RefCounted
## Auto-test headless della demo: godot --headless --path . -- --demo-test
## Usa assert(): valido solo nell'editor o in un export debug.

const PERCORSO_TEST := "user://mondo_persistente_test.json"


static func _attendi(app: Node, secondi: float) -> void:
	await app.get_tree().create_timer(secondi).timeout


static func _trova_bottone(nodo: Node, testo: String) -> Button:
	if nodo == null:
		return null
	if nodo is Button and (nodo as Button).text.replace("●", "").strip_edges().begins_with(testo):
		return nodo
	for c in nodo.get_children():
		var r := _trova_bottone(c, testo)
		if r != null:
			return r
	return null


static func _premi(app: Node, radice: Node, testo: String, attesa_max: float = 5.0) -> bool:
	var t := 0.0
	while t < attesa_max:
		var b := _trova_bottone(radice, testo)
		if b != null and not b.disabled and b.is_visible_in_tree():
			b.pressed.emit()
			await _attendi(app, 0.05)
			return true
		await _attendi(app, 0.1)
		t += 0.1
	return false


## Chiude tutti i modali aperti (dadi, eventi, occasioni) scegliendo sempre la
## prima risposta possibile.
static func _svuota_modali(app: Node, ui: MondoUI) -> void:
	for i in 20:
		if ui._modale == null:
			return
		if await _premi(app, ui._modale, "CONTINUA", 3.0):
			continue
		var bottoni := ui._modale.find_children("*", "Button", true, false)
		if bottoni.is_empty():
			await _attendi(app, 0.3)
			continue
		(bottoni[0] as Button).pressed.emit()
		await _attendi(app, 0.1)


static func esegui(app: App) -> void:
	print("=== TEST DEMO ===")
	_test_testi()
	_test_mondo()
	await _test_audio(app)
	await _test_titolo(app)
	await _test_ui(app)
	print("TUTTI I TEST DEMO OK")


static func _test_testi() -> void:
	for a: ActionData in ActionDatabase.get_all():
		assert(TestiDemo.esito_azione(a.nome, true) != "Fatto.", "esito mancante: " + a.nome)
		assert(TestiDemo.esito_azione(a.nome, false) != "Non è andata.", "esito mancante: " + a.nome)
	var parole := TestiDemo.INTRO.split(" ", false).size()
	assert(parole <= 120, "intro oltre 120 parole")
	for t in TestiDemo.TUTORIAL:
		assert(str(t.testo).split(" ", false).size() <= 60, "tutorial oltre 60 parole: " + str(t.titolo))
	assert(TestiDemo.CITAZIONI.size() == 8)
	assert(MondoRun.dati().luoghi.size() >= 20 and MondoRun.dati().contatti.size() >= 10)
	print("OK: testi e dati del mondo.")


static func _test_mondo() -> void:
	var m := MondoRun.new(GameState.new(31337))
	assert(m.luogo == "ospedale")
	assert(not m.luoghi_noti.has("bisca"), "la bisca si scopre, non è nota all'inizio")
	assert(m.contatti_noti.has("gaetano") and m.contatti_noti.has("rocco") and not m.contatti_noti.has("shen"))

	# il viaggio costa le stesse ore a padre e figlia
	var p0 := m.stato.sabbia_padre_ore
	var f0 := m.stato.tempo_figlia_ore
	var v := m.viaggia("porto")
	assert(not v.has("rifiutata"))
	assert(is_equal_approx(f0 - m.stato.tempo_figlia_ore, p0 - m.stato.sabbia_padre_ore), "il viaggio deve costare uguale a entrambi")
	assert(m.viaggia("porto").has("rifiutata"), "non si va dove si è già")
	assert(m.viaggia("bisca").has("rifiutata"), "non si va in un posto che non si conosce")
	print("OK: viaggio (%.2fh) costa uguale a Sirio e a Sara." % v.ore)

	# solo le azioni del luogo
	assert(m.esegui_azione("Piccolo furto (scippo)").has("rifiutata"), "lo scippo non si fa al porto")
	var p1 := m.stato.sabbia_padre_ore
	var r := m.esegui_azione("Turno di lavoro onesto (8h, salario mediano)")
	assert(not r.has("rifiutata"))
	var rr: Dictionary = r.risultati[0].r
	var atteso: float = p1 - rr.costo_tempo_figlia_ore + rr.effetto_sabbia_padre_ore
	assert(absf(m.stato.sabbia_padre_ore - atteso) < 0.001, "il padre paga le ore del turno e incassa la paga")
	print("OK: il turno costa %.1fh anche a Sirio, rende %.1fh." % [rr.costo_tempo_figlia_ore, rr.effetto_sabbia_padre_ore])

	# fame e sonno
	m.ore_sveglio = 40.0
	m.ore_digiuno = 0.0
	assert(m.malus_bisogni().modificatore == -2)
	m.ore_digiuno = 80.0
	assert(m.malus_bisogni().modo == DiceSystem.RollMode.SVANTAGGIO)
	assert(m.malus_bisogni().modificatore == -4, "malus massimo -4")
	m.ore_sveglio = 0.0
	m.ore_digiuno = 0.0
	assert(m.malus_bisogni().modificatore == 0)
	print("OK: fame e sonno.")

	# telefono: le strade si aprono solo con i meriti
	var ha_lavoro1 := false
	for o in m.opzioni_contatto("gaetano"):
		if o.id == "lavoro1":
			ha_lavoro1 = true
	assert(ha_lavoro1 == bool(rr.successo), "Gaetano offre il posto solo dopo un turno riuscito")
	var esito := m.scegli_opzione("rocco", "bisca")
	assert(m.luoghi_noti.has("bisca") and not esito.notifiche.is_empty())
	for o in m.opzioni_contatto("rocco"):
		assert(o.id != "bisca", "un'opzione una tantum sparisce dopo l'uso")
	print("OK: telefono, sblocchi e strade su merito.")

	# donazione: anche un'ora, ma solo in ospedale
	assert(not m.dona(1.0).get("successo", false), "si dona in ospedale")
	m.viaggia("ospedale")
	if not m.stato.is_over:
		var d := m.dona(1.0)
		assert(d.successo and m.stato.is_over and is_equal_approx(m.stato.donated_ore, 1.0))
	print("OK: donazione di un'ora.")

	# obiettivi persistenti
	var pers := MondoPersistente.new()
	var note := m.valuta_obiettivi(pers)
	assert(pers.contatti.has("anselmo") and not note.is_empty(), "donare sblocca Padre Anselmo per le prossime run")
	pers.salva(PERCORSO_TEST)
	var ricaricato := MondoPersistente.carica(PERCORSO_TEST)
	assert(ricaricato.contatti.has("anselmo") and ricaricato.run_giocate == 1)
	var m2 := MondoRun.new(GameState.new(1), ricaricato)
	assert(m2.contatti_noti.has("anselmo"), "il contatto sbloccato c'è nella run successiva")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PERCORSO_TEST))
	print("OK: sblocchi permanenti tra una run e l'altra.")

	# orologio del mondo
	var m3 := MondoRun.new(GameState.new(5))
	assert(m3.ora_testo() == "Lunedì 23:00")
	m3._passa_tempo(2.0)
	assert(m3.ora_testo() == "Martedì 01:00" and m3.giorno() == 2 and m3.messaggi_non_letti() == 1)
	print("OK: orologio e messaggi del giorno.")


static func _test_audio(app: App) -> void:
	var t0 := Time.get_ticks_msec()
	while not app.audio.brano_disponibile("titolo") and Time.get_ticks_msec() - t0 < 20000:
		await _attendi(app, 0.2)
	assert(app.audio.brano_disponibile("titolo") and app.audio.brano_disponibile("click"))
	print("OK: audio.")


static func _test_titolo(app: App) -> void:
	var titolo := TitleScreen.new()
	app.add_child(titolo)
	titolo.avvia(PlayerProfile.new(), ImpostazioniDemo.new(), app.audio)
	var ricevuto := [-2, false]
	titolo.nuova_partita.connect(func(s, g):
		ricevuto[0] = s
		ricevuto[1] = g)
	await _attendi(app, 0.1)
	assert(await _premi(app, titolo, "NUOVA PARTITA"))
	var campo: LineEdit = titolo._overlay.find_children("*", "LineEdit", true, false)[0]
	campo.text = "4242"
	campo.text_changed.emit("4242")
	assert(await _premi(app, titolo, "GIOCA"))
	assert(ricevuto[0] == 4242 and ricevuto[1] == false, "il seed scritto a mano arriva alla partita")
	titolo.queue_free()
	print("OK: scelta del seed.")


static func _test_ui(app: App) -> void:
	var mondo := MondoRun.new(GameState.new(31337))
	var ui := MondoUI.new()
	app.add_child(ui)
	ui.avvia(mondo, null, null, app.audio, false)
	await _attendi(app, 0.2)
	assert(ui._modale != null, "il bivio iniziale deve comparire")
	assert(await _premi(app, ui._modale, "A PASSI PICCOLI"))
	assert(ui._modale == null)
	# in ospedale si vede solo cio che si fa in ospedale
	var testi: Array = []
	for c in ui._griglia.get_children():
		if c is CartaUI and not c.is_queued_for_deletion():
			testi.append(c._lbl_titolo.text)
	assert(testi.has("Visitare la figlia in ospedale") and testi.has("Donare a Sara"), "carte dell'ospedale: %s" % str(testi))
	assert(not testi.has("Turno di lavoro onesto (8h, salario mediano)"), "il lavoro non si fa in ospedale")
	print("OK: carte contestuali (%s)." % ", ".join(testi))

	# visita a Sara: dado e diario
	var turno := mondo.stato.turno
	for c in ui._griglia.get_children():
		if c is CartaUI and c._lbl_titolo.text == "Visitare la figlia in ospedale":
			c.premuta.emit()
	await _svuota_modali(app, ui)
	assert(mondo.stato.turno == turno + 1)

	# telefono: Rocco indica la bisca
	ui._apri_telefono()
	await _attendi(app, 0.1)
	assert(await _premi(app, ui._pannello, "Rocco Ferrante"))
	assert(await _premi(app, ui._pannello, "Dove si gioca forte?"))
	await _svuota_modali(app, ui)
	assert(mondo.luoghi_noti.has("bisca"))
	ui._chiudi_pannello()
	print("OK: telefono.")

	# mappa e viaggio
	ui._apri_mappa()
	await _attendi(app, 0.2)
	ui._viaggia("piazza")
	await _attendi(app, 1.2)
	await _svuota_modali(app, ui)
	assert(mondo.luogo == "piazza" or mondo.stato.is_over)
	print("OK: viaggio dalla mappa.")

	# ritorno in ospedale e donazione di un'ora
	if not mondo.stato.is_over:
		ui._viaggia("ospedale")
		await _attendi(app, 1.2)
		await _svuota_modali(app, ui)
	if not mondo.stato.is_over:
		ui._apri_donazione()
		await _attendi(app, 0.1)
		assert(await _premi(app, ui._modale, "UN'ORA"))
		assert(await _premi(app, ui._modale, "DONO"))
		await _attendi(app, 0.3)
		assert(mondo.stato.donation_made and is_equal_approx(mondo.stato.donated_ore, 1.0))
	await _attendi(app, 0.3)
	assert(ui._fine_mostrata, "la schermata finale deve comparire")
	ui.queue_free()
	print("OK: donazione di un'ora e fine.")


static func _scatta(app: Node, cartella: String, nome: String) -> void:
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	app.get_viewport().get_texture().get_image().save_png("%s/shot_%s.png" % [cartella, nome])


static func foto(app: App, cartella: String) -> void:
	var t := TitleScreen.new()
	app.add_child(t)
	t.avvia(PlayerProfile.new(), ImpostazioniDemo.new(), app.audio)
	await _attendi(app, 0.5)
	await _scatta(app, cartella, "titolo")
	t._apri_nuova_partita()
	await _attendi(app, 0.2)
	await _scatta(app, cartella, "nuova_partita")
	t.queue_free()
	var mondo := MondoRun.new(GameState.new(31337))
	var ui := MondoUI.new()
	app.add_child(ui)
	ui.avvia(mondo, null, MondoPersistente.new(), app.audio, false)
	await _attendi(app, 0.4)
	await _scatta(app, cartella, "bivio")
	await _premi(app, ui._modale, "A PASSI PICCOLI")
	await _attendi(app, 0.3)
	await _scatta(app, cartella, "ospedale")
	mondo.scegli_opzione("rocco", "bisca")
	mondo.viaggia("porto")
	ui._aggiorna()
	await _attendi(app, 0.3)
	await _scatta(app, cartella, "porto")
	for c in ui._griglia.get_children():
		if c is CartaUI and c._lbl_titolo.text.begins_with("Turno di lavoro onesto"):
			c.premuta.emit()
	await _attendi(app, 2.0)
	await _scatta(app, cartella, "dado")
	await _svuota_modali(app, ui)
	ui._apri_telefono()
	await _attendi(app, 0.2)
	await _premi(app, ui._pannello, "Gaetano Ruggiero")
	await _attendi(app, 0.3)
	await _scatta(app, cartella, "telefono")
	ui._chiudi_pannello()
	ui._apri_mappa()
	await _attendi(app, 0.4)
	await _scatta(app, cartella, "mappa")
	ui._chiudi_pannello()
	ui._apri_taccuino("stato")
	await _attendi(app, 0.3)
	await _scatta(app, cartella, "taccuino")
	ui._chiudi_pannello()
	mondo.viaggia("ospedale")
	ui._aggiorna()
	ui._apri_donazione()
	await _attendi(app, 0.3)
	await _scatta(app, cartella, "donazione")
	await _premi(app, ui._modale, "UN'ORA")
	await _premi(app, ui._modale, "DONO")
	await _attendi(app, 0.6)
	await _scatta(app, cartella, "fine")
