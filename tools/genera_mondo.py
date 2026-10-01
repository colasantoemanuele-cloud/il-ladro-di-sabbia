"""Genera data/mondo.json: luoghi di Ledune, contatti del telefono con i
dialoghi, occasioni (eventi che capitano), obiettivi che sbloccano contatti e
luoghi tra una run e l'altra. Controlla che ogni nome di azione, traccia e
sottotrama esista nei dati di gioco e che ogni azione scegliobile (non
"Evento") sia raggiungibile da un luogo o da un contatto.

Uso: python3 tools/genera_mondo.py

Condizioni (tutte devono valere): riuscita, successi {categorie|azioni, min},
rango {traccia, min}, rango_max {traccia, max}, flag, non_flag,
visite {luogo, min}, giorno_min, auto, polizia_min.
Effetti: azione, traccia+rango, sottotrama, luogo, contatto, pista, flag,
ore, pasto, messaggio. "se_riesce" contiene effetti applicati solo se il
tiro dell'azione/traccia/sottotrama riesce.
"""
import json
import re
import sys
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent

CRIMINI = ["Furto", "Crimine", "Minaccia 1 a 1", "Crimine organizzato"]
TURNI = ["Turno di lavoro onesto (8h, salario mediano)", "Turno doppio / straordinario (+25%)"]

