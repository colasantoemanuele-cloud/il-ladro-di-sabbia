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

**Scope attuale**: loop core (62 azioni — 60 originali + 2 aggiunte in Fase
10, doppio countdown, dado d20, donazione, punteggio, varianza roguelite) +
le 7 tracce normali + le 10 sottotrame endgame + le sinergie tra tracce
(Blocco Fase 9, completo: 9a+9b+9c) + le 5 risorse con effetti reali
(Attenzione Polizia, Rivalità Criminale, Fama Pubblica, Karma persistente,
Fede del Culto/della Setta) + una versione meccanica minima (dialoghi
segnaposto) del Patto con lo Stregatto (Fase 10, completa). Eterni, il
personaggio scritto per esteso dello Stregatto, contenuti narrativi: fasi
successive, non ancora iniziate. Il tetto economico del sistema completo
è **definitivo e confermato**: **265,55 anni** per un solo personaggio
(azioni + tracce + sottotrame + sinergie, budget 168h) — vedi "Fase 10 —
verifica e correzione cash-in" più sotto per lo storico delle due
ambiguità che precedevano questo numero (formula del cash-in
interpretazione A/B, soglia di Fede per il Rango 2 religioso), entrambe
ora risolte e confermate dall'autore.

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
  (`scripts/data/action_data.gd`). Include il campo `unica_per_run` (colonna
  Excel "Unica per run", aggiunta dopo il playtest della Fase 5): 17 azioni
  su 60 rappresentano un bersaglio/accordo/evento singolo e non sono
  ripetibili nella stessa run — vedi `GameState.azione_disponibile()`.
- **60 azioni core, confermato** (non 61): l'etichetta "61" nei documenti
  era un refuso, corretto dall'autore in design doc ed Excel. Nessuna azione
  mancante.
