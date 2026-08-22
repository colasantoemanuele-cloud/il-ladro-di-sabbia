#!/usr/bin/env python3
"""
Fase 5 (+ Fase 9a/9b/9c) — validazione del tetto economico deterministico
raggiungibile con le 60 azioni core, le 7 tracce normali (14 righe di
rango), le 10 sottotrame endgame e le sinergie tra tracce, entro le 168 ore
di Tempo-Figlia disponibili in una run, IGNORANDO il rischio/dado (limite
superiore teorico: un giocatore con successo garantito su ogni tiro).

Serve a verificare quantitativamente l'affermazione del design doc (sezione
6, sezione 4.4): "con le sole azioni core è impossibile arrivare a 100 anni
per entrambi i personaggi" — e a misurare quanto tracce, sottotrame e
sinergie alzano quel tetto, fino al sistema completo (Fase 9c).

Metodo: knapsack misto sul budget di 168 ore intere.
  - Le azioni marcate "Unica per run" sono knapsack 0/1; le altre restano a
    ripetizione illimitata (knapsack unbounded).
  - Ogni traccia normale è un gruppo a scelta multipla: al massimo UNA tra
    "solo Rango 1" o "Rango 1 + Rango 2" (il Rango 2 richiede sempre il
    Rango 1 della stessa traccia). Le 7 tracce sono indipendenti tra loro.
  - Ogni sottotrama è un item 0/1 (azione una tantum). "Il tesoro del
    vecchio boss" include nel proprio costo anche quello del prerequisito.
  - Sinergie (Fase 9c, design doc 7.3): per ogni possibile combo di 2, 3 o
    4 tracce (su 7 — C(7,2)+C(7,3)+C(7,4) = 91 combinazioni, tutte
    enumerate), si calcola il valore ottenibile FORZANDO quella combo a
    Rango 2 su tutte le tracce coinvolte + il cash-in (costo 8h, guadagno
    = somma dei valori base della combo x moltiplicatore secondo il
    numero di tracce), e si ottimizza il budget RESIDUO su azioni, le
    tracce NON coinvolte nella combo (ancora libere di essere skip/R1/R1+R2)
    e le sottotrame. Il tetto finale è il massimo tra "nessuna sinergia
    tentata" e il migliore tra tutte le 91 combo.

Uso: python3 tools/balance_ceiling.py
"""

import json
from itertools import combinations
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JSON_PATH = ROOT / "data" / "azioni.json"
TRACCE_JSON_PATH = ROOT / "data" / "tracce.json"
SOTTOTRAME_JSON_PATH = ROOT / "data" / "sottotrame.json"
ORE_PER_ANNO = 8760.0
BUDGET_ORE = 168
CASH_IN_COSTO_ORE = 8
SINERGIA_MOLTIPLICATORI = {2: 2.0, 3: 4.0, 4: 8.0}


def _forward_fill(dp: list) -> None:
    """dp[t] deve essere monotona non decrescente ('al massimo t' invece di
    'esattamente t'): garanzia esplicita, non solo assunta dalla ricorrenza."""
    for t in range(1, len(dp)):
        if dp[t - 1] > dp[t]:
            dp[t] = dp[t - 1]


def compute_dp_azioni(azioni: list) -> list:
    candidate = [a for a in azioni if a["costo_tempo_figlia_ore"] > 0 and a["effetto_sabbia_padre_ore"] > 0]
    dp = [0.0] * (BUDGET_ORE + 1)

    for a in candidate:
        if a["unica_per_run"]:
            continue
        c = int(a["costo_tempo_figlia_ore"])
        v = a["effetto_sabbia_padre_ore"]
        for t in range(c, BUDGET_ORE + 1):
            val = dp[t - c] + v
            if val > dp[t]:
                dp[t] = val

    for a in candidate:
        if not a["unica_per_run"]:
            continue
        c = int(a["costo_tempo_figlia_ore"])
        v = a["effetto_sabbia_padre_ore"]
        for t in range(BUDGET_ORE, c - 1, -1):
            val = dp[t - c] + v
            if val > dp[t]:
                dp[t] = val

    _forward_fill(dp)
    return dp


def apply_track_groups(dp: list, tracce_per_nome: dict, escludi: set = frozenset()) -> list:
    dp = dp.copy()
    for nome_traccia, ranghi in tracce_per_nome.items():
        if nome_traccia in escludi:
            continue
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
    _forward_fill(dp)
    return dp


def apply_subplots(dp: list, sottotrame: list, costo_prerequisito_per_nome: dict) -> list:
    dp = dp.copy()
    for s in sottotrame:
        c = int(s["costo_tempo_figlia_ore"])
        if s.get("prerequisito"):
            c += costo_prerequisito_per_nome[s["prerequisito"]]
        v = s["effetto_sabbia_padre_ore"]
        for t in range(BUDGET_ORE, c - 1, -1):
            val = dp[t - c] + v
            if val > dp[t]:
                dp[t] = val
    _forward_fill(dp)
    return dp


