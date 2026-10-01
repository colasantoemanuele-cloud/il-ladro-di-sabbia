class_name IntroScreen
extends Control
## Intro narrativa (scritta a macchina, un tocco la completa) seguita da tre
## schermate di tutorial.

signal finita

var audio: MusicEngine
var _fase := 0
var _testo: RichTextLabel
var _titolo: Label
var _avanti: Button
var _tween: Tween


func avvia(motore_audio: MusicEngine) -> void:
	audio = motore_audio
	theme = Stile.tema()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.color = Stile.NERO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var margine := MarginContainer.new()
	margine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lato in ["left", "right", "top", "bottom"]:
		margine.add_theme_constant_override("margin_" + lato, 60)
	add_child(margine)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	margine.add_child(v)

	_titolo = Stile.etichetta("", Stile.TITOLI, Stile.SABBIA)
	v.add_child(_titolo)
	_testo = RichTextLabel.new()
	_testo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_testo.add_theme_font_size_override("normal_font_size", 24)
	_testo.scroll_active = false
	v.add_child(_testo)
	_avanti = Button.new()
	_avanti.custom_minimum_size = Vector2(0, 96)
	_avanti.add_theme_font_size_override("font_size", 26)
	Stile.applica_bottone(_avanti, Stile.ROSSO)
	_avanti.pressed.connect(_su_avanti)
	v.add_child(_avanti)
	_mostra_fase()


func _mostra_fase() -> void:
	if _tween != null:
		_tween.kill()
	if _fase == 0:
		_titolo.text = ""
		_testo.text = TestiDemo.INTRO
		_avanti.text = "AVANTI"
	else:
		var t: Dictionary = TestiDemo.TUTORIAL[_fase - 1]
		_titolo.text = "%d/%d  %s" % [_fase, TestiDemo.TUTORIAL.size(), str(t.titolo).to_upper()]
		_testo.text = t.testo
		_avanti.text = "INIZIA" if _fase == TestiDemo.TUTORIAL.size() else "AVANTI"
	_testo.visible_ratio = 0.0
	var durata := maxf(float(_testo.get_total_character_count()) * 0.025, 0.4)
	_tween = create_tween()
	_tween.tween_property(_testo, "visible_ratio", 1.0, durata)


func _su_avanti() -> void:
	if audio != null:
		audio.sfx("click")
	if _testo.visible_ratio < 1.0:
		if _tween != null:
			_tween.kill()
		_testo.visible_ratio = 1.0
		return
	_fase += 1
	if _fase > TestiDemo.TUTORIAL.size():
		finita.emit()
		return
	_mostra_fase()


func gestisci_indietro() -> void:
	_su_avanti()
