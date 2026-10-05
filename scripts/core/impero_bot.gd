class_name ImperoBot
extends RefCounted
## Giocatore automatico a regole, per il bilanciamento (stesse strategie del
## prototipo tools/prototipo/impero.py). Usa solo l'interfaccia pubblica di
## ImperoState, come farebbe la UI: telefono, luoghi, voci, donazione.

const STRATEGIE := {
	"ladro": {"ordine": [], "crimine": true},
	"onesto": {"ordine": ["cooperativa"], "crimine": false},
	"usuraio": {"ordine": ["usura"], "crimine": true},
	"boss": {"ordine": ["protezione"], "crimine": true},
	"biscazziere": {"ordine": ["bische"], "crimine": true},
	"predicatore": {"ordine": ["culto"], "crimine": true},
	"impero": {"ordine": ["usura", "culto", "protezione"], "tetto": 150.0, "crimine": true},
	"impero_dona_14": {"ordine": ["usura", "culto", "protezione"], "tetto": 150.0, "crimine": true, "dona_giorno": 14},
	"impero_mosse": {"ordine": ["usura", "culto", "protezione"], "tetto": 150.0, "crimine": true, "mosse": true},
}


static var traccia := false


static func _disponibile(s: ImperoState, id: String) -> Dictionary:
	var v := s.voce_per_id(id)
	if v.is_empty() or not v.disponibile:
		return {}
	return v


static func _prova(s: ImperoState, ids: Array) -> Dictionary:
	for id in ids:
		var v := _disponibile(s, id)
		if not v.is_empty():
			return v
	return {}


static func _telefono(s: ImperoState, prof: Dictionary) -> void:
	for st in DialogoSystem.dati().get("stanze", []):
		for n in st.npc:
			if n.has("contatto") and s.luoghi_noti.has(st.luogo):
				s.incontra(n.contatto)
	var fatto := true
	while fatto:
		fatto = false
		for c in s.contatti_visibili():
			for o in s.opzioni_contatto(c.id):
				if o.get("ripetibile", false):
					continue
				var apre := ""
				for e in o.get("effetti", []):
					if e.has("apri_giro"):
						apre = e.apri_giro
				if apre != "" and not prof.ordine.has(apre):
					continue
				s.scegli_opzione(c.id, o.id)
				fatto = true


static func _deve_donare(s: ImperoState, prof: Dictionary) -> bool:
	if s.sara < 130.0:
		return true
	if s.sirio < 4.0 and s.fascia > 8:
		return true
	return prof.has("dona_giorno") and s.giorno() >= int(prof.dona_giorno)


static func scegli(s: ImperoState, prof: Dictionary) -> Dictionary:
	var crim: bool = prof.crimine
	if s.sveglio >= 30.0 and s.sirio > 8.0:
		return _prova(s, ["dormi"])
	if s.sirio < 20.0:
		return _prova(s, ["lavoretto", "scippo", "turno", "mendicare"] if crim else ["turno", "lavoretto", "mendicare"])
	if s.tempo_min - s.ultima_visita >= 60.0 * 60.0:
		return _prova(s, ["visita"])
	if s.polizia > 40.0 and not _disponibile(s, "corrompi").is_empty():
		return _disponibile(s, "corrompi")
	if s.rivalita > 40.0 and not _disponibile(s, "tributo").is_empty():
		return _disponibile(s, "tributo")
	if prof.get("mosse", false):
		for m in s.piste:
			var v := _disponibile(s, "mossa:" + m)
			if not v.is_empty() and v.rischio <= 0.45:
				return v
	for g in prof.ordine:
		var st: Dictionary = s.giri[g]
		if st.controllo < 0.6 and not _disponibile(s, "riscuoti:" + g).is_empty():
			return _disponibile(s, "riscuoti:" + g)
	for g in prof.ordine:
		var st: Dictionary = s.giri[g]
		if st.persone >= 8.0 and not st.luogotenente and s.flusso_lordo() > 12.0:
			var serve := 1 + (1 if g in ["protezione", "bische"] else 0)
			if s.uomini < serve:
				var r := _prova(s, ["recluta", "lavoretto"])
				if not r.is_empty():
					return r
			var lv := _disponibile(s, "luogotenente:" + g)
			if not lv.is_empty() and s.sirio > 28.0:
				return lv
		if g in ["protezione", "bische"]:
			var serve2: float = s.giri.protezione.persone / 25.0 + s.giri.bische.persone / 6.0
			if s.uomini < serve2 and not _disponibile(s, "recluta").is_empty():
				return _disponibile(s, "recluta")
		var cv := _disponibile(s, "cresci:" + g)
		if not cv.is_empty() and s.sirio - s.costo_crescita(g) > 18.0 and (not st.luogotenente or st.persone < float(prof.get("tetto", 1e9))):
			return cv
	if crim and s.uomini >= 4:
		var cg := _prova(s, ["furgone", "rapina"])
		if not cg.is_empty():
			return cg
	if s.polizia > 15.0 and not _disponibile(s, "informatore").is_empty():
		return _disponibile(s, "informatore")
	return _prova(s, ["lavoretto", "scippo", "turno", "mendicare"] if crim else ["turno", "lavoretto", "mendicare"])


