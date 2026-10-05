"""Genera data/esplorazione.json: le stanze esplorabili di ogni luogo di
Ledune (oggetti, porte, persone), l'aspetto dei personaggi e i dialoghi di
persona con le quattro categorie di opzioni (fissa, stat, memoria, seed).

Controlla: che ogni azione, giro e grande mossa di data/impero.json sia
raggiungibile da un oggetto nel suo luogo; porte, arrivi e posizioni libere;
nodi dei dialoghi; flag usati e mai impostati; regole editoriali.

Uso: python3 tools/genera_esplorazione.py   (dopo tools/genera_impero.py)
"""
import json
import re
import sys
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RADICE / "tools"))
import genera_impero as imp  # noqa: E402

MAPPA = "@mappa"


def porta(pos, verso, arrivo=None, nome="", richiede=None, scala=False):
    p = {"pos": pos, "verso": verso}
    if scala:
        p["scala"] = True
    if arrivo:
        p["arrivo"] = arrivo
    if nome:
        p["nome"] = nome
    if richiede:
        p["richiede"] = richiede
    return p


def ogg(id_, tipo, pos, dim=(1, 1), nome="", voci=None, esamina="", effetti=None, minigioco=""):
    o = {"id": id_, "tipo": tipo, "pos": list(pos), "dim": list(dim), "nome": nome or id_}
    if voci:
        o["voci"] = voci
    if esamina:
        o["esamina"] = esamina
    if effetti:
        o["effetti"] = effetti
    if minigioco:
        o["minigioco"] = minigioco
    return o


def npc(id_, aspetto, pos, nome, dialogo="", battute=None, contatto=""):
    n = {"id": id_, "aspetto": aspetto, "pos": list(pos), "nome": nome}
    if dialogo:
        n["dialogo"] = dialogo
    if battute:
        n["battute"] = battute
    if contatto:
        n["contatto"] = contatto
    return n


def stanza(id_, nome, tema, w, h, porte, oggetti=(), persone=(), entrata=None, buio=False, musica=""):
    s = {"id": id_, "luogo": id_.split("/")[0], "nome": nome, "tema": tema, "w": w, "h": h,
         "porte": porte, "oggetti": list(oggetti), "npc": list(persone)}
    if entrata:
        s["entrata"] = entrata
    if buio:
        s["buio"] = True
    if musica:
        s["musica"] = musica
    return s


GIRO = lambda g: ["cresci:" + g, "riscuoti:" + g, "luogotenente:" + g]  # noqa: E731

