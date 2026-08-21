# Il ladro di sabbia

Guida per sessioni future di sviluppo (Claude Code / vibe coding). Aggiornata
al termine di ogni fase — vedi in fondo lo stato di avanzamento.

## Premessa del gioco (poche righe)

In questo mondo il tempo si chiama "sabbia" ed è la valuta universale: si
nasce con una quantità nota (l'aspettativa di vita), e si può cederla solo
volontariamente (anche sotto minaccia). Il protagonista è un padre che ha
ceduto quasi tutta la propria sabbia per salvare la figlia neonata durante un
parto difficile in cui la moglie è morta: a lui restano 24 ore di vita
("Sabbia-Padre"), alla figlia 168 ore (una settimana, "Tempo-Figlia"). Il
padre, ex criminale, deve racimolare più sabbia possibile in una settimana
prima di una donazione finale, volontaria e irreversibile, verso la figlia.
Dettaglio narrativo ed economico completo: `Il_ladro_di_sabbia_design_doc.docx`
(sezioni 1-4 per il loop core), stato delle decisioni aperte in
`Il_ladro_di_sabbia_elementi_mancanti.docx`, numeri in
`ladro_di_sabbia_bilanciamento.xlsx`.

**Scope attuale**: solo il loop core (61/60 azioni, doppio countdown, dado
d20, donazione, punteggio). Tracce, sottotrame, Eterni, Stregatto, contenuti
narrativi: fasi successive, non ancora iniziate.

## Convenzioni di codice

- **Cartelle**: `data/` (JSON di sola-lettura), `scripts/data/` (classi dati
  + loader), `scripts/core/` (logica di gioco pura, senza dipendenze dalla
  scena), `scripts/` (entry point / orchestrazione), `scenes/` (scene minime),
  `tools/` (script Python di conversione/estrazione, non parte del gioco).
- **Naming**: file e variabili `snake_case`, classi/`class_name` in
  `PascalCase`. Nomi di dominio in italiano (coerenti col design doc:
  `tempo_figlia_ore`, `sabbia_padre_ore`, `rischio_pct`), non tradotti in
  inglese.
- **Logica core testabile senza scena**: `scripts/core/*.gd` non deve
  dipendere da nodi della scena (niente `get_node`, niente scene tree) così
  da poter essere richiamato sia dalla UI di gioco sia dallo script di
  simulazione headless con lo stesso codice — nessuna logica duplicata tra
  "gioco vero" e "simulatore di bilanciamento".
- Niente commenti superflui; solo dove il *perché* non è ovvio dal codice.

## Decisioni tecniche chiave

- **Motore**: Godot 4.7.2 stable, GDScript. Renderer `gl_compatibility`.
- **Dati azioni**: JSON caricato a runtime (`data/azioni.json`), non
  `.tres` per-azione — 60 righe cambiano più comodamente in un unico file
  generato da Excel che in 60 risorse editor separate. Rigenerabile da
  `tools/extract_azioni.py` (richiede `openpyxl`) ogni volta che l'Excel
  cambia. Caricato dall'autoload `ActionDatabase`
  (`scripts/data/action_database.gd`) in `Array[ActionData]`
  (`scripts/data/action_data.gd`).
- **⚠️ Discrepanza dati**: il design doc parla di "61 azioni core", ma il
  foglio Excel "Azioni" ne contiene realmente **60** (righe 6-65; la riga 67
  è solo una nota istruttiva per aggiungere azioni future, non un'azione).
  `tools/extract_azioni.py` segnala questo scarto automaticamente ogni volta
  che viene rilanciato. Non ho aggiunto un'azione fittizia per arrivare a 61:
  va chiarito con l'autore se manca davvero una riga nel foglio.
- **Architettura di salvataggio a due livelli** (da design doc 4.7, non
  ancora implementata nel codice — solo pianificata):
  - *Stato di Run*: effimero, solo in memoria, nessun salvataggio a metà
    run (coerente con roguelite a run brevi).
  - *Profilo Persistente*: file permanente (JSON o ConfigFile) tra le run:
    Karma, Rete di contatti sbloccati, achievement, livello di difficoltà,
    stato del "mondo senza sabbia". Fuori scope per le fasi 1-5 (nessuna di
    queste risorse esiste ancora nel loop core).
- **Formula del sistema d20** (design doc sezione 4.6, implementata in
  `scripts/core/dice_system.gd`):
  - `CD = 1 + round(Rischio% * 20)`
  - Tiro base: `1d20 (+ modificatori) >= CD` = successo.
  - Vantaggio/Svantaggio: `2d20`, tieni il migliore/peggiore — sostituisce
    il dado usato, non si somma ai modificatori fissi.
  - Bonus/Malus fissi: si sommano al valore del dado scelto DOPO aver
    applicato Vantaggio/Svantaggio.
  - Critici: naturale 20 = successo automatico (ignora CD e modificatori),
    naturale 1 = fallimento automatico (ignora CD e modificatori) — il
    controllo critico guarda il valore *naturale* del dado tenuto, mai il
    totale con modificatori.
  - Fallimento: nessun rimborso del tempo speso, nessun effetto in
    Sabbia-Padre. Fallimento critico: conseguenza aggravata.

## Comandi utili

```bash
# Rigenerare data/azioni.json dall'Excel (dopo ogni modifica al foglio "Azioni")
python3 tools/extract_azioni.py

# Prima esecuzione su una macchina nuova / dopo aggiunta di nuove classi con
# class_name: costruisce la cache delle classi globali (altrimenti gli
# script headless falliscono con "Could not find type X in the current scope")
godot --headless --editor --quit

# Lanciare il gioco in headless per testare senza aprire l'editor
godot --headless --path .

# (Fase 2+) loop testuale giocabile da terminale
godot --headless --path . -- --play

# (Fase 5+) simulazione bilanciamento, N run aggregate
godot --headless --path . -- --simulate=10000
```

## Stato di avanzamento

- **Fase 1 (dati puri)**: fatto. `data/azioni.json` generato da
  `tools/extract_azioni.py`, caricato da `ActionDatabase` in
  `Array[ActionData]`. Verificato in headless: 60 azioni, 17 categorie,
  nessun errore di parsing (corretto un bug su celle Excel vuote/null in
  `fonte_nota` che JSON.parse_string restituisce come `null` esplicito, non
  come chiave mancante — `Dictionary.get(key, default)` non copre quel caso).
- **Fase 2 (loop testuale giocabile)**: fatto. `scripts/core/game_state.gd`
  (`class_name GameState`) tiene i due countdown e applica costo/effetto
  **deterministicamente** (nessun tiro di dado ancora — rispecchia
  deliberatamente il foglio "Simulatore Run" dell'Excel, anch'esso
  deterministico; il dado arriva in Fase 3 senza toccare questo file).
  `scripts/main.gd` espone un loop testuale (`godot --headless --path . --
  --play`) che legge da stdin con `OS.read_string_from_stdin()`, stampa le
  60 azioni raggruppate per categoria e applica la scelta. Game over quando
  un countdown arriva a 0 (`GameState.EndReason`).
  **Validato**: ho rigiocato a mano la sequenza di 8 azioni del foglio
  "Simulatore Run" dell'Excel (turno di lavoro → pasto → dormire → poker →
  vendita oggetti → scippo → riattivare contatto → piani di sicurezza banca)
  e i valori intermedi di Tempo-Figlia/Sabbia-Padre coincidono esattamente
  con quelli del foglio (160/29.97, 159/29.44, ... fino al game over del
  padre all'azione 8). Verificato anche il game over per Tempo-Figlia a
  zero (21x "Riposare").
