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
	var successo_critico: bool = false  ## naturale == 20 (mai vero se senza_tiro)
	var fallimento_critico: bool = false  ## naturale == 1 (mai vero se senza_tiro)
	var successo: bool = false
	var senza_tiro: bool = false  ## Rischio 0%/100%: nessun dado tirato, vedi risolvi()

	func _to_string() -> String:
		if senza_tiro:
			return "nessun tiro (rischio estremo) -> %s" % ("successo automatico" if successo else "fallimento automatico")
		var esito := "CRITICO" if successo_critico else ("FALLIMENTO CRITICO" if fallimento_critico else ("successo" if successo else "fallimento"))
		return "dadi=%s naturale=%d totale=%d CD=%d -> %s" % [dadi, naturale, totale, cd, esito]


## CD = 1 + arrotonda(Rischio% x 20). Esempio dal design doc: Rischio 50% -> CD 11.
static func calcola_cd(rischio_pct: float) -> int:
	return 1 + roundi(rischio_pct * 20.0)


## `rng` opzionale (Fase 8): se fornito, i tiri usano quel generatore seedato
## (rende la run riproducibile dal suo seed — vedi GameState.seed_run) invece
## del generatore globale del motore. Il generatore globale resta il default
## per compatibilità con gli usi esistenti (es. gli script di verifica
## statistica della Fase 3, che non hanno bisogno di riproducibilità).
static func tira_d20(rng: RandomNumberGenerator = null) -> int:
	return rng.randi_range(1, 20) if rng != null else randi_range(1, 20)


## Risolve un'azione con Rischio% `rischio_pct`, un'eventuale
## Vantaggio/Svantaggio (2d20, tieni il migliore/peggiore) e un
## Bonus/Malus fisso `modificatore` (positivo = bonus, negativo = malus)
## sommato al dado DOPO aver scelto Vantaggio/Svantaggio.
## Naturale 20 = successo automatico, naturale 1 = fallimento automatico:
## entrambi ignorano CD e modificatori, come da design doc 4.6.
##
## Casi estremi (design doc 4.6, corretti dopo il playtest della Fase 5):
## Rischio 0% e Rischio 100% NON passano dal tiro di dado, regola dei
## critici inclusa — sono rispettivamente un successo e un fallimento
## automatici. Senza questa eccezione, la regola dei critici (naturale 1/20
## sempre decisivo) applicata anche a questi estremi produceva un tasso di
## riuscita reale di ~95%/~5% invece di 100%/0%, contraddicendo l'intento
## di queste due soglie (azioni neutre sempre valide / eventi automatici
## imposti). Per tutti i rischi intermedi (1%-99%) resta il sistema pieno.
static func risolvi(rischio_pct: float, modo: RollMode = RollMode.NORMALE, modificatore: int = 0, rng: RandomNumberGenerator = null) -> RollResult:
	if rischio_pct <= 0.0 or rischio_pct >= 1.0:
		var estremo := RollResult.new()
		estremo.senza_tiro = true
		estremo.cd = calcola_cd(rischio_pct)
		estremo.modificatore = modificatore
		estremo.successo = rischio_pct <= 0.0
		return estremo

	var d1 := tira_d20(rng)
	var dadi: Array[int] = [d1]
	var naturale := d1

	if modo != RollMode.NORMALE:
		var d2 := tira_d20(rng)
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
