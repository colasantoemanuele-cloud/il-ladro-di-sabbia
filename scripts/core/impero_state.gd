class_name ImperoState
extends RefCounted
## Il motore dell'impero di sabbia (docs/progetto_impero.md). Logica pura,
## nessuna dipendenza dalla scena. Il tempo scorre a minuti: ogni minuto che
## passa nel mondo costa un minuto di vita a Sirio e uno a Sara, che Sirio
## cammini, parli, giochi o dorma. Ogni sei ore la città gira (_tick): i giri
## rendono, il calore si muove, Sara può avere una crisi. Numeri in
## data/impero.json.

const GIORNI := ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"]
const ORE_ANNO := 8760.0
const MINUTI_TICK := 360.0

static var _dati: Dictionary = {}

var seed_run: int
var _rng := RandomNumberGenerator.new()
var livello_difficolta := 0

var tempo_min := 0.0
var fascia := 0
var sirio := 0.0
var sara := 0.0
var rate_debito := 0
var luogo := "ospedale"
var luoghi_noti: Dictionary = {}
var contatti_noti: Dictionary = {}
var giri_aperti: Dictionary = {}
var giri: Dictionary = {}
var uomini := 0
var informatore := false
var polizia := 0.0
var rivalita := 0.0
var fama := 0.0
var karma := 0.0
var karma_inizio := 0.0
var sveglio := 18.0
var digiuno := 6.0
var visite := 0
var ultima_visita := -99999.0
var colpi_riusciti := 0
var lavori := 0
var luogotenenti_messi := 0
var vittorie_azzardo := 0
var stat: Dictionary = {}
var oggetti: Dictionary = {}
var flag: Dictionary = {}
var piste: Dictionary = {}
var mosse_tentate: Dictionary = {}
var usate: Dictionary = {}
var attese: Dictionary = {}
var opzioni_fatte: Dictionary = {}
var messaggi: Array[Dictionary] = []
var patto_in_sospeso: Dictionary = {}
var is_over := false
var fine := ""
var donato := 0.0
var picco_flusso := 0.0
var giorno_max := 1
var ultimo_incasso := 0.0


