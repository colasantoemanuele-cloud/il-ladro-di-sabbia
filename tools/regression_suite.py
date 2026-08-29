#!/usr/bin/env python3
"""
Batch tecnico (autore in viaggio) — suite di regressione unica: esegue in
sequenza tutte le verifiche già esistenti nel progetto (sparse tra Godot
headless e script Python) e produce un report aggregato PASS/FAIL, più i
numeri chiave (i tetti economici e le probabilità di riferimento).

Comando di riferimento per "verifica generale dello stato del progetto"
(vedi CLAUDE.md). Pensato per essere rilanciato dopo ogni fase/task, non
solo una tantum.

Uso: python3 tools/regression_suite.py [--simulate=N] [--godot=PATH]

  --simulate=N   run per politica nel Monte Carlo (default 500 — un
                 compromesso deliberato: 2000-3000 run, il numero usato
                 nei report "ufficiali" di fase, richiede diversi minuti;
                 500 basta per un controllo di regressione rapido e dà
                 comunque numeri stabili entro un paio di punti percentuali)
  --godot=PATH   eseguibile Godot da usare (default: "godot" nel PATH)

Uscita: codice 0 se tutte le verifiche passano, 1 altrimenti (utile per
CI/script). Ogni verifica ha un timeout individuale per non bloccare
l'intera suite se una singola invocazione si blocca.
"""

import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TIMEOUT = 120
SIMULATE_TIMEOUT = 600


def _parse_args():
    simulate_n = 500
    godot_bin = "godot"
    for a in sys.argv[1:]:
        if a.startswith("--simulate="):
            simulate_n = int(a.split("=", 1)[1])
        elif a.startswith("--godot="):
            godot_bin = a.split("=", 1)[1]
    return simulate_n, godot_bin


def _run_godot(godot_bin: str, args: list, timeout: int) -> subprocess.CompletedProcess:
    cmd = [godot_bin, "--headless", "--path", str(ROOT), "--"] + args
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=ROOT)


def _godot_test_ok(proc: subprocess.CompletedProcess, marker: str) -> tuple:
    """Un test headless e' considerato PASS solo se il marker di
    completamento compare in stdout E non compaiono errori — l'exit code
    di Godot da solo non e' affidabile per un assert() fallito (Godot
    stampa 'Assertion failed' ma non sempre esce con codice diverso da 0
    in build release)."""
    out = proc.stdout + proc.stderr
    ha_marker = marker in out
    ha_errori = ("Assertion failed" in out) or ("SCRIPT ERROR" in out) or ("Parse Error" in out)
    ok = ha_marker and not ha_errori
    dettaglio = "" if ok else _ultime_righe(out, 8)
    return ok, dettaglio


def _ultime_righe(testo: str, n: int) -> str:
    righe = [r for r in testo.splitlines() if r.strip()]
    return "\n".join(righe[-n:])


class Risultato:
    def __init__(self, nome: str, ok: bool, dettaglio: str = "", numeri: str = ""):
        self.nome = nome
        self.ok = ok
        self.dettaglio = dettaglio
        self.numeri = numeri


def check_knapsack() -> Risultato:
    try:
        proc = subprocess.run(
            [sys.executable, str(ROOT / "tools" / "balance_ceiling.py")],
            capture_output=True, text=True, timeout=DEFAULT_TIMEOUT, cwd=ROOT,
        )
    except subprocess.TimeoutExpired:
        return Risultato("Knapsack deterministico (tools/balance_ceiling.py)", False, "timeout")

    out = proc.stdout
    ok = proc.returncode == 0 and "Tetto SOLE AZIONI CORE" in out
    if not ok:
        return Risultato("Knapsack deterministico (tools/balance_ceiling.py)", False, _ultime_righe(out + proc.stderr, 8))

    def cerca(pattern, testo):
        m = re.search(pattern, testo)
        return m.group(1) if m else "?"

    core = cerca(r"SOLE AZIONI CORE, budget \d+h: ([\d,.]+) anni", out)
    tracce = cerca(r"AZIONI \+ TRACCE \(senza sottotrame/sinergie\): ([\d,.]+) anni", out)
    sottotrame = cerca(r"AZIONI \+ TRACCE \+ SOTTOTRAME \(senza sinergie\): ([\d,.]+) anni", out)
    sinergie = cerca(r"CON SINERGIE.*?\n\s*[\d,.]+ ore Sabbia-Padre = ([\d,.]+) anni", out)

    numeri = f"core={core}  +tracce={tracce}  +sottotrame={sottotrame}  +sinergie={sinergie} anni"
    return Risultato("Knapsack deterministico (tools/balance_ceiling.py)", True, "", numeri)


