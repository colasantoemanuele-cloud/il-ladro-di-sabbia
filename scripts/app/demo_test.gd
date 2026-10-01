class_name DemoTest
extends RefCounted
## Auto-test headless della demo: godot --headless --path . -- --demo-test
## Usa assert(): valido solo nell'editor o in un export debug.


static func _attendi(app: Node, secondi: float) -> void:
	await app.get_tree().create_timer(secondi).timeout


static func _premi_continua(app: Node, ui: TouchUI) -> void:
	# attende la fine dell'animazione del dado e preme il bottone del modale
	for i in 60:
		await _attendi(app, 0.1)
		var b := _trova_bottone(ui._modale, "CONTINUA")
		if b != null and not b.disabled:
			b.pressed.emit()
			return
	assert(false, "il bottone CONTINUA non e' diventato attivo")


static func _trova_bottone(nodo: Node, testo: String) -> Button:
	if nodo == null:
		return null
	if nodo is Button and (nodo as Button).text.begins_with(testo):
		return nodo
	for c in nodo.get_children():
		var r := _trova_bottone(c, testo)
		if r != null:
			return r
	return null


static func esegui(app: App) -> void:
	print("=== TEST DEMO ===")

	# testi di esito: tutte le 62 azioni, le 7 tracce e le 10 sottotrame
	for a: ActionData in ActionDatabase.get_all():
		assert(TestiDemo.esito_azione(a.nome, true) != "Fatto.", "esito mancante (ok): " + a.nome)
		assert(TestiDemo.esito_azione(a.nome, false) != "Non è andata.", "esito mancante (ko): " + a.nome)
	for s: SubplotData in SubplotDatabase.get_all():
		assert(TestiDemo.esito_sottotrama(s.nome, true) != "Fatto.", "esito sottotrama mancante: " + s.nome)
	for t in TrackDatabase.get_nomi_tracce_normali():
		assert(TestiDemo.esito_traccia(t, "X", true) != "Un passo avanti.", "esito traccia mancante: " + t)
	assert(TestiDemo.CITAZIONI.size() == 8)
	var parole := TestiDemo.INTRO.split(" ", false).size()
	assert(parole <= 120, "intro oltre 120 parole: %d" % parole)
	print("OK: testi di esito completi, intro di %d parole." % parole)

	# pixel art
	for f in 6:
		assert(PixelArt.dado_frame(f, 7).get_width() == 32)
	assert(PixelArt.avatar_frame(3).get_height() == 48)
	assert(PixelArt.icona_app().get_width() == 192)
	print("OK: asset pixel art generati.")

	# audio
	var t0 := Time.get_ticks_msec()
	while not app.audio.brano_disponibile("titolo") and Time.get_ticks_msec() - t0 < 20000:
		await _attendi(app, 0.2)
	assert(app.audio.brano_disponibile("titolo"), "brano titolo non generato")
	assert(app.audio.brano_disponibile("click") and app.audio.brano_disponibile("vittoria"))
	print("OK: audio generato (%d ms)." % (Time.get_ticks_msec() - t0))

	# titolo
	var titolo := TitleScreen.new()
	app.add_child(titolo)
	titolo.avvia(PlayerProfile.new(), ImpostazioniDemo.new(), app.audio)
	await _attendi(app, 0.2)
	assert(_trova_bottone(titolo, "NUOVA PARTITA") != null)
	assert(_trova_bottone(titolo, "CARICA PROFILO") != null)
	titolo.queue_free()
	print("OK: schermata titolo.")

	# partita: bivio iniziale, azione col dado, traccia, donazione
	var stato := GameState.new(31337)
	var ui := TouchUI.new()
	app.add_child(ui)
	ui.avvia(stato, null, app.audio, false)
	await _attendi(app, 0.3)
	assert(ui._modale != null, "il bivio iniziale deve comparire")
	var scelta := _trova_bottone(ui._modale, "A PASSI PICCOLI")
	assert(scelta != null)
	scelta.pressed.emit()
	await _attendi(app, 0.1)
	assert(ui._modale == null)
	assert(stato.bivi_scelti.has(TestiDemo.BIVIO_INIZIO))
	assert(is_equal_approx(stato.karma, 4.0), "il bivio deve dare Karma +4")
	print("OK: bivio iniziale.")

	var lavoro := ActionDatabase.get_all()[0]
	var tempo_prima := stato.tempo_figlia_ore
	ui._su_azione(lavoro)
	assert(ui._modale != null, "il lancio del dado deve aprire il modale")
	await _premi_continua(app, ui)
	await _attendi(app, 0.1)
	assert(ui._modale == null)
	assert(stato.turno == 1 and stato.tempo_figlia_ore < tempo_prima)
	print("OK: azione con dado (tempo %.1f -> %.1f)." % [tempo_prima, stato.tempo_figlia_ore])

	var chiave := "Lavoro|1"
	ui._su_traccia(ui._righe_traccia[chiave])
	await _premi_continua(app, ui)
	await _attendi(app, 0.1)
	assert(stato.azioni_uniche_usate.has(chiave), "il tentativo di traccia deve bruciare la riga")
	# l'eventuale bivio di aggancio o un evento puo' aprire altri modali
	for i in 6:
		if ui._modale == null:
			break
		var b := _trova_bottone(ui._modale, "CONTINUA")
		if b != null and not b.disabled:
			b.pressed.emit()
		else:
			var opz := _trova_bottone(ui._modale, "DA SOLO")
			if opz != null:
				opz.pressed.emit()
		await _attendi(app, 1.6)
	print("OK: traccia.")

	ui._mostra_pagina("profilo")
	ui._aggiorna_profilo()
	assert(ui._slider_dono.max_value >= 1.0)
	ui._slider_dono.value = ui._slider_dono.max_value
	ui._su_dona()
	await _attendi(app, 0.1)
	_trova_bottone(ui._modale, "DONO").pressed.emit()
	await _attendi(app, 0.3)
	assert(stato.donation_made and stato.is_over, "la donazione deve concludere la run")
	assert(ui._fine_mostrata and _trova_bottone(ui._modale, "NUOVA PARTITA") != null)
	print("OK: donazione e schermata finale.")

	ui.queue_free()
	print("TUTTI I TEST DEMO OK")


