class_name GameState
extends RefCounted
## Stato di una run (effimero, solo in memoria — vedi CLAUDE.md,
## "architettura di salvataggio a due livelli"). Nessuna dipendenza dalla
## scena: usabile sia dal loop di gioco sia dal simulatore headless.

enum EndReason { NONE, FIGLIA_MORTA, PADRE_MORTO, DONAZIONE_FINALE_SCELTA }

const TEMPO_FIGLIA_INIZIALE := 168.0
const SABBIA_PADRE_INIZIALE := 24.0

## Difficoltà crescente (design doc 12.5, sbloccata "dopo il primo
## traguardo 100+100 anni" — il gate è responsabilità del chiamante,
## PlayerProfile.traguardo_100_100_raggiunto, non di GameState, che si
## fida del livello ricevuto). Per livello: Sabbia-Padre iniziale -4h
## (24h -> 20h -> 16h..., come da design doc), rischio base di ogni
## azione/traccia/sottotrama/cash-in +5% (non applicato agli eventi
## casuali automatici né al Patto con lo Stregatto: non sono "azioni"
## scelte dal giocatore nello stesso senso). Clamp a un floor di 1h
## invece di un livello massimo esplicito (non specificato dal design
## doc): a livello 6 la formula darebbe 0h, ingiocabile da subito —
## scelta tecnica, non di design.
const SABBIA_PADRE_RIDUZIONE_PER_LIVELLO := 4.0
const RISCHIO_AUMENTO_PER_LIVELLO := 0.05
const SABBIA_PADRE_MINIMA_DIFFICOLTA := 1.0

var livello_difficolta: int = 0

var tempo_figlia_ore: float = TEMPO_FIGLIA_INIZIALE
var sabbia_padre_ore: float = SABBIA_PADRE_INIZIALE

var donation_made: bool = false
var donated_ore: float = 0.0

## Le 5 risorse del design doc (sezione 7.2). Attenzione Polizia/Rivalità
## Criminale/Fama Pubblica: 0-100, per run, azzerate a inizio run, salgono
## e scendono SOLO tramite azioni dedicate (decisione confermata
## dall'autore in Fase 10: MAI passivamente nel tempo). `karma` è l'unica
## pensata per persistere tra le run (design doc 7.2): viene inizializzata
## dal Profilo Persistente all'avvio della run (Fase 7, vedi
## scripts/core/player_profile.gd) invece di partire sempre da zero come
## le altre, e accumula tra le run senza alcuna correzione artificiale
## (decisione confermata dall'autore in Fase 10: il meccanismo di
## accumulo grezzo tra le run è sufficiente da solo).
var attenzione_polizia: float = 0.0
var rivalita_criminale: float = 0.0
var fama_pubblica: float = 0.0
var karma: float = 0.0

## Fede del Culto e Fede della Setta (Fase 10, design doc 7.2): due
## contatori SEPARATI (0-100, per run), NON coincidono col Rango della
## traccia Religiosa/Occulto. Completare il Rango 1 di una delle due
## tracce alza la Fede corrispondente di 40 e abbassa l'altra di 10;
## completare il Rango 2 alza la Fede corrispondente di altri 40. Il
## Rango 2 richiede ORA anche Fede corrispondente >= 40 (corretto da 50
## dopo la Fase 10: un solo Rango 1 riuscito dà esattamente 40, quindi la
## combo storica di un singolo Rango 1 pulito resta sufficiente), oltre al
## consueto prerequisito di rango — vedi traccia_disponibile().
var fede_culto: float = 0.0
var fede_setta: float = 0.0

var is_over: bool = false
var end_reason: int = EndReason.NONE

var turno: int = 0
var storico: Array[Dictionary] = []

## Seed della run (design doc 12.1: "Ogni run usa un proprio seed"),
## loggato/visibile (UI e loop testuale lo mostrano) per poter riprodurre
## una run specifica in debug: rilanciando con lo stesso seed (vedi
## `GameState.new(seed_iniziale)` e il flag --seed= in main.gd) si ottiene
## esattamente la stessa sequenza di tiri di dado e di varianza sui costi/
## guadagni, perché entrambi pescano dallo stesso generatore seedato.
var seed_run: int
var _rng: RandomNumberGenerator

## Fase 10: cadenza degli eventi casuali (design doc 12.1/"sistema minimo di
## eventi casuali"). "Ogni 5-8 azioni compiute" lasciava la scelta esatta a
## me: ho fissato 6 (valore singolo, non un intervallo re-randomizzato ad
## ogni volta), a metà del range indicato. Conta OGNI turno risolto
## (azione, traccia, sottotrama, cash-in, spostamento), non solo le 62
## azioni core: altrimenti una run che gioca solo tracce/sottotrame non
## vedrebbe mai un evento.
const SOGLIA_EVENTO_TURNI := 6
var _turni_dal_evento: int = 0

## Karma congelato all'inizio della run (design doc: la condizione del
## Patto con lo Stregatto è "Karma <= -50 A INIZIO RUN", non il Karma
## corrente che può muoversi durante la run per effetto delle azioni
## compiute — a differenza del PESO degli eventi normali, che invece usa
## il Karma corrente). `karma` viene assegnato dal chiamante (GameUI/
## main.gd) dal Profilo Persistente DOPO il costruttore, quindi va
## catturato pigramente al primo turno risolto, non in _init().
var karma_inizio_run: float = 0.0
var _karma_inizio_run_catturato: bool = false

## Fase 10, design doc sezione 9: versione meccanica minima del Patto con
## lo Stregatto. Quando un evento casuale propone il patto, i dettagli
## restano qui finché il giocatore non risponde con risolvi_patto_stregatto()
## — vuoto se nessun patto è in sospeso.
var patto_in_sospeso: Dictionary = {}


func _init(seed_iniziale: int = -1, livello_difficolta_iniziale: int = 0) -> void:
	seed_run = seed_iniziale if seed_iniziale >= 0 else randi()
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_run

	livello_difficolta = livello_difficolta_iniziale
	sabbia_padre_ore = maxf(
		SABBIA_PADRE_MINIMA_DIFFICOLTA,
		SABBIA_PADRE_INIZIALE - SABBIA_PADRE_RIDUZIONE_PER_LIVELLO * livello_difficolta
	)


## Rischio effettivo dopo il malus di difficoltà (+5% per livello,
## clampato a 100%). Applicato alle azioni/tracce/sottotrame/cash-in, non
## agli eventi casuali automatici né al Patto con lo Stregatto.
func _rischio_con_difficolta(rischio_base: float) -> float:
	return clampf(rischio_base + RISCHIO_AUMENTO_PER_LIVELLO * livello_difficolta, 0.0, 1.0)

