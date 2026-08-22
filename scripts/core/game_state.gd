class_name GameState
extends RefCounted
## Stato di una run (effimero, solo in memoria — vedi CLAUDE.md,
## "architettura di salvataggio a due livelli"). Nessuna dipendenza dalla
## scena: usabile sia dal loop di gioco sia dal simulatore headless.

enum EndReason { NONE, FIGLIA_MORTA, PADRE_MORTO, DONAZIONE_FINALE_SCELTA }

const TEMPO_FIGLIA_INIZIALE := 168.0
const SABBIA_PADRE_INIZIALE := 24.0

var tempo_figlia_ore: float = TEMPO_FIGLIA_INIZIALE
var sabbia_padre_ore: float = SABBIA_PADRE_INIZIALE

var donation_made: bool = false
var donated_ore: float = 0.0

## Le 5 risorse del design doc (sezione 7.2), esposte per la UI (Fase 6) ma
## SENZA alcuna logica che le aggiorni ancora: nessun sistema di tracce,
## eventi o conseguenze le tocca in questo prototipo — restano fisse a 0.0
## finché quei sistemi (fuori scope per le fasi 1-7) non verranno
## implementati. `karma` è l'unica pensata per persistere tra le run (design
## doc 7.2): viene inizializzata dal Profilo Persistente all'avvio della run
## (Fase 7, vedi scripts/core/player_profile.gd) invece di partire sempre da
## zero come le altre 4, ma nulla la modifica ancora durante il gioco.
var attenzione_polizia: float = 0.0
var rivalita_criminale: float = 0.0
var fama_pubblica: float = 0.0
var karma: float = 0.0
var fede: float = 0.0

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


func _init(seed_iniziale: int = -1) -> void:
	seed_run = seed_iniziale if seed_iniziale >= 0 else randi()
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_run

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


## Categorie considerate "illegali" ai soli fini della conseguenza di
## fallimento (design doc 4.6: aumento di Attenzione Polizia/Rivalità
## Criminale). Euristica basata sulla colonna Categoria, non sulla
## Moralità (più fedele a "azione illegale" in senso stretto).
const CATEGORIE_ILLEGALI := [
	"Furto", "Crimine", "Grande colpo", "Minaccia 1 a 1",
	"Crimine organizzato", "Corruzione", "Tradimento",
]


func _is_azione_illegale(azione: ActionData) -> bool:
	return CATEGORIE_ILLEGALI.has(azione.categoria)


