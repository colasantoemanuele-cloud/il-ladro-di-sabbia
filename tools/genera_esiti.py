"""Genera data/esiti_azioni.json: messaggi di esito (successo / fallimento)
per azioni, tracce e sottotrame della demo. Tono asciutto, noir, nessun
trattino lungo, massimo 20 parole per messaggio. Rilanciare dopo ogni
modifica ai testi: python3 tools/genera_esiti.py
"""
import json
import re
import sys
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent

AZIONI = {
    "Turno di lavoro onesto (8h, salario mediano)": ("Otto ore di fatica, una paga piccola e pulita.", "Il capoturno ti manda a casa senza paga. Ore buttate."),
    "Turno doppio / straordinario (+25%)": ("Doppio turno finito. Le mani tremano, il conto sale.", "Cedi a metà turno. Ti pagano il minimo e ti guardano storto."),
    "Settimana di lavoro nero con un caporale": ("Il caporale paga in contanti e non fa domande.", "Il caporale sparisce il venerdì con la cassa."),
    "Lavoretto di sicurezza per un vecchio contatto": ("Stai fermo in un corridoio, nessuno passa. Pagato bene.", "Qualcuno passa. Il contatto non ti chiama più."),
    "Consulenza sicurezza per un'azienda": ("Trovi tre falle in una mattina. L'azienda paga e finge di ringraziare.", "Il direttore preferisce un altro nome. La settimana è persa."),
    "Vendere anni futuri a un'agenzia di prestiti-vita": ("Firmi. L'agenzia ti conta anni che non vivrai e te li paga subito.", "L'agenzia rifiuta la firma. Non sei abbastanza malleabile."),
    "Fare da cavia per un esperimento clandestino": ("L'ago entra, le ore escono. Il medico non ti guarda in faccia.", "La cavia sbagliata. Esci con le gambe che non rispondono."),
    "Mendicare in strada": ("Qualche moneta di sabbia nel cappello.", "Nessuno guarda. Un vigile ti sposta."),
    "Rovistare tra i rifiuti in zone ricche": ("Nel bidone di un ricco c'è sempre qualcosa che vale.", "Solo avanzi e un cane che ringhia."),
    "Esibirsi per strada (musica)": ("Suoni, qualcuno si ferma. La sabbia cade nel cappello.", "Strada deserta. Le dita sono fredde."),
    "Vendere oggetti personali (fede nuziale)": ("Il banco dei pegni la pesa in fretta. Serena aveva le dita sottili.", "Il banco non la vuole. Resta al dito, più pesante."),
    "Fingersi malato per elemosina mirata": ("Il trucco regge. Una signora lascia più del dovuto.", "Qualcuno ti riconosce. Vergogna e niente sabbia."),
    "Chiedere aiuto a un vecchio compagno di cella": ("Il vecchio compagno apre la porta. Un pasto e qualche ora in prestito.", "Il compagno non risponde. Ha nuovi amici, o è morto."),
    "Comprare un'arma dal fornitore di fiducia": ("Il fornitore pesa i soldi, non te. L'arma è nel sacchetto.", "Il fornitore ha cambiato numero. Le ore sono perse."),
    "Comprare un giubbotto antiproiettile": ("Pesante, scomodo, utile. Lo indossi sotto il cappotto.", "Il giubbotto è di seconda mano e di taglia sbagliata."),
    "Vendere refurtiva al proprio fence": ("Il fence abbassa il prezzo, tu alzi le spalle. Affare chiuso.", "Il fence dice che la merce scotta. Te la tieni."),
    "Comprare informazioni su un bersaglio d'elite": ("L'informatore ha tutto: orari, abitudini, la porta di servizio.", "Ti vendono informazioni vecchie. Lo capisci troppo tardi."),
    "Vendere una soffiata compromettente a un rivale dell'organizzazione": ("La soffiata passa di mano. Qualcuno, altrove, dorme male stanotte.", "Il rivale sa già tutto. Ora sa anche chi ha parlato."),
    "Comprare documenti falsi di alta qualita'": ("I documenti reggono a ogni controllo. Hai un nome nuovo.", "La carta ha una crepa. Il falsario sparisce."),
    "Noleggiare un furgone blindato per un colpo": ("Chiavi in mano, targa pulita. Il furgone aspetta.", "Il noleggiatore vuole vedere i documenti. Rinunci."),
    "Comprare i piani di sicurezza di una banca": ("Le planimetrie sono vere. Ogni porta ha un orario.", "I piani sono un falso ben fatto. Hai pagato per niente."),
    "Trovi un portafoglio, rintracci il proprietario e ti fai 'ricompensare' con le maniere forti": ("Il proprietario capisce in fretta e ti ringrazia a modo suo.", "L'uomo urla. Scappi senza niente."),
    "Rintracci il proprietario di un portafoglio trovato e glielo restituisci": ("Lo restituisci. L'uomo non sa cosa dire e ti stringe la mano.", "Il proprietario sospetta di te. Ti fai insultare e basta."),
    "Testimoni un crimine di un pezzo grosso, lo ricatti": ("Hai visto, hai la prova, hai un prezzo. Lui paga.", "Il pezzo grosso ti vede per primo."),
    "Un piccolo criminale ti minaccia per strada e ti costringe a cedere sabbia": ("Cedi il minimo e te ne vai a testa bassa.", "Il piccolo criminale ti guarda, ti riconosce e cambia marciapiede."),
    "Un vecchio socio propone un colpo last-minute": ("Il colpo va liscio. Il socio conta, tu non fai domande.", "Il socio aveva già venduto il piano a qualcun altro."),
    "Controllo di polizia a sorpresa": ("Paghi quello che serve e il controllo finisce lì.", "Ti trattengono in questura più del dovuto."),
    "Un'associazione benefica dona sabbia (rara)": ("Una busta anonima, poche ore, nessun nome. Le accetti.", "L'associazione ha chiuso i fondi. Un volontario si scusa."),
    "Un associato a cui avevi affidato sabbia viene minacciato dai rivali e gliela cede": ("L'associato cede tutto ai rivali. Piange, poi ti chiama.", "L'associato resiste alla minaccia. Per oggi la sabbia è al sicuro."),
    "Un boss ti fa un favore avvelenato": ("Il boss ti fa un favore. Sai che prima o poi lo riscuoterà.", "Il favore del boss si rivela una trappola. Esci con le tasche vuote."),
    "Poker in una bisca di quartiere": ("Una mano buona, una faccia di pietra. Il banco paga.", "Il bluff non regge. Il piatto va a un tizio coi baffi."),
    "Slot machine": ("Tre ciliegie. La moneta sputata vale più di quanto hai perso.", "La macchina inghiotte la moneta e suona una musichetta allegra."),
    "Scommesse su combattimenti clandestini": ("Punti sul perdente giusto. Il sangue paga bene.", "Il favorito vince in due riprese. Il tuo biglietto è carta."),
    "Corse clandestine di alto livello": ("La tua macchina taglia il traguardo per prima. L'asfalto fuma.", "Una curva sbagliata, un rottame in più. Perdi la puntata."),
    "Tavolo VIP del boss della malavita": ("Siedi al tavolo del boss e non tremi. Esci più ricco e più osservato.", "Il boss ti guarda perdere con un sorriso paziente."),
    "Lotteria clandestina della sabbia (jackpot raro)": ("Il numero esce. Per un momento il mondo è silenzioso.", "Non sei tu. Quasi mai sei tu."),
    "Piccolo furto (scippo)": ("Una borsa, un vicolo, trenta secondi. Nessuno ha visto.", "La signora urla. Corri finché i polmoni bruciano."),
    "Furto con scasso in un appartamento": ("La serratura cede senza rumore. Esci con quello che luccica.", "Il cane del vicino sa fare il suo mestiere."),
    "Rapina a un negozio": ("Il negoziante svuota la cassa senza dire niente.", "Il negoziante ha un fucile e meno paura di te."),
    "Rapina a un furgone blindato": ("Il furgone si ferma dove deve. Il bottino pesa.", "Il furgone ha una scorta che non ti avevano detto."),
    "Rapina alla Banca della Sabbia Centrale (IL GRANDE COLPO)": ("La Banca della Sabbia Centrale perde il silenzio e una parte dell'oro. Ledune ne parlerà per anni.", "L'allarme parte un minuto prima del previsto. Il piano era buono, la fortuna no."),
    "Minacciare un passante": ("Il passante capisce subito e consegna il minimo.", "Il passante è più grosso di come sembrava."),
    "Rapire l'erede di una famiglia ricca": ("L'erede ha paura e una famiglia che paga in fretta.", "L'erede ha una guardia del corpo che sa leggere le intenzioni."),
    "Colpo pianificato con la vecchia organizzazione": ("L'chen pianifica meglio di chiunque. Il colpo scorre come un orologio.", "Qualcuno dentro L'chen ha cambiato lato. Salta tutto."),
    "Fare da sicario per un contratto d'elite": ("Un solo colpo, nessun testimone. Il committente paga e non ti saluta.", "Il bersaglio non era solo. Esci a mani vuote e con un nome in più sul registro."),
    "Sabotare un concorrente dell'organizzazione": ("Un cavo tagliato, una consegna ritardata. L'organizzazione ringrazia in contanti.", "Il concorrente ti becca. L'organizzazione ti guarda come un debito."),
    "Rubare un'auto (strumentale)": ("L'auto parte al primo tentativo. Serve, non rende.", "Allarme. Torni a piedi."),
    "Estorsione a un piccolo imprenditore (pizzo)": ("L'imprenditore paga in silenzio, guardando la strada.", "L'imprenditore chiama qualcuno più forte di te."),
    "Ricatto a un politico corrotto": ("Il politico firma, poi paga. Ha una famiglia e uno stipendio da proteggere.", "Il politico ha già un avvocato. E un amico in questura."),
    "Comprare un pasto": ("Pane, olio, un pomodoro. Mangi seduto, per una volta.", "Il locale è chiuso. Mangi in piedi, quello che trovi."),
    "Fare benzina": ("Il serbatoio è pieno. La città è lunga.", "La pompa è asciutta. Spingi a mano."),
    "Riposare (dormire)": ("Dormi senza sogni. È l'unico lusso che ti concedi.", "Il sonno non arriva. Conti le ore, e sono quelle di Sara."),
    "Chiedere un favore importante a un vecchio boss": ("Il vecchio boss ascolta e annuisce. Sai che avrà un prezzo.", "Il vecchio boss non ti riceve. Hai dimenticato di portare un regalo."),
    "Corrompere un poliziotto": ("Il poliziotto intasca e dimentica il tuo nome.", "Il poliziotto rifiuta e lo scrive nel rapporto."),
    "Corrompere un giudice per far cadere un'accusa": ("Il giudice trova un cavillo. L'accusa cade come una foglia.", "Il giudice conta male. O finge di contare male."),
    "Fare l'informatore per la polizia (tradimento)": ("Dai un nome. Ti pagano e non ti guardano più negli occhi.", "La polizia sospetta di te quanto del nome che hai dato."),
    "Donare sabbia a un bisognoso": ("Una vecchia ti stringe la mano. Non dici niente.", "Il bisognoso rifiuta. Ha ancora un po' di orgoglio."),
    "Visitare la figlia in ospedale": ("Sara dorme. La guardi finché l'infermiera ti manda via.", "Il reparto è chiuso per il turno. Resti dietro al vetro."),
    "Riattivare un vecchio contatto della rete criminale": ("Il numero risponde. Dall'altra parte, una voce che ricorda.", "Il numero è muto. Sei solo."),
    "Ripagare un vecchio debito d'onore": ("Paghi quello che devi. Il creditore ti guarda come un fantasma.", "Il creditore non vuole soldi. Vuole altro."),
    "Pagare un tributo ai rivali": ("I rivali prendono il tributo e rimandano la vendetta.", "Il tributo non basta. Chiedono il resto con gli interessi."),
    "Mantenere un basso profilo pubblico": ("Un cappello, una strada laterale. Per qualche giorno non esisti.", "Qualcuno ti riconosce al mercato. Il basso profilo è andato."),
}

