class_name Spostamento
extends RefCounted
## Evento con esito incerto aggiuntivo (design doc 12.1, esempio esplicito:
## "uno spostamento da un punto A a un punto B ha una durata variabile
## entro un range e una probabilità indipendente di incidente"). Distinto
## sia dal sistema Rischio%/d20 (4.6, si applica alle 60 azioni core) sia
## dalla varianza ±15%/±20% di ActionVariance (anch'essa sulle 60 azioni):
## questo è un evento a sé, non legato a nessuna riga del foglio Excel.
##
## Numeri (durata base, probabilità e gravità dell'incidente) sono una mia
## scelta placeholder — nessuna azione "spostamento" esiste tra le 60 core,
## quindi non c'è un valore del foglio da riprendere. Da tarare con l'autore
## quando si deciderà come/se integrare eventi di questo tipo nel loop
## principale (es. tra un'azione e l'altra, o come costo di un viaggio verso
## un bersaglio specifico).

const DURATA_MIN_ORE := 1.0
const DURATA_MAX_ORE := 4.0
const PROBABILITA_INCIDENTE := 0.10
const INCIDENTE_RITARDO_MIN_ORE := 2.0
const INCIDENTE_RITARDO_MAX_ORE := 8.0


class Esito:
	var durata_base_ore: float
	var incidente: bool
	var ritardo_extra_ore: float
	var durata_totale_ore: float


static func esegui(rng: RandomNumberGenerator) -> Esito:
	var e := Esito.new()
	e.durata_base_ore = rng.randf_range(DURATA_MIN_ORE, DURATA_MAX_ORE)
	e.incidente = rng.randf() < PROBABILITA_INCIDENTE
	e.ritardo_extra_ore = rng.randf_range(INCIDENTE_RITARDO_MIN_ORE, INCIDENTE_RITARDO_MAX_ORE) if e.incidente else 0.0
	e.durata_totale_ore = e.durata_base_ore + e.ritardo_extra_ore
	return e
