class_name Narrativa
extends RefCounted
## Testi narrativi (design doc sezioni 3.3, 4.5, 9). Solo funzioni statiche
## pure su valori, nessuna dipendenza da scena o da GameState: usabili sia
## dalla UI sia dal loop testuale.

const KARMA_FINALE_PULITO := 20.0
const KARMA_FINALE_SPORCO := -50.0

const INTRO := "A Ledune la sabbia è tutto: il tempo che ti resta, la moneta con cui lo si compra.\n" \
	+ "Sirio ha ceduto quasi tutto il suo per far respirare Sara, nata mentre Serena moriva.\n" \
	+ "Gli restano 24 ore. A Sara, una settimana. Una sola donazione, irreversibile, può ancora cambiare le cose."


static func frase_serena(karma: float) -> String:
	if karma > 50.0:
		return "Non ti giudico più. Guardo solo."
	if karma < -50.0:
		return "L'ho vista in te, oggi. Non voltarti."
	if karma < -10.0:
		return "Certe impronte non si asciugano."
	return "Il vento la muove uguale, qui e là."


static func patto_proposta(prezzo_ore: float) -> String:
	return "Dolce Volpe è già seduta sul bordo del letto di Sara, e non l'hai sentita entrare.\n" \
		+ "«Sei sporco di cose che non si lavano, Sirio. Io posso lavarti. Metà della sabbia che ti resta (%.1fh) e il tuo conto con Serena si riapre. " % prezzo_ore \
		+ "Non lo faccio perché mi serva. Lo faccio perché voglio vedere cosa scegli.» Accetti?"


static func patto_accettato(prezzo_ore: float, karma_ottenuto: float, karma_ora: float) -> String:
	return "Dolce Volpe sorride, o forse no. «Affare fatto.» Perdi %.1fh di Sabbia-Padre; il Karma sale di %.0f (ora %.0f)." % [
		prezzo_ore, karma_ottenuto, karma_ora
	]


static func patto_rifiutato() -> String:
	return "«Peccato», dice Dolce Volpe, e non c'è più. «Mi piacevi quando eri curioso.» Il Karma resta com'è."


## Epilogo mostrato a fine run (design doc 4.5). Solo se la donazione è
## stata fatta E Sara è ancora viva si vede il finale a tre esiti,
## scelto dal Karma finale della run.
static func epilogo(donazione_fatta: bool, figlia_viva: bool, padre_vivo: bool, karma: float) -> String:
	if not figlia_viva:
		return "Sara non ha avuto abbastanza tempo. Ledune continua, come ha sempre fatto."
	if not donazione_fatta:
		if padre_vivo:
			return "Il tempo è finito senza una scelta. Sara crescerà senza sapere cosa Sirio avrebbe potuto darle."
		return "Sirio si spegne prima di poter donare. Sara resta con ciò che ha."
	if karma >= KARMA_FINALE_PULITO:
		return "Sara, adulta, racconta Sirio con un affetto imperfetto ma vero: il padre che ha dato tutto, e ha provato a farlo senza sporcarsi."
	if karma <= KARMA_FINALE_SPORCO:
		return "Sara, adulta, non nomina Sirio. Quando lo fa, lo nomina come si nomina una ferita."
	return "Sara, adulta, parla di Sirio senza sapere bene cosa provare. Ha il suo tempo. Non sa a che prezzo."