STANZE = [
    # ------------------------------------------------------------ casa
    stanza("casa/soggiorno", "Soggiorno", "casa", 14, 9, [
        porta([7, 8], MAPPA, nome="Uscire in strada"),
        porta([0, 5], "casa/camera", [11, 5], "Camera"),
        porta([13, 5], "casa/cucina", [1, 5], "Cucina"),
    ], [
        ogg("divano", "divano", (2, 3), (3, 1), "Il divano", esamina="Il divano dove Serena si addormentava col libro aperto. Il segno è ancora a pagina novanta."),
        ogg("cornice", "cornice", (7, 1), nome="Una foto", esamina="Serena al mare, tre anni fa. Ride di qualcosa che hai detto tu. Non ricordi cosa."),
        ogg("scrittoio", "scrivania", (10, 2), (2, 1), "Lo scrittoio", voci=["liquida"],
            esamina="Qui tieni i conti. Se un giorno vorrai vendere tutto in una notte, si comincia da questo foglio."),
        ogg("tavolino", "tavolino", (5, 5), (2, 1), "Il tavolino", esamina="Bollette, una ninna nanna stampata da internet, le chiavi di Serena."),
    ], entrata=[7, 7], musica="casa"),
    stanza("casa/camera", "Camera da letto", "casa", 13, 9, [
        porta([12, 5], "casa/soggiorno", [1, 5], "Soggiorno"),
    ], [
        ogg("letto", "letto", (2, 3), (2, 3), "Il letto", voci=["dormi"], esamina="Metà del letto è fredda da tre giorni."),
        ogg("culla", "culla", (7, 3), nome="La culla", esamina="L'hai montata tu, sbagliando due viti. Sara non ci ha ancora dormito."),
        ogg("armadio", "armadio", (9, 2), (2, 1), "L'armadio",
            esamina="Tra i vestiti di Serena c'è il suo portafoglio. Dentro, un santino di Santa Rena consumato agli angoli.",
            effetti=[{"oggetto": "santino"}]),
    ], musica="casa"),
    stanza("casa/cucina", "Cucina", "casa", 12, 9, [
        porta([0, 5], "casa/soggiorno", [12, 5], "Soggiorno"),
    ], [
        ogg("fornello", "fornello", (2, 2), (2, 1), "Il fornello", esamina="Una pentola di sugo che nessuno ha finito. Ormai è da buttare."),
        ogg("tavolo_cucina", "tavolo", (5, 4), (2, 2), "Il tavolo", voci=["mangia"], esamina="Due sedie. Ne basterebbe una."),
        ogg("frigo", "frigo", (9, 2), nome="Il frigorifero", esamina="Un biglietto attaccato con la calamita: «Compra il latte. Ti amo.»"),
    ], musica="casa"),
    # ------------------------------------------------------------ ospedale
    stanza("ospedale/corridoio", "Corridoio del terzo piano", "ospedale", 16, 9, [
        porta([8, 8], MAPPA, nome="Uscire dall'ospedale"),
        porta([8, 1], "ospedale/reparto", [8, 8], "Terapia intensiva neonatale"),
    ], [
        ogg("distributore", "distributore", (13, 2), nome="Il distributore", esamina="Caffè a un minuto di sabbia. Il cartello dice che è un'offerta."),
        ogg("sedie", "sedie", (2, 3), (3, 1), "Le sedie", esamina="Sedie di plastica arancione. Ci hai passato la prima notte."),
    ], [
        npc("infermiera", "infermiera", (5, 5), "Un'infermiera", battute=[
            "Il turno di notte è il più lungo. Anche per i genitori.",
            "Non corra nel corridoio. Qui il tempo passa uguale.",
            "La dottoressa Venti è in reparto. Bussi piano.",
        ]),
    ], entrata=[8, 7], musica="ospedale"),
    stanza("ospedale/reparto", "Terapia intensiva neonatale", "ospedale", 16, 10, [
        porta([8, 9], "ospedale/corridoio", [8, 2], "Corridoio"),
    ], [
        ogg("incubatrice", "incubatrice", (6, 3), (2, 2), "L'incubatrice di Sara", voci=["visita", "dona"],
            esamina="Sara dorme sotto la luce. Un tubicino, un cerotto, una clessidra piccola sul monitor."),
        ogg("lettino", "lettino", (12, 3), (2, 2), "Il letto in fondo", voci=["mossa:ultima_donazione"],
            esamina="Un vecchio dorme con la bocca aperta. Sul comodino, nessun fiore."),
        ogg("monitor", "monitor", (3, 2), nome="Il monitor", esamina="Una linea verde che sale e scende. La guardi finché non ti fa male."),
    ], [
        npc("venti", "venti", (10, 5), "Dott.ssa Ilaria Venti", dialogo="venti", contatto="venti"),
    ], musica="ospedale"),
    # ------------------------------------------------------------ osteria
    stanza("osteria/sala", "Osteria di Rocco", "osteria", 16, 10, [
        porta([8, 9], MAPPA, nome="Uscire"),
    ], [
        ogg("bancone", "bancone", (2, 2), (6, 1), "Il bancone", voci=["lavoretto", "mangia"],
            esamina="Legno segnato dai bicchieri. Rocco ci passa lo straccio anche quando è pulito."),
        ogg("tavolo_uomini", "tavolo", (11, 6), (2, 1), "Il tavolo in fondo", voci=["recluta"],
            esamina="Ragazzi con le mani grandi e niente da fare. Aspettano qualcuno che li paghi."),
        ogg("jukebox", "jukebox", (14, 2), nome="Il jukebox", esamina="Suona sempre la stessa canzone. Nessuno si alza a cambiarla."),
    ], [
        npc("rocco", "rocco", (5, 4), "Rocco Ferrante", dialogo="rocco", contatto="rocco"),
        npc("ubriaco", "ubriaco", (3, 7), "Un ubriaco", dialogo="ubriaco"),
    ], entrata=[8, 8], musica="osteria"),
    # ------------------------------------------------------------ porto
    stanza("porto/banchina", "La banchina", "porto", 18, 10, [
        porta([9, 9], MAPPA, nome="Lasciare il porto"),
    ], [
        ogg("casse", "casse", (3, 3), (3, 2), "Le casse", voci=["turno"] + GIRO("cooperativa"),
            esamina="Casse da spostare, sempre. Il porto non dorme mai abbastanza."),
        ogg("gru", "gru", (13, 2), (3, 2), "La gru", esamina="Ferma da un mese. Dicono che la sabbia per ripararla non c'è."),
        ogg("bitta", "bitta", (9, 3), nome="Una bitta", esamina="Ci leghi lo sguardo al mare. Il mare non restituisce niente."),
    ], [
        npc("gaetano", "gaetano", (7, 5), "Gaetano Ruggiero", dialogo="gaetano", contatto="gaetano"),
        npc("portuale", "portuale", (15, 6), "Un portuale", battute=[
            "Gaetano è uno giusto. Raro, da queste parti.",
            "Se cerchi lavoro, il turno parte quando arrivi.",
            "Le casse col timbro rosso non le tocca nessuno. Sono di L'chen.",
        ]),
    ], entrata=[9, 8], musica="citta"),
    # ------------------------------------------------------------ piazza
    stanza("piazza/mercato", "Piazza del Mercato", "piazza", 18, 10, [
        porta([9, 9], MAPPA, nome="Lasciare la piazza"),
    ], [
        ogg("fontana", "fontana", (8, 4), (2, 2), "La fontana", voci=["mendicare"],
            esamina="Senz'acqua da anni. La gente ci butta lo stesso le monete, per abitudine."),
        ogg("bancarella", "bancarella", (2, 3), (3, 1), "La bancarella", voci=["mangia"],
            esamina="Arancini, olive, pane di ieri a metà prezzo."),
        ogg("botteghe", "botteghe", (13, 2), (4, 1), "Le botteghe", voci=GIRO("protezione"),
            esamina="Un fornaio, un barbiere, una merceria. Ogni negozio paga qualcuno, o pagherà."),
        ogg("folla", "folla", (14, 6), (2, 1), "La folla del mercato", voci=["scippo"],
            esamina="Borse aperte, tasche gonfie, occhi altrove."),
    ], [
        npc("venditore", "venditore", (5, 6), "Un venditore", battute=[
            "Arancini caldi. Due minuti di sabbia, uno se mi fai ridere.",
            "Quelli dell'Aurora passano il venerdì a riscuotere. Tu chi sei?",
            "La fontana una volta funzionava. Anche io.",
        ]),
    ], entrata=[9, 8], musica="citta"),
    # ------------------------------------------------------------ chiesa
    stanza("chiesa/navata", "Santuario di Santa Rena", "chiesa", 14, 12, [
        porta([7, 11], MAPPA, nome="Uscire sul sagrato"),
        porta([13, 4], "chiesa/sagrestia", [1, 4], "Sagrestia"),
    ], [
        ogg("pulpito", "altare", (6, 2), (2, 1), "Il pulpito", voci=GIRO("culto"),
            esamina="Da qui si vede tutta la navata. Da qui si chiede, e si ottiene."),
        ogg("ceri", "ceri", (2, 2), nome="I ceri", esamina="Accendi un cero per Serena. La fiamma trema e poi sta dritta.",
            effetti=[{"karma": 1}]),
        ogg("banchi1", "banchi", (3, 6), (3, 1), "I banchi", esamina="Legno lucido di ginocchia."),
        ogg("banchi2", "banchi", (8, 6), (3, 1), "I banchi", esamina="Una vecchia prega a bassa voce. Prega per le ore di qualcun altro."),
    ], [
        npc("anselmo", "anselmo", (10, 3), "Padre Anselmo", dialogo="anselmo", contatto="anselmo"),
    ], entrata=[7, 10], musica="chiesa"),
    stanza("chiesa/sagrestia", "Sagrestia", "chiesa", 10, 8, [
        porta([0, 4], "chiesa/navata", [12, 4], "Navata"),
    ], [
        ogg("registro_offerte", "registro", (4, 2), (2, 1), "Il registro delle offerte",
            esamina="Due colonne di numeri. Quella delle offerte e quella di quello che arriva in curia. Non tornano.",
            effetti=[{"flag": "conti_parroco"}]),
        ogg("armadio_paramenti", "armadio", (7, 2), (2, 1), "L'armadio dei paramenti",
            esamina="Tra le stole c'è una lanterna a olio. Nessuno qui ne ha bisogno. Laggiù, sotto la città, sì.",
            effetti=[{"oggetto": "lanterna"}]),
    ], musica="chiesa"),
    # ------------------------------------------------------------ questura
    stanza("questura/atrio", "Questura", "questura", 16, 9, [
        porta([8, 8], MAPPA, nome="Uscire"),
    ], [
        ogg("sportello", "sportello", (6, 2), (3, 1), "Lo sportello", voci=["corrompi"],
            esamina="Un vetro opaco, una fessura per i documenti. E per altro."),
        ogg("scrivania_agente", "scrivania", (11, 2), (2, 1), "La scrivania dell'agente", voci=["informatore"],
            esamina="Fascicoli impilati, un posacenere pieno, una foto di bambini."),
        ogg("bacheca", "bacheca", (2, 1), (2, 1), "La bacheca", esamina="Ricercati. Una faccia somiglia alla tua di dieci anni fa."),
    ], [
        npc("lombardi", "agente", (12, 5), "Agente Lombardi", dialogo="lombardi"),
    ], entrata=[8, 7], musica="citta"),
    # ------------------------------------------------------------ stazione
    stanza("stazione/piazzale", "Stazione di servizio", "stazione", 16, 9, [
        porta([8, 8], MAPPA, nome="Ripartire"),
    ], [
        ogg("negozio", "cassa", (10, 2), (3, 1), "La cassa", voci=["rapina", "mangia"],
            esamina="Un ragazzo con le cuffie conta i resti. Dietro di lui, la cassa piena."),
        ogg("pompe", "pompe", (3, 3), (2, 1), "Le pompe", esamina="Neon che ronza. Odore di benzina e di notte lunga."),
    ], [
        npc("benzinaio", "benzinaio", (6, 5), "Il benzinaio", battute=[
            "Il caffè è bruciato, ma è caffè.",
            "Le volanti passano alle tre. Non lo dico per niente.",
        ]),
    ], entrata=[8, 7], musica="citta"),
    # ------------------------------------------------------------ quartiere alto
    stanza("quartiere_alto/via", "Via dei Giardini", "giardini", 18, 10, [
        porta([9, 9], MAPPA, nome="Scendere in città"),
    ], [
        ogg("villetta", "cancello", (3, 2), (3, 1), "Una villetta", voci=["scasso"],
            esamina="Persiane chiuse, posta accumulata. I padroni sono al mare."),
        ogg("palazzo", "palazzo", (12, 1), (4, 2), "Palazzo Sabbiedoro", voci=["mossa:casata"],
            esamina="Lo stemma di una clessidra d'oro, scrostato. I Sabbiedoro stanno crollando da dentro."),
        ogg("siepe", "siepe", (7, 5), (3, 1), "Una siepe", esamina="Potata da qualcuno pagato bene."),
    ], [
        npc("guardia", "guardia", (14, 6), "Una guardia privata", battute=[
            "Circoli. Qui non c'è niente da vedere.",
            "Lei non abita qui. Si vede dalle scarpe.",
        ]),
    ], entrata=[9, 8], musica="citta"),
    # ------------------------------------------------------------ banca
    stanza("banca/salone", "Banca della Sabbia Centrale", "banca", 16, 10, [
        porta([8, 9], MAPPA, nome="Uscire"),
    ], [
        ogg("sportelli", "sportello", (4, 2), (5, 1), "Gli sportelli", esamina="Si deposita sabbia come si deposita la vita. Con un modulo in triplice copia."),
        ogg("caveau", "caveau", (12, 1), (2, 2), "La porta del caveau", voci=["mossa:banca"],
            esamina="Acciaio, ruote dentate, un orologio a tempo. Sotto c'è più sabbia che in tutta Ledune."),
    ], [
        npc("bassi", "bassi", (10, 5), "Ettore Bassi", dialogo="bassi", contatto="bassi"),
        npc("guardia_banca", "guardia", (3, 5), "Una guardia", battute=["Le mani dove posso vederle, prego.", "Orario di chiusura alle sei."]),
    ], entrata=[8, 8], musica="citta"),
    # ------------------------------------------------------------ agenzia
    stanza("agenzia/ufficio", "Agenzia Clessidra", "agenzia", 12, 8, [
        porta([6, 7], MAPPA, nome="Uscire"),
    ], [
        ogg("scrivania_agenzia", "scrivania", (5, 2), (2, 1), "La scrivania", voci=["anni_futuri"],
            esamina="Un contratto già compilato. Manca solo il tuo nome e il tuo futuro."),
        ogg("manifesto", "quadro", (2, 1), nome="Un manifesto", esamina="«Il futuro è adesso.» Sotto, a matita, qualcuno ha scritto: «Il mio no.»"),
    ], [
        npc("impiegata", "impiegata", (8, 4), "L'impiegata", battute=[
            "Gli anni futuri si pagano subito. È il bello del contratto.",
            "Firmi qui, qui e qui. Il resto lo legge dopo.",
        ]),
    ], entrata=[6, 6], musica="citta"),
    # ------------------------------------------------------------ bottega di Nando
    stanza("bottega_nando/negozio", "Bottega di Nando", "bottega", 12, 8, [
        porta([6, 7], MAPPA, nome="Uscire"),
        porta([11, 4], "bottega_nando/retro", [1, 4], "Il retro"),
    ], [
        ogg("teca", "teca", (2, 2), (3, 1), "La teca dei pegni", voci=["fede"],
            esamina="Orologi, fedi, una medaglia al valore. Ogni oggetto è una storia finita male."),
    ], [
        npc("nando", "nando", (7, 3), "Nando", dialogo="nando"),
    ], entrata=[6, 6], musica="osteria"),
    stanza("bottega_nando/retro", "Il retro di Nando", "bottega", 10, 8, [
        porta([0, 4], "bottega_nando/negozio", [10, 4], "Il negozio"),
    ], [
        ogg("registro", "registro", (4, 2), (2, 1), "Il registro dei debitori", voci=GIRO("usura"),
            esamina="Nomi, ore prestate, ore dovute. Una calligrafia minuta e paziente."),
        ogg("scaffali", "scaffale", (7, 2), (2, 1), "Gli scaffali", esamina="Scatole con sopra un nome e una data. Alcune date sono passate da molto."),
    ], musica="osteria"),
    # ------------------------------------------------------------ bisca
    stanza("bisca/sala", "La Bisca del Molo", "bisca", 18, 11, [
        porta([9, 10], MAPPA, nome="Uscire sul molo"),
        porta([17, 5], "bisca/ring", [1, 5], "Il ring"),
        porta([14, 1], "bisca/retro", [5, 6], "La saletta privata",
              richiede=[{"flag": "accesso_retro"}, {"oggetto": "chiave_retro"}]),
    ], [
        ogg("roulette", "roulette", (3, 4), (2, 2), "La roulette", minigioco="roulette",
            esamina="Il croupier ha le mani bianche e gli occhi altrove."),
        ogg("tavolo_verde", "tavolo_verde", (10, 4), (3, 2), "Il tavolo verde", voci=["cresci:bische", "mossa:torneo"],
            esamina="Panno consumato, fiches di osso. Chi siede qui ha già perso qualcosa."),
    ], [
        npc("marisa", "marisa", (7, 3), "Marisa Lo Bianco", dialogo="marisa", contatto="marisa"),
        npc("giocatore", "giocatore", (14, 7), "Un giocatore", battute=[
            "Rosso, sempre rosso. Una volta o l'altra esce.",
            "Ho giocato un anno di mia moglie. Non glielo dica.",
            "Al ring stasera c'è da guadagnare, se sai chi guardare.",
        ]),
    ], entrata=[9, 9], musica="bisca"),
    stanza("bisca/retro", "La saletta privata", "retro", 12, 8, [
        porta([5, 7], "bisca/sala", [14, 2], "La sala"),
    ], [
        ogg("tavolo_privato", "tavolo_verde", (4, 2), (3, 2), "Il tavolo privato", voci=["riscuoti:bische", "luogotenente:bische"],
            esamina="Qui si gioca senza fiches. Si gioca a voce, e la voce vale ore."),
        ogg("cassaforte", "cassaforte", (9, 2), nome="La cassaforte", esamina="Chiusa. Marisa porta la combinazione al collo."),
    ], musica="bisca"),
    stanza("bisca/ring", "Il ring clandestino", "ring", 14, 10, [
        porta([0, 5], "bisca/sala", [16, 5], "La sala"),
    ], [
        ogg("ring", "ring", (5, 3), (4, 4), "Il ring", minigioco="lotte",
            esamina="Corde lise, sangue vecchio sul telo. Si scommette in ore."),
    ], [
        npc("allibratore", "allibratore", (11, 4), "L'allibratore", battute=[
            "Le quote le faccio io. Le sorprese le fa il ring.",
            "Chi punta sul favorito non si diverte mai.",
        ]),
    ], musica="bisca"),
    # ------------------------------------------------------------ magazzino
    stanza("magazzino/deposito", "Magazzino di L'chen", "magazzino", 18, 10, [
        porta([9, 9], MAPPA, nome="Uscire"),
    ], [
        ogg("casse_pesce", "casse", (2, 2), (3, 2), "Le casse di pesce", esamina="Ghiaccio e pesce, sopra. Sotto, altro."),
        ogg("furgone", "furgone", (11, 6), (3, 2), "Il furgone", voci=["furgone"],
            esamina="Un furgone con le targhe cambiate. Aspetta un lavoro grosso."),
        ogg("cassa_guerra", "cassaforte", (15, 2), (2, 1), "La cassa di guerra", voci=["mossa:cassa_guerra"],
            esamina="Una cassa di ferro con il marchio di L'chen. Due uomini la guardano anche quando dormono."),
    ], [
        npc("shen", "shen", (8, 4), "Mei Shen", dialogo="shen", contatto="shen"),
    ], entrata=[9, 8], musica="osteria"),
    # ------------------------------------------------------------ bar Aurora
    stanza("bar_aurora/sala", "Bar Aurora", "bar", 14, 9, [
        porta([7, 8], MAPPA, nome="Uscire"),
    ], [
        ogg("bancone_aurora", "bancone", (2, 2), (5, 1), "Il bancone", voci=["mangia", "tributo"],
            esamina="Il caffè migliore di Ledune. Lo servono a chi conviene."),
        ogg("tavolo_mezzanotte", "tavolo", (10, 3), (2, 1), "Il tavolo in fondo", voci=["mossa:usuraio"],
            esamina="Un uomo in cappotto beve acqua. Aspetta qualcuno con dei debitori da vendere."),
    ], [
        npc("rivale", "rivale", (6, 5), "Uno dell'Aurora", battute=[
            "La piazza è nostra da prima che nascessi.",
            "Bevi e vattene. Oggi siamo gentili.",
        ]),
    ], entrata=[7, 7], musica="osteria"),
    # ------------------------------------------------------------ villa Corradi
    stanza("villa_corradi/giardino", "Villa Corradi", "villa", 16, 10, [
        porta([8, 9], MAPPA, nome="Andarsene"),
    ], [
        ogg("portone", "portone", (7, 1), (2, 2), "Il portone", voci=["mossa:tesoro_boss"],
            esamina="Sigilli della polizia, scoloriti. Il vecchio boss di L'chen diceva che la casa era più sicura di una banca."),
        ogg("fontana_secca", "fontana", (3, 4), (2, 2), "La fontana", esamina="Foglie marce e una statua senza testa."),
    ], entrata=[8, 8], musica="cripta"),
    # ------------------------------------------------------------ casa d'aste
    stanza("casa_aste/sala", "Casa d'aste Morandi", "aste", 14, 10, [
        porta([7, 9], MAPPA, nome="Uscire"),
    ], [
        ogg("podio", "podio", (6, 1), (2, 2), "Il podio del banditore", voci=["mossa:asta"],
            esamina="Un martelletto d'avorio. Batte secoli come se fossero sedie."),
        ogg("sedie_aste", "sedie", (3, 5), (8, 1), "Le sedie", esamina="Velluto rosso. Chi siede qui ha più tempo di quanto possa spendere."),
    ], [
        npc("morandi", "morandi", (10, 3), "Morandi", battute=[
            "Qui non si chiede da dove viene la sabbia. Si chiede quanta.",
            "Il prossimo lotto è un secolo intero. Rilancio minimo, dieci anni.",
        ]),
    ], entrata=[7, 8], musica="chiesa"),
    # ------------------------------------------------------------ cripta degli Eterni
    stanza("catacombe/ingresso", "La Cripta: ingresso", "cripta", 12, 9, [
        porta([6, 8], MAPPA, nome="Risalire in città"),
        porta([10, 3], "catacombe/ossario", [2, 3], "Scendere", scala=True),
    ], [
        ogg("candele", "candele", (3, 2), (2, 1), "Le candele", esamina="Qualcuno le accende ogni notte. Nessuno sa chi."),
        ogg("iscrizione", "lapide", (6, 1), nome="Un'iscrizione", esamina="Lettere più vecchie del latino. Una sola parola leggibile: ETERNI."),
    ], buio=True, entrata=[6, 7], musica="cripta"),
    stanza("catacombe/ossario", "La Cripta: ossario", "cripta", 16, 10, [
        porta([1, 2], "catacombe/ingresso", [9, 3], "Risalire", scala=True),
        porta([14, 8], "catacombe/santuario", [2, 8], "Scendere ancora", richiede=[{"oggetto": "lanterna"}], scala=True),
    ], [
        ogg("teschi", "ossa", (5, 1), (6, 1), "La parete di teschi", esamina="Migliaia di teschi in file ordinate. Tutti girati verso il basso, come se ascoltassero."),
        ogg("nicchia", "lapide", (11, 4), nome="Una nicchia", esamina="Dentro, un foglio di sabbia pressata. Al tatto è calda."),
    ], [
        npc("custode", "custode", (8, 6), "Il custode", dialogo="custode"),
    ], buio=True, musica="cripta"),
    stanza("catacombe/santuario", "La Cripta: santuario", "cripta", 14, 11, [
        porta([1, 9], "catacombe/ossario", [13, 8], "Risalire", scala=True),
    ], [
        ogg("altare_rituale", "altare_rituale", (6, 3), (2, 2), "L'altare", voci=["mossa:cripta"],
            esamina="Pietra nera con una conca al centro. Il fondo della conca è pieno di sabbia che non cade."),
        ogg("sarcofago", "sarcofago", (10, 2), (2, 1), "Il sarcofago",
            esamina="Un sacerdote scolpito con le mani aperte. Sotto le mani, una scritta: «Prendemmo senza chiedere.»",
            effetti=[{"flag": "frammento_eterni"}]),
    ], buio=True, musica="cripta"),
]


