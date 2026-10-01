class_name MondoBot
extends RefCounted
## Giocatore automatico per controllare il bilanciamento del mondo (padre che
## paga le ore, spostamenti, fame e sonno). Euristica avida: valore atteso
## netto per ora, viaggio compreso; dorme e mangia quando il malus pesa.
## Non usa telefono ne tracce: misura il "pavimento" di una run giocata male.

static func gioca(seme: int) -> Dictionary:
	var mondo := MondoRun.new(GameState.new(seme))
	var passi := 0
	while not mondo.stato.is_over and passi < 400:
		passi += 1
		if not mondo.stato.patto_in_sospeso.is_empty():
			mondo.stato.risolvi_patto_stregatto(false)
		var occ := mondo.cerca_occasione(false)
		if not occ.is_empty():
			mondo.risolvi_occasione(occ.id, 0)
			continue
		if mondo.stato.tempo_figlia_ore < 6.0 or mondo.stato.sabbia_padre_ore < 3.0:
			if mondo.luogo != "ospedale":
				mondo.viaggia("ospedale")
			if not mondo.stato.is_over:
				mondo.dona(maxf(mondo.stato.sabbia_padre_ore * 0.95, 0.1))
			break
		var mb := mondo.malus_bisogni()
		if int(mondo.stato_sonno()[2]) >= 2 and mondo.stato.sabbia_padre_ore > 14.0:
			_vai_e_fai(mondo, "casa", MondoRun.AZIONE_DORMIRE)
			continue
		if int(mondo.stato_fame()[2]) >= 1:
			_vai_e_fai(mondo, "piazza", MondoRun.AZIONE_PASTO)
			continue
		var migliore := ""
		var luogo_migliore := ""
		var valore_migliore := -INF
		for l in mondo.luoghi_visibili():
			var viaggio := 0.0 if l.id == mondo.luogo else mondo.stima_viaggio(l.id)
			var salva := mondo.luogo
			mondo.luogo = l.id
			var voci := mondo.azioni_qui()
			mondo.luogo = salva
			for v in voci:
				if v.tipo != "azione" or not v.disponibile:
					continue
				var a: ActionData = v.azione
				if a.costo_tempo_figlia_ore + viaggio >= mondo.stato.sabbia_padre_ore - 1.0:
					continue
				var p := clampf(1.0 - a.rischio_pct + mb.modificatore * 0.05, 0.0, 1.0)
				var netto := p * a.effetto_sabbia_padre_ore - a.costo_tempo_figlia_ore - viaggio
				var ore := maxf(a.costo_tempo_figlia_ore + viaggio, 0.5)
				var val := netto / ore
				if val > valore_migliore:
					valore_migliore = val
					migliore = a.nome
					luogo_migliore = l.id
		if migliore == "":
			break
		_vai_e_fai(mondo, luogo_migliore, migliore)
	return {
		"giorno": mondo.giorno_max, "fine": mondo.stato.end_reason,
		"totale": mondo.stato.calcola_punteggio().punteggio_totale_anni,
		"figlia_anni": mondo.stato.calcola_punteggio().figlia_anni,
	}


static func _vai_e_fai(mondo: MondoRun, luogo: String, azione: String) -> void:
	if mondo.luogo != luogo:
		mondo.viaggia(luogo)
		if mondo.stato.is_over:
			return
		mondo.cerca_occasione(true)
	mondo.esegui_azione(azione)


static func report(n: int) -> void:
	var finali := {}
	var somma := 0.0
	var giorni := 0.0
	var tot: Array[float] = []
	for i in n:
		var r := gioca(1000 + i)
		finali[r.fine] = int(finali.get(r.fine, 0)) + 1
		somma += r.figlia_anni
		giorni += r.giorno
		tot.append(r.totale)
	tot.sort()
	print("MONDO BOT su %d run: giorno medio raggiunto %.1f, anni a Sara medi %.2f, mediana totale %.2f, max %.2f" % [n, giorni / n, somma / n, tot[n / 2], tot[-1]])
	print("fine run (0=nessuna,1=figlia morta,2=padre morto,3=donazione): %s" % str(finali))
