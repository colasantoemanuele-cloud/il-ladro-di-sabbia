#!/usr/bin/env python3
"""
Batch tecnico (autore in viaggio) — controllo di coerenza tra il foglio
Excel (fonte di verità, ladro_di_sabbia_bilanciamento.xlsx) e i tre file
JSON che il gioco legge a runtime (data/azioni.json, data/tracce.json,
data/sottotrame.json).

Non rigenera né corregge nulla: SOLO segnala. Se un JSON è disallineato
dall'Excel, la correzione è rilanciare lo script di estrazione pertinente
(tools/extract_azioni.py / extract_tracce.py / extract_sottotrame.py) —
questo script serve a scoprire PRIMA che serva farlo, non a farlo.

Riusa la stessa logica di parsing degli script extract_*.py (le funzioni
estrai_azioni()/estrai_tracce()/estrai_sottotrame(), refactored per questo
scopo senza cambiare il loro comportamento — vedi CLAUDE.md) invece di
duplicarla indipendentemente: un secondo parser scritto da zero rischia di
segnalare differenze spurie dovute a un proprio bug, non a una vera
discrepanza tra Excel e JSON. Confronta quindi "cosa direbbe l'estrattore
se rilanciato ORA" con "cosa c'è davvero nel JSON committato" — il caso
pratico che conta (qualcuno ha modificato l'Excel e dimenticato di
rigenerare il JSON).

Uso: python3 tools/check_data_consistency.py
Richiede: pip install openpyxl

Uscita: 0 se nessuna discrepanza, 1 se ne trova almeno una (utile in CI/
script — non è un giudizio su quale dei due file "ha ragione": l'Excel è
per definizione la fonte di verità, quindi una discrepanza significa
sempre "il JSON va rigenerato", salvo il caso raro di un bug
nell'estrattore stesso).
"""

import json
import sys
from pathlib import Path

import openpyxl

sys.path.insert(0, str(Path(__file__).resolve().parent))
import extract_azioni
import extract_sottotrame
import extract_tracce

ROOT = Path(__file__).resolve().parent.parent
XLSX_PATH = ROOT / "ladro_di_sabbia_bilanciamento.xlsx"

FLOAT_TOLLERANZA = 1e-6


def _valori_diversi(a, b) -> bool:
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return abs(a - b) > FLOAT_TOLLERANZA
    return a != b


def _carica_json(path: Path):
    if not path.exists():
        return None
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _confronta_elenchi(nome_dataset: str, chiave_id, attesi: list, attuali: list, campi_da_confrontare: list) -> list:
    """Confronta due liste di dict (attesi = dall'Excel appena letto,
    attuali = dal JSON committato), indicizzate da chiave_id (funzione che
    estrae la chiave identificativa da un elemento). Restituisce una lista
    di stringhe-problema (vuota se tutto coincide)."""
    problemi = []
    attesi_per_chiave = {chiave_id(a): a for a in attesi}
    attuali_per_chiave = {chiave_id(a): a for a in attuali}

    mancanti_nel_json = set(attesi_per_chiave) - set(attuali_per_chiave)
    extra_nel_json = set(attuali_per_chiave) - set(attesi_per_chiave)

    for chiave in sorted(mancanti_nel_json, key=str):
        problemi.append(f"[{nome_dataset}] presente nell'Excel ma MANCANTE nel JSON: {chiave!r}")
    for chiave in sorted(extra_nel_json, key=str):
        problemi.append(f"[{nome_dataset}] presente nel JSON ma ASSENTE dall'Excel (rimosso o rinominato?): {chiave!r}")

    for chiave in sorted(set(attesi_per_chiave) & set(attuali_per_chiave), key=str):
        atteso = attesi_per_chiave[chiave]
        attuale = attuali_per_chiave[chiave]
        for campo in campi_da_confrontare:
            v_atteso = atteso.get(campo)
            v_attuale = attuale.get(campo)
            if _valori_diversi(v_atteso, v_attuale):
                problemi.append(
                    f"[{nome_dataset}] {chiave!r}, campo '{campo}': Excel={v_atteso!r} ma JSON={v_attuale!r}"
                )

    return problemi


