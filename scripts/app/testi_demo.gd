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
		"titolo": "Un minuto è un minuto",
		"testo": "Ogni minuto che passa nel mondo costa un minuto a te e uno a Sara. Camminare, parlare, giocare, viaggiare: tutto si paga. Le cose grosse durano ore. Ogni sei ore la città gira: la tua rete rende, il calore sale, Sara può avere una crisi.",
	},
	{
		"titolo": "Ledune a piedi",
		"testo": "Tocca il pavimento per camminare. Tocca un oggetto o una persona per avvicinarti e agire. I segni gialli sono cose da fare, quelli bianchi persone con qualcosa da dire. Uscendo da un luogo si apre la mappa della città, e il viaggio costa tempo.",
	},
	{
		"titolo": "Le parole",
		"testo": "Nei dialoghi le risposte hanno un colore. Bianche: le solite. Azzurre: chiedono Carisma, Intuizione o Freddezza. Oro: ricordi di questa partita. Viola: occasioni di oggi, diverse a ogni seed. Quando hai deciso, dona a Sara in reparto. Anche un'ora.",
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
