class_name SubplotData
extends RefCounted
## Una sottotrama endgame (una riga del foglio "Endgame", sezione "LE 10
## SOTTOTRAME"). Nessuna logica di gioco qui: solo dati.
##
## Stessi nomi di campo di ActionData/TrackData per costo/effetto/rischio
## (duck typing deliberato, vedi TrackData) così GameState/BalanceSimulator
## possono trattare azioni, tracce e sottotrame in modo uniforme.

var nome: String
var costo_tempo_figlia_ore: float
var effetto_sabbia_padre_ore: float
var rischio_pct: float
var nota: String
## Nome di un'ActionData che deve essere stata completata CON SUCCESSO in
## questa run prima di poter tentare questa sottotrama. Stringa vuota se
## nessun prerequisito (9 sottotrame su 10). Solo "Il tesoro del vecchio
## boss" ne ha uno, da design doc 6.1 (non da una colonna Excel).
var prerequisito: String


static func from_dict(d: Dictionary) -> SubplotData:
	var s := SubplotData.new()
	s.nome = str(d.get("nome", ""))
	s.costo_tempo_figlia_ore = float(d.get("costo_tempo_figlia_ore", 0.0))
	s.effetto_sabbia_padre_ore = float(d.get("effetto_sabbia_padre_ore", 0.0))
	s.rischio_pct = float(d.get("rischio_pct", 0.0))
	s.nota = str(d.get("nota", ""))
	var prereq = d.get("prerequisito")
	s.prerequisito = str(prereq) if prereq != null else ""
	return s


func _to_string() -> String:
	return "%s costo=%.1fh effetto=%.1fh rischio=%d%%%s" % [
		nome, costo_tempo_figlia_ore, effetto_sabbia_padre_ore, roundi(rischio_pct * 100),
		(" prerequisito=%s" % prerequisito) if prerequisito != "" else ""
	]
