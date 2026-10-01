class_name MondoPersistente
extends RefCounted
## Sblocchi permanenti del mondo (contatti e luoghi guadagnati raggiungendo
## obiettivi tra una run e l'altra). File separato dal Profilo Persistente.

const PERCORSO := "user://mondo_persistente.json"

var obiettivi: Dictionary = {}
var contatti: Array = []
var luoghi: Array = []
var run_giocate := 0


static func carica(percorso: String = PERCORSO) -> MondoPersistente:
	var m := MondoPersistente.new()
	var f := FileAccess.open(percorso, FileAccess.READ)
	if f == null:
		return m
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		m.obiettivi = d.get("obiettivi", {})
		m.contatti = d.get("contatti", [])
		m.luoghi = d.get("luoghi", [])
		m.run_giocate = int(d.get("run_giocate", 0))
	return m


func salva(percorso: String = PERCORSO) -> void:
	var f := FileAccess.open(percorso, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"obiettivi": obiettivi, "contatti": contatti, "luoghi": luoghi, "run_giocate": run_giocate}))