## Chiavi già "esaurite" in questa run — un TENTATIVO (riuscito o fallito)
## le consuma per sempre, non solo il successo. Due usi:
##  - azioni "Unica per run" (colonna Excel aggiunta dopo il playtest della
##    Fase 5: 17 azioni rappresentano un bersaglio/accordo/evento singolo —
##    es. IL GRANDE COLPO, la lotteria jackpot), chiave = azione.nome.
##  - righe di traccia (Fase 9b, decisione confermata dall'autore: un
##    fallimento blocca la riga esattamente come un'azione una tantum),
##    chiave = "<traccia>|<rango>" (vedi _chiave_traccia).
## Marcata al primo TENTATIVO, non solo al successo: altrimenti fallire il
## tiro permetterebbe di ritentare all'infinito fino a un successo,
## vanificando il vincolo.
var azioni_uniche_usate: Dictionary = {}


## True se l'azione può ancora essere scelta in questa run: sempre vero per
## le azioni ripetibili, falso per un'azione "Unica per run" già tentata.
func azione_disponibile(azione: ActionData) -> bool:
	return not (azione.unica_per_run and azioni_uniche_usate.has(azione.nome))


## Applica costo/effetto di un'azione in modo deterministico (nessun tiro di
## dado): la Fase 2 rispecchia deliberatamente il foglio "Simulatore Run"
## dell'Excel, che è anch'esso deterministico ("il Rischio % resta di
## riferimento, non simulato con dadi in questo prototipo"). Il dado arriva
## in Fase 3 (vedi action_resolver.gd), senza toccare questo metodo.
func applica_azione_deterministica(azione: ActionData) -> Dictionary:
	if not azione_disponibile(azione):
		return {"rifiutata": true, "motivo": "Azione unica per run: già tentata in questa run."}

	turno += 1
	tempo_figlia_ore -= azione.costo_tempo_figlia_ore
	sabbia_padre_ore += azione.effetto_sabbia_padre_ore
	if azione.unica_per_run:
		azioni_uniche_usate[azione.nome] = true

	var risultato := {
		"turno": turno,
		"azione": azione.nome,
		"costo_tempo_figlia_ore": azione.costo_tempo_figlia_ore,
		"effetto_sabbia_padre_ore": azione.effetto_sabbia_padre_ore,
		"tempo_figlia_ore": tempo_figlia_ore,
		"sabbia_padre_ore": sabbia_padre_ore,
	}
	storico.append(risultato)

	_controlla_fine_partita()
	return risultato


## --- Fase 10: le 5 risorse — formule comuni e ambiti di applicazione -----
##
## Formula comune ad Attenzione Polizia / Rivalità Criminale / Fama
## Pubblica (design doc 7.2, valori confermati dall'autore): malus al tiro
## = -floor(valore/20) (0 a -5 su un range 0-100); Svantaggio (non
## cumulativo: conta come un solo Svantaggio anche se più risorse lo
## innescano) quando il valore supera 50. La soglia 75 esiste solo per la
## gravità narrativa degli eventi (non implementata: nessun sistema di
## eventi "gravi" distinti in questa fase), non per un secondo malus al
## dado.
const RISORSA_MAX := 100.0
const RISORSA_SOGLIA_SVANTAGGIO := 50.0

## Ambito di applicazione (decisione esplicita dell'autore, non generico):
## Attenzione Polizia e Fama Pubblica riguardano le STESSE 7 categorie di
## azioni core. Rivalità Criminale non è basata su categoria: riguarda
## specificamente la traccia Criminale e le sottotrame/sinergie legate
## all'organizzazione (gestito con casi dedicati in applica_traccia/
## applica_sottotrama/applica_cash_in, non qui).
const CATEGORIE_POLIZIA_FAMA := [
	"Furto", "Crimine", "Crimine organizzato", "Minaccia 1 a 1",
	"Tradimento", "Corruzione", "Azzardo",
]

## Tracce "pubbliche/legittime" il cui Rango 2 sblocca l'applicabilità del
## malus di Fama Pubblica (design doc 7.2: "Cresce con i ranghi legittimi").
const TRACCE_LEGITTIME := ["Lavoro", "Politica", "Bancaria", "Religiosa (indulgenze)"]

## Incrementi/decrementi delle risorse: NON specificati numericamente né dal
## design doc né dalle istruzioni dell'autore ("piccolo aumento" era la sola
## indicazione per Attenzione Polizia) — valori miei, documentati qui e in
## CLAUDE.md, da confermare.
const ATTENZIONE_POLIZIA_INCREMENTO_FALLIMENTO := 10.0
const ATTENZIONE_POLIZIA_INCREMENTO_FALLIMENTO_CRITICO := 20.0
const ATTENZIONE_POLIZIA_DECREMENTO_CORRUZIONE := 25.0
const RIVALITA_CRIMINALE_INCREMENTO_RANGO1 := 15.0
const RIVALITA_CRIMINALE_INCREMENTO_RANGO2 := 25.0
const RIVALITA_CRIMINALE_INCREMENTO_SOTTOTRAMA := 15.0
const RIVALITA_CRIMINALE_INCREMENTO_CASHIN := 20.0
const RIVALITA_CRIMINALE_DECREMENTO_TRIBUTO := 20.0
const FAMA_PUBBLICA_INCREMENTO_RANGO_LEGITTIMO := 30.0
const FAMA_PUBBLICA_DECREMENTO_BASSO_PROFILO := 20.0

## Nomi delle 2 sottotrame "legate all'organizzazione" (design doc 6.1/6.10 —
## giudizio dell'autore delegato a me, "usa il buon senso"): entrambe
## coinvolgono esplicitamente il boss/l'organizzazione criminale del
## protagonista, non un bersaglio esterno.
const SOTTOTRAME_ORGANIZZAZIONE := ["Il tesoro del vecchio boss", "La cassa di guerra della vecchia organizzazione"]

const AZIONE_DECREMENTO_ATTENZIONE_POLIZIA := "Corrompere un poliziotto"
const AZIONE_DECREMENTO_RIVALITA_CRIMINALE := "Pagare un tributo ai rivali"
const AZIONE_DECREMENTO_FAMA_PUBBLICA := "Mantenere un basso profilo pubblico"


func _malus_risorsa(valore: float) -> int:
	return -floori(valore / 20.0)


func _svantaggio_da_risorsa(valore: float) -> bool:
	return valore > RISORSA_SOGLIA_SVANTAGGIO


func _clamp_risorsa(valore: float) -> float:
	return clampf(valore, 0.0, RISORSA_MAX)


