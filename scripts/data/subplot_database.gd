extends Node
## Autoload (singleton): carica data/sottotrame.json a runtime, sullo stesso
## pattern di ActionDatabase/TrackDatabase. Nessuna logica di gioco qui:
## solo accesso ai dati.

const DATA_PATH := "res://data/sottotrame.json"

var sottotrame: Array[SubplotData] = []


func _ready() -> void:
	load_data()


func load_data() -> void:
	sottotrame.clear()

	if not FileAccess.file_exists(DATA_PATH):
		push_error("SubplotDatabase: file dati non trovato: %s" % DATA_PATH)
		return

	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("SubplotDatabase: JSON non valido in %s" % DATA_PATH)
		return

	for entry in parsed.get("sottotrame", []):
		sottotrame.append(SubplotData.from_dict(entry))


func get_all() -> Array[SubplotData]:
	return sottotrame
