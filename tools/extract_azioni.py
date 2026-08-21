#!/usr/bin/env python3
"""
Estrae la tabella delle azioni dal foglio "Azioni" di
ladro_di_sabbia_bilanciamento.xlsx e la scrive come data/azioni.json,
il formato letto a runtime da ActionDatabase (scripts/data/action_database.gd).

Uso: python3 tools/extract_azioni.py
Richiede: pip install openpyxl

Rilanciare questo script dopo ogni modifica al foglio "Azioni" per
tenere data/azioni.json sincronizzato con l'Excel (fonte di verita').
"""

import json
import sys
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parent.parent
XLSX_PATH = ROOT / "ladro_di_sabbia_bilanciamento.xlsx"
JSON_PATH = ROOT / "data" / "azioni.json"

HEADER_ROW = 5
FIRST_DATA_ROW = 6


def main() -> None:
    wb = openpyxl.load_workbook(XLSX_PATH, data_only=True)
    ws = wb["Azioni"]

    salario_mediano = ws["B2"].value
    ore_anno = ws["B3"].value

    actions = []
    for row in ws.iter_rows(min_row=FIRST_DATA_ROW, max_row=ws.max_row):
        nome = row[0].value
        categoria = row[1].value
        if nome is None or categoria is None:
            # Riga vuota o nota istruttiva in fondo al foglio: non e' un'azione.
            continue
        actions.append({
            "nome": nome,
            "categoria": categoria,
            "costo_tempo_figlia_ore": row[2].value,
            "valore_economico_eur": row[3].value,
            "effetto_sabbia_padre_ore": row[4].value,
            "effetto_sabbia_padre_anni": row[5].value,
            "rischio_pct": row[6].value,
            "moralita": row[7].value,
            "fonte_nota": row[8].value,
        })

    output = {
        "_meta": {
            "fonte": "ladro_di_sabbia_bilanciamento.xlsx, foglio Azioni",
            "salario_mediano_eur_ora": salario_mediano,
            "ore_per_anno": ore_anno,
            "numero_azioni": len(actions),
        },
        "azioni": actions,
    }

    JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"Scritte {len(actions)} azioni in {JSON_PATH}")
    if len(actions) != 61:
        print(
            f"ATTENZIONE: il design doc parla di 61 azioni core, "
            f"ma il foglio Excel ne contiene {len(actions)}.",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
