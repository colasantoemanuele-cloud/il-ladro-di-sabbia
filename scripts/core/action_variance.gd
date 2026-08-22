class_name ActionVariance
extends RefCounted
## Varianza roguelite sui costi/guadagni delle azioni (design doc 12.1):
## "Ogni azione ... ha costo e guadagno randomizzati entro un range (non più
## valori fissi)". Range ripresi INVARIATI da quelli già usati nella
## validazione Monte Carlo del foglio Excel (design doc 12.7: "±15% varianza
## sui costi in ore e ±20% sui guadagni") — non ne ho inventati di nuovi.
##
## Varianza moltiplicativa uniforme, simmetrica attorno a 1.0: il valore
## atteso su molte run resta quello nominale del foglio Azioni, la varianza
## rende diversa ogni singola run senza spostare sistematicamente la media
## (verificato in Fase 8, vedi CLAUDE.md).

const VARIANZA_COSTO := 0.15    ## ±15%
const VARIANZA_GUADAGNO := 0.20  ## ±20%


static func costo_variato(azione: ActionData, rng: RandomNumberGenerator) -> float:
	var fattore := 1.0 + rng.randf_range(-VARIANZA_COSTO, VARIANZA_COSTO)
	return max(0.0, azione.costo_tempo_figlia_ore * fattore)


static func effetto_variato(azione: ActionData, rng: RandomNumberGenerator) -> float:
	var fattore := 1.0 + rng.randf_range(-VARIANZA_GUADAGNO, VARIANZA_GUADAGNO)
	return azione.effetto_sabbia_padre_ore * fattore