## Combina il malus/Svantaggio di Attenzione Polizia e Fama Pubblica per
## un'azione core, secondo l'ambito di applicazione dichiarato. La Fama
## Pubblica si applica solo se il giocatore ha già raggiunto almeno un
## Rango 2 in una traccia legittima in questa run (design doc, Fase 10).
func _modificatore_polizia_fama(azione: ActionData) -> Dictionary:
	if not CATEGORIE_POLIZIA_FAMA.has(azione.categoria):
		return {"modificatore": 0, "svantaggio": false}

	var modificatore := _malus_risorsa(attenzione_polizia)
	var svantaggio := _svantaggio_da_risorsa(attenzione_polizia)

	var fama_attiva := false
	for nome_traccia in TRACCE_LEGITTIME:
		if tracce_raggiunte.get(nome_traccia, 0) >= 2:
			fama_attiva = true
			break
	if fama_attiva:
		modificatore += _malus_risorsa(fama_pubblica)
		svantaggio = svantaggio or _svantaggio_da_risorsa(fama_pubblica)

	return {"modificatore": modificatore, "svantaggio": svantaggio}


## Peso Karma per azione (design doc 7.2, valori confermati dall'autore),
## dalla colonna Moralità del foglio Azioni: Estrema -5, Molto sporca -3,
## Sporca -2, Ambigua -1, Pulita +1, Pulita/altruista +2. Le varianti con
## suffisso tra parentesi (es. "Ambigua (costo emotivo)") o con un prefisso
## "Molto "/ecc. contano come la loro etichetta base — solo un suffisso
## descrittivo, non una categoria diversa. Etichette che non riconducono
## chiaramente a una delle sei (Neutra, Negativo, Pericoloso e varianti,
## più le etichette ibride "Pulita/ambigua" e "Pulita/neutra") pesano 0,
## come confermato esplicitamente dall'autore.
const PESI_KARMA := {
	"Estrema": -5.0,
	"Molto sporca": -3.0,
	"Sporca": -2.0,
	"Ambigua": -1.0,
	"Pulita": 1.0,
	"Pulita/altruista": 2.0,
}


func _peso_karma(moralita: String) -> float:
	if PESI_KARMA.has(moralita):
		return PESI_KARMA[moralita]
	# Rimuove un eventuale suffisso " (...)" per confrontare solo la base:
	# "Ambigua (costo emotivo)" -> "Ambigua".
	var idx := moralita.find(" (")
	var base := moralita.substr(0, idx) if idx >= 0 else moralita
	return PESI_KARMA.get(base, 0.0)


## --- Fase 10: sistema minimo di eventi casuali + Patto con lo Stregatto -

const KARMA_SOGLIA_ALTA := 50.0    ## Vantaggio agli eventi, pesa 3x gli eventi "Pulita"
const KARMA_SOGLIA_BASSA := -50.0  ## Svantaggio agli eventi, pesa 3x "Negativo"/"Sporca", soglia del Patto

const STREGATTO_PROBABILITA := 0.15     ## quando Karma <= KARMA_SOGLIA_BASSA
const STREGATTO_PREZZO_FRAZIONE := 0.5  ## metà della Sabbia-Padre posseduta
const STREGATTO_KARMA_EFFETTO := 30.0


## Modificatore Karma per gli eventi casuali (design doc, "applicata SOLO
## agli eventi casuali, mai alle azioni scelte attivamente"): stessa
## formula di malus graduale delle altre risorse, ma BIPOLARE — Karma
## positivo dà un BONUS al tiro (non solo l'assenza di malus), coerente
## col design doc 7.2 ("sopra +50... un piccolo sconto al rischio
## globale"). Vantaggio se Karma >= 50, Svantaggio se Karma <= -50.
func _modificatore_karma_eventi() -> Dictionary:
	var segno := 1 if karma > 0 else (-1 if karma < 0 else 0)
	var modificatore := floori(abs(karma) / 20.0) * segno
	var modo := DiceSystem.RollMode.NORMALE
	if karma >= KARMA_SOGLIA_ALTA:
		modo = DiceSystem.RollMode.VANTAGGIO
	elif karma <= KARMA_SOGLIA_BASSA:
		modo = DiceSystem.RollMode.SVANTAGGIO
	return {"modificatore": modificatore, "modo": modo}


func _pesca_pesata(elementi: Array[ActionData], pesi: Array[float]) -> ActionData:
	var totale := 0.0
	for p in pesi:
		totale += p
	var r := _rng.randf() * totale
	var accumulato := 0.0
	for i in elementi.size():
		accumulato += pesi[i]
		if r < accumulato:
			return elementi[i]
	return elementi[elementi.size() - 1]


## Sistema minimo di eventi casuali (design doc, "sistema minimo di eventi
## casuali"): pesca un'azione dalla categoria "Evento" del foglio Azioni e
## la risolve subito (dado con modificatore Karma), oppure — se Karma <=
## -50 e un tiro al 15% lo conferma — propone il Patto con lo Stregatto al
## suo posto (design doc sezione 9, versione meccanica minima; il
## personaggio scritto per esteso arriva in Fase 11, qui solo dialoghi
## segnaposto chiaramente marcati). Con Karma >= 50 pesa 3x le voci
## "Pulita"; con Karma <= -50 pesa 3x le voci "Negativo"/"Sporca";
## altrimenti pesca uniforme.
func _pesca_evento_casuale() -> Dictionary:
	if karma_inizio_run <= KARMA_SOGLIA_BASSA and _rng.randf() < STREGATTO_PROBABILITA:
		var prezzo := roundf(sabbia_padre_ore * STREGATTO_PREZZO_FRAZIONE)
		patto_in_sospeso = {"prezzo_ore": prezzo}
		return {
			"tipo": "patto_stregatto_proposto",
			"testo": "[PLACEHOLDER STREGATTO]: offre di aggiustare il tuo Karma in cambio di metà della tua Sabbia-Padre. Accetti?",
			"prezzo_ore": prezzo,
		}

	var eventi := ActionDatabase.get_by_categoria("Evento")
	if eventi.is_empty():
		return {}

	var pesi: Array[float] = []
	for e in eventi:
		var peso := 1.0
		if karma >= KARMA_SOGLIA_ALTA and e.moralita == "Pulita":
			peso = 3.0
		elif karma <= KARMA_SOGLIA_BASSA and (e.moralita == "Negativo" or e.moralita == "Sporca"):
			peso = 3.0
		pesi.append(peso)

	var scelto := _pesca_pesata(eventi, pesi)
	var mod_karma := _modificatore_karma_eventi()
	var roll := DiceSystem.risolvi(scelto.rischio_pct, mod_karma.modo, mod_karma.modificatore, _rng)
	var effetto := 0.0
	if roll.successo:
		effetto = ActionVariance.effetto_variato(scelto.effetto_sabbia_padre_ore, _rng)
		sabbia_padre_ore += effetto

	return {
		"tipo": "evento_normale",
		"azione": scelto.nome,
		"roll": roll,
		"successo": roll.successo,
		"effetto_sabbia_padre_ore": effetto,
	}


