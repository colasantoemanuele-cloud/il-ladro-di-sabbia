class_name Stile
extends RefCounted
## Tema grafico condiviso: colori, font monospace, stili dei bottoni e dei
## pannelli, formattazione dei numeri. Corpo 18, valori 22, titoli 28.

const NERO := Color("0d0d0d")
const BLU_NOTTE := Color("1a1a2e")
const BLU_PANEL := Color("16213e")
const ROSSO := Color("e94560")
const SABBIA := Color("c8a97e")
const CHIARO := Color("e8e8e8")
const VERDE := Color("4a7c59")
const GRIGIO := Color("5a5a6e")
const GIALLO := Color("f0c050")

const CORPO := 18
const VALORI := 22
const TITOLI := 28

static var _font: Font
static var _tema: Theme


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["monospace", "DejaVu Sans Mono", "Droid Sans Mono", "Courier New"])
		f.allow_system_fallback = true
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		_font = f
	return _font


static func box(fondo: Color, bordo: Color, spessore: int = 3, margine: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = bordo
	s.set_border_width_all(spessore)
	s.set_corner_radius_all(0)
	s.content_margin_left = margine
	s.content_margin_right = margine
	s.content_margin_top = margine
	s.content_margin_bottom = margine
	return s


static func tema() -> Theme:
	if _tema != null:
		return _tema
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = CORPO
	t.set_font_size("font_size", "Label", CORPO)
	t.set_color("font_color", "Label", CHIARO)
	t.set_font_size("normal_font_size", "RichTextLabel", CORPO)
	t.set_font_size("bold_font_size", "RichTextLabel", CORPO)
	t.set_color("default_color", "RichTextLabel", CHIARO)
	t.set_font_size("font_size", "Button", 20)
	t.set_color("font_color", "Button", SABBIA)
	t.set_color("font_hover_color", "Button", CHIARO)
	t.set_color("font_pressed_color", "Button", CHIARO)
	t.set_color("font_disabled_color", "Button", GRIGIO)
	t.set_color("font_focus_color", "Button", SABBIA)
	t.set_stylebox("normal", "Button", box(BLU_PANEL, SABBIA.darkened(0.3)))
	t.set_stylebox("hover", "Button", box(BLU_PANEL.lightened(0.1), SABBIA))
	t.set_stylebox("pressed", "Button", box(BLU_NOTTE, ROSSO))
	t.set_stylebox("disabled", "Button", box(Color("14141c"), Color("2a2a36")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(BLU_PANEL, GRIGIO, 3, 10))
	var barra_fondo := box(Color("0a0a12"), Color("2a2a3a"), 2, 0)
	t.set_stylebox("background", "ProgressBar", barra_fondo)
	t.set_stylebox("fill", "ProgressBar", box(SABBIA, SABBIA, 0, 0))
	t.set_stylebox("slider", "HSlider", box(Color("2a2a3a"), Color("2a2a3a"), 0, 4))
	t.set_stylebox("grabber_area", "HSlider", box(SABBIA.darkened(0.2), SABBIA.darkened(0.2), 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(SABBIA, SABBIA, 0, 4))
	_tema = t
	return t


static func barra(colore: Color) -> StyleBoxFlat:
	return box(colore, colore.darkened(0.4), 0, 0)


static func bottone_stile(colore: Color) -> Dictionary:
	return {
		"normal": box(colore.darkened(0.55), colore),
		"hover": box(colore.darkened(0.4), colore.lightened(0.2)),
		"pressed": box(colore.darkened(0.7), CHIARO),
		"disabled": box(Color("14141c"), Color("2a2a36")),
	}


static func applica_bottone(b: Button, colore: Color) -> void:
	var st := bottone_stile(colore)
	for k in st:
		b.add_theme_stylebox_override(k, st[k])


static func etichetta(testo: String, dimensione: int = CORPO, colore: Color = CHIARO) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_font_size_override("font_size", dimensione)
	l.add_theme_color_override("font_color", colore)
	return l


## Ore con unita adatta: sotto 100h "x.xh", oltre "x anni" per i valori enormi.
static func ore(v: float, con_segno: bool = false) -> String:
	var segno := ""
	if con_segno:
		segno = "+" if v >= 0.0 else "-"
	elif v < 0.0:
		segno = "-"
	var a := absf(v)
	if a >= 1000.0:
		return "%s%.1f anni" % [segno, a / 8760.0]
	if a >= 100.0:
		return "%s%.0fh" % [segno, a]
	return "%s%.1fh" % [segno, a]