def check_monte_carlo(godot_bin: str, n: int) -> Risultato:
    nome = f"Monte Carlo (--simulate={n})"
    try:
        proc = _run_godot(godot_bin, [f"--simulate={n}"], SIMULATE_TIMEOUT)
    except subprocess.TimeoutExpired:
        return Risultato(nome, False, "timeout")

    out = proc.stdout
    ok = proc.returncode == 0 and "Politica: greedy" in out and "tripletta storica" in out
    if not ok:
        return Risultato(nome, False, _ultime_righe(out + proc.stderr, 8))

    m_media = re.search(r"--- Politica: greedy \(\d+ run\) ---\n.*?media=([\d.]+)", out, re.S)
    m_tripletta = re.search(r"successo dell'INTERA catena.*?: ([\d.]+)%", out)
    media = m_media.group(1) if m_media else "?"
    tripletta = m_tripletta.group(1) if m_tripletta else "?"

    numeri = f"greedy media={media} anni  |  tripletta storica={tripletta}%"
    return Risultato(nome, True, "", numeri)


def check_salvataggio(godot_bin: str) -> Risultato:
    nome = "Salvataggio (--test-save-write + --test-save-read)"
    try:
        p1 = _run_godot(godot_bin, ["--test-save-write"], DEFAULT_TIMEOUT)
        p2 = _run_godot(godot_bin, ["--test-save-read"], DEFAULT_TIMEOUT)
    except subprocess.TimeoutExpired:
        return Risultato(nome, False, "timeout")

    out = p1.stdout + p2.stdout
    ok, dettaglio = _godot_test_ok(
        subprocess.CompletedProcess(args=[], returncode=0, stdout=out, stderr=p1.stderr + p2.stderr),
        "TEST SALVATAGGIO OK",
    )
    return Risultato(nome, ok, dettaglio)


def check_godot_test(godot_bin: str, nome: str, flag: str, marker: str) -> Risultato:
    try:
        proc = _run_godot(godot_bin, [flag], DEFAULT_TIMEOUT)
    except subprocess.TimeoutExpired:
        return Risultato(nome, False, "timeout")
    ok, dettaglio = _godot_test_ok(proc, marker)
    return Risultato(nome, ok, dettaglio)


def main() -> None:
    simulate_n, godot_bin = _parse_args()

    print("=== SUITE DI REGRESSIONE — Il ladro di sabbia ===")
    print(f"(Monte Carlo con --simulate={simulate_n}; usa --simulate=N per un numero diverso)")
    print()

    checks = []
    t0 = time.time()

    checks.append(check_knapsack())
    checks.append(check_monte_carlo(godot_bin, simulate_n))
    checks.append(check_salvataggio(godot_bin))
    checks.append(check_godot_test(godot_bin, "UI (--test-ui)", "--test-ui", "TUTTI I TEST UI OK"))
    checks.append(check_godot_test(godot_bin, "Sinergie tra tracce (--test-sinergie)", "--test-sinergie", "TUTTI I TEST SINERGIE OK"))
    checks.append(check_godot_test(godot_bin, "Fase 10: le 5 risorse (--test-fase10)", "--test-fase10", "TUTTI I TEST FASE 10 OK"))
    checks.append(check_godot_test(godot_bin, "Difficoltà crescente (--test-difficolta)", "--test-difficolta", "TUTTI I TEST DIFFICOLTÀ OK"))
    checks.append(check_godot_test(godot_bin, "Seed del giorno (--test-seed-del-giorno)", "--test-seed-del-giorno", "TUTTI I TEST SEED DEL GIORNO OK"))
    checks.append(check_godot_test(godot_bin, "Bivi (--test-bivi)", "--test-bivi", "TUTTI I TEST BIVI OK"))
    checks.append(check_godot_test(godot_bin, "Rete di contatti (--test-rete-contatti)", "--test-rete-contatti", "TUTTI I TEST RETE DI CONTATTI OK"))

    durata = time.time() - t0

    for r in checks:
        stato = "PASS" if r.ok else "FAIL"
        print(f"[{stato}] {r.nome}")
        if r.numeri:
            print(f"       {r.numeri}")
        if not r.ok and r.dettaglio:
            print("       Ultime righe di output:")
            for riga in r.dettaglio.splitlines():
                print(f"         {riga}")

    passati = sum(1 for r in checks if r.ok)
    totale = len(checks)
    print()
    print(f"RISULTATO COMPLESSIVO: {passati}/{totale} PASS ({durata:.0f}s)")

    if passati < totale:
        print("Verifiche fallite:", ", ".join(r.nome for r in checks if not r.ok))
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