LUOGHI = [
    {"id": "casa", "nome": "Casa", "tipo": "casa", "pos": [22, 32], "iniziale": True,
     "descrizione": "Due stanze in via dei Cordai. La culla è ancora montata.",
     "azioni": ["Riposare (dormire)", "Mantenere un basso profilo pubblico"],
     "speciali": [
         {"id": "mangia_casa", "testo": "Mangiare qualcosa a casa", "descrizione": "Pane secco e quel che resta in frigo.", "ore": 1.0, "effetti": [{"pasto": True}], "ripetibile": True},
         {"id": "cashin", "testo": "Mettere insieme i pezzi", "descrizione": "Seduto al tavolo della cucina, giochi tutte le tue posizioni in una mossa sola.", "tipo": "cashin"},
     ]},
    {"id": "ospedale", "nome": "Ospedale San Lazzaro", "tipo": "ospedale", "pos": [46, 18], "iniziale": True,
     "descrizione": "Terzo piano, terapia intensiva neonatale. Odore di disinfettante e di attesa.",
     "azioni": ["Visitare la figlia in ospedale"],
     "speciali": [{"id": "dona", "testo": "Donare a Sara", "descrizione": "Una volta sola. Irreversibile. La settimana finisce qui.", "tipo": "dona"}],
     "sottotrame": ["L'ultima donazione"]},
    {"id": "porto", "nome": "Il porto", "tipo": "porto", "pos": [14, 80], "iniziale": True,
     "descrizione": "Gru ferme, container arrugginiti. Gaetano dirige il turno di notte.",
     "azioni": TURNI + ["Settimana di lavoro nero con un caporale"],
     "condizioni_azioni": {"Settimana di lavoro nero con un caporale": {"flag": "caporale"}}},
    {"id": "piazza", "nome": "Piazza del Mercato", "tipo": "piazza", "pos": [46, 56], "iniziale": True,
     "descrizione": "Bancarelle, turisti distratti, una fontana senz'acqua.",
     "azioni": ["Comprare un pasto", "Mendicare in strada", "Esibirsi per strada (musica)", "Fingersi malato per elemosina mirata",
                "Piccolo furto (scippo)", "Minacciare un passante", "Estorsione a un piccolo imprenditore (pizzo)"],
     "condizioni_azioni": {"Estorsione a un piccolo imprenditore (pizzo)": {"successi": {"categorie": CRIMINI, "min": 1}}}},
    {"id": "quartiere_alto", "nome": "Via dei Giardini", "tipo": "villa", "pos": [76, 24], "iniziale": True,
     "descrizione": "Il quartiere alto. Cancelli, cani, finestre che non si aprono mai.",
     "azioni": ["Rovistare tra i rifiuti in zone ricche", "Furto con scasso in un appartamento", "Rapire l'erede di una famiglia ricca"],
     "condizioni_azioni": {"Rapire l'erede di una famiglia ricca": {"riuscita": "Comprare un'arma dal fornitore di fiducia"}},
     "sottotrame": ["Il crollo della casata [nome da assegnare]"]},
    {"id": "stazione", "nome": "Stazione di servizio", "tipo": "stazione", "pos": [70, 76], "iniziale": True,
     "descrizione": "Aperta tutta la notte. Neon, caffè bruciato, macchine parcheggiate male.",
     "azioni": ["Comprare un pasto", "Fare benzina", "Rubare un'auto (strumentale)", "Rapina a un negozio", "Corse clandestine di alto livello"],
     "condizioni_azioni": {"Fare benzina": {"auto": True}, "Corse clandestine di alto livello": {"auto": True}}},
    {"id": "chiesa", "nome": "Santuario di Santa Rena", "tipo": "chiesa", "pos": [48, 38], "iniziale": True,
     "descrizione": "Ceri accesi a pagamento. Il parroco conta le offerte due volte.",
     "azioni": ["Donare sabbia a un bisognoso"],
     "speciali": [{"id": "parroco", "testo": "Parlare con il parroco", "descrizione": "Padre Anselmo ascolta tutti. Ricorda tutto.", "ore": 1.0, "effetti": [{"contatto": "anselmo"}]}]},
    {"id": "banca", "nome": "Banca della Sabbia Centrale", "tipo": "banca", "pos": [64, 52], "iniziale": True,
     "descrizione": "Marmo, vetro blindato, guardie annoiate. Il caveau sta sotto la piazza.",
     "azioni": ["Rapina alla Banca della Sabbia Centrale (IL GRANDE COLPO)"],
     "condizioni_azioni": {"Rapina alla Banca della Sabbia Centrale (IL GRANDE COLPO)": {"riuscita": "Comprare i piani di sicurezza di una banca"}},
     "speciali": [{"id": "sportello", "testo": "Chiedere un prestito allo sportello", "descrizione": "Non te lo daranno. Ma il funzionario ti guarda in un modo strano.", "ore": 1.0, "effetti": [{"contatto": "bassi"}]}]},
    {"id": "questura", "nome": "Questura", "tipo": "questura", "pos": [34, 44], "iniziale": True,
     "descrizione": "Corridoi gialli, sedie di plastica. Qui tutti hanno un prezzo, ma nessuno lo dice.",
     "azioni": ["Corrompere un poliziotto", "Corrompere un giudice per far cadere un'accusa", "Fare l'informatore per la polizia (tradimento)"]},
    {"id": "palazzo", "nome": "Palazzo Comunale", "tipo": "palazzo", "pos": [64, 27], "iniziale": True,
     "descrizione": "Scale larghe, uscieri lenti. Le decisioni vere si prendono a cena.",
     "azioni": ["Ricatto a un politico corrotto"],
     "condizioni_azioni": {"Ricatto a un politico corrotto": {"riuscita": "Comprare informazioni su un bersaglio d'elite"}},
     "speciali": [{"id": "udienza", "testo": "Chiedere udienza all'assessore", "descrizione": "Due ore in anticamera per cinque minuti di sorrisi.", "ore": 2.0, "effetti": [{"contatto": "conti"}]}]},
    {"id": "agenzia", "nome": "Agenzia Clessidra", "tipo": "agenzia", "pos": [84, 46], "iniziale": True,
     "descrizione": "Prestiti-vita. Sul vetro: «Il futuro è adesso». Nessuno ride.",
     "azioni": ["Vendere anni futuri a un'agenzia di prestiti-vita"],
     "sottotrame": ["La fuga dal purgatorio dei debitori"]},
    {"id": "bottega_nando", "nome": "Bottega di Nando", "tipo": "bottega", "pos": [30, 66],
     "descrizione": "Banco dei pegni sul davanti, ricettazione sul retro.",
     "azioni": ["Vendere oggetti personali (fede nuziale)", "Vendere refurtiva al proprio fence"],
     "condizioni_azioni": {"Vendere refurtiva al proprio fence": {"successi": {"categorie": ["Furto", "Crimine"], "min": 1}}}},
    {"id": "bisca", "nome": "La Bisca del Molo", "tipo": "bisca", "pos": [8, 64],
     "descrizione": "Fumo, panno verde, una porta che si apre solo da dentro.",
     "azioni": ["Poker in una bisca di quartiere", "Slot machine", "Scommesse su combattimenti clandestini",
                "Lotteria clandestina della sabbia (jackpot raro)", "Tavolo VIP del boss della malavita"],
     "condizioni_azioni": {"Tavolo VIP del boss della malavita": {"successi": {"categorie": ["Azzardo"], "min": 3}}},
     "sottotrame": ["Il grande torneo dei senza-tempo", "Il tavolo dei senza fondo"]},
    {"id": "retrobottega", "nome": "Retrobottega di Ottavio", "tipo": "bottega", "pos": [26, 90],
     "descrizione": "Ottavio vende attrezzi da giardino. Nessuno ha mai visto un giardino.",
     "azioni": ["Comprare un'arma dal fornitore di fiducia", "Comprare un giubbotto antiproiettile", "Comprare documenti falsi di alta qualita'",
                "Noleggiare un furgone blindato per un colpo", "Comprare informazioni su un bersaglio d'elite"]},
    {"id": "magazzino", "nome": "Magazzino di L'chen", "tipo": "magazzino", "pos": [6, 90],
     "descrizione": "Casse di pesce, uomini che non sorridono. L'chen ha la memoria lunga.",
     "azioni": ["Colpo pianificato con la vecchia organizzazione", "Sabotare un concorrente dell'organizzazione", "Fare da sicario per un contratto d'elite",
                "Rapina a un furgone blindato", "Chiedere un favore importante a un vecchio boss", "Ripagare un vecchio debito d'onore",
                "Comprare i piani di sicurezza di una banca"],
     "condizioni_azioni": {"Fare da sicario per un contratto d'elite": {"riuscita": "Comprare un'arma dal fornitore di fiducia"},
                           "Rapina a un furgone blindato": {"riuscita": "Noleggiare un furgone blindato per un colpo"}},
     "sottotrame": ["La cassa di guerra della vecchia organizzazione"]},
    {"id": "bar_aurora", "nome": "Bar Aurora", "tipo": "bar", "pos": [50, 86],
     "descrizione": "Il bar dei rivali. Il caffè è buono, gli sguardi no.",
     "azioni": ["Pagare un tributo ai rivali", "Vendere una soffiata compromettente a un rivale dell'organizzazione"],
     "condizioni_azioni": {"Vendere una soffiata compromettente a un rivale dell'organizzazione": {"successi": {"categorie": CRIMINI, "min": 1}}},
     "sottotrame": ["Il patto con l'usuraio della mezzanotte"]},
    {"id": "laboratorio", "nome": "Laboratorio di via Recanati", "tipo": "laboratorio", "pos": [38, 8],
     "descrizione": "Seminterrato con luci al neon. Il dottor Sabatini paga in anticipo.",
     "azioni": ["Fare da cavia per un esperimento clandestino"]},
    {"id": "uffici_vettori", "nome": "Uffici Vettori & Figli", "tipo": "palazzo", "pos": [88, 14],
     "descrizione": "Un'azienda di trasporti con troppe porte e troppo poche serrature.",
     "azioni": ["Consulenza sicurezza per un'azienda"]},
    {"id": "villa_corradi", "nome": "Villa Corradi", "tipo": "villa", "pos": [94, 6],
     "descrizione": "La villa del vecchio boss di L'chen. Chiusa da quando è morto.",
     "sottotrame": ["Il tesoro del vecchio boss"]},
    {"id": "casa_aste", "nome": "Casa d'aste Morandi", "tipo": "palazzo", "pos": [90, 32],
     "descrizione": "Qui si vendono secoli di sabbia al miglior offerente.",
     "sottotrame": ["L'asta dei secoli"]},
    {"id": "catacombe", "nome": "Le catacombe", "tipo": "catacombe", "pos": [56, 70],
     "descrizione": "Sotto la città vecchia. Qualcuno accende candele che nessuno vede.",
     "speciali": [{"id": "candele", "testo": "Seguire le candele", "descrizione": "Una scia di cera porta più in basso.", "ore": 1.0, "effetti": [{"contatto": "morgana"}, {"flag": "rito_visto"}]}],
     "sottotrame": ["La cripta della setta degli eterni"]},
]

