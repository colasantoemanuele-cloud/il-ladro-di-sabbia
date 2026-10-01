class_name TestiDemo
extends RefCounted
## Testi della demo: intro, tutorial, citazioni del titolo. Gli esiti delle
## azioni e i dialoghi stanno in data/impero.json (tools/genera_impero.py).
## Regole editoriali: tono asciutto, nessun trattino lungo, nessun punto
## esclamativo di troppo.

const INTRO := "Mi chiamo Sirio. A Ledune rubavo per chi pagava meglio. Qui il tempo si chiama sabbia, ed è l'unica moneta che nessuno falsifica.\n\n" \
	+ "Serena è morta mettendo al mondo Sara. Per tenere in vita mia figlia ho ceduto quasi tutto. A lei restano tre settimane. A me poche ore e un debito con Rocco.\n\n" \
	+ "La sabbia si cede solo di propria volontà. Allora mi servono persone che me la cedano ogni giorno. Una rete. Un impero piccolo e sporco.\n\n" \
	+ "Poi, una volta sola, donerò a Sara. Non cerco perdono. Cerco ore."

const TUTORIAL := [
	{
		"titolo": "Sei ore alla volta",
		"testo": "Il giorno ha quattro fasce: notte, mattina, pomeriggio, sera. In ogni fascia fai una cosa sola, poi la città gira. Ogni fascia costa sei ore a te e sei a Sara. I colpi ti tengono in vita per un giorno. Solo una rete di persone rende abbastanza.",
	},
	{
		"titolo": "La rete",
		"testo": "Chi conosci decide in quali giri puoi entrare: chiama Rocco. Ogni giro cresce in proporzione a quanto è grande e rende a ogni fascia. Ma scotta: polizia, rivali, scandali. Un luogotenente lo fa crescere senza di te, finché non ti tradisce. Telefonare e mangiare non occupano la fascia.",
	},
	{
		"titolo": "La donazione",
		"testo": "Più aspetti, più la rete rende. Ma Sara ha crisi sempre più spesso, e ogni crisi le toglie ore. Starle vicino le dimezza. Quando decidi, vai in reparto e dona. Anche un'ora. Una volta sola, e la partita finisce.",
	},
]

const CITAZIONI := [
	"Il tempo non si ruba. Si consuma.",
	"Ogni granello è un giorno che qualcuno non vivrà.",
	"In questa città tutti hanno un prezzo. Io ho una scadenza.",
	"La sabbia non chiede da dove viene. Solo dove va.",
	"Mia figlia dorme. Io conto.",
	"Chi ha fretta paga due volte. Chi non ne ha, non esiste.",
	"Il perdono è una moneta che qui non si spende.",
	"Si invecchia in fretta quando si vende il futuro.",
]


static func citazione_casuale() -> String:
	return CITAZIONI[randi() % CITAZIONI.size()]
