class_name PlayerProfile
extends RefCounted
## Profilo Persistente (design doc 4.7, architettura di salvataggio a due
## livelli): file permanente che sopravvive tra le run, a differenza dello
## Stato di Run (GameState, effimero, solo in memoria).
##
## Fase 7: solo la STRUTTURA del salvataggio. `karma` e (dal batch tecnico
## post-Fase-10) `livello_difficolta`/`traguardo_100_100_raggiunto` hanno
## un collegamento reale al gioco — vedi GameState/main.gd. `rete_contatti_
## sbloccati`, `achievement` e `stato_mondo_senza_sabbia` restano vuoti/a
## default finché i rispettivi sistemi (Rete di contatti — solo lo
## scheletro tecnico esiste, vedi contact_network.gd — e mondo senza
## sabbia) non saranno implementati.

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

## Livello di difficoltà crescente (design doc 12.5): il livello a cui il
## giocatore ha scelto di giocare l'ultima volta (0 = base). Persistito così
## la UI/CLI possono riproporlo come default alla run successiva.
var livello_difficolta: int = 0

## True se il giocatore ha raggiunto il traguardo 100+100 anni ALMENO una
## volta (in qualunque run, con la donazione finale — GameState.dona() +
## calcola_punteggio().vittoria_100_100). Design doc 12.5: "dopo il primo
## traguardo 100+100 anni, si sbloccano i livelli di difficoltà crescente"
## — finché è false, solo il livello 0 è selezionabile (invariato finché
## questo campo non diventa true). Gate applicato dal chiamante (main.gd),
## non da GameState, che si fida del livello ricevuto.
var traguardo_100_100_raggiunto: bool = false

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
		"traguardo_100_100_raggiunto": traguardo_100_100_raggiunto,
		"stato_mondo_senza_sabbia": stato_mondo_senza_sabbia,
	}


static func from_dict(d: Dictionary) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.karma = float(d.get("karma", 0.0))
	p.rete_contatti_sbloccati = d.get("rete_contatti_sbloccati", [])
	p.achievement = d.get("achievement", [])
	p.livello_difficolta = int(d.get("livello_difficolta", 0))
	p.traguardo_100_100_raggiunto = bool(d.get("traguardo_100_100_raggiunto", false))
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