CONTATTI = [
    {"id": "gaetano", "nome": "Gaetano Ruggiero", "ruolo": "Capocantiere al porto", "iniziale": True,
     "saluto": "Sirio. Se chiami a quest'ora o ti serve lavoro o ti serve un alibi.",
     "opzioni": [
         {"id": "turno", "testo": "Hai bisogno di braccia stanotte?", "risposta": "Il turno parte quando arrivi al molo. Otto ore, paga onesta, niente domande sulla tua faccia.", "ripetibile": True},
         {"id": "nero", "testo": "C'è qualcosa che paga di più?", "risposta": "C'è un caporale che cerca gente per una settimana intera. Paga in nero. Te lo mando al molo.", "effetti": [{"flag": "caporale"}]},
         {"id": "lavoro1", "testo": "Un posto fisso, Gaetano.", "risposta": "Mi serve un caposquadra che non rubi. Tu rubi, ma lavori. Ti metto alla prova.",
          "condizione": {"successi": {"azioni": TURNI, "min": 1}}, "effetti": [{"traccia": "Lavoro", "rango": 1}]},
         {"id": "lavoro2", "testo": "Voglio la scrivania del direttore.", "risposta": "Il direttore va in pensione. Qualcuno deve firmare. Sai firmare, Sirio?",
          "condizione": {"rango": {"traccia": "Lavoro", "min": 1}}, "effetti": [{"traccia": "Lavoro", "rango": 2}]},
         {"id": "vettori", "testo": "Chi paga bene per la sicurezza?", "risposta": "I Vettori. Hanno più porte che serrature. Digli che ti mando io.",
          "condizione": {"rango": {"traccia": "Lavoro", "min": 1}}, "effetti": [{"luogo": "uffici_vettori"}]},
     ]},
    {"id": "rocco", "nome": "Rocco Ferrante", "ruolo": "Ex compagno di cella", "iniziale": True,
     "saluto": "Sei uscito vivo da quel parto? Allora dimmi cosa ti serve.",
     "opzioni": [
         {"id": "aiuto", "testo": "Mi serve una mano, Rocco.", "risposta": "Passa da me. Qualcosa ti trovo, come ai tempi.", "effetti": [{"azione": "Chiedere aiuto a un vecchio compagno di cella"}], "ripetibile": True},
         {"id": "lavoretto", "testo": "Hai un lavoretto per me?", "risposta": "Un magazzino da guardare fino all'alba. Se passa qualcuno, non l'hai visto.", "effetti": [{"azione": "Lavoretto di sicurezza per un vecchio contatto"}], "ripetibile": True},
         {"id": "nando", "testo": "Dove si vende roba senza domande?", "risposta": "Da Nando, dietro il mercato del pesce. Pesa tutto, anche te.", "effetti": [{"luogo": "bottega_nando"}]},
         {"id": "bisca", "testo": "Dove si gioca forte?", "risposta": "Alla bisca del molo. Bussa tre volte e non guardare il buttafuori negli occhi.", "effetti": [{"luogo": "bisca"}]},
         {"id": "ottavio", "testo": "Mi serve un ferro.", "risposta": "Ottavio. Retrobottega vicino ai cantieri. Paga subito e non toccare niente.", "effetti": [{"luogo": "retrobottega"}]},
         {"id": "lchen", "testo": "Rimettimi in contatto con L'chen.", "risposta": "Ci provo. Ma L'chen non dimentica chi se n'è andato.",
          "effetti": [{"azione": "Riattivare un vecchio contatto della rete criminale"}],
          "se_riesce": [{"contatto": "shen"}, {"luogo": "magazzino"}]},
         {"id": "medico", "testo": "Conosci un medico che non fa domande?", "risposta": "Sabatini. Paga chi si fa bucare. Non chiedere cosa c'è nella siringa.",
          "condizione": {"giorno_min": 2}, "effetti": [{"contatto": "sabatini"}, {"luogo": "laboratorio"}]},
         {"id": "usuraio", "testo": "Ho sentito di un usuraio che lavora di notte.", "risposta": "Al bar Aurora, dopo mezzanotte. Presta secoli. Si riprende tutto.",
          "condizione": {"giorno_min": 3}, "effetti": [{"pista": "Il patto con l'usuraio della mezzanotte"}, {"luogo": "bar_aurora"}]},
     ]},
    {"id": "venti", "nome": "Dott.ssa Ilaria Venti", "ruolo": "Pediatra di Sara", "iniziale": True,
     "saluto": "Signor Sirio. Sono di turno, ho poco tempo.",
     "opzioni": [
         {"id": "sara", "testo": "Come sta Sara?", "risposta": "@stato_sara", "ripetibile": True},
         {"id": "dono", "testo": "Quando posso donarle la mia sabbia?", "risposta": "Quando vuole, qui in reparto. Ma una volta sola: il suo corpo non regge una seconda donazione.", "ripetibile": True},
         {"id": "vicino", "testo": "Chi è il vecchio nel letto in fondo?", "risposta": "Un paziente senza parenti. Ha più sabbia di quanta gliene serva. Dice che la regalerà a chi lo farà ridere.",
          "condizione": {"visite": {"luogo": "ospedale", "min": 2}}, "effetti": [{"pista": "L'ultima donazione"}]},
     ]},
    {"id": "shen", "nome": "Mei Shen", "ruolo": "Luogotenente di L'chen",
     "saluto": "Il figliol prodigo. Parla in fretta, il telefono non è sicuro.",
     "opzioni": [
         {"id": "tesoro", "testo": "Cosa resta del vecchio boss?", "risposta": "La villa è chiusa. Si dice che il tesoro sia ancora sotto il pavimento. Nessuno ha avuto il coraggio.",
          "effetti": [{"pista": "Il tesoro del vecchio boss"}, {"luogo": "villa_corradi"}]},
         {"id": "rivali", "testo": "Chi sono i rivali, adesso?", "risposta": "Quelli del bar Aurora. Pagano bene le soffiate e male i debiti.", "effetti": [{"luogo": "bar_aurora"}]},
         {"id": "crim1", "testo": "Voglio rientrare. Davvero.", "risposta": "Hai mostrato i denti. Ti diamo una squadra. Non farcela rimpiangere.",
          "condizione": {"successi": {"categorie": CRIMINI, "min": 2}}, "effetti": [{"traccia": "Criminale", "rango": 1}]},
         {"id": "crim2", "testo": "Voglio il posto del boss.", "risposta": "Allora prenditelo. Ma il posto del boss si prende una volta sola.",
          "condizione": {"rango": {"traccia": "Criminale", "min": 1}}, "effetti": [{"traccia": "Criminale", "rango": 2}]},
         {"id": "cassa", "testo": "Si parla di una cassa di guerra.", "risposta": "Nel magazzino, dietro le casse di pesce. Solo i luogotenenti conoscono la combinazione. Adesso anche tu.",
          "condizione": {"rango": {"traccia": "Criminale", "min": 1}}, "effetti": [{"pista": "La cassa di guerra della vecchia organizzazione"}]},
     ]},
    {"id": "marisa", "nome": "Marisa Lo Bianco", "ruolo": "Croupier alla bisca",
     "saluto": "Il fortunato. O lo sfortunato, dipende dalla sera.",
     "opzioni": [
         {"id": "azz1", "testo": "Voglio un posto fisso al tavolo.", "risposta": "Il boss ha notato come giochi. Ti fa sedere tra quelli che contano.",
          "condizione": {"successi": {"categorie": ["Azzardo"], "min": 2}}, "effetti": [{"traccia": "Azzardo", "rango": 1}]},
         {"id": "azz2", "testo": "E se la bisca fosse mia?", "risposta": "Il gestore è stanco. Gli serve qualcuno che regga i conti e i coltelli.",
          "condizione": {"rango": {"traccia": "Azzardo", "min": 1}}, "effetti": [{"traccia": "Azzardo", "rango": 2}]},
         {"id": "torneo", "testo": "Ho sentito parlare di un torneo.", "risposta": "Il torneo dei senza-tempo. Giocano quelli che non hanno più niente. Vince chi ha meno paura.",
          "condizione": {"successi": {"categorie": ["Azzardo"], "min": 3}}, "effetti": [{"pista": "Il grande torneo dei senza-tempo"}]},
         {"id": "senzafondo", "testo": "Esiste un tavolo più alto di questo?", "risposta": "Il tavolo dei senza fondo. Sotto la sala, una sera sì e una no.",
          "condizione": {"rango": {"traccia": "Azzardo", "min": 1}}, "effetti": [{"pista": "Il tavolo dei senza fondo"}]},
     ]},
    {"id": "bassi", "nome": "Ettore Bassi", "ruolo": "Funzionario di banca",
     "saluto": "Non mi chiami in ufficio. Mai più. Cosa vuole?",
     "opzioni": [
         {"id": "banca1", "testo": "Mi serve qualcuno dentro.", "risposta": "Con documenti puliti posso farla entrare come consulente. Il resto lo impara da solo.",
          "condizione": {"riuscita": "Comprare documenti falsi di alta qualita'"}, "effetti": [{"traccia": "Bancaria", "rango": 1}]},
         {"id": "banca2", "testo": "Voglio una filiale in tasca.", "risposta": "Il direttore ha dei vizi. Io ho le prove. Lei ha il coraggio. Forse.",
          "condizione": {"rango": {"traccia": "Bancaria", "min": 1}}, "effetti": [{"traccia": "Bancaria", "rango": 2}]},
         {"id": "asta", "testo": "Chi compra sabbia all'ingrosso?", "risposta": "Morandi. Una casa d'aste per gente che compra secoli. Le do l'indirizzo.",
          "condizione": {"rango": {"traccia": "Bancaria", "min": 1}}, "effetti": [{"pista": "L'asta dei secoli"}, {"luogo": "casa_aste"}]},
     ]},
    {"id": "anselmo", "nome": "Padre Anselmo", "ruolo": "Parroco di Santa Rena",
     "saluto": "Figliolo. Il Signore ascolta. Io anche, ma costo meno.",
     "opzioni": [
         {"id": "rel1", "testo": "La gente compra speranza?", "risposta": "Compra reliquie. La speranza la regaliamo con lo scontrino.",
          "condizione": {"successi": {"azioni": ["Donare sabbia a un bisognoso"], "min": 1}}, "effetti": [{"traccia": "Religiosa (indulgenze)", "rango": 1}]},
         {"id": "rel2", "testo": "Voglio un gregge tutto mio.", "risposta": "Allora predica. Il gregge segue chi parla forte e chiede poco.",
          "condizione": {"rango": {"traccia": "Religiosa (indulgenze)", "min": 1}}, "effetti": [{"traccia": "Religiosa (indulgenze)", "rango": 2}]},
         {"id": "paura", "testo": "Di cosa ha paura, padre?", "risposta": "Delle candele nelle catacombe. Qualcuno prega laggiù, e non prega il mio Dio.", "effetti": [{"luogo": "catacombe"}]},
     ]},
    {"id": "conti", "nome": "Valerio Conti", "ruolo": "Assessore al bilancio",
     "saluto": "Signor Sirio. La mia segreteria dice che lei insiste. Mi dica.",
     "opzioni": [
         {"id": "pol1", "testo": "So cose che le servono.", "risposta": "Allora lavori per me. Un fixer che sa tacere vale più di un consigliere.",
          "condizione": {"riuscita": "Comprare informazioni su un bersaglio d'elite"}, "effetti": [{"traccia": "Politica", "rango": 1}]},
         {"id": "pol2", "testo": "Voglio tirare i fili, non portarli.", "risposta": "Ambizioso. Bene. I burattinai non si vedono mai sul palco.",
          "condizione": {"rango": {"traccia": "Politica", "min": 1}}, "effetti": [{"traccia": "Politica", "rango": 2}]},
         {"id": "casata", "testo": "Chi comanda davvero in via dei Giardini?", "risposta": "I Sabbiedoro. Una casata che sta crollando. Chi è vicino quando cade, raccoglie.",
          "condizione": {"rango": {"traccia": "Politica", "min": 1}}, "effetti": [{"pista": "Il crollo della casata [nome da assegnare]"}]},
     ]},
    {"id": "morgana", "nome": "Morgana Vizzini", "ruolo": "Voce della setta",
     "saluto": "Ti aspettavamo. La sabbia ha un rumore, quando scende.",
     "opzioni": [
         {"id": "occ1", "testo": "Cosa chiedete a chi entra?", "risposta": "Un nome falso e un po' di sangue. Diventerai adepto, se il rito ti accetta.",
          "condizione": {"flag": "rito_visto"}, "effetti": [{"traccia": "Occulto (setta satanica)", "rango": 1}]},
         {"id": "occ2", "testo": "Voglio guidarvi.", "risposta": "Chi guida deve scendere più in basso degli altri. Sei pronto?",
          "condizione": {"rango": {"traccia": "Occulto (setta satanica)", "min": 1}}, "effetti": [{"traccia": "Occulto (setta satanica)", "rango": 2}]},
         {"id": "cripta", "testo": "Cosa c'è oltre l'ultima porta?", "risposta": "La cripta degli eterni. Chi la apre trova qualcosa. Non sempre quello che cercava.",
          "effetti": [{"pista": "La cripta della setta degli eterni"}]},
     ]},
    {"id": "sabatini", "nome": "Dott. Sabatini", "ruolo": "Medico senza albo",
     "saluto": "Vene buone, lei. Le ho viste in sala d'attesa.",
     "opzioni": [
         {"id": "prova", "testo": "Cosa c'è nella siringa?", "risposta": "Sabbia sintetica. Forse funziona. Le pago la risposta.", "ripetibile": True},
     ]},
]