TRACCE = {
    "Lavoro": ("Ti danno una scrivania e un titolo: {n}. Il lavoro onesto stanca, ma paga.", "La promozione va a un altro. Il tuo nome non sta nel verbale."),
    "Criminale": ("La banda ti riconosce: {n}. Qualcuno abbassa gli occhi, qualcuno ti guarda male.", "I tuoi uomini non ti seguono. Il passo falso lo pagano gli altri."),
    "Politica": ("Il palazzo ti apre una porta laterale: {n}. Qui nessuno dice la verità e tutti la sanno.", "Il tuo favore non basta. Il palazzo si dimentica di te."),
    "Azzardo": ("Il tavolo ti riconosce: {n}. Le carte non mentono, gli altri sì.", "La fortuna cambia faccia. Il tavolo ti restituisce al marciapiede."),
    "Bancaria": ("Un funzionario ti allunga una chiave: {n}. La banca è paziente e ruba più di te.", "Il funzionario si spaventa. Il tuo nome sparisce dai registri."),
    "Religiosa": ("L'incenso e la menzogna reggono: {n}. La gente paga per credere.", "Il fedele sospetta. La chiesa si svuota in una sera."),
    "Occulto": ("La candela si spegne da sola: {n}. Qualcuno, sotto, ride piano.", "Il rito va storto. Gli adepti ti guardano con un silenzio nuovo."),
}

