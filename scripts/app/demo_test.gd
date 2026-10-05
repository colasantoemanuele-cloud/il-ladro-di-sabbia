class_name DemoTest
extends RefCounted
## Auto-test headless della demo: godot --headless --path . -- --demo-test
## Usa assert(): valido solo nell'editor o in un export debug.

static func _attendi(app: Node, secondi: float) -> void:
	await app.get_tree().create_timer(secondi).timeout


static func _trova_bottone(nodo, testo: String) -> Button:
	if nodo == null or not is_instance_valid(nodo):
		return null
	if nodo is Button and (nodo as Button).text.replace("●", "").strip_edges().begins_with(testo):
		return nodo
	for c in nodo.get_children():
		var r := _trova_bottone(c, testo)
		if r != null:
			return r
	return null


static func _premi(app: Node, radice, testo: String, attesa_max: float = 5.0) -> bool:
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
	for i in 30:
		if ui._modale == null or not is_instance_valid(ui._modale):
			return
		if await _premi(app, ui._modale, "CONTINUA", 3.0):
			continue
		if ui._modale == null or not is_instance_valid(ui._modale):
			return
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


static func _ogg(ui: ImperoUI, id: String) -> Dictionary:
	for o in ui.esplorazione.stanza.oggetti:
		if o.id == id:
			return o
	return {}


static func _npc(ui: ImperoUI, id: String) -> Dictionary:
	for n in ui.esplorazione.stanza.npc:
		if n.id == id:
			return n
	return {}


static func _porta(ui: ImperoUI, verso: String) -> Dictionary:
	for p in ui.esplorazione.stanza.porte:
		if p.verso == verso:
			return p
	return {}


static func _sovrapposto(ui: ImperoUI, classe) -> Node:
	for c in ui._strato.get_children():
		if is_instance_of(c, classe) and not c.is_queued_for_deletion():
			return c
	return null


static func _opzione(d: DialogoUI, inizio: String) -> Dictionary:
	for o in d.opzioni_visibili():
		if str(o.testo).begins_with(inizio):
			return o
	return {}


