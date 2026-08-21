extends Node
## Autoload (singleton): carica data/azioni.json a runtime e lo espone come
## Array[ActionData]. Nessuna logica di gioco qui: solo accesso ai dati.

const DATA_PATH := "res://data/azioni.json"

var azioni: Array[ActionData] = []
var salario_mediano_eur_ora: float = 0.0
var ore_per_anno: float = 8760.0


func _ready() -> void:
	load_data()


func load_data() -> void:
	azioni.clear()

	if not FileAccess.file_exists(DATA_PATH):
		push_error("ActionDatabase: file dati non trovato: %s" % DATA_PATH)
		return

	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("ActionDatabase: JSON non valido in %s" % DATA_PATH)
		return

	var meta: Dictionary = parsed.get("_meta", {})
	salario_mediano_eur_ora = float(meta.get("salario_mediano_eur_ora", 14.9))
	ore_per_anno = float(meta.get("ore_per_anno", 8760))

	var lista: Array = parsed.get("azioni", [])
	for entry in lista:
		azioni.append(ActionData.from_dict(entry))


func get_all() -> Array[ActionData]:
	return azioni


func get_by_index(i: int) -> ActionData:
	if i < 0 or i >= azioni.size():
		return null
	return azioni[i]


func get_by_categoria(categoria: String) -> Array[ActionData]:
	var out: Array[ActionData] = []
	for a in azioni:
		if a.categoria == categoria:
			out.append(a)
	return out


func find_by_nome(nome: String) -> ActionData:
	for a in azioni:
		if a.nome == nome:
			return a
	return null


func get_categorie() -> Array:
	var seen := {}
	var out := []
	for a in azioni:
		if not seen.has(a.categoria):
			seen[a.categoria] = true
			out.append(a.categoria)
	return out
