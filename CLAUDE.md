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

**Scope attuale**: loop core (60 azioni, doppio countdown, dado d20,
donazione, punteggio, varianza roguelite) + le 7 tracce normali + le 10
sottotrame endgame + le sinergie tra tracce (Blocco Fase 9, completo:
9a+9b+9c). Le 5 risorse con effetti reali (Fase 10), Eterni, Stregatto,
contenuti narrativi: fasi successive, non ancora iniziate. **Ambiguità
aperta da confermare con l'autore prima di considerare il tetto economico
definitivo**: la formula del cash-in di sinergia — vedi "Fase 9c" più sotto.

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
    e sottotrame (Fase 9b) non sono ancora incluse.
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
    mancante per avvicinarsi a quel numero.
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
  - **⚠️ AMBIGUITÀ IMPORTANTE DA RISOLVERE CON L'AUTORE — non risolta
    unilateralmente**: il design doc 7.3 dice che il cash-in "frutta la
    somma dei valori base delle N tracce moltiplicata per" il fattore,
    ma non chiarisce se "valori base" = Rango1+Rango2 sommati
    (interpretazione A, quella implementata sia in
    `GameState.applica_cash_in()` sia nel knapsack: i ranghi si
    incassano normalmente E IN PIÙ il cash-in dà quella somma ×
    moltiplicatore) oppure solo il Rango2 (interpretazione B, senza
    sommare anche i ranghi già incassati). Le due letture divergono
    enormemente: per la tripletta storica, A dà **293,43 anni**
    (**2.570.470,5 ore**), B dà **206,86 anni** (**1.812.080,8 ore**).
    **Il riferimento storico del documento "Elementi mancanti" (~206,9
    anni per questa stessa tripletta) combacia quasi esattamente con
    l'interpretazione B**, non con la A — probabile che l'autore
    intendesse quella, ma il codice attuale implementa la A. Tetto del
    sistema completo (azioni+tracce+sottotrame+sinergie) col codice
    attuale (interpretazione A): **293,43 anni** per un solo personaggio
    (ben sopra sia i 100 anni sia il riferimento storico ~207-208 anni,
    che però non includeva le sottotrame nello stesso calcolo — non è un
    confronto pulito). Se l'autore conferma l'interpretazione B, sia
    `GameState.applica_cash_in()` sia `tools/balance_ceiling.py`
    andranno corretti di conseguenza — NON ho corretto nulla
    unilateralmente, come da istruzioni.