## Applica un'azione risolvendola con un tiro di dado d20 (Fase 3, design doc
## 4.6) e con varianza roguelite su costo/guadagno (Fase 8, design doc 12.1:
## ±15%/±20%, vedi ActionVariance), al posto dell'applicazione diretta e
## deterministica di applica_azione_deterministica(). Il tempo (variato) si
## spende sempre, anche in caso di fallimento; l'effetto in Sabbia-Padre
## (variato) si applica solo in caso di successo. Dado e varianza pescano
## entrambi dal generatore seedato della run (`_rng`), quindi rilanciare con
## lo stesso seed_run riproduce esattamente la stessa sequenza.
##
## `modo` e `modificatore` sono gli aggangi per Vantaggio/Svantaggio e
## Bonus/Malus: nessuna fonte (oggetti, ranghi di traccia, soglie di
## risorsa) esiste ancora nel gioco, quindi qui arrivano sempre i valori di
## default — ma il sistema è già pronto a riceverli quando quelle fonti
## verranno implementate.
func applica_azione_con_dado(
	azione: ActionData,
	modo: DiceSystem.RollMode = DiceSystem.RollMode.NORMALE,
	modificatore: int = 0
) -> Dictionary:
	if not azione_disponibile(azione):
		return {"rifiutata": true, "motivo": "Azione unica per run: già tentata in questa run."}

	turno += 1
	var costo := ActionVariance.costo_variato(azione.costo_tempo_figlia_ore, _rng)
	tempo_figlia_ore -= costo
	if azione.unica_per_run:
		azioni_uniche_usate[azione.nome] = true

	var roll := DiceSystem.risolvi(azione.rischio_pct, modo, modificatore, _rng)

	var risultato := {
		"turno": turno,
		"azione": azione.nome,
		"costo_tempo_figlia_ore": costo,
		"roll": roll,
		"successo": roll.successo,
		"effetto_sabbia_padre_ore": 0.0,
		"conseguenza_risorsa": null,  # placeholder: Attenzione Polizia / Rivalità Criminale non esistono ancora (fase futura)
	}

	if roll.successo:
		var effetto := ActionVariance.effetto_variato(azione.effetto_sabbia_padre_ore, _rng)
		sabbia_padre_ore += effetto
		risultato.effetto_sabbia_padre_ore = effetto
	elif _is_azione_illegale(azione):
		risultato.conseguenza_risorsa = "rivalita_criminale_o_attenzione_polizia (fallimento%s)" % (
			"_critico" if roll.fallimento_critico else ""
		)

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
	turno += 1
	var esito := Spostamento.esegui(_rng)
	tempo_figlia_ore -= esito.durata_totale_ore

	var risultato := {
		"turno": turno,
		"azione": "Spostamento in città",
		"spostamento": esito,
		"costo_tempo_figlia_ore": esito.durata_totale_ore,
		"effetto_sabbia_padre_ore": 0.0,
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


## True se questa riga (Rango 1 o Rango 2 di una traccia) può essere
## tentata ora: serve che il Rango precedente della stessa traccia sia già
## stato raggiunto (per il Rango 1 questo è automaticamente vero, essendo
## 0 == 1-1) E che questa riga non sia già stata tentata in questa run —
## riuscita o fallita, vedi applica_traccia().
func traccia_disponibile(riga: TrackData) -> bool:
	if azioni_uniche_usate.has(_chiave_traccia(riga)):
		return false
	var progresso: int = tracce_raggiunte.get(riga.traccia, 0)
	return progresso == riga.rango - 1


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
func applica_traccia(
	riga: TrackData,
	modo: DiceSystem.RollMode = DiceSystem.RollMode.NORMALE,
	modificatore: int = 0
) -> Dictionary:
	if not traccia_disponibile(riga):
		var motivo := "già tentata in questa run (riuscita o fallita)."
		if riga.rango > 1 and tracce_raggiunte.get(riga.traccia, 0) < riga.rango - 1:
			motivo = "serve prima completare con successo il Rango %d della stessa traccia." % (riga.rango - 1)
		return {"rifiutata": true, "motivo": motivo}

	turno += 1
	var costo := ActionVariance.costo_variato(riga.costo_tempo_figlia_ore, _rng)
	tempo_figlia_ore -= costo
	azioni_uniche_usate[_chiave_traccia(riga)] = true

	var roll := DiceSystem.risolvi(riga.rischio_pct, modo, modificatore, _rng)

	var risultato := {
		"turno": turno,
		"azione": "%s — Rango %d: %s" % [riga.traccia, riga.rango, riga.nome_rango],
		"traccia": riga.traccia,
		"rango": riga.rango,
		"costo_tempo_figlia_ore": costo,
		"roll": roll,
		"successo": roll.successo,
		"effetto_sabbia_padre_ore": 0.0,
	}

	if roll.successo:
		var effetto := ActionVariance.effetto_variato(riga.effetto_sabbia_padre_ore, _rng)
		sabbia_padre_ore += effetto
		risultato.effetto_sabbia_padre_ore = effetto
		tracce_raggiunte[riga.traccia] = riga.rango

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

	turno += 1
	var costo := ActionVariance.costo_variato(sub.costo_tempo_figlia_ore, _rng)
	tempo_figlia_ore -= costo
	azioni_uniche_usate[_chiave_sottotrama(sub)] = true

	var roll := DiceSystem.risolvi(sub.rischio_pct, modo, modificatore, _rng)

	var risultato := {
		"turno": turno,
		"azione": sub.nome,
		"costo_tempo_figlia_ore": costo,
		"roll": roll,
		"successo": roll.successo,
		"effetto_sabbia_padre_ore": 0.0,
	}

	if roll.successo:
		var effetto := ActionVariance.effetto_variato(sub.effetto_sabbia_padre_ore, _rng)
		sabbia_padre_ore += effetto
		risultato.effetto_sabbia_padre_ore = effetto

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
