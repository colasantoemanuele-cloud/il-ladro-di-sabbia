class_name DemoTest
extends RefCounted
## Auto-test headless della demo: godot --headless --path . -- --demo-test
## Usa assert(): valido solo nell'editor o in un export debug.

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
static func _svuota_modali(app: Node, ui: ImperoUI) -> void:
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
	await _test_audio(app)
	await _test_titolo(app)
	await _test_ui(app)
	print("TUTTI I TEST DEMO OK")


static func _test_testi() -> void:
	var parole := TestiDemo.INTRO.split(" ", false).size()
	assert(parole <= 120, "intro oltre 120 parole")
	for t in TestiDemo.TUTORIAL:
		assert(str(t.testo).split(" ", false).size() <= 60, "tutorial oltre 60 parole: " + str(t.titolo))
	assert(TestiDemo.CITAZIONI.size() == 8)
	for testo in [TestiDemo.INTRO] + TestiDemo.CITAZIONI:
		assert(not str(testo).contains("—"), "trattino lungo")
	print("OK: testi.")


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


static func _titoli_carte(ui: ImperoUI) -> Array:
	var testi: Array = []
	for c in ui._griglia.get_children():
		if c is CartaUI and not c.is_queued_for_deletion():
			testi.append(c._lbl_titolo.text)
	return testi


static func _premi_carta(ui: ImperoUI, titolo: String) -> bool:
	for c in ui._griglia.get_children():
		if c is CartaUI and not c.is_queued_for_deletion() and c._lbl_titolo.text == titolo:
			c.premuta.emit()
			return true
	return false


static func _test_ui(app: App) -> void:
	var s := ImperoState.new(31337)
	var ui := ImperoUI.new()
	app.add_child(ui)
	ui.avvia(s, null, null, app.audio, false)
	await _attendi(app, 0.2)
	assert(ui._modale == null)
	var testi := _titoli_carte(ui)
	assert(testi.has("Stare con Sara") and testi.has("Donare a Sara"), "carte dell'ospedale: %s" % str(testi))
	assert(not testi.has("Turno al porto"), "il lavoro non si fa in ospedale")
	print("OK: carte contestuali (%s)." % ", ".join(testi))

	# una fascia passa: costa sei ore a entrambi
	var sirio := s.sirio
	assert(_premi_carta(ui, "Stare con Sara"))
	await _svuota_modali(app, ui)
	assert(s.fascia == 1 and is_equal_approx(s.sirio, sirio - 6.0))
	print("OK: una fascia costa sei ore a Sirio e a Sara.")

	# telefono: Rocco apre l'usura
	ui._apri_telefono()
	await _attendi(app, 0.1)
	assert(await _premi(app, ui._pannello, "Rocco Ferrante"))
	assert(await _premi(app, ui._pannello, "Chi presta ore"))
	assert(s.giri_aperti.has("usura") and s.luoghi_noti.has("bottega_nando"))
	assert(s.fascia == 1, "il telefono non occupa la fascia")
	ui._chiudi_pannello()
	print("OK: telefono.")

	# mappa: guardare un luogo è gratis, agire lì fa viaggiare
	ui._apri_mappa()
	await _attendi(app, 0.2)
	ui.guarda("bottega_nando")
	assert(s.luogo == "ospedale" and ui.vista == "bottega_nando")
	assert(_titoli_carte(ui).has("Prestare a nuovi disperati"), "carte della bottega: %s" % str(_titoli_carte(ui)))
	assert(_premi_carta(ui, "Prestare a nuovi disperati"))
	await _svuota_modali(app, ui)
	assert(s.luogo == "bottega_nando" and s.fascia == 2)
	print("OK: mappa e primo giro (%d debitori)." % int(s.giri.usura.persone))

	# pannello impero
	ui._apri_impero()
	await _attendi(app, 0.1)
	assert(ui._pannello != null)
	ui._chiudi_pannello()

	# donazione di un'ora dall'ospedale
	ui.guarda("ospedale")
	assert(_premi_carta(ui, "Donare a Sara"))
	await _attendi(app, 0.1)
	assert(await _premi(app, ui._modale, "UN'ORA"))
	assert(await _premi(app, ui._modale, "DONO"))
	await _attendi(app, 0.3)
	assert(s.is_over and s.fine == "dono" and is_equal_approx(s.donato, 1.0))
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
	t.queue_free()
	var s := ImperoState.new(1000)
	var ui := ImperoUI.new()
	app.add_child(ui)
	ui.avvia(s, null, ImperoPersistente.new(), app.audio, false)
	await _attendi(app, 0.4)
	await _scatta(app, cartella, "ospedale")
	for i in 44:
		ImperoBot.passo(s, ImperoBot.STRATEGIE.usuraio, false)
	ui.vista = "bottega_nando"
	ui._aggiorna()
	await _attendi(app, 0.3)
	await _scatta(app, cartella, "bottega")
	if not s.is_over:
		s.sirio = maxf(s.sirio, 200.0)
		ui.esegui("cresci:usura")
		await _attendi(app, 1.6)
		await _scatta(app, cartella, "dado")
		await _svuota_modali(app, ui)
	ui._apri_impero()
	await _attendi(app, 0.3)
	await _scatta(app, cartella, "impero")
	ui._chiudi_pannello()
	ui._apri_telefono()
	await _attendi(app, 0.2)
	await _premi(app, ui._pannello, "Rocco Ferrante")
	await _attendi(app, 0.3)
	await _scatta(app, cartella, "telefono")
	ui._chiudi_pannello()
	ui._apri_mappa()
	await _attendi(app, 0.4)
	await _scatta(app, cartella, "mappa")
	ui._chiudi_pannello()
	ui._apri_taccuino("mosse")
	await _attendi(app, 0.3)
	await _scatta(app, cartella, "taccuino")
	ui._chiudi_pannello()
	ui.guarda("ospedale")
	ui._apri_donazione()
	await _attendi(app, 0.3)
	await _scatta(app, cartella, "donazione")
	await _premi(app, ui._modale, "TUTTO TRANNE")
	await _premi(app, ui._modale, "DONO")
	await _attendi(app, 0.6)
	await _scatta(app, cartella, "fine")