## Va chiamata da OGNI metodo applica_*() al posto di un `turno += 1`
## diretto: avanza il turno e, ogni SOGLIA_EVENTO_TURNI turni, innesca un
## evento casuale (o il Patto con lo Stregatto). Conta OGNI turno risolto
## (azione, traccia, sottotrama, cash-in, spostamento), non solo le azioni
## core: altrimenti una run che gioca solo tracce/sottotrame non vedrebbe
## mai un evento.
func _avanza_turno() -> Dictionary:
	if not _karma_inizio_run_catturato:
		karma_inizio_run = karma
		_karma_inizio_run_catturato = true
	turno += 1
	_turni_dal_evento += 1
	if _turni_dal_evento < SOGLIA_EVENTO_TURNI:
		return {}
	_turni_dal_evento = 0
	return {"evento": _pesca_evento_casuale()}


## [PLACEHOLDER STREGATTO]: risponde a un patto proposto da
## _pesca_evento_casuale(). Se accettato: sottrae il prezzo (metà della
## Sabbia-Padre al momento della proposta, già arrotondata) e aggiunge
## +30 Karma SENZA clamp a zero (può portare il Karma sopra zero anche se
## era molto negativo, come richiesto) — resta comunque dentro il range
## generale -100/+100 del Karma. Non consuma un turno proprio: risolve un
## evento già innescato da un'altra azione.
func risolvi_patto_stregatto(accetta: bool) -> Dictionary:
	if patto_in_sospeso.is_empty():
		return {"rifiutata": true, "motivo": "Nessun patto con lo Stregatto in sospeso."}

	var prezzo: float = patto_in_sospeso.prezzo_ore
	patto_in_sospeso = {}

	if not accetta:
		var rifiuto := {"accettato": false, "azione": "[PLACEHOLDER STREGATTO] Patto rifiutato"}
		storico.append(rifiuto)
		return rifiuto

	sabbia_padre_ore -= prezzo
	karma = clampf(karma + STREGATTO_KARMA_EFFETTO, -RISORSA_MAX, RISORSA_MAX)

	var risultato := {
		"accettato": true,
		"azione": "[PLACEHOLDER STREGATTO] Patto accettato",
		"prezzo_ore": prezzo,
		"karma_ottenuto": STREGATTO_KARMA_EFFETTO,
		"sabbia_padre_ore": sabbia_padre_ore,
	}
	storico.append(risultato)

	_controlla_fine_partita()
	return risultato


## Guardia comune a tutti i metodi applica_*(): finché un Patto con lo
## Stregatto è in sospeso (design doc sezione 9), nessun'altra azione/
## traccia/sottotrama/cash-in/spostamento può essere tentata — il giocatore
## deve prima rispondere con risolvi_patto_stregatto(). Applicata a livello
## di logica di gioco (non solo in UI) così resta valida anche dal loop
## testuale e dal simulatore.
func _patto_in_sospeso_blocca() -> Dictionary:
	return {"rifiutata": true, "motivo": "Devi prima rispondere al patto con lo Stregatto in sospeso."}


## Applica un'azione risolvendola con un tiro di dado d20 (Fase 3, design doc
## 4.6) e con varianza roguelite su costo/guadagno (Fase 8, design doc 12.1:
## ±15%/±20%, vedi ActionVariance), al posto dell'applicazione diretta e
## deterministica di applica_azione_deterministica(). Il tempo (variato) si
## spende sempre, anche in caso di fallimento; l'effetto in Sabbia-Padre
## (variato) si applica solo in caso di successo. Dado e varianza pescano
## entrambi dal generatore seedato della run (`_rng`), quindi rilanciare con
## lo stesso seed_run riproduce esattamente la stessa sequenza.
##
## Fase 10: Attenzione Polizia/Fama Pubblica modificano il tiro secondo il
## loro ambito di applicazione (vedi _modificatore_polizia_fama). Un
## fallimento su un'azione nell'ambito di Attenzione Polizia la alza;
## "Corrompere un poliziotto" riuscita la abbassa. Il Karma si aggiorna
## SEMPRE (successo o fallimento: il peso riflette la scelta compiuta, non
## il suo esito) secondo il peso Moralità dell'azione.
##
## `modo` e `modificatore` restano gli aggangi per fonti future
## (oggetti, ranghi di traccia): si sommano/combinano con quelli delle
## risorse invece di sostituirli.
func applica_azione_con_dado(
	azione: ActionData,
	modo: DiceSystem.RollMode = DiceSystem.RollMode.NORMALE,
	modificatore: int = 0
) -> Dictionary:
	if not azione_disponibile(azione):
		return {"rifiutata": true, "motivo": "Azione unica per run: già tentata in questa run."}
	if not patto_in_sospeso.is_empty():
		return _patto_in_sospeso_blocca()

	var evento_info := _avanza_turno()
	var costo := ActionVariance.costo_variato(azione.costo_tempo_figlia_ore, _rng)
	tempo_figlia_ore -= costo
	if azione.unica_per_run:
		azioni_uniche_usate[azione.nome] = true

	var mod_risorse := _modificatore_polizia_fama(azione)
	var modo_finale: DiceSystem.RollMode = DiceSystem.RollMode.SVANTAGGIO if (modo == DiceSystem.RollMode.NORMALE and mod_risorse.svantaggio) else modo
	var roll := DiceSystem.risolvi(_rischio_con_difficolta(azione.rischio_pct), modo_finale, modificatore + mod_risorse.modificatore, _rng)

	var risultato := {
		"turno": turno,
		"azione": azione.nome,
		"costo_tempo_figlia_ore": costo,
		"roll": roll,
		"successo": roll.successo,
		"effetto_sabbia_padre_ore": 0.0,
		"evento_casuale": evento_info.get("evento"),
	}

	if roll.successo:
		var effetto := ActionVariance.effetto_variato(azione.effetto_sabbia_padre_ore, _rng)
		sabbia_padre_ore += effetto
		risultato.effetto_sabbia_padre_ore = effetto
		if azione.nome == AZIONE_DECREMENTO_ATTENZIONE_POLIZIA:
			attenzione_polizia = _clamp_risorsa(attenzione_polizia - ATTENZIONE_POLIZIA_DECREMENTO_CORRUZIONE)
		elif azione.nome == AZIONE_DECREMENTO_RIVALITA_CRIMINALE:
			rivalita_criminale = _clamp_risorsa(rivalita_criminale - RIVALITA_CRIMINALE_DECREMENTO_TRIBUTO)
		elif azione.nome == AZIONE_DECREMENTO_FAMA_PUBBLICA:
			fama_pubblica = _clamp_risorsa(fama_pubblica - FAMA_PUBBLICA_DECREMENTO_BASSO_PROFILO)
	elif CATEGORIE_POLIZIA_FAMA.has(azione.categoria):
		var incremento := ATTENZIONE_POLIZIA_INCREMENTO_FALLIMENTO_CRITICO if roll.fallimento_critico else ATTENZIONE_POLIZIA_INCREMENTO_FALLIMENTO
		attenzione_polizia = _clamp_risorsa(attenzione_polizia + incremento)

	karma = clampf(karma + _peso_karma(azione.moralita), -RISORSA_MAX, RISORSA_MAX)

	risultato["tempo_figlia_ore"] = tempo_figlia_ore
	risultato["sabbia_padre_ore"] = sabbia_padre_ore
	storico.append(risultato)

	_controlla_fine_partita()
	return risultato