# Aspetto dei personaggi: sprite in mappa e ritratto nei dialoghi.
ASPETTI = {
    "sirio": {"pelle": "d9b98f", "capelli": "2a2018", "stile": "corti", "vestito": "23233f", "vestito2": "3a3a60", "cappello": "1a1a28", "barba": True},
    "rocco": {"pelle": "c99a70", "capelli": "000000", "stile": "calvo", "vestito": "e8e0d0", "vestito2": "6a4a30", "barba": True, "corpulento": True},
    "gaetano": {"pelle": "b8865a", "capelli": "5a5a5a", "stile": "corti", "vestito": "3a5a8a", "vestito2": "2a3a5a", "cappello": "c0a040", "baffi": True},
    "venti": {"pelle": "e8c8a8", "capelli": "3a2a20", "stile": "chignon", "vestito": "f0f0f0", "vestito2": "8fb0c8", "occhiali": True},
    "nando": {"pelle": "d0b090", "capelli": "c8c8c8", "stile": "radi", "vestito": "6a5a40", "vestito2": "4a3a28", "occhiali": True},
    "marisa": {"pelle": "e0b898", "capelli": "101010", "stile": "caschetto", "vestito": "a02030", "vestito2": "601020", "rossetto": True},
    "shen": {"pelle": "e0c0a0", "capelli": "0a0a0a", "stile": "lunghi", "vestito": "151515", "vestito2": "e94560"},
    "anselmo": {"pelle": "d8b090", "capelli": "b0b0b0", "stile": "radi", "vestito": "151520", "vestito2": "e8e8e8"},
    "bassi": {"pelle": "e0c8b0", "capelli": "4a3a2a", "stile": "riporto", "vestito": "4a4a5a", "vestito2": "8a2020", "baffi": True},
    "agente": {"pelle": "c8a080", "capelli": "2a2a2a", "stile": "corti", "vestito": "2a3a6a", "vestito2": "c8a040", "cappello": "1a2a5a"},
    "ubriaco": {"pelle": "d0a080", "capelli": "6a5040", "stile": "spettinati", "vestito": "5a4a3a", "vestito2": "3a2a1a", "barba": True},
    "custode": {"pelle": "a89880", "capelli": "e0e0e0", "stile": "cappuccio", "vestito": "2a2a2a", "vestito2": "4a3a2a"},
    "infermiera": {"pelle": "e0c0a0", "capelli": "8a5a30", "stile": "chignon", "vestito": "a0d0c0", "vestito2": "f0f0f0"},
    "portuale": {"pelle": "a07050", "capelli": "1a1a1a", "stile": "corti", "vestito": "c06030", "vestito2": "3a3a3a", "cappello": "3a3a3a"},
    "venditore": {"pelle": "c89060", "capelli": "3a2a1a", "stile": "corti", "vestito": "e8e8e8", "vestito2": "c03030", "baffi": True},
    "benzinaio": {"pelle": "d0a880", "capelli": "5a3a20", "stile": "spettinati", "vestito": "3a6a3a", "vestito2": "f0c050"},
    "guardia": {"pelle": "c0a080", "capelli": "1a1a1a", "stile": "corti", "vestito": "1a1a1a", "vestito2": "5a5a6e", "occhiali": True},
    "impiegata": {"pelle": "e8d0b8", "capelli": "c8a050", "stile": "caschetto", "vestito": "a050c0", "vestito2": "f0f0f0", "occhiali": True},
    "giocatore": {"pelle": "d8b090", "capelli": "2a2a2a", "stile": "riporto", "vestito": "6a2a2a", "vestito2": "c8a97e"},
    "allibratore": {"pelle": "c8a078", "capelli": "1a1a1a", "stile": "calvo", "vestito": "3a3a2a", "vestito2": "f0c050", "corpulento": True},
    "rivale": {"pelle": "d0a880", "capelli": "0a0a0a", "stile": "corti", "vestito": "e8e8e8", "vestito2": "1a1a1a", "occhiali": True},
    "morandi": {"pelle": "e0c8b0", "capelli": "f0f0f0", "stile": "radi", "vestito": "2a1a3a", "vestito2": "c8a040", "baffi": True},
    "volpe": {"pelle": "e08030", "capelli": "f0f0f0", "stile": "volpe", "vestito": "1a1a2e", "vestito2": "e94560"},
}


