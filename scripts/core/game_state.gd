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