OCCASIONI = [
    {"id": "portafoglio", "luoghi": ["piazza", "quartiere_alto", "porto"], "probabilita": 0.22, "max": 2,
     "titolo": "Un portafoglio a terra",
     "testo": "Pelle buona, un documento, qualche ora di sabbia. Il proprietario abita a due isolati.",
     "scelte": [
         {"testo": "Restituirlo", "effetti": [{"azione": "Rintracci il proprietario di un portafoglio trovato e glielo restituisci"}]},
         {"testo": "Farsi ricompensare", "effetti": [{"azione": "Trovi un portafoglio, rintracci il proprietario e ti fai 'ricompensare' con le maniere forti"}]},
         {"testo": "Lasciarlo dov'è", "effetti": []}]},
    {"id": "testimone", "luoghi": ["quartiere_alto", "porto", "stazione"], "probabilita": 0.12, "max": 1,
     "titolo": "Hai visto troppo",
     "testo": "Un uomo in cappotto di cammello chiude il bagagliaio in fretta. Lo riconosci: è un pezzo grosso.",
     "scelte": [
         {"testo": "Ricattarlo", "effetti": [{"azione": "Testimoni un crimine di un pezzo grosso, lo ricatti"}]},
         {"testo": "Guardare altrove", "effetti": []}]},
    {"id": "socio", "luoghi": [], "probabilita": 0.1, "max": 1, "condizione": {"giorno_min": 2},
     "titolo": "Messaggio da un numero sconosciuto",
     "testo": "«Sono Lillo. Ho un colpo per stanotte, mi manca un uomo. Ci sei?»",
     "scelte": [
         {"testo": "Ci sono", "effetti": [{"azione": "Un vecchio socio propone un colpo last-minute"}]},
         {"testo": "Non rispondere", "effetti": []}]},
    {"id": "benefica", "luoghi": ["chiesa", "ospedale"], "probabilita": 0.3, "max": 1,
     "titolo": "Una busta senza nome",
     "testo": "Una volontaria ti ferma. Hanno saputo di Sara. C'è una busta con qualche ora di sabbia.",
     "scelte": [
         {"testo": "Accettare", "effetti": [{"azione": "Un'associazione benefica dona sabbia (rara)"}]},
         {"testo": "Rifiutare", "effetti": []}]},
    {"id": "favore", "luoghi": ["magazzino"], "probabilita": 0.35, "max": 1,
     "titolo": "Un favore che pesa",
     "testo": "Un vecchio boss ti fa chiamare. Ha una busta per te. Non dice cosa vorrà in cambio.",
     "scelte": [
         {"testo": "Prendere la busta", "effetti": [{"azione": "Un boss ti fa un favore avvelenato"}]},
         {"testo": "Declinare con rispetto", "effetti": []}]},
    {"id": "posto_blocco", "luoghi": [], "probabilita": 0.25, "max": 3, "condizione": {"polizia_min": 30}, "al_viaggio": True,
     "titolo": "Posto di blocco",
     "testo": "Due volanti di traverso sulla strada. Un agente ti fa cenno di accostare.",
     "scelte": [{"testo": "Accostare", "effetti": [{"azione": "Controllo di polizia a sorpresa"}]}]},
    {"id": "marisa", "luoghi": ["bisca"], "probabilita": 1.0, "max": 1, "condizione": {"successi": {"categorie": ["Azzardo"], "min": 1}},
     "titolo": "Un numero sul tovagliolo",
     "testo": "La croupier ti passa un tovagliolo con un numero. «Se vuoi giocare sul serio, chiamami.»",
     "scelte": [{"testo": "Tenere il numero", "effetti": [{"contatto": "marisa"}]}]},
    {"id": "debitore", "luoghi": ["agenzia"], "probabilita": 1.0, "max": 1, "condizione": {"riuscita": "Vendere anni futuri a un'agenzia di prestiti-vita"},
     "titolo": "Un uomo senza futuro",
     "testo": "Fuori dall'agenzia, un uomo grigio ti afferra il braccio. «Anche tu? Esiste una via d'uscita dal purgatorio dei debitori. Io la conosco.»",
     "scelte": [{"testo": "Ascoltarlo", "effetti": [{"pista": "La fuga dal purgatorio dei debitori"}]}, {"testo": "Liberarti e andare", "effetti": []}]},
]