## Evento con esito incerto aggiuntivo (Fase 8, design doc 12.1, vedi
## Spostamento): non è legata a nessuna delle 60 azioni core, quindi non
## interagisce con "Unica per run" né con ActionVariance. Il tempo si spende
## sempre; non ha alcun effetto diretto su Sabbia-Padre (solo tempo perso in
## caso di incidente).
func applica_spostamento() -> Dictionary:
	if not patto_in_sospeso.is_empty():
		return _patto_in_sospeso_blocca()

	var evento_info := _avanza_turno()
	var esito := Spostamento.esegui(_rng)
	tempo_figlia_ore -= esito.durata_totale_ore

	var risultato := {
		"turno": turno,
		"azione": "Spostamento in città",
		"spostamento": esito,
		"costo_tempo_figlia_ore": esito.durata_totale_ore,
		"effetto_sabbia_padre_ore": 0.0,
		"evento_casuale": evento_info.get("evento"),
		"tempo_figlia_ore": tempo_figlia_ore,
		"sabbia_padre_ore": sabbia_padre_ore,
	}
	storico.append(risultato)

	_controlla_fine_partita()
	return risultato


## Rango massimo raggiunto in questa run per ciascuna traccia normale
## (nome traccia -> rango, 0 = non ancora iniziata). Fase 9a, design doc
## 7.1: "una volta raggiunto un rango resta sbloccato per il resto della
## run" — mai decrementato. Le 7 tracce sono indipendenti l'una dall'altra
## (nessun aggancio malavita comune, decisione confermata dall'autore): il
## solo prerequisito è interno a ciascuna traccia (Rango 2 richiede il
## Rango 1 della STESSA traccia, già raggiunto in questa run).
var tracce_raggiunte: Dictionary = {}


func _chiave_traccia(riga: TrackData) -> String:
	return "%s|%d" % [riga.traccia, riga.rango]


## Fede del Culto e Fede della Setta (Fase 10, design doc 7.2): mappa il
## nome traccia -> chiave interna della Fede corrispondente. Solo Religiosa
## e Occulto sono collegate a una Fede — le altre 5 tracce normali non
## hanno alcuna interazione con questo sistema.
const FEDE_TRACCE := {
	"Religiosa (indulgenze)": "culto",
	"Occulto (setta satanica)": "setta",
}
const FEDE_INCREMENTO_RANGO := 40.0
const FEDE_DECREMENTO_RIVALE := 10.0
## Corretta da 50 a 40 (confermato dall'autore dopo la Fase 10): con la
## soglia originale un singolo Rango 1 riuscito (+40 Fede) non bastava mai
## a raggiungerla, rendendo il Rango 2 irraggiungibile in pratica — nessuna
## azione colmava il divario di 10. A 40, un Rango 1 pulito su una sola
## traccia religiosa sblocca subito il Rango 2 di quella traccia, mentre
## l'attrito tra le due Fedi (-10 sulla rivale) resta reale per chi tenta
## entrambe le tracce nella stessa run.
const FEDE_SOGLIA_RANGO2 := 40.0


func _fede(chiave: String) -> float:
	return fede_culto if chiave == "culto" else fede_setta


func _imposta_fede(chiave: String, valore: float) -> void:
	var v := clampf(valore, 0.0, RISORSA_MAX)
	if chiave == "culto":
		fede_culto = v
	else:
		fede_setta = v


## Completare il Rango 1 di Religiosa/Occulto alza la Fede corrispondente
## di 40 e abbassa l'ALTRA di 10 (design doc 7.2: le due fedi sono in
## competizione, un passo verso l'una allontana dall'altra); completare il
## Rango 2 alza solo la Fede corrispondente di altri 40, senza toccare
## l'altra una seconda volta.
func _aggiorna_fede_dopo_traccia(riga: TrackData) -> void:
	if not FEDE_TRACCE.has(riga.traccia):
		return
	var chiave: String = FEDE_TRACCE[riga.traccia]
	_imposta_fede(chiave, _fede(chiave) + FEDE_INCREMENTO_RANGO)
	if riga.rango == 1:
		var altra_chiave := "setta" if chiave == "culto" else "culto"
		_imposta_fede(altra_chiave, _fede(altra_chiave) - FEDE_DECREMENTO_RIVALE)


## True se il Rango 2 di Religiosa/Occulto è bloccato SOLO dalla Fede
## insufficiente (il prerequisito di rango è già soddisfatto) — Fase 10,
## per distinguere questo caso dal normale "manca ancora il Rango 1" in
## UI/loop testuale (design doc: l'azione resta visibile ma non
## selezionabile, con un messaggio esplicativo dedicato).
func traccia_bloccata_da_fede(riga: TrackData) -> bool:
	if riga.rango != 2 or not FEDE_TRACCE.has(riga.traccia):
		return false
	if tracce_raggiunte.get(riga.traccia, 0) < 1:
		return false
	return _fede(FEDE_TRACCE[riga.traccia]) < FEDE_SOGLIA_RANGO2


## True se questa riga (Rango 1 o Rango 2 di una traccia) può essere
## tentata ora: serve che il Rango precedente della stessa traccia sia già
## stato raggiunto (per il Rango 1 questo è automaticamente vero, essendo
## 0 == 1-1), che questa riga non sia già stata tentata in questa run —
## riuscita o fallita, vedi applica_traccia() — e, SOLO per il Rango 2 di
## Religiosa/Occulto (Fase 10), che la Fede corrispondente sia >= 40.
func traccia_disponibile(riga: TrackData) -> bool:
	if azioni_uniche_usate.has(_chiave_traccia(riga)):
		return false
	var progresso: int = tracce_raggiunte.get(riga.traccia, 0)
	if progresso != riga.rango - 1:
		return false
	return not traccia_bloccata_da_fede(riga)


