class_name DialogoUI
extends Control
## Dialogo di persona in stile visual novel: i ritratti di Sirio e
## dell'interlocutore si fronteggiano e cambiano espressione, il testo scorre
## lettera per lettera, sotto ci sono le risposte. Ogni risposta mostra la sua
## categoria (fissa, statistica, ricordo, oggi) e quanti minuti costa.

signal chiuso

const COLORI := {"fissa": Color("e8e8e8"), "stat": Color("6ab0f0"), "memoria": Color("f0c050"), "seed": Color("c090f0")}

var ui
var s: ImperoState
var persona: Dictionary
var _nodo := ""
var _sirio: TextureRect
var _altro: TextureRect
var _nome: Label
var _testo: Label
var _citazione: Label
var _opzioni: VBoxContainer
var _tw: Tween


func avvia(interfaccia, stato: ImperoState, p: Dictionary) -> void:
	ui = interfaccia
	s = stato
	persona = p
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var velo := ColorRect.new()
	velo.color = Color(0.02, 0.02, 0.05, 0.82)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(velo)
	_sirio = _ritratto(true)
	_altro = _ritratto(false)
	var pannello := PanelContainer.new()
	pannello.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	pannello.offset_top = -390
	pannello.offset_left = 16
	pannello.offset_right = -16
	pannello.offset_bottom = -8
	pannello.add_theme_stylebox_override("panel", Stile.box(Color("10101e"), Stile.SABBIA, 4, 16))
	add_child(pannello)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pannello.add_child(v)
	_nome = Stile.etichetta(str(p.nome).to_upper(), 22, Stile.SABBIA)
	v.add_child(_nome)
	_citazione = Stile.etichetta("", 16, Stile.GRIGIO.lightened(0.35))
	_citazione.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_citazione.visible = false
	v.add_child(_citazione)
	_testo = Stile.etichetta("", 20, Stile.CHIARO)
	_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_testo.custom_minimum_size = Vector2(0, 56)
	_testo.mouse_filter = Control.MOUSE_FILTER_STOP
	_testo.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_completa())
	v.add_child(_testo)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_opzioni = VBoxContainer.new()
	_opzioni.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opzioni.add_theme_constant_override("separation", 6)
	sc.add_child(_opzioni)
	_nodo = DialogoSystem.nodo_iniziale(s, persona.dialogo)
	var n := DialogoSystem.nodo(persona.dialogo, _nodo)
	_mostra(str(n.get("testo", "")), str(n.get("espressione", "neutro")), "neutro", "")
	_entrata()


func _ritratto(sinistra: bool) -> TextureRect:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	r.custom_minimum_size = Vector2(240, 240)
	r.size = Vector2(240, 240)
	r.anchor_left = 0.0 if sinistra else 1.0
	r.anchor_right = r.anchor_left
	r.anchor_top = 1.0
	r.anchor_bottom = 1.0
	r.offset_left = 40.0 if sinistra else -280.0
	r.offset_right = r.offset_left + 240.0
	r.offset_top = -628.0
	r.offset_bottom = -392.0
	r.flip_h = not sinistra
	add_child(r)
	return r


func _entrata() -> void:
	for r in [_sirio, _altro]:
		r.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_sirio, "modulate:a", 1.0, 0.25)
	tw.tween_property(_altro, "modulate:a", 1.0, 0.25)


func _mostra(testo: String, espressione: String, espressione_sirio: String, battuta_sirio: String) -> void:
	_altro.texture = PixelMondo.ritratto(persona.aspetto, espressione)
	_sirio.texture = PixelMondo.ritratto("sirio", espressione_sirio)
	_citazione.visible = battuta_sirio != ""
	_citazione.text = "Sirio: «%s»" % battuta_sirio
	_testo.text = testo
	_testo.visible_ratio = 0.0
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_testo, "visible_ratio", 1.0, clampf(testo.length() / 55.0, 0.2, 3.0))
	var parla := create_tween()
	parla.tween_property(_altro, "position:y", _altro.position.y - 6, 0.08)
	parla.tween_property(_altro, "position:y", _altro.position.y, 0.08)
	_riempi_opzioni()


func _completa() -> void:
	if _tw != null and _tw.is_running():
		_tw.kill()
		_testo.visible_ratio = 1.0


func _riempi_opzioni() -> void:
	for c in _opzioni.get_children():
		c.queue_free()
	if _nodo == "":
		var b := _bottone("CONTINUA", Color("e8e8e8"), true)
		b.pressed.connect(chiudi)
		_opzioni.add_child(b)
		return
	for o in DialogoSystem.opzioni(s, persona.dialogo, _nodo):
		var etichetta := ""
		match o.categoria:
			"stat":
				etichetta = "[%s] " % o.requisito_testo.to_upper()
			"memoria":
				etichetta = "[RICORDO] "
			"seed":
				etichetta = "[OGGI] "
		var coda := ""
		if o.has("costo"):
			coda = "  · costa %s" % Stile.ore(float(o.costo))
		elif int(o.minuti) > 0:
			coda = "  · %d min" % int(o.minuti)
		var b := _bottone(etichetta + str(o.testo) + coda, COLORI.get(o.categoria, Color.WHITE), o.aperta)
		if not o.aperta:
			b.tooltip_text = "Ti serve %s." % o.requisito_testo
		var opz: Dictionary = o
		b.pressed.connect(func(): scegli(opz))
		_opzioni.add_child(b)


func _bottone(testo: String, colore: Color, aperta: bool) -> Button:
	var b := Button.new()
	b.text = testo
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", colore if aperta else colore.darkened(0.5))
	b.add_theme_color_override("font_hover_color", colore.lightened(0.2))
	if not aperta:
		b.add_theme_color_override("font_disabled_color", colore.darkened(0.5))
	return b


## Pubblica per i test: sceglie un'opzione (come se fosse toccata).
func scegli(o: Dictionary) -> void:
	if ui != null:
		ui._s("click")
	if not o.get("aperta", true):
		if ui != null:
			ui.notifica("Ti serve %s." % o.requisito_testo)
		var tw := create_tween()
		for i in 4:
			tw.tween_property(_sirio, "position:x", _sirio.position.x + (4 if i % 2 == 0 else -4), 0.04)
		tw.tween_property(_sirio, "position:x", _sirio.position.x, 0.04)
		return
	var r := DialogoSystem.scegli(s, persona.dialogo, _nodo, o)
	if r.get("rifiutata", false):
		if ui != null:
			ui.notifica(str(r.motivo))
		return
	if ui != null:
		ui.accoda_esito(r.esito, "Con %s" % persona.nome)
	if s.is_over:
		chiudi()
		return
	if o.get("vai", "") == "fine" and str(r.risposta) == "":
		chiudi()
		return
	_nodo = r.prossimo
	_mostra(str(r.risposta), str(r.espressione), str(r.sirio), str(o.testo))


func chiudi() -> void:
	if is_queued_for_deletion():
		return
	chiuso.emit()
	queue_free()


func opzioni_visibili() -> Array:
	return DialogoSystem.opzioni(s, persona.dialogo, _nodo) if _nodo != "" else []
