class_name TrackBonusData
extends RefCounted
## Una traccia bonus (Eterni, Rete di scienziati criminali, Magica): solo
## narrativa, nessun valore economico fisso (foglio Endgame, sezione "LE 3
## TRACCE BONUS"). Fase 9a: solo dati + placeholder in UI, nessuna logica —
## il contenuto vero arriva quando i testi narrativi saranno scritti.

var traccia: String
var descrizione: String


static func from_dict(d: Dictionary) -> TrackBonusData:
	var t := TrackBonusData.new()
	t.traccia = str(d.get("traccia", ""))
	t.descrizione = str(d.get("descrizione", ""))
	return t
