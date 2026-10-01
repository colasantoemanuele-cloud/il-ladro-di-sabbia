class_name TestiDemo
extends RefCounted
## Testi della demo: intro, tutorial, citazioni, bivi, messaggi di esito.
## Regole editoriali: tono asciutto, nessun trattino lungo, nessun punto
## esclamativo di troppo. I messaggi di esito stanno in data/esiti_azioni.json
## (generato da tools/genera_esiti.py).

const INTRO := "Mi chiamo Sirio. A Ledune rubavo per chi pagava meglio. Ora rubo tempo, che qui si chiama sabbia ed è l'unica moneta che nessuno falsifica.\n\n" \
	+ "Serena è morta mettendo al mondo Sara. Per tenere in vita mia figlia ho ceduto quasi tutto quello che avevo. A me restano ventiquattro ore. A lei ne restano centosessantotto, una settimana.\n\n" \
	+ "Ho sette giorni per mettere insieme più sabbia che posso. Poi, una volta sola, potrò donarne a Sara. Non si torna indietro.\n\n" \
	+ "Non cerco perdono. Cerco ore."

const TUTORIAL := [
	{
		"titolo": "Due orologi",
		"testo": "Hai due orologi. La Sabbia-Padre sono le tue ore: se arrivano a zero, muori. Il Tempo-Figlia è la settimana di Sara: ogni azione ne consuma un pezzo. Se finisce, finisce tutto. Scegli cosa vale la pena fare.",
	},
	{
		"titolo": "Il dado",
		"testo": "Ogni azione costa ore di Tempo-Figlia e rende sabbia. Il rischio decide la difficoltà: tiri un d20. Un venti passa sempre. Un uno non perdona. Se fallisci, le ore sono già andate. Il lavoro onesto rende poco ma non tradisce.",
	},
	{
		"titolo": "La strada",
		"testo": "La polizia guarda, i rivali ricordano, la gente parla. Il Karma ti segue da una vita all'altra. Le tracce sono strade lunghe: un passo falso chiude la porta. Quando decidi, dona. Una volta sola.",
	},
]

const CITAZIONI := [
	"Il tempo non si ruba. Si consuma.",
	"Ogni granello è un giorno che qualcuno non vivrà.",
	"In questa città tutti hanno un prezzo. Io ho una scadenza.",
	"La sabbia non chiede da dove viene. Solo dove va.",
	"Mia figlia dorme. Io conto.",
	"Chi ha fretta paga due volte. Chi non ne ha, non esiste.",
	"Il perdono è una moneta che qui non si spende.",
	"Si invecchia in fretta quando si vende il futuro.",
]

const BIVIO_INIZIO := "demo_prima_notte"
const BIVIO_AGGANCIO := "demo_primo_gradino"
const BIVIO_POCHE_ORE := "demo_poche_ore"

static var _esiti: Dictionary = {}


static func citazione_casuale() -> String:
	return CITAZIONI[randi() % CITAZIONI.size()]


static func _carica() -> void:
	if not _esiti.is_empty():
		return
	var f := FileAccess.open("res://data/esiti_azioni.json", FileAccess.READ)
	if f == null:
		_esiti = {"azioni": {}, "tracce": {}, "sottotrame": {}}
		return
	var d = JSON.parse_string(f.get_as_text())
	_esiti = d if d is Dictionary else {"azioni": {}, "tracce": {}, "sottotrame": {}}


static func esito_azione(nome: String, successo: bool) -> String:
	_carica()
	var e: Dictionary = _esiti.get("azioni", {}).get(nome, {})
	return e.get("ok" if successo else "ko", "Fatto." if successo else "Non è andata.")


static func esito_traccia(traccia: String, nome_rango: String, successo: bool) -> String:
	_carica()
	var chiave := traccia.split(" ")[0]
	var e: Dictionary = _esiti.get("tracce", {}).get(chiave, {})
	var testo: String = e.get("ok" if successo else "ko", "Un passo avanti." if successo else "Un passo falso.")
	return testo.replace("{n}", nome_rango)


