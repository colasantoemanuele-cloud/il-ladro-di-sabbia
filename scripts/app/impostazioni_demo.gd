class_name ImpostazioniDemo
extends RefCounted
## Preferenze della demo (intro vista, volumi, livello di difficolta scelto).
## File separato dal Profilo Persistente: quello appartiene alla logica di
## gioco e non va esteso da qui.

const PERCORSO := "user://demo_impostazioni.json"

var intro_vista := false
var volume_master := 1.0
var volume_musica := 0.8
var volume_effetti := 0.9
var livello_scelto := 0


static func carica() -> ImpostazioniDemo:
	var i := ImpostazioniDemo.new()
	var f := FileAccess.open(PERCORSO, FileAccess.READ)
	if f == null:
		return i
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		i.intro_vista = bool(d.get("intro_vista", false))
		i.volume_master = float(d.get("volume_master", 1.0))
		i.volume_musica = float(d.get("volume_musica", 0.8))
		i.volume_effetti = float(d.get("volume_effetti", 0.9))
		i.livello_scelto = int(d.get("livello_scelto", 0))
	return i


func salva() -> void:
	var f := FileAccess.open(PERCORSO, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"intro_vista": intro_vista, "volume_master": volume_master,
		"volume_musica": volume_musica, "volume_effetti": volume_effetti,
		"livello_scelto": livello_scelto,
	}))