SOTTOTRAME = {
    "Il tesoro del vecchio boss": ("Sotto il pavimento della vecchia casa, il tesoro del boss di L'chen. Pesa più dei ricordi.", "La casa è vuota. Qualcuno è arrivato prima e ti ha lasciato la polvere."),
    "L'asta dei secoli": ("Alzi la mano all'ultimo secondo. Aggiudicato. Un secolo di sabbia cambia padrone.", "Il rilancio arriva da un telefono. Perdi l'asta e il fiato."),
    "L'ultima donazione": ("Un vecchio moribondo ti lascia tutto e ti chiede di non scoprire perché.", "Il vecchio cambia testamento un'ora prima di morire."),
    "Il patto con l'usuraio della mezzanotte": ("Firmi a mezzanotte. L'usuraio non ha ombra. La sabbia arriva.", "L'usuraio legge i tuoi occhi e rifiuta il contratto."),
    "La cripta della setta degli eterni": ("Nella cripta, tra ossa e candele, trovi un frammento che non dovresti toccare.", "La cripta si richiude dietro di te. Esci da un altro corridoio, senza niente."),
    "Il grande torneo dei senza-tempo": ("Vinci l'ultimo incontro. Il pubblico, che non ha più ore da perdere, applaude lo stesso.", "Cadi al terzo turno. Il pubblico ride piano."),
    "Il crollo della casata": ("La casata Sabbiedoro crolla e tu raccogli quello che cade.", "Il crollo travolge anche chi stava vicino. Compreso te."),
    "La fuga dal purgatorio dei debitori": ("Esci dal purgatorio dei debitori con le tasche piene e il debito di un altro.", "Il cancello dei debitori si richiude. Resti dentro un po' più a lungo."),
    "Il tavolo dei senza fondo": ("Siedi al tavolo dove nessuno ha più niente da perdere. Tu perdi meno.", "Al tavolo dei senza fondo, il fondo lo trovi tu."),
    "La cassa di guerra della vecchia organizzazione": ("La cassa di guerra di L'chen si apre con una sola chiave. Hai la chiave.", "La cassa è vuota. L'organizzazione ha speso tutto prima di cadere."),
}


