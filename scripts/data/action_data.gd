class_name ActionData
extends RefCounted
## Un'azione economica core del gioco (una riga del foglio "Azioni" dell'Excel
## di bilanciamento). Nessuna logica di gioco qui: solo dati.

var nome: String
var categoria: String
var costo_tempo_figlia_ore: float
var valore_economico_eur: float
var effetto_sabbia_padre_ore: float
var effetto_sabbia_padre_anni: float
var rischio_pct: float
var moralita: String
var unica_per_run: bool
var fonte_nota: String


static func from_dict(d: Dictionary) -> ActionData:
	var a := ActionData.new()
	a.nome = _str_or(d.get("nome"), "")
	a.categoria = _str_or(d.get("categoria"), "")
	a.costo_tempo_figlia_ore = _num_or(d.get("costo_tempo_figlia_ore"), 0.0)
	a.valore_economico_eur = _num_or(d.get("valore_economico_eur"), 0.0)
	a.effetto_sabbia_padre_ore = _num_or(d.get("effetto_sabbia_padre_ore"), 0.0)
	a.effetto_sabbia_padre_anni = _num_or(d.get("effetto_sabbia_padre_anni"), 0.0)
	a.rischio_pct = _num_or(d.get("rischio_pct"), 0.0)
	a.moralita = _str_or(d.get("moralita"), "")
	a.unica_per_run = bool(d.get("unica_per_run", false))
	a.fonte_nota = _str_or(d.get("fonte_nota"), "")
	return a


## Alcune celle Excel (es. "Fonte/nota" per azioni ovvie come "Riposare") sono
## vuote e arrivano come JSON null: vanno trattate come stringa/numero vuoti,
## non come errore di parsing.
static func _str_or(value, fallback: String) -> String:
	return fallback if value == null else str(value)


static func _num_or(value, fallback: float) -> float:
	return fallback if value == null else float(value)


func _to_string() -> String:
	return "%s [%s] costo=%.1fh effetto=%.1fh rischio=%d%%" % [
		nome, categoria, costo_tempo_figlia_ore, effetto_sabbia_padre_ore, roundi(rischio_pct * 100)
	]
