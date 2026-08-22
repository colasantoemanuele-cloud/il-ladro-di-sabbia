extends Node
## Autoload (singleton): carica data/tracce.json a runtime, sullo stesso
## pattern di ActionDatabase. Nessuna logica di gioco qui: solo accesso ai
## dati.

const DATA_PATH := "res://data/tracce.json"

var tracce_normali: Array[TrackData] = []
var tracce_bonus: Array[TrackBonusData] = []


func _ready() -> void:
	load_data()


func load_data() -> void:
	tracce_normali.clear()
	tracce_bonus.clear()

	if not FileAccess.file_exists(DATA_PATH):
		push_error("TrackDatabase: file dati non trovato: %s" % DATA_PATH)
		return

	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("TrackDatabase: JSON non valido in %s" % DATA_PATH)
		return

	for entry in parsed.get("tracce_normali", []):
		tracce_normali.append(TrackData.from_dict(entry))
	for entry in parsed.get("tracce_bonus", []):
		tracce_bonus.append(TrackBonusData.from_dict(entry))


func get_tracce_normali() -> Array[TrackData]:
	return tracce_normali


func get_tracce_bonus() -> Array[TrackBonusData]:
	return tracce_bonus


func get_riga(nome_traccia: String, rango: int) -> TrackData:
	for t in tracce_normali:
		if t.traccia == nome_traccia and t.rango == rango:
			return t
	return null


## Nomi delle 7 tracce normali, nell'ordine in cui compaiono nel foglio.
func get_nomi_tracce_normali() -> Array:
	var seen := {}
	var out := []
	for t in tracce_normali:
		if not seen.has(t.traccia):
			seen[t.traccia] = true
			out.append(t.traccia)
	return out
