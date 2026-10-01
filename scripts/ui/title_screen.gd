class_name TitleScreen
extends Control
## Schermata titolo: skyline notturna a quattro livelli di parallasse,
## titolo, citazione, seed del giorno e menu.

## seme -1 = casuale
signal nuova_partita(seme: int, del_giorno: bool)

var profilo: PlayerProfile
var impostazioni: ImpostazioniDemo
var audio: MusicEngine
var _overlay: Control = null


func avvia(profilo_corrente: PlayerProfile, imp: ImpostazioniDemo, motore_audio: MusicEngine) -> void:
	profilo = profilo_corrente
	impostazioni = imp
	audio = motore_audio
	theme = Stile.tema()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_costruisci()


func _s(nome: String) -> void:
	if audio != null:
		audio.sfx(nome)


func _costruisci() -> void:
	var fondo := ColorRect.new()
	fondo.color = Stile.NERO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var ampiezze := [0.0, 6.0, 12.0, 20.0]
	for i in 4:
		var l := TextureRect.new()
		l.texture = PixelArt.skyline_livello(i)
		l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		l.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.offset_left = -30
		l.offset_right = 30
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		if ampiezze[i] > 0.0:
			var tw := create_tween().set_loops()
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(l, "position:x", -ampiezze[i], 7.0 + i)
			tw.tween_property(l, "position:x", ampiezze[i], 7.0 + i)
		if i == 1:
			var tw2 := create_tween().set_loops()
			tw2.tween_property(l, "modulate:a", 0.78, 1.6)
			tw2.tween_property(l, "modulate:a", 1.0, 1.6)

	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.0)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(velo)

	var colonna := VBoxContainer.new()
	colonna.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	colonna.alignment = BoxContainer.ALIGNMENT_CENTER
	colonna.add_theme_constant_override("separation", 10)
	add_child(colonna)

	colonna.add_child(_spazio(30))
	var titolo := Stile.etichetta("IL LADRO\nDI SABBIA", 76, Stile.SABBIA)
	titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titolo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	titolo.add_theme_constant_override("shadow_offset_x", 5)
	titolo.add_theme_constant_override("shadow_offset_y", 5)
	titolo.add_theme_constant_override("line_spacing", -6)
	colonna.add_child(titolo)

	var sotto := Stile.etichetta("Demo v0.1", 22, Stile.GRIGIO.lightened(0.35))
	sotto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonna.add_child(sotto)

	var citazione := Stile.etichetta("\"%s\"" % TestiDemo.citazione_casuale(), 22, Stile.CHIARO)
	citazione.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	citazione.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	citazione.custom_minimum_size = Vector2(700, 0)
	citazione.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	citazione.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	citazione.add_theme_constant_override("shadow_offset_x", 2)
	citazione.add_theme_constant_override("shadow_offset_y", 2)
	colonna.add_child(citazione)

	colonna.add_child(_spazio(40))
	var nuova := _bottone("NUOVA PARTITA", Stile.ROSSO)
	nuova.pressed.connect(_apri_nuova_partita)
	colonna.add_child(nuova)
	var carica := _bottone("CARICA PROFILO", Stile.GRIGIO)
	carica.pressed.connect(_apri_profilo)
	colonna.add_child(carica)
	colonna.add_child(_spazio(20))

	var seed_label := Stile.etichetta("Seed del giorno %s: %d" % [SeedDelGiorno.data_di_oggi_stringa(), SeedDelGiorno.seed_di_oggi()], 17, Stile.CHIARO)
	seed_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	seed_label.add_theme_constant_override("shadow_offset_x", 2)
	seed_label.add_theme_constant_override("shadow_offset_y", 2)
	seed_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	seed_label.offset_left = 16
	seed_label.offset_top = -40
	seed_label.offset_bottom = -12
	add_child(seed_label)


func _spazio(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _bottone(testo: String, colore: Color) -> Button:
	var b := Button.new()
	b.text = testo
	b.custom_minimum_size = Vector2(480, 80)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 28)
	Stile.applica_bottone(b, colore)
	return b


func _overlay_base(larghezza: float) -> VBoxContainer:
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.85)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	_overlay = fondo
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)
	var pannello := PanelContainer.new()
	pannello.custom_minimum_size = Vector2(larghezza, 0)
	pannello.add_theme_stylebox_override("panel", Stile.box(Color("12122a"), Stile.SABBIA, 4, 22))
	centro.add_child(pannello)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pannello.add_child(v)
	return v


func _chiudi_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