def o(id_, testo, risposta="", categoria="fissa", minuti=4, vai=None, effetti=None, condizione=None,
      requisito=None, espressione="neutro", sirio="neutro", ripetibile=False, costo=None):
    r = {"id": id_, "testo": testo, "categoria": categoria, "minuti": minuti, "espressione": espressione, "sirio": sirio}
    if risposta:
        r["risposta"] = risposta
    if vai:
        r["vai"] = vai
    if effetti:
        r["effetti"] = effetti
    if condizione:
        r["condizione"] = condizione
    if requisito:
        r["requisito"] = requisito
    if ripetibile:
        r["ripetibile"] = True
    if costo is not None:
        r["costo"] = costo
    return r


VADO = lambda: o("vado", "Niente. Vado.", vai="fine", minuti=0, ripetibile=True)  # noqa: E731


def nodo(testo, opzioni, espressione="neutro", telefono=False, seed=()):
    n = {"testo": testo, "espressione": espressione, "opzioni": opzioni + [VADO()]}
    if telefono:
        n["telefono"] = True
    if seed:
        n["seed"] = list(seed)
    return n


DIALOGHI = {
    "rocco": {
        "contatto": "rocco", "inizio": "inizio",
        "nodi": {
            "inizio": nodo("Rocco asciuga un bicchiere che è già asciutto. «Sei vivo. Me ne compiaccio, mi devi quaranta ore.»", [
                o("rate", "Le rate le pago quando posso.", "Rocco posa il bicchiere. Ti guarda a lungo. «Va bene. Una rata te la scordo. Una.»",
                  "stat", requisito={"stat": ["freddezza", 3]}, effetti=[{"condona": 1}], espressione="arrabbiato", sirio="duro"),
                o("serena", "Questo santino era di Serena.", "Rocco lo prende tra due dita, come una cosa che scotta. «Al matrimonio ho pianto io e non tu. Le ultime due rate dimenticale.»",
                  "memoria", condizione={"oggetto": "santino"}, effetti=[{"condona": 2}, {"karma": 2}], espressione="triste", sirio="triste", minuti=10),
                o("garante", "Fai sapere a Nando che vengo da parte tua.", "«Gli telefono adesso. Con me alle spalle, Nando ti dà i debitori buoni.»",
                  "fissa", condizione={"giro_aperto": "usura"}, effetti=[{"flag": "rocco_garante"}], espressione="felice"),
            ], telefono=True, seed=["offerta"]),
        },
        "seed": {
            "offerta": [
                o("pistola", "Hai ancora quella cosa sotto il banco?", "«Pulita e oliata. Dodici ore e non l'hai mai vista.»", "seed",
                  costo=12.0, requisito={"sabbia": 14}, effetti=[{"oggetto": "pistola"}], espressione="felice"),
                o("grimaldello", "Mi servono ferri sottili.", "«Un rotolo di grimaldelli, roba di prima. Otto ore.»", "seed",
                  costo=8.0, requisito={"sabbia": 10}, effetti=[{"oggetto": "grimaldello"}]),
                o("cella", "Ti ricordi la cella?", "«Ogni notte. Tu parlavi di lei e io di niente. Adesso parli di tua figlia. È un progresso.»", "seed",
                  effetti=[{"stat": ["carisma", 1]}], espressione="triste", minuti=15),
            ],
        },
    },
    "ubriaco": {
        "inizio": "inizio",
        "nodi": {
            "inizio": nodo("Un uomo con la barba di tre giorni ti fissa il bicchiere vuoto. «Offri tu? Io ho sete e storie.»", [
                o("bere", "Offrirgli da bere.", "Beve tutto d'un fiato. Si avvicina, l'alito pesante.", costo=1.0, requisito={"sabbia": 2}, vai="storia", minuti=10),
            ]),
            "storia": nodo("«Te la dico perché sei gentile. Ma non l'hai sentita da me.»", [], seed=["soffiata"]),
        },
        "seed": {
            "soffiata": [
                o("ring", "Quale storia?", "«Al ring della bisca qualcuno si vende, quasi ogni sera. Guarda chi non suda.»", "seed",
                  effetti=[{"flag": "soffiata_ring"}], vai="fine", espressione="felice"),
                o("bassi", "Quale storia?", "«Quello della banca, Bassi. Gioca forte alla bisca e perde più forte. Deve ore a mezza città.»", "seed",
                  effetti=[{"flag": "debito_bassi"}], vai="fine", espressione="felice"),
                o("lanterna", "Quale storia?", "«Sotto la città c'è una cripta. Al primo livello ci arrivi. Al secondo serve luce, e la luce sta in chiesa.»", "seed",
                  effetti=[{"flag": "voce_cripta"}], vai="fine", espressione="sorpreso"),
            ],
        },
    },
    "gaetano": {
        "contatto": "gaetano", "inizio": "inizio",
        "nodi": {
            "inizio": nodo("Gaetano si toglie il cappello e se lo rimette. «Sirio. Qui si lavora sei ore e si va a casa. Tu cosa cerchi?»", [
                o("operai", "Fammi parlare con gli operai.", "Gli operai ti ascoltano. Alla fine Gaetano annuisce. «Una cooperativa. Tu porti le commesse, io le braccia.»",
                  "stat", requisito={"stat": ["carisma", 3]}, condizione={"giro_chiuso": "cooperativa"},
                  effetti=[{"apri_giro": "cooperativa"}], espressione="sorpreso", sirio="duro", minuti=30),
                o("fiducia", "Tre turni puliti. Ti fidi?", "«Mi fido. Prendi dieci dei miei. Lavorano per la cooperativa da domani.»", "memoria",
                  condizione={"lavori": 3, "giro_aperto": "cooperativa"}, effetti=[{"giro_persone": ["cooperativa", 10]}], espressione="felice"),
            ], telefono=True, seed=["extra"]),
        },
        "seed": {
            "extra": [
                o("doppio", "Hai un turno di notte?", "«Doppio turno, paga doppia. Quattro ore di casse al buio.»", "seed",
                  effetti=[{"sabbia": 9.0}, {"karma": 1}], minuti=240, ripetibile=False),
                o("bolla", "C'è qualche container senza bolla?", "Gaetano guarda il mare. «Uno. Non l'hai sentito da me. E non tornare a chiedere.»", "seed",
                  effetti=[{"sabbia": 18.0}, {"polizia": 8}, {"karma": -2}], minuti=120, espressione="arrabbiato"),
                o("sciopero", "Come va al porto?", "«Parlano di sciopero. Se succede, chi ha una cooperativa comanda il porto per una settimana.»", "seed",
                  effetti=[{"stat": ["intuizione", 1]}], minuti=10),
            ],
        },
    },
    "venti": {
        "contatto": "venti", "inizio": "inizio",
        "nodi": {
            "inizio": nodo("La dottoressa Venti ha le occhiaie di chi non dorme da un turno e mezzo. «Signor Sirio. Ho poco tempo, come tutti qui.»", [
                o("verita", "Lei non mi dice tutto.", "Si toglie gli occhiali. «Il vecchio nel letto in fondo. Senza parenti, con più sabbia di quanta gliene serva. Regala a chi lo fa ridere.»",
                  "stat", requisito={"stat": ["intuizione", 3]}, condizione={"senza_pista": "ultima_donazione"},
                  effetti=[{"pista": "ultima_donazione"}], espressione="sorpreso", sirio="duro"),
                o("braccio", "Posso tenerla in braccio?", "Venti esita, poi apre l'incubatrice. Sara pesa meno di un'arancia. Ti stringe il pollice.",
                  "memoria", condizione={"visite": 3}, effetti=[{"karma": 3}, {"stat": ["carisma", 1]}], espressione="felice", sirio="triste", minuti=20),
            ], telefono=True, seed=["notizia"]),
        },
        "seed": {
            "notizia": [
                o("farmaco", "Le serve qualcosa per Sara?", "«Un farmaco che il reparto non può comprare. Se lo paga lei, a Sara regala mezza giornata.»", "seed",
                  costo=6.0, requisito={"sabbia": 8}, effetti=[{"sara": 12.0}, {"karma": 2}], espressione="triste"),
                o("occhi", "Novità?", "«Ha aperto gli occhi, stamattina. Grigi. Come quelli di sua moglie, dice l'infermiera.»", "seed",
                  effetti=[{"karma": 1}], espressione="felice", sirio="triste"),
                o("donatore", "C'è qualcuno che dona, qui?", "«Una signora del quartiere alto dona ore ai neonati. Una volta l'anno. Quest'anno è passata ieri.»", "seed",
                  effetti=[{"stat": ["intuizione", 1]}]),
            ],
        },
    },
    "nando": {
        "inizio": "inizio",
        "nodi": {
            "inizio": nodo("Nando pulisce una fede con un panno giallo. Non alza gli occhi. «Comprare, vendere, impegnare. Il resto non lo faccio.»", [
                o("presentazione", "Mi manda Rocco.", "Nando sospira. «Rocco manda sempre gente che non torna. Va bene. Il registro è sul retro. Ti do i debitori che pagano.»",
                  "memoria", condizione={"flag": "rocco_garante", "giro_aperto": "usura"}, effetti=[{"giro_persone": ["usura", 6]}], espressione="triste"),
                o("registro", "Il registro lo tengo io, da oggi.", "Nando ti guarda le mani. Poi ti passa la chiave del retro. «Non farli piangere troppo.»",
                  "stat", requisito={"stat": ["freddezza", 3]}, condizione={"giro_aperto": "usura"},
                  effetti=[{"giro_persone": ["usura", 8]}, {"karma": -2}], espressione="triste", sirio="duro"),
                o("chi", "Chi sono i tuoi debitori?", "«Gente che aveva bisogno di un'ora in più. Un'ora oggi costa due domani. È così che va.»",
                  espressione="neutro", vai="inizio"),
            ], seed=["offerta"]),
        },
        "seed": {
            "offerta": [
                o("grimaldelli", "Hai qualcosa di utile?", "«Grimaldelli di un fabbro morto. Sei ore.»", "seed",
                  costo=6.0, requisito={"sabbia": 8}, effetti=[{"oggetto": "grimaldello"}]),
                o("lanterna", "Hai qualcosa di utile?", "«Una lanterna a olio. Chi la impegnò diceva che serviva per scendere sotto la città. Quattro ore.»", "seed",
                  costo=4.0, requisito={"sabbia": 6}, effetti=[{"oggetto": "lanterna"}], espressione="sorpreso"),
                o("orologio", "Ti vendo un orologio.", "Nando lo pesa, lo ascolta, lo posa. «Cinque ore. Non chiedo di chi era.»", "seed",
                  effetti=[{"sabbia": 5.0}, {"karma": -1}]),
            ],
        },
    },
    "marisa": {
        "contatto": "marisa", "inizio": "inizio",
        "nodi": {
            "inizio": nodo("Marisa mescola un mazzo senza guardarlo. «Il fortunato. O lo sfortunato, dipende da come finisce la sera.»", [
                o("banco", "Il banco bara sul tavolo tre.", "Marisa smette di mescolare. Ti fa scivolare in mano una chiave. «La saletta privata. E tu stasera non hai visto niente.»",
                  "stat", requisito={"stat": ["intuizione", 3]}, condizione={"senza_oggetto": "chiave_retro"},
                  effetti=[{"oggetto": "chiave_retro"}], espressione="arrabbiato", sirio="duro"),
                o("ring", "So che al ring qualcuno si vende.", "«Lo sanno tutti quelli che contano. Tu adesso conti. Tieni, e tieni la bocca chiusa.»",
                  "memoria", condizione={"flag": "soffiata_ring"}, effetti=[{"sabbia": 12.0}, {"rivalita": 5}], espressione="sorpreso"),
                o("tre", "Tre vittorie stasera.", "«Ti ho visto. Il capo vuole conoscerti. Da adesso la saletta è aperta anche per te.»",
                  "memoria", condizione={"vittorie_azzardo": 3}, effetti=[{"flag": "accesso_retro"}], espressione="felice"),
            ], telefono=True, seed=["storia"]),
        },
        "seed": {
            "storia": [
                o("chiave", "Quanto costa la saletta?", "«Dieci ore e la chiave è tua. Il resto lo paghi giocando.»", "seed",
                  costo=10.0, requisito={"sabbia": 12}, condizione={"senza_oggetto": "chiave_retro"}, effetti=[{"oggetto": "chiave_retro"}]),
                o("passato", "Perché lavori qui?", "«Mio padre ha giocato la mia infanzia a questo tavolo. Adesso il tavolo lo tengo io.»", "seed",
                  effetti=[{"stat": ["intuizione", 1]}], espressione="triste"),
                o("mano", "Dammi una mano fortunata.", "Marisa ti distribuisce una mano a bassa voce. Vinci, per una volta, senza capire come.", "seed",
                  effetti=[{"sabbia": 8.0}], espressione="felice", minuti=20),
            ],
        },
    },
    "shen": {
        "contatto": "shen", "inizio": "inizio",
        "nodi": {
            "inizio": nodo("Mei Shen non si alza. «Il figliol prodigo. L'chen ha la memoria lunga e la pazienza corta. Parla.»", [
                o("vecchio", "Il vecchio boss era mio amico. Anche tuo.", "Shen ti guarda per la prima volta davvero. «Villa Corradi. Sotto il pavimento. Vai prima che ci vada qualcun altro.»",
                  "stat", requisito={"stat": ["freddezza", 4]}, condizione={"senza_pista": "tesoro_boss"},
                  effetti=[{"pista": "tesoro_boss"}, {"luogo": "villa_corradi"}], espressione="sorpreso", sirio="duro"),
                o("tesoro", "Ho trovato il tesoro del vecchio.", "«Lo so. Lo sa tutta L'chen. Prendi due dei miei. Ti serviranno.»",
                  "memoria", condizione={"flag": "mossa_tesoro_boss"}, effetti=[{"uomini": 2}], espressione="felice"),
            ], telefono=True, seed=["incarico"]),
        },
        "seed": {
            "incarico": [
                o("pacco", "Hai un lavoro per me?", "«Un pacco da consegnare al porto. Non aprirlo. Un'ora e mezza.»", "seed",
                  effetti=[{"sabbia": 15.0}, {"polizia": 5}, {"karma": -1}], minuti=90),
                o("uomo", "Mi serve gente fidata.", "«Uno dei miei cerca un padrone nuovo. Dieci ore, e ti è fedele finché paghi.»", "seed",
                  costo=10.0, requisito={"sabbia": 12}, effetti=[{"uomini": 1}]),
                o("pistola", "Mi servirebbe un ferro.", "Shen apre un cassetto. «Questa non ha storia. Nove ore.»", "seed",
                  costo=9.0, requisito={"sabbia": 11}, condizione={"senza_oggetto": "pistola"}, effetti=[{"oggetto": "pistola"}]),
            ],
        },
    },
    "anselmo": {
        "contatto": "anselmo", "inizio": "inizio",
        "nodi": {
            "inizio": nodo("Padre Anselmo conta monete sul bordo dell'acquasantiera. «Figliolo. Il Signore ascolta. Io anche, ma costo meno.»", [
                o("insieme", "Predichiamo insieme, padre.", "Anselmo ride piano. «Hai la voce giusta. I miei fedeli più devoti ascolteranno te. Metà delle offerte a me.»",
                  "stat", requisito={"stat": ["carisma", 3]}, condizione={"giro_chiuso": "culto"},
                  effetti=[{"apri_giro": "culto"}, {"giro_persone": ["culto", 8]}], espressione="felice", sirio="duro", minuti=20),
                o("conti", "Ho visto il registro delle offerte.", "Il parroco smette di contare. «La curia non deve sapere. Prendi i miei fedeli migliori. E tieni chiuso quel libro.»",
                  "memoria", condizione={"flag": "conti_parroco"}, effetti=[{"apri_giro": "culto"}, {"giro_persone": ["culto", 15]}, {"karma": -2}],
                  espressione="arrabbiato", sirio="duro"),
                o("santino", "Questo santino era di mia moglie.", "Anselmo lo benedice con due dita. «Santa Rena protegge chi aspetta. Portalo quando predichi: la gente sente queste cose.»",
                  "memoria", condizione={"oggetto": "santino"}, effetti=[{"karma": 2}], espressione="triste", sirio="triste"),
            ], telefono=True, seed=["confessione"]),
        },
        "seed": {
            "confessione": [
                o("confessa", "Voglio confessarmi.", "Ti ascolta senza interrompere. «Tre Ave Maria e tre ore per la parrocchia.»", "seed",
                  costo=3.0, requisito={"sabbia": 5}, effetti=[{"karma": 5}], minuti=30, espressione="triste"),
                o("chiesa_vuota", "La chiesa è vuota.", "«Le chiese si riempiono quando la gente ha paura. Dai tempo alla paura.»", "seed",
                  effetti=[{"stat": ["carisma", 1]}]),
                o("cripta_voci", "Cosa c'è sotto la città?", "«Gente che pregava prima di Cristo. Non scendere senza luce, e senza fede.»", "seed",
                  effetti=[{"flag": "voce_cripta"}], espressione="sorpreso"),
            ],
        },
    },
    "bassi": {
        "contatto": "bassi", "inizio": "inizio",
        "nodi": {
            "inizio": nodo("Ettore Bassi si sistema il riporto e controlla che nessuno guardi. «Non qui. Cosa vuole?»", [
                o("amico", "Mi serve un amico in banca.", "Bassi suda. «Morandi. Casa d'aste. Compra e vende secoli. Le scrivo l'indirizzo, poi lei si scorda la mia faccia.»",
                  "stat", requisito={"stat": ["carisma", 4]}, condizione={"senza_pista": "asta"},
                  effetti=[{"pista": "asta"}, {"luogo": "casa_aste"}], espressione="sorpreso", sirio="duro"),
                o("debiti", "So dei suoi debiti alla bisca.", "Bassi diventa grigio. «Martedì e venerdì, alle quattro, cambiano le guardie. Il caveau. Adesso mi lasci in pace.»",
                  "memoria", condizione={"flag": "debito_bassi"}, effetti=[{"pista": "banca"}, {"karma": -3}],
                  espressione="arrabbiato", sirio="duro", minuti=10),
            ], telefono=True, seed=["offerta"]),
        },
        "seed": {
            "offerta": [
                o("prestito", "Mi serve un prestito.", "«Trenta ore subito. Le restituisce in sei rate, come tutti.»", "seed",
                  effetti=[{"sabbia": 30.0}, {"debito": 6}], espressione="neutro"),
                o("consiglio", "Un consiglio da banchiere.", "«Non tenga mai tutta la sabbia nello stesso posto. Nemmeno in sua figlia.»", "seed",
                  effetti=[{"stat": ["intuizione", 1]}], espressione="triste"),
                o("guardie", "Quante guardie ci sono?", "«Quattro di giorno, sei di notte. Perché lo chiede?» Bassi si pente della risposta.", "seed",
                  effetti=[{"flag": "turni_guardie"}], espressione="sorpreso"),
            ],
        },
    },
    "lombardi": {
        "inizio": "inizio",
        "nodi": {
            "inizio": nodo("L'agente Lombardi mastica una penna. «Denuncia, ritiro o confessione? Ho tempo per una sola.»", [
                o("fascicolo", "Quanto costa un fascicolo smarrito?", "Lombardi non risponde. Apre un cassetto, lo richiude più leggero. «Smarrito.»",
                  "stat", requisito={"stat": ["freddezza", 3]}, costo=6.0, effetti=[{"polizia": -15}], espressione="neutro", sirio="duro"),
                o("bassi_info", "Cosa sai di Ettore Bassi?", "«Quello della banca? Ha debiti alla bisca del molo. Il commissario lo sa e aspetta. Ti costa niente, sei dei nostri.»",
                  "memoria", condizione={"flag": "informatore"}, effetti=[{"flag": "debito_bassi"}], espressione="felice"),
                o("retate", "Ci sono retate in vista?", "«Ci sono sempre retate in vista. La domanda è chi c'è dentro.»", ripetibile=True, minuti=3),
            ]),
        },
    },
    "custode": {
        "inizio": "inizio",
        "nodi": {
            "inizio": nodo("Un vecchio incappucciato spazza la polvere da un teschio all'altro. Non ti guarda. «Chi scende chiede sempre la stessa cosa.»", [
                o("eterni", "Chi erano gli Eterni?", "«Sacerdoti, prima di tutto. Volevano prendere la sabbia senza che nessuno la desse. Ci sono riusciti.»",
                  "memoria", condizione={"flag": "frammento_eterni"}, effetti=[{"stat": ["intuizione", 1]}, {"flag": "lore_eterni"}],
                  espressione="triste", minuti=15),
            ], seed=["presagio"]),
        },
        "seed": {
            "presagio": [
                o("mare", "Cosa chiedono?", "«Se è vero degli Uomini del Mare. È vero. Non scendere oltre, se hai qualcuno che aspetta.»", "seed",
                  effetti=[{"flag": "voce_cripta"}], espressione="sorpreso"),
                o("sabbia", "Cosa chiedono?", "«Se la sabbia di qui sotto si può portare via. Si può. Poi però torna, e torna con te.»", "seed",
                  effetti=[{"karma": -1}]),
                o("tempo", "Cosa chiedono?", "«Quanto tempo resta. A te poco. A lei, dipende da te.»", "seed",
                  effetti=[{"stat": ["freddezza", 1]}], espressione="triste"),
            ],
        },
    },
}