## Applica il tentativo di salire di rango in una traccia: stesso motore di
## risoluzione delle 60 azioni core (dado d20 Fase 3 + varianza ±15%/±20%
## Fase 8, stesso _rng seedato della run — vedi ActionVariance).
##
## Un TENTATIVO (riuscito o fallito) esaurisce quella riga per il resto
## della run, riusando esattamente lo stesso meccanismo delle azioni "Unica
## per run" (`azioni_uniche_usate`, decisione confermata dall'autore dopo
## la Fase 9a): un fallimento sul Rango 1 rende l'intera traccia
## inaccessibile per il resto della run (il Rango 2 non potrà mai
## sbloccarsi, dato che richiede il Rango 1 completato con successo); un
## fallimento sul Rango 2 lascia valido il Rango 1 già raggiunto ma
## preclude il Rango 2.
##
## Fase 10: un successo sulla traccia Criminale alza Rivalità Criminale; un
## successo di Rango 2 su una traccia legittima (Lavoro/Politica/Bancaria/
## Religiosa) alza Fama Pubblica; un successo su Religiosa/Occulto
## aggiorna le rispettive Fede (vedi _aggiorna_fede_dopo_traccia). Il
## Rango 2 di Religiosa/Occulto richiede anche Fede >= 40, controllato da
## traccia_disponibile()/traccia_bloccata_da_fede().
func applica_traccia(
	riga: TrackData,
	modo: DiceSystem.RollMode = DiceSystem.RollMode.NORMALE,
	modificatore: int = 0
) -> Dictionary:
	if not traccia_disponibile(riga):
		var motivo := "già tentata in questa run (riuscita o fallita)."
		if traccia_bloccata_da_fede(riga):
			motivo = "richiede Fede %s >= %d (attualmente %d)." % [
				FEDE_TRACCE[riga.traccia], int(FEDE_SOGLIA_RANGO2), int(_fede(FEDE_TRACCE[riga.traccia]))
			]
		elif riga.rango > 1 and tracce_raggiunte.get(riga.traccia, 0) < riga.rango - 1:
			motivo = "serve prima completare con successo il Rango %d della stessa traccia." % (riga.rango - 1)
		return {"rifiutata": true, "motivo": motivo}
	if not patto_in_sospeso.is_empty():
		return _patto_in_sospeso_blocca()

	var evento_info := _avanza_turno()
	var costo := ActionVariance.costo_variato(riga.costo_tempo_figlia_ore, _rng)
	tempo_figlia_ore -= costo
	azioni_uniche_usate[_chiave_traccia(riga)] = true

	var roll := DiceSystem.risolvi(_rischio_con_difficolta(riga.rischio_pct), modo, modificatore, _rng)

	var risultato := {
		"turno": turno,
		"azione": "%s — Rango %d: %s" % [riga.traccia, riga.rango, riga.nome_rango],
		"traccia": riga.traccia,
		"rango": riga.rango,
		"costo_tempo_figlia_ore": costo,
		"roll": roll,
		"successo": roll.successo,
		"effetto_sabbia_padre_ore": 0.0,
		"evento_casuale": evento_info.get("evento"),
	}

	if roll.successo:
		var effetto := ActionVariance.effetto_variato(riga.effetto_sabbia_padre_ore, _rng)
		sabbia_padre_ore += effetto
		risultato.effetto_sabbia_padre_ore = effetto
		tracce_raggiunte[riga.traccia] = riga.rango
		_aggiorna_fede_dopo_traccia(riga)

		if riga.traccia == "Criminale":
			var incremento_rivalita: float = RIVALITA_CRIMINALE_INCREMENTO_RANGO2 if riga.rango == 2 else RIVALITA_CRIMINALE_INCREMENTO_RANGO1
			rivalita_criminale = _clamp_risorsa(rivalita_criminale + incremento_rivalita)
		if riga.rango == 2 and TRACCE_LEGITTIME.has(riga.traccia):
			fama_pubblica = _clamp_risorsa(fama_pubblica + FAMA_PUBBLICA_INCREMENTO_RANGO_LEGITTIMO)

	risultato["tempo_figlia_ore"] = tempo_figlia_ore
	risultato["sabbia_padre_ore"] = sabbia_padre_ore
	storico.append(risultato)

	_controlla_fine_partita()
	return risultato


## Fase 9c, design doc 7.3: raggiungere Rango 2 in N tracce NORMALI diverse
## (2, 3 o 4 — le sottotrame NON contano mai per questo conteggio, decisione
## esplicita dell'autore) nella stessa run sblocca un'azione di "cash-in".
const CASH_IN_COSTO_ORE := 8.0

## Rischio del cash-in: NON specificato né dal foglio Excel né dal design
## doc (la sezione 7.3 descrive solo il moltiplicatore, non un Rischio%
## per l'azione di cash-in in sé). Valore back-calcolato dal 16,8% di
## probabilità sull'intera catena che il design doc 7.4 riporta per la
## tripletta storica Azzardo+Bancaria+Religiosa: il prodotto delle
## probabilità di successo dei 6 tentativi di rango di quella tripletta
## (con i Rischio% attuali del foglio Endgame) è ~19,3%; 16,8% / 19,3% ≈
## 87% di successo per il solo cash-in, cioè un rischio di ~13%,
## arrotondato qui a 15%. Placeholder mio, da confermare con l'autore.
const CASH_IN_RISCHIO_PCT := 0.15

const SINERGIA_MOLTIPLICATORI := {2: 2.0, 3: 4.0, 4: 8.0}

## Le 3 combinazioni "malus" del design doc 7.3 (nomi di traccia, non di
## rango — il malus scatta quando ENTRAMBE le tracce della coppia sono a
## Rango 2): "Capo di culto tollerato" + "Capo di setta satanica" ->
## Religiosa+Occulto; "Direttore di banca" + "Boss riconosciuto" ->
## Bancaria+Criminale; "Burattinaio politico" + "Capo di setta occulta" ->
## Politica+Occulto. Nomi di traccia interpretati dal testo narrativo del
## design doc (non sono colonne Excel), da confermare con l'autore.
const MALUS_COMBINAZIONI := [
	["Religiosa (indulgenze)", "Occulto (setta satanica)"],
	["Bancaria", "Criminale"],
	["Politica", "Occulto (setta satanica)"],
]


## Nomi delle tracce normali attualmente a Rango 2 in questa run. Solo le
## tracce normali contano per la sinergia: le sottotrame non entrano mai
## in questo conteggio, per esplicita decisione dell'autore.
func tracce_a_rango_2() -> Array:
	var out := []
	for nome in tracce_raggiunte:
		if tracce_raggiunte[nome] >= 2:
			out.append(nome)
	return out


## Somma di Rango1+Rango2 di una traccia (i due guadagni già incassati
## separatamente quando si sale di rango — NON è più la base del cash-in,
## vedi valore_rango2_traccia() e la nota sotto applica_cash_in).
func valore_base_traccia(nome: String) -> float:
	var r1 := TrackDatabase.get_riga(nome, 1)
	var r2 := TrackDatabase.get_riga(nome, 2)
	return (r1.effetto_sabbia_padre_ore if r1 != null else 0.0) + (r2.effetto_sabbia_padre_ore if r2 != null else 0.0)


