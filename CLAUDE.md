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

**Scope attuale**: solo il loop core (60 azioni, doppio countdown, dado d20,
donazione, punteggio). Tracce, sottotrame, Eterni, Stregatto, contenuti
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
  (`scripts/data/action_data.gd`). Include il campo `unica_per_run` (colonna
  Excel "Unica per run", aggiunta dopo il playtest della Fase 5): 17 azioni
  su 60 rappresentano un bersaglio/accordo/evento singolo e non sono
  ripetibili nella stessa run — vedi `GameState.azione_disponibile()`.
- **60 azioni core, confermato** (non 61): l'etichetta "61" nei documenti
  era un refuso, corretto dall'autore in design doc ed Excel. Nessuna azione
  mancante.
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

# (Fase 6) giocare con la UI grafica (richiede un display, es. X11/Wayland)
godot --path .

# (Fase 6) auto-test headless della UI: simula pressioni di bottoni senza
# display reale (utile da terminale/CI dove non si può vedere la finestra)
godot --headless --path . -- --test-ui

# (Fase 2, legacy) loop testuale giocabile da terminale — tenuto per
# verifiche headless rapide, la UI (Fase 6) è ora il modo principale di giocare
godot --headless --path . -- --play

# (Fase 5) simulazione Monte Carlo di bilanciamento, N run per ciascuna
# delle 3 politiche (greedy / greedy_no_free / random)
godot --headless --path . -- --simulate=3000

# (Fase 5) tetto economico deterministico (nessun dado), knapsack sulle
# 168h disponibili, legge data/azioni.json (nessuna dipendenza extra)
python3 tools/balance_ceiling.py
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
      ragionevole, nessuna ulteriore anomalia rilevata.
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
