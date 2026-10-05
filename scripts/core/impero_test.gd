class_name ImperoTest
extends RefCounted
## Auto-test del motore dell'impero (--test-impero).


static func esegui() -> void:
	print("=== TEST IMPERO ===")
	var d := ImperoState.dati()
	assert(d.giri.size() == 5 and d.azioni.size() == 16 and d.mosse.size() == 9)
	assert(d.luoghi.size() == 18 and d.contatti.size() == 7)
	assert(not JSON.stringify(d).contains("—"), "trattino lungo nei testi")
	print("dati: ok")

	var s := ImperoState.new(42)
	assert(is_equal_approx(s.sirio, 64.0) and is_equal_approx(s.sara, 504.0))
	assert(s.luogo == "ospedale" and s.contatti_noti.size() == 3)
	assert(s.esegui("turno", "ospedale").get("rifiutata", false), "il turno si fa solo al porto")
	assert(not s.voce_per_id("turno").is_empty() and s.voce_per_id("turno").luogo == "porto")
	var e := s.esegui("visita")
	assert(not e.get("rifiutata", false))
	assert(is_equal_approx(s.sirio, 62.0), "due ore con Sara costano due ore a Sirio")
	assert(is_equal_approx(s.sara, 502.0) and s.visite == 1)
	assert(s.ora_testo() == "Martedì 2, 01:00", s.ora_testo())
	s.attendi(1.0)
	assert(is_equal_approx(s.sirio, 62.0 - 1.0 / 60.0), "un minuto nel mondo è un minuto di vita")
	var vg := s.viaggia("porto")
	assert(vg.ore > 0.0 and s.luogo == "porto")
	assert(is_equal_approx(504.0 - s.sara, 64.0 - s.sirio), "il viaggio costa uguale a entrambi")
	assert(s.viaggia("bisca").get("rifiutata", false), "non si va dove non si conosce la strada")
	s.attendi(400.0)
	assert(s.fascia == 1, "ogni sei ore la città gira")
	print("tempo e luoghi: ok")

	assert(not s.giri_aperti.has("usura") and not s.luoghi_noti.has("bottega_nando"))
	var nomi: Array = []
	for o in s.opzioni_contatto("rocco"):
		nomi.append(o.id)
	assert(nomi.has("usura") and not nomi.has("lchen"), "Rocco presenta Mei Shen solo dopo due colpi")
	s.scegli_opzione("rocco", "usura")
	assert(s.giri_aperti.has("usura") and s.luoghi_noti.has("bottega_nando"))
	assert(s.fascia == 1)
	s.colpi_riusciti = 2
	s.scegli_opzione("rocco", "lchen")
	assert(s.contatti_noti.has("shen") and s.luoghi_noti.has("magazzino"))
	print("telefono: ok")

	var prima := s.giri.usura.persone as float
	var tentativi := 0
	while s.giri.usura.persone == prima and tentativi < 10:
		s.sirio = 100.0
		s.sara = 500.0
		s.esegui("cresci:usura", "bottega_nando")
		tentativi += 1
	assert(s.giri.usura.persone > prima, "la crescita del giro funziona")
	s.giri.usura.persone = 1000.0
	s.giri.usura.controllo = 1.0
	assert(is_equal_approx(s.tributo("usura"), 400.0))
	var sirio_prima := s.sirio
	s.attendi(360.0)
	assert(s.sirio > sirio_prima + 300.0 or s.is_over, "il giro rende ogni sei ore")
	print("giri: ok")

	var t := ImperoState.new(7)
	t.scegli_opzione("rocco", "usura")
	t.giri.usura.persone = 10.0
	t.sirio = 100.0
	assert(not t.voce_per_id("luogotenente:usura").disponibile, "serve un uomo")
	t.uomini = 1
	assert(t.voce_per_id("luogotenente:usura").disponibile)
	t.esegui("luogotenente:usura", "bottega_nando")
	assert(t.giri.usura.luogotenente and t.uomini == 0)
	print("luogotenenti: ok")

	t.sveglio = 61.0
	var m := t.malus()
	assert(int(m.modificatore) <= -3 and m.modo == DiceSystem.RollMode.SVANTAGGIO)
	t.sveglio = 0
	t.digiuno = 0
	assert(int(t.malus().modificatore) == 0)
	print("bisogni: ok")

	var r := ImperoState.new(3)
	r.giri.bische.persone = 100.0
	r.polizia = 5000.0
	r.attendi(360.0)
	assert(r.giri.bische.persone < 60.0, "retata sicura con polizia altissima")
	print("calore: ok")

	var u := ImperoState.new(5)
	u.luogo = "casa"
	assert(not u.dona(1.0).successo, "si dona solo in ospedale")
	var sara_prima := u.sara
	assert(u.dona(1.0, "ospedale").successo and is_equal_approx(u.sara, sara_prima + 1.0))
	assert(u.is_over and u.fine == "dono")
	assert(u.esegui("visita").get("rifiutata", false))
	print("donazione: ok")

	var p := ImperoPersistente.new()
	var v := ImperoState.new(9)
	v.giorno_max = 8
	var note := v.valuta_obiettivi(p)
	assert(note.size() >= 1 and p.contatti.has("shen") and p.luoghi.has("magazzino"))
	var percorso := "user://impero_test.json"
	p.salva(percorso)
	var p2 := ImperoPersistente.carica(percorso)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(percorso))
	var w := ImperoState.new(10, 0, p2)
	assert(w.contatti_noti.has("shen") and w.luoghi_noti.has("magazzino"))
	assert(v.valuta_obiettivi(p).is_empty(), "un obiettivo si sblocca una volta")
	print("sblocchi permanenti: ok")

	var a := ImperoBot.gioca(77, "usuraio")
	var b := ImperoBot.gioca(77, "usuraio")
	assert(a.fascia == b.fascia and is_equal_approx(a.sara, b.sara), "stesso seed, stessa partita")
	var media_ladro := 0.0
	var media_usuraio := 0.0
	for i in 30:
		media_ladro += ImperoBot.gioca(500 + i, "ladro").punteggio().sara_anni
		media_usuraio += ImperoBot.gioca(500 + i, "usuraio").punteggio().sara_anni
	assert(media_usuraio > media_ladro * 3.0, "un impero deve rendere più dei colpi")
	print("bot: ladro %.2f anni, usuraio %.2f anni" % [media_ladro / 30.0, media_usuraio / 30.0])

	var k := ImperoState.new(11, 2)
	assert(is_equal_approx(k.sirio, 56.0), "difficoltà 2: 8 ore in meno")
	var somma := 0
	for n in k.stat:
		somma += int(k.stat[n])
		assert(int(k.stat[n]) >= 1 and int(k.stat[n]) <= 4)
	assert(somma == 7, "sette punti tra le tre statistiche")
	var k2 := ImperoState.new(11)
	assert(k2.stat == k.stat and k2.variante("x", 5) == k.variante("x", 5), "statistiche e varianti dipendono dal seed")
	print("statistiche: ok")

	# minigiochi
	var mg := ImperoState.new(21)
	mg.sirio = 100.0
	var rr := Minigiochi.roulette(mg, 5.0, "rosso")
	assert(rr.numero >= 0 and rr.numero <= 36)
	assert(rr.vinto == (Minigiochi.colore(rr.numero) == "rosso"))
	assert(Minigiochi.vince("numero:7", 7) and not Minigiochi.vince("pari", 0))
	assert(is_equal_approx(mg.tempo_min, 10.0), "un giro di ruota costa dieci minuti")
	assert(Minigiochi.roulette(mg, 500.0, "rosso").get("rifiutata", false))
	var inc := Minigiochi.incontro(mg)
	assert(inc.nomi[0] != inc.nomi[1] and inc.quote[0] > 1.0 and inc.quote[1] > 1.0)
	var lt := Minigiochi.lotta(mg, 4.0, 0)
	assert(lt.vincitore == 0 or lt.vincitore == 1)
	assert(not lt.colpi.is_empty())
	assert(Minigiochi.incontro(mg).nomi != inc.nomi or Minigiochi.incontro(mg).forza != inc.forza, "dopo un incontro ne arriva un altro")
	var vendute := 0
	var indovinate := 0
	for i in 60:
		var sx := ImperoState.new(300 + i)
		sx.sirio = 100.0
		var ix := Minigiochi.incontro(sx)
		if ix.venduto >= 0:
			vendute += 1
			var lx := Minigiochi.lotta(sx, 1.0, 1 - ix.venduto)
			if lx.vinto:
				indovinate += 1
	assert(vendute > 5 and indovinate >= vendute * 0.7, "chi sa chi si è venduto vince quasi sempre")
	print("minigiochi: ok (%d incontri truccati su 60, %d vinti sapendolo)" % [vendute, indovinate])

	# dialoghi: le quattro categorie
	var dl := ImperoState.new(42)
	var nodo := DialogoSystem.nodo_iniziale(dl, "rocco")
	var cat := {}
	for o in DialogoSystem.opzioni(dl, "rocco", nodo):
		cat[o.categoria] = true
	assert(cat.has("fissa") and cat.has("stat") and cat.has("seed"), "Rocco: %s" % str(cat))
	assert(not cat.has("memoria"), "la memoria compare solo dopo")
	dl.oggetti["santino"] = true
	var mem := false
	for o in DialogoSystem.opzioni(dl, "rocco", nodo):
		if o.categoria == "memoria":
			mem = true
	assert(mem, "con il santino di Serena si apre un ricordo")
	dl.stat.freddezza = 1
	for o in DialogoSystem.opzioni(dl, "rocco", nodo):
		if o.categoria == "stat":
			assert(not o.aperta and o.requisito_testo.contains("Freddezza"), "l'opzione stat chiusa mostra il requisito")
			assert(DialogoSystem.scegli(dl, "rocco", nodo, o).get("rifiutata", false))
	var t0 := dl.tempo_min
	var usura_tel: Dictionary = {}
	for o in DialogoSystem.opzioni(dl, "rocco", nodo):
		if o.get("contatto_opzione", "") == "usura":
			usura_tel = o
	var r1 := DialogoSystem.scegli(dl, "rocco", nodo, usura_tel)
	assert(dl.giri_aperti.has("usura") and r1.risposta.contains("Nando"))
	assert(dl.tempo_min > t0, "parlare costa minuti")
	var semi := {}
	for i in 30:
		var sd := ImperoState.new(1000 + i)
		for o in DialogoSystem.opzioni(sd, "rocco", "inizio"):
			if o.categoria == "seed":
				semi[o.id] = true
	assert(semi.size() >= 2, "seed diversi danno offerte diverse")
	# memoria: l'informatore apre il ricatto a Bassi
	var ric := ImperoState.new(5)
	var ha_ricatto := func() -> bool:
		for o in DialogoSystem.opzioni(ric, "bassi", "inizio"):
			if o.id == "debiti":
				return true
		return false
	assert(not ha_ricatto.call())
	ric.ricorda("informatore")
	for o in DialogoSystem.opzioni(ric, "lombardi", "inizio"):
		if o.id == "bassi_info":
			DialogoSystem.scegli(ric, "lombardi", "inizio", o)
	assert(ha_ricatto.call(), "aver parlato con l'informatore apre il ricatto")
	print("dialoghi: ok")
	print("TUTTI I TEST IMPERO OK")