## Solo il valore del Rango 2 di una traccia (interpretazione B, confermata
## dall'autore dopo la Fase 10 per il calcolo del cash-in di sinergia — il
## Rango 1 NON viene sommato di nuovo: è già stato incassato per conto suo
## quando è stato completato, il cash-in aggiunge solo un moltiplicatore
## sul valore del Rango 2).
func valore_rango2_traccia(nome: String) -> float:
	var r2 := TrackDatabase.get_riga(nome, 2)
	return r2.effetto_sabbia_padre_ore if r2 != null else 0.0


## Tracce che verrebbero effettivamente incluse in un cash-in tentato ora:
## tutte quelle a Rango 2 se sono <= 4, altrimenti le 4 di maggior valore
## di Rango 2 (il design doc 7.4 nota che una quadrupletta è già di fatto
## irraggiungibile entro 168 ore, quindi 5+ è solo una guardia difensiva,
## non un caso atteso in pratica) — ordinate per lo stesso valore che
## determina davvero il payout del cash-in (interpretazione B).
func combo_tracce() -> Array:
	var candidate := tracce_a_rango_2()
	if candidate.size() <= 4:
		return candidate
	candidate.sort_custom(func(a, b): return valore_rango2_traccia(a) > valore_rango2_traccia(b))
	return candidate.slice(0, 4)


func combo_dimensione() -> int:
	return combo_tracce().size()


func cash_in_disponibile() -> bool:
	return not azioni_uniche_usate.has("cashin") and combo_dimensione() >= 2


## Rileva le combinazioni "malus" del design doc 7.3 attualmente attive
## (entrambe le tracce della coppia a Rango 2 in questa run). Le risorse
## coinvolte (Karma / Attenzione Polizia / Rivalità Criminale) sono ancora
## placeholder fissi a 0 (Fase 6): qui si rileva SOLO la condizione
## narrativa — l'aggancio che le somma davvero per finta arriverà in Fase
## 10, quando quelle risorse avranno un effetto reale sul gioco.
func malus_attivi() -> Array:
	var attivi := []
	for coppia in MALUS_COMBINAZIONI:
		if tracce_raggiunte.get(coppia[0], 0) >= 2 and tracce_raggiunte.get(coppia[1], 0) >= 2:
			attivi.append(coppia)
	return attivi


## Applica il tentativo di cash-in della sinergia (design doc 7.3). Costo
## (8h) e guadagno hanno la stessa varianza ±15%/±20% di azioni/tracce/
## sottotrame, stesso _rng seedato.
##
## Guadagno — INTERPRETAZIONE B (confermata dall'autore dopo la Fase 10,
## corregge l'interpretazione A usata inizialmente): la "somma dei valori
## base delle N tracce" del design doc 7.3 è la somma dei soli valori di
## RANGO 2 delle tracce della combo, NON Rango1+Rango2 sommati. Il Rango 1
## e il Rango 2 di ciascuna traccia sono già stati incassati per conto
## proprio quando completati (vedi applica_traccia) — il cash-in aggiunge
## solo il moltiplicatore di sinergia sul valore di Rango 2, non un
## secondo incasso del Rango 1. Un fallimento fa perdere TUTTI i ranghi coinvolti nella
## combo ("si perdono TUTTI i ranghi coinvolti nella combo, non solo
## uno") — riusa esattamente lo stesso meccanismo di azioni_uniche_usate
## già scritto per il fallimento di rango (Fase 9a/9b, non logica nuova):
## ogni riga (Rango 1 e Rango 2) delle tracce coinvolte viene marcata
## "usata" (bloccata per sempre) e il progresso azzerato.
func applica_cash_in(
	modo: DiceSystem.RollMode = DiceSystem.RollMode.NORMALE,
	modificatore: int = 0
) -> Dictionary:
	if not cash_in_disponibile():
		return {
			"rifiutata": true,
			"motivo": "servono almeno 2 tracce diverse a Rango 2, oppure il cash-in è già stato tentato in questa run.",
		}
	if not patto_in_sospeso.is_empty():
		return _patto_in_sospeso_blocca()

	var combo := combo_tracce()
	var n := combo.size()
	var moltiplicatore: float = SINERGIA_MOLTIPLICATORI.get(n, SINERGIA_MOLTIPLICATORI[4])
	var valore_base := 0.0
	for nome in combo:
		valore_base += valore_rango2_traccia(nome)

	var evento_info := _avanza_turno()
	var costo := ActionVariance.costo_variato(CASH_IN_COSTO_ORE, _rng)
	tempo_figlia_ore -= costo
	azioni_uniche_usate["cashin"] = true

	var roll := DiceSystem.risolvi(_rischio_con_difficolta(CASH_IN_RISCHIO_PCT), modo, modificatore, _rng)

	var risultato := {
		"turno": turno,
		"azione": "Cash-in sinergia (%d tracce: %s)" % [n, ", ".join(combo)],
		"combo": combo,
		"moltiplicatore": moltiplicatore,
		"costo_tempo_figlia_ore": costo,
		"roll": roll,
		"successo": roll.successo,
		"effetto_sabbia_padre_ore": 0.0,
		"evento_casuale": evento_info.get("evento"),
	}

	if roll.successo:
		var effetto := ActionVariance.effetto_variato(valore_base * moltiplicatore, _rng)
		sabbia_padre_ore += effetto
		risultato.effetto_sabbia_padre_ore = effetto
		if combo.has("Criminale"):
			rivalita_criminale = _clamp_risorsa(rivalita_criminale + RIVALITA_CRIMINALE_INCREMENTO_CASHIN)
	else:
		for nome in combo:
			for rango in [1, 2]:
				var riga_persa := TrackDatabase.get_riga(nome, rango)
				if riga_persa != null:
					azioni_uniche_usate[_chiave_traccia(riga_persa)] = true
			tracce_raggiunte[nome] = 0

	risultato["tempo_figlia_ore"] = tempo_figlia_ore
	risultato["sabbia_padre_ore"] = sabbia_padre_ore
	storico.append(risultato)

	_controlla_fine_partita()
	return risultato


func _chiave_sottotrama(sub: SubplotData) -> String:
	return "sottotrama:%s" % sub.nome


## True se un'ActionData con questo nome è stata applicata CON SUCCESSO
## almeno una volta in questa run (scansiona `storico`). Usato solo per il
## prerequisito di "Il tesoro del vecchio boss" (design doc 6.1) — non è la
## regola generale delle tracce/azioni uniche, è specifico di questa
## sottotrama.
func azione_completata_con_successo(nome_azione: String) -> bool:
	for r in storico:
		if r.get("azione") == nome_azione and r.get("successo", false):
			return true
	return false


