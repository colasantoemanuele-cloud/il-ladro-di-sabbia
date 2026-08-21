class_name BalanceSimulator
extends RefCounted
## Fase 5: simula molte run del loop core per validare il bilanciamento,
## riusando esattamente GameState/DiceSystem/ActionDatabase (nessuna logica
## di gioco duplicata tra "gioco vero" e simulatore, vedi CLAUDE.md).
##
## Due politiche di scelta azione, nessuna delle due pensata per essere
## "l'IA del gioco": servono solo a generare distribuzioni di punteggio
## realistiche per il confronto col foglio Excel.
##   - "greedy": ad ogni turno sceglie l'azione affrontabile col miglior
##     valore atteso per ora spesa (approssimazione: (1-rischio)*effetto/costo,
##     costo 0 trattato come "sempre preferita se a valore atteso positivo").
##     Rappresenta un giocatore razionale che ottimizza il rendimento — e per
##     questo trova ed sfrutta l'azione a costo zero (vedi
##     tools/balance_ceiling.py): la usa all'infinito perché non consuma mai
##     il Tempo-Figlia, il che è un risultato reale, non un artefatto.
##   - "greedy_no_free": come "greedy" ma esclude a priori le azioni a costo
##     0h, per mostrare cosa ottiene un giocatore razionale se spende
##     ottimamente solo il budget scarso delle 168 ore — il corrispettivo
##     "con i dadi" del tetto deterministico calcolato da
##     tools/balance_ceiling.py.
##   - "random": ad ogni turno sceglie un'azione affrontabile a caso, incluse
##     quelle a valore atteso negativo. Rappresenta un giocatore che non
##     ottimizza affatto — baseline di confronto.
##
## MAX_TURNI è una valvola di sicurezza, non una regola di gioco: esistono
## azioni a costo 0h con effetto positivo (vedi tools/balance_ceiling.py),
## quindi senza un tetto la politica "greedy" girerebbe all'infinito.

const MAX_TURNI := 1000


static func simula_run(azioni: Array[ActionData], politica: String) -> Dictionary:
	var stato := GameState.new()
	var cap_raggiunto := false

	while not stato.is_over:
		if stato.turno >= MAX_TURNI:
			cap_raggiunto = true
			break

		var azione: ActionData
		match politica:
			"greedy":
				azione = _scegli_greedy(azioni, stato.tempo_figlia_ore, false)
			"greedy_no_free":
				azione = _scegli_greedy(azioni, stato.tempo_figlia_ore, true)
			_:
				azione = _scegli_random(azioni, stato.tempo_figlia_ore)
		if azione == null:
			break  # nessuna azione affrontabile o utile rimasta

		stato.applica_azione_con_dado(azione)

	var punteggio := stato.calcola_punteggio()
	return {
		"turni": stato.turno,
		"end_reason": stato.end_reason,
		"cap_turni_raggiunto": cap_raggiunto,
		"padre_anni": punteggio.padre_anni,
		"figlia_anni": punteggio.figlia_anni,
		"totale_anni": punteggio.punteggio_totale_anni,
		"vittoria_100_100": punteggio.vittoria_100_100,
	}


static func _scegli_greedy(azioni: Array[ActionData], tempo_disponibile: float, escludi_costo_zero: bool) -> ActionData:
	var migliore: ActionData = null
	var miglior_efficienza := -INF
	for a in azioni:
		if a.costo_tempo_figlia_ore > tempo_disponibile:
			continue
		if escludi_costo_zero and a.costo_tempo_figlia_ore == 0.0:
			continue
		var valore_atteso := (1.0 - a.rischio_pct) * a.effetto_sabbia_padre_ore
		if valore_atteso <= 0.0:
			continue
		var efficienza := INF if a.costo_tempo_figlia_ore == 0.0 else valore_atteso / a.costo_tempo_figlia_ore
		if efficienza > miglior_efficienza:
			miglior_efficienza = efficienza
			migliore = a
	return migliore


static func _scegli_random(azioni: Array[ActionData], tempo_disponibile: float) -> ActionData:
	var affrontabili: Array[ActionData] = []
	for a in azioni:
		if a.costo_tempo_figlia_ore <= tempo_disponibile:
			affrontabili.append(a)
	if affrontabili.is_empty():
		return null
	return affrontabili[randi_range(0, affrontabili.size() - 1)]


## Esegue N run con la politica data e restituisce statistiche aggregate.
static func esegui_batch(n_run: int, politica: String) -> Dictionary:
	var azioni := ActionDatabase.get_all()
	var totali: Array[float] = []
	var padri: Array[float] = []
	var figlie: Array[float] = []
	var vittorie := 0
	var cap_raggiunto_count := 0
	var end_reasons := {}
	var turni_totali := 0

	for i in n_run:
		var r := simula_run(azioni, politica)
		totali.append(r.totale_anni)
		padri.append(r.padre_anni)
		figlie.append(r.figlia_anni)
		if r.vittoria_100_100:
			vittorie += 1
		if r.cap_turni_raggiunto:
			cap_raggiunto_count += 1
		turni_totali += r.turni
		var reason_key := str(r.end_reason)
		end_reasons[reason_key] = end_reasons.get(reason_key, 0) + 1

	totali.sort()
	padri.sort()

	return {
		"n_run": n_run,
		"politica": politica,
		"totale_anni_media": _media(totali),
		"totale_anni_mediana": _mediana(totali),
		"totale_anni_min": totali[0] if not totali.is_empty() else 0.0,
		"totale_anni_max": totali[-1] if not totali.is_empty() else 0.0,
		"padre_anni_media": _media(padri),
		"prob_vittoria_100_100": float(vittorie) / n_run,
		"prob_soglie": _prob_soglie(totali),
		"prob_cap_turni_raggiunto": float(cap_raggiunto_count) / n_run,
		"end_reasons": end_reasons,
		"turni_medi": float(turni_totali) / n_run,
	}


static func _media(v: Array[float]) -> float:
	if v.is_empty():
		return 0.0
	var somma := 0.0
	for x in v:
		somma += x
	return somma / v.size()


static func _mediana(v_sorted: Array[float]) -> float:
	if v_sorted.is_empty():
		return 0.0
	var n := v_sorted.size()
	if n % 2 == 1:
		return v_sorted[n / 2]
	return (v_sorted[n / 2 - 1] + v_sorted[n / 2]) / 2.0


static func _prob_soglie(totali_sorted: Array[float]) -> Dictionary:
	var soglie := [10.0, 25.0, 50.0, 100.0, 200.0]
	var out := {}
	for soglia in soglie:
		var count := 0
		for x in totali_sorted:
			if x >= soglia:
				count += 1
		out[soglia] = float(count) / totali_sorted.size()
	return out
