class_name DialogoSystem
extends RefCounted
## Dialoghi di persona (data/esplorazione.json, sezione "dialoghi"). Logica
## pura. Ogni opzione appartiene a una di quattro categorie:
##   fissa    - lore e avanzamento, sempre visibile finché ha senso;
##   stat     - richiede una soglia di Carisma, Intuizione o Freddezza; si vede
##              anche quando è chiusa, con il requisito, così il giocatore sa
##              cosa gli manca;
##   memoria  - compare solo se nella stessa partita è successo qualcosa
##              (un flag, un oggetto, una persona già incontrata);
##   seed     - generata dal seed della partita: una variante su più possibili
##              (offerte, retroscena, piccoli eventi), stabile per tutta la run.
## Ogni risposta costa minuti di vita a Sirio e a Sara.

const CATEGORIE := ["fissa", "stat", "memoria", "seed"]
const MINUTI_DEFAULT := 4

static var _dati: Dictionary = {}


static func dati() -> Dictionary:
	if _dati.is_empty():
		var f := FileAccess.open("res://data/esplorazione.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_dati = d
	return _dati


static func dialogo(npc: String) -> Dictionary:
	return dati().get("dialoghi", {}).get(npc, {})


static func nodo(npc: String, id: String) -> Dictionary:
	return dialogo(npc).get("nodi", {}).get(id, {})


static func _chiave(npc: String, o: Dictionary) -> String:
	return "dlg/%s/%s" % [npc, o.id]


## Le opzioni del nodo, già filtrate. Ognuna porta "aperta" (si può scegliere)
## e "requisito" (testo del requisito, per le opzioni stat chiuse).
static func opzioni(s: ImperoState, npc: String, id_nodo: String) -> Array:
	var out: Array = []
	var d := dialogo(npc)
	var n := nodo(npc, id_nodo)
	var grezze: Array = n.get("opzioni", []).duplicate()
	for pool in n.get("seed", []):
		var varianti: Array = d.get("seed", {}).get(pool, [])
		if not varianti.is_empty():
			var v: Dictionary = varianti[s.variante("%s/%s" % [npc, pool], varianti.size())].duplicate()
			v["categoria"] = "seed"
			if not v.has("id"):
				v["id"] = "%s_%d" % [pool, s.variante("%s/%s" % [npc, pool], varianti.size())]
			grezze.append(v)
	if n.get("telefono", false) and d.has("contatto"):
		for o in s.opzioni_contatto(d.contatto):
			grezze.append({"id": "tel_" + o.id, "testo": o.testo, "categoria": "fissa", "contatto_opzione": o.id,
				"ripetibile": o.get("ripetibile", false), "minuti": 5})
	for o in grezze:
		if not o.get("ripetibile", false) and s.opzioni_fatte.has(_chiave(npc, o)):
			continue
		if not s.vale(o.get("condizione", {})):
			continue
		var c: Dictionary = o.duplicate()
		c["categoria"] = o.get("categoria", "fissa")
		c["aperta"] = s.vale(o.get("requisito", {}))
		c["requisito_testo"] = requisito_testo(o.get("requisito", {}))
		c["minuti"] = int(o.get("minuti", MINUTI_DEFAULT))
		out.append(c)
	var ordine := {"fissa": 0, "stat": 1, "memoria": 2, "seed": 3}
	var chiave := func(o: Dictionary) -> int:
		return 9 if o.id == "vado" else int(ordine.get(o.categoria, 0))
	var ordinate: Array = []
	for k in [0, 1, 2, 3, 9]:
		for o in out:
			if chiave.call(o) == k:
				ordinate.append(o)
	return ordinate


static func requisito_testo(r: Dictionary) -> String:
	var parti: Array[String] = []
	if r.has("stat"):
		parti.append("%s %d" % [ImperoState.dati().stat[r.stat[0]].nome, int(r.stat[1])])
	if r.has("sabbia"):
		parti.append("%dh di sabbia" % int(r.sabbia))
	if r.has("uomini"):
		parti.append("%d uomini" % int(r.uomini))
	return ", ".join(parti)


## Sceglie un'opzione. Restituisce la risposta, le espressioni, il nodo
## successivo ("" se il dialogo finisce) e l'esito (notifiche, eventi).
static func scegli(s: ImperoState, npc: String, id_nodo: String, opzione: Dictionary) -> Dictionary:
	var esito := {"risultati": [], "eventi": [], "notifiche": []}
	if not opzione.get("aperta", true):
		return {"rifiutata": true, "motivo": "Non ce la fai: %s." % opzione.requisito_testo}
	if not opzione.get("ripetibile", false):
		s.opzioni_fatte[_chiave(npc, opzione)] = true
	var risposta: String = opzione.get("risposta", "")
	if opzione.has("contatto_opzione"):
		var r := s.scegli_opzione(dialogo(npc).contatto, opzione.contatto_opzione, false)
		risposta = str(r.get("risposta", ""))
		esito.notifiche.append_array(r.get("notifiche", []))
	if opzione.has("costo"):
		s.sirio -= float(opzione.costo)
		esito.notifiche.append("Paghi %s." % ImperoState._ore(float(opzione.costo)))
	for e in opzione.get("effetti", []):
		s.applica_effetto(e, esito)
	if risposta.begins_with("@"):
		risposta = s.risposta({"risposta": risposta})
	esito.eventi.append_array(s.attendi(float(opzione.minuti)))
	var prossimo: String = opzione.get("vai", id_nodo)
	if prossimo == "fine":
		prossimo = ""
	return {"risposta": risposta, "espressione": opzione.get("espressione", "neutro"),
		"sirio": opzione.get("sirio", "neutro"), "prossimo": prossimo, "esito": esito}


## Il primo nodo: quello d'inizio, o un nodo di ritorno se c'è un flag.
static func nodo_iniziale(s: ImperoState, npc: String) -> String:
	var d := dialogo(npc)
	for r in d.get("ritorni", []):
		if s.vale(r.condizione):
			return r.nodo
	return d.get("inizio", "inizio")