## True se questa sottotrama può ancora essere tentata: non è già stata
## tentata in questa run (riuscita o fallita — stesso meccanismo delle
## azioni "Unica per run", vedi applica_sottotrama) e, se ha un
## prerequisito, quello è già stato completato con successo.
func sottotrama_disponibile(sub: SubplotData) -> bool:
	if azioni_uniche_usate.has(_chiave_sottotrama(sub)):
		return false
	if sub.prerequisito != "" and not azione_completata_con_successo(sub.prerequisito):
		return false
	return true


## Applica il tentativo di una sottotrama endgame (Fase 9b, design doc
## sezione 6): ogni sottotrama è una singola azione una tantum, stesso
## meccanismo delle azioni "Unica per run" del foglio Azioni (un tentativo,
## riuscito o fallito, la esaurisce per questa run) e stesso motore di
## risoluzione delle azioni core e delle tracce (dado d20 + varianza
## ±15%/±20%, stesso _rng seedato della run).
func applica_sottotrama(
	sub: SubplotData,
	modo: DiceSystem.RollMode = DiceSystem.RollMode.NORMALE,
	modificatore: int = 0
) -> Dictionary:
	if not sottotrama_disponibile(sub):
		var motivo := "già tentata in questa run (riuscita o fallita)."
		if sub.prerequisito != "" and not azione_completata_con_successo(sub.prerequisito):
			motivo = "richiede prima di completare con successo l'azione \"%s\" in questa run." % sub.prerequisito
		return {"rifiutata": true, "motivo": motivo}
	if not patto_in_sospeso.is_empty():
		return _patto_in_sospeso_blocca()

	var evento_info := _avanza_turno()
	var costo := ActionVariance.costo_variato(sub.costo_tempo_figlia_ore, _rng)
	tempo_figlia_ore -= costo
	azioni_uniche_usate[_chiave_sottotrama(sub)] = true

	var roll := DiceSystem.risolvi(_rischio_con_difficolta(sub.rischio_pct), modo, modificatore, _rng)

	var risultato := {
		"turno": turno,
		"azione": sub.nome,
		"costo_tempo_figlia_ore": costo,
		"roll": roll,
		"successo": roll.successo,
		"effetto_sabbia_padre_ore": 0.0,
		"evento_casuale": evento_info.get("evento"),
	}

	if roll.successo:
		var effetto := ActionVariance.effetto_variato(sub.effetto_sabbia_padre_ore, _rng)
		sabbia_padre_ore += effetto
		risultato.effetto_sabbia_padre_ore = effetto
		if SOTTOTRAME_ORGANIZZAZIONE.has(sub.nome):
			rivalita_criminale = _clamp_risorsa(rivalita_criminale + RIVALITA_CRIMINALE_INCREMENTO_SOTTOTRAMA)

	risultato["tempo_figlia_ore"] = tempo_figlia_ore
	risultato["sabbia_padre_ore"] = sabbia_padre_ore
	storico.append(risultato)

	_controlla_fine_partita()
	return risultato


func _controlla_fine_partita() -> void:
	if is_over:
		return
	if tempo_figlia_ore <= 0.0:
		is_over = true
		end_reason = EndReason.FIGLIA_MORTA
		tempo_figlia_ore = 0.0
	elif sabbia_padre_ore <= 0.0:
		is_over = true
		end_reason = EndReason.PADRE_MORTO
		sabbia_padre_ore = 0.0


func end_reason_testo() -> String:
	match end_reason:
		EndReason.FIGLIA_MORTA:
			return "Il Tempo-Figlia è arrivato a zero: la figlia muore. GAME OVER."
		EndReason.PADRE_MORTO:
			return "La Sabbia-Padre è arrivata a zero: il padre muore. GAME OVER."
		EndReason.DONAZIONE_FINALE_SCELTA:
			return "Donazione finale compiuta: la run termina qui."
		_:
			return ""


## 1 anno = 8.760 ore (design doc 5.1, nota 9). Costante locale (non presa da
## ActionDatabase) per mantenere GameState indipendente dall'autoload e
## quindi utilizzabile anche fuori dall'albero della scena.
const ORE_PER_ANNO := 8760.0
const SOGLIA_VITTORIA_ANNI := 100.0


## Donazione finale (design doc 4.3): volontaria, irreversibile, un'unica
## volta nella run. Trasferisce ore da Sabbia-Padre a Tempo-Figlia — la
## figlia può riceverla una sola volta in vita, non è accumulo progressivo.
## Decisione di design (da confermare con l'autore, vedi CLAUDE.md): la
## donazione è l'atto conclusivo della run e la termina immediatamente,
## punteggio compreso; l'importo donato è scelto dal giocatore (fino al
## massimo disponibile), non necessariamente tutta la Sabbia-Padre — coerente
## con "quanta sabbia il protagonista ha raccolto per sé E/O per la figlia"
## (4.4, "e/o" implica una possibile ripartizione).
func dona(quantita_ore: float) -> Dictionary:
	if donation_made:
		return {"successo": false, "motivo": "La donazione è unica e già avvenuta: non si può ripetere."}
	if is_over:
		return {"successo": false, "motivo": "La run è già conclusa."}
	if quantita_ore <= 0.0:
		return {"successo": false, "motivo": "La quantità donata deve essere positiva."}
	if quantita_ore > sabbia_padre_ore:
		return {"successo": false, "motivo": "Non hai abbastanza Sabbia-Padre (disponibili %.1fh)." % sabbia_padre_ore}

	sabbia_padre_ore -= quantita_ore
	tempo_figlia_ore += quantita_ore
	donation_made = true
	donated_ore = quantita_ore

	is_over = true
	end_reason = EndReason.DONAZIONE_FINALE_SCELTA

	return {"successo": true, "quantita_ore": quantita_ore, "punteggio": calcola_punteggio()}


## Punteggio finale (design doc 4.4): somma degli anni di vita assicurati a
## padre e figlia. Richiamabile in ogni momento (non solo a fine run) così
## la UI può mostrare un punteggio "corrente" oltre a quello finale.
func calcola_punteggio() -> Dictionary:
	var padre_anni := sabbia_padre_ore / ORE_PER_ANNO
	var figlia_anni := tempo_figlia_ore / ORE_PER_ANNO
	return {
		"padre_ore": sabbia_padre_ore,
		"padre_anni": padre_anni,
		"figlia_ore": tempo_figlia_ore,
		"figlia_anni": figlia_anni,
		"punteggio_totale_anni": padre_anni + figlia_anni,
		"vittoria_100_100": padre_anni >= SOGLIA_VITTORIA_ANNI and figlia_anni >= SOGLIA_VITTORIA_ANNI,
	}