## Nuova partita: seed casuale, seed scritto a mano o seed del giorno.
func _apri_nuova_partita() -> void:
	_s("click")
	if _overlay != null:
		return
	var v := _overlay_base(720)
	v.add_child(Stile.etichetta("NUOVA SETTIMANA", Stile.TITOLI, Stile.SABBIA))
	var casuale := _bottone("SEED CASUALE", Stile.ROSSO)
	casuale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	casuale.pressed.connect(func():
		_s("click")
		_chiudi_overlay()
		nuova_partita.emit(-1, false))
	v.add_child(casuale)
	var giorno := _bottone("SEED DEL GIORNO  %d" % SeedDelGiorno.seed_di_oggi(), Stile.SABBIA)
	giorno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	giorno.add_theme_font_size_override("font_size", 22)
	giorno.pressed.connect(func():
		_s("click")
		_chiudi_overlay()
		nuova_partita.emit(SeedDelGiorno.seed_di_oggi(), true))
	v.add_child(giorno)
	v.add_child(Stile.etichetta("Oppure scrivi un seed per rigiocare una settimana precisa:", 18, Stile.GRIGIO.lightened(0.3)))
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 10)
	v.add_child(riga)
	var campo := LineEdit.new()
	campo.placeholder_text = "Seed (solo numeri)"
	campo.custom_minimum_size = Vector2(0, 80)
	campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campo.add_theme_font_size_override("font_size", 28)
	campo.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	campo.max_length = 10
	riga.add_child(campo)
	var gioca := Button.new()
	gioca.text = "GIOCA"
	gioca.custom_minimum_size = Vector2(180, 80)
	gioca.add_theme_font_size_override("font_size", 26)
	Stile.applica_bottone(gioca, Stile.ROSSO)
	gioca.disabled = true
	campo.text_changed.connect(func(t: String):
		var pulito := ""
		for ch in t:
			if ch >= "0" and ch <= "9":
				pulito += ch
		if pulito != t:
			campo.text = pulito
			campo.caret_column = pulito.length()
		gioca.disabled = pulito == "")
	var avvia_seed := func():
		if campo.text == "":
			return
		_s("click")
		var seme := int(campo.text) & 0x7FFFFFFF
		_chiudi_overlay()
		nuova_partita.emit(seme, false)
	gioca.pressed.connect(avvia_seed)
	campo.text_submitted.connect(func(_t): avvia_seed.call())
	riga.add_child(gioca)
	var indietro := _bottone("INDIETRO", Stile.GRIGIO)
	indietro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	indietro.pressed.connect(func():
		_s("click")
		_chiudi_overlay())
	v.add_child(indietro)


func _apri_profilo() -> void:
	_s("click")
	if _overlay != null:
		return
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.85)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	_overlay = fondo
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)
	var pannello := PanelContainer.new()
	pannello.custom_minimum_size = Vector2(720, 0)
	pannello.add_theme_stylebox_override("panel", Stile.box(Color("12122a"), Stile.SABBIA, 4, 22))
	centro.add_child(pannello)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pannello.add_child(v)

	v.add_child(Stile.etichetta("PROFILO", Stile.TITOLI, Stile.SABBIA))
	var righe := PackedStringArray()
	righe.append("Karma salvato: %.0f" % profilo.karma)
	righe.append("Contatti nella rete: %d" % profilo.rete_contatti_sbloccati.size())
	righe.append("Cento anni a testa raggiunto: %s" % ("sì" if profilo.traguardo_100_100_raggiunto else "no"))
	var oggi := profilo.tentativi_seed_del_giorno()
	if oggi.is_empty():
		righe.append("Seed del giorno: nessun tentativo oggi")
	else:
		var migliore := 0.0
		for t in oggi:
			migliore = maxf(migliore, float(t.get("totale_anni", 0.0)))
		righe.append("Seed del giorno: %d tentativi oggi, migliore %.1f anni" % [oggi.size(), migliore])
	var info := Stile.etichetta("\n".join(righe), 20, Stile.CHIARO)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)

	v.add_child(HSeparator.new())
	if profilo.traguardo_100_100_raggiunto:
		v.add_child(Stile.etichetta("Difficoltà crescente", 22, Stile.SABBIA))
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", 10)
		v.add_child(riga)
		var meno := Button.new()
		meno.text = "-"
		meno.custom_minimum_size = Vector2(96, 96)
		meno.add_theme_font_size_override("font_size", 40)
		var valore := Stile.etichetta(str(impostazioni.livello_scelto), 36, Stile.CHIARO)
		valore.custom_minimum_size = Vector2(120, 0)
		valore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		valore.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var piu := Button.new()
		piu.text = "+"
		piu.custom_minimum_size = Vector2(96, 96)
		piu.add_theme_font_size_override("font_size", 40)
		meno.pressed.connect(func():
			_s("click")
			impostazioni.livello_scelto = maxi(impostazioni.livello_scelto - 1, 0)
			valore.text = str(impostazioni.livello_scelto)
			impostazioni.salva())
		piu.pressed.connect(func():
			_s("click")
			impostazioni.livello_scelto = mini(impostazioni.livello_scelto + 1, 10)
			valore.text = str(impostazioni.livello_scelto)
			impostazioni.salva())
		riga.add_child(meno)
		riga.add_child(valore)
		riga.add_child(piu)
		var nota := Stile.etichetta("Ogni livello toglie 4 ore al padre e aggiunge il 5% al rischio.", 17, Stile.GRIGIO)
		nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(nota)
	else:
		var chiuso := Stile.etichetta("La difficoltà crescente si apre dopo il primo traguardo da cento anni a testa.", 18, Stile.GRIGIO)
		chiuso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(chiuso)

	var indietro := Button.new()
	indietro.text = "INDIETRO"
	indietro.custom_minimum_size = Vector2(0, 96)
	Stile.applica_bottone(indietro, Stile.GRIGIO)
	indietro.pressed.connect(func():
		_s("click")
		fondo.queue_free()
		_overlay = null)
	v.add_child(indietro)


func gestisci_indietro() -> bool:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
		return true
	return false
