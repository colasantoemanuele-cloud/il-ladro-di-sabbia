class_name BalanceSimulator
extends RefCounted
## Fase 5: simula molte run del loop core per validare il bilanciamento,
## riusando esattamente GameState/DiceSystem/ActionDatabase (nessuna logica
## di gioco duplicata tra "gioco vero" e simulatore, vedi CLAUDE.md). Dalla
## Fase 9a considera anche le 14 righe di rango delle 7 tracce normali
## (TrackDatabase) e dalla Fase 9b le 10 sottotrame (SubplotDatabase),
## trattate come candidati alla pari delle 60 azioni core grazie ai campi
## in comune di ActionData/TrackData/SubplotData (duck typing).
##
## Due politiche di scelta azione, nessuna delle due pensata per essere
## "l'IA del gioco": servono solo a generare distribuzioni di punteggio
## realistiche per il confronto col foglio Excel.
##   - "greedy": ad ogni turno sceglie il candidato affrontabile col miglior
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
##   - "random": ad ogni turno sceglie un candidato affrontabile a caso,
##     inclusi quelli a valore atteso negativo. Rappresenta un giocatore che
##     non ottimizza affatto — baseline di confronto.
##
## MAX_TURNI è una valvola di sicurezza, non una regola di gioco: esistono
## azioni a costo 0h con effetto positivo (vedi tools/balance_ceiling.py),
## quindi senza un tetto la politica "greedy" girerebbe all'infinito.

const MAX_TURNI := 1000


## Candidato "virtuale" per il cash-in di sinergia (Fase 9c): a differenza
## di ActionData/TrackData/SubplotData non viene da un database statico,
## perché costo/effetto/rischio dipendono dallo stato di gioco corrente
## (quali tracce sono a Rango 2 in questo momento). Costruito al volo, un
## turno alla volta, solo quando `stato.cash_in_disponibile()`.
class SynergyCandidate:
	extends RefCounted
	var costo_tempo_figlia_ore: float = GameState.CASH_IN_COSTO_ORE
	var rischio_pct: float = GameState.CASH_IN_RISCHIO_PCT
	var effetto_sabbia_padre_ore: float


static func _candidato_sinergia(stato: GameState) -> SynergyCandidate:
	var combo: Array = stato.combo_tracce()
	var moltiplicatore: float = GameState.SINERGIA_MOLTIPLICATORI.get(combo.size(), GameState.SINERGIA_MOLTIPLICATORI[4])
	var valore_base := 0.0
	for nome in combo:
		valore_base += stato.valore_base_traccia(nome)
	var c := SynergyCandidate.new()
	c.effetto_sabbia_padre_ore = valore_base * moltiplicatore
	return c


## `candidati` è un Array misto di ActionData, TrackData e SubplotData
## (nessuna interfaccia comune in GDScript, ma stessi nomi di campo — vedi
## TrackData). Il tipo di ciascun elemento decide sia il controllo di
## disponibilità sia il metodo di GameState da chiamare. Il cash-in di
## sinergia (SynergyCandidate) viene aggiunto al volo ad ogni turno, solo
## quando disponibile — non fa parte di `candidati` perché non è dati
## statici.
static func simula_run(candidati: Array, politica: String) -> Dictionary:
	var stato := GameState.new()
	var cap_raggiunto := false
	var cashin_tentato := false
	var cashin_riuscito := false

	while not stato.is_over:
		if stato.turno >= MAX_TURNI:
			cap_raggiunto = true
			break

		var pool := candidati
		if stato.cash_in_disponibile():
			pool = candidati.duplicate()
			pool.append(_candidato_sinergia(stato))

		var candidato
		match politica:
			"greedy":
				candidato = _scegli_greedy(pool, stato, false)
			"greedy_no_free":
				candidato = _scegli_greedy(pool, stato, true)
			_:
				candidato = _scegli_random(pool, stato)
		if candidato == null:
			break  # nessun candidato affrontabile o utile rimasto

		if candidato is TrackData:
			stato.applica_traccia(candidato)
		elif candidato is SubplotData:
			stato.applica_sottotrama(candidato)
		elif candidato is SynergyCandidate:
			var r := stato.applica_cash_in()
			cashin_tentato = true
			cashin_riuscito = r.get("successo", false)
		else:
			stato.applica_azione_con_dado(candidato)

	var punteggio := stato.calcola_punteggio()
	return {
		"turni": stato.turno,
		"end_reason": stato.end_reason,
		"cap_turni_raggiunto": cap_raggiunto,
		"padre_anni": punteggio.padre_anni,
		"figlia_anni": punteggio.figlia_anni,
		"totale_anni": punteggio.punteggio_totale_anni,
		"vittoria_100_100": punteggio.vittoria_100_100,
		"cashin_tentato": cashin_tentato,
		"cashin_riuscito": cashin_riuscito,
	}


