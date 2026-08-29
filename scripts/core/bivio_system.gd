class_name BivioSystem
extends RefCounted
## Design doc 12.2: "A determinati trigger... il gioco presenta 2-3 opzioni
## mutuamente esclusive pescate dal pool disponibile: sceglierne una
## preclude le altre per quella run."
##
## Batch tecnico (autore in viaggio): SOLO il meccanismo generico, come
## richiesto esplicitamente — nessun bivio narrativo reale. I bivi definiti
## qui sotto sono segnaposto (marcati "[SEGNAPOSTO]" in ogni testo visibile
## al giocatore), pensati solo per verificare che pool -> scelta -> effetto
## registrato -> alternative precluse funzioni end-to-end. Il contenuto
## narrativo reale (trigger veri come "dopo l'aggancio alla traccia
## Bancaria", opzioni con tono ed effetti scritti) resta da fare quando
## l'autore tornerà a occuparsi di scrittura/design.
##
## La logica di applicazione/persistenza vive in GameState
## (bivio_disponibile/applica_bivio/opzione_scelta), non qui: questa classe
## contiene solo i DATI (il pool di bivi disponibili), sullo stesso
## principio delle azioni core in ActionDatabase — dati separati dalla
## logica che li applica.

class Opzione:
	extends RefCounted
	var nome: String
	var descrizione: String

	func _init(nome_: String, descrizione_: String) -> void:
		nome = nome_
		descrizione = descrizione_


class Bivio:
	extends RefCounted
	var id: String
	var trigger: String  ## descrizione testuale del trigger (placeholder)
	var opzioni: Array[Opzione]

	func _init(id_: String, trigger_: String, opzioni_: Array[Opzione]) -> void:
		id = id_
		trigger = trigger_
		opzioni = opzioni_


## 3 bivi segnaposto (2-3 opzioni ciascuno, come richiesto), MAI popolati
## con contenuto narrativo reale in questo passaggio.
static func get_bivi_segnaposto() -> Array[Bivio]:
	var bivi: Array[Bivio] = []

	bivi.append(Bivio.new(
		"bivio_inizio_run_segnaposto",
		"[SEGNAPOSTO] Trigger: inizio run",
		[
			Opzione.new("[SEGNAPOSTO] Approccio cauto", "[SEGNAPOSTO] descrizione dell'opzione cauta"),
			Opzione.new("[SEGNAPOSTO] Approccio aggressivo", "[SEGNAPOSTO] descrizione dell'opzione aggressiva"),
		] as Array[Opzione]
	))

	bivi.append(Bivio.new(
		"bivio_aggancio_traccia_segnaposto",
		"[SEGNAPOSTO] Trigger: dopo un aggancio a una traccia",
		[
			Opzione.new("[SEGNAPOSTO] Via rapida (più rischiosa)", "[SEGNAPOSTO] descrizione via rapida"),
			Opzione.new("[SEGNAPOSTO] Via lenta (più sicura)", "[SEGNAPOSTO] descrizione via lenta"),
		] as Array[Opzione]
	))

	bivi.append(Bivio.new(
		"bivio_evento_segnaposto",
		"[SEGNAPOSTO] Trigger: dopo certi eventi",
		[
			Opzione.new("[SEGNAPOSTO] Opzione A", "[SEGNAPOSTO] descrizione A"),
			Opzione.new("[SEGNAPOSTO] Opzione B", "[SEGNAPOSTO] descrizione B"),
			Opzione.new("[SEGNAPOSTO] Opzione C", "[SEGNAPOSTO] descrizione C"),
		] as Array[Opzione]
	))

	return bivi


static func get_bivio(id: String) -> Bivio:
	for b in get_bivi_segnaposto():
		if b.id == id:
			return b
	return null
