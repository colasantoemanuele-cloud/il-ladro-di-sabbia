class_name ContactNetwork
extends RefCounted
## Design doc 12.3: "La progressione permanente tra le run non riguarda
## potenziamenti astratti, ma il network di contatti del protagonista".
##
## Batch tecnico (autore in viaggio): SOLO lo scheletro tecnico, come
## richiesto esplicitamente — struttura dati persistente + meccanismo di
## sblocco/effetto, NESSUN contatto reale. I 3 contatti segnaposto sotto
## sono marcati "[SEGNAPOSTO]" in ogni testo visibile, e i loro
## `bersaglio_effetto` puntano deliberatamente a nomi di azione INESISTENTI
## nel foglio Azioni reale (mai una delle 62 azioni vere) — così il
## meccanismo è agganciato a GameState (vedi applica_azione_con_dado/
## azione_disponibile) senza avere ALCUN effetto sul gioco reale finché
## l'autore non definirà contatti veri con bersagli reali.
##
## Scope ridotto rispetto al design doc 12.3 completo, seguendo la
## descrizione più specifica del task (non l'intera tripartizione
## Amici/Amici di amici/Nemici del design doc): un contatto ha un trigger
## e UNO tra tre effetti — riduzione costo, riduzione rischio, sblocco di
## un'azione altrimenti invisibile. I "Nemici" (rischio ricorrente, nuove
## leve narrative) non sono modellati qui: sono contenuto/design, non
## meccanismo generico.

enum TriggerTipo { SOTTOTRAMA_COMPLETATA, TRACCIA_RANGO_RAGGIUNTO }
enum EffettoTipo { RIDUZIONE_COSTO, RIDUZIONE_RISCHIO, SBLOCCO_AZIONE }


class Contatto:
	extends RefCounted
	var id: String
	var nome: String
	var trigger_tipo: int  ## TriggerTipo
	var trigger_parametro: String  ## nome sottotrama, o "traccia|rango"
	var tipo_effetto: int  ## EffettoTipo
	var bersaglio_effetto: String  ## nome azione a cui si applica l'effetto
	var valore_effetto: float  ## frazione 0-1 per le riduzioni; ignorato per SBLOCCO_AZIONE

	func _init(id_: String, nome_: String, trigger_tipo_: int, trigger_parametro_: String,
			tipo_effetto_: int, bersaglio_effetto_: String, valore_effetto_: float = 0.0) -> void:
		id = id_
		nome = nome_
		trigger_tipo = trigger_tipo_
		trigger_parametro = trigger_parametro_
		tipo_effetto = tipo_effetto_
		bersaglio_effetto = bersaglio_effetto_
		valore_effetto = valore_effetto_


static func get_contatti_segnaposto() -> Array[Contatto]:
	var contatti: Array[Contatto] = []

	contatti.append(Contatto.new(
		"contatto_segnaposto_sottotrama",
		"[SEGNAPOSTO] Amico sbloccato completando una sottotrama",
		TriggerTipo.SOTTOTRAMA_COMPLETATA, "L'ultima donazione",
		EffettoTipo.RIDUZIONE_COSTO, "[SEGNAPOSTO] Azione collegata al contatto sottotrama", 0.20
	))

	contatti.append(Contatto.new(
		"contatto_segnaposto_traccia",
		"[SEGNAPOSTO] Amico sbloccato raggiungendo un rango di traccia",
		TriggerTipo.TRACCIA_RANGO_RAGGIUNTO, "Lavoro|2",
		EffettoTipo.RIDUZIONE_RISCHIO, "[SEGNAPOSTO] Azione collegata al contatto traccia", 0.10
	))

	contatti.append(Contatto.new(
		"contatto_segnaposto_sblocco",
		"[SEGNAPOSTO] Amico di amici che sblocca un'azione nascosta",
		TriggerTipo.TRACCIA_RANGO_RAGGIUNTO, "Criminale|2",
		EffettoTipo.SBLOCCO_AZIONE, "[SEGNAPOSTO] Azione nascosta sbloccata dal contatto"
	))

	return contatti


static func get_contatto(id: String) -> Contatto:
	for c in get_contatti_segnaposto():
		if c.id == id:
			return c
	return null


static func _trigger_soddisfatto(contatto: Contatto, stato: GameState) -> bool:
	match contatto.trigger_tipo:
		TriggerTipo.SOTTOTRAMA_COMPLETATA:
			return stato.azione_completata_con_successo(contatto.trigger_parametro)
		TriggerTipo.TRACCIA_RANGO_RAGGIUNTO:
			var parti := contatto.trigger_parametro.split("|")
			return stato.tracce_raggiunte.get(parti[0], 0) >= int(parti[1])
		_:
			return false


## Da chiamare a fine run: valuta i trigger di tutti i contatti segnaposto
## non ancora sbloccati contro lo stato finale della run, sblocca
## (permanentemente, su `profilo`) quelli soddisfatti. Restituisce gli id
## dei contatti sbloccati ORA (non quelli già sbloccati in precedenza), per
## poterli segnalare al giocatore.
static func valuta_sblocchi(stato: GameState, profilo: PlayerProfile) -> Array[String]:
	var nuovi: Array[String] = []
	for c in get_contatti_segnaposto():
		if profilo.contatto_sbloccato(c.id):
			continue
		if _trigger_soddisfatto(c, stato):
			profilo.sblocca_contatto(c.id)
			nuovi.append(c.id)
	return nuovi


## Aggrega l'effetto dei contatti ATTIVI (sbloccati nel profilo, passati
## come lista di id — GameState.contatti_attivi) su una specifica azione.
## Più contatti con lo stesso bersaglio si sommano (nessun cap qui: non
## previsto da nessun contatto reale ancora, quindi non c'è un caso da
## testare per un cap — se servirà, si aggiungerà quando esisteranno
## contatti reali con bersagli sovrapposti).
static func modificatore_per_azione(nome_azione: String, contatti_attivi: Array[String]) -> Dictionary:
	var riduzione_costo := 0.0
	var riduzione_rischio := 0.0
	var sbloccata_da: String = ""
	for c in get_contatti_segnaposto():
		if c.bersaglio_effetto != nome_azione or not contatti_attivi.has(c.id):
			continue
		match c.tipo_effetto:
			EffettoTipo.RIDUZIONE_COSTO:
				riduzione_costo += c.valore_effetto
			EffettoTipo.RIDUZIONE_RISCHIO:
				riduzione_rischio += c.valore_effetto
			EffettoTipo.SBLOCCO_AZIONE:
				sbloccata_da = c.id
	return {
		"riduzione_costo": clampf(riduzione_costo, 0.0, 1.0),
		"riduzione_rischio": clampf(riduzione_rischio, 0.0, 1.0),
		"sbloccata_da": sbloccata_da,
	}


## True se un'azione con questo nome richiede un contatto per essere
## visibile/disponibile (SBLOCCO_AZIONE) e, in caso, se quel contatto è
## tra quelli attivi. Un'azione SENZA alcun contatto di tipo SBLOCCO_AZIONE
## che la bersagli è sempre disponibile per questo aspetto (comportamento
## di default, invariato per tutte le 62 azioni reali oggi).
static func azione_visibile(nome_azione: String, contatti_attivi: Array[String]) -> bool:
	for c in get_contatti_segnaposto():
		if c.tipo_effetto == EffettoTipo.SBLOCCO_AZIONE and c.bersaglio_effetto == nome_azione:
			return contatti_attivi.has(c.id)
	return true
