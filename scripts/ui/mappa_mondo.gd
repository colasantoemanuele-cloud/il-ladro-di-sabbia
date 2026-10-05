class_name MappaMondo
extends Control
## La mappa di Ledune. Si apre da sola quando Sirio esce da un luogo: si
## sceglie la destinazione tra quelle conosciute, si vede quanto costa il
## viaggio e si parte. Il viaggio stesso lo fa ImperoState; qui c'è solo
## l'animazione del segnaposto che attraversa la città.

signal parti(dest: String)
signal resta

var s: ImperoState
var _area: Control
var _img: TextureRect
var _info: VBoxContainer
var _pin: Dictionary = {}
var _sirio: TextureRect
var _selezionato := ""
var _in_viaggio := false


func avvia(stato: ImperoState) -> void:
	s = stato
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.color = Color("08080f")
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var corpo := HBoxContainer.new()
	corpo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corpo.add_theme_constant_override("separation", 12)
	add_child(corpo)
	_area = Control.new()
	_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_area.clip_contents = true
	corpo.add_child(_area)
	_img = TextureRect.new()
	_img.texture = PixelArt.mappa_ledune()
	_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img.stretch_mode = TextureRect.STRETCH_SCALE
	_area.add_child(_img)
	var titolo := Stile.etichetta("LEDUNE", 26, Stile.SABBIA)
	titolo.position = Vector2(14, 8)
	titolo.add_theme_color_override("font_shadow_color", Color.BLACK)
	titolo.add_theme_constant_override("shadow_offset_x", 2)
	titolo.add_theme_constant_override("shadow_offset_y", 2)
	_area.add_child(titolo)
	var scheda := PanelContainer.new()
	scheda.custom_minimum_size = Vector2(340, 0)
	scheda.add_theme_stylebox_override("panel", Stile.box(Color("12122a"), Stile.GRIGIO, 3, 14))
	corpo.add_child(scheda)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 12)
	scheda.add_child(_info)
	for l in s.luoghi_visibili():
		var nodo := VBoxContainer.new()
		nodo.custom_minimum_size = Vector2(84, 84)
		nodo.add_theme_constant_override("separation", 0)
		var b := TextureButton.new()
		b.texture_normal = PixelArt.pin_luogo(str(l.tipo), l.id == s.luogo)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(84, 52)
		var lid: String = l.id
		b.pressed.connect(func(): seleziona(lid))
		nodo.add_child(b)
		var nome := Stile.etichetta(str(l.nome), 13, Stile.ROSSO if l.id == s.luogo else Stile.CHIARO)
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nome.add_theme_color_override("font_shadow_color", Color.BLACK)
		nome.add_theme_constant_override("shadow_offset_x", 1)
		nome.add_theme_constant_override("shadow_offset_y", 1)
		nome.custom_minimum_size = Vector2(84, 0)
		nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nodo.add_child(nome)
		_area.add_child(nodo)
		_pin[l.id] = nodo
	_sirio = TextureRect.new()
	_sirio.texture = PixelMondo.personaggio("sirio", 0, 0)
	_sirio.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sirio.custom_minimum_size = Vector2(32, 48)
	_sirio.size = Vector2(32, 48)
	_sirio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.add_child(_sirio)
	_area.resized.connect(_disponi)
	_disponi.call_deferred()
	seleziona(s.luogo)


func _geometria() -> Array:
	var dim_area := _area.size
	var scala := minf(dim_area.x / 160.0, dim_area.y / 100.0)
	var dim := Vector2(160, 100) * scala
	return [(dim_area - dim) * 0.5, dim]


func _punto(id: String) -> Vector2:
	var g := _geometria()
	var l := ImperoState.luogo_dati(id)
	return g[0] + Vector2(float(l.pos[0]) / 100.0 * g[1].x, float(l.pos[1]) / 100.0 * g[1].y)


func _disponi() -> void:
	var g := _geometria()
	_img.position = g[0]
	_img.size = g[1]
	for id in _pin:
		_pin[id].position = _punto(id) - Vector2(42, 52)
	if not _in_viaggio:
		_sirio.position = _punto(s.luogo) - Vector2(16, 70)


func seleziona(id: String) -> void:
	if _in_viaggio:
		return
	_selezionato = id
	for c in _info.get_children():
		c.queue_free()
	var l := ImperoState.luogo_dati(id)
	var t := Stile.etichetta(str(l.nome).to_upper(), 24, Stile.SABBIA)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_child(t)
	var d := Stile.etichetta(str(l.descrizione), 18, Stile.CHIARO)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_child(d)
	if id == s.luogo:
		_info.add_child(_nota("Sei qui. Rientrare non costa niente."))
		var b := _bottone("RIENTRA", Stile.SABBIA)
		b.pressed.connect(func(): resta.emit())
		_info.add_child(b)
	else:
		var ore := s.ore_viaggio(id)
		var minuti := int(roundf(ore * 60.0))
		_info.add_child(_nota("Il viaggio dura %dh %02dm. Lo pagano Sirio e Sara, minuto per minuto." % [minuti / 60, minuti % 60]))
		var b := _bottone("VAI", Stile.ROSSO)
		b.pressed.connect(func(): _parti(id))
		_info.add_child(b)
		var r := _bottone("TORNA DENTRO", Stile.GRIGIO)
		r.pressed.connect(func(): resta.emit())
		_info.add_child(r)


func _nota(testo: String) -> Label:
	var l := Stile.etichetta(testo, 17, Stile.GRIGIO.lightened(0.35))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _bottone(testo: String, colore: Color) -> Button:
	var b := Button.new()
	b.text = testo
	b.custom_minimum_size = Vector2(0, 88)
	b.add_theme_font_size_override("font_size", 24)
	Stile.applica_bottone(b, colore)
	return b


func _parti(dest: String) -> void:
	if _in_viaggio:
		return
	_in_viaggio = true
	var da := _punto(s.luogo) - Vector2(16, 70)
	var a := _punto(dest) - Vector2(16, 70)
	var durata := clampf(s.ore_viaggio(dest) * 0.8, 0.6, 1.8)
	var tw := create_tween()
	tw.tween_method(func(k: float):
		_sirio.position = da.lerp(a, k)
		_sirio.texture = PixelMondo.personaggio("sirio", 3 if a.x >= da.x else 2, 1 + int(k * 12.0) % 2), 0.0, 1.0, durata)
	tw.tween_callback(func(): parti.emit(dest))


## Per i test: parte subito verso una destinazione, senza animazione.
func parti_subito(dest: String) -> void:
	parti.emit(dest)
