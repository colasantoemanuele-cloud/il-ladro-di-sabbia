#!/usr/bin/env python3
"""
Fase 9b — estrae le 10 sottotrame endgame dal foglio "Endgame" di
ladro_di_sabbia_bilanciamento.xlsx (sezione "4. LE 10 SOTTOTRAME") e le
scrive come data/sottotrame.json, letto a runtime da SubplotDatabase
(scripts/data/subplot_database.gd), sullo stesso pattern di
extract_azioni.py/extract_tracce.py.

Il prerequisito di "Il tesoro del vecchio boss" (richiede prima l'azione
"Riattivare un vecchio contatto della rete criminale", già completata con
successo in questa run) NON è una colonna del foglio Excel: è testo
narrativo nel design doc, sezione 6.1. Aggiunto qui a mano (unico caso:
nessun'altra sottotrama ha un prerequisito codificato in questa fase).

Uso: python3 tools/extract_sottotrame.py
Richiede: pip install openpyxl
"""

import json
import sys
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parent.parent
XLSX_PATH = ROOT / "ladro_di_sabbia_bilanciamento.xlsx"
JSON_PATH = ROOT / "data" / "sottotrame.json"

FIRST_ROW = 41
LAST_ROW = 50

# Design doc 6.1: unico prerequisito esplicito tra le 10 sottotrame.
PREREQUISITI = {
    "Il tesoro del vecchio boss": "Riattivare un vecchio contatto della rete criminale",
}


## Estrae le sottotrame dal workbook già aperto, senza scrivere su disco:
## riusata da main() e da tools/check_data_consistency.py (unica fonte di
## verità sul parsing di questa sezione del foglio Endgame).
def estrai_sottotrame(wb) -> list:
    ws = wb["Endgame"]

    sottotrame = []
    for row in ws.iter_rows(min_row=FIRST_ROW, max_row=LAST_ROW):
        nome = row[0].value
        if nome is None:
            continue
        sottotrame.append({
            "nome": nome,
            "costo_tempo_figlia_ore": row[1].value,
            "effetto_sabbia_padre_ore": row[2].value,
            "rischio_pct": row[3].value,
            "nota": row[4].value,
            "prerequisito": PREREQUISITI.get(nome),
        })

    return sottotrame


def main() -> None:
    wb = openpyxl.load_workbook(XLSX_PATH, data_only=True)
    sottotrame = estrai_sottotrame(wb)

    output = {
        "_meta": {
            "fonte": "ladro_di_sabbia_bilanciamento.xlsx, foglio Endgame, sezione 4 (LE 10 SOTTOTRAME); "
                     "prerequisito di 'Il tesoro del vecchio boss' da design doc sezione 6.1, non dall'Excel",
            "numero_sottotrame": len(sottotrame),
        },
        "sottotrame": sottotrame,
    }

    JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"Scritte {len(sottotrame)} sottotrame in {JSON_PATH}")
    if len(sottotrame) != 10:
        print(f"ATTENZIONE: attese 10 sottotrame, trovate {len(sottotrame)}.", file=sys.stderr)
    n_prereq = sum(1 for s in sottotrame if s["prerequisito"])
    print(f"Di cui con prerequisito esplicito: {n_prereq}")


if __name__ == "__main__":
    main()
