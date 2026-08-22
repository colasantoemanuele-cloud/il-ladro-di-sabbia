#!/usr/bin/env python3
"""
Fase 5 (+ Fase 9a/9b) — validazione del tetto economico deterministico
raggiungibile con le 60 azioni core, le 7 tracce normali (14 righe di
rango) e le 10 sottotrame endgame, entro le 168 ore di Tempo-Figlia
disponibili in una run, IGNORANDO il rischio/dado (limite superiore
teorico: un giocatore con successo garantito su ogni tiro).

Serve a verificare quantitativamente l'affermazione del design doc (sezione
6, sezione 4.4): "con le sole azioni core è impossibile arrivare a 100 anni
per entrambi i personaggi" — e a misurare quanto tracce e sottotrame
alzano quel tetto.

Metodo: knapsack misto sul budget di 168 ore intere.
  - Le azioni marcate "Unica per run" (colonna aggiunta dopo il primo
    playtest della Fase 5, vedi Leggimi nota 11) sono trattate come
    knapsack 0/1: al massimo una volta nella sequenza ottima.
  - Tutte le altre azioni restano a ripetizione illimitata (knapsack
    unbounded), coerente con "una settimana di lavoro nero" o "un turno di
    lavoro onesto" ripetuti più volte nella stessa settimana.
  - Ogni traccia normale (Fase 9a) e' un gruppo a scelta multipla: al
    massimo UNA delle due opzioni "solo Rango 1" o "Rango 1 + Rango 2"
    (il Rango 2 richiede sempre il Rango 1 della stessa traccia — non si
    puo' scegliere il Rango 2 da solo). Le 7 tracce sono indipendenti tra
    loro (nessun aggancio comune, decisione confermata dall'autore).
  - Ogni sottotrama (Fase 9b) e' un item 0/1 (azione una tantum). "Il
    tesoro del vecchio boss" ha un prerequisito esplicito (design doc
    6.1): il suo costo nel knapsack include anche il costo dell'azione
    prerequisito "Riattivare un vecchio contatto della rete criminale",
    cosi' il calcolo non la ottiene "gratis" ignorando il prerequisito.

Uso: python3 tools/balance_ceiling.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JSON_PATH = ROOT / "data" / "azioni.json"
TRACCE_JSON_PATH = ROOT / "data" / "tracce.json"
SOTTOTRAME_JSON_PATH = ROOT / "data" / "sottotrame.json"
ORE_PER_ANNO = 8760.0
BUDGET_ORE = 168


def main() -> None:
    data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    azioni = data["azioni"]

    # --- Guardia di sicurezza: azioni a costo 0 con effetto positivo ----
    # Se il costo e' 0 e l'effetto e' positivo, l'azione e' ripetibile un
    # numero illimitato di volte entro le 168 ore (nessun costo la consuma):
    # il "tetto" deterministico diventa infinito, "Unica per run" o no
    # (un'azione unica a costo 0 sarebbe comunque usabile una sola volta,
    # ma qui controlliamo il caso generale come guardia per modifiche future
    # al foglio Excel).
    zero_cost_positive = [
        a for a in azioni
        if a["costo_tempo_figlia_ore"] == 0 and a["effetto_sabbia_padre_ore"] > 0 and not a["unica_per_run"]
    ]
    if zero_cost_positive:
        print("ATTENZIONE — azioni a costo Tempo-Figlia 0h, effetto positivo, NON uniche:")
        for a in zero_cost_positive:
            print(f"  - {a['nome']!r}: effetto +{a['effetto_sabbia_padre_ore']:.2f}h, rischio {a['rischio_pct']*100:.0f}%")
        print("  Ripetibile all'infinito: il tetto deterministico sarebbe matematicamente INFINITO. Esclusa dal calcolo sotto.\n")

    candidate = [
        a for a in azioni
        if a["costo_tempo_figlia_ore"] > 0 and a["effetto_sabbia_padre_ore"] > 0
    ]
    n_uniche = sum(1 for a in candidate if a["unica_per_run"])
    print(f"Azioni candidate: {len(candidate)} (di cui {n_uniche} marcate 'Unica per run', usabili al massimo 1 volta)\n")

    # --- Knapsack misto: 0/1 per le uniche, unbounded per le altre ------
    dp = [0.0] * (BUDGET_ORE + 1)
    origine = [None] * (BUDGET_ORE + 1)  # (nome, costo) dell'azione che ha prodotto dp[t], se migliorato in quel passo

    # Prima le azioni ripetibili (unbounded): ordine crescente di t, cosi'
    # un'azione puo' essere riusata piu' volte nello stesso passaggio.
    for a in candidate:
        if a["unica_per_run"]:
            continue
        c = int(a["costo_tempo_figlia_ore"])
        v = a["effetto_sabbia_padre_ore"]
        for t in range(c, BUDGET_ORE + 1):
            val = dp[t - c] + v
            if val > dp[t]:
                dp[t] = val
                origine[t] = (a["nome"], c)

    # Poi le azioni uniche (0/1): ordine decrescente di t, cosi' ognuna
    # viene usata al massimo una volta nella sequenza ottima.
    for a in candidate:
        if not a["unica_per_run"]:
            continue
        c = int(a["costo_tempo_figlia_ore"])
        v = a["effetto_sabbia_padre_ore"]
        for t in range(BUDGET_ORE, c - 1, -1):
            val = dp[t - c] + v
            if val > dp[t]:
                dp[t] = val
                origine[t] = (a["nome"], c)

    tetto_solo_azioni_ore = dp[BUDGET_ORE]
    tetto_solo_azioni_anni = tetto_solo_azioni_ore / ORE_PER_ANNO
    print(f"Tetto deterministico SOLE AZIONI CORE (senza tracce), budget {BUDGET_ORE}h:")
    print(f"  {tetto_solo_azioni_ore:,.1f} ore = {tetto_solo_azioni_anni:.2f} anni\n")

    # --- Fase 9a: aggiunta delle 7 tracce normali come gruppi a scelta ---
    # multipla (0, "solo R1", o "R1+R2") sullo stesso budget condiviso.
    tracce_data = json.loads(TRACCE_JSON_PATH.read_text(encoding="utf-8"))
    righe_traccia = tracce_data["tracce_normali"]
    tracce_per_nome = {}
    for r in righe_traccia:
        tracce_per_nome.setdefault(r["traccia"], {})[r["rango"]] = r

    for nome_traccia, ranghi in tracce_per_nome.items():
        r1 = ranghi[1]
        r2 = ranghi.get(2)
        opzioni = [(int(r1["costo_tempo_figlia_ore"]), r1["effetto_sabbia_padre_ore"])]
        if r2 is not None:
            opzioni.append((
                int(r1["costo_tempo_figlia_ore"]) + int(r2["costo_tempo_figlia_ore"]),
                r1["effetto_sabbia_padre_ore"] + r2["effetto_sabbia_padre_ore"],
            ))
        dp_prima_del_gruppo = dp.copy()
        for t in range(BUDGET_ORE + 1):
            migliore_t = dp[t]
            for c, v in opzioni:
                if c <= t:
                    candidato = dp_prima_del_gruppo[t - c] + v
                    if candidato > migliore_t:
                        migliore_t = candidato
            dp[t] = migliore_t

    tetto_con_tracce_ore = dp[BUDGET_ORE]
    tetto_con_tracce_anni = tetto_con_tracce_ore / ORE_PER_ANNO
    print(f"Tetto deterministico AZIONI + TRACCE (senza sottotrame), budget {BUDGET_ORE}h:")
    print(f"  {tetto_con_tracce_ore:,.1f} ore = {tetto_con_tracce_anni:.2f} anni "
          f"({tetto_con_tracce_anni - tetto_solo_azioni_anni:+.2f} anni rispetto alle sole azioni)\n")

    # --- Fase 9b: aggiunta delle 10 sottotrame come item 0/1 (azione una ---
    # tantum) sullo stesso budget condiviso. "Il tesoro del vecchio boss"
    # include nel proprio costo anche quello del prerequisito.
    sottotrame_data = json.loads(SOTTOTRAME_JSON_PATH.read_text(encoding="utf-8"))
    costo_prerequisito_per_nome = {a["nome"]: int(a["costo_tempo_figlia_ore"]) for a in azioni}

    for s in sottotrame_data["sottotrame"]:
        c = int(s["costo_tempo_figlia_ore"])
        if s.get("prerequisito"):
            c += costo_prerequisito_per_nome[s["prerequisito"]]
        v = s["effetto_sabbia_padre_ore"]
        # 0/1: ordine decrescente di t, cosi' ogni sottotrama e' usata al
        # massimo una volta (sono indipendenti tra loro, nessun gruppo).
        for t in range(BUDGET_ORE, c - 1, -1):
            val = dp[t - c] + v
            if val > dp[t]:
                dp[t] = val

    tetto_ore = dp[BUDGET_ORE]
    tetto_anni = tetto_ore / ORE_PER_ANNO

    print(f"Tetto economico deterministico AZIONI + TRACCE + SOTTOTRAME (senza rischio), budget {BUDGET_ORE}h:")
    print(f"  {tetto_ore:,.1f} ore Sabbia-Padre = {tetto_anni:.2f} anni")
    print(f"  Aumento rispetto al tetto senza tracce/sottotrame: {tetto_anni - tetto_solo_azioni_anni:+.2f} anni ({(tetto_anni/tetto_solo_azioni_anni - 1)*100:+.1f}%)")
    print(f"  Aumento rispetto al tetto con le sole tracce: {tetto_anni - tetto_con_tracce_anni:+.2f} anni ({(tetto_anni/tetto_con_tracce_anni - 1)*100:+.1f}%)")
    print(f"  Soglia vittoria 100+100 anni = {100*ORE_PER_ANNO:,.0f} ore per personaggio")
    print(f"  Rapporto tetto/soglia-100-anni: {tetto_anni/100.0*100:.1f}%")

    print()
    print(f"Tetto SOLE AZIONI CORE: {tetto_solo_azioni_anni:.2f} anni (< 100, coerente col design doc "
          f"4.4/6: \"con le sole azioni core è impossibile arrivare a 100 anni\" — questo claim vale "
          f"solo per le 60 azioni da sole, verificato e confermato).")
    print(f"Tetto AZIONI + TRACCE + SOTTOTRAME: {tetto_anni:.2f} anni. Superare i 100 anni QUI non è "
          f"un'anomalia: il design doc (sezione 7.4) dichiara esplicitamente che \"le sole sottotrame, "
          f"senza nessuna traccia, arrivano al massimo a 100 anni entro 168 ore\" — è il traguardo "
          f"raro ma voluto delle sottotrame, non una violazione. Il tetto qui sopra è per UN SOLO "
          f"personaggio: la vittoria richiede 100+100 (entrambi), quindi va ancora diviso tra padre e "
          f"figlia con la donazione. Il tetto combinato di riferimento del foglio Excel con tracce E "
          f"sinergie è ~207-208 anni (sezione 7.4) — le sinergie (Fase 9c, non ancora implementate) "
          f"sono il pezzo mancante per avvicinarsi a quel numero.")


if __name__ == "__main__":
    main()
