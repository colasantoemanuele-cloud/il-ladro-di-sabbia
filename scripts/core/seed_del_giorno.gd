class_name SeedDelGiorno
extends RefCounted
## Design doc 12.6: "Un seed fisso condiviso, uguale per tutti i giocatori
## in un dato giorno, con classifica punteggio". Nessun server esiste
## (chiarito dall'autore in questo batch tecnico): qui solo la derivazione
## DETERMINISTICA del seed dalla data corrente e lo storico LOCALE dei
## propri punteggi su quel seed (PlayerProfile.storico_seed_del_giorno,
## per confrontare i propri tentativi) — non una classifica condivisa tra
## giocatori diversi, che richiederebbe un server non esistente.

static func data_di_oggi_stringa() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## String.hash() (djb2) è deterministico per la stessa stringa, su
## qualunque macchina/OS/versione di Godot con la stessa build — non è
## randomizzato per processo come l'hash di stringhe in altri linguaggi.
## Mascherato a 31 bit per garantire un intero non negativo, coerente con
## GameState._init(seed_iniziale) che tratta seed < 0 come "genera un seed
## casuale" invece che come un seed esplicito.
static func seed_da_data(data_str: String) -> int:
	return data_str.hash() & 0x7FFFFFFF


static func seed_di_oggi() -> int:
	return seed_da_data(data_di_oggi_stringa())