def main() -> None:
    if not XLSX_PATH.exists():
        print(f"ERRORE: {XLSX_PATH} non trovato.", file=sys.stderr)
        sys.exit(2)

    wb = openpyxl.load_workbook(XLSX_PATH, data_only=True)

    print("=== CONTROLLO DI COERENZA — Excel (fonte di verità) vs data/*.json ===")
    print()

    tutti_i_problemi = []

    # --- Azioni ---------------------------------------------------------
    azioni_attese, _, _ = extract_azioni.estrai_azioni(wb)
    azioni_json = _carica_json(extract_azioni.JSON_PATH)
    if azioni_json is None:
        tutti_i_problemi.append(f"[Azioni] {extract_azioni.JSON_PATH} non esiste — rilanciare tools/extract_azioni.py.")
    else:
        problemi = _confronta_elenchi(
            "Azioni", lambda a: a["nome"], azioni_attese, azioni_json.get("azioni", []),
            campi_da_confrontare=[
                "categoria", "costo_tempo_figlia_ore", "valore_economico_eur",
                "effetto_sabbia_padre_ore", "effetto_sabbia_padre_anni",
                "rischio_pct", "moralita", "unica_per_run", "fonte_nota",
            ],
        )
        tutti_i_problemi.extend(problemi)
        print(f"Azioni: {len(azioni_attese)} nell'Excel, {len(azioni_json.get('azioni', []))} nel JSON, {len(problemi)} discrepanze.")

    # --- Tracce (normali + bonus) ----------------------------------------
    tracce_normali_attese, tracce_bonus_attese = extract_tracce.estrai_tracce(wb)
    tracce_json = _carica_json(extract_tracce.JSON_PATH)
    if tracce_json is None:
        tutti_i_problemi.append(f"[Tracce] {extract_tracce.JSON_PATH} non esiste — rilanciare tools/extract_tracce.py.")
    else:
        problemi_normali = _confronta_elenchi(
            "Tracce normali", lambda t: (t["traccia"], t["rango"]),
            tracce_normali_attese, tracce_json.get("tracce_normali", []),
            campi_da_confrontare=["nome_rango", "costo_tempo_figlia_ore", "effetto_sabbia_padre_ore", "rischio_pct", "nota"],
        )
        problemi_bonus = _confronta_elenchi(
            "Tracce bonus", lambda t: t["traccia"],
            tracce_bonus_attese, tracce_json.get("tracce_bonus", []),
            campi_da_confrontare=["descrizione"],
        )
        tutti_i_problemi.extend(problemi_normali)
        tutti_i_problemi.extend(problemi_bonus)
        print(f"Tracce normali: {len(tracce_normali_attese)} righe nell'Excel, {len(tracce_json.get('tracce_normali', []))} nel JSON, {len(problemi_normali)} discrepanze.")
        print(f"Tracce bonus: {len(tracce_bonus_attese)} nell'Excel, {len(tracce_json.get('tracce_bonus', []))} nel JSON, {len(problemi_bonus)} discrepanze.")

    # --- Sottotrame -------------------------------------------------------
    sottotrame_attese = extract_sottotrame.estrai_sottotrame(wb)
    sottotrame_json = _carica_json(extract_sottotrame.JSON_PATH)
    if sottotrame_json is None:
        tutti_i_problemi.append(f"[Sottotrame] {extract_sottotrame.JSON_PATH} non esiste — rilanciare tools/extract_sottotrame.py.")
    else:
        problemi = _confronta_elenchi(
            "Sottotrame", lambda s: s["nome"], sottotrame_attese, sottotrame_json.get("sottotrame", []),
            campi_da_confrontare=["costo_tempo_figlia_ore", "effetto_sabbia_padre_ore", "rischio_pct", "nota", "prerequisito"],
        )
        tutti_i_problemi.extend(problemi)
        print(f"Sottotrame: {len(sottotrame_attese)} nell'Excel, {len(sottotrame_json.get('sottotrame', []))} nel JSON, {len(problemi)} discrepanze.")

    print()
    if not tutti_i_problemi:
        print("Nessuna discrepanza: tutti i JSON sono allineati all'Excel.")
        sys.exit(0)

    print(f"=== {len(tutti_i_problemi)} DISCREPANZE TROVATE (non corrette automaticamente) ===")
    for p in tutti_i_problemi:
        print(f"  - {p}")
    print()
    print("Nessuna correzione applicata: rilanciare lo script di estrazione pertinente per allineare il JSON all'Excel.")
    sys.exit(1)


if __name__ == "__main__":
    main()