static func esito_sottotrama(nome: String, successo: bool) -> String:
	_carica()
	var tutti: Dictionary = _esiti.get("sottotrame", {})
	var e: Dictionary = tutti.get(nome, {})
	if e.is_empty():
		for k in tutti:
			if nome.begins_with(k):
				e = tutti[k]
				break
	return e.get("ok" if successo else "ko", "Fatto." if successo else "Non è andata.")


static func nome_sottotrama_visibile(nome: String) -> String:
	if nome.begins_with("Il crollo della casata"):
		return "Il crollo della casata Sabbiedoro"
	return nome


# ------------------------------------------------------------------ bivi

static func bivio(id: String) -> BivioSystem.Bivio:
	match id:
		BIVIO_INIZIO:
			return BivioSystem.Bivio.new(id, "La prima notte", [
				BivioSystem.Opzione.new("A passi piccoli", "Bussare ai vecchi amici, uno alla volta. Karma +4."),
				BivioSystem.Opzione.new("Senza guardare", "Prendere subito quello che la strada offre. Sabbia +2h, Attenzione Polizia +10."),
			] as Array[BivioSystem.Opzione])
		BIVIO_AGGANCIO:
			return BivioSystem.Bivio.new(id, "Il primo gradino", [
				BivioSystem.Opzione.new("La scorciatoia", "Qualcuno ti offre una porta laterale. Sabbia +3h, Karma -4."),
				BivioSystem.Opzione.new("Da solo", "Salire senza favori. Karma +3."),
			] as Array[BivioSystem.Opzione])
		_:
			return BivioSystem.Bivio.new(id, "Poche ore", [
				BivioSystem.Opzione.new("Chiedere in prestito", "Un vecchio compagno anticipa ore e tiene il conto. Sabbia +4h, Rivalità Criminale +15."),
				BivioSystem.Opzione.new("Vendere un ricordo", "Un collezionista paga il ricordo di un compleanno. Sabbia +3h, Karma -2."),
				BivioSystem.Opzione.new("Stringere i denti", "Niente favori, niente debiti. Karma +3."),
			] as Array[BivioSystem.Opzione])


const TESTO_BIVIO := {
	BIVIO_INIZIO: "Sara dorme in ospedale. Fuori piove sabbia sottile e le strade sono vuote. Devi decidere come muoverti.",
	BIVIO_AGGANCIO: "Hai un piede dentro. Qualcuno sa che ne vuoi di più e ti offre una strada più corta, a un prezzo che non dice.",
	BIVIO_POCHE_ORE: "Il conto si stringe. Ti restano poche ore e la strada non fa sconti. Qualcuno, nel buio, si offre di aiutarti.",
}

## Effetti minimi dei bivi: valori fissi, sommati direttamente allo stato.
const EFFETTI_BIVIO := {
	BIVIO_INIZIO: [{"karma": 4.0}, {"sabbia": 2.0, "polizia": 10.0}],
	BIVIO_AGGANCIO: [{"sabbia": 3.0, "karma": -4.0}, {"karma": 3.0}],
	BIVIO_POCHE_ORE: [{"sabbia": 4.0, "rivalita": 15.0}, {"sabbia": 3.0, "karma": -2.0}, {"karma": 3.0}],
}


static func applica_effetti_bivio(stato: GameState, id: String, indice: int) -> void:
	var lista: Array = EFFETTI_BIVIO.get(id, [])
	if indice < 0 or indice >= lista.size():
		return
	var e: Dictionary = lista[indice]
	stato.sabbia_padre_ore += e.get("sabbia", 0.0)
	stato.karma = clampf(stato.karma + e.get("karma", 0.0), -GameState.RISORSA_MAX, GameState.RISORSA_MAX)
	stato.attenzione_polizia = clampf(stato.attenzione_polizia + e.get("polizia", 0.0), 0.0, GameState.RISORSA_MAX)
	stato.rivalita_criminale = clampf(stato.rivalita_criminale + e.get("rivalita", 0.0), 0.0, GameState.RISORSA_MAX)