static func dati() -> Dictionary:
	if _dati.is_empty():
		var f := FileAccess.open("res://data/impero.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_dati = d
	return _dati


static func par() -> Dictionary:
	return dati().parametri


static func luogo_dati(id: String) -> Dictionary:
	for l in dati().luoghi:
		if l.id == id:
			return l
	return {}


static func contatto_dati(id: String) -> Dictionary:
	for c in dati().contatti:
		if c.id == id:
			return c
	return {}


func _init(seme: int = -1, livello: int = 0, persistente: ImperoPersistente = null, karma_iniziale: float = 0.0) -> void:
	if seme < 0:
		var r := RandomNumberGenerator.new()
		r.randomize()
		seme = r.randi() & 0x7FFFFFFF
	seed_run = seme
	_rng.seed = seme
	livello_difficolta = maxi(livello, 0)
	var p := par()
	sirio = maxf(p.sirio_iniziale - p.difficolta.sirio_per_livello * livello_difficolta, 4.0) + p.anticipo.ore
	sara = float(p.giorni) * 24.0
	rate_debito = int(p.anticipo.rate)
	karma = karma_iniziale
	karma_inizio = karma_iniziale
	for g in dati().giri:
		giri[g] = {"persone": 0.0, "luogotenente": false, "controllo": 1.0}
	for l in dati().luoghi:
		if l.get("iniziale", false):
			luoghi_noti[l.id] = true
	for c in dati().contatti:
		if c.get("iniziale", false):
			contatti_noti[c.id] = true
	_distribuisci_stat()
	if persistente != null:
		for id in persistente.luoghi:
			luoghi_noti[str(id)] = true
		for id in persistente.contatti:
			contatti_noti[str(id)] = true
		for id in persistente.piste:
			piste[str(id)] = true


## Ogni partita ha un Sirio un po' diverso: 7 punti tra le tre statistiche,
## da 1 a 4 ciascuna, decisi dal seed.
func _distribuisci_stat() -> void:
	var nomi: Array = dati().stat.keys()
	for n in nomi:
		stat[n] = 1
	var restanti := int(par().stat_iniziali) - nomi.size()
	var r := RandomNumberGenerator.new()
	r.seed = seed_run ^ 0x5A5A
	while restanti > 0:
		var n: String = nomi[r.randi() % nomi.size()]
		if int(stat[n]) < 4:
			stat[n] = int(stat[n]) + 1
			restanti -= 1


## Variante stabile decisa dal seed, indipendente dall'ordine delle azioni.
func variante(chiave: String, quante: int) -> int:
	if quante <= 0:
		return 0
	return absi(("%d/%s" % [seed_run, chiave]).hash()) % quante


# ================================================================ tempo

func fasce_totali() -> int:
	return int(par().giorni) * 4


func _minuti_orologio() -> float:
	return float(par().ora_inizio) * 60.0 + tempo_min


func giorno() -> int:
	return int(_minuti_orologio() / 1440.0) + 1


func orologio() -> String:
	var m := int(_minuti_orologio()) % 1440
	return "%02d:%02d" % [m / 60, m % 60]


func ora_testo() -> String:
	return "%s %d, %s" % [GIORNI[(giorno() - 1) % 7], giorno(), orologio()]


func giorni_sara() -> float:
	return sara / 24.0


## Fa passare il tempo: lo stesso tempo per Sirio e per Sara. Ogni sei ore la
## città gira. Restituisce gli eventi accaduti nel frattempo.
func passa_tempo(minuti: float, dorme: bool = false) -> Array:
	var eventi: Array = []
	var resto := minuti
	while resto > 0.0001 and not is_over:
		var prossimo := float(fascia + 1) * MINUTI_TICK
		var passo := minf(resto, prossimo - tempo_min)
		var ore := passo / 60.0
		tempo_min += passo
		resto -= passo
		sirio -= ore
		sara -= ore
		if not dorme:
			sveglio += ore
		digiuno += ore
		if tempo_min >= prossimo - 0.0001:
			tempo_min = prossimo
			eventi.append_array(_tick())
		if giorno() > giorno_max:
			giorno_max = giorno()
			eventi.append_array(_nuovo_giorno())
		_controlla_fine()
	return eventi


func attendi(minuti: float) -> Array:
	return passa_tempo(minuti)


func _nuovo_giorno() -> Array:
	var eventi: Array = []
	var p := par()
	var msg: String = dati().messaggi.get(str(giorno()), "")
	if msg != "":
		messaggi.append({"da": "venti", "testo": msg, "letto": false})
		eventi.append({"tipo": "messaggio", "testo": "Un messaggio della dottoressa Venti.", "grave": false})
	if karma_inizio <= float(p.patto.soglia_karma) and patto_in_sospeso.is_empty() and _rng.randf() < float(p.patto.probabilita_giorno):
		patto_in_sospeso = {"prezzo": roundf(maxf(sirio, 0.0) * float(p.patto.prezzo))}
		eventi.append({"tipo": "patto", "testo": Narrativa.patto_proposta(patto_in_sospeso.prezzo), "grave": true})
	return eventi


# ================================================================ statistiche, oggetti, memoria

func bonus_stat(nome: String) -> int:
	return (int(stat.get(nome, 1)) - 1) / 2


func aumenta_stat(nome: String, quanto: int = 1) -> String:
	var prima := int(stat.get(nome, 1))
	stat[nome] = clampi(prima + quanto, 1, int(par().stat_max))
	if int(stat[nome]) == prima:
		return ""
	return "%s sale a %d." % [dati().stat[nome].nome, stat[nome]]


func bonus_oggetti(chiave: String) -> int:
	var b := 0
	for o in oggetti:
		b += int(dati().oggetti[o].get("bonus", {}).get(chiave, 0))
	return b


func ricorda(f: String) -> void:
	flag[f] = true


func ricordato(f: String) -> bool:
	return flag.has(f)


func incontra(cid: String) -> bool:
	if cid == "" or contatti_noti.has(cid) or contatto_dati(cid).is_empty():
		return false
	contatti_noti[cid] = true
	return true


# ================================================================ bisogni e tiri

static func _livello(valore: float, soglie: Array) -> Array:
	var esito := ["", 0, 0]
	for i in soglie.size():
		if valore >= float(soglie[i][0]):
			esito = [soglie[i][1], int(soglie[i][2]), i + 1]
	return esito


func stato_sonno() -> Array:
	var l := _livello(sveglio, dati().sonno)
	if l[0] == "":
		l[0] = "Lucido"
	return l


func stato_fame() -> Array:
	var l := _livello(digiuno, dati().fame)
	if l[0] == "":
		l[0] = "Sazio"
	return l


func malus() -> Dictionary:
	var s := stato_sonno()
	var f := stato_fame()
	var mod := maxi(int(s[1]) + int(f[1]), -4)
	var svantaggio: bool = int(s[2]) >= 3 or int(f[2]) >= 3
	return {"modificatore": mod, "modo": DiceSystem.RollMode.SVANTAGGIO if svantaggio else DiceSystem.RollMode.NORMALE}


func _rischio(base: float) -> float:
	return clampf(base + par().difficolta.rischio_per_livello * livello_difficolta, 0.0, 1.0)


func tiro(rischio: float, extra: int = 0) -> DiceSystem.RollResult:
	var m := malus()
	return DiceSystem.risolvi(_rischio(rischio), m.modo, int(m.modificatore) + extra, _rng)


func casuale() -> float:
	return _rng.randf()


func casuale_intero(da: int, a: int) -> int:
	return _rng.randi_range(da, a)


# ================================================================ economia

func tributo(g: String) -> float:
	var d: Dictionary = dati().giri[g]
	var stato: Dictionary = giri[g]
	var n: float = stato.persone
	var per: int = int(d.uomini_per)
	if per > 0:
		n = minf(n, float(uomini * per + per))
	var t: float = n * float(d.tributo) * float(stato.controllo)
	if stato.luogotenente:
		t *= 1.0 - float(par().luogotenente.cresta)
	return t


func flusso_lordo() -> float:
	var f := 0.0
	for g in giri:
		f += tributo(g)
	return f


func costi_fissi() -> float:
	var c := uomini * float(par().paga_uomo)
	if rate_debito > 0 and fascia >= int(par().anticipo.dalla_fascia):
		c += float(par().anticipo.rata)
	return c


## Quanto entra ogni sei ore al netto delle sei ore che passano.
func flusso_netto() -> float:
	return flusso_lordo() - costi_fissi() - float(par().ore_fascia)


func persone_totali() -> float:
	var n := 0.0
	for g in giri:
		n += giri[g].persone
	return n


# ================================================================ luoghi e viaggi

func ore_viaggio(dest: String) -> float:
	if dest == luogo:
		return 0.0
	var a: Array = luogo_dati(luogo).get("pos", [0, 0])
	var b: Array = luogo_dati(dest).get("pos", [0, 0])
	return 0.2 + Vector2(a[0], a[1]).distance_to(Vector2(b[0], b[1])) / 55.0


func viaggia(dest: String) -> Dictionary:
	if is_over:
		return _rifiuto("La partita è finita.")
	if not luoghi_noti.has(dest):
		return _rifiuto("Non conosci la strada.")
	if dest == luogo:
		return {"ore": 0.0, "eventi": []}
	var ore := ore_viaggio(dest)
	var eventi := passa_tempo(ore * 60.0)
	luogo = dest
	return {"ore": ore, "eventi": eventi}


func luoghi_visibili() -> Array:
	var out: Array = []
	for l in dati().luoghi:
		if luoghi_noti.has(l.id):
			out.append(l)
	return out


func costo_crescita(g: String) -> float:
	var d: Dictionary = dati().giri[g]
	return float(d.costo) * (float(d.base) + float(d.perc) * float(giri[g].persone))


func _costo_quota(base: float, quota: float) -> float:
	return base + quota * maxf(flusso_lordo(), 0.0)


func _voce(id: String, nome: String, tipo: String, descrizione: String, disponibile: bool, durata: float, nota: String = "", rischio: float = -1.0) -> Dictionary:
	return {"id": id, "nome": nome, "tipo": tipo, "descrizione": descrizione, "disponibile": disponibile and not is_over,
		"nota": nota, "rischio": rischio, "durata": durata}


## Tutto quello che si può fare in un luogo (anche non ancora disponibile,
## con il motivo nella nota). Ogni voce ha una durata in ore.
func voci(id_luogo: String) -> Array:
	var out: Array = []
	var l := luogo_dati(id_luogo)
	if l.is_empty():
		return out
	var p := par()
	var dur: Dictionary = p.durate
	for a in dati().azioni:
		if a.luogo != id_luogo:
			continue
		var ok := true
		var nota := ""
		var desc := ""
		match a.tipo:
			"lavoro":
				desc = "Rende %s." % _ore(float(a.resa))
			"colpo":
				desc = "Rende %s-%s." % [_ore(float(a.resa[0])), _ore(float(a.resa[1]))]
				if a.has("per_uomo"):
					desc = "Rende %s-%s, di più con più uomini." % [_ore(float(a.resa[0])), _ore(float(a.resa[1]))]
				if uomini < int(a.get("uomini", 0)):
					ok = false
					nota = "Servono %d uomini" % int(a.uomini)
			"recluta":
				desc = "Costa %s, poi %s ogni sei ore." % [_ore(float(p.costo_recluta)), _ore(float(p.paga_uomo))]
				ok = sirio > float(p.costo_recluta)
			"corrompi":
				var c := _costo_quota(float(p.corrompi.costo), float(p.corrompi.quota))
				desc = "Costa %s. La polizia ti perde di vista." % _ore(c)
				ok = sirio > c and polizia > 0.0
			"tributo":
				var c2 := _costo_quota(float(p.tributo.costo), float(p.tributo.quota))
				desc = "Costa %s. I rivali si calmano." % _ore(c2)
				ok = sirio > c2 and rivalita > 0.0
			"informatore":
				desc = "Costa %s. La polizia ti scalda più piano, per sempre." % _ore(float(p.informatore))
				ok = not informatore and sirio > float(p.informatore)
				if informatore:
					nota = "Ce l'hai già"
			"dormi":
				desc = "Sei ore di sonno. La rete lavora lo stesso."
			"visita":
				desc = "Sara ha meno crisi quando ci sei."
			"liquida":
				var valore := flusso_lordo() * float(p.liquidazione.fasce)
				desc = "Vendi tutta la rete in una notte: circa %s. Poi non hai più niente." % _ore(valore)
				ok = valore > 200.0
				if not ok:
					nota = "La rete è ancora troppo piccola"
		if a.get("una_volta", false) and usate.has(a.id):
			ok = false
			nota = "Già fatto"
		if float(attese.get(a.id, -1.0)) > tempo_min:
			ok = false
			nota = "Di nuovo tra %dh" % ceili((float(attese[a.id]) - tempo_min) / 60.0)
		var rischio: float = float(a.get("rischio", -1.0))
		if a.tipo == "liquida":
			rischio = float(p.liquidazione.rischio)
		out.append(_voce(a.id, a.nome, a.tipo, desc, ok, float(a.durata), nota, rischio))
	for g in dati().giri:
		var d: Dictionary = dati().giri[g]
		if d.sede != id_luogo or not giri_aperti.has(g):
			continue
		var st: Dictionary = giri[g]
		var costo := costo_crescita(g)
		var nuove := float(d.base) + float(d.perc) * float(st.persone)
		var nota_c := ""
		if sirio <= costo + 4.0:
			nota_c = "Non hai abbastanza sabbia"
		out.append(_voce("cresci:" + g, d.cresci, "cresci", "Circa %d %s in più, costa %s. %s" % [int(nuove), d.persone, _ore(costo), d.descrizione], sirio > costo + 4.0, float(dur.cresci), nota_c, float(d.rischio)))
		if st.persone > 0.0 and not st.luogotenente:
			out.append(_voce("riscuoti:" + g, "Giro di riscossione", "riscuoti", "Rimetti in riga i %s e incassi gli arretrati. Controllo ora al %d%%." % [d.persone, int(float(st.controllo) * 100.0)], float(st.controllo) < 0.99, float(dur.riscuoti)))
		if not st.luogotenente:
			var lp: Dictionary = p.luogotenente
			var ok_l: bool = st.persone >= float(lp.soglia) and uomini >= 1 and sirio > float(lp.costo)
			var nota_l := ""
			if st.persone < float(lp.soglia):
				nota_l = "Servono almeno %d %s" % [int(lp.soglia), d.persone]
			elif uomini < 1:
				nota_l = "Serve un uomo da mettere a capo"
			out.append(_voce("luogotenente:" + g, "Mettere un luogotenente", "luogotenente", "Costa %s e un uomo. Il giro cresce da solo del %d%% ogni sei ore, ma lui trattiene il %d%% e può tradire." % [_ore(float(lp.costo)), int(float(lp.crescita) * 100.0), int(float(lp.cresta) * 100.0)], ok_l, float(dur.luogotenente), nota_l))
	for m in dati().mosse:
		var md: Dictionary = dati().mosse[m]
		if md.luogo != id_luogo or not piste.has(m):
			continue
		var motivo := _manca_per_mossa(md)
		if mosse_tentate.has(m):
			motivo = "Già tentata"
		var desc_m := ""
		if md.has("posta"):
			desc_m = "Punti %s. Se va bene ne ricevi %s." % [_ore(float(md.posta)), _ore(float(md.posta) * float(md.moltiplica))]
		else:
			desc_m = "Rende %s-%s. Una sola occasione." % [_ore(float(md.resa[0])), _ore(float(md.resa[1]))]
		out.append(_voce("mossa:" + m, md.nome, "mossa", desc_m, motivo == "", float(dur.mossa), motivo, float(md.rischio)))
	if l.get("dona", false):
		out.append(_voce("dona", "Donare a Sara", "dona", "Una volta sola, irreversibile. Puoi dare anche un'ora sola. La partita finisce qui.", not is_over, 0.0))
	if l.has("cibo"):
		out.append(_voce("mangia", "Mangiare qualcosa", "mangia", "Costa %s." % _ore(float(l.cibo)), sirio > float(l.cibo) and digiuno > 2.0, float(dur.mangia), "" if digiuno > 2.0 else "Hai appena mangiato"))
	return out


func _manca_per_mossa(md: Dictionary) -> String:
	var r: Dictionary = md.get("richiede", {})
	if r.has("uomini") and uomini < int(r.uomini):
		return "Servono %d uomini" % int(r.uomini)
	if r.has("visite") and visite < int(r.visite):
		return "Devi stare con Sara più spesso"
	if r.has("informatore") and not informatore:
		return "Serve un informatore in questura"
	if r.has("sabbia") and sirio < float(r.sabbia):
		return "Servono %s da puntare" % _ore(float(r.sabbia))
	if r.has("giro"):
		var g: String = r.giro[0]
		if float(giri[g].persone) < float(r.giro[1]):
			return "Servono %d %s" % [int(r.giro[1]), dati().giri[g].persone]
	return ""


func voce_per_id(id: String) -> Dictionary:
	for l in luoghi_visibili():
		for v in voci(l.id):
			if v.id == id:
				var c: Dictionary = v.duplicate()
				c["luogo"] = l.id
				return c
	return {}


static func _ore(v: float) -> String:
	var a := absf(v)
	if a >= 4380.0:
		return "%.1f anni" % (v / ORE_ANNO)
	if a >= 100.0:
		return "%dh" % int(roundf(v))
	return "%.1fh" % v


# ================================================================ azioni

func _esito() -> Dictionary:
	return {"risultati": [], "eventi": [], "notifiche": []}


func _rifiuto(motivo: String) -> Dictionary:
	var e := _esito()
	e["rifiutata"] = true
	e["motivo"] = motivo
	return e


## Esegue una voce. Se Sirio è altrove, prima ci va (il viaggio costa tempo).
func esegui(id: String, dove: String = "") -> Dictionary:
	if is_over:
		return _rifiuto("La partita è finita.")
	if not patto_in_sospeso.is_empty():
		return _rifiuto("Prima rispondi a Dolce Volpe.")
	if dove == "":
		dove = luogo
	var voce: Dictionary = {}
	for v in voci(dove):
		if v.id == id:
			voce = v
	if voce.is_empty() or not voce.disponibile:
		return _rifiuto(str(voce.nota) if not voce.is_empty() and voce.nota != "" else "Non qui, non adesso.")
	if id == "dona":
		return _rifiuto("La donazione si fa con dona().")
	var esito := _esito()
	if dove != luogo:
		var v := viaggia(dove)
		esito.eventi.append_array(v.get("eventi", []))
		if is_over:
			return esito
	var tipo: String = voce.tipo
	var dorme := false
	if tipo == "cresci" or tipo == "riscuoti" or tipo == "luogotenente":
		_giro(tipo, id.split(":")[1], esito)
	elif tipo == "mossa":
		_mossa(id.split(":")[1], esito)
	elif tipo == "mangia":
		var costo: float = float(luogo_dati(luogo).cibo)
		sirio -= costo
		digiuno = 0.0
		_risultato(esito, "Mangiare qualcosa", "Pane, olio, qualcosa di caldo. Mangi in piedi.", null, true, ["Costo %s" % _ore(costo)])
	else:
		dorme = tipo == "dormi"
		_azione(_azione_dati(id), esito)
	esito.eventi.append_array(passa_tempo(float(voce.durata) * 60.0, dorme))
	if dorme:
		sveglio = 0.0
	return esito


func _azione_dati(id: String) -> Dictionary:
	for a in dati().azioni:
		if a.id == id:
			return a
	return {}


func _risultato(esito: Dictionary, titolo: String, testo: String, roll, successo: bool, righe: Array) -> void:
	esito.risultati.append({"titolo": titolo, "testo": testo, "roll": roll, "successo": successo, "righe": righe})


func _azione(a: Dictionary, esito: Dictionary) -> void:
	var p := par()
	if a.get("una_volta", false):
		usate[a.id] = true
	if a.has("attesa"):
		attese[a.id] = tempo_min + float(a.attesa) * 60.0
	karma = clampf(karma + float(a.get("karma", 0)), -100.0, 100.0)
	match a.tipo:
		"lavoro":
			var resa := float(a.resa)
			sirio += resa
			lavori += 1
			_risultato(esito, a.nome, a.ok, null, true, ["Sabbia +%s" % _ore(resa)])
		"colpo":
			var extra := -int(polizia / 25.0) + bonus_stat(a.get("stat", "freddezza")) + bonus_oggetti("colpo") + bonus_oggetti(a.id)
			var roll := tiro(float(a.rischio), extra)
			if roll.successo:
				var resa2 := _rng.randf_range(float(a.resa[0]), float(a.resa[1])) * (1.0 + float(a.get("per_uomo", 0.0)) * uomini)
				sirio += resa2
				colpi_riusciti += 1
				var righe2 := ["Sabbia +%s" % _ore(resa2)]
				if colpi_riusciti % 3 == 0:
					var s := aumenta_stat("freddezza")
					if s != "":
						righe2.append(s)
				_risultato(esito, a.nome, a.ok, roll, true, righe2)
			else:
				polizia += float(a.get("polizia", 0))
				var righe := ["Polizia +%d" % int(a.get("polizia", 0))]
				if a.id == "furgone" and uomini > 0:
					uomini -= 1
					righe.append("Un uomo in meno")
				_risultato(esito, a.nome, a.ko, roll, false, righe)
		"recluta":
			sirio -= float(p.costo_recluta)
			uomini += 1
			_risultato(esito, a.nome, a.ok, null, true, ["Uomini: %d" % uomini])
		"corrompi":
			var c := _costo_quota(float(p.corrompi.costo), float(p.corrompi.quota))
			sirio -= c
			polizia = maxf(0.0, polizia - float(p.corrompi.effetto))
			_risultato(esito, a.nome, a.ok, null, true, ["Costo %s" % _ore(c), "Polizia -%d" % int(p.corrompi.effetto)])
		"tributo":
			var c2 := _costo_quota(float(p.tributo.costo), float(p.tributo.quota))
			sirio -= c2
			rivalita = maxf(0.0, rivalita - float(p.tributo.effetto))
			_risultato(esito, a.nome, a.ok, null, true, ["Costo %s" % _ore(c2), "Rivalità -%d" % int(p.tributo.effetto)])
		"informatore":
			sirio -= float(p.informatore)
			informatore = true
			ricorda("informatore")
			_risultato(esito, a.nome, a.ok, null, true, [])
		"dormi":
			_risultato(esito, a.nome, a.ok, null, true, [])
		"visita":
			visite += 1
			ultima_visita = tempo_min
			_risultato(esito, a.nome, a.ok, null, true, [])
		"liquida":
			var valore := flusso_lordo() * float(p.liquidazione.fasce)
			var roll2 := tiro(float(p.liquidazione.rischio), bonus_stat("freddezza"))
			var preso := valore if roll2.successo else valore * 0.2
			sirio += preso
			for g in giri:
				giri[g] = {"persone": 0.0, "luogotenente": false, "controllo": 1.0}
			_risultato(esito, a.nome, a.ok if roll2.successo else a.ko, roll2, roll2.successo, ["Sabbia +%s" % _ore(preso), "La rete non c'è più"])


func _giro(tipo: String, g: String, esito: Dictionary) -> void:
	var d: Dictionary = dati().giri[g]
	var st: Dictionary = giri[g]
	match tipo:
		"cresci":
			var nuove := float(d.base) + float(d.perc) * float(st.persone)
			var costo := costo_crescita(g)
			sirio -= costo
			karma = clampf(karma + float(d.karma), -100.0, 100.0)
			var roll := tiro(float(d.rischio), bonus_stat(d.stat) + bonus_oggetti(g))
			if roll.successo:
				var prese := nuove * _rng.randf_range(0.8, 1.2)
				st.persone = minf(float(st.persone) + prese, float(par().popolazione))
				st.controllo = minf(1.0, float(st.controllo) + 0.2)
				_risultato(esito, d.cresci, "Il giro si allarga.", roll, true, ["%s +%d (ora %d)" % [str(d.persone).capitalize(), int(prese), int(st.persone)], "Costo %s" % _ore(costo)])
			else:
				_risultato(esito, d.cresci, "Porte chiuse, facce dure. La sabbia spesa non torna.", roll, false, ["Costo %s" % _ore(costo)])
		"riscuoti":
			var pieno := tributo(g) / maxf(float(st.controllo), 0.01)
			var arretrati := (1.0 - float(st.controllo)) * pieno * 4.0
			st.controllo = 1.0
			sirio += arretrati
			_risultato(esito, "Giro di riscossione", "Passi di persona. Nessuno ha voglia di essere in ritardo.", null, true, ["Arretrati +%s" % _ore(arretrati)])
		"luogotenente":
			sirio -= float(par().luogotenente.costo)
			uomini -= 1
			st.luogotenente = true
			st.controllo = maxf(float(st.controllo), float(par().controllo.con_luogotenente))
			luogotenenti_messi += 1
			_risultato(esito, "Un luogotenente per %s" % str(d.nome).to_lower(), "Gli dai le chiavi e un numero di telefono. Da adesso il giro cresce anche senza di te.", null, true, [])


func _mossa(m: String, esito: Dictionary) -> void:
	var md: Dictionary = dati().mosse[m]
	mosse_tentate[m] = true
	karma = clampf(karma + float(md.get("karma", 0)), -100.0, 100.0)
	var extra: int = bonus_stat(md.get("stat", "freddezza"))
	if md.get("richiede", {}).has("uomini"):
		extra += uomini / 4
	var roll := tiro(float(md.rischio), extra)
	var righe: Array = []
	if md.has("posta"):
		var posta := float(md.posta)
		sirio -= posta
		if roll.successo:
			sirio += posta * float(md.moltiplica)
			righe.append("Sabbia +%s" % _ore(posta * (float(md.moltiplica) - 1.0)))
		else:
			righe.append("Sabbia -%s" % _ore(posta))
	elif roll.successo:
		var resa := _rng.randf_range(float(md.resa[0]), float(md.resa[1]))
		sirio += resa
		righe.append("Sabbia +%s" % _ore(resa))
	if roll.successo:
		rivalita += float(md.get("rivali", 0))
		ricorda("mossa_" + m)
	else:
		var f: Dictionary = md.get("fallimento", {})
		if f.has("uomini"):
			uomini = maxi(0, uomini - int(f.uomini))
			righe.append("Uomini -%d" % int(f.uomini))
		if f.has("polizia"):
			polizia += float(f.polizia)
			righe.append("Polizia +%d" % int(f.polizia))
		if f.has("rivali"):
			rivalita += float(f.rivali)
		if f.has("giro"):
			giri[f.giro[0]].persone = float(giri[f.giro[0]].persone) * float(f.giro[1])
			righe.append("Il giro si dimezza")
	_risultato(esito, md.nome, md.ok if roll.successo else md.ko, roll, roll.successo, righe)


## Si dona in reparto. Chi lo fa da un altro luogo ci va: la partita finisce.
func dona(ore: float, dove: String = "") -> Dictionary:
	if is_over:
		return {"successo": false, "motivo": "La partita è finita."}
	if dove != "":
		luogo = dove
	if luogo != "ospedale":
		return {"successo": false, "motivo": "Si dona in reparto, accanto a Sara."}
	if ore <= 0.0 or ore > sirio:
		return {"successo": false, "motivo": "Quantità non valida."}
	sirio -= ore
	sara += ore
	donato = ore
	is_over = true
	fine = "dono"
	return {"successo": true}


func risolvi_patto(accetta: bool) -> Dictionary:
	if patto_in_sospeso.is_empty():
		return {}
	var prezzo: float = patto_in_sospeso.prezzo
	patto_in_sospeso = {}
	if not accetta:
		return {"accettato": false}
	sirio -= prezzo
	karma = clampf(karma + float(par().patto.karma), -100.0, 100.0)
	_controlla_fine()
	return {"accettato": true, "prezzo": prezzo}


# ================================================================ la città gira

func _tick() -> Array:
	var eventi: Array = []
	var p := par()
	var ev: Dictionary = dati().eventi
	if rate_debito > 0 and fascia >= int(p.anticipo.dalla_fascia):
		sirio -= float(p.anticipo.rata)
		rate_debito -= 1
		if rate_debito == 0:
			eventi.append({"tipo": "debito", "testo": ev.debito_fine, "grave": false})
	var f := flusso_lordo() - uomini * float(p.paga_uomo)
	sirio += f
	ultimo_incasso = f
	picco_flusso = maxf(picco_flusso, f)
	if absf(f) >= 0.1:
		eventi.append({"tipo": "incasso", "testo": "La rete ha reso %s." % _ore(f), "grave": false, "ore": f})
	var riduzione: float = float(p.calore.informatore) if informatore else 1.0
	var lp: Dictionary = p.luogotenente
	for g in giri:
		var d: Dictionary = dati().giri[g]
		var st: Dictionary = giri[g]
		var n: float = st.persone
		if n <= 0.0:
			continue
		polizia = maxf(0.0, polizia + n * float(d.polizia) * riduzione)
		rivalita += n * float(d.rivali)
		fama += n * float(d.fama)
		n *= 1.0 - float(d.perdita)
		if st.luogotenente:
			n = minf(n * (1.0 + float(lp.crescita)), float(p.popolazione))
			st.controllo = maxf(float(st.controllo), float(p.controllo.con_luogotenente))
			if _rng.randf() < float(lp.tradimento):
				n *= 0.5
				st.luogotenente = false
				eventi.append({"tipo": "tradimento", "testo": str(ev.tradimento).format({"giro": str(d.nome).to_lower()}), "grave": true})
		else:
			st.controllo = maxf(float(p.controllo.minimo), float(st.controllo) - float(p.controllo.calo))
		st.persone = n
	if _rng.randf() < polizia / float(p.calore.retata):
		var bersaglio := ""
		var peggiore := 0.0
		for g in ["bische", "protezione", "usura"]:
			var calore: float = float(giri[g].persone) * float(dati().giri[g].polizia)
			if calore > peggiore:
				peggiore = calore
				bersaglio = g
		if bersaglio != "":
			giri[bersaglio].persone = float(giri[bersaglio].persone) * 0.5
			giri[bersaglio].luogotenente = false
			eventi.append({"tipo": "retata", "testo": str(ev.retata).format({"giro": str(dati().giri[bersaglio].nome).to_lower()}), "grave": true})
		polizia *= 0.6
	if _rng.randf() < rivalita / float(p.calore.assalto):
		if uomini >= 3 and _rng.randf() < 0.5:
			eventi.append({"tipo": "assalto", "testo": ev.assalto_respinto, "grave": false})
		else:
			giri.protezione.persone = float(giri.protezione.persone) * 0.6
			giri.bische.persone = float(giri.bische.persone) * 0.7
			uomini = maxi(0, uomini - 1)
			eventi.append({"tipo": "assalto", "testo": ev.assalto, "grave": true})
		rivalita *= 0.7
	if _rng.randf() < fama / float(p.calore.scandalo):
		giri.culto.persone = float(giri.culto.persone) * 0.4
		fama *= 0.5
		eventi.append({"tipo": "scandalo", "testo": ev.scandalo, "grave": true})
	polizia = maxf(0.0, polizia - float(p.calore.calo_polizia))
	rivalita = maxf(0.0, rivalita - float(p.calore.calo_rivali))
	var c: Dictionary = p.crisi
	var prob: float = float(c.base) * giorno()
	if tempo_min - ultima_visita < float(c.ore_visita) * 60.0:
		prob *= float(c.visita)
	if _rng.randf() < prob:
		var danno := _rng.randf_range(float(c.danno[0]), float(c.danno[1])) * (1.0 + giorno() / 5.0)
		sara -= danno
		eventi.append({"tipo": "crisi", "testo": str(ev.crisi).format({"ore": int(danno)}), "grave": true})
	fascia += 1
	return eventi


func _controlla_fine() -> void:
	if is_over:
		return
	if sirio <= 0.0:
		is_over = true
		fine = "sirio"
	elif sara <= 0.0:
		sara = 0.0
		is_over = true
		fine = "sara"


# ================================================================ telefono e incontri

func contatti_visibili() -> Array:
	var out: Array = []
	for c in dati().contatti:
		if contatti_noti.has(c.id):
			out.append(c)
	return out


func vale(cond: Dictionary) -> bool:
	for k in cond:
		var v = cond[k]
		match k:
			"colpi":
				if colpi_riusciti < int(v):
					return false
			"lavori":
				if lavori < int(v):
					return false
			"visite":
				if visite < int(v):
					return false
			"uomini":
				if uomini < int(v):
					return false
			"giro":
				if float(giri[v[0]].persone) < float(v[1]):
					return false
			"giro_aperto":
				if not giri_aperti.has(v):
					return false
			"giro_chiuso":
				if giri_aperti.has(v):
					return false
			"flusso":
				if flusso_lordo() < float(v):
					return false
			"giorno":
				if giorno_max < int(v):
					return false
			"luogotenenti":
				if luogotenenti_messi < int(v):
					return false
			"donazione":
				if (fine == "dono") != bool(v):
					return false
			"giro_qualsiasi":
				var ok := false
				for g in giri:
					if float(giri[g].persone) >= float(v):
						ok = true
				if not ok:
					return false
			"anni_sara":
				if punteggio().sara_anni < float(v):
					return false
			"flag":
				if not ricordato(str(v)):
					return false
			"senza_flag":
				if ricordato(str(v)):
					return false
			"oggetto":
				if not oggetti.has(v):
					return false
			"senza_oggetto":
				if oggetti.has(v):
					return false
			"stat":
				if int(stat.get(v[0], 1)) < int(v[1]):
					return false
			"vittorie_azzardo":
				if vittorie_azzardo < int(v):
					return false
			"sabbia":
				if sirio < float(v):
					return false
			"pista":
				if not piste.has(v):
					return false
			"senza_pista":
				if piste.has(v):
					return false
			"contatto":
				if not contatti_noti.has(v):
					return false
	return true


func _opzione_valida(c: Dictionary, o: Dictionary) -> bool:
	if opzioni_fatte.has("%s/%s" % [c.id, o.id]) and not o.get("ripetibile", false):
		return false
	return vale(o.get("condizione", {}))


func opzioni_contatto(id: String) -> Array:
	var out: Array = []
	var c := contatto_dati(id)
	for o in c.get("opzioni", []):
		if _opzione_valida(c, o):
			out.append(o)
	return out


func ha_novita(id: String) -> bool:
	for o in opzioni_contatto(id):
		if not o.get("ripetibile", false):
			return true
	return false


## Opzione di un contatto. Al telefono costa qualche minuto; di persona il
## tempo lo conta il dialogo.
func scegli_opzione(cid: String, oid: String, al_telefono: bool = true) -> Dictionary:
	var c := contatto_dati(cid)
	for o in c.get("opzioni", []):
		if o.id != oid or not _opzione_valida(c, o):
			continue
		opzioni_fatte["%s/%s" % [cid, oid]] = true
		var esito := _esito()
		esito["risposta"] = risposta(o)
		for e in o.get("effetti", []):
			applica_effetto(e, esito)
		if al_telefono:
			esito.eventi.append_array(passa_tempo(float(par().minuti_telefonata)))
		return esito
	return _rifiuto("Non risponde.")


## Effetti condivisi da telefono, dialoghi, oggetti da esaminare e minigiochi.
func applica_effetto(e: Dictionary, esito: Dictionary) -> void:
	if e.has("apri_giro") and not giri_aperti.has(e.apri_giro):
		giri_aperti[e.apri_giro] = true
		var d: Dictionary = dati().giri[e.apri_giro]
		esito.notifiche.append("Nuovo giro: %s, a %s." % [d.nome, luogo_dati(d.sede).nome])
	if e.has("luogo") and not luoghi_noti.has(e.luogo):
		luoghi_noti[e.luogo] = true
		esito.notifiche.append("Nuovo luogo sulla mappa: %s" % luogo_dati(e.luogo).nome)
	if e.has("contatto") and incontra(e.contatto):
		esito.notifiche.append("Nuovo contatto in rubrica: %s" % contatto_dati(e.contatto).nome)
	if e.has("pista") and not piste.has(e.pista):
		piste[e.pista] = true
		esito.notifiche.append("Nuova grande mossa nel taccuino: %s" % dati().mosse[e.pista].nome)
	if e.has("flag"):
		ricorda(e.flag)
	if e.has("oggetto") and not oggetti.has(e.oggetto):
		oggetti[e.oggetto] = true
		esito.notifiche.append("Hai preso: %s" % dati().oggetti[e.oggetto].nome)
	if e.has("stat"):
		var s := aumenta_stat(e.stat[0], int(e.stat[1]))
		if s != "":
			esito.notifiche.append(s)
	if e.has("karma"):
		karma = clampf(karma + float(e.karma), -100.0, 100.0)
	if e.has("sabbia"):
		sirio += float(e.sabbia)
		esito.notifiche.append("Sabbia %s%s" % ["+" if float(e.sabbia) >= 0.0 else "", _ore(float(e.sabbia))])
	if e.has("polizia"):
		polizia = maxf(0.0, polizia + float(e.polizia))
	if e.has("rivalita"):
		rivalita = maxf(0.0, rivalita + float(e.rivalita))
	if e.has("fama"):
		fama = maxf(0.0, fama + float(e.fama))
	if e.has("uomini"):
		uomini = maxi(0, uomini + int(e.uomini))
		esito.notifiche.append("Uomini: %d" % uomini)
	if e.has("condona") and rate_debito > 0:
		var n := mini(int(e.condona), rate_debito)
		rate_debito -= n
		esito.notifiche.append("Rate a Rocco condonate: %d" % n)
	if e.has("debito"):
		rate_debito += int(e.debito)
		esito.notifiche.append("Nuove rate da pagare: %d" % int(e.debito))
	if e.has("sara"):
		sara += float(e.sara)
		esito.notifiche.append("Sara +%s" % _ore(float(e.sara)))
	if e.has("giro_persone"):
		var g: String = e.giro_persone[0]
		giri[g].persone = float(giri[g].persone) + float(e.giro_persone[1])
		esito.notifiche.append("%s +%d" % [str(dati().giri[g].persone).capitalize(), int(e.giro_persone[1])])
	_controlla_fine()


func risposta(o: Dictionary) -> String:
	var r: String = o.get("risposta", "")
	if r == "@stato_sara":
		var giorni := giorni_sara()
		if giorni > 14.0:
			return "Respira con l'aiuto della macchina. Le restano %.0f giorni. È tanto e non è niente." % giorni
		if giorni > 5.0:
			return "Regge. Le restano %.0f giorni. Si sveglia quando sente la sua voce, anche se non ci crede." % giorni
		if giorni > 1.5:
			return "Le restano %.0f giorni. Se ha qualcosa da darle, il momento si avvicina." % giorni
		return "Restano poche ore. Venga in reparto. Adesso."
	return r


func messaggi_non_letti() -> int:
	var n := 0
	for m in messaggi:
		if not m.letto:
			n += 1
	return n


# ================================================================ fine partita

func punteggio() -> Dictionary:
	var sa := maxf(sara, 0.0) / ORE_ANNO
	var si := maxf(sirio, 0.0) / ORE_ANNO
	var traguardo := "Non arriva a fine mese"
	for t in dati().traguardi:
		if sa >= float(t[0]):
			traguardo = t[1]
	return {"sara_anni": sa, "sirio_anni": si, "totale_anni": sa + si, "traguardo": traguardo,
		"vittoria_100_100": sa >= 100.0 and si >= 100.0}


func valuta_obiettivi(persistente: ImperoPersistente) -> Array:
	var note: Array = []
	if persistente == null:
		return note
	persistente.partite += 1
	if fine == "dono":
		persistente.record_anni = maxf(persistente.record_anni, punteggio().sara_anni)
	for ob in dati().obiettivi:
		if persistente.obiettivi.has(ob.id) or not vale(ob.condizione):
			continue
		persistente.obiettivi[ob.id] = true
		for s in ob.sblocca:
			if s.has("contatto") and not persistente.contatti.has(s.contatto):
				persistente.contatti.append(s.contatto)
			if s.has("luogo") and not persistente.luoghi.has(s.luogo):
				persistente.luoghi.append(s.luogo)
			if s.has("pista") and not persistente.piste.has(s.pista):
				persistente.piste.append(s.pista)
		note.append("%s. %s" % [ob.testo, ob.nota])
	return note
