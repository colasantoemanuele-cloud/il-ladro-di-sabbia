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

## Nomi delle azioni "Unica per run" già tentate in questa run (colonna
## Excel aggiunta dopo il playtest della Fase 5: 17 azioni rappresentano un
## bersaglio/accordo/evento singolo — es. IL GRANDE COLPO, la lotteria
## jackpot — e non sono ripetibili nella stessa run). Marcata al primo
## TENTATIVO, non solo al successo: altrimenti fallire il tiro permetterebbe
## di ritentare all'infinito fino a un successo, vanificando il vincolo.
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
## 4.6), al posto dell'applicazione diretta e deterministica di
## applica_azione_deterministica(). Il tempo si spende sempre (anche in caso
## di fallimento); l'effetto in Sabbia-Padre si applica solo in caso di
## successo.
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
	tempo_figlia_ore -= azione.costo_tempo_figlia_ore
	if azione.unica_per_run:
		azioni_uniche_usate[azione.nome] = true

	var roll := DiceSystem.risolvi(azione.rischio_pct, modo, modificatore)

	var risultato := {
		"turno": turno,
		"azione": azione.nome,
		"costo_tempo_figlia_ore": azione.costo_tempo_figlia_ore,
		"roll": roll,
		"successo": roll.successo,
		"effetto_sabbia_padre_ore": 0.0,
		"conseguenza_risorsa": null,  # placeholder: Attenzione Polizia / Rivalità Criminale non esistono ancora (fase futura)
	}

	if roll.successo:
		sabbia_padre_ore += azione.effetto_sabbia_padre_ore
		risultato.effetto_sabbia_padre_ore = azione.effetto_sabbia_padre_ore
	elif _is_azione_illegale(azione):
		risultato.conseguenza_risorsa = "rivalita_criminale_o_attenzione_polizia (fallimento%s)" % (
			"_critico" if roll.fallimento_critico else ""
		)

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
