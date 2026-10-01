class_name MondoRun
extends RefCounted
## Il mondo di Ledune attorno a una run: luoghi e spostamenti, telefono con
## contatti e dialoghi, occasioni che capitano, fame e sonno. Tutte le regole
## economiche restano in GameState; qui si aggiunge solo cio che il mondo
## impone, senza modificarlo:
## - ogni ora che passa costa la stessa ora a Sirio e a Sara (il core toglie
##   il costo solo al Tempo-Figlia, qui lo si toglie anche alla Sabbia-Padre);
## - un'azione si puo fare solo nel luogo giusto o tramite il contatto giusto;
## - fame e sonno danno un malus al tiro (parametro modificatore del core).

const GIORNI := ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"]
const ORA_INIZIO := 23.0
const ORE_PER_UNITA_MAPPA := 1.0 / 55.0
const ORE_VIAGGIO_MIN := 0.2
const FATTORE_AUTO := 0.45
const BENZINA_PIENO := 4
const PROBABILITA_INCIDENTE := 0.05
const ORE_TELEFONATA := 0.1

## [soglia ore, etichetta, malus al tiro]
const SOGLIE_SONNO := [[20.0, "Stanco", -1], [36.0, "Sfinito", -2], [60.0, "Allo stremo", -3]]
const SOGLIE_FAME := [[16.0, "Affamato", -1], [36.0, "Debilitato", -2], [72.0, "A digiuno", -3]]

const AZIONE_DORMIRE := "Riposare (dormire)"
const AZIONE_PASTO := "Comprare un pasto"
const AZIONE_AUTO := "Rubare un'auto (strumentale)"
const AZIONE_BENZINA := "Fare benzina"

static var _dati: Dictionary = {}

var stato: GameState
var luogo := "ospedale"
var luoghi_noti: Dictionary = {}
var contatti_noti: Dictionary = {}
var piste: Dictionary = {}
var flags: Dictionary = {}
var opzioni_fatte: Dictionary = {}
var occasioni_viste: Dictionary = {}
var successi_azione: Dictionary = {}
var successi_categoria: Dictionary = {}
var visite: Dictionary = {}
var ore_trascorse := 0.0
var ore_sveglio := 16.0
var ore_digiuno := 10.0
var auto := false
var benzina := 0
var messaggi: Array[Dictionary] = []
var notifiche: Array[String] = []
var giorno_max := 1
var _rng := RandomNumberGenerator.new()


