# Il ladro di sabbia: l'impero di sabbia (direzione A)

Documento di riprogettazione del cuore economico. Stato: proposta validata con
un prototipo (`tools/prototipo/impero.py`), non ancora implementata nel gioco.

## 1. Perché cambiare

Il gioco attuale è una sequenza di colpi isolati: tiri, incassi, ricominci.
Niente di quello che fai continua a rendere, le scelte migliori si vedono a
colpo d'occhio (i guadagni vanno da mezz'ora a 23 anni), e la donazione non
è un dilemma: si dona sempre all'ultimo. Il concept regge; manca un motore.

La regola del mondo offre il motore: **la sabbia si cede solo
volontariamente, anche sotto minaccia**. Un impero, a Ledune, è una rete di
persone che ti cedono ore con regolarità. Sirio smette di rubare ore e
comincia a farsele dare.

## 2. Il ciclo di gioco

- Il tempo avanza a **fasce di 6 ore**: mattina, pomeriggio, sera, notte.
- In ogni fascia Sirio fa **una cosa**. Poi la città gira: i giri rendono,
  il calore sale, i rischi si risolvono, Sara può avere una crisi.
- Ogni fascia costa **6 ore a Sirio e 6 a Sara** (la regola "il padre paga
  ogni ora" resta).
- **Sara ha 21 giorni** (504 ore, 84 fasce) invece di una settimana. È il
  cambiamento di premessa più grosso: serve a dare spazio alla costruzione.
- **Sirio parte con 24 ore** più l'anticipo di Rocco: 30 ore subito, da
  restituire in 8 rate da 5 ore a partire dal terzo giorno. La prima
  giornata è una corsa per sopravvivere, poi si costruisce.
- Dormire occupa una fascia. Mentre Sirio dorme, la rete lavora: è il
  momento in cui l'impero si sente.

## 3. La rete: cinque giri

Ogni giro è un numero di persone che ti cedono sabbia a ogni fascia. Si fa
crescere con un'azione: ogni volta aggiunge persone in proporzione a quante
ne hai già (i debitori portano debitori, i fedeli portano fedeli). Più è
grande, più scotta.

| Giro | Chi ti dà sabbia | Ore per persona a fascia | Crescita per azione | Costo per persona | Rischio del tiro | Cosa scalda |
|---|---|---|---|---|---|---|
| Usura | debitori | 0,40 | 4 + 18% | 2h (il prestito) | 10% | polizia, piano piano; ogni tanto un debitore sparisce |
| Protezione | negozi | 0,90 | 3 + 20% | 1h | 30% | rivali e polizia; serve 1 uomo ogni 25 negozi |
| Bische | tavoli | 3,50 | 1 + 15% | 10h | 20% | polizia (molto); serve 1 uomo ogni 6 tavoli |
| Culto | fedeli | 0,15 | 5 + 22% | 0,4h | 25% | fama: lo scandalo dimezza il gregge |
| Cooperativa | operai del porto | 0,25 | 5 + 15% | 1,5h | 5% | niente; abbassa la polizia, alza il karma |

Personalità dei giri, emerse dal prototipo:
- **Usura e culto**: crescono in fretta e molto, con grande varianza (una
  retata o uno scandalo dimezzano tutto).
- **Protezione e bische**: più lente e stabili, ma vogliono uomini e
  attirano i rivali.
- **Cooperativa**: la strada onesta. Lenta e sicura, non porta lontano da
  sola: è una scelta morale, non la migliore economicamente.

## 4. Delegare: i luogotenenti

Quando un giro arriva a 8 persone e hai un uomo libero, puoi metterci un
luogotenente (20 ore). Da quel momento il giro **cresce da solo del 7% a
fascia** e non perde controllo, ma il luogotenente trattiene il 15% e ogni
fascia c'è una piccola probabilità che tradisca (il giro si dimezza). Il
passaggio da "fare" a "far fare" è il cuore della progressione.

Un giro senza luogotenente perde controllo (fino al 60% della resa) se non
ci passi di persona: il **giro di riscossione** è un'azione che lo
riporta al massimo e incassa qualcosa in più.

## 5. Il calore

Tre misure, legate alle risorse che esistono già:
- **Polizia** (usura, protezione, bische): a ogni fascia può scattare una
  **retata** che dimezza il giro illegale più esposto.
- **Rivalità** (protezione, bische): un **assalto** toglie negozi, tavoli e
  un uomo, a meno che tu non abbia uomini a difesa.
- **Fama** (culto, cooperativa): uno **scandalo** dimezza i fedeli.

Leve per raffreddare: corrompere (polizia), pagare un tributo (rivali),
un informatore in questura (la polizia sale più piano, permanente). Costano
di più quanto più sei grande.

## 6. Sara e la donazione

- Sara ha **crisi** sempre più probabili e gravi con il passare dei giorni.
  Visitarla dimezza la probabilità per due giorni.
- La donazione resta **unica e chiude la partita**, ma ora è un
  azzardo: aspettare fa crescere quello che puoi darle, e alza il rischio
  che una crisi la porti via prima.
- Nel prototipo chi aspetta fino in fondo perde Sara in circa il 9% delle
  partite. Chi dona al quattordicesimo giorno quasi mai, ma le dà circa
  sette volte meno.

## 7. Il punteggio

Il punteggio diventa una storia: gli anni di vita che Sara riceve.

| Traguardo | Anni a Sara |
|---|---|
| Arriva a fine mese | sotto 0,1 |
| Primo compleanno | 1 |
| Primo giorno di scuola | 6 |
| Maggiore età | 18 |
| Cento anni a testa (leggenda) | 100, e altrettanti a Sirio |

## 8. Risultati del prototipo

400 partite per strategia, bot a regole (gioca come una persona ragionevole,
non in modo ottimo):

| Strategia | Anni a Sara (media) | Mediana | 10% migliore | Massimo | Sara muore |
|---|---|---|---|---|---|
| Solo colpi | 0,01 | 0,01 | 0,01 | 0,02 | 8% |
| Onesto (cooperativa) | 0,08 | 0,05 | 0,16 | 1,12 | 4% |
| Usuraio | 1,31 | 0,70 | 3,33 | 8,02 | 9% |
| Boss (protezione) | 0,79 | 0,82 | 1,54 | 2,25 | 8% |
| Biscazziere | 0,60 | 0,61 | 1,21 | 1,79 | 10% |
| Predicatore | 1,00 | 0,33 | 3,12 | 5,70 | 8% |
| Impero misto (bot semplice) | 0,33 | 0,24 | 0,82 | 1,56 | 6% |
| Dona al giorno 14 | 0,12 | 0,12 | 0,22 | 0,31 | 0% |
| Mosse casuali | 0,03 | 0,02 | 0,05 | 0,30 | (Sirio muore nel 50%) |

Cosa dicono i numeri:
- **Rubare non basta.** Chi vive di colpi sopravvive ma non costruisce niente.
- **Quattro strade criminali tutte giocabili**, con profili diversi: alta
  varianza (usura, culto) o crescita stabile (protezione, bische).
- **La strada onesta è dura**, come dev'essere in questo mondo.
- **Il dilemma della donazione esiste**: aspettare rende molto di più, ma
  costa Sara in quasi una partita su dieci.
- **Il bot misto è più debole degli specialisti** perché è ingenuo nel
  dividere il tempo. Da verificare con giocatori veri: l'obiettivo è che
  mescolare i giri convenga a chi lo fa con giudizio (protezione dagli
  imprevisti di un giro solo).
- **La leggenda dei cento anni resta irraggiungibile** con il solo motore:
  servono le grandi mosse (sezione 9).

## 9. Cosa resta del gioco attuale

- **Dado d20, critici, vantaggio e svantaggio**: invariati, usati per far
  crescere i giri, per i colpi e per difendersi.
- **Risorse**: polizia, rivalità, fama, karma diventano il calore dei giri.
  La fede resta per il culto.
- **Telefono**: i contatti diventano le porte dei giri. Rocco apre l'usura,
  Mei Shen la protezione, Marisa le bische, Padre Anselmo o Morgana il
  culto, Gaetano la cooperativa. I dialoghi restano.
- **Mappa**: ogni giro ha la sua sede (il porto, la bisca, il santuario,
  il magazzino di L'chen). Il giro di riscossione si fa sul posto.
- **Fame e sonno**: restano, a scala di fasce.
- **Tracce**: diventano i gradi dei giri (luogotenente, poi capo).
- **Sottotrame**: diventano le grandi mosse una tantum, possibili solo con
  un impero alle spalle (uomini, informatori, sabbia da investire). Sono
  l'unica via verso i traguardi più alti.
- **Sinergie (cash-in)**: diventano "la grande mossa" finale che liquida
  più giri insieme.
- **Le 62 azioni**: si riducono a una ventina di azioni di avvio e di
  colpo, riscalate su numeri da poche ore a qualche decina.
- **Karma persistente, Dolce Volpe, sblocchi tra una partita e l'altra**:
  restano.

## 10. Decisioni prese (approvate dall'autore)

1. **Sara 21 giorni invece di 7.** Cambia la premessa ("una settimana").
   Alternativa: restare a 7 giorni con fasce da 2 ore (stesso numero di
   turni, premessa intatta, ma notti e giornate meno leggibili).
2. **Il cuore economico va riscritto.** Finora il vincolo era non toccare
   `scripts/core/`. Con questa direzione il motore è nuovo: propongo un
   nuovo `ImperoState` in `scripts/core/`, lasciando `GameState` e i suoi
   test come riferimento storico finché il nuovo motore non li sostituisce.
3. **Il foglio Excel e il tetto dei 265,55 anni** non descrivono più il
   gioco. Propongo che i numeri vivano in un file di dati nuovo, tarato con
   il prototipo.

## 11. Piano di implementazione

1. `ImperoState` (logica pura, testabile senza scena) con fasce, giri,
   luogotenenti, calore, crisi di Sara, donazione.
2. Bot di bilanciamento in GDScript, stessi numeri del prototipo, nella
   suite di regressione.
3. Interfaccia: la schermata del luogo diventa la "sede" del giro con le
   sue azioni; un pannello Impero mostra giri, flussi, calore, luogotenenti.
4. Telefono e mappa ricollegati ai giri.
5. Grandi mosse e scrittura degli eventi (retate, assalti, scandali,
   tradimenti) con testi propri.

## 12. Stato dell'implementazione

Tutti i punti del piano sono fatti.

- `data/impero.json`, generato e validato da `tools/genera_impero.py`
  (riferimenti tra luoghi, contatti, giri e mosse; ogni giro aperto da un
  contatto, ogni grande mossa scopribile; regole editoriali).
- `scripts/core/impero_state.gd` (`ImperoState`), `impero_persistente.gd`
  (sblocchi tra una partita e l'altra, `user://impero_persistente.json`),
  `impero_bot.gd` (giocatore a regole), `impero_test.gd` (`--test-impero`).
- `scripts/ui/impero_ui.gd` (`ImperoUI`): barra con ora, i due orologi, la
  resa netta della rete a fascia, fame, sonno e calore; il luogo che stai
  guardando con le sue carte (guardare è gratis, agire in un luogo lontano
  riduce la resa della fascia); diario; telefono, mappa, pannello Impero,
  taccuino (grandi mosse, stato, obiettivi, opzioni); donazione con
  selettore.
- Rispetto al prototipo il gioco aggiunge luoghi, viaggi, telefono, pasti e
  sonno veri: rende un po' meno. Bot su 300 partite
  (`--demo-bilancio=300`): ladro 0,03 anni a Sara, onesto 0,05, usuraio
  0,32 (massimo 2,95), boss 0,30, biscazziere 0,33, predicatore 0,38
  (massimo 3,68), impero misto 0,08. Il bot dona quando a Sara restano
  meno di 130 ore: un giocatore che regge il rischio delle crisi fino agli
  ultimi giorni fa molto di più, perché la rete cresce in modo composto.

## 13. Ledune a piedi (Fase 15)

Il gioco ha smesso di essere un menu. Il tempo scorre a minuti: un secondo
nel mondo è un minuto di vita per Sirio e per Sara, e ogni gesto ne costa
altri (parlare, esaminare, giocare, cambiare stanza, viaggiare). Ogni sei ore
la città gira come prima.

- Ogni luogo è una o più stanze da percorrere a piedi. Gli oggetti sono le
  azioni: il registro di Nando fa crescere l'usura, il letto fa dormire,
  l'incubatrice fa stare con Sara o donare. Uscendo si apre la mappa.
- Le persone si incontrano di persona: dialoghi con ritratti, quattro
  categorie di risposta (fissa, statistica, ricordo della partita,
  occasione del seed).
- Sirio ha tre statistiche (Carisma, Intuizione, Freddezza) decise dal seed
  e qualche oggetto in tasca: aprono risposte, porte e vantaggi ai tiri.
- La bisca ha roulette e ring; la Cripta degli Eterni scende su tre livelli
  e al terzo serve la lanterna della sagrestia.
- Cutscene a pannelli per l'apertura, i finali e i momenti chiave; un tema
  musicale, quello di Sara, che cambia veste in ogni luogo.

Bilanciamento dopo il passaggio ai minuti (bot, 100 partite): le strategie
concentrate su un giro danno a Sara da 1,5 a 3 anni in media, con punte di 7;
i colpi da soli e il lavoro onesto restano sotto il mese.