static func _scatta(app: Node, cartella: String, nome: String) -> void:
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	var img := app.get_viewport().get_texture().get_image()
	img.save_png("%s/shot_%s.png" % [cartella, nome])


static func foto(app: App, cartella: String) -> void:
	var imp := ImpostazioniDemo.new()
	var t := TitleScreen.new()
	app.add_child(t)
	t.avvia(PlayerProfile.new(), imp, app.audio)
	await app.get_tree().create_timer(0.5).timeout
	await _scatta(app, cartella, "titolo")
	var prof := PlayerProfile.new()
	prof.traguardo_100_100_raggiunto = true
	t.queue_free()
	var t2 := TitleScreen.new()
	app.add_child(t2)
	t2.avvia(prof, imp, app.audio)
	t2._apri_profilo()
	await app.get_tree().create_timer(0.3).timeout
	await _scatta(app, cartella, "titolo_profilo")
	t2.queue_free()
	var intro := IntroScreen.new()
	app.add_child(intro)
	intro.avvia(app.audio)
	await app.get_tree().create_timer(3.0).timeout
	await _scatta(app, cartella, "intro")
	intro._fase = 1
	intro._mostra_fase()
	await app.get_tree().create_timer(2.5).timeout
	await _scatta(app, cartella, "tutorial")
	intro.queue_free()
	var stato := GameState.new(31337)
	var ui := TouchUI.new()
	app.add_child(ui)
	ui.avvia(stato, null, app.audio, false)
	await app.get_tree().create_timer(0.4).timeout
	await _scatta(app, cartella, "bivio")
	var b: Button = ui._modale.find_children("*", "Button", true, false)[0]
	b.pressed.emit()
	await app.get_tree().create_timer(0.3).timeout
	await _scatta(app, cartella, "azioni")
	ui._su_azione(ActionDatabase.get_all()[1])
	await app.get_tree().create_timer(0.35).timeout
	await _scatta(app, cartella, "dado_anim")
	await app.get_tree().create_timer(1.8).timeout
	await _scatta(app, cartella, "dado_fine")
	for bt in ui._modale.find_children("*", "Button", true, false):
		if bt.text.begins_with("CONTINUA"): bt.pressed.emit()
	await app.get_tree().create_timer(0.3).timeout
	ui._mostra_pagina("tracce")
	await app.get_tree().create_timer(0.2).timeout
	await _scatta(app, cartella, "tracce")
	ui._mostra_pagina("sottotrame")
	await app.get_tree().create_timer(0.2).timeout
	await _scatta(app, cartella, "sottotrame")
	ui._mostra_pagina("profilo")
	await app.get_tree().create_timer(0.2).timeout
	await _scatta(app, cartella, "profilo")
	stato.sabbia_padre_ore = 3.0
	stato.tempo_figlia_ore = 20.0
	stato.attenzione_polizia = 80.0
	ui._aggiorna_hud()
	ui._mostra_pagina("azioni")
	await app.get_tree().create_timer(0.3).timeout
	await _scatta(app, cartella, "hud_critico")
	ui._mostra_pagina("azioni")
	ui._chiudi_modale()
	ui._mostra_patto({"tipo": "patto_stregatto_proposto", "testo": Narrativa.patto_proposta(12.0), "prezzo_ore": 12.0})
	await app.get_tree().create_timer(0.3).timeout
	await _scatta(app, cartella, "patto")
	ui._chiudi_modale()
	stato.dona(3.0)
	ui._mostra_fine()
	await app.get_tree().create_timer(0.3).timeout
	await _scatta(app, cartella, "fine")
