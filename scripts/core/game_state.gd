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

var is_over: bool = false
var end_reason: int = EndReason.NONE

var turno: int = 0
var storico: Array[Dictionary] = []


## Applica costo/effetto di un'azione in modo deterministico (nessun tiro di
## dado): la Fase 2 rispecchia deliberatamente il foglio "Simulatore Run"
## dell'Excel, che è anch'esso deterministico ("il Rischio % resta di
## riferimento, non simulato con dadi in questo prototipo"). Il dado arriva
## in Fase 3 (vedi action_resolver.gd), senza toccare questo metodo.
func applica_azione_deterministica(azione: ActionData) -> Dictionary:
	turno += 1
	tempo_figlia_ore -= azione.costo_tempo_figlia_ore
	sabbia_padre_ore += azione.effetto_sabbia_padre_ore

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
	turno += 1
	tempo_figlia_ore -= azione.costo_tempo_figlia_ore

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
