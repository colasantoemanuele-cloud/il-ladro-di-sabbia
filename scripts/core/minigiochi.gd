class_name Minigiochi
extends RefCounted
## Logica pura dei minigiochi della bisca: roulette e lotte clandestine.
## Il tempo passa anche qui: ogni giro di ruota e ogni incontro costano minuti
## a Sirio e a Sara. Tutto pesca dal generatore della partita, quindi lo
## stesso seed dà la stessa serata.

const ROSSI := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const NOMI_LOTTATORI := ["il Toro", "Mani di Pietra", "il Siciliano", "Bruno l'Orso", "il Muto", "Gennaro Due Pugni",
	"lo Svedese", "il Calabrese", "Tonino Ferro", "il Prete", "Ciro la Gru", "il Greco"]
const SEGNI := ["guarda troppo spesso verso il banco", "si tiene il fianco quando crede di non essere visto",
	"ha le nocche fasciate di fresco", "non ha bevuto niente tutta la sera"]


static func colore(numero: int) -> String:
	if numero == 0:
		return "verde"
	return "rosso" if ROSSI.has(numero) else "nero"


static func vince(scelta: String, numero: int) -> bool:
	match scelta:
		"rosso", "nero":
			return colore(numero) == scelta
		"pari":
			return numero != 0 and numero % 2 == 0
		"dispari":
			return numero % 2 == 1
		_:
			return scelta.begins_with("numero:") and int(scelta.split(":")[1]) == numero


static func moltiplicatore(scelta: String) -> float:
	return 36.0 if scelta.begins_with("numero:") else 2.0


## Il croupier lascia intravedere il prossimo numero a chi sa guardare.
## Costa tempo; la lettura è giusta più spesso quanto più alta è l'Intuizione.
static func leggi_croupier(s: ImperoState) -> Dictionary:
	var eventi := s.attendi(15.0)
	var numero := s.casuale_intero(0, 36)
	s.flag["roulette_prossimo"] = numero
	var vero := colore(numero)
	var precisione := 0.6 + 0.08 * (int(s.stat.get("intuizione", 1)) - 3)
	var detto := vero
	if vero != "verde" and s.casuale() > precisione:
		detto = "nero" if vero == "rosso" else "rosso"
	return {"presagio": detto, "eventi": eventi}


static func roulette(s: ImperoState, puntata: float, scelta: String) -> Dictionary:
	if s.is_over:
		return {"rifiutata": true, "motivo": "La partita è finita."}
	if puntata <= 0.0 or puntata >= s.sirio:
		return {"rifiutata": true, "motivo": "Non puoi puntare la vita che ti resta."}
	var numero: int = int(s.flag.get("roulette_prossimo", -1))
	s.flag.erase("roulette_prossimo")
	if numero < 0:
		numero = s.casuale_intero(0, 36)
	s.sirio -= puntata
	var vinto := vince(scelta, numero)
	var guadagno := -puntata
	var note: Array = []
	if vinto:
		s.sirio += puntata * moltiplicatore(scelta)
		guadagno = puntata * (moltiplicatore(scelta) - 1.0)
		s.vittorie_azzardo += 1
		if s.vittorie_azzardo % 3 == 0:
			var st := s.aumenta_stat("intuizione")
			if st != "":
				note.append(st)
	var eventi := s.attendi(float(ImperoState.par().minuti_roulette))
	return {"numero": numero, "colore": colore(numero), "vinto": vinto, "guadagno": guadagno, "eventi": eventi, "note": note}


## L'incontro in programma adesso: dipende dal seed, dal giorno e da quanti
## incontri hai già visto stasera.
static func incontro(s: ImperoState) -> Dictionary:
	var chiave := "lotta/%d/%d" % [s.giorno(), int(s.flag.get("lotte_viste", 0))]
	var a := s.variante(chiave + "/a", NOMI_LOTTATORI.size())
	var b := (a + 1 + s.variante(chiave + "/b", NOMI_LOTTATORI.size() - 1)) % NOMI_LOTTATORI.size()
	var fa := 40 + s.variante(chiave + "/fa", 41)
	var fb := 40 + s.variante(chiave + "/fb", 41)
	var venduto := -1
	if s.variante(chiave + "/venduto", 4) == 0:
		venduto = s.variante(chiave + "/chi", 2)
	var p_a := float(fa) / float(fa + fb)
	return {
		"nomi": [NOMI_LOTTATORI[a], NOMI_LOTTATORI[b]],
		"forza": [fa, fb],
		"quote": [snappedf(0.9 / p_a, 0.1), snappedf(0.9 / (1.0 - p_a), 0.1)],
		"venduto": venduto,
		"segno": SEGNI[s.variante(chiave + "/segno", SEGNI.size())],
	}


## Cosa nota Sirio prima dell'incontro. Con Intuizione 3 o con la soffiata
## giusta (memoria della partita) vede chi si è venduto.
static func indizio(s: ImperoState, inc: Dictionary) -> String:
	var v: int = inc.venduto
	if v < 0:
		if int(s.stat.get("intuizione", 1)) >= 3:
			return "Li guardi scaldarsi. Nessuno dei due sembra fingere."
		return ""
	var nome: String = inc.nomi[v]
	if s.ricordato("soffiata_ring"):
		return "Ti torna in mente la soffiata dell'osteria: stasera %s va giù al terzo round." % nome
	if int(s.stat.get("intuizione", 1)) >= 3:
		return "%s %s. Qualcuno l'ha pagato." % [nome.capitalize(), inc.segno]
	return ""


static func lotta(s: ImperoState, puntata: float, scelta: int) -> Dictionary:
	if s.is_over:
		return {"rifiutata": true, "motivo": "La partita è finita."}
	if puntata <= 0.0 or puntata >= s.sirio:
		return {"rifiutata": true, "motivo": "Non puoi puntare la vita che ti resta."}
	var inc := incontro(s)
	var p_a := float(inc.forza[0]) / float(inc.forza[0] + inc.forza[1])
	if inc.venduto == 0:
		p_a = 0.1
	elif inc.venduto == 1:
		p_a = 0.9
	var vincitore := 0 if s.casuale() < p_a else 1
	var colpi: Array = []
	var vita := [100, 100]
	while vita[1 - vincitore] > 0:
		var chi := vincitore if s.casuale() < 0.62 else 1 - vincitore
		var danno := s.casuale_intero(8, 22)
		if chi != vincitore:
			danno = mini(danno, vita[vincitore] - 5)
			if danno <= 0:
				continue
		vita[1 - chi] = maxi(0, vita[1 - chi] - danno)
		colpi.append([chi, danno])
	s.sirio -= puntata
	var vinto := vincitore == scelta
	var guadagno := -puntata
	if vinto:
		var vincita: float = puntata * float(inc.quote[scelta])
		s.sirio += vincita
		guadagno = vincita - puntata
		s.vittorie_azzardo += 1
	s.flag["lotte_viste"] = int(s.flag.get("lotte_viste", 0)) + 1
	var eventi := s.attendi(float(ImperoState.par().minuti_lotta))
	return {"incontro": inc, "vincitore": vincitore, "vinto": vinto, "guadagno": guadagno, "colpi": colpi, "eventi": eventi}