static func _disponibile(candidato, stato: GameState) -> bool:
	if candidato is TrackData:
		return stato.traccia_disponibile(candidato)
	if candidato is SubplotData:
		return stato.sottotrama_disponibile(candidato)
	if candidato is SynergyCandidate:
		return true  # aggiunto al pool solo quando già disponibile
	return stato.azione_disponibile(candidato)


static func _scegli_greedy(candidati: Array, stato: GameState, escludi_costo_zero: bool):
	var migliore = null
	var miglior_efficienza := -INF
	for c in candidati:
		var costo: float = c.costo_tempo_figlia_ore
		if costo > stato.tempo_figlia_ore:
			continue
		if not _disponibile(c, stato):
			continue
		if escludi_costo_zero and costo == 0.0:
			continue
		var valore_atteso: float = (1.0 - float(c.rischio_pct)) * float(c.effetto_sabbia_padre_ore)
		if valore_atteso <= 0.0:
			continue
		var efficienza: float = INF if costo == 0.0 else valore_atteso / costo
		if efficienza > miglior_efficienza:
			miglior_efficienza = efficienza
			migliore = c
	return migliore


static func _scegli_random(candidati: Array, stato: GameState):
	var affrontabili: Array = []
	for c in candidati:
		if c.costo_tempo_figlia_ore <= stato.tempo_figlia_ore and _disponibile(c, stato):
			affrontabili.append(c)
	if affrontabili.is_empty():
		return null
	return affrontabili[randi_range(0, affrontabili.size() - 1)]


## Esegue N run con la politica data e restituisce statistiche aggregate.
static func esegui_batch(n_run: int, politica: String) -> Dictionary:
	var candidati: Array = []
	candidati.append_array(ActionDatabase.get_all())
	candidati.append_array(TrackDatabase.get_tracce_normali())
	candidati.append_array(SubplotDatabase.get_all())

	var totali: Array[float] = []
	var padri: Array[float] = []
	var figlie: Array[float] = []
	var vittorie := 0
	var cap_raggiunto_count := 0
	var end_reasons := {}
	var turni_totali := 0
	var cashin_tentati := 0
	var cashin_riusciti := 0

	for i in n_run:
		var r := simula_run(candidati, politica)
		totali.append(r.totale_anni)
		padri.append(r.padre_anni)
		figlie.append(r.figlia_anni)
		if r.vittoria_100_100:
			vittorie += 1
		if r.cap_turni_raggiunto:
			cap_raggiunto_count += 1
		if r.cashin_tentato:
			cashin_tentati += 1
			if r.cashin_riuscito:
				cashin_riusciti += 1
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
		"prob_cashin_tentato": float(cashin_tentati) / n_run,
		"prob_cashin_riuscito_se_tentato": (float(cashin_riusciti) / cashin_tentati) if cashin_tentati > 0 else 0.0,
	}


## Sequenza SCRIPTATA (non una politica euristica) che riproduce esattamente
## la "tripletta storica" del design doc 7.4 — Azzardo + Bancaria +
## Religiosa, entrambi i ranghi, poi il cash-in — per misurare col dado vero
## la probabilità di successo dell'INTERA catena, sullo stesso metodo con
## cui il design doc ha validato quel 16,8% deterministico / 8,4% Monte
## Carlo (sezione 7.4/12.7). Serve perché nessuna delle politiche euristiche
## (greedy/random) sceglie mai spontaneamente questa strategia: il design
## doc stesso nota che ha un valore atteso PIÙ BASSO della strategia
## prudente ("un vero biglietto della lotteria"), quindi un ottimizzatore
## miope come "greedy" non la trova mai da solo — bisogna forzarla per
## poterla misurare.
static func simula_tripletta_storica(n_run: int) -> Dictionary:
	var tracce_target := ["Azzardo", "Bancaria", "Religiosa (indulgenze)"]
	var successi_catena := 0
	var punteggi_totali: Array[float] = []
	var punteggi_se_riuscita: Array[float] = []

	for i in n_run:
		var stato := GameState.new()
		var riuscita := true

		for nome in tracce_target:
			for rango in [1, 2]:
				if not riuscita or stato.is_over:
					riuscita = false
					break
				var riga := TrackDatabase.get_riga(nome, rango)
				var r := stato.applica_traccia(riga)
				if r.has("rifiutata") or not r.successo:
					riuscita = false

		if riuscita and not stato.is_over:
			var r_cash := stato.applica_cash_in()
			riuscita = r_cash.get("successo", false)
		else:
			riuscita = false

		if riuscita:
			successi_catena += 1

		var p := stato.calcola_punteggio()
		punteggi_totali.append(p.punteggio_totale_anni)
		if riuscita:
			punteggi_se_riuscita.append(p.punteggio_totale_anni)

	return {
		"n_run": n_run,
		"prob_successo_catena": float(successi_catena) / n_run,
		"punteggio_medio_se_successo": _media(punteggi_se_riuscita),
		"punteggio_medio_totale": _media(punteggi_totali),
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
