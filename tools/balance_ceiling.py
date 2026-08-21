#!/usr/bin/env python3
"""
Fase 5 — validazione del tetto economico deterministico raggiungibile con le
sole 60 azioni core, entro le 168 ore di Tempo-Figlia disponibili in una run,
IGNORANDO il rischio/dado (limite superiore teorico: un giocatore con successo
garantito su ogni tiro).

Serve a verificare quantitativamente l'affermazione del design doc (sezione
6, sezione 4.4): "con le sole 61 azioni core è impossibile arrivare a 100
anni per entrambi i personaggi" — qui la verifichiamo con le 60 azioni
realmente presenti nel foglio (vedi CLAUDE.md sulla discrepanza 61 vs 60).

Metodo: unbounded knapsack (le azioni sono ripetibili — nel loop core attuale
non esiste ancora alcun vincolo "una sola volta a run", vedi la segnalazione
sull'azione a costo zero qui sotto) sul budget di 168 ore intere, scegliendo
tra le sole azioni a costo > 0 ed effetto positivo.

Uso: python3 tools/balance_ceiling.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JSON_PATH = ROOT / "data" / "azioni.json"
ORE_PER_ANNO = 8760.0
BUDGET_ORE = 168


def main() -> None:
    data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    azioni = data["azioni"]

    # --- Segnalazione: azioni a costo 0 con effetto positivo -----------
    # Se il costo e' 0 e l'effetto e' positivo, l'azione e' ripetibile un
    # numero illimitato di volte entro le 168 ore (nessun costo la consuma):
    # il "tetto" deterministico diventa infinito. Questo NON e' un bug del
    # mio codice: e' un dato del foglio Excel. Lo segnalo, non lo correggo.
    zero_cost_positive = [
        a for a in azioni
        if a["costo_tempo_figlia_ore"] == 0 and a["effetto_sabbia_padre_ore"] > 0
    ]
    if zero_cost_positive:
        print("ATTENZIONE — azioni a costo Tempo-Figlia 0h con effetto Sabbia-Padre positivo:")
        for a in zero_cost_positive:
            print(f"  - {a['nome']!r}: effetto +{a['effetto_sabbia_padre_ore']:.2f}h, rischio {a['rischio_pct']*100:.0f}%")
        print(
            "  Nel prototipo attuale (nessun vincolo 'una sola volta per run', le "
            "tracce/prerequisiti sono fuori scope) questa azione e' ripetibile un "
            "numero illimitato di volte senza mai consumare Tempo-Figlia: il tetto "
            "economico deterministico e' matematicamente INFINITO se inclusa.\n"
            "  Il calcolo del tetto qui sotto la ESCLUDE per restituire un numero "
            "finito e utile; la si valuta separatamente.\n"
        )

    # --- Unbounded knapsack sulle azioni a costo intero > 0 -------------
    candidate = [
        a for a in azioni
        if a["costo_tempo_figlia_ore"] > 0 and a["effetto_sabbia_padre_ore"] > 0
    ]

    dp = [0.0] * (BUDGET_ORE + 1)
    scelta = [None] * (BUDGET_ORE + 1)
    for t in range(1, BUDGET_ORE + 1):
        dp[t] = dp[t - 1]
        scelta[t] = scelta[t - 1]
        for a in candidate:
            c = int(a["costo_tempo_figlia_ore"])
            if c <= t:
                val = dp[t - c] + a["effetto_sabbia_padre_ore"]
                if val > dp[t]:
                    dp[t] = val
                    scelta[t] = a["nome"]

    tetto_ore = dp[BUDGET_ORE]
    tetto_anni = tetto_ore / ORE_PER_ANNO

    # Ricostruzione della sequenza ottima (solo per leggibilita' del report)
    seq = []
    t = BUDGET_ORE
    lookup = {a["nome"]: a for a in candidate}
    # Ricostruzione approssimata: ripercorriamo scegliendo ad ogni passo
    # l'azione che ha prodotto il valore ottimo in quello stato.
    remaining = BUDGET_ORE
    conteggio = {}
    while remaining > 0 and scelta[remaining] is not None:
        nome = scelta[remaining]
        if nome == scelta[remaining - 1] and dp[remaining] == dp[remaining - 1]:
            # nessuna azione scelta in questo passo di tempo (dp non e' salito)
            remaining -= 1
            continue
        a = lookup[nome]
        c = int(a["costo_tempo_figlia_ore"])
        if remaining - c < 0:
            break
        conteggio[nome] = conteggio.get(nome, 0) + 1
        remaining -= c
        if remaining == 0:
            break

    print(f"Tetto economico deterministico (senza rischio, azione a costo 0 esclusa), budget {BUDGET_ORE}h:")
    print(f"  {tetto_ore:,.1f} ore Sabbia-Padre = {tetto_anni:.2f} anni")
    print(f"  Soglia vittoria 100+100 anni = {100*ORE_PER_ANNO:,.0f} ore per personaggio")
    print(f"  Rapporto tetto/soglia-100-anni: {tetto_anni/100.0*100:.1f}%")
    print()
    print("Composizione approssimativa della sequenza ottima (azione: ripetizioni):")
    for nome, n in sorted(conteggio.items(), key=lambda kv: -lookup[kv[0]]["effetto_sabbia_padre_ore"] * kv[1]):
        a = lookup[nome]
        print(f"  {n:3d}x {nome} (costo {a['costo_tempo_figlia_ore']:.0f}h, +{a['effetto_sabbia_padre_ore']:.1f}h cad.)")

    print()
    print("Le 8 azioni con miglior rapporto effetto/costo (h di Sabbia-Padre per h di Tempo-Figlia):")
    ranked = sorted(candidate, key=lambda a: -a["effetto_sabbia_padre_ore"] / a["costo_tempo_figlia_ore"])
    for a in ranked[:8]:
        rapporto = a["effetto_sabbia_padre_ore"] / a["costo_tempo_figlia_ore"]
        print(f"  {rapporto:10,.1f} h/h  {a['nome']:<55s} costo={a['costo_tempo_figlia_ore']:.0f}h rischio={a['rischio_pct']*100:.0f}%")
    print(
        "  Le prime tre (lotteria, prestito su anni futuri, grande colpo) hanno un "
        "rapporto ordini di grandezza sopra le altre e sono chiaramente pensate come "
        "eventi rari/unici a livello narrativo (jackpot 'raro', 'debito esistenziale', "
        "IL GRANDE COLPO) — ma nulla nel foglio Excel né nel prototipo attuale impedisce "
        "di ripeterle più volte nella stessa run: è l'assenza di un vincolo 'una tantum "
        "per run', non un valore economico sbagliato, a produrre il tetto abnorme sopra."
    )

    print()
    if tetto_anni >= 100.0:
        print("ATTENZIONE: il tetto deterministico supera 100 anni per il solo padre -- "
              "in contraddizione con l'affermazione del design doc che con le sole azioni "
              "core sia impossibile arrivare a 100 anni.")
    else:
        print(f"Coerente col design doc: anche in condizioni ideali (nessun rischio) il "
              f"solo padre non raggiunge 100 anni con le azioni core (tetto {tetto_anni:.2f} < 100). "
              f"Per ENTRAMBI (100+100=200 anni totali) servirebbe piu' del doppio di questo "
              f"tetto, quindi la conclusione del design doc regge chiaramente per il loop core.")


if __name__ == "__main__":
    main()
