class_name PlayerProfile
extends RefCounted
## Profilo Persistente (design doc 4.7, architettura di salvataggio a due
## livelli): file permanente che sopravvive tra le run, a differenza dello
## Stato di Run (GameState, effimero, solo in memoria).
##
## Fase 7: solo la STRUTTURA del salvataggio. Nessuno dei sistemi che
## popoleranno questi campi esiste ancora (tracce, achievement, difficoltà
## crescente, mondo senza sabbia — tutti fuori scope per le fasi 1-7): i
## campi restano vuoti/a zero finché quei sistemi non verranno implementati.
## L'unico collegamento reale già attivo è `karma`, che GameUI legge
## all'inizio di ogni run e riscrive alla fine — ma senza alcun meccanismo
## di gioco che lo modifichi ancora, resta 0.0 finché non esisterà.

const DEFAULT_PATH := "user://profilo_persistente.json"

## L'UNICA risorsa pensata per persistere tra le run (design doc 7.2,
## "la sabbia non dimentica"). Le altre 4 risorse di GameState sono
## per-run e si azzerano sempre a ogni nuova run.
var karma: float = 0.0

## Rete di contatti sbloccati (design doc 12.3): amici/amici di amici/nemici,
## l'albero di sblocco permanente. Vuoto finché il sistema non esiste.
var rete_contatti_sbloccati: Array = []

## Achievement/traguardi raggiunti tra le run. Vuoto finché non esistono.
var achievement: Array = []

## Livello di difficoltà crescente (design doc 12.5, sbloccato dopo il primo
## 100+100). 0 = difficoltà base, nessun livello superiore esiste ancora.
var livello_difficolta: int = 0

## Stato del meccanismo "mondo senza sabbia" (design doc sezione 10).
## "normale" = mondo standard; gli altri stati (innescato dagli Eterni,
## mondo maledetto) non sono ancora implementati.
var stato_mondo_senza_sabbia: String = "normale"


func to_dict() -> Dictionary:
	return {
		"karma": karma,
		"rete_contatti_sbloccati": rete_contatti_sbloccati,
		"achievement": achievement,
		"livello_difficolta": livello_difficolta,
		"stato_mondo_senza_sabbia": stato_mondo_senza_sabbia,
	}


static func from_dict(d: Dictionary) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.karma = float(d.get("karma", 0.0))
	p.rete_contatti_sbloccati = d.get("rete_contatti_sbloccati", [])
	p.achievement = d.get("achievement", [])
	p.livello_difficolta = int(d.get("livello_difficolta", 0))
	p.stato_mondo_senza_sabbia = d.get("stato_mondo_senza_sabbia", "normale")
	return p


func save(path: String = DEFAULT_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("PlayerProfile: impossibile scrivere %s (errore %d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(to_dict(), "  "))
	file.close()
	return true


## Se il file non esiste (prima run in assoluto), restituisce un profilo
## nuovo con tutti i valori di default — non e' un errore.
static func load(path: String = DEFAULT_PATH) -> PlayerProfile:
	if not FileAccess.file_exists(path):
		return PlayerProfile.new()

	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if parsed == null or not (parsed is Dictionary):
		push_error("PlayerProfile: JSON non valido in %s, uso profilo di default" % path)
		return PlayerProfile.new()

	return PlayerProfile.from_dict(parsed)