static func dati() -> Dictionary:
	if _dati.is_empty():
		var f := FileAccess.open("res://data/mondo.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_dati = d
	return _dati


static func luogo_dati(id: String) -> Dictionary:
	for l in dati().get("luoghi", []):
		if l.id == id:
			return l
	return {}


static func contatto_dati(id: String) -> Dictionary:
	for c in dati().get("contatti", []):
		if c.id == id:
			return c
	return {}


func _init(stato_iniziale: GameState, persistente: MondoPersistente = null) -> void:
	stato = stato_iniziale
	_rng.seed = hash(stato.seed_run * 7919 + 17)
	for l in dati().get("luoghi", []):
		if l.get("iniziale", false):
			luoghi_noti[l.id] = true
	for c in dati().get("contatti", []):
		if c.get("iniziale", false):
			contatti_noti[c.id] = true
	if persistente != null:
		for id in persistente.luoghi:
			luoghi_noti[str(id)] = true
		for id in persistente.contatti:
			contatti_noti[str(id)] = true
	visite[luogo] = 1


# ------------------------------------------------------------------ tempo

func giorno() -> int:
	return int(floor((ORA_INIZIO + ore_trascorse) / 24.0)) + 1


func ora_testo() -> String:
	var t := ORA_INIZIO + ore_trascorse
	var g := int(floor(t / 24.0))
	var h := fmod(t, 24.0)
	var nome: String = GIORNI[clampi(g, 0, GIORNI.size() - 1)] if g < GIORNI.size() else "Giorno %d" % (g + 1)
	return "%s %02d:%02d" % [nome, int(h), int(fmod(h, 1.0) * 60.0)]


func e_notte() -> bool:
	var h := fmod(ORA_INIZIO + ore_trascorse, 24.0)
	return h >= 21.0 or h < 6.0


## Tempo che passa fuori dal core (viaggi, telefonate, azioni del mondo):
## costa uguale a padre e figlia.
func _passa_tempo(ore: float) -> void:
	stato.tempo_figlia_ore -= ore
	stato.sabbia_padre_ore -= ore
	_avanza_orologio(ore)
	stato._controlla_fine_partita()


func _avanza_orologio(ore: float) -> void:
	var giorno_prima := giorno()
	ore_trascorse += ore
	ore_sveglio += ore
	ore_digiuno += ore
	var g := giorno()
	giorno_max = maxi(giorno_max, g)
	if g > giorno_prima:
		var testo: String = dati().get("messaggi_giornalieri", {}).get(str(g), "")
		if testo != "":
			messaggi.append({"da": "venti", "testo": testo, "letto": false})
			notifiche.append("Nuovo messaggio dalla dottoressa Venti.")


## Dopo ogni risoluzione del core: il padre paga le ore spese.
func _dopo_core(r: Dictionary) -> void:
	var costo: float = r.get("costo_tempo_figlia_ore", 0.0)
	stato.sabbia_padre_ore -= costo
	_avanza_orologio(costo)
	stato._controlla_fine_partita()


# ------------------------------------------------------------------ bisogni

static func _livello(ore: float, soglie: Array) -> Array:
	var esito := ["", 0, 0]
	for i in soglie.size():
		if ore >= soglie[i][0]:
			esito = [soglie[i][1], soglie[i][2], i + 1]
	return esito


func stato_sonno() -> Array:
	var l := _livello(ore_sveglio, SOGLIE_SONNO)
	if l[0] == "":
		l[0] = "Lucido"
	return l


func stato_fame() -> Array:
	var l := _livello(ore_digiuno, SOGLIE_FAME)
	if l[0] == "":
		l[0] = "Sazio"
	return l


## Malus al tiro sommato (massimo -4) e Svantaggio solo al livello estremo.
func malus_bisogni() -> Dictionary:
	var s := stato_sonno()
	var f := stato_fame()
	var mod := maxi(int(s[1]) + int(f[1]), -4)
	var svantaggio: bool = int(s[2]) >= 3 or int(f[2]) >= 3
	return {"modificatore": mod, "modo": DiceSystem.RollMode.SVANTAGGIO if svantaggio else DiceSystem.RollMode.NORMALE}


# ------------------------------------------------------------------ condizioni

func vale(cond: Dictionary) -> bool:
	for k in cond:
		var v = cond[k]
		match k:
			"riuscita":
				if not stato.azione_completata_con_successo(v):
					return false
			"successi":
				if _conta_successi(v) < int(v.get("min", 1)):
					return false
			"rango":
				if int(stato.tracce_raggiunte.get(v.traccia, 0)) < int(v.min):
					return false
			"rango_qualsiasi":
				var ok := false
				for t in stato.tracce_raggiunte:
					if int(stato.tracce_raggiunte[t]) >= int(v):
						ok = true
				if not ok:
					return false
			"flag":
				if not flags.has(v):
					return false
			"non_flag":
				if flags.has(v):
					return false
			"visite":
				if int(visite.get(v.luogo, 0)) < int(v.min):
					return false
			"giorno_min":
				if giorno_max < int(v):
					return false
			"auto":
				if auto != bool(v):
					return false
			"polizia_min":
				if stato.attenzione_polizia < float(v):
					return false
			"donazione":
				if stato.donation_made != bool(v):
					return false
	return true


func _conta_successi(v: Dictionary) -> int:
	var n := 0
	for c in v.get("categorie", []):
		n += int(successi_categoria.get(c, 0))
	for a in v.get("azioni", []):
		n += int(successi_azione.get(a, 0))
	return n


## Suggerimento mostrato su un'azione presente ma non ancora disponibile.
## Vuoto = l'azione resta nascosta.
func suggerimento(cond: Dictionary) -> String:
	if cond.has("riuscita"):
		return "Prima serve: " + str(cond.riuscita).split(" (")[0].to_lower()
	if cond.has("successi"):
		return "Serve più mestiere nel giro"
	return ""


# ------------------------------------------------------------------ luoghi

func luoghi_visibili() -> Array:
	var out: Array = []
	for l in dati().get("luoghi", []):
		if luoghi_noti.has(l.id):
			out.append(l)
	return out


func stima_viaggio(dest: String) -> float:
	var a: Array = luogo_dati(luogo).get("pos", [0, 0])
	var b: Array = luogo_dati(dest).get("pos", [0, 0])
	var dist := Vector2(a[0], a[1]).distance_to(Vector2(b[0], b[1]))
	var ore := ORE_VIAGGIO_MIN + dist * ORE_PER_UNITA_MAPPA
	if auto and benzina > 0:
		ore *= FATTORE_AUTO
	return ore


func viaggia(dest: String) -> Dictionary:
	if stato.is_over:
		return {"rifiutata": true, "motivo": "La settimana è finita."}
	if dest == luogo:
		return {"rifiutata": true, "motivo": "Sei già qui."}
	if not luoghi_noti.has(dest):
		return {"rifiutata": true, "motivo": "Non conosci questo posto."}
	var in_auto := auto and benzina > 0
	var ore := stima_viaggio(dest) * _rng.randf_range(0.85, 1.15)
	var incidente := _rng.randf() < PROBABILITA_INCIDENTE
	var ritardo := 0.0
	if incidente:
		ritardo = _rng.randf_range(1.0, 3.0)
	if in_auto:
		benzina -= 1
	_passa_tempo(ore + ritardo)
	luogo = dest
	visite[dest] = int(visite.get(dest, 0)) + 1
	var testo := "Arrivi a %s." % luogo_dati(dest).nome
	if incidente:
		testo = ("Una gomma a terra sulla circonvallazione. " if in_auto else "Un tram che non arriva, poi un altro pieno. ") + testo
	return {"ore": ore + ritardo, "incidente": incidente, "in_auto": in_auto, "testo": testo}


## Cosa si puo fare nel luogo corrente, gia filtrato per il giocatore.
func azioni_qui() -> Array:
	var l := luogo_dati(luogo)
	var out: Array = []
	if l.is_empty():
		return out
	var condizioni: Dictionary = l.get("condizioni_azioni", {})
	for nome in l.get("azioni", []):
		var azione := _azione(nome)
		if azione == null:
			continue
		var cond: Dictionary = condizioni.get(nome, {})
		var ok := vale(cond)
		var hint := "" if ok else suggerimento(cond)
		if not ok and hint == "":
			continue
		var usata: bool = not stato.azione_disponibile(azione)
		out.append({"tipo": "azione", "azione": azione, "disponibile": ok and not usata, "nota": hint if not ok else ("Già fatto in questa settimana" if usata else "")})
	for sp in l.get("speciali", []):
		var tipo: String = sp.get("tipo", "speciale")
		if tipo == "cashin":
			if stato.cash_in_disponibile():
				out.append({"tipo": "cashin", "speciale": sp, "disponibile": true, "nota": ""})
			continue
		if tipo == "dona":
			out.append({"tipo": "dona", "speciale": sp, "disponibile": not stato.donation_made, "nota": ""})
			continue
		var fatta: bool = opzioni_fatte.has("speciale:" + str(sp.id)) and not sp.get("ripetibile", false)
		if fatta:
			continue
		out.append({"tipo": "speciale", "speciale": sp, "disponibile": vale(sp.get("condizione", {})), "nota": ""})
	for nome in l.get("sottotrame", []):
		if not piste.has(nome):
			continue
		var sub := _sottotrama(nome)
		if sub == null:
			continue
		var tentata: bool = stato.azioni_uniche_usate.has("sottotrama:%s" % nome)
		out.append({"tipo": "sottotrama", "sottotrama": sub, "disponibile": not tentata and stato.sottotrama_disponibile(sub), "nota": "Già tentata" if tentata else ""})
	return out


static func _azione(nome: String) -> ActionData:
	for a: ActionData in ActionDatabase.get_all():
		if a.nome == nome:
			return a
	return null


static func _sottotrama(nome: String) -> SubplotData:
	for s: SubplotData in SubplotDatabase.get_all():
		if s.nome == nome:
			return s
	return null


# ------------------------------------------------------------------ esecuzione

func _esito_vuoto() -> Dictionary:
	return {"risultati": [], "notifiche": [], "testi": []}


func _rifiuto(motivo: String) -> Dictionary:
	return {"rifiutata": true, "motivo": motivo, "risultati": [], "notifiche": [], "testi": []}


## Esegue un'azione del core. Se da_luogo, deve essere offerta qui.
func esegui_azione(nome: String, da_luogo: bool = true) -> Dictionary:
	if stato.is_over:
		return _rifiuto("La settimana è finita.")
	var azione := _azione(nome)
	if azione == null:
		return _rifiuto("Azione sconosciuta.")
	if da_luogo:
		var trovata := false
		for voce in azioni_qui():
			if voce.tipo == "azione" and voce.azione.nome == nome and voce.disponibile:
				trovata = true
		if not trovata:
			return _rifiuto("Non qui, non adesso.")
	var m := malus_bisogni()
	var r := stato.applica_azione_con_dado(azione, m.modo, m.modificatore)
	if r.has("rifiutata"):
		return _rifiuto(str(r.motivo))
	_dopo_core(r)
	if r.successo:
		successi_azione[nome] = int(successi_azione.get(nome, 0)) + 1
		successi_categoria[azione.categoria] = int(successi_categoria.get(azione.categoria, 0)) + 1
		match nome:
			AZIONE_AUTO:
				auto = true
				benzina = BENZINA_PIENO
				notifiche.append("Hai una macchina. Ti sposti in metà del tempo, finché c'è benzina.")
			AZIONE_BENZINA:
				benzina = BENZINA_PIENO
	if nome == AZIONE_DORMIRE:
		ore_sveglio = 0.0
	elif nome == AZIONE_PASTO and r.successo:
		ore_digiuno = 0.0
	var esito := _esito_vuoto()
	esito.risultati.append({"titolo": nome, "testo": TestiDemo.esito_azione(nome, r.successo), "r": r})
	return esito


func esegui_traccia(traccia: String, rango: int) -> Dictionary:
	if stato.is_over:
		return _rifiuto("La settimana è finita.")
	var riga := TrackDatabase.get_riga(traccia, rango)
	if riga == null or not stato.traccia_disponibile(riga):
		return _rifiuto("Non è il momento.")
	var m := malus_bisogni()
	var r := stato.applica_traccia(riga, m.modo, m.modificatore)
	if r.has("rifiutata"):
		return _rifiuto(str(r.motivo))
	_dopo_core(r)
	var esito := _esito_vuoto()
	esito.risultati.append({"titolo": "%s: %s" % [traccia.split(" (")[0], riga.nome_rango], "testo": TestiDemo.esito_traccia(traccia, riga.nome_rango, r.successo), "r": r})
	return esito


func esegui_sottotrama(nome: String) -> Dictionary:
	if stato.is_over:
		return _rifiuto("La settimana è finita.")
	var sub := _sottotrama(nome)
	if sub == null or not piste.has(nome):
		return _rifiuto("Non sai ancora niente di questa storia.")
	var m := malus_bisogni()
	var r := stato.applica_sottotrama(sub, m.modo, m.modificatore)
	if r.has("rifiutata"):
		return _rifiuto(str(r.motivo))
	_dopo_core(r)
	var esito := _esito_vuoto()
	esito.risultati.append({"titolo": TestiDemo.nome_sottotrama_visibile(nome), "testo": TestiDemo.esito_sottotrama(nome, r.successo), "r": r})
	return esito


func esegui_cashin() -> Dictionary:
	if stato.is_over or luogo != "casa":
		return _rifiuto("Questa mossa si prepara a casa.")
	var m := malus_bisogni()
	var r := stato.applica_cash_in(m.modo, m.modificatore)
	if r.has("rifiutata"):
		return _rifiuto(str(r.motivo))
	_dopo_core(r)
	var esito := _esito_vuoto()
	var testo := "Tutte le tue posizioni, giocate in una notte. Ledune tace un momento." if r.successo else "Un pezzo cede e trascina gli altri. Quello che avevi costruito è fumo."
	esito.risultati.append({"titolo": "Mettere insieme i pezzi", "testo": testo, "r": r})
	return esito


func esegui_speciale(id: String) -> Dictionary:
	if stato.is_over:
		return _rifiuto("La settimana è finita.")
	for voce in azioni_qui():
		if voce.tipo == "speciale" and voce.speciale.id == id and voce.disponibile:
			var sp: Dictionary = voce.speciale
			var ore: float = sp.get("ore", 0.0)
			if ore > 0.0:
				_passa_tempo(ore)
			opzioni_fatte["speciale:" + id] = true
			var esito := _esito_vuoto()
			esito.testi.append(str(sp.get("descrizione", "")))
			_applica_effetti(sp.get("effetti", []), esito)
			return esito
	return _rifiuto("Non qui, non adesso.")


func dona(ore: float) -> Dictionary:
	if luogo != "ospedale":
		return {"successo": false, "motivo": "Si dona in reparto, accanto a Sara."}
	return stato.dona(ore)


# ------------------------------------------------------------------ effetti

func _applica_effetti(effetti: Array, esito: Dictionary) -> bool:
	var riuscito := true
	for e in effetti:
		if e.has("azione"):
			var r := esegui_azione(e.azione, false)
			esito.risultati.append_array(r.risultati)
			if r.has("rifiutata") or r.risultati.is_empty():
				riuscito = false
			else:
				riuscito = riuscito and bool(r.risultati[-1].r.successo)
		elif e.has("traccia"):
			var r := esegui_traccia(e.traccia, int(e.rango))
			esito.risultati.append_array(r.risultati)
			riuscito = not r.risultati.is_empty() and bool(r.risultati[-1].r.successo)
		elif e.has("sottotrama"):
			var r := esegui_sottotrama(e.sottotrama)
			esito.risultati.append_array(r.risultati)
		elif e.has("luogo"):
			if not luoghi_noti.has(e.luogo):
				luoghi_noti[e.luogo] = true
				esito.notifiche.append("Nuovo luogo sulla mappa: %s" % luogo_dati(e.luogo).nome)
		elif e.has("contatto"):
			if not contatti_noti.has(e.contatto):
				contatti_noti[e.contatto] = true
				esito.notifiche.append("Nuovo contatto in rubrica: %s" % contatto_dati(e.contatto).nome)
		elif e.has("pista"):
			if not piste.has(e.pista):
				piste[e.pista] = true
				esito.notifiche.append("Nuova pista nel taccuino: %s" % TestiDemo.nome_sottotrama_visibile(e.pista))
		elif e.has("flag"):
			flags[e.flag] = true
		elif e.has("pasto"):
			ore_digiuno = 0.0
		elif e.has("ore"):
			_passa_tempo(float(e.ore))
	return riuscito


# ------------------------------------------------------------------ telefono

func contatti_visibili() -> Array:
	var out: Array = []
	for c in dati().get("contatti", []):
		if contatti_noti.has(c.id):
			out.append(c)
	return out


func _opzione_valida(c: Dictionary, o: Dictionary) -> bool:
	var chiave := "%s/%s" % [c.id, o.id]
	if opzioni_fatte.has(chiave) and not o.get("ripetibile", false):
		return false
	if not vale(o.get("condizione", {})):
		return false
	for e in o.get("effetti", []):
		if e.has("traccia"):
			var riga := TrackDatabase.get_riga(e.traccia, int(e.rango))
			if riga == null or not stato.traccia_disponibile(riga):
				return false
		if e.has("azione"):
			var a := _azione(e.azione)
			if a == null or not stato.azione_disponibile(a):
				return false
	return true


func opzioni_contatto(id: String) -> Array:
	var c := contatto_dati(id)
	var out: Array = []
	for o in c.get("opzioni", []):
		if _opzione_valida(c, o):
			out.append(o)
	return out


func scegli_opzione(cid: String, oid: String) -> Dictionary:
	if stato.is_over:
		return _rifiuto("La settimana è finita.")
	var c := contatto_dati(cid)
	for o in c.get("opzioni", []):
		if o.id != oid:
			continue
		if not _opzione_valida(c, o):
			return _rifiuto("Non risponde.")
		opzioni_fatte["%s/%s" % [cid, oid]] = true
		var esito := _esito_vuoto()
		esito["risposta"] = risposta(o)
		var ha_tiro := false
		for e in o.get("effetti", []):
			if e.has("azione") or e.has("traccia") or e.has("sottotrama"):
				ha_tiro = true
		if not ha_tiro:
			_passa_tempo(ORE_TELEFONATA)
		var ok := _applica_effetti(o.get("effetti", []), esito)
		if ok and o.has("se_riesce"):
			_applica_effetti(o.se_riesce, esito)
		return esito
	return _rifiuto("Non risponde.")


func risposta(o: Dictionary) -> String:
	var r: String = o.get("risposta", "")
	if r == "@stato_sara":
		var ore := stato.tempo_figlia_ore
		if ore > 120.0:
			return "Respira con l'aiuto della macchina. Le restano %.0f ore. È tanto e non è niente." % ore
		if ore > 48.0:
			return "Regge. Le restano %.0f ore. Si sveglia quando sente la sua voce, anche se non ci crede." % ore
		if ore > 12.0:
			return "Le restano %.0f ore. Se ha qualcosa da darle, il momento si avvicina." % ore
		return "Restano %.0f ore. Venga in reparto. Adesso." % ore
	return r


func messaggi_non_letti() -> int:
	var n := 0
	for m in messaggi:
		if not m.letto:
			n += 1
	return n


func segna_letti() -> void:
	for m in messaggi:
		m.letto = true


# ------------------------------------------------------------------ occasioni

func cerca_occasione(al_viaggio: bool) -> Dictionary:
	if stato.is_over or not stato.patto_in_sospeso.is_empty():
		return {}
	for oc in dati().get("occasioni", []):
		if bool(oc.get("al_viaggio", false)) != al_viaggio:
			continue
		var luoghi: Array = oc.get("luoghi", [])
		if not luoghi.is_empty() and not luoghi.has(luogo):
			continue
		if int(occasioni_viste.get(oc.id, 0)) >= int(oc.get("max", 1)):
			continue
		if not vale(oc.get("condizione", {})):
			continue
		if not _occasione_ancora_utile(oc):
			continue
		if _rng.randf() < float(oc.get("probabilita", 0.0)):
			occasioni_viste[oc.id] = int(occasioni_viste.get(oc.id, 0)) + 1
			return oc
	return {}


func _occasione_ancora_utile(oc: Dictionary) -> bool:
	for s in oc.scelte:
		for e in s.effetti:
			if e.has("azione"):
				var a := _azione(e.azione)
				if a != null and stato.azione_disponibile(a):
					return true
			elif e.has("contatto") and not contatti_noti.has(e.contatto):
				return true
			elif e.has("pista") and not piste.has(e.pista):
				return true
	return false


func risolvi_occasione(id: String, indice: int) -> Dictionary:
	for oc in dati().get("occasioni", []):
		if oc.id == id:
			if indice < 0 or indice >= oc.scelte.size():
				return _rifiuto("Scelta non valida.")
			var esito := _esito_vuoto()
			_applica_effetti(oc.scelte[indice].effetti, esito)
			return esito
	return _rifiuto("Occasione sconosciuta.")


# ------------------------------------------------------------------ obiettivi

func valuta_obiettivi(persistente: MondoPersistente) -> Array:
	var note: Array = []
	if persistente == null:
		return note
	persistente.run_giocate += 1
	for ob in dati().get("obiettivi", []):
		if persistente.obiettivi.has(ob.id):
			continue
		if not vale(ob.condizione):
			continue
		persistente.obiettivi[ob.id] = true
		for s in ob.sblocca:
			if s.has("contatto") and not persistente.contatti.has(s.contatto):
				persistente.contatti.append(s.contatto)
			if s.has("luogo") and not persistente.luoghi.has(s.luogo):
				persistente.luoghi.append(s.luogo)
		note.append("%s. %s" % [ob.testo, ob.get("nota", "")])
	return note
