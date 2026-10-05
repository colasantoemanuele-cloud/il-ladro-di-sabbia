class_name CutsceneUI
extends Control
## Cutscene a pannelli, a tutto schermo: un'illustrazione in pixel art che si
## avvicina piano, una didascalia che scorre lettera per lettera. Si tocca per
## andare avanti; SALTA chiude tutto. Usata per l'apertura, i finali, la
## prima discesa nella Cripta e l'arrivo di Dolce Volpe.

signal finita

const INTRO := [
	["pioggia", "Ledune, lunedì notte. La pioggia porta giù la sabbia sporca dei tetti."],
	["ospedale", "Al terzo piano del San Lazzaro, Serena ha smesso di respirare alle ventidue e dieci."],
	["incubatrice", "Sara è nata un minuto dopo. Troppo presto, troppo piccola. Le servivano anni, non ore."],
	["clessidra", "Gliene ho dati quasi tutti. Qui la vita si cede, e io l'ho ceduta."],
	["sirio", "A lei restano tre settimane. A me un giorno e un debito con Rocco. Ogni minuto lo paghiamo in due."],
	["serena", "Serena diceva che il tempo non si ruba, si consuma. Stanotte comincio a rubarlo."],
]
const CRIPTA := [
	["cripta", "La scala scende più di quanto dovrebbe. L'aria sa di cera e di qualcosa di più vecchio della cera."],
]
const VOLPE := [
	["volpe", "Il buio della stanza si ritira in un angolo. Nell'angolo ci sono due occhi gialli, e un sorriso."],
]

var _pannelli: Array = []
var _indice := -1
var _img: TextureRect
var _testo: Label
var _tw: Tween
var _pan: Tween


func avvia(pannelli: Array) -> void:
	_pannelli = pannelli
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var nero := ColorRect.new()
	nero.color = Color("050508")
	nero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(nero)
	var cornice := Control.new()
	cornice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cornice.offset_left = 60
	cornice.offset_right = -60
	cornice.offset_top = 30
	cornice.offset_bottom = -190
	cornice.clip_contents = true
	add_child(cornice)
	_img = TextureRect.new()
	_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cornice.add_child(_img)
	_testo = Stile.etichetta("", 24, Stile.CHIARO)
	_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_testo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_testo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_testo.offset_top = -170
	_testo.offset_bottom = -50
	_testo.offset_left = 120
	_testo.offset_right = -120
	add_child(_testo)
	var aiuto := Stile.etichetta("tocca per continuare", 15, Stile.GRIGIO)
	aiuto.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	aiuto.offset_top = -40
	aiuto.offset_left = -100
	aiuto.offset_right = 100
	aiuto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(aiuto)
	var salta := Button.new()
	salta.text = "SALTA"
	salta.custom_minimum_size = Vector2(150, 60)
	salta.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	salta.offset_left = -170
	salta.offset_top = 16
	salta.offset_right = -20
	salta.offset_bottom = 76
	salta.pressed.connect(fine)
	add_child(salta)
	avanti()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		accept_event()
		if _tw != null and _tw.is_running():
			_tw.kill()
			_testo.visible_ratio = 1.0
		else:
			avanti()


func avanti() -> void:
	_indice += 1
	if _indice >= _pannelli.size():
		fine()
		return
	var p: Array = _pannelli[_indice]
	_img.texture = PixelMondo.vignetta(p[0])
	_img.modulate.a = 0.0
	_img.scale = Vector2.ONE
	_img.pivot_offset = _img.size * 0.5
	var f := create_tween()
	f.tween_property(_img, "modulate:a", 1.0, 0.5)
	if _pan != null:
		_pan.kill()
	_pan = create_tween()
	_pan.tween_property(_img, "scale", Vector2(1.08, 1.08), 6.0)
	_testo.text = p[1]
	_testo.visible_ratio = 0.0
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_interval(0.3)
	_tw.tween_property(_testo, "visible_ratio", 1.0, clampf(str(p[1]).length() / 40.0, 0.5, 4.0))


func fine() -> void:
	if is_queued_for_deletion():
		return
	finita.emit()
	queue_free()
