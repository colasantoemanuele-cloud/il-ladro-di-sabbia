class_name CartaUI
extends PanelContainer
## Carta toccabile: cornice pixel art colorata per categoria, titolo, riga di
## dettaglio, badge di stato e dado d20 con il rischio. Un Button trasparente
## sopra il contenuto raccoglie il tocco (cosi lo scroll a trascinamento
## resta fluido: il ScrollContainer prende il gesto oltre la zona morta).

signal premuta

const ALTEZZA_MIN := 112.0

var categoria: String = ""
var _bottone: Button
var _lbl_titolo: Label
var _lbl_dettaglio: Label
var _lbl_badge: Label
var _lbl_rischio: Label
var _icona_dado: TextureRect
var _disabilitata := false


func _init(cat: String = "", titolo: String = "", dettaglio: String = "", rischio: float = -1.0) -> void:
	categoria = cat
	custom_minimum_size = Vector2(0, ALTEZZA_MIN)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", PixelArt.stile_carta(cat))

	var margine := MarginContainer.new()
	margine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margine)

	var riga := HBoxContainer.new()
	riga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riga.add_theme_constant_override("separation", 10)
	margine.add_child(riga)

	var colonna := VBoxContainer.new()
	colonna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonna.add_theme_constant_override("separation", 4)
	riga.add_child(colonna)

	_lbl_titolo = Stile.etichetta(titolo, 19, Stile.CHIARO)
	_lbl_titolo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_titolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonna.add_child(_lbl_titolo)

	_lbl_dettaglio = Stile.etichetta(dettaglio, 17, Stile.SABBIA)
	_lbl_dettaglio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_dettaglio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonna.add_child(_lbl_dettaglio)

	_lbl_badge = Stile.etichetta("", 16, Stile.ROSSO)
	_lbl_badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_badge.visible = false
	colonna.add_child(_lbl_badge)

	if rischio >= 0.0:
		var destra := VBoxContainer.new()
		destra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		destra.alignment = BoxContainer.ALIGNMENT_CENTER
		riga.add_child(destra)
		_icona_dado = TextureRect.new()
		_icona_dado.texture = PixelArt.icona_d20_piccola()
		_icona_dado.custom_minimum_size = Vector2(48, 48)
		_icona_dado.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icona_dado.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icona_dado.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_icona_dado.mouse_filter = Control.MOUSE_FILTER_IGNORE
		destra.add_child(_icona_dado)
		_lbl_rischio = Stile.etichetta("%d%%" % roundi(rischio * 100.0), 18, Stile.CHIARO)
		_lbl_rischio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lbl_rischio.mouse_filter = Control.MOUSE_FILTER_IGNORE
		destra.add_child(_lbl_rischio)

	_bottone = Button.new()
	_bottone.flat = true
	_bottone.focus_mode = Control.FOCUS_NONE
	_bottone.mouse_filter = Control.MOUSE_FILTER_STOP
	for nome in ["normal", "hover", "pressed", "disabled", "focus"]:
		_bottone.add_theme_stylebox_override(nome, StyleBoxEmpty.new())
	_bottone.pressed.connect(func(): premuta.emit())
	_bottone.button_down.connect(_su_giu)
	_bottone.button_up.connect(_su_su)
	add_child(_bottone)


func _su_giu() -> void:
	if not _disabilitata:
		add_theme_stylebox_override("panel", PixelArt.stile_carta(categoria, "premuto"))


func _su_su() -> void:
	_applica_stile()


func _applica_stile() -> void:
	add_theme_stylebox_override("panel", PixelArt.stile_carta(categoria, "disabilitato" if _disabilitata else "normale"))


func imposta_testi(titolo: String, dettaglio: String) -> void:
	_lbl_titolo.text = titolo
	_lbl_dettaglio.text = dettaglio


func imposta_badge(testo: String, colore: Color = Stile.ROSSO) -> void:
	_lbl_badge.text = testo
	_lbl_badge.visible = testo != ""
	_lbl_badge.add_theme_color_override("font_color", colore)


func imposta_rischio(rischio: float) -> void:
	if _lbl_rischio != null:
		_lbl_rischio.text = "%d%%" % roundi(rischio * 100.0)


func abilita(attiva: bool) -> void:
	_disabilitata = not attiva
	_bottone.disabled = not attiva
	_applica_stile()
	var colore := Stile.CHIARO if attiva else Stile.GRIGIO
	_lbl_titolo.add_theme_color_override("font_color", colore)
	_lbl_dettaglio.add_theme_color_override("font_color", Stile.SABBIA if attiva else Stile.GRIGIO)
	if _icona_dado != null:
		_icona_dado.modulate = Color.WHITE if attiva else Color(1, 1, 1, 0.35)


func e_abilitata() -> bool:
	return not _disabilitata
