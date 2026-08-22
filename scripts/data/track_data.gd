class_name TrackData
extends RefCounted
## Una riga di rango di una traccia normale (una riga del foglio "Endgame",
## sezione "LE 7 TRACCE NORMALI"). Nessuna logica di gioco qui: solo dati.
##
## Campi con lo stesso nome delle controparti in ActionData
## (costo_tempo_figlia_ore, effetto_sabbia_padre_ore, rischio_pct) di
## proposito: permette a GameState/BalanceSimulator di trattare azioni e
## righe di traccia in modo uniforme (stessa formula di valore atteso,
## stesso motore di risoluzione dado+varianza) senza una vera interfaccia
## comune, che GDScript non ha — è "duck typing" deliberato.

var traccia: String
var rango: int
var nome_rango: String
var costo_tempo_figlia_ore: float
var effetto_sabbia_padre_ore: float
var rischio_pct: float
var nota: String


static func from_dict(d: Dictionary) -> TrackData:
	var t := TrackData.new()
	t.traccia = str(d.get("traccia", ""))
	t.rango = int(d.get("rango", 0))
	t.nome_rango = str(d.get("nome_rango", ""))
	t.costo_tempo_figlia_ore = float(d.get("costo_tempo_figlia_ore", 0.0))
	t.effetto_sabbia_padre_ore = float(d.get("effetto_sabbia_padre_ore", 0.0))
	t.rischio_pct = float(d.get("rischio_pct", 0.0))
	t.nota = str(d.get("nota", ""))
	return t


func _to_string() -> String:
	return "%s Rango %d (%s) costo=%.1fh effetto=%.1fh rischio=%d%%" % [
		traccia, rango, nome_rango, costo_tempo_figlia_ore, effetto_sabbia_padre_ore, roundi(rischio_pct * 100)
	]