## Un passo del bot: telefono, eventuale pasto, una scelta. Restituisce
## false quando decide di donare (o la partita è finita).
static func passo(s: ImperoState, prof: Dictionary, puo_donare: bool = true) -> bool:
	if s.is_over:
		return false
	if not s.patto_in_sospeso.is_empty():
		s.risolvi_patto(false)
	_telefono(s, prof)
	if puo_donare and _deve_donare(s, prof):
		s.dona(maxf(s.sirio * 0.9, 1.0), "ospedale")
		return false
	if s.digiuno >= 18.0:
		var cibo := _prova(s, ["mangia"])
		if not cibo.is_empty():
			s.esegui("mangia", cibo.luogo)
	var v := scegli(s, prof)
	if v.is_empty():
		v = _prova(s, ["mendicare", "dormi"])
	var e := s.esegui(v.id, v.luogo)
	if traccia:
		print("%s %-22s %-14s S=%.0f F=%.0f flusso=%.1f usura=%d uomini=%d pol=%.0f %s" % [s.ora_testo(), v.id, v.luogo, s.sirio, s.sara, s.flusso_lordo(),
			int(s.giri.usura.persone), s.uomini, s.polizia, "ok" if e.risultati.size() > 0 and e.risultati[0].successo else "ko"])
	return not s.is_over


static func gioca(seme: int, nome: String, persistente: ImperoPersistente = null) -> ImperoState:
	var prof: Dictionary = STRATEGIE[nome]
	var s := ImperoState.new(seme, 0, persistente)
	var passi := 0
	while passo(s, prof) and passi < 500:
		passi += 1
	return s


static func report(n: int, seme0: int = 1000) -> String:
	var righe: Array[String] = ["%-16s %9s %8s %8s %9s  %6s %6s %6s" % ["strategia", "Sara anni", "mediana", "max", "flusso", "Sirio+", "Sara+", "dono"]]
	for nome in STRATEGIE:
		var anni: Array[float] = []
		var picchi: Array[float] = []
		var fini := {"sirio": 0, "sara": 0, "dono": 0}
		for i in n:
			var s := gioca(seme0 + i, nome)
			anni.append(s.punteggio().sara_anni if s.fine == "dono" else 0.0)
			picchi.append(s.picco_flusso)
			fini[s.fine if fini.has(s.fine) else "sirio"] += 1
		anni.sort()
		picchi.sort()
		var media := 0.0
		for a in anni:
			media += a
		righe.append("%-16s %9.2f %8.2f %8.2f %9.0f  %5d%% %5d%% %5d%%" % [nome, media / n, anni[n / 2], anni[-1], picchi[n / 2],
			fini.sirio * 100 / n, fini.sara * 100 / n, fini.dono * 100 / n])
	return "\n".join(righe)