def controlla(testo: str, origine: str) -> list:
    errori = []
    if "—" in testo or "–" in testo or "--" in testo:
        errori.append(f"trattino lungo in {origine}")
    if len(testo.split()) > 20:
        errori.append(f"oltre 20 parole in {origine}: {testo}")
    if testo.count("!") > max(1, len(re.findall(r"[.!?]", testo)) // 3):
        errori.append(f"troppi punti esclamativi in {origine}")
    for vietata in ("Certamente", "Assolutamente", "Ecco", "Come richiesto", "Nel contesto di"):
        if vietata.lower() in testo.lower():
            errori.append(f"frase vietata '{vietata}' in {origine}")
    return errori


def main() -> int:
    azioni_json = json.loads((RADICE / "data" / "azioni.json").read_text(encoding="utf-8"))["azioni"]
    nomi = {a["nome"] for a in azioni_json}
    errori = []
    mancanti = nomi - set(AZIONI)
    extra = set(AZIONI) - nomi
    if mancanti:
        errori.append(f"azioni senza esito: {sorted(mancanti)}")
    if extra:
        errori.append(f"esiti per azioni inesistenti: {sorted(extra)}")
    for gruppo, dati in (("azioni", AZIONI), ("tracce", TRACCE), ("sottotrame", SOTTOTRAME)):
        for chiave, (ok, ko) in dati.items():
            errori += controlla(ok.replace("{n}", "Nome"), f"{gruppo}/{chiave}/ok")
            errori += controlla(ko, f"{gruppo}/{chiave}/ko")
    if errori:
        print("\n".join(errori))
        return 1
    uscita = {g: {k: {"ok": v[0], "ko": v[1]} for k, v in d.items()} for g, d in
              (("azioni", AZIONI), ("tracce", TRACCE), ("sottotrame", SOTTOTRAME))}
    (RADICE / "data" / "esiti_azioni.json").write_text(
        json.dumps(uscita, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"esiti scritti: {len(AZIONI)} azioni, {len(TRACCE)} tracce, {len(SOTTOTRAME)} sottotrame")
    return 0


if __name__ == "__main__":
    sys.exit(main())
