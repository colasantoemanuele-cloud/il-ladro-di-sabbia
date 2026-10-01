class_name App
extends Control
## Punto di ingresso della demo. Con argomenti da riga di comando di test o
## debug (--play, --simulate, --test-*, --ui-legacy) delega a Main, che resta
## invariato. Senza argomenti (caso Android) orchestra titolo, intro e partita.

const FLAG_LEGACY := ["--play", "--ui-legacy"]

var audio: MusicEngine
var impostazioni: ImpostazioniDemo
var profilo: PlayerProfile
var _fader: ColorRect
var _schermata: Control = null
var _seed_cli := -1
var _livello_cli := 0
var _seed_giorno_cli := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var args := OS.get_cmdline_user_args()
	if _deve_delegare(args):
		var main: Node = load("res://scenes/Main.tscn").instantiate()
		add_child(main)
		return
	for a in args:
		if a.begins_with("--seed="):
			_seed_cli = int(a.get_slice("=", 1))
		elif a.begins_with("--difficolta="):
			_livello_cli = int(a.get_slice("=", 1))
		elif a == "--seed-del-giorno":
			_seed_giorno_cli = true

	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	theme = Stile.tema()
	impostazioni = ImpostazioniDemo.carica()
	profilo = PlayerProfile.load()
	audio = MusicEngine.new()
	audio.volume_master = impostazioni.volume_master
	audio.volume_musica = impostazioni.volume_musica
	audio.volume_effetti = impostazioni.volume_effetti
	add_child(audio)

	var strato := CanvasLayer.new()
	strato.layer = 100
	add_child(strato)
	_fader = ColorRect.new()
	_fader.color = Color.BLACK
	_fader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fader.modulate.a = 0.0
	strato.add_child(_fader)

	if args.has("--demo-test"):
		await DemoTest.esegui(self)
		get_tree().quit()
		return
	if args.has("--demo-foto"):
		var cartella := "/tmp"
		for a in args:
			if a.begins_with("--out="):
				cartella = a.get_slice("=", 1)
		await DemoTest.foto(self, cartella)
		get_tree().quit()
		return
	_mostra_titolo(false)


func _deve_delegare(args: PackedStringArray) -> bool:
	if args.has("--demo-test") or args.has("--demo-foto"):
		return false
	for a in args:
		if a.begins_with("--test-") or a.begins_with("--simulate") or FLAG_LEGACY.has(a):
			return true
	return false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_indietro()
		NOTIFICATION_WM_CLOSE_REQUEST:
			impostazioni.volume_master = audio.volume_master
			impostazioni.volume_musica = audio.volume_musica
			impostazioni.volume_effetti = audio.volume_effetti
			impostazioni.salva()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED:
			AudioServer.set_bus_mute(0, true)
		NOTIFICATION_APPLICATION_RESUMED:
			AudioServer.set_bus_mute(0, false)


func _indietro() -> void:
	if _schermata == null:
		return
	if _schermata is TitleScreen:
		if not _schermata.gestisci_indietro():
			get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	elif _schermata.has_method("gestisci_indietro"):
		_schermata.gestisci_indietro()


## Dissolvenza in nero (0.3s), cambio schermata, dissolvenza inversa.
func _transizione(costruttore: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(_fader, "modulate:a", 1.0, 0.3)
	await tw.finished
	if _schermata != null:
		_schermata.queue_free()
		_schermata = null
	_schermata = costruttore.call()
	var tw2 := create_tween()
	tw2.tween_property(_fader, "modulate:a", 0.0, 0.3)


func _mostra_titolo(con_transizione: bool = true) -> void:
	var crea := func() -> Control:
		profilo = PlayerProfile.load()
		var t := TitleScreen.new()
		add_child(t)
		move_child(t, 1)
		t.avvia(profilo, impostazioni, audio)
		t.nuova_partita.connect(func(): _inizia(false))
		t.seed_del_giorno.connect(func(): _inizia(true))
		audio.suona_musica("titolo")
		return t
	if con_transizione:
		_transizione(crea)
	else:
		_schermata = crea.call()


func _inizia(usa_seed_giorno: bool) -> void:
	if not impostazioni.intro_vista:
		_transizione(func() -> Control:
			var intro := IntroScreen.new()
			add_child(intro)
			move_child(intro, 1)
			intro.avvia(audio)
			intro.finita.connect(func():
				impostazioni.intro_vista = true
				impostazioni.salva()
				_avvia_partita(usa_seed_giorno))
			return intro)
	else:
		_avvia_partita(usa_seed_giorno)


func _livello_effettivo() -> int:
	var richiesto := maxi(_livello_cli, impostazioni.livello_scelto)
	if richiesto <= 0 or not profilo.traguardo_100_100_raggiunto:
		return 0
	return richiesto


func crea_stato(usa_seed_giorno: bool) -> GameState:
	var seme := _seed_cli
	if usa_seed_giorno or _seed_giorno_cli:
		seme = SeedDelGiorno.seed_di_oggi()
	var stato := GameState.new(seme, _livello_effettivo())
	var contatti: Array[String] = []
	for id in profilo.rete_contatti_sbloccati:
		contatti.append(str(id))
	stato.contatti_attivi = contatti
	return stato


func _avvia_partita(usa_seed_giorno: bool) -> void:
	_transizione(func() -> Control:
		profilo = PlayerProfile.load()
		var ui := TouchUI.new()
		add_child(ui)
		move_child(ui, 1)
		ui.avvia(crea_stato(usa_seed_giorno), profilo, audio, usa_seed_giorno or _seed_giorno_cli)
		ui.torna_al_titolo.connect(_mostra_titolo)
		ui.nuova_partita.connect(func(): _avvia_partita(false))
		return ui)