MESSAGGI_GIORNALIERI = {
    "2": "Sara ha passato la prima notte. Respira da sola, a tratti. Torni quando può.",
    "3": "Stabile. Ha stretto il mio dito. Non vuol dire niente, ma gliel'ho voluto dire.",
    "4": "Metà settimana. Il conto della sua sabbia scende come previsto. Non come speravamo.",
    "5": "Ha pianto tutta la notte. Le infermiere dicono che cercava qualcuno.",
    "6": "Mancano due giorni. Se deve decidere, decida presto.",
    "7": "Ultimo giorno. Sono qui fino alla fine del turno. Poi non so.",
}

OBIETTIVI = [
    {"id": "tre_giorni", "testo": "Arrivare vivo al terzo giorno", "condizione": {"giorno_min": 3},
     "sblocca": [{"contatto": "sabatini"}, {"luogo": "laboratorio"}], "nota": "Il dottor Sabatini ti ha notato nei corridoi."},
    {"id": "donazione", "testo": "Donare a Sara", "condizione": {"donazione": True},
     "sblocca": [{"contatto": "anselmo"}], "nota": "Padre Anselmo ha saputo cosa hai fatto."},
    {"id": "lchen", "testo": "Tornare in contatto con L'chen", "condizione": {"riuscita": "Riattivare un vecchio contatto della rete criminale"},
     "sblocca": [{"contatto": "shen"}, {"luogo": "magazzino"}], "nota": "Mei Shen terrà il tuo numero."},
    {"id": "bisca", "testo": "Vincere tre volte all'azzardo in una settimana", "condizione": {"successi": {"categorie": ["Azzardo"], "min": 3}},
     "sblocca": [{"contatto": "marisa"}, {"luogo": "bisca"}], "nota": "Alla bisca ricordano la tua faccia."},
    {"id": "rango2", "testo": "Raggiungere il rango più alto di una strada", "condizione": {"rango_qualsiasi": 2},
     "sblocca": [{"luogo": "casa_aste"}], "nota": "Morandi ti manda un invito per le prossime aste."},
]