def main() -> None:
    data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    azioni = data["azioni"]

    zero_cost_positive = [
        a for a in azioni
        if a["costo_tempo_figlia_ore"] == 0 and a["effetto_sabbia_padre_ore"] > 0 and not a["unica_per_run"]
    ]
    if zero_cost_positive:
        print("ATTENZIONE — azioni a costo Tempo-Figlia 0h, effetto positivo, NON uniche:")
        for a in zero_cost_positive:
            print(f"  - {a['nome']!r}: effetto +{a['effetto_sabbia_padre_ore']:.2f}h, rischio {a['rischio_pct']*100:.0f}%")
        print("  Ripetibile all'infinito: il tetto deterministico sarebbe matematicamente INFINITO. Esclusa dal calcolo sotto.\n")

    dp_azioni = compute_dp_azioni(azioni)
    tetto_solo_azioni_anni = dp_azioni[BUDGET_ORE] / ORE_PER_ANNO
    print(f"Tetto deterministico SOLE AZIONI CORE, budget {BUDGET_ORE}h: {tetto_solo_azioni_anni:.2f} anni\n")

    tracce_data = json.loads(TRACCE_JSON_PATH.read_text(encoding="utf-8"))
    righe_traccia = tracce_data["tracce_normali"]
    tracce_per_nome = {}
    for r in righe_traccia:
        tracce_per_nome.setdefault(r["traccia"], {})[r["rango"]] = r

    dp_con_tracce = apply_track_groups(dp_azioni, tracce_per_nome)
    tetto_con_tracce_anni = dp_con_tracce[BUDGET_ORE] / ORE_PER_ANNO
    print(f"Tetto deterministico AZIONI + TRACCE (senza sottotrame/sinergie): {tetto_con_tracce_anni:.2f} anni "
          f"({tetto_con_tracce_anni - tetto_solo_azioni_anni:+.2f} anni)\n")

    sottotrame_data = json.loads(SOTTOTRAME_JSON_PATH.read_text(encoding="utf-8"))
    sottotrame = sottotrame_data["sottotrame"]
    costo_prerequisito_per_nome = {a["nome"]: int(a["costo_tempo_figlia_ore"]) for a in azioni}

    dp_senza_sinergia = apply_subplots(dp_con_tracce, sottotrame, costo_prerequisito_per_nome)
    tetto_senza_sinergia_anni = dp_senza_sinergia[BUDGET_ORE] / ORE_PER_ANNO
    print(f"Tetto deterministico AZIONI + TRACCE + SOTTOTRAME (senza sinergie): {tetto_senza_sinergia_anni:.2f} anni "
          f"({tetto_senza_sinergia_anni - tetto_con_tracce_anni:+.2f} anni rispetto alle sole tracce)\n")

    # --- Fase 9c: enumerazione esaustiva delle 91 combo di sinergia -----
    def valore_base_traccia(nome: str) -> float:
        r1 = tracce_per_nome[nome][1]
        r2 = tracce_per_nome[nome].get(2)
        return r1["effetto_sabbia_padre_ore"] + (r2["effetto_sabbia_padre_ore"] if r2 else 0.0)

    def costo_traccia_r1r2(nome: str) -> int:
        r1 = tracce_per_nome[nome][1]
        r2 = tracce_per_nome[nome].get(2)
        return int(r1["costo_tempo_figlia_ore"]) + (int(r2["costo_tempo_figlia_ore"]) if r2 else 0)

    nomi_tracce = list(tracce_per_nome.keys())
    migliore_combo = None
    migliore_totale_ore = dp_senza_sinergia[BUDGET_ORE]

    for n, moltiplicatore in SINERGIA_MOLTIPLICATORI.items():
        for combo in combinations(nomi_tracce, n):
            combo_costo = sum(costo_traccia_r1r2(t) for t in combo) + CASH_IN_COSTO_ORE
            if combo_costo > BUDGET_ORE:
                continue
            combo_valore_base = sum(valore_base_traccia(t) for t in combo)
            combo_valore_totale = combo_valore_base * (1 + moltiplicatore)  # guadagno di rango + bonus cash-in

            budget_residuo = BUDGET_ORE - combo_costo
            dp_resto = apply_track_groups(dp_azioni, tracce_per_nome, escludi=set(combo))
            dp_resto = apply_subplots(dp_resto, sottotrame, costo_prerequisito_per_nome)

            totale_ore = combo_valore_totale + dp_resto[budget_residuo]
            if totale_ore > migliore_totale_ore:
                migliore_totale_ore = totale_ore
                migliore_combo = (combo, n, moltiplicatore, combo_costo, combo_valore_totale)

    tetto_anni = migliore_totale_ore / ORE_PER_ANNO

    print(f"Tetto economico deterministico CON SINERGIE (sistema completo: azioni + tracce + sottotrame + "
          f"la migliore tra le 91 combo di sinergia possibili), budget {BUDGET_ORE}h:")
    print(f"  {migliore_totale_ore:,.1f} ore Sabbia-Padre = {tetto_anni:.2f} anni")
    if migliore_combo:
        combo, n, mult, costo, valore = migliore_combo
        print(f"  Combo ottima: {', '.join(combo)} ({n} tracce, moltiplicatore x{mult:.0f}), "
              f"costo combo+cashin={costo}h, guadagno combo (rango+cashin)={valore:,.1f}h")
    else:
        print("  Nessuna sinergia migliora il tetto rispetto a azioni+tracce+sottotrame senza sinergia "
              "(il budget non basta per completare nessuna combo E lasciare margine sufficiente al resto).")
    print(f"  Aumento rispetto al tetto senza sinergie: {tetto_anni - tetto_senza_sinergia_anni:+.2f} anni "
          f"({(tetto_anni/tetto_senza_sinergia_anni - 1)*100:+.1f}%)")
    print(f"  Soglia vittoria 100+100 anni = {100*ORE_PER_ANNO:,.0f} ore per personaggio")
    print(f"  Rapporto tetto/soglia-100-anni: {tetto_anni/100.0*100:.1f}%")

    # --- AMBIGUITA' DA SEGNALARE: due letture possibili di "somma dei ---
    # valori base delle N tracce" per il cash-in, che il design doc non
    # disambigua esplicitamente. La differenza è enorme: da riportare
    # all'autore, NON risolta unilateralmente qui.
    if migliore_combo:
        combo, n, mult, _, _ = migliore_combo
        base_r1r2 = sum(valore_base_traccia(t) for t in combo)
        base_solo_r2 = sum(tracce_per_nome[t][2]["effetto_sabbia_padre_ore"] for t in combo)
        interpretazione_a = base_r1r2 * (1 + mult)  # quella usata sopra e nel codice di gioco
        interpretazione_b = base_solo_r2 * mult      # alternativa, senza R1 e senza sommare i ranghi già incassati
        print()
        print("AMBIGUITA' DA SEGNALARE (non risolta unilateralmente): il design doc 7.3 dice che il cash-in "
              "\"frutta la somma dei VALORI BASE delle N tracce moltiplicata per\" il fattore, ma non chiarisce "
              "se \"valori base\" = Rango1+Rango2 sommati (interpretazione A, quella usata sopra e nel codice "
              "di gioco: i ranghi si incassano normalmente E IN PIÙ il cash-in dà base x moltiplicatore) oppure "
              "solo il Rango2 (interpretazione B, senza sommare i ranghi già incassati).")
        print(f"  Interpretazione A (quella implementata ora, combo {n} tracce): "
              f"{interpretazione_a:,.1f}h = {interpretazione_a/ORE_PER_ANNO:.2f} anni per la sola combo.")
        print(f"  Interpretazione B (solo Rango2 x moltiplicatore): "
              f"{interpretazione_b:,.1f}h = {interpretazione_b/ORE_PER_ANNO:.2f} anni per la sola combo.")
        print(f"  Il riferimento storico del documento \"Elementi mancanti\" (~206,9 anni per questa stessa "
              f"tripletta) combacia quasi esattamente con l'interpretazione B, non con la A — probabile che "
              f"l'autore intendesse quella. Il codice di gioco (GameState.applica_cash_in) usa attualmente "
              f"l'interpretazione A: da confermare/correggere insieme.")

    print()
    print(f"Tetto SOLE AZIONI CORE: {tetto_solo_azioni_anni:.2f} anni (< 100, coerente col design doc "
          f"4.4/6: \"con le sole azioni core è impossibile arrivare a 100 anni\").")
    print(f"Tetto SISTEMA COMPLETO (azioni + tracce + sottotrame + sinergie): {tetto_anni:.2f} anni per UN SOLO "
          f"personaggio — la vittoria 100+100 richiede ENTRAMBI, quindi va ancora diviso con la donazione.")
    print(f"Riferimento storico del foglio Excel (tracce + sinergia, SENZA sottotrame nello stesso calcolo, "
          f"validazione pre-Fase-9): ~207-208 anni. Il numero qui sopra include ANCHE le sottotrame (che il "
          f"riferimento storico non includeva), quindi non è atteso che coincida: è un confronto tra sistemi "
          f"diversi, non una ri-validazione dello stesso numero.")


if __name__ == "__main__":
    main()