- **Architettura di salvataggio a due livelli** (design doc 4.7,
  implementata dalla Fase 7):
  - *Stato di Run* (`scripts/core/game_state.gd`, `class_name GameState`):
    effimero, solo in memoria, nessun salvataggio a metà run (coerente con
    roguelite a run brevi).
  - *Profilo Persistente* (`scripts/core/player_profile.gd`,
    `class_name PlayerProfile`): file JSON in `user://profilo_persistente.json`
    (cartella dati utente del sistema operativo, FUORI dal repo). Campi:
    Karma, Rete di contatti sbloccati, achievement, livello di difficoltà,
    stato del "mondo senza sabbia" — tutti già presenti nella struttura ma
    vuoti/a zero, perché i sistemi che li popoleranno (tracce, achievement,
    difficoltà crescente, mondo senza sabbia) sono fuori scope per le fasi
    1-7. Solo `karma` ha già un collegamento reale (letto/scritto da
    `GameUI` a inizio/fine run), anche se nulla lo modifica ancora durante
    il gioco.
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
  - **Casi estremi (Rischio 0% e 100%)**: NON passano dal tiro di dado,
    regola dei critici inclusa. Rischio 0% = successo automatico sempre;
    Rischio 100% = evento automatico sempre. Eccezione esplicita nel
    design doc 4.6, aggiunta dopo il playtest della Fase 5 (senza di essa,
    la regola dei critici applicata anche a questi estremi dava un tasso
    reale di ~95%/~5% invece di 100%/0%). Per tutti i rischi intermedi
    (1%-99%) resta il sistema pieno coi critici. `DiceSystem.RollResult`
    espone `senza_tiro: bool` per questo caso.
  - Fallimento: nessun rimborso del tempo speso, nessun effetto in
    Sabbia-Padre. Fallimento critico: conseguenza aggravata.
  - **Unica per run**: 17 azioni (colonna Excel `Unica per run`) possono
    essere tentate una sola volta a run, successo o fallimento non importa
    — marcata "usata" al primo tentativo, non al successo, altrimenti un
    fallimento permetterebbe di ritentare all'infinito fino a un successo,
    vanificando il vincolo. `GameState.applica_azione_con_dado()` rifiuta
    (senza consumare turno/tempo) un tentativo su un'azione unica già
    usata; `GameState.azione_disponibile(azione)` fa il controllo.
  - **Varianza roguelite (Fase 8, design doc 12.1)**: ogni run ha un seed
    (`GameState.seed_run`, loggato/visibile in UI e loop testuale) che
    guida un `RandomNumberGenerator` seedato dedicato — stesso seed =
    stessa identica sequenza di tiri di dado E di varianza sui costi/
    guadagni (riproducibile in debug con `--seed=N`). Costo e guadagno di
    ogni azione variano moltiplicativamente ±15%/±20% (`ActionVariance`,
    stessi range già usati nella validazione Monte Carlo del foglio
    Excel — non ne ho inventati di nuovi), applicati SOLO da
    `applica_azione_con_dado()`: `applica_azione_deterministica()` (Fase
    2, validazione esatta contro l'Excel) resta invariata, senza varianza.

## Comandi utili

```bash
# COMANDO DI RIFERIMENTO per una verifica generale dello stato del
# progetto (batch tecnico post-Fase-10): lancia in sequenza TUTTE le
# verifiche esistenti (knapsack deterministico, Monte Carlo, salvataggio,
# UI, sinergie, Fase 10, difficoltà, seed del giorno, bivi, rete di
# contatti) e stampa un report aggregato PASS/FAIL con i numeri chiave
# (i quattro tetti economici, media Monte Carlo, probabilità tripletta
# storica). Usare questo comando prima di ogni commit importante o dopo
# essersi allontanati a lungo dal progetto, invece di rilanciare a mano
# le singole verifiche sparse sotto. Uscita 0 se tutto passa, 1 altrimenti
# (utile in CI/script). --simulate=N (default 500) controlla la
# dimensione del Monte Carlo; --godot=PATH se "godot" non è nel PATH.
#
# ⚠️ VALIDO SOLO IN EDITOR O SU UN EXPORT DEBUG. Questo comando (come
# ogni flag --test-*) si basa su assert() per verificare le condizioni —
# e Godot RIMUOVE assert() dalle build "--export-release". Lanciato
# contro un eseguibile di quel tipo, "TUTTI I TEST OK" comparirebbe
# SEMPRE, anche se le verifiche interne non girassero affatto: un falso
# PASS silenzioso, non un errore visibile. Su un export release
# (quello che si dà ai giocatori) l'UNICA verifica valida è uno smoke
# test comportamentale (--play o equivalente) — MAI i flag --test-*, MAI
# questo comando. Dettagli e riproduzione del problema più sotto,
# sezione "Export standalone Linux", e nel log "Task 7" più in fondo.
python3 tools/regression_suite.py
python3 tools/regression_suite.py --simulate=2000   # numero "ufficiale" da report di fase, più lento

# Controllo di coerenza tra l'Excel (fonte di verità) e i tre data/*.json:
# segnala SOLO, non corregge — se trova discrepanze, rilanciare lo script
# di estrazione pertinente sotto. Incluso anche in regression_suite.py.
python3 tools/check_data_consistency.py

# Rigenerare data/azioni.json dall'Excel (dopo ogni modifica al foglio "Azioni")
python3 tools/extract_azioni.py

# (Fase 9a) rigenerare data/tracce.json dall'Excel (dopo ogni modifica al
# foglio "Endgame", sezioni "LE 7 TRACCE NORMALI" e "LE 3 TRACCE BONUS")
python3 tools/extract_tracce.py

# (Fase 9b) rigenerare data/sottotrame.json dall'Excel (dopo ogni modifica
# al foglio "Endgame", sezione "4. LE 10 SOTTOTRAME") — il prerequisito de
# "Il tesoro del vecchio boss" è codificato a mano nello script, non
# nell'Excel: controllarlo se le sottotrame con prerequisito cambiano
python3 tools/extract_sottotrame.py

# Prima esecuzione su una macchina nuova / dopo aggiunta di nuove classi con
# class_name: costruisce la cache delle classi globali (altrimenti gli
# script headless falliscono con "Could not find type X in the current scope")
godot --headless --editor --quit

# Lanciare il gioco in headless per testare senza aprire l'editor
godot --headless --path .

# (Fase 6) giocare con la UI grafica (richiede un display, es. X11/Wayland)
godot --path .

# (Fase 6) auto-test headless della UI: simula pressioni di bottoni senza
# display reale (utile da terminale/CI dove non si può vedere la finestra)
godot --headless --path . -- --test-ui

# (Fase 9c) auto-test headless del sistema di sinergie tra tracce
godot --headless --path . -- --test-sinergie

# (Fase 2, legacy) loop testuale giocabile da terminale — tenuto per
# verifiche headless rapide, la UI (Fase 6) è ora il modo principale di giocare
godot --headless --path . -- --play

# (Fase 8) riprodurre una run specifica in debug: --seed=N funziona sia con
# --play sia con la UI (nessun argomento = UI, quindi "-- --seed=N" da solo)
godot --headless --path . -- --play --seed=12345
godot --path . -- --seed=12345

# (Fase 5) simulazione Monte Carlo di bilanciamento, N run per ciascuna
# delle 3 politiche (greedy / greedy_no_free / random)
godot --headless --path . -- --simulate=3000

# (Fase 5) tetto economico deterministico (nessun dado), knapsack sulle
# 168h disponibili, legge data/azioni.json (nessuna dipendenza extra)
python3 tools/balance_ceiling.py

# (Fase 7) test di salvataggio "chiudi e riapri": due processi Godot
# SEPARATI, il secondo deve rileggere esattamente cio' che ha scritto il primo
godot --headless --path . -- --test-save-write
godot --headless --path . -- --test-save-read

# Il Profilo Persistente vive fuori dal repo, nella cartella dati utente di
# Godot (percorso reale stampato da --test-save-write); su Linux tipicamente:
#   ~/.local/share/godot/app_userdata/Il ladro di sabbia/profilo_persistente.json

# --- Export standalone Linux (batch tecnico) --------------------------
# Richiede gli export template Godot 4.7.2.stable installati in
# ~/.local/share/godot/export_templates/4.7.2.stable/ (scaricabili da
# https://github.com/godotengine/godot/releases/tag/4.7.2-stable,
# Godot_v4.7.2-stable_export_templates.tpz, da estrarre in quella cartella).
# Preset "Linux" già configurato in export_presets.cfg (tracciato da git).
mkdir -p build/linux
godot --headless --export-release "Linux" build/linux/il_ladro_di_sabbia.x86_64

# ⚠️ REGOLA DA NON DIMENTICARE PRIMA DELLA PUBBLICAZIONE: su un
# eseguibile "--export-release" (quello che si dà ai giocatori), assert()
# è RIMOSSO dal bytecode da Godot stesso — quindi ogni flag --test-*
# (compreso l'intero tools/regression_suite.py, che li lancia tutti)
# smette silenziosamente di verificare qualunque cosa e stampa comunque
# "TUTTI I TEST OK": un falso PASS, non un errore visibile. Su un export
# release l'UNICA verifica valida è uno smoke test COMPORTAMENTALE come
# --play (sotto) — mai i flag --test-*. Per rilanciare davvero i
# --test-* fuori dall'editor (con assert() ancora attivo, es. per
# verificare l'export stesso prima di una release, come fatto qui),
# esportare con --export-debug invece di --export-release — stesso
# identico comando, preset "debug" invece di "release":
#   godot --headless --export-debug "Linux" build/linux-debug/il_ladro_di_sabbia_debug.x86_64
#   ./build/linux-debug/il_ladro_di_sabbia_debug.x86_64 --headless -- --test-ui
# Ma su una build DA PUBBLICARE, la sola verifica sensata resta questa:
./build/linux/il_ladro_di_sabbia.x86_64 --headless -- --play --seed=12345
```

## Stato di avanzamento

- **Fase 1 (dati puri)**: fatto. `data/azioni.json` generato da
  `tools/extract_azioni.py`, caricato da `ActionDatabase` in
  `Array[ActionData]`. Verificato in headless: 60 azioni (confermato,
  l'"61" nei documenti era un refuso), 17 categorie, nessun errore di
  parsing (corretto un bug su celle Excel vuote/null in `fonte_nota` che
  JSON.parse_string restituisce come `null` esplicito, non come chiave
  mancante — `Dictionary.get(key, default)` non copre quel caso).
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
- **Fase 3 (sistema d20)**: fatto. `scripts/core/dice_system.gd`
  (`class_name DiceSystem`, funzioni statiche pure) implementa CD = 1 +
  arrotonda(Rischio% × 20), tiro 1d20, Vantaggio/Svantaggio (2d20,
  migliore/peggiore), Bonus/Malus fissi sommati dopo la scelta del dado,
  critici (naturale 20/1 ignorano CD e modificatori). `GameState` guadagna
  `applica_azione_con_dado(azione, modo, modificatore)` che sostituisce
  `applica_azione_deterministica()` nel loop di gioco (quest'ultima resta
  nel codice: serve alla Fase 5 per calcolare il tetto economico
  deterministico da confrontare col foglio Excel, separatamente dalla
  simulazione Monte Carlo). Il tempo si spende sempre; l'effetto in
  Sabbia-Padre si applica solo in caso di successo.
  Vantaggio/Svantaggio/Bonus/Malus sono già parametri del metodo ma nel
  loop di gioco arrivano sempre a default: nessuna fonte (oggetti, ranghi
  di traccia) esiste ancora — fuori scope per queste fasi.
  **Deciso ma NON implementato**: la conseguenza di fallimento su azioni
  illegali (aumento di Attenzione Polizia/Rivalità Criminale, sezione 4.6)
  è solo un placeholder in `risultato.conseguenza_risorsa` — quelle due
  risorse appartengono al sistema di tracce (sezione 7.2), esplicitamente
  fuori scope per le fasi 1-5. Va deciso con l'autore se questa scelta è
  corretta o se serve un contatore minimo anche prima delle tracce.
  **Verificato statisticamente** (200k tiri per valore di rischio, script
  ad-hoc non incluso nel repo): il tasso di successo osservato coincide
  con `1 - Rischio%` per ogni CD compreso tra 2 e 20 (rischio 10%-90%),
  Vantaggio/Svantaggio si comportano nella direzione attesa.
  **Correzione post-Fase-5 (confermata dall'autore)**: alle due code
  (Rischio 0% e 100%) la regola dei critici dava un tasso reale di
  ~95%/~5% invece di 100%/0%. L'autore ha aggiornato il design doc 4.6 per
  escludere esplicitamente questi due estremi dal tiro di dado (successo/
  evento automatico, nessuna regola dei critici). Corretto in
  `DiceSystem.risolvi()`: per `rischio_pct <= 0.0` o `>= 1.0` non si tira
  alcun dado (`RollResult.senza_tiro = true`). Riverificato
  statisticamente: rischio 0% → 100.0% di successo esatto, rischio 100% →
  0.0% esatto (in precedenza ~95%/~5%).
- **Fase 4 (donazione, punteggio, vittoria)**: fatto.
  `GameState.dona(quantita_ore)` trasferisce ore da Sabbia-Padre a
  Tempo-Figlia: unica per run (`donation_made`), irreversibile, importo
  scelto dal giocatore fino al massimo disponibile (non necessariamente
  tutto). `GameState.calcola_punteggio()` restituisce anni di padre e
  figlia, il totale, e `vittoria_100_100` (entrambi >= 100 anni).
  **Decisione confermata dall'autore**: la donazione conclude immediatamente
  la run (`is_over = true`), il padre non può continuare ad agire dopo aver
  donato. Il comando `donare <ore>` è stato
  aggiunto al loop testuale (`scripts/main.gd`) accanto alla lista di
  azioni. La condizione 100+100 viene solo rilevata e segnalata a schermo
  ("TRAGUARDO RAGGIUNTO"), senza sbloccare nulla, come richiesto.
  **Verificato** con uno script di test diretto su `GameState` (bypassa il
  dado, deterministico): donazione parziale corretta, rifiuto di una
  seconda donazione, rifiuto di donare più di quanto disponibile,
  rilevamento corretto del traguardo 100+100 sopra e sotto soglia.
  Verificato anche end-to-end nel loop testuale (`donare 5` dopo
  un'azione).
- **Fase 5 (playtest e validazione bilanciamento)**: fatto in due passate.
  - `tools/balance_ceiling.py`: knapsack deterministico (nessun dado) sul
    budget di 168h, per calcolare il vero tetto economico raggiungibile con
    le sole azioni core.
  - `scripts/core/balance_simulator.gd` + `--simulate=N` in `scripts/main.gd`:
    Monte Carlo con dado vero (riusa `GameState`/`DiceSystem`/
    `ActionDatabase`, nessuna logica duplicata), tre politiche di scelta
    (`greedy`, `greedy_no_free`, `random`), report aggregato (media/mediana/
    min/max del punteggio, probabilità di soglie, probabilità vittoria
    100+100, motivi di fine run).
  - **1ª passata — TROVATO (segnalato, non corretto)**: diverse azioni ad
    altissimo rendimento pensate come eventi narrativamente rari/unici
    (lotteria jackpot, prestito su anni futuri, IL GRANDE COLPO) erano
    liberamente ripetibili nella stessa run; una di esse ("Trovi un
    portafoglio...") aveva costo Tempo-Figlia 0h, quindi ripetibile
    all'infinito. Tetto deterministico: 643 anni. Confermato col dado vero:
    politica "greedy_no_free" su 3000 run, media ~399 anni, 100% delle run
    sopra 200 anni.
  - **Correzione applicata dall'autore**: aggiunta la colonna Excel "Unica
    per run" (17 azioni marcate VERO), costo del portafoglio corretto da 0h
    a 1h. `tools/extract_azioni.py` aggiornato per leggere la colonna
    (`unica_per_run` in `ActionData`/`azioni.json`).
    `GameState.azione_disponibile(azione)` +
    `azioni_uniche_usate: Dictionary` impediscono di scegliere due volte
    un'azione unica nella stessa run — marcata "usata" al primo TENTATIVO
    (non al successo: altrimenti un fallimento permetterebbe ritentativi
    infiniti fino al successo, vanificando il vincolo). Il rifiuto non
    consuma turno né Tempo-Figlia. `scripts/main.gd` mostra `[unica]` /
    `[GIÀ USATA]` accanto alle azioni marcate nel loop testuale.
    `tools/balance_ceiling.py` riscritto con un knapsack misto: 0/1 per le
    azioni uniche, illimitato per le altre.
  - **2ª passata — risultati dopo la correzione**:
    - Tetto deterministico: **643 → 42.23 anni** (knapsack misto, 16 azioni
      uniche su 40 candidate positive).
    - Monte Carlo dado vero (N=3000, politica `greedy`): media **17.77
      anni**, mediana 13.84, **massimo osservato 42.22** — combacia quasi
      esattamente col tetto deterministico (42.23), buon segnale di
      coerenza incrociata fra i due metodi. 0% delle run supera 50 anni,
      100% termina per Tempo-Figlia esaurito (`figlia morta`) — nessuna
      run muore più per Sabbia-Padre esaurita con questa politica.
      `greedy_no_free` produce numeri praticamente identici a `greedy`
      (atteso: senza più azioni a costo 0h le due politiche coincidono).
    - Politica `random` (N=3000): media 2.83 anni, mediana 0.02, max 40.21
      (una run fortunata su 3000, plausibile), 55.7% delle run muore per
      Sabbia-Padre esaurita — invariato rispetto alla 1ª passata, coerente
      col design doc (lavoro onesto "quasi pareggia": turno da 8h, costo
      8h, effetto +5.97h).
    - **Esito**: il tetto economico del solo loop core è ora ben al di
      sotto sia dei 100 anni (soglia 100+100 dichiarata irraggiungibile con
      le sole azioni core) sia del tetto di ~207 anni del sistema completo
      con tracce+sottotrame (foglio Endgame) — ordine di grandezza
      ragionevole, nessuna ulteriore anomalia rilevata. **Nota aggiunta a
      posteriori (Fase 10)**: quel ~207 anni era il numero del foglio
      Excel di questa fase (Fase 5), da un modello semplificato precedente
      alla costruzione del vero sistema a due ranghi (dove anche il Rango
      1, non solo il Rango 2, ha un guadagno economico proprio). Il tetto
      definitivo del sistema completo, calcolato con la meccanica a due
      ranghi effettivamente implementata, è **265,55 anni** — vedi "Fase
      10 — verifica e correzione cash-in" in fondo a questo file.
  - **Nota sulla metrica vittoria_100_100 nel report Monte Carlo**: risulta
    sempre 0% perché il simulatore non effettua mai la donazione (Fase 4)
    — la Sabbia-Padre accumulata resta sul padre, la Sabbia-Figlia parte da
    168h e non cresce mai. Non è un problema di bilanciamento: è un limite
    intenzionale del simulatore, che misura "quanta sabbia si riesce a
    raccogliere in totale", non "come la si ripartisce". Il numero
    corretto da guardare per il tetto economico è `totale_anni`
    (padre+figlia), non `prob_vittoria_100_100`.
- **Fase 6 (UI minima funzionale)**: fatto. `scripts/ui/game_ui.gd`
  (`class_name GameUI`, `extends Control`) costruisce l'intera interfaccia a
  codice (nessun `.tscn` con nodi disegnati a mano — più leggibile in vibe
  coding di 60 bottoni generati dinamicamente): doppio countdown sempre
  visibile, pannello con le 5 risorse (sempre a 0, nessun sistema le
  aggiorna ancora — vedi `GameState`), barra di donazione (LineEdit +
  Button), messaggio/esito (RichTextLabel), lista azioni scorrevole
  (ScrollContainer + VBoxContainer) raggruppata per categoria con un
  Button per azione. Azioni scelte cliccando, non più digitando. Le
  azioni "Unica per run" si disabilitano e mostrano `[GIÀ USATA]` dopo il
  primo tentativo, coerente con `GameState.azione_disponibile()`. Non
  risolve l'affollamento delle 60 azioni (decisione presa: è un problema
  di arte finale, Fase 13) — la lista è semplicemente scorrevole.
  `scripts/main.gd`: `Main` ora `extends Control` (prima `Node`, serviva
  per far propagare correttamente gli anchor "riempi tutto" ai figli); di
  default (nessun argomento da riga di comando) apre la UI e NON chiama
  `get_tree().quit()` (resta interattiva). Il loop testuale della Fase 2
  resta disponibile dietro il flag esplicito `--play` (utile per verifiche
  headless rapide senza display).
  **Impostazioni progetto aggiunte** (`project.godot`, sezione
  `[display]`): `window/size/viewport_width/height=1280x800`,
  `window/stretch/mode=canvas_items` + `aspect=expand` (la UI si
  ridimensiona con la finestra), `window/dpi/allow_hidpi=false` (evita
  scaling automatico indesiderato — ragionevole anche in vista della
  pixel art futura, che non vuole essere ri-scalata dal sistema).
  **Verificato**: `godot --headless --path . -- --test-ui` (nuovo, aggiunto
  apposta) istanzia la UI reale, verifica che vengano creati 60 bottoni,
  simula la pressione di un bottone azione via `Button.pressed.emit()` e
  controlla che `GameState` si aggiorni di conseguenza, verifica che un
  bottone di un'azione unica si disabiliti dopo un tentativo, e verifica
  che la donazione via UI termini la run e disabiliti tutti i controlli —
  tutti PASS. Rilanciate anche le verifiche di regressione di `--play` e
  `--simulate=N`: nessuna rottura.
  **Verifica visiva**: ho effettivamente lanciato la UI con un display
  reale disponibile in questa sessione (`DISPLAY=:1`, X11 via XWayland) e
  catturato uno screenshot — tutti gli elementi richiesti sono presenti,
  leggibili e disposti correttamente (doppio countdown, pannello risorse,
  barra donazione, lista azioni scorrevole con separatori di categoria).
  **Limite noto della verifica, non del progetto**: nell'ambiente sandbox
  di questa sessione il compositor (Smithay/XWayland) forza la finestra
  reale a una larghezza fissa (1896px, verificato non dipendere dalla
  risoluzione richiesta) diversa da quella che Godot stesso riporta
  internamente (`DisplayServer.window_get_size()` = 1280×800, coerente col
  progetto) — la UI viene quindi visualizzata "letterboxed" (contenuto
  corretto ma non riempie tutta la finestra) SOLO in questo screenshot.
  Diagnosticato a fondo (viewport_rect, window_size, texture del
  framebuffer, prova con `--resolution` esplicita): è un mismatch
  compositor↔Godot specifico di questo ambiente virtuale, non riproducibile
  né correggibile da impostazioni di progetto. Su un desktop Linux reale
  (o in editor) questo problema non dovrebbe presentarsi, ma non ho potuto
  verificarlo direttamente in questa sessione — da tenere d'occhio la
  prima volta che l'autore apre il progetto sulla propria macchina.
- **Fase 7 (sistema di salvataggio)**: fatto. `scripts/core/player_profile.gd`
  (`class_name PlayerProfile`) implementa il Profilo Persistente (design doc
  4.7): file JSON in `user://profilo_persistente.json` (cartella dati utente
  di Godot, FUORI dal repo — path reale dipende dal sistema operativo, su
  Linux tipicamente `~/.local/share/godot/app_userdata/<nome progetto>/`).
  Campi già presenti ma vuoti/a zero, nessun sistema li popola ancora:
  `karma` (float), `rete_contatti_sbloccati` (Array), `achievement` (Array),
  `livello_difficolta` (int), `stato_mondo_senza_sabbia` (String, default
  `"normale"`). `to_dict()`/`from_dict()`/`save()`/`load()` — `load()`
  restituisce un profilo nuovo di default se il file non esiste ancora
  (prima run in assoluto, non è un errore).
  **Collegamento reale (unico già attivo)**: `GameUI.avvia(stato, profilo)`
  inizializza `GameState.karma` dal profilo caricato all'avvio della run, e
  lo riscrive su disco a fine run (`_fine_partita()`); `main.gd._run_ui()`
  carica il profilo con `PlayerProfile.load()` prima di aprire la UI. Nulla
  modifica ancora karma durante il gioco (nessun sistema di moralità/tracce
  esiste), quindi in pratica il valore resta 0.0 finché quei sistemi non
  verranno costruiti — ma l'intera tubatura di lettura/scrittura è reale e
  verificata, non un placeholder. Il loop testuale legacy (`--play`) e il
  simulatore di bilanciamento (`--simulate=N`) NON usano il profilo
  (scelta di scope: sono modalità di test/debug, non "il gioco vero").
  **Verificato in due modi**:
  1. Round-trip vero tra processi: `--test-save-write` scrive un profilo di
     prova (karma, rete contatti, achievement, difficoltà, stato mondo) e
     termina; `--test-save-read`, lanciato come invocazione SEPARATA di
     Godot (processo nuovo, nessuno stato condiviso in memoria — la vera
     simulazione di "chiudi il gioco e riaprilo"), ricarica il file e
     verifica che ogni campo coincida. PASS.
  2. Wiring end-to-end nella UI reale (esteso `--test-ui`): scrive un
     profilo con karma=42 su disco, lo ricarica, apre una GameUI con quel
     profilo e verifica che `GameState.karma` parta da 42 (non da 0),
     conclude la run con una donazione, poi ricarica il profilo da disco
     una terza volta e verifica che il karma sia stato correttamente
     riscritto. PASS.
  Rilanciate anche le verifiche di regressione di `--play`, `--simulate=N`
  e `--test-ui` (parte UI): nessuna rottura.
- **Fase 8 (varianza roguelite, core)**: fatto. Design doc 12.1.
  - `GameState.seed_run` + `_rng` (`RandomNumberGenerator` seedato,
    `GameState.new(seed_iniziale := -1)`): ogni run ha un seed proprio
    (casuale se non specificato), loggato/visibile ("Seed: N" in UI, riga
    dedicata in `--play`). `main.gd` accetta `--seed=N` (con `--play` o in
    UI) per forzare un seed specifico e riprodurre una run in debug.
  - `scripts/core/action_variance.gd` (`ActionVariance`): varianza
    moltiplicativa uniforme ±15% sul costo, ±20% sul guadagno di ogni
    azione (stessi range della validazione Monte Carlo del foglio Excel,
    design doc 12.7 — non inventati). Applicata in
    `GameState.applica_azione_con_dado()` prima di sottrarre/sommare a
    Tempo-Figlia/Sabbia-Padre; `DiceSystem.risolvi()` e
    `ActionVariance.*` pescano dallo stesso `_rng` seedato, quindi stesso
    seed → stessa sequenza esatta di tiri E di varianza.
    `applica_azione_deterministica()` (Fase 2, validazione esatta contro
    l'Excel) NON è stata toccata: resta senza varianza.
  - `scripts/core/spostamento.gd` (`Spostamento`): l'evento con esito
    incerto aggiuntivo richiesto dalla Fase 8 (design doc 12.1, esempio
    esplicito "uno spostamento... durata variabile... probabilità
    indipendente di incidente"). Durata base 1-4h, 10% di probabilità di
    incidente indipendente (non legata a Rischio%/d20 né a
    ActionVariance), che aggiunge 2-8h di ritardo extra. **Numeri
    placeholder miei**, non presenti nel foglio Excel (nessuna delle 60
    azioni core è uno "spostamento") — da tarare con l'autore quando si
    deciderà come integrare eventi di questo tipo nel loop principale.
    Esposto come `GameState.applica_spostamento()`, comando `spostati` nel
    loop testuale, bottone dedicato nella UI.
  - **Verificato**: riproducibilità esatta a parità di seed (stessa
    sequenza di costo/effetto/tiro su 10 azioni, due `GameState` con lo
    stesso seed), seed diverso → valori diversi; varianza entro i range
    dichiarati (±15%/±20%) su 5000 campioni, media non spostata
    sistematicamente (scarto <2% dal valore nominale); tasso di incidente
    di `Spostamento` osservato su 20000 campioni coerente con il 10%
    dichiarato; riproducibilità end-to-end via CLI (`--play --seed=777`
    due volte, stesso identico output). Rilanciate `--test-ui`,
    `--test-save-write/read`: nessuna rottura (un'asserzione in
    `--test-ui` aggiornata per accettare il range di varianza invece di
    un costo fisso, atteso — non è una regressione).
  - **Richiesta esplicita dell'autore verificata**: `tools/balance_ceiling.py`
    (non tocca la varianza in-game, opera solo sui dati statici) resta
    invariato a **42.23 anni**. `--simulate=3000` con la varianza attiva:
    politica `greedy` media **17.76 anni** (era 17.77 prima della Fase 8,
    sostanzialmente identica), mediana 13.80, massimo osservato 46.64
    (contro 42.22 prima — leggermente più alto per via della varianza
    positiva su una run fortunata, non anomalo). Nessuno spostamento
    sistematico del valore atteso: la varianza rende diversa ogni run,
    non cambia il tetto economico.
  - **Effetto collaterale minore osservato, non un problema di
    bilanciamento**: con la varianza attiva, la politica `random` (mai
    pensata per rappresentare un giocatore reale) ora raggiunge il tetto
    di sicurezza di 1000 turni nel 23,9% delle run (prima 0%), perché
    occasionalmente sceglie ripetutamente le poche azioni a costo
    nominale 0h (rimaste 6, tutte a effetto negativo/neutro dopo la
    correzione della Fase 5) senza mai esaurire naturalmente Tempo-Figlia
    o Sabbia-Padre. Non inflaziona il punteggio (media 2.17 anni, in linea
    con il ~2.83 di prima): è solo una politica di test che "gira a
    vuoto" più a lungo, non un nuovo modo di accumulare sabbia.
- **Fase 9a (le 10 tracce: 7 normali + 3 bonus)**: fatto. Solo tracce —
  nessuna sottotrama (Fase 9b) né sinergia (Fase 9c) ancora.
  - `tools/extract_tracce.py`: estrae il foglio Endgame (sezioni "LE 7
    TRACCE NORMALI" e "LE 3 TRACCE BONUS") in `data/tracce.json`, stesso
    pattern di `extract_azioni.py`. `scripts/data/track_data.gd`
    (`TrackData`, una riga di rango) e `track_bonus_data.gd`
    (`TrackBonusData`, solo nome+descrizione) caricati dall'autoload
    `TrackDatabase` (`scripts/data/track_database.gd`).
  - **Decisione confermata dall'autore**: le 7 tracce normali sono
    completamente indipendenti l'una dall'altra — nessun aggancio
    malavita/rete comune (il testo del foglio Excel "sblocco sempre via
    malavita/rete di contatti" resta com'era nell'header della sezione,
    ma NON è stato implementato come vincolo: l'unico prerequisito è
    interno a ciascuna traccia). `GameState.tracce_raggiunte` (nome
    traccia -> rango massimo raggiunto, mai decrementato) +
    `GameState.traccia_disponibile(riga)`: il Rango 2 di una traccia
    richiede solo il Rango 1 della STESSA traccia già raggiunto in questa
    run, nessuna dipendenza incrociata tra tracce diverse.
  - `GameState.applica_traccia(riga)`: stesso motore di risoluzione delle
    60 azioni core (dado d20 Fase 3 + varianza ±15%/±20% Fase 8, stesso
    `_rng` seedato della run). `ActionVariance` è stata rifattorizzata per
    prendere valori grezzi (costo/effetto) invece di un'`ActionData`
    intera, cosi da essere condivisa tra azioni e tracce senza duplicare
    la logica di varianza.
  - **Regola confermata dall'autore dopo la Fase 9a**: un TENTATIVO
    (riuscito o fallito) esaurisce quella riga di rango per il resto della
    run — riusa esattamente lo stesso meccanismo delle azioni "Unica per
    run" (`azioni_uniche_usate`, chiave `"<traccia>|<rango>"` invece del
    nome azione), non logica nuova. Un fallimento sul Rango 1 rende
    l'intera traccia inaccessibile per il resto della run (il Rango 2 non
    potrà mai sbloccarsi, dato che richiede il Rango 1 completato con
    successo — e il Rango 1 non è più ritentabile). Un fallimento sul
    Rango 2 lascia valido il Rango 1 già raggiunto ma preclude il Rango 2.
    `GameState.traccia_disponibile(riga)` controlla sia il prerequisito di
    rango sia questo flag "già tentata"; UI e loop testuale mostrano
    "[FALLITA — non più tentabile]" per distinguerlo da "[RAGGIUNTO]".
  - Le 3 tracce bonus (Eterni, Rete di scienziati criminali, Magica):
    solo caricate come dati, esposte in UI come bottoni disabilitati con
    testo "— contenuto narrativo non ancora scritto" (tooltip con la
    descrizione dal foglio Excel), nessuna logica — come richiesto.
  - UI (`scripts/ui/game_ui.gd`): nuova sezione "TRACCE" in fondo alla
    lista scorrevole, un bottone per riga di rango (Rango 2 disabilitato
    finché non si raggiunge il Rango 1 della stessa traccia; una volta
    raggiunto un rango il suo bottone si disabilita e mostra
    "[RAGGIUNTO]"). Loop testuale (`--play`): le 14 righe di traccia
    continuano la numerazione delle 60 azioni (indici 61-74).
  - **Verificato**: 14 righe/7 tracce caricate correttamente; Rango 2
    rifiutato senza il Rango 1 della stessa traccia; tracce diverse
    restano disponibili senza alcun prerequisito incrociato; successo al
    Rango 1 sblocca il Rango 2 e blocca il Rango 1 stesso; un fallimento
    al Rango 1 non blocca il tentativo successivo; costo/effetto delle
    tracce rispettano il range di varianza ±15%/±20%. Verificato anche
    end-to-end nella UI reale (`--test-ui` esteso: 14 bottoni traccia,
    Rango 2 si sblocca dopo un successo al Rango 1) e nel loop testuale.
    Nessuna regressione su `--test-ui` (resto), `--play`,
    `--test-save-write/read`.
  - **Richiesta esplicita dell'autore verificata — nuovo tetto
    economico**: `tools/balance_ceiling.py` esteso con le 14 righe di
    traccia trattate come 7 gruppi a scelta multipla (0, "solo Rango 1",
    o "Rango 1+2" — mai il Rango 2 da solo) sullo stesso budget condiviso
    di 168h. Tetto deterministico: **42.23 → 67.58 anni (+60,0%)**.
    Confermato col dado vero: `--simulate=1000`, politica `greedy`, media
    **32.70 anni** (era 17.76 senza tracce), massimo osservato 65.90-71.07
    — vicino al tetto deterministico di 67.58, buon segnale di coerenza
    incrociata. **Aumento coerente con l'attesa dell'autore** ("dovrebbe
    salire ma senza sinergie il salto non dovrebbe essere enorme"): +60%
    è un incremento sostanziale ma non sproporzionato, nessuna anomalia
    da segnalare. Il tetto resta ben sotto sia i 100 anni (soglia
    100+100) sia il tetto ~207 anni del sistema completo con sinergie
    (foglio Endgame) — margine coerente col fatto che sinergie (Fase 9c)
    e sottotrame (Fase 9b) non sono ancora incluse. **Nota aggiunta a
    posteriori (Fase 10)**: quel ~207 anni era il numero del foglio
    Excel di questa fase (Fase 9a), da un modello semplificato precedente
    alla costruzione del vero sistema a due ranghi (dove anche il Rango 1
    ha un guadagno economico proprio, non solo il Rango 2). Il tetto
    definitivo, con la meccanica a due ranghi effettivamente implementata,
    è **265,55 anni** — vedi "Fase 10 — verifica e correzione cash-in" in
    fondo a questo file.
- **Correzione post-9a (confermata dall'autore) — un fallimento blocca la
  traccia**: implementata riusando `azioni_uniche_usate` (nessuna logica
  nuova, come richiesto): `GameState._chiave_traccia(riga)` genera la
  chiave `"<traccia>|<rango>"`, marcata in `azioni_uniche_usate` ad ogni
  TENTATIVO (non solo al successo) esattamente come già avveniva per le
  azioni "Unica per run". `traccia_disponibile(riga)` ora controlla sia
  questa chiave sia il prerequisito di rango. Effetto: un fallimento sul
  Rango 1 rende l'intera traccia inaccessibile per il resto della run (il
  Rango 2 non potrà mai sbloccarsi); un fallimento sul Rango 2 lascia
  valido il Rango 1 già raggiunto ma preclude il Rango 2. UI e loop
  testuale mostrano `[FALLITA — non più tentabile]` per distinguerlo da
  `[RAGGIUNTO]`. Aggiornato anche il design doc (sezione 7.1, nuovo
  paragrafo inserito con python-docx) per documentare questa regola.
  Verificato: fallimento su Rango 1 blocca anche il Rango 2; fallimento
  su Rango 2 lascia il Rango 1 valido; nessuna regressione su `--test-ui`
  (corretta un'asserzione che assumeva erroneamente la ritentabilità).
- **Fase 9b (le 10 sottotrame endgame)**: fatto.
  - `tools/extract_sottotrame.py`: estrae il foglio Endgame (sezione "4.
    LE 10 SOTTOTRAME") in `data/sottotrame.json`, stesso pattern di
    `extract_azioni.py`/`extract_tracce.py`. Il prerequisito de "Il
    tesoro del vecchio boss" (richiede "Riattivare un vecchio contatto
    della rete criminale" completata con successo — design doc 6.1) NON
    è una colonna Excel: è codificato a mano nello script
    (`PREREQUISITI` dict), unico caso tra le 10 sottotrame.
    `scripts/data/subplot_data.gd` (`SubplotData`) caricato dall'autoload
    `SubplotDatabase`.
  - `GameState.applica_sottotrama(sub)`: ogni sottotrama è un'azione una
    tantum — stesso meccanismo di `azioni_uniche_usate` (chiave
    `"sottotrama:<nome>"`) e stesso motore dado+varianza delle azioni e
    tracce. `GameState.sottotrama_disponibile(sub)` controlla sia il
    flag "già tentata" sia, per "Il tesoro del vecchio boss", il
    prerequisito tramite il nuovo metodo pubblico
    `GameState.azione_completata_con_successo(nome_azione)` (rinominato
    da privato a pubblico: serve anche a UI/loop testuale per mostrare lo
    stato del prerequisito, non solo internamente).
  - UI (`scripts/ui/game_ui.gd`): nuova sezione "SOTTOTRAME" con un
    bottone per sottotrama (tooltip con la nota Excel), disabilitato se
    il prerequisito non è soddisfatto; si rivaluta dopo ogni azione core
    completata (`_aggiorna_bottoni_sottotrama()` richiamato da
    `_on_azione_pressed`, perché il prerequisito è un'ActionData, non una
    traccia). Loop testuale (`--play`): le 10 sottotrame continuano la
    numerazione (indici 75-84, dopo le 60 azioni + 14 righe di traccia).
  - **Verificato**: 10 sottotrame caricate, 1 sola con prerequisito;
    sottotrama con prerequisito rifiutata/sbloccata correttamente in
    base al successo/fallimento del prerequisito; una tantum vera (sia
    successo che fallimento bruciano il tentativo); varianza nel range
    atteso. Verificato end-to-end in UI (`--test-ui` esteso, entrambi i
    rami successo/fallimento del prerequisito) e nel loop testuale.
    Nessuna regressione.
  - **Richiesta esplicita dell'autore verificata — nuovo tetto
    economico**: `tools/balance_ceiling.py` esteso con le 10 sottotrame
    come item 0/1 indipendenti (una tantum); "Il tesoro del vecchio
    boss" include nel proprio costo anche quello del prerequisito, per
    non "regalargliela" nel calcolo. Tetto deterministico: **67.58 →
    109.26 anni** (+41.68 anni, +61,7% sopra il tetto con le sole
    tracce; +158,7% sopra le sole azioni core). Confermato col dado
    vero: `--simulate=3000`, politica `greedy`, media **58.25 anni**
    (era 32.70 senza sottotrame), massimo osservato **112.25** — di
    nuovo molto vicino al tetto deterministico (109.26), buon segnale
    di coerenza incrociata. 2,4% delle run supera i 100 anni (per il
    solo padre, dato che il simulatore non dona mai — vedi nota
    precedente su `prob_vittoria_100_100`).
  - **Importante — questo NON è un'anomalia benché superi i 100 anni**:
    il design doc (sezione 7.4) dichiara esplicitamente che "le sole
    sottotrame, senza nessuna traccia, arrivano al massimo a 100 anni
    entro 168 ore — già un traguardo raro di per sé". Ho verificato
    indipendentemente questo claim isolando le sole sottotrame nel
    knapsack (senza azioni né tracce): **100.36 anni**, praticamente
    identico al numero dichiarato dal design doc — ottima conferma
    incrociata che l'estrazione dati e la gestione del prerequisito
    sono corrette. Il claim "impossibile arrivare a 100 anni" del
    design doc (4.4/6) si applica SOLO alle 60 azioni core da sole
    (verificato: 42.23 anni, ben sotto soglia), non al sistema
    combinato con tracce e sottotrame — lì i 100 anni per un personaggio
    sono un traguardo raro ma esplicitamente voluto. La vittoria
    100+100 richiede comunque ENTRAMBI i personaggi a 100 anni tramite
    la donazione (non ancora testata dal simulatore automatico), e il
    tetto combinato di riferimento del foglio Excel con tracce E
    sinergie è ~207-208 anni — le sinergie (Fase 9c) restano il pezzo
    mancante per avvicinarsi a quel numero. **Nota aggiunta a posteriori
    (Fase 10)**: quel ~207-208 anni era il numero del foglio Excel di
    questa fase (Fase 9b), da un modello semplificato precedente alla
    costruzione del vero sistema a due ranghi (dove anche il Rango 1 ha
    un guadagno economico proprio, non solo il Rango 2) — due modelli
    diversi che non devono più coincidere. Il tetto definitivo, con la
    meccanica a due ranghi effettivamente implementata, è **265,55
    anni** — vedi "Fase 10 — verifica e correzione cash-in" in fondo a
    questo file.
- **Fase 9c (sinergie tra tracce)**: fatto. Chiude il Blocco Fase 9
  (tracce + sottotrame + sinergie).
  - `GameState`: `tracce_a_rango_2()`, `combo_tracce()` (limitata alle 4
    di maggior valore se >4 tracce qualificano — guardia difensiva, il
    design doc 7.4 nota che 5+ è comunque irraggiungibile entro 168h),
    `cash_in_disponibile()`, `applica_cash_in()`. **Solo le 7 tracce
    normali contano per il conteggio N** — le sottotrame (Fase 9b) sono
    escluse esplicitamente (verificato con un test dedicato), come
    richiesto.
  - **Il cash-in riusa `azioni_uniche_usate`** (chiave fissa `"cashin"`):
    una tantum per l'intera run, non per combo — nessuna logica nuova.
  - **Fallimento del cash-in**: fa perdere TUTTI i ranghi della combo,
    riusando esattamente lo stesso meccanismo del fallimento di rango
    (Fase 9a/9b): ogni riga (Rango 1 e Rango 2) delle tracce coinvolte
    viene marcata "usata" in `azioni_uniche_usate` E `tracce_raggiunte`
    viene azzerato per quelle tracce — come richiesto, nessuna logica
    nuova.
  - **Rischio del cash-in — mio placeholder, non specificato dal design
    doc**: 15%, back-calcolato dal 16,8% di probabilità sull'intera
    catena che il design doc 7.4 riporta per la tripletta storica
    (prodotto delle probabilità dei 6 climb ≈19,3%, 16,8%/19,3%≈87% di
    successo per il cash-in da solo ⇒ rischio ≈13%, arrotondato a 15%).
    Da confermare con l'autore.
  - **Malus** (`MALUS_COMBINAZIONI`, `malus_attivi()`): rileva le 3
    combinazioni del design doc 7.3 (Religiosa+Occulto,
    Bancaria+Criminale, Politica+Occulto — nomi di traccia dedotti dal
    testo narrativo informale del design doc, non colonne Excel, da
    confermare). **Come richiesto**, solo la CONDIZIONE è rilevata e
    segnalata (UI/loop testuale mostrano "Tensione tematica attiva");
    l'aggancio reale alle risorse (che si sommerebbero invece di restare
    separate) è marcato con un commento esplicito in `malus_attivi()` —
    resta un placeholder per la Fase 10, quando Karma/Attenzione
    Polizia/Rivalità Criminale avranno effetti reali.
  - UI: nuova barra "Sinergie" (stato combo + bottone cash-in) tra
    Spostamento e Donazione; notifica di tensione tematica nel messaggio
    dopo un successo di traccia. Loop testuale: sezione `[SINERGIA]` +
    comando `cashin`. `BalanceSimulator`: `SynergyCandidate` (classe
    interna, costruita al volo ad ogni turno solo quando disponibile,
    dato che costo/effetto dipendono dallo stato corrente — non è dato
    statico come Action/Track/SubplotData).
  - **Trovato durante la Fase 9c**: nessuna delle politiche euristiche
    (`greedy`/`greedy_no_free`/`random`) tenta MAI il cash-in
    spontaneamente (0,00% su 3000 run ciascuna). Non è un bug: `greedy`
    massimizza il valore atteso per ora spesa AD OGNI SINGOLO TURNO, e
    investire in un Rango 1 di traccia (bassa efficienza isolata, serve
    solo da gradino) perde sempre contro le tante azioni/sottotrame a
    maggior resa immediata — esattamente la dinamica "biglietto della
    lotteria" che il design doc 7.4 già descriveva (valore atteso della
    tripletta più basso della strategia prudente). Per misurare la
    probabilità reale della sinergia ho aggiunto
    `BalanceSimulator.simula_tripletta_storica()`, una sequenza
    SCRIPTATA (non euristica) che riproduce esattamente la tripletta
    storica Azzardo+Bancaria+Religiosa, stampata come sezione separata
    da `--simulate=N`.
  - **Verificato**: 8 casi in `--test-sinergie` (nessuna combo con <2
    tracce, combo rilevata a 2 tracce, cash-in riuscito applica
    base×moltiplicatore, cash-in fallito azzera TUTTI i ranghi della
    combo e blocca le righe, cash-in una tantum, sottotrame escluse dal
    conteggio, malus rilevato, combo limitata a 4 con 5+ tracce
    qualificate) + verifica end-to-end in UI (`--test-ui` esteso).
    Nessuna regressione.
  - **Richiesta esplicita dell'autore verificata — tetto finale del
    sistema completo e probabilità reale della sinergia**:
    `tools/balance_ceiling.py` esteso con enumerazione ESAUSTIVA delle
    91 combinazioni possibili di 2/3/4 tracce su 7 (knapsack: budget
    riservato alla combo + cash-in, ottimizzazione del budget residuo su
    azioni/tracce-non-coinvolte/sottotrame). Combo ottima trovata: la
    STESSA tripletta storica (Azzardo+Bancaria+Religiosa), che usa da
    sola il 100% delle 168h — conferma indipendente che il foglio Excel
    aveva già trovato l'ottimo globale. Monte Carlo (sequenza scriptata,
    N=3000): probabilità di successo dell'INTERA catena (6 climb +
    cash-in) = **15,37%** — sorprendentemente vicina al 16,8%
    deterministico storico (non all'8,4% Monte Carlo storico: la
    varianza sui costi ±15% sembra avere un impatto minore
    sull'overshoot del budget in questa implementazione rispetto alla
    validazione originale — non ho investigato ulteriormente il perché
    esatto, riportato così com'è per istruzione esplicita di non forzare
    la coincidenza).
  - **Ambiguità cash-in A/B — segnalata qui a fine Fase 9c, rimasta
    APERTA (non applicata nel codice) per tutta la Fase 10**
    (interpretazione A: Rango1+Rango2 sommati come base del
    moltiplicatore; interpretazione B: solo il Rango2). Il resoconto di
    fine Fase 10 riportava ancora 293,43 anni/interpretazione A perché
    la Fase 10 non conteneva un'istruzione a cambiarla — restava solo
    segnalata come ambiguità da confermare, correttamente non toccata
    unilateralmente. **L'autore ha poi confermato esplicitamente
    l'interpretazione B in una richiesta di verifica dedicata,
    successiva al resoconto di fine Fase 10** — vedi la voce "Fase 10 —
    verifica e correzione cash-in" più sotto per i dettagli e i numeri
    aggiornati.
- **Fase 10 (le 5 risorse + Patto con lo Stregatto minimo)**: fatto.
  Attenzione Polizia / Rivalità Criminale / Fama Pubblica (0-100, per run,
  azzerate a inizio run, salgono/scendono SOLO tramite azioni dedicate —
  mai passivamente) e Karma (-100/+100, **persistente** nel Profilo
  Persistente, Fase 7) implementati in `scripts/core/game_state.gd`.
  - **Formula comune malus/Svantaggio** (`_malus_risorsa`,
    `_svantaggio_da_risorsa`): malus al tiro = `-floor(valore/20)` (0 a
    -5); Svantaggio (non cumulativo tra le tre risorse: conta come un
    solo Svantaggio) quando il valore **supera** 50 (soglia esclusiva:
    50 esatto non dà ancora Svantaggio). La soglia 75 resta un
    placeholder per la gravità degli eventi futuri, nessun secondo malus
    implementato.
  - **Ambito Attenzione Polizia/Fama Pubblica**
    (`_modificatore_polizia_fama`): le 7 categorie
    `CATEGORIE_POLIZIA_FAMA` (Furto, Crimine, Crimine organizzato,
    Minaccia 1 a 1, Tradimento, Corruzione, Azzardo). Fama Pubblica si
    somma SOLO se il giocatore ha già raggiunto almeno un Rango 2 in una
    traccia `TRACCE_LEGITTIME` (Lavoro/Politica/Bancaria/Religiosa) in
    questa run — altrimenti pesa 0, verificato esplicitamente in
    `--test-fase10`.
  - **Rivalità Criminale**: non è basata su categoria (decisione
    delegata dall'autore, "usa il buon senso, documenta"). Sale con
    successi sulla traccia Criminale (Rango 1: +15, Rango 2: +25), con
    le 2 sottotrame giudicate "legate all'organizzazione"
    (`SOTTOTRAME_ORGANIZZAZIONE`: "Il tesoro del vecchio boss" e "La
    cassa di guerra della vecchia organizzazione", scelte perché
    entrambe coinvolgono esplicitamente il boss/l'organizzazione nel
    testo — non colonne Excel, da confermare) con +15, e con un cash-in
    di sinergia che include la traccia Criminale nella combo con +20.
  - **Karma**: peso per azione dalla colonna Moralità (Estrema -5, Molto
    sporca -3, Sporca -2, Ambigua -1, Pulita +1, Pulita/altruista +2,
    tutte le altre 0 — incluse le etichette ibride come
    "Pulita/ambigua"), applicato SEMPRE (successo o fallimento: il peso
    riflette la scelta, non l'esito), MAI sulle azioni "una tantum" già
    esaurite ovviamente (l'azione va comunque rifiutata prima). Le
    etichette con un suffisso tra parentesi (es. "Ambigua (costo
    emotivo)") contano come la loro base (`_peso_karma`, taglia al primo
    " ("). Persiste tra le run tramite il Profilo Persistente, nessuna
    correzione artificiale (decisione confermata dall'autore).
  - **Nuove azioni per colmare il vuoto di riduzione** (istruzione
    esplicita: "decidi tu... purché ogni risorsa abbia almeno un modo
    concreto di scendere"), aggiunte SIA all'Excel (foglio Azioni, righe
    68-69) SIA rigenerate in `data/azioni.json` via
    `tools/extract_azioni.py` (ora 62 azioni, non più 60 — contatore di
    sanità aggiornato nello script):
    - **"Pagare un tributo ai rivali"** (Relazioni, costo 4h, -10.000€,
      rischio 15%, moralità Ambigua): riduce Rivalità Criminale di 20 al
      successo (`RIVALITA_CRIMINALE_DECREMENTO_TRIBUTO`).
    - **"Mantenere un basso profilo pubblico"** (Relazioni, costo 6h,
      -1.000€, rischio 5%, moralità Neutra): riduce Fama Pubblica di 20
      al successo (`FAMA_PUBBLICA_DECREMENTO_BASSO_PROFILO`).
    - Attenzione Polizia riusa l'azione già esistente "Corrompere un
      poliziotto" (-25 al successo,
      `ATTENZIONE_POLIZIA_DECREMENTO_CORRUZIONE`), come richiesto
      esplicitamente dall'autore.
    - **Incrementi/decrementi numerici**: NON specificati dall'autore
      (solo "piccolo aumento" per Attenzione Polizia) — tutti valori
      placeholder miei (10 su fallimento semplice, 20 su fallimento
      critico per Attenzione Polizia; 15/25 per Rango 1/2 Criminale; 15
      per le sottotrame; 20 per il cash-in; 20/25/20 per i tre
      decrementi), documentati come costanti nominate in `game_state.gd`
      e qui, da confermare con l'autore.
  - **Sistema minimo di eventi casuali** (design doc: "ogni 5-8 azioni
    compiute", scelta esatta delegata a me): fissato **6** (valore
    singolo al centro del range, non re-randomizzato ogni volta —
    `SOGLIA_EVENTO_TURNI`). Conta OGNI turno che consuma tempo (azione,
    traccia, sottotrama, cash-in, spostamento — tutti ora passano da
    `_avanza_turno()` invece di un `turno += 1` diretto), non solo le 62
    azioni core, altrimenti una run "solo tracce/sottotrame" non
    vedrebbe mai un evento. Pesca dalla categoria "Evento" del foglio
    Azioni (9 righe): con Karma corrente >= 50 pesa 3x le voci
    "Pulita"; con Karma <= -50 pesa 3x "Negativo"/"Sporca"; altrimenti
    uniforme (`_pesca_pesata`). L'evento pescato si risolve subito con
    un dado modificato dal Karma corrente (bipolare: malus/bonus
    `floor(|karma|/20)` col segno di karma, Vantaggio se karma >= 50,
    Svantaggio se karma <= -50 — `_modificatore_karma_eventi`), MAI
    applicato alle azioni scelte attivamente, solo agli eventi.
  - **Patto con lo Stregatto — versione meccanica minima** (design doc
    sezione 9; il personaggio scritto per esteso resta per la Fase 11,
    qui SOLO dialoghi segnaposto marcati `[PLACEHOLDER STREGATTO]`).
    Innestato nello stesso selettore di eventi
    (`_pesca_evento_casuale`): se il **Karma a inizio run** (NON quello
    corrente, che può muoversi durante la run — congelato al primo
    turno risolto in `karma_inizio_run`, dato che `karma` viene
    assegnato dal chiamante dal Profilo Persistente DOPO il costruttore
    di `GameState`) è <= -50, un tiro al 15% (`STREGATTO_PROBABILITA`)
    decide se l'evento pescato è il patto invece di un evento normale.
    Prezzo: 50% della Sabbia-Padre posseduta al momento, arrotondata
    (`STREGATTO_PREZZO_FRAZIONE`); effetto se accettato: Karma +30
    (`STREGATTO_KARMA_EFFETTO`) SENZA clamp a zero (può portare il
    Karma sopra zero anche partendo da molto negativo — clampato solo
    al range generale ±100). Il giocatore può rifiutare
    (`GameState.risolvi_patto_stregatto(accetta)`). **Finché il patto è
    in sospeso, GameState rifiuta ogni altro tentativo di
    azione/traccia/sottotrama/cash-in/spostamento**
    (`_patto_in_sospeso_blocca`, applicato a livello di logica di
    gioco, non solo UI) — il giocatore deve rispondere prima di
    continuare. UI (`scripts/ui/game_ui.gd`): barra dedicata con
    messaggio e due bottoni Accetta/Rifiuta, che appare quando
    `stato.patto_in_sospeso` non è vuoto e disabilita tutti gli altri
    controlli nel frattempo (`_blocca_controlli_per_patto`). Loop
    testuale (`scripts/main.gd`): prompt bloccante `si/no` via stdin
    (`_gestisci_evento_casuale`).
  - **Fede del Culto / Fede della Setta** (0-100, per run, NON
    coincidono col Rango della traccia): completare il Rango 1 di
    Religiosa (indulgenze) o di Occulto (setta satanica) alza la Fede
    corrispondente di 40 e abbassa l'ALTRA di 10
    (`_aggiorna_fede_dopo_traccia`); completare il Rango 2 alza la Fede
    corrispondente di altri 40. Il Rango 2 di queste due tracce richiede
    ORA due condizioni: il consueto prerequisito di Rango 1 raggiunto E
    Fede corrispondente >= 40 (`FEDE_SOGLIA_RANGO2`) — se manca solo la
    seconda, `traccia_disponibile()` resta false ma
    `traccia_bloccata_da_fede()` la distingue esplicitamente dal caso
    "manca ancora il Rango 1", con un messaggio dedicato sia in UI sia
    nel loop testuale ("richiede Fede X >= 40, attuale Y").
  - **Correzione post-Fase-10 (confermata dall'autore) — soglia di Fede
    50 → 40**: la prima verifica aveva trovato il Rango 2 di
    Religiosa/Occulto **irraggiungibile nella pratica** con soglia 50 (un
    singolo successo al Rango 1 porta la Fede a 40, e nessun'altra azione
    la alza ulteriormente — il Rango 1 è "Unica per run", non
    ritentabile). L'autore ha confermato la causa e corretto la soglia a
    40 (`FEDE_SOGLIA_RANGO2`), lasciando invariati il guadagno di +40 per
    Rango 1 riuscito e il malus di -10 sulla Fede rivale: un singolo
    Rango 1 pulito su una sola traccia religiosa sblocca ora direttamente
    il Rango 2 di quella traccia, mantenendo l'attrito tra le due Fedi
    per chi tenta entrambe nella stessa run (tentare l'altra traccia fa
    scendere la propria Fede sotto soglia). Verificato: la sequenza
    scriptata `BalanceSimulator.simula_tripletta_storica()`
    (Azzardo+Bancaria+Religiosa, Fase 9c) è tornata dallo 0,00% (bug) al
    **15,00%** su 2000 run (riferimento storico Fase 9c: 15,37% — stessa
    fascia).
  - `tools/balance_ceiling.py` esteso con `apply_tracce_religiose()`: una
    versione SEMPLIFICATA del vincolo di Fede (il vincolo reale è
    sequenziale/stateful — dipende dall'ordine in cui si tentano le due
    tracce religiose — non riducibile esattamente a un knapsack, che non
    ha nozione di ordine). Regola usata: il Rango 2 di una traccia
    religiosa è raggiungibile SOLO se quella traccia ha completato il
    proprio Rango 1 E l'altra traccia religiosa non è stata toccata
    affatto (nemmeno il solo Rango 1) nella stessa sequenza — più severa
    della regola reale in un caso limite (nella realtà la traccia
    completata per ULTIMA può comunque raggiungere il proprio Rango 2
    anche se l'altra è stata tentata prima), ma esclude correttamente la
    combinazione realmente impossibile di ENTRAMBE le tracce religiose a
    Rango 2 nella stessa run. Le 91 combo di sinergia che includerebbero
    entrambe le tracce religiose a Rango 2 vengono ora scartate a monte
    (16 su 91, segnalate a schermo) invece di essere contate come
    raggiungibili.
  - **Verificato**: nuovo `--test-fase10` (`scripts/main.gd`), 14 blocchi
    di asserzioni (aggiunta una verifica dedicata: un singolo Rango 1
    riuscito su una traccia religiosa sblocca DA SOLO il Rango 2 della
    stessa traccia con la soglia 40) — formula malus/Svantaggio, ambito
    Polizia/Fama, pesi Karma (incluse varianti con suffisso), Attenzione
    Polizia su/giù, Karma sempre aggiornato, cadenza eventi esattamente
    ogni 6 turni, Fede dopo Rango 1, gating Rango 2 da Fede, Rivalità
    Criminale su/giù, proposta/accettazione/blocco del Patto con lo
    Stregatto, nessuna proposta di patto con Karma iniziale > -50. Tutti
    PASS. Nessuna regressione su `--test-ui` (contatore azioni aggiornato
    da 60 a 62), `--test-sinergie`, `--test-save-write/read`, `--play`.
  - **Tetto di riferimento aggiornato**: `tools/balance_ceiling.py` **42,23
    / 67,58 / 109,26 / 293,43 anni** per i quattro livelli —
    **invariato numericamente** rispetto a prima della correzione: la
    combo ottima (Azzardo+Bancaria+Religiosa) tocca una sola traccia
    religiosa, quindi il nuovo vincolo di Fede non la penalizza; le 16
    combo scartate perché includevano entrambe le tracce religiose non
    erano comunque ottimali. Monte Carlo (`--simulate=2000`, con
    Fede/Attenzione Polizia/eventi attivi): politica `greedy` media
    **58,47 anni** (sostanzialmente in linea con la Fase 9c — nessuna
    politica euristica tenta mai spontaneamente il cash-in o le tracce
    religiose abbastanza da essere influenzata dal vincolo di Fede), max
    osservato 111,65. La sequenza scriptata tripletta storica è tornata a
    **15,00%** (era 15,37% a fine Fase 9c, 0,00% col bug pre-correzione).
  - **Semplificazione nota, non richiesta esplicitamente**: la donazione
    finale (`GameState.dona()`) NON verifica `patto_in_sospeso` a
    livello di logica di gioco (il blocco è solo lato UI/testuale,
    disabilitando il controllo mentre il patto è aperto) — un accesso
    diretto a `dona()` bypassando l'interfaccia potrebbe teoricamente
    donare con un patto ancora aperto. Non specificato dalle istruzioni
    della Fase 10, lasciato così per non estendere lo scope.
- **Fase 10 — verifica e correzione cash-in (interpretazione B)**: fatto,
  chiude definitivamente la Fase 10. L'autore ha segnalato che il
  resoconto di fine Fase 10 riportava ancora 293,43 anni/interpretazione
  A per il tetto con sinergie. Verifica: confermato che la correzione
  all'interpretazione B (segnalata come ambiguità aperta a fine Fase 9c)
  non era MAI stata applicata al codice — non un refuso nel resoconto, un
  passo mancato. Per la cronaca: la Fase 10 originale non conteneva
  un'istruzione esplicita a cambiarla, quindi non è stata un'omissione
  di un'istruzione già data — restava segnalata come ambiguità aperta,
  correttamente non toccata unilateralmente fino a questa conferma
  esplicita dell'autore.
  - **Correzione applicata**: `GameState.applica_cash_in()` usa ora
    l'interpretazione B — nuova funzione `valore_rango2_traccia(nome)`
    (solo l'effetto del Rango 2, non Rango1+Rango2 sommati come la
    preesistente `valore_base_traccia()`, che resta ma non è più usata
    per il cash-in). Il bonus del cash-in si somma al guadagno di
    Rango1+Rango2 già incassato NORMALMENTE salendo di rango (
    `applica_traccia()`, invariato) — non lo sostituisce e non lo
    raddoppia nel moltiplicatore. `combo_tracce()` (per la scelta delle
    4 tracce di maggior valore quando 5+ qualificano) ordina ora per
    `valore_rango2_traccia`, coerente con cosa determina davvero il
    payout. Stessa correzione propagata a `BalanceSimulator._candidato_sinergia`
    (Monte Carlo) e `tools/balance_ceiling.py` (nuova
    `valore_rango2_traccia()` Python, formula del combo aggiornata da
    `base_r1r2 * (1 + moltiplicatore)` a
    `base_r1r2 + base_rango2_soli * moltiplicatore`).
  - **Chiarimento confermato dall'autore — 265,55 anni non è un bug**:
    il riferimento storico ~206,9 anni (e i vari "~207/~207-208 anni"
    sparsi nei log delle fasi precedenti, vedi le note aggiunte a
    posteriori più sopra) veniva da un **modello semplificato**,
    precedente alla costruzione del vero sistema a due ranghi in cui
    anche il Rango 1 — non solo il Rango 2 — ha un guadagno economico
    proprio. Sono due modelli diversi, costruiti in momenti diversi
    dello sviluppo, che non devono più coincidere: quello storico non
    contabilizzava affatto il guadagno di Rango 1. Il numero
    definitivo, calcolato con la meccanica a due ranghi effettivamente
    implementata (Rango1+Rango2 incassati salendo di rango,
    `applica_traccia`, invariato dalla Fase 9a, PIÙ il bonus del
    cash-in sul solo Rango 2, interpretazione B), è **265,55 anni**:
    206,86 di bonus cash-in isolato (quello che il vecchio riferimento
    ~206,9 misurava) + 58,69 di guadagno di Rango1+Rango2 che il
    vecchio modello non includeva.
  - **Tetto finale ai quattro livelli** (`tools/balance_ceiling.py`,
    rilanciato dopo la correzione):
    - Sole azioni core: **42,23 anni** (invariato)
    - + tracce (senza sottotrame/sinergie): **67,58 anni** (invariato)
    - + sottotrame (senza sinergie): **109,26 anni** (invariato)
    - + sinergie (sistema completo): **265,55 anni** (era 293,43 con
      l'interpretazione A) — combo ottima invariata (Azzardo + Bancaria
      + Religiosa, moltiplicatore x4, usa l'intero budget di 168h);
      sottotrame contribuiscono **0** a questo specifico ottimo, perché
      la combo consuma tutte le 168h disponibili senza lasciare margine
      residuo — il loro contributo resta comunque incluso nel calcolo
      (tier "+ sottotrame" sopra, 109,26 anni, e nella ricerca
      esaustiva delle 91 combo, dove ogni combo lascia il budget
      residuo ottimizzabile anche su azioni/sottotrame).
  - **Verificato con Monte Carlo** (`--simulate=2000`, dado vero):
    sequenza scriptata tripletta storica tornata a **16,80%** di
    successo sull'intera catena (era 0,00% con la soglia di Fede 50 non
    ancora corretta, 15,00%/15,37% con la sola correzione di Fede prima
    di questa — il numero è salito ulteriormente perché ora il costo
    atteso del cash-in non cambia ma il fallimento/successo dipende solo
    dal tiro CASH_IN_RISCHIO_PCT, indipendente dalla formula A/B: la
    piccola oscillazione tra 15,00/15,37/16,80% è normale rumore
    statistico su 2000 campioni, non un effetto della correzione),
    punteggio medio quando la catena riesce **266,57 anni** — coerente
    col tetto deterministico di 265,55.
  - **Nessuna regressione**: `--test-sinergie` aggiornato (assert ora
    verifica il bonus contro `valore_rango2_traccia` invece della somma
    Rango1+Rango2, con lo stesso margine di varianza ±20%),
    `--test-fase10`, `--test-ui`, `--test-save-write/read` tutti PASS.
- **Sessione narrativa (post-Fase 10): nomi propri, Dolce Volpe, origine
  Eterni, patti, revisione del mondo senza sabbia**: fatto. **Solo
  documentazione — nessuna modifica al codice.** I nomi propri e i nuovi
  contenuti narrativi vivono per ora SOLO nel design doc (e in questo
  file): il codice (`GameState`, UI, loop testuale) continua a usare
  "Sirio"/"Sara"/ecc. mai — resta genericamente "il padre"/"la figlia" nei
  commenti e "[PLACEHOLDER STREGATTO]" come marcatore letterale, invariato.
  Applicare i nomi propri al codice (testi UI, eventuali costanti) è
  esplicitamente fuori scope per questo passaggio.
  - **Nomi propri** (design doc sezione 3): Sirio (protagonista/padre),
    Sara (figlia neonata), Serena (madre defunta), Ledune (la metropoli),
    L'chen (l'organizzazione criminale PRINCIPALE/attuale di Sirio).
    Sostituiti in tutto il design doc ovunque il riferimento fosse
    chiaramente al personaggio specifico (circa 25 paragrafi tra sezioni
    2-11). **Correzione post-sessione (confermata dall'autore)**: "il
    vecchio boss"/"la vecchia organizzazione"/"la vecchia rete"
    (sottotrame 6.1 "Il tesoro del vecchio boss" e 6.10 "La cassa di
    guerra della vecchia organizzazione") erano state inizialmente
    lasciate ambigue (non era chiaro se fossero la STESSA L'chen vista
    dal passato di Sirio o un'organizzazione diversa). L'autore ha
    confermato: è sempre L'chen — "il vecchio boss" è il mentore
    criminale defunto di Sirio, predecessore dell'attuale vertice
    dell'organizzazione; "la vecchia organizzazione" è L'chen vista dal
    passato di Sirio, non un'entità diversa. Reso esplicito nel design
    doc alla prima occorrenza in ciascuna sottotrama ("il vecchio boss
    di L'chen" in 6.1, "la sua vecchia organizzazione, L'chen" in 6.10)
    e nella descrizione della traccia Criminale (7.1, "soppianti il
    vecchio boss di L'chen"), così resta chiaro anche leggendo una
    sezione isolata. **Ancora lasciato generico, non toccato da questa
    correzione**: "un rivale dell'organizzazione" (5.3, testo di
    un'azione corretta) — non menzionato dall'autore, resta ambiguo per
    lo stesso motivo originale. **NON toccati**:
    "Tempo-Figlia"/"Sabbia-Padre" (nomi di meccaniche/variabili, non
    riferimenti narrativi al personaggio) restano tali in tutto il
    documento, inclusa la prosa che li definisce.
  - **Lo Stregatto → Dolce Volpe** (nome proprio: Dolce Volpe / Dessert
    Fox): "Stregatto" mantenuto come nome dell'archetipo/categoria
    narrativa (prima introdotto in 3.5, poi ribadito in apertura di 9),
    "Dolce Volpe" usato come nome proprio in tutti i riferimenti
    successivi del documento (headings 3.5 e 9 aggiornati a "... (Dolce
    Volpe)" per rintracciabilità). Aggiornati anche i riferimenti sparsi
    nelle sezioni 7.2/7.4/8.4/10 che davano ancora "lo Stregatto".
  - **Monologo della rottura della quarta parete** (nuova sezione 9.2,
    testo integrale fornito dall'autore, trascritto verbatim inclusi gli
    apostrofi diritti dei dialoghi): sostituisce qualunque placeholder
    precedente nel design doc — NON il placeholder nel CODICE
    (`[PLACEHOLDER STREGATTO]`), che resta invariato, essendo questo
    passaggio solo documentazione.
  - **Revisione di continuità (sezione 8.3, non un'aggiunta)**: la
    rottura della quarta parete in chiave di orrore cosmico, prima
    attribuita agli Eterni che parlavano direttamente al giocatore, è
    ora messa in scena TRAMITE Dolce Volpe. Gli Eterni restano
    un'entità narrativa distinta con una propria lore (origine, sotto),
    ma non parlano più in prima persona al giocatore — testo precedente
    di 8.3 RIMOSSO, non lasciato come alternativa.
  - **Origine degli Eterni** (nuova lore, sezione 8.1): un tempo
    sacerdoti della Mesopotamia; in cambio della capacità di assorbire
    sabbia altrui SENZA consenso — l'unica eccezione alla regola
    fondamentale del mondo (sezione 4.2, ora con una nota di
    cross-reference) — compirono un rituale che evocò gli Uomini del
    Mare (demoni, non il popolo storico), che distrussero le civiltà
    mesopotamiche ed egizie. Il giocatore arriva a scoprirla (non resta
    un segreto mai svelato). **Catena di scoperta** (sezione 8.2, collega
    sistemi già esistenti — nessuna nuova logica inventata): completare
    "La cripta della setta degli eterni" (6.5) lascia un frammento
    permanente → sblocca la nuova azione rara "Consultare uno studioso
    clandestino" → la rivelazione completa richiede ANCHE Fede >= 90 in
    Religiosa o Occulto nella STESSA run. **Solo testo/contenuto per
    ora**: la nuova azione è documentata nel design doc, non aggiunta al
    foglio Excel/`data/azioni.json` né implementata la logica di sblocco
    — prossimo passo naturale quando si tornerà a toccare il codice.
  - **Due patti concreti** (nuova sezione 9.3, narrativi, NON
    implementati meccanicamente — il codice ha solo il meccanismo
    generico di Fase 10, sezione 9.1, informalmente "il Patto delle 26
    Ore" nella terminologia dell'autore): **Il Patto della Grazia a
    Termine** (Karma azzerato a 0 subito; prezzo condizionale — se la run
    successiva non porta a Sara almeno 75 anni di sabbia senza crimini,
    il Karma crolla a -100 alla fine di quella run; richiederebbe un
    nuovo campo "condizione pendente" nel Profilo Persistente, non
    esistente, fuori scope) e **Il Patto del Ritorno** (disponibile solo
    dopo un evento "mondo senza sabbia" in una run precedente; riporta la
    sabbia come meccanica; prezzo: Sirio uccide Serena e Sara, vive e
    felici in quel mondo — sezione 10.2 revisionata). Il terzo patto
    resta esplicitamente aperto, non inventato.
  - **Revisione del mondo senza sabbia** (sezione 10.2, SOSTITUISCE la
    versione precedente, non un'aggiunta — vecchio testo rimosso):
    Serena e Sara sono vive e vivono una vita serena e felice nel mondo
    dove la sabbia non esiste più, non la stessa tragedia che si ripete
    identica come descritto in precedenza. Collegata esplicitamente al
    Patto del Ritorno: il suo prezzo (uccidere Serena e Sara) ha senso
    narrativo solo perché in quel mondo sono vive. Sezione 10.3
    aggiornata di conseguenza: "come uscirne" ora punta esplicitamente al
    Patto del Ritorno invece di una frase generica scollegata dai nuovi
    patti.
  - **Nome della casata, sottotrama 6.7**: Sabbiedoro — sostituito il
    placeholder "[dinastia da nominare]" nel titolo e "manca ancora un
    nome proprio" nello stato. **Non toccato**: il nome della sottotrama
    in `data/sottotrame.json`/Excel resta "Il crollo della casata [nome
    da assegnare]" — nessuna modifica al codice in questo passaggio,
    andrà aggiornato quando si toccherà di nuovo l'estrazione dati.
  - **Loading screen di Serena legati al Karma** (nuova sottosezione in
    3.3): 4 fasce di esempio (Karma neutro, lievemente negativo,
    molto negativo <-50, molto positivo >+50) con una frase ciascuna —
    schema di riferimento, non l'elenco finale delle frasi (da scrivere
    in una fase futura).
  - **Finali multipli a tre esiti** (sezione 4.5, aggiornata): schema
    pulito / ambiguo / sporco-estremo invece di un finale per singola
    sfumatura di moralità — testo integrale dei tre finali da scrivere in
    una fase futura, qui solo lo schema.
  - **Scope del flavor text** (nuova nota in sezione 5.2): nessun flavor
    text per le 60 azioni core generiche (il nome basta); riservato solo
    alle 10 sottotrame endgame e alle 17 azioni "una tantum", da
    scrivere in una fase futura.
  - **Elementi mancanti**: sezione "Contenuti narrativi non scritti"
    aggiornata — nomi propri, patti (parzialmente), nome casata, nuova
    voce "Origine degli Eterni" tutti marcati RISOLTO/PARZIALMENTE
    RISOLTO (nuovo stato aggiunto alla legenda). Lasciati aperti (per
    istruzione esplicita): "perché solo gli umani scambiano sabbia"
    (non ha una riga dedicata nella tabella, resta aperta solo nel
    design doc 11.1) e il terzo patto. **Lasciato aperto anche se non
    esplicitamente richiesto**: "Cosa fa scattare l'intervento degli
    Eterni" resta RIMANDATO — non è stato affrontato in questa sessione
    (il contenuto aggiunto riguarda l'origine storica degli Eterni, non
    il trigger dell'evento "mondo senza sabbia"), quindi non l'ho marcato
    risolto pur non essendo tra le due eccezioni esplicitamente elencate.
    **Correzione post-sessione**: la riga "'Il tesoro del vecchio boss'
    incompatibile con la regola della sabbia", segnalata come
    incongruente (RIMANDATO nella tabella nonostante il design doc,
    sezione 11.1, la desse già RISOLTO da una fase precedente), è stata
    corretta su richiesta esplicita dell'autore: ora RISOLTO anche in
    Elementi mancanti, allineata al design doc.
- **Batch tecnico (autore in viaggio, lavoro senza decisioni di
  design/scrittura) — Task 1: difficoltà crescente (design doc 12.5)**:
  fatto. `GameState._init(seed_iniziale, livello_difficolta_iniziale)`
  accetta ora un secondo parametro opzionale: Sabbia-Padre iniziale
  `24h - 4h*livello` (24→20→16→...), clampata a un floor di 1h invece di
  un livello massimo esplicito (non specificato dal design doc — scelta
  tecnica, non di design, evita solo che una Sabbia-Padre iniziale a 0 o
  negativa renda la run immediatamente game-over o rompa la matematica).
  Rischio base `+5%` per livello, clampato a 100%, applicato a
  `DiceSystem.risolvi()` in TUTTI i 4 punti di risoluzione col dado
  (azioni, tracce, sottotrame, cash-in) tramite il nuovo helper
  `_rischio_con_difficolta()` — NON applicato agli eventi casuali
  automatici né al Patto con lo Stregatto: non sono "azioni" scelte
  attivamente nello stesso senso, scelta di scope documentata qui.
  - **Interpretazione del gate, non esplicitamente scritta nel design
    doc**: "sbloccabili dopo il primo traguardo 100+100" letto come un
    **gate binario** (hai raggiunto 100+100 almeno una volta? sì → puoi
    scegliere qualunque livello; no → forzato a 0), non un percorso
    sequenziale "vinci al livello N per sbloccare N+1" come in Ascension
    di Slay the Spire — che il design doc cita esplicitamente come
    modello insieme ad Heat di Hades, ma i due sistemi citati hanno
    regole di sblocco diverse tra loro (Ascension è sequenziale, Heat è
    liberamente selezionabile dopo il primo completamento), quindi la
    citazione non basta a determinare quale dei due si intendesse. Ho
    scelto il gate binario perché è quello letteralmente descritto dal
    testo del task ("sbloccabili dopo il primo traguardo 100+100" — una
    condizione sola, non una progressione). **Se l'autore intendeva il
    modello sequenziale, va rifatto**: non l'ho segnalato come domanda
    bloccante separata perché il testo del task era comunque sufficiente
    per procedere con un'interpretazione difendibile, ma la nota resta
    qui per la revisione al ritorno.
  - `PlayerProfile`: nuovo campo `traguardo_100_100_raggiunto: bool`
    (persistito, round-trip testato). `livello_difficolta` (già esistente
    dalla Fase 7, mai collegato a nulla) ora si aggiorna davvero a fine
    run (`GameUI._fine_partita()`) col livello effettivamente giocato, e
    `traguardo_100_100_raggiunto` diventa `true` la prima volta che
    `calcola_punteggio().vittoria_100_100` risulta vero a fine run.
  - **Gate applicato in `main.gd`, non in `GameState`** (che si fida del
    livello ricevuto, coerente con come già si fida del seed):
    `_livello_difficolta_effettivo(richiesto, profilo)` forza a 0 se
    `not profilo.traguardo_100_100_raggiunto`. Nuovo flag `--difficolta=N`
    (stesso pattern di `--seed=`): con la UI reale passa dal gate; con
    `--play` (strumento di debug, non tocca il Profilo Persistente — scelta
    di scope preesistente dalla Fase 7) il livello è applicato DIRETTAMENTE
    senza gate, per poter testare qualunque livello senza dover prima
    raggiungere 100+100. UI: barra seed ora mostra anche "Difficoltà: N".
  - **Verificato**: nuovo `--test-difficolta` — livello 0 non altera nulla,
    livello 2 dà esattamente 16h, livelli molto alti clampano al floor
    1h (mai 0/negativo), il rischio sale +5%/livello clampato a 100%,
    **a parità di seed un livello più alto trasforma un successo in un
    fallimento** (prova che il rischio è davvero applicato al tiro, non
    solo calcolato), il gate forza 0 senza traguardo e concede il
    livello richiesto con traguardo raggiunto. `--test-save-write/read`
    esteso al round-trip di `traguardo_100_100_raggiunto`. Nessuna
    regressione su `--test-ui`, `--test-sinergie`, `--test-fase10`.
  - **Non fatto, fuori scope per "lavoro tecnico"**: nessun selettore
    grafico del livello in `GameUI` (solo il flag `--difficolta=` e la
    lettura/scrittura da profilo) — costruire un widget di selezione
    prima di una run è una decisione di UI/UX, non solo tecnica.
- **Batch tecnico — Task 2: seed del giorno (design doc 12.6)**: fatto.
  Nuovo `scripts/core/seed_del_giorno.gd` (`class_name SeedDelGiorno`):
  `data_di_oggi_stringa()` (formato `YYYY-MM-DD` da `Time.get_date_dict_
  from_system()`), `seed_da_data(stringa)` (hash deterministico della
  data — `String.hash()` di Godot è un djb2 non randomizzato per
  processo, stessa stringa dà sempre lo stesso intero, mascherato a 31
  bit per restare non negativo, coerente col contratto di
  `GameState._init(seed_iniziale)`), `seed_di_oggi()`.
  - **Chiarimento dell'autore applicato alla lettera**: "classifica solo
    locale (nessun server esiste)" — NON costruito nulla che assomigli a
    una classifica condivisa tra giocatori (il design doc 12.6 parla di
    "classifica punteggio" in modo ambiguo, ma qui la richiesta era già
    esplicita: solo storico locale dei propri tentativi).
  - `PlayerProfile`: nuovo campo `storico_seed_del_giorno: Dictionary`
    (chiave = data, valore = Array di record punteggio+timestamp),
    nuovi metodi `registra_punteggio_seed_del_giorno(data, punteggio)`
    (accumula, non sovrascrive) e `tentativi_seed_del_giorno(data =
    oggi)`.
  - **Flag `--seed-del-giorno`** (stesso pattern di `--seed=`/
    `--difficolta=`, sovrascrive `--seed=` se entrambi presenti): con
    `--play` forza solo il valore del seed (nessuna registrazione,
    `--play` non tocca mai il Profilo Persistente, scelta di scope
    preesistente dalla Fase 7); con la UI reale, `GameUI.avvia()` prende
    un terzo parametro opzionale `e_seed_del_giorno` e a fine run
    registra il punteggio nello storico se true. `_run_ui()` stampa
    anche il record dei tentativi precedenti di oggi, se ce ne sono già,
    prima di iniziare.
  - **Verificato**: nuovo `--test-seed-del-giorno` — stessa data ->
    stesso seed (deterministico, non negativo), date diverse -> seed
    diversi, formato data corretto, il seed prodotto è davvero
    utilizzabile da `GameState` (due `GameState` con lo stesso seed
    derivato danno lo stesso esito sulla stessa azione), lo storico
    accumula (non sovrascrive) ed è verificato sopravvivere a
    `to_dict()`/`from_dict()`. Nessuna regressione su `--test-ui`,
    `--test-sinergie`, `--test-fase10`, `--test-difficolta`,
    `--test-save-write/read`.
  - **Nessuna decisione bloccante**: il testo del task era già
    sufficientemente specifico (compreso il chiarimento esplicito
    sull'assenza di server) da non richiedere di fermarsi.
- **Batch tecnico — Task 3: scheletro tecnico dei bivi (design doc 12.2)**:
  fatto. Come richiesto esplicitamente, SOLO il meccanismo generico —
  nessun bivio narrativo reale.
  - Nuovo `scripts/core/bivio_system.gd` (`class_name BivioSystem`): dati
    puri, separati dalla logica di applicazione (stesso principio di
    `ActionDatabase`/`TrackDatabase`). `Opzione` (nome, descrizione),
    `Bivio` (id, trigger testuale, `Array[Opzione]`),
    `get_bivi_segnaposto()` → 3 bivi (2-3 opzioni ciascuno, come
    richiesto), OGNI testo marcato `[SEGNAPOSTO]` esplicitamente. I
    trigger testuali ("inizio run", "dopo un aggancio a una traccia",
    "dopo certi eventi") ricalcano gli esempi del design doc 12.2 ma
    NON sono agganciati a nulla — nessun sistema li innesca
    automaticamente, sono scelte manuali per ora.
  - `GameState`: `bivi_scelti: Dictionary` (bivio.id -> indice opzione),
    `bivio_disponibile(id)`, `opzione_scelta(id)`, `applica_bivio(bivio,
    indice)` — un bivio è sempre "riuscito" (nessun dado: è una scelta
    pura), non consuma un turno (design doc: i trigger sono momenti
    puntuali dentro il flusso di gioco, non un'azione a sé), e una volta
    risolto preclude PER SEMPRE tutte le opzioni (anche quella scelta:
    non è ririsolvibile) per il resto della run — coerente col resto del
    "una tantum" già usato altrove nel progetto, ma con una struttura
    dedicata (`bivi_scelti`, non `azioni_uniche_usate`) perché un bivio
    non ha successo/fallimento da tracciare.
  - **Presentazione testuale** (come richiesto, "anche solo testo per
    ora"): nuova sezione `[BIVI]` nel loop testuale (`--play`), comando
    `bivio <id> <indice>`. **Non fatto, fuori scope per "lavoro
    tecnico"**: nessuna UI grafica per i bivi in `GameUI` — quando/come
    interromperli nel flusso della UI reale (modale? inline? a quale
    trigger esatto?) sono decisioni di UI/UX, non solo tecniche.
  - **Verificato**: nuovo `--test-bivi` — 3 bivi caricati con 2-3 opzioni
    ciascuno, un bivio non risolto è disponibile senza opzione scelta,
    un indice fuori range viene rifiutato SENZA consumare il bivio, la
    scelta valida non consuma un turno, un bivio risolto preclude ogni
    opzione (anche quella già scelta — non ririsolvibile) per il resto
    della run, bivi diversi restano indipendenti, una nuova run riparte
    con tutti i bivi disponibili (nessuna persistenza tra run in questo
    scheletro — non richiesta dal task). Verificato anche end-to-end nel
    loop testuale. Nessuna regressione sulle altre suite.
- **Batch tecnico — Task 4: scheletro tecnico della Rete di contatti
  (design doc 12.3)**: fatto. Come richiesto esplicitamente, SOLO il
  meccanismo generico — nessun contatto narrativo reale.
  - **Scope ridotto rispetto al design doc 12.3 completo, seguendo la
    descrizione più specifica del task**: il design doc parla di tre
    categorie (Amici/Amici di amici/Nemici); il task descrive UN
    contatto con un trigger e UNO tra tre effetti (riduzione costo,
    riduzione rischio, sblocco azione). Ho seguito il task, non il
    design doc completo — i "Nemici" (rischio ricorrente, nuove leve
    narrative) non sono modellati: sono contenuto/design, non
    meccanismo generico riducibile a un tipo di effetto.
  - Nuovo `scripts/core/contact_network.gd` (`class_name ContactNetwork`):
    dati puri (`Contatto`: id, nome, trigger, effetto, bersaglio, valore)
    + funzioni di valutazione. 3 contatti segnaposto, ogni testo marcato
    `[SEGNAPOSTO]`. **Scelta tecnica importante per la sicurezza del
    gioco reale**: i `bersaglio_effetto` dei 3 contatti puntano a nomi
    di azione INESISTENTI nel foglio Azioni (mai una delle 62 azioni
    vere) — così il meccanismo si aggancia davvero a `GameState`
    (`applica_azione_con_dado`, `azione_disponibile`) senza avere ALCUN
    effetto sul gioco reale finché l'autore non definirà contatti veri
    con bersagli reali. Verificato esplicitamente con un test dedicato
    (nessuna delle 62 azioni è bersagliata, un'azione reale resta
    disponibile anche con tutti e 3 i contatti segnaposto attivi).
  - Due tipi di trigger: `SOTTOTRAMA_COMPLETATA` (riusa
    `GameState.azione_completata_con_successo()`, già esistente dalla
    Fase 9b) e `TRACCIA_RANGO_RAGGIUNTO` (legge `tracce_raggiunte`).
  - `PlayerProfile`: il campo `rete_contatti_sbloccati` (esistente dalla
    Fase 7, sempre vuoto) ora è l'elenco reale degli id dei contatti
    sbloccati permanentemente, con `contatto_sbloccato(id)` e
    `sblocca_contatto(id)` (idempotente, mai rimosso).
    `ContactNetwork.valuta_sblocchi(stato, profilo)` va chiamato a fine
    run: valuta tutti i trigger non ancora soddisfatti contro lo stato
    finale, sblocca e persiste i nuovi, restituisce la lista per
    segnalarli al giocatore.
  - `GameState.contatti_attivi: Array[String]` (assegnato dal chiamante
    DOPO il costruttore, stesso pattern di `karma` — GameState non deve
    dipendere da `PlayerProfile`). `applica_azione_con_dado()` applica
    riduzione costo/rischio via `ContactNetwork.modificatore_per_azione()`
    prima della varianza roguelite; `azione_disponibile()` nasconde
    un'azione bersagliata da un contatto SBLOCCO_AZIONE non ancora
    sbloccato.
  - **Collegato in `main.gd`/`GameUI`**: `_run_ui()` popola
    `stato.contatti_attivi` da `profilo.rete_contatti_sbloccati`
    all'avvio; `GameUI._fine_partita()` chiama `valuta_sblocchi()` e
    segnala eventuali nuovi contatti nel messaggio finale prima di
    salvare il profilo. **Non fatto, fuori scope per "lavoro tecnico"**:
    nessuna UI grafica per esplorare/visualizzare la rete di contatti
    (schermata dedicata, albero di sblocco visuale) — decisione di
    UI/UX, non solo tecnica. `--play` non popola/non persiste
    `contatti_attivi` (stessa scelta di scope preesistente dalla Fase 7
    per tutto ciò che riguarda il Profilo Persistente in modalità debug).
  - **Verificato**: nuovo `--test-rete-contatti` — 3 contatti caricati,
    entrambi i tipi di trigger sbloccano correttamente (con ricerca di
    seed per un successo reale di sottotrama, non solo un mock),
    `valuta_sblocchi()` è idempotente, `modificatore_per_azione()`
    aggrega correttamente (0 se il contatto non è attivo), `azione_
    visibile()` nasconde/mostra il bersaglio SBLOCCO_AZIONE, **nessuna
    delle 62 azioni reali è toccata** (verifica di sicurezza esplicita),
    e soprattutto — il punto richiesto dal task — **uno sblocco ottenuto
    in una run (profilo + `sblocca_contatto`) sopravvive a un round-trip
    JSON completo e ha effetto in un `GameState` NUOVO e DIVERSO**
    (simula "run 1 sblocca, run 2 ne beneficia"). Nessuna regressione
    sulle altre suite né su `--play`.
- **Batch tecnico — Task 5: suite di regressione unica**: fatto. Nuovo
  `tools/regression_suite.py` — vedi anche "Comandi utili" in cima a
  questo file, dove è documentato come comando di riferimento.
  - Esegue in sequenza: `tools/balance_ceiling.py` (knapsack, estrae i 4
    tetti via regex dall'output), `--simulate=N` (Monte Carlo, estrae
    media `greedy` e probabilità della tripletta storica), `--test-save-
    write` + `--test-save-read` (in sequenza, come richiedono — il
    secondo dipende dal file scritto dal primo), `--test-ui`,
    `--test-sinergie`, `--test-fase10`, più i 4 test nuovi di questo
    stesso batch tecnico (`--test-difficolta`, `--test-seed-del-giorno`,
    `--test-bivi`, `--test-rete-contatti`) — **estensione non
    esplicitamente richiesta dal task**: il task elencava l'elenco
    "storico" di verifiche (knapsack/Monte Carlo/salvataggio/UI/
    sinergie/Fase 10), ma "verifica generale dello stato del progetto"
    doveva includere anche ciò che i Task 1-4 di questo stesso batch
    hanno appena aggiunto, altrimenti il comando sarebbe stato incompleto
    fin dal giorno in cui è stato scritto.
  - **PASS/FAIL non si fida del solo exit code**: un `assert()` fallito
    in GDScript non sempre fa uscire Godot con codice diverso da 0 (in
    build release); il criterio è la presenza del marker di
    completamento (`"TUTTI I TEST X OK"`) NELL'output E l'assenza di
    `"Assertion failed"`/`"SCRIPT ERROR"`/`"Parse Error"` — entrambe le
    condizioni verificate esplicitamente con un mini-test del parser
    stesso (output finto con/senza marker, con un errore nascosto dopo
    un marker presente per errore).
  - `--simulate=N` di default a **500** (non 2000-3000 come nei report
    "ufficiali" di fine fase): scelta tecnica di velocità per un comando
    pensato per essere rilanciato spesso, non un numero di validazione
    definitivo — parametrizzabile con `--simulate=N` sulla riga di
    comando per chi vuole i numeri "ufficiali".
  - **Verificato**: lanciato con `--simulate=100` (veloce) — 10/10 PASS,
    numeri estratti corretti e coerenti con quelli già confermati nelle
    fasi precedenti (core=42,23, +tracce=67,58, +sottotrame=109,26,
    +sinergie=265,55 anni). Verificato anche il codice di uscita (0 con
    tutto PASS) e la logica di rilevamento FAIL con input sintetici
    (marker assente, marker presente ma con un errore dopo).
- **Batch tecnico — Task 6: controllo di coerenza tra documenti**: fatto.
  Nuovo `tools/check_data_consistency.py`, confronta il foglio Excel
  (fonte di verità) con `data/azioni.json`, `data/tracce.json`,
  `data/sottotrame.json` — azioni/righe/sottotrame mancanti nel JSON,
  extra nel JSON (rimosse dall'Excel senza rigenerare), e per ogni voce
  presente in entrambi confronta campo per campo (tolleranza 1e-6 sui
  float). Non corregge nulla, solo segnala — coerente con l'istruzione
  esplicita.
  - **Scelta tecnica**: invece di scrivere un secondo parser Excel
    indipendente (rischio di segnalare differenze spurie per un bug
    proprio, non una vera discrepanza), ho refactorizzato
    `tools/extract_azioni.py`/`extract_tracce.py`/`extract_sottotrame.py`
    estraendo la logica di parsing in funzioni riusabili
    (`estrai_azioni(wb)`, `estrai_tracce(wb)`, `estrai_sottotrame(wb)`)
    che il checker importa e chiama direttamente — un'unica fonte di
    verità su "come si legge l'Excel", condivisa tra chi genera i JSON e
    chi li verifica. **Refactor confermato behavior-preserving**: ho
    confrontato l'output di ciascuno dei tre script (JSON scritto +
    stdout) PRIMA e DOPO il refactor (via `git stash`), byte per byte —
    identici in tutti e tre i casi. `main()` di ciascuno script continua
    a funzionare esattamente come prima, nessuna modifica al formato
    JSON o al comportamento da riga di comando.
  - **⚠️ Nessuna discrepanza trovata in questo momento**: rilanciato
    subito dopo la scrittura, i tre JSON risultano tutti allineati
    all'Excel (62 azioni, 14 righe di traccia + 3 tracce bonus, 10
    sottotrame, 0 discrepanze in ciascun dataset) — atteso, dato che
    ogni sessione precedente ha sempre rigenerato i JSON subito dopo
    ogni modifica all'Excel. Nessuna correzione da segnalare.
  - **Verificato che il rilevamento funzioni davvero** (non solo "non
    trova nulla perché non guarda bene"): test con una copia modificata
    di `data/azioni.json` (un valore alterato + una riga rimossa,
    ripristinata subito dopo) — lo script ha segnalato correttamente
    entrambe le discrepanze con dettaglio preciso (nome azione, campo,
    valore Excel vs valore JSON) ed è uscito con codice 1; con i file
    ripristinati, di nuovo 0 discrepanze e codice 0. `git status`
    confermato pulito su `data/azioni.json` dopo il test.
  - **Aggiunto anche a `tools/regression_suite.py`** (Task 5, stesso
    batch): la suite di regressione ora include anche questo controllo
    — coerente con lo scopo dichiarato di quel comando ("verifica
    generale dello stato del progetto").
- **Batch tecnico — Task 7: verifica di export standalone**: fatto.
  - **Export template mancanti, scaricati e installati**: la macchina
    non aveva alcun export template Godot installato
    (`~/.local/share/godot/export_templates/` vuota). Scaricato
    `Godot_v4.7.2-stable_export_templates.tpz` (~1,2GB, dai release
    GitHub ufficiali di Godot, stessa versione esatta del motore usato
    in questo progetto — la corrispondenza di versione è obbligatoria,
    Godot rifiuta l'export con template di versione diversa) e installato
    in `~/.local/share/godot/export_templates/4.7.2.stable/`.
  - **Nuovo `export_presets.cfg`** (in radice, ora TRACCIATO da git — vedi
    sotto): un preset "Linux" (piattaforma `Linux/X11`, architettura
    x86_64), scritto a mano seguendo lo schema noto di Godot 4.x (nessun
    modo da riga di comando per generare un preset dall'interno
    dell'editor — normalmente si aggiunge da Project > Export nella GUI).
    Nessun valore locale/sensibile: i campi `ssh_remote_deploy/*` sono i
    placeholder di default di Godot stesso (`"user@host_ip"`), non un
    valore reale di questa macchina.
  - **⚠️ Decisione tecnica presa senza fermarmi, da confermare**:
    `export_presets.cfg` era nel `.gitignore` fin dall'inizio del
    progetto (probabilmente ereditato dallo script di setup della Fase
    13/changelog "12", non documentato altrove il motivo). L'ho rimosso
    dal `.gitignore` e committato: è configurazione di progetto
    riproducibile, senza segreti, e il task chiedeva esplicitamente di
    "configurare" il preset — se fosse rimasto ignorato, la
    configurazione sarebbe esistita solo su questo checkout locale e
    sparita al primo `git clone` pulito. `export.cfg` (voce diversa,
    ancora ignorata, probabilmente un file legacy Godot 3 mai realmente
    usato in questo progetto Godot 4) lasciato invariato — non l'ho
    indagato oltre, fuori scope. Aggiunta anche una nuova voce `build/`
    al `.gitignore`: gli eseguibili esportati (70+ MB ciascuno) non
    vanno mai committati, si rigenerano dal sorgente.
  - **Export reale eseguito e verificato FUORI dall'editor**:
    `godot --headless --export-release "Linux" build/linux/il_ladro_di_sabbia.x86_64`
    produce un vero eseguibile ELF 64-bit (`file` conferma: "ELF 64-bit
    LSB executable, x86-64... stripped") + il `.pck` con le risorse.
    Smoke test: `./build/linux/il_ladro_di_sabbia.x86_64 --headless --
    --play --seed=777`, eseguito come processo INDIPENDENTE (non tramite
    l'editor Godot), produce un output byte-per-byte IDENTICO a
    `godot --headless --path . -- --play --seed=777` per diversi turni di
    gioco — prova che l'export non altera in alcun modo la logica.
  - **⚠️ Scoperta importante durante la verifica — `assert()` disattivato
    nelle build "release"**: rilanciando `--test-difficolta` (e le altre
    suite `--test-*`) sull'eseguibile `--export-release`, TUTTI i test
    riportano ancora "TUTTI I TEST X OK" in fondo, ma le singole righe di
    verifica sparivano silenziosamente — non un fallimento visibile, un
    **falso positivo silenzioso**: in Godot, `assert()` (incluse
    eventuali espressioni/effetti collaterali al suo interno, come i
    `print()` di debug annidati nelle mie funzioni di test) viene
    RIMOSSO dal bytecode nelle esportazioni "release" (comportamento
    standard, non un bug del progetto) — quindi le mie funzioni
    `_run_test_*()`, che si basano su `assert()` per verificare le
    condizioni, NON verificano più nulla in una build release: il
    messaggio finale "TUTTI I TEST OK" verrebbe stampato comunque anche
    se una condizione fosse falsa, perché il controllo stesso non viene
    mai eseguito. **Confermato e isolato con un secondo export**:
    `godot --headless --export-debug "Linux" build/linux-debug/...`
    (stesso identico progetto, preset "debug" invece di "release") — lì
    tutte le righe di verifica ricompaiono correttamente, identiche
    all'editor. **Implicazione pratica per il futuro**: i flag `--test-*`
    (e quindi anche `tools/regression_suite.py`, Task 5) sono affidabili
    SOLO nell'editor o in un export DEBUG — mai in un export release, che
    va verificato solo con smoke test "comportamentali" come `--play`
    (che non usa `assert()` per la logica di gioco vera, solo `print()`),
    non con i flag `--test-*`. Documentato qui perché non era un fatto
    noto prima di questa verifica, e chiunque in futuro lanci `--test-*`
    su un build distribuito ai giocatori otterrebbe un falso senso di
    sicurezza.
  - **Verificato anche sull'export debug**: tutti gli 8 flag `--test-*`
    esistenti (`--test-ui`, `--test-sinergie`, `--test-fase10`,
    `--test-difficolta`, `--test-seed-del-giorno`, `--test-bivi`,
    `--test-rete-contatti`, `--test-save-write`/`--test-save-read`)
    rilanciati sull'eseguibile debug esportato: tutti PASS, nessuna
    differenza rispetto all'editor.
- **Messa a verbale (solo documentazione): assert() rimosso nelle build
  release — confermato dall'autore, entrambe le decisioni tecniche del
  batch precedente restano invariate** (gate binario della difficoltà
  crescente, `export_presets.cfg` tracciato da git). L'unico compito di
  questa sessione era assicurarsi che la scoperta del Task 7 non
  restasse solo in fondo al log di questo file, dove rischiava di
  passare inosservata prima della pubblicazione:
  - **CLAUDE.md**: aggiunto un avviso ⚠️ prominente subito sotto il
    comando di riferimento `tools/regression_suite.py` in cima a
    "Comandi utili" (non solo nella sezione export, 80 righe più sotto)
    — chi cerca "come verifico lo stato del progetto" lo trova subito,
    non solo chi legge fino in fondo. Rafforzato anche l'avviso già
    presente nella sezione export standalone.
  - **Elementi mancanti**: nuova voce in sezione 1 "Decisioni tecniche"
    (tabella), stato RISOLTO (il meccanismo di verifica in editor/export
    debug funziona ed è verificato) ma col limite scritto per esteso e
    marcato ⚠️ IMPORTANTE come prima parola del dettaglio — non
    "RISOLTO" e basta, per non lasciare che un colpo d'occhio sul
    tracker dia l'impressione di "tutto verificabile allo stesso modo
    ovunque".
  - **Design doc**: la sezione 4.7 "Architettura tecnica" non
    menzionava affatto l'export/build finale — aggiunto un nuovo
    paragrafo con la stessa scoperta, prima del rimando esistente al
    documento "Elementi mancanti".
  - **Changelog design doc**: aggiunte le righe 17 (il batch tecnico
    Task 1-7 nel suo complesso, MAI loggato qui finora — solo in
    CLAUDE.md) e 18 (questa sessione di sola documentazione).
  - Nessuna modifica al codice, come richiesto.
- **Fase 11a (narrativa nel codice, prima tranche)**: fatto. Nuovo
  `scripts/core/narrativa.gd` (`Narrativa`, funzioni statiche pure): intro
  con i nomi propri (Sirio/Sara/Serena/Ledune), frase di Serena legata al
  Karma persistente (4 fasce del design doc 3.3, mostrata all'avvio in UI e
  `--play`), dialoghi del Patto con Dolce Volpe (sostituiscono ogni
  `[PLACEHOLDER STREGATTO]` in `GameState`, UI e loop testuale; il
  monologo della quarta parete 9.2 NON è ancora usato — resta per una
  scena dedicata) ed epilogo a tre esiti (4.5). **Decisioni mie, da
  confermare**: il finale pulito/ambiguo/sporco si sceglie dal Karma
  finale della run (>= +20 pulito, <= -50 sporco, altrimenti ambiguo) e si
  mostra solo se Sara è viva e la donazione è stata fatta; negli altri casi
  (Sara morta, nessuna donazione, padre morto) epiloghi brevi dedicati. Il
  testo è mio, da riscrivere/approvare dall'autore. Nuovo `--test-narrativa`
  incluso in `tools/regression_suite.py` (12/12 PASS).
  Ancora da fare: azione "Consultare uno studioso clandestino" e catena
  Eterni, patti 9.3, selettore di difficoltà e UI per bivi/rete di contatti.