TEMI = ["casa", "ospedale", "osteria", "porto", "piazza", "chiesa", "questura", "stazione", "giardini", "banca",
        "agenzia", "bottega", "bisca", "retro", "ring", "magazzino", "bar", "villa", "aste", "cripta"]
MUSICHE = ["casa", "ospedale", "osteria", "citta", "chiesa", "bisca", "cripta"]


def testi(o_, out):
    if isinstance(o_, dict):
        for k, v in o_.items():
            if isinstance(v, str) and k in ("nome", "testo", "risposta", "esamina"):
                out.append(v)
            else:
                testi(v, out)
    elif isinstance(o_, list):
        for v in o_:
            if isinstance(v, str) and len(v) > 15:
                out.append(v)
            else:
                testi(v, out)


def main() -> int:
    errori = []
    luoghi = {l["id"]: l for l in imp.LUOGHI}
    stanze = {s["id"]: s for s in STANZE}
    azioni = {a["id"]: a for a in imp.AZIONI}

    def voce_luogo(v):
        if v in azioni:
            return azioni[v]["luogo"]
        if v.startswith(("cresci:", "riscuoti:", "luogotenente:")):
            return imp.GIRI[v.split(":")[1]]["sede"]
        if v.startswith("mossa:"):
            return imp.MOSSE[v.split(":")[1]]["luogo"]
        return None

    raggiunte = set()
    flag_impostati, flag_usati = {"informatore", "lotte_viste"}, set()
    for m in imp.MOSSE:
        flag_impostati.add("mossa_" + m)
    for s in STANZE:
        if s["luogo"] not in luoghi:
            errori.append(f"{s['id']}: luogo inesistente")
        if s["tema"] not in TEMI:
            errori.append(f"{s['id']}: tema {s['tema']} sconosciuto")
        if s.get("musica") and s["musica"] not in MUSICHE:
            errori.append(f"{s['id']}: musica sconosciuta")
        w, h = s["w"], s["h"]
        occupate = set()

        def interno(x, y):
            return 1 <= x <= w - 2 and 2 <= y <= h - 2

        for ob in s["oggetti"]:
            x, y = ob["pos"]
            dw, dh = ob["dim"]
            for i in range(dw):
                for j in range(dh):
                    if not (1 <= x + i <= w - 2 and 1 <= y + j <= h - 2):
                        errori.append(f"{s['id']}/{ob['id']}: fuori dalla stanza")
                    occupate.add((x + i, y + j))
            for v in ob.get("voci", []):
                lv = voce_luogo(v)
                if v not in ("dona", "mangia") and lv is None:
                    errori.append(f"{s['id']}/{ob['id']}: voce sconosciuta {v}")
                elif lv is not None and lv != s["luogo"]:
                    errori.append(f"{s['id']}/{ob['id']}: {v} appartiene a {lv}")
                if v == "mangia" and "cibo" not in luoghi[s["luogo"]]:
                    errori.append(f"{s['id']}: si mangia dove non c'è cibo")
                if v == "dona" and not luoghi[s["luogo"]].get("dona"):
                    errori.append(f"{s['id']}: si dona fuori dall'ospedale")
                raggiunte.add((s["luogo"], v))
            for e in ob.get("effetti", []):
                if "flag" in e:
                    flag_impostati.add(e["flag"])
        for n in s["npc"]:
            if not interno(*n["pos"]) or tuple(n["pos"]) in occupate:
                errori.append(f"{s['id']}/{n['id']}: posizione non libera")
            occupate.add(tuple(n["pos"]))
            if n["aspetto"] not in ASPETTI:
                errori.append(f"{s['id']}/{n['id']}: aspetto mancante")
            if n.get("dialogo") and n["dialogo"] not in DIALOGHI:
                errori.append(f"{s['id']}/{n['id']}: dialogo mancante")
            if not n.get("dialogo") and not n.get("battute"):
                errori.append(f"{s['id']}/{n['id']}: muto")
        uscite = [p for p in s["porte"] if p["verso"] == MAPPA]
        for p in s["porte"]:
            x, y = p["pos"]
            if p.get("scala"):
                if not interno(x, y) or (x, y) in occupate:
                    errori.append(f"{s['id']}: scala {p['pos']} non libera")
            elif not (x in (0, w - 1) or y in (1, h - 1)):
                errori.append(f"{s['id']}: porta {p['pos']} non sul muro")
            if p["verso"] != MAPPA:
                if p["verso"] not in stanze:
                    errori.append(f"{s['id']}: porta verso {p['verso']} inesistente")
                    continue
                dest = stanze[p["verso"]]
                ax, ay = p.get("arrivo", [0, 0])
                if not (1 <= ax <= dest["w"] - 2 and 2 <= ay <= dest["h"] - 2):
                    errori.append(f"{s['id']}: arrivo {p.get('arrivo')} fuori da {dest['id']}")
                if not any(q["verso"] == s["id"] for q in dest["porte"]):
                    errori.append(f"{s['id']} -> {dest['id']}: manca la porta di ritorno")
            for alt in p.get("richiede", []):
                if "flag" in alt:
                    flag_usati.add(alt["flag"])
        if uscite and "entrata" not in s:
            errori.append(f"{s['id']}: uscita senza entrata")
        if "entrata" in s:
            ex, ey = s["entrata"]
            if not interno(ex, ey) or (ex, ey) in occupate:
                errori.append(f"{s['id']}: entrata non libera")
    for l in luoghi:
        entrate = [s for s in STANZE if s["luogo"] == l and "entrata" in s]
        if len(entrate) != 1:
            errori.append(f"luogo {l}: {len(entrate)} stanze d'ingresso")
    for a in imp.AZIONI:
        if (a["luogo"], a["id"]) not in raggiunte:
            errori.append(f"azione {a['id']}: nessun oggetto a {a['luogo']}")
    for g, d in imp.GIRI.items():
        for v in GIRO(g):
            if (d["sede"], v) not in raggiunte:
                errori.append(f"giro {g}: manca {v} a {d['sede']}")
    for m, d in imp.MOSSE.items():
        if (d["luogo"], "mossa:" + m) not in raggiunte:
            errori.append(f"mossa {m}: nessun oggetto a {d['luogo']}")
    for l in luoghi.values():
        if "cibo" in l and (l["id"], "mangia") not in raggiunte:
            errori.append(f"luogo {l['id']}: cibo senza oggetto")
    if ("ospedale", "dona") not in raggiunte:
        errori.append("nessun oggetto per donare")

    contatti = {c["id"] for c in imp.CONTATTI}
    for npc_id, d in DIALOGHI.items():
        if d.get("contatto") and d["contatto"] not in contatti:
            errori.append(f"dialogo {npc_id}: contatto inesistente")
        tutte = []
        for nid, n in d["nodi"].items():
            tutte += n["opzioni"]
            for pool in n.get("seed", []):
                if pool not in d.get("seed", {}):
                    errori.append(f"dialogo {npc_id}/{nid}: pool {pool} mancante")
        for varianti in d.get("seed", {}).values():
            tutte += varianti
        for op in tutte:
            if op.get("vai") and op["vai"] != "fine" and op["vai"] not in d["nodi"]:
                errori.append(f"dialogo {npc_id}/{op['id']}: nodo {op['vai']} mancante")
            for e in op.get("effetti", []):
                if "flag" in e:
                    flag_impostati.add(e["flag"])
                if "oggetto" in e and e["oggetto"] not in imp.OGGETTI:
                    errori.append(f"dialogo {npc_id}/{op['id']}: oggetto sconosciuto")
                if "pista" in e and e["pista"] not in imp.MOSSE:
                    errori.append(f"dialogo {npc_id}/{op['id']}: pista sconosciuta")
                if "stat" in e and e["stat"][0] not in imp.STAT:
                    errori.append(f"dialogo {npc_id}/{op['id']}: stat sconosciuta")
            for c in (op.get("condizione", {}), op.get("requisito", {})):
                if "flag" in c:
                    flag_usati.add(c["flag"])
                if "stat" in c and c["stat"][0] not in imp.STAT:
                    errori.append(f"dialogo {npc_id}/{op['id']}: stat sconosciuta")
            if op["categoria"] not in ("fissa", "stat", "memoria", "seed"):
                errori.append(f"dialogo {npc_id}/{op['id']}: categoria {op['categoria']}")
            if op["categoria"] == "stat" and "stat" not in op.get("requisito", {}):
                errori.append(f"dialogo {npc_id}/{op['id']}: opzione stat senza soglia")
            if op["categoria"] == "memoria" and not op.get("condizione"):
                errori.append(f"dialogo {npc_id}/{op['id']}: memoria senza condizione")
        categorie = {op["categoria"] for op in tutte}
        if d.get("contatto") or npc_id in ("nando",):
            for c in ("stat", "memoria", "seed"):
                if c not in categorie:
                    errori.append(f"dialogo {npc_id}: manca una opzione {c}")
    for f in flag_usati - flag_impostati:
        errori.append(f"flag {f} usato ma mai impostato")
    for oid in imp.OGGETTI:
        trovato = any(e.get("oggetto") == oid for d in DIALOGHI.values() for n in list(d["nodi"].values())
                      for op in n["opzioni"] for e in op.get("effetti", []))
        trovato = trovato or any(e.get("oggetto") == oid for d in DIALOGHI.values() for v in d.get("seed", {}).values()
                                 for op in v for e in op.get("effetti", []))
        trovato = trovato or any(e.get("oggetto") == oid for s in STANZE for ob in s["oggetti"] for e in ob.get("effetti", []))
        if not trovato:
            errori.append(f"oggetto {oid}: nessuno lo dà")

    tutti = []
    testi([STANZE, DIALOGHI], tutti)
    for t in tutti:
        if "—" in t or "–" in t or "--" in t:
            errori.append(f"trattino lungo: {t}")
        frasi = max(1, len(re.findall(r"[.?!…]", t)))
        if t.count("!") * 3 > frasi + 2:
            errori.append(f"troppi esclamativi: {t}")
        for v in ("Certamente", "Assolutamente", "Ecco", "Come richiesto", "Nel contesto di", "Spero che"):
            if re.search(r"\b" + v + r"\b", t):
                errori.append(f"frase vietata: {t}")
    if errori:
        print("\n".join(errori))
        return 1
    dati = {"stanze": STANZE, "aspetti": ASPETTI, "dialoghi": DIALOGHI}
    (RADICE / "data/esplorazione.json").write_text(json.dumps(dati, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    n_opz = sum(len(n["opzioni"]) for d in DIALOGHI.values() for n in d["nodi"].values())
    n_seed = sum(len(v) for d in DIALOGHI.values() for v in d.get("seed", {}).values())
    print(f"esplorazione scritta: {len(STANZE)} stanze in {len(luoghi)} luoghi, "
          f"{sum(len(s['oggetti']) for s in STANZE)} oggetti, {sum(len(s['npc']) for s in STANZE)} persone, "
          f"{len(DIALOGHI)} dialoghi ({n_opz} opzioni fisse/stat/memoria, {n_seed} varianti da seed)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
