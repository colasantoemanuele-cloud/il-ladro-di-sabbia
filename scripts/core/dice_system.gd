class_name DiceSystem
extends RefCounted
## Risoluzione del Rischio% con un tiro di dado d20 (design doc sezione 4.6).
## Nessuno stato: solo funzioni statiche pure, così sia il loop di gioco sia
## il simulatore di bilanciamento (Fase 5) usano esattamente la stessa
## implementazione.

enum RollMode { NORMALE, VANTAGGIO, SVANTAGGIO }


class RollResult:
	var dadi: Array[int] = []
	var naturale: int = 0      ## valore del dado tenuto, PRIMA dei modificatori
	var modificatore: int = 0
	var totale: int = 0        ## naturale + modificatore
	var cd: int = 0
	var successo_critico: bool = false  ## naturale == 20
	var fallimento_critico: bool = false  ## naturale == 1
	var successo: bool = false

	func _to_string() -> String:
		var esito := "CRITICO" if successo_critico else ("FALLIMENTO CRITICO" if fallimento_critico else ("successo" if successo else "fallimento"))
		return "dadi=%s naturale=%d totale=%d CD=%d -> %s" % [dadi, naturale, totale, cd, esito]


## CD = 1 + arrotonda(Rischio% x 20). Esempio dal design doc: Rischio 50% -> CD 11.
static func calcola_cd(rischio_pct: float) -> int:
	return 1 + roundi(rischio_pct * 20.0)


static func tira_d20() -> int:
	return randi_range(1, 20)


## Risolve un'azione con Rischio% `rischio_pct`, un'eventuale
## Vantaggio/Svantaggio (2d20, tieni il migliore/peggiore) e un
## Bonus/Malus fisso `modificatore` (positivo = bonus, negativo = malus)
## sommato al dado DOPO aver scelto Vantaggio/Svantaggio.
## Naturale 20 = successo automatico, naturale 1 = fallimento automatico:
## entrambi ignorano CD e modificatori, come da design doc 4.6.
static func risolvi(rischio_pct: float, modo: RollMode = RollMode.NORMALE, modificatore: int = 0) -> RollResult:
	var d1 := tira_d20()
	var dadi: Array[int] = [d1]
	var naturale := d1

	if modo != RollMode.NORMALE:
		var d2 := tira_d20()
		dadi.append(d2)
		naturale = max(d1, d2) if modo == RollMode.VANTAGGIO else min(d1, d2)

	var res := RollResult.new()
	res.dadi = dadi
	res.naturale = naturale
	res.modificatore = modificatore
	res.totale = naturale + modificatore
	res.cd = calcola_cd(rischio_pct)
	res.successo_critico = naturale == 20
	res.fallimento_critico = naturale == 1
	res.successo = res.successo_critico or (not res.fallimento_critico and res.totale >= res.cd)
	return res