def testi(o, out):
    if isinstance(o, dict):
        for k, v in o.items():
            if k in ("testo", "risposta", "saluto", "descrizione", "titolo", "nota"):
                out.append(v)
            else:
                testi(v, out)
    elif isinstance(o, list):
        for v in o:
            testi(v, out)


def main() -> int:
    azioni = {a["nome"]: a for a in json.loads((RADICE / "data/azioni.json").read_text(encoding="utf-8"))["azioni"]}
    tracce = {t["traccia"] for t in json.loads((RADICE / "data/tracce.json").read_text(encoding="utf-8"))["tracce_normali"]}
    sottotrame = {s["nome"] for s in json.loads((RADICE / "data/sottotrame.json").read_text(encoding="utf-8"))["sottotrame"]}
    luoghi = {l["id"] for l in LUOGHI}
    contatti = {c["id"] for c in CONTATTI}
    errori = []

    def controlla_effetti(effetti, dove):
        for e in effetti:
            if "azione" in e and e["azione"] not in azioni:
                errori.append(f"{dove}: azione inesistente {e['azione']}")
            if "traccia" in e and e["traccia"] not in tracce:
                errori.append(f"{dove}: traccia inesistente {e['traccia']}")
            for k in ("sottotrama", "pista"):
                if k in e and e[k] not in sottotrame:
                    errori.append(f"{dove}: sottotrama inesistente {e[k]}")
            if "luogo" in e and e["luogo"] not in luoghi:
                errori.append(f"{dove}: luogo inesistente {e['luogo']}")
            if "contatto" in e and e["contatto"] not in contatti:
                errori.append(f"{dove}: contatto inesistente {e['contatto']}")

    raggiungibili = set()
    sotto_eseguibili = set()
    for l in LUOGHI:
        for a in l.get("azioni", []):
            if a not in azioni:
                errori.append(f"luogo {l['id']}: azione inesistente {a}")
            raggiungibili.add(a)
        for s in l.get("sottotrame", []):
            if s not in sottotrame:
                errori.append(f"luogo {l['id']}: sottotrama inesistente {s}")
            sotto_eseguibili.add(s)
        for sp in l.get("speciali", []):
            controlla_effetti(sp.get("effetti", []), f"speciale {sp['id']}")
    for c in CONTATTI:
        for o in c["opzioni"]:
            controlla_effetti(o.get("effetti", []) + o.get("se_riesce", []), f"contatto {c['id']}/{o['id']}")
            for e in o.get("effetti", []):
                if "azione" in e:
                    raggiungibili.add(e["azione"])
    for oc in OCCASIONI:
        for s in oc["scelte"]:
            controlla_effetti(s["effetti"], f"occasione {oc['id']}")
            for e in s["effetti"]:
                if "azione" in e:
                    raggiungibili.add(e["azione"])
    for ob in OBIETTIVI:
        controlla_effetti(ob["sblocca"], f"obiettivo {ob['id']}")

    for nome, a in azioni.items():
        if a["categoria"] != "Evento" and nome not in raggiungibili:
            errori.append(f"azione non raggiungibile: {nome}")
    for s in sottotrame:
        if s not in sotto_eseguibili:
            errori.append(f"sottotrama senza luogo: {s}")

    tutti = []
    testi([LUOGHI, CONTATTI, OCCASIONI, OBIETTIVI, list(MESSAGGI_GIORNALIERI.values())], tutti)
    for t in tutti:
        if "—" in t or "–" in t or "--" in t:
            errori.append(f"trattino lungo: {t}")
        if t.count("!") > 1:
            errori.append(f"troppi punti esclamativi: {t}")
        for v in ("Certamente", "Assolutamente", "Ecco", "Come richiesto", "Nel contesto di"):
            if re.search(r"\b" + v + r"\b", t):
                errori.append(f"frase vietata '{v}': {t}")

    if errori:
        print("\n".join(errori))
        return 1
    dati = {"luoghi": LUOGHI, "contatti": CONTATTI, "occasioni": OCCASIONI,
            "messaggi_giornalieri": MESSAGGI_GIORNALIERI, "obiettivi": OBIETTIVI}
    (RADICE / "data/mondo.json").write_text(json.dumps(dati, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"mondo scritto: {len(LUOGHI)} luoghi, {len(CONTATTI)} contatti, {len(OCCASIONI)} occasioni, "
          f"{len(OBIETTIVI)} obiettivi, {len(raggiungibili)} azioni raggiungibili")
    return 0


if __name__ == "__main__":
    sys.exit(main())
