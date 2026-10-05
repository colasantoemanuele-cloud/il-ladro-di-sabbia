class_name ImperoPersistente
extends RefCounted
## Sblocchi permanenti tra una partita e l'altra (contatti, luoghi, piste
## guadagnati con gli obiettivi). Il Karma resta nel Profilo Persistente.

const PERCORSO := "user://impero_persistente.json"

var obiettivi: Dictionary = {}
var contatti: Array = []
var luoghi: Array = []
var piste: Array = []
var partite := 0
var record_anni := 0.0


static func carica(percorso: String = PERCORSO) -> ImperoPersistente:
	var p := ImperoPersistente.new()
	var f := FileAccess.open(percorso, FileAccess.READ)
	if f == null:
		return p
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		p.obiettivi = d.get("obiettivi", {})
		p.contatti = d.get("contatti", [])
		p.luoghi = d.get("luoghi", [])
		p.piste = d.get("piste", [])
		p.partite = int(d.get("partite", 0))
		p.record_anni = float(d.get("record_anni", 0.0))
	return p


func salva(percorso: String = PERCORSO) -> void:
	var f := FileAccess.open(percorso, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"obiettivi": obiettivi, "contatti": contatti, "luoghi": luoghi,
			"piste": piste, "partite": partite, "record_anni": record_anni}))
