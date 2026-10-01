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
	assert(is_equal_approx(s.sirio, 58.0), "la fascia costa 6 ore a Sirio")
	assert(s.sara <= 498.0 and s.fascia == 1 and s.visite == 1)
	print("tempo e luoghi: ok")

	assert(not s.giri_aperti.has("usura") and not s.luoghi_noti.has("bottega_nando"))
	var nomi: Array = []
	for o in s.opzioni_contatto("rocco"):
		nomi.append(o.id)
	assert(nomi.has("usura") and not nomi.has("lchen"), "Rocco presenta Mei Shen solo dopo due colpi")
	s.scegli_opzione("rocco", "usura")
	assert(s.giri_aperti.has("usura") and s.luoghi_noti.has("bottega_nando"))
	assert(s.fascia == 1, "il telefono non occupa la fascia")
	s.colpi_riusciti = 2
	s.scegli_opzione("rocco", "lchen")
	assert(s.contatti_noti.has("shen") and s.luoghi_noti.has("magazzino"))
	print("telefono: ok")

	var prima := s.giri.usura.persone as float
	var tentativi := 0
	while s.giri.usura.persone == prima and tentativi < 10:
		s.sirio = 100.0
		s.esegui("cresci:usura", "bottega_nando")
		tentativi += 1
	assert(s.giri.usura.persone > prima, "la crescita del giro funziona")
	s.giri.usura.persone = 1000.0
	s.giri.usura.controllo = 1.0
	assert(is_equal_approx(s.tributo("usura"), 400.0))
	var sirio_prima := s.sirio
	s.passa_fascia()
	assert(s.sirio > sirio_prima + 300.0 or s.is_over, "il giro rende a ogni fascia")
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

	t.sveglio = 10
	var m := t.malus()
	assert(int(m.modificatore) <= -3 and m.modo == DiceSystem.RollMode.SVANTAGGIO)
	t.sveglio = 0
	t.digiuno = 0
	assert(int(t.malus().modificatore) == 0)
	print("bisogni: ok")

	var r := ImperoState.new(3)
	r.giri.bische.persone = 100.0
	r.polizia = 5000.0
	r.passa_fascia()
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
	print("TUTTI I TEST IMPERO OK")