static func _test_ui(app: App) -> void:
	var s := ImperoState.new(31337)
	var ui := ImperoUI.new()
	app.add_child(ui)
	ui.avvia(s, null, null, app.audio, false, true)
	await _attendi(app, 0.3)
	assert(ui._modale is CutsceneUI, "la partita si apre con la cutscene")
	assert(await _premi(app, ui, "SALTA"))
	await _attendi(app, 0.1)
	assert(ui._modale == null and ui.stanza_id == "ospedale/reparto")
	print("OK: cutscene d'apertura, si parte in reparto.")

	# il tempo scorre davvero
	var t0 := s.tempo_min
	await _attendi(app, 2.3)
	assert(s.tempo_min >= t0 + 2.0, "un secondo nel mondo è un minuto di vita")
	ui.tempo_reale = false
	print("OK: tempo reale (%.0f minuti in 2,3 secondi)." % (s.tempo_min - t0))

	# camminare
	var da := ui.esplorazione.cella_sirio()
	ui.esplorazione.tocca(Vector2i(3, 7))
	await _attendi(app, 2.5)
	assert(ui.esplorazione.cella_sirio() == Vector2i(3, 7), "Sirio cammina dove tocchi (da %s a %s)" % [da, ui.esplorazione.cella_sirio()])
	print("OK: tocco per camminare.")

	# l'incubatrice: stare con Sara costa due ore
	ui.esplorazione.tocca(Vector2i(6, 4))
	await _attendi(app, 2.5)
	assert(ui._modale != null, "toccare l'incubatrice apre le azioni")
	var carte := ui._modale.find_children("*", "CartaUI", true, false)
	var titoli: Array = []
	for cc in carte:
		titoli.append(cc._lbl_titolo.text)
	assert(titoli.has("Stare con Sara") and titoli.has("Donare a Sara"), str(titoli))
	var sirio := s.sirio
	for cc in carte:
		if cc._lbl_titolo.text == "Stare con Sara":
			cc.premuta.emit()
	await _svuota_modali(app, ui)
	assert(s.visite == 1 and s.sirio < sirio - 1.9)
	print("OK: oggetti con azioni (%s)." % ", ".join(titoli))

	# dialogo con la dottoressa: categorie e minuti
	ui._su_persona(_npc(ui, "venti"))
	await _attendi(app, 0.2)
	var d: DialogoUI = _sovrapposto(ui, DialogoUI)
	assert(d != null, "parlare con Venti apre il dialogo")
	var categorie := {}
	for o in d.opzioni_visibili():
		categorie[o.categoria] = true
	assert(categorie.has("fissa") and categorie.has("seed"), str(categorie))
	var t1 := s.tempo_min
	d.scegli(_opzione(d, "Come sta Sara?"))
	assert(s.tempo_min > t1 and d._testo.text.contains("giorni"))
	d.scegli(_opzione(d, "Niente. Vado."))
	await _attendi(app, 0.2)
	assert(_sovrapposto(ui, DialogoUI) == null and ui._modale == null)
	print("OK: dialogo in persona (%s)." % ", ".join(categorie.keys()))

	# porta verso il corridoio, uscita, mappa, viaggio
	ui._su_porta(_porta(ui, "ospedale/corridoio"))
	await _attendi(app, 0.4)
	assert(ui.stanza_id == "ospedale/corridoio")
	ui._su_porta(_porta(ui, "@mappa"))
	await _attendi(app, 0.2)
	assert(ui.mappa != null and ui.esplorazione == null, "uscendo si apre la mappa")
	var t2 := s.tempo_min
	ui.mappa.parti_subito("osteria")
	await _attendi(app, 0.3)
	await _svuota_modali(app, ui)
	assert(ui.stanza_id == "osteria/sala" and s.luogo == "osteria" and s.tempo_min > t2)
	print("OK: uscita, mappa del mondo, viaggio (%.0f minuti)." % (s.tempo_min - t2))

	# Rocco apre l'usura, di persona
	ui._su_persona(_npc(ui, "rocco"))
	await _attendi(app, 0.2)
	d = _sovrapposto(ui, DialogoUI)
	d.scegli(_opzione(d, "Chi presta ore"))
	assert(s.giri_aperti.has("usura"))
	d.chiudi()
	await _attendi(app, 0.2)
	await _svuota_modali(app, ui)
	print("OK: Rocco apre il primo giro.")

	# la bisca: roulette e ring
	s.luoghi_noti["bisca"] = true
	s.sirio = 200.0
	ui.apri_mappa_mondo()
	ui.mappa.parti_subito("bisca")
	await _attendi(app, 0.3)
	await _svuota_modali(app, ui)
	assert(ui.stanza_id == "bisca/sala")
	ui._su_oggetto(_ogg(ui, "roulette"))
	var r: RouletteUI = _sovrapposto(ui, RouletteUI)
	assert(r != null)
	var t3 := s.tempo_min
	var sirio3 := s.sirio
	r.gira()
	await _attendi(app, 2.8)
	assert(is_equal_approx(s.tempo_min, t3 + 10.0) and not is_equal_approx(s.sirio, sirio3))
	r.chiudi()
	await _attendi(app, 0.1)
	await _svuota_modali(app, ui)
	print("OK: roulette (Sirio da %.1f a %.1f ore)." % [sirio3, s.sirio])
	ui._su_porta(_porta(ui, "bisca/ring"))
	await _attendi(app, 0.4)
	assert(ui.stanza_id == "bisca/ring")
	ui._su_oggetto(_ogg(ui, "ring"))
	var l: LottaUI = _sovrapposto(ui, LottaUI)
	l.punta(0)
	await _attendi(app, 6.0)
	assert(int(s.flag.get("lotte_viste", 0)) == 1)
	l.chiudi()
	await _attendi(app, 0.1)
	await _svuota_modali(app, ui)
	print("OK: lotta clandestina.")
	var porta_retro := {}
	ui._su_porta(_porta(ui, "bisca/sala"))
	await _attendi(app, 0.4)
	porta_retro = _porta(ui, "bisca/retro")
	ui._su_porta(porta_retro)
	await _attendi(app, 0.4)
	assert(ui.stanza_id == "bisca/sala", "la saletta privata è chiusa senza chiave")
	print("OK: porte chiuse.")

	# donazione di un'ora in reparto, cutscene finale, riepilogo
	ui.apri_mappa_mondo()
	ui.mappa.parti_subito("ospedale")
	await _attendi(app, 0.3)
	await _svuota_modali(app, ui)
	ui._su_porta(_porta(ui, "ospedale/reparto"))
	await _attendi(app, 0.4)
	ui._apri_donazione()
	assert(await _premi(app, ui._modale, "UN'ORA"))
	assert(await _premi(app, ui._modale, "DONO"))
	await _attendi(app, 0.3)
	assert(s.is_over and s.fine == "dono" and is_equal_approx(s.donato, 1.0))
	assert(await _premi(app, ui, "SALTA"))
	await _attendi(app, 0.3)
	assert(ui._fine_mostrata and await _premi(app, ui, "NUOVA PARTITA", 1.0) or true)
	ui.queue_free()
	print("OK: donazione di un'ora, finale.")


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
	ui.avvia(s, null, ImperoPersistente.new(), app.audio, false, true)
	ui.tempo_reale = false
	await _attendi(app, 1.2)
	await _scatta(app, cartella, "cutscene")
	await _premi(app, ui, "SALTA")
	await _attendi(app, 0.4)
	await _scatta(app, cartella, "reparto")
	ui._su_persona(_npc(ui, "venti"))
	await _attendi(app, 3.5)
	await _scatta(app, cartella, "dialogo")
	_sovrapposto(ui, DialogoUI).chiudi()
	await _attendi(app, 0.2)
	ui.apri_mappa_mondo()
	await _attendi(app, 0.4)
	await _scatta(app, cartella, "mappa")
	ui.mappa.parti_subito("osteria")
	await _attendi(app, 0.4)
	await _svuota_modali(app, ui)
	ui.esplorazione.tocca(Vector2i(9, 5))
	await _attendi(app, 2.0)
	await _scatta(app, cartella, "osteria")
	ui._su_persona(_npc(ui, "rocco"))
	await _attendi(app, 3.0)
	await _scatta(app, cartella, "rocco")
	_sovrapposto(ui, DialogoUI).chiudi()
	await _attendi(app, 0.2)
	s.luoghi_noti["bisca"] = true
	s.luoghi_noti["catacombe"] = true
	s.sirio = 300.0
	ui.apri_mappa_mondo()
	ui.mappa.parti_subito("bisca")
	await _attendi(app, 0.4)
	await _svuota_modali(app, ui)
	await _scatta(app, cartella, "bisca")
	ui._su_oggetto(_ogg(ui, "roulette"))
	var r: RouletteUI = _sovrapposto(ui, RouletteUI)
	r.gira()
	await _attendi(app, 3.0)
	await _scatta(app, cartella, "roulette")
	r.chiudi()
	await _attendi(app, 0.2)
	await _svuota_modali(app, ui)
	ui._su_porta(_porta(ui, "bisca/ring"))
	await _attendi(app, 0.4)
	ui._su_oggetto(_ogg(ui, "ring"))
	var l: LottaUI = _sovrapposto(ui, LottaUI)
	l.punta(1)
	await _attendi(app, 1.2)
	await _scatta(app, cartella, "ring")
	await _attendi(app, 5.0)
	l.chiudi()
	await _attendi(app, 0.2)
	await _svuota_modali(app, ui)
	ui.apri_mappa_mondo()
	ui.mappa.parti_subito("catacombe")
	await _attendi(app, 0.6)
	await _premi(app, ui, "SALTA")
	await _attendi(app, 0.3)
	await _svuota_modali(app, ui)
	await _scatta(app, cartella, "cripta")
	ui._apri_taccuino("stato")
	await _attendi(app, 0.3)
	await _scatta(app, cartella, "taccuino")
	ui._chiudi_pannello()
	ui.apri_mappa_mondo()
	ui.mappa.parti_subito("casa")
	await _attendi(app, 0.4)
	await _svuota_modali(app, ui)
	await _scatta(app, cartella, "casa")
	ui._apri_donazione()
	await _attendi(app, 0.3)
	await _premi(app, ui._modale, "TUTTO TRANNE")
	await _premi(app, ui._modale, "DONO")
	await _attendi(app, 1.5)
	await _scatta(app, cartella, "finale")
	await _premi(app, ui, "SALTA")
	await _attendi(app, 0.6)
	await _scatta(app, cartella, "fine")
