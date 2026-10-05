class_name Esplorazione
extends Control
## Una stanza esplorabile in vista dall'alto. Si tocca un punto e Sirio ci
## cammina (percorso su griglia, AStarGrid2D); si tocca un oggetto, una
## persona o una porta e Sirio ci va vicino e poi segnala l'interazione.
## Sul desktop funzionano anche le frecce e WASD (Spazio o Invio per
## interagire con quello che ha davanti). Nessuna regola di gioco qui: la
## vista emette segnali, ImperoUI decide.

signal oggetto_toccato(ogg: Dictionary)
signal persona_toccata(persona: Dictionary)
signal porta_toccata(porta: Dictionary)
signal passo_fatto

const T := 16
const VELOCITA := 5.5
const DIREZIONI := {Vector2i(0, 1): 0, Vector2i(0, -1): 1, Vector2i(-1, 0): 2, Vector2i(1, 0): 3}

var stanza: Dictionary = {}
var zoom := 3
var attiva := true
var luce_extra := false

var _mondo: Node2D
var _sfondo: Sprite2D
var _attori: Node2D
var _sirio: Sprite2D
var _buio: Sprite2D
var _segno: Sprite2D
var _astar := AStarGrid2D.new()
var _cella := Vector2i.ZERO
var _pos := Vector2.ZERO
var _percorso: Array[Vector2i] = []
var _dir := 0
var _passo := 0
var _t_passo := 0.0
var _obiettivo: Dictionary = {}
var _persone: Dictionary = {}
var _marcatori: Array[Node2D] = []
var _strato_segni: Node2D
var _t := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func carica(s: Dictionary, arrivo: Array, ha_lanterna: bool) -> void:
	stanza = s
	luce_extra = ha_lanterna
	if _mondo != null:
		_mondo.queue_free()
	_mondo = Node2D.new()
	_mondo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_mondo)
	_sfondo = Sprite2D.new()
	_sfondo.centered = false
	_sfondo.texture = PixelMondo.stanza(s)
	_mondo.add_child(_sfondo)
	_attori = Node2D.new()
	_attori.y_sort_enabled = true
	_mondo.add_child(_attori)
	_strato_segni = Node2D.new()
	_marcatori.clear()
	_persone.clear()
	for o in s.oggetti:
		var sp := Sprite2D.new()
		sp.centered = false
		sp.texture = PixelMondo.oggetto(o.tipo, o.dim)
		sp.position = Vector2(o.pos[0] * T, (o.pos[1] + o.dim[1]) * T)
		sp.offset = Vector2(0, -(int(o.dim[1]) * T + 8))
		_attori.add_child(sp)
		if o.has("voci") or o.has("minigioco"):
			_marcatore(Vector2(o.pos[0] * T + o.dim[0] * T * 0.5, o.pos[1] * T - 10), Color("f0c050"))
	for n in s.npc:
		var sp := Sprite2D.new()
		sp.centered = false
		sp.texture = PixelMondo.personaggio(n.aspetto, 0, 0)
		sp.position = Vector2(n.pos[0] * T + T / 2, n.pos[1] * T + T - 1)
		sp.offset = Vector2(-8, -24)
		_attori.add_child(sp)
		_persone[n.id] = sp
		if n.has("dialogo"):
			_marcatore(Vector2(n.pos[0] * T + T / 2, n.pos[1] * T - 16), Color("e8e8e8"))
	_sirio = Sprite2D.new()
	_sirio.centered = false
	_sirio.offset = Vector2(-8, -24)
	_attori.add_child(_sirio)
	_segno = Sprite2D.new()
	_segno.texture = _texture_segno()
	_segno.visible = false
	_mondo.add_child(_segno)
	_buio = null
	if s.get("buio", false):
		_buio = Sprite2D.new()
		_buio.texture = PixelMondo.buio(110 if ha_lanterna else 55)
		_mondo.add_child(_buio)
	_mondo.add_child(_strato_segni)
	_prepara_griglia()
	_cella = Vector2i(int(arrivo[0]), int(arrivo[1]))
	_pos = _centro(_cella)
	_percorso.clear()
	_obiettivo = {}
	_dir = 0
	_aggiorna_sirio()
	_disponi()


func _texture_segno() -> ImageTexture:
	var img := Image.create(10, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in 10:
		for y in 6:
			var d := Vector2((x - 4.5) / 5.0, (y - 2.5) / 3.0).length()
			if d <= 1.0 and d > 0.55:
				img.set_pixel(x, y, Color(0.94, 0.75, 0.3, 0.9))
	return ImageTexture.create_from_image(img)


func _marcatore(p: Vector2, c: Color) -> void:
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for k in [[2, 0], [1, 1], [2, 1], [3, 1], [0, 2], [1, 2], [2, 2], [3, 2], [4, 2], [1, 3], [2, 3], [3, 3], [2, 4]]:
		img.set_pixel(k[0], k[1], c)
	var sp := Sprite2D.new()
	sp.texture = ImageTexture.create_from_image(img)
	sp.position = p
	_strato_segni.add_child(sp)
	_marcatori.append(sp)


func _prepara_griglia() -> void:
	var w: int = stanza.w
	var h: int = stanza.h
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, w, h)
	_astar.cell_size = Vector2(1, 1)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	for y in h:
		for x in w:
			if x == 0 or x == w - 1 or y <= 1 or y == h - 1:
				_astar.set_point_solid(Vector2i(x, y), true)
	for o in stanza.oggetti:
		for i in int(o.dim[0]):
			for j in int(o.dim[1]):
				_astar.set_point_solid(Vector2i(int(o.pos[0]) + i, int(o.pos[1]) + j), true)
	for n in stanza.npc:
		_astar.set_point_solid(Vector2i(int(n.pos[0]), int(n.pos[1])), true)
	for p in stanza.porte:
		_astar.set_point_solid(Vector2i(int(p.pos[0]), int(p.pos[1])), true)


func _centro(c: Vector2i) -> Vector2:
	return Vector2(c.x * T + T / 2, c.y * T + T - 2)


func _disponi() -> void:
	if stanza.is_empty() or _mondo == null:
		return
	var dim_stanza := Vector2(int(stanza.w) * T, int(stanza.h) * T)
	zoom = clampi(int(minf(size.x / dim_stanza.x, size.y / dim_stanza.y)), 2, 4)
	if zoom < 2:
		zoom = 2
	_mondo.scale = Vector2(zoom, zoom)
	var px := dim_stanza * zoom
	var pos := Vector2.ZERO
	for asse in 2:
		if px[asse] <= size[asse]:
			pos[asse] = (size[asse] - px[asse]) * 0.5
		else:
			pos[asse] = clampf(size[asse] * 0.5 - _pos[asse] * zoom, size[asse] - px[asse], 0.0)
	_mondo.position = pos.round()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_disponi()


func _aggiorna_sirio() -> void:
	_sirio.texture = PixelMondo.personaggio("sirio", _dir, _passo)
	_sirio.position = _pos.round()
	if _buio != null:
		_buio.position = _pos + Vector2(0, -8)
		_buio.scale = Vector2(2, 2)


func _process(delta: float) -> void:
	if _mondo == null:
		return
	_t += delta
	for i in _marcatori.size():
		_marcatori[i].offset.y = roundf(sin(_t * 3.0 + i) * 1.5)
	for id in _persone:
		var sp: Sprite2D = _persone[id]
		sp.offset.y = -24 - (1 if fmod(_t + float(id.hash() % 7) * 0.3, 1.6) < 0.8 else 0)
	if _percorso.is_empty():
		return
	var prossima: Vector2i = _percorso[0]
	var meta := _centro(prossima)
	var d := meta - _pos
	var passo := VELOCITA * T * delta
	if d.length() <= passo:
		_pos = meta
		_cella = prossima
		_percorso.pop_front()
		passo_fatto.emit()
		if _percorso.is_empty():
			_passo = 0
			_segno.visible = false
			_arrivato()
	else:
		_pos += d.normalized() * passo
		var dir_v := Vector2i(signi(int(roundf(d.x))), signi(int(roundf(d.y))))
		if DIREZIONI.has(dir_v):
			_dir = DIREZIONI[dir_v]
		_t_passo += delta
		if _t_passo > 0.14:
			_t_passo = 0.0
			_passo = 1 if _passo != 1 else 2
	_aggiorna_sirio()
	_disponi()


func in_cammino() -> bool:
	return not _percorso.is_empty()


func _arrivato() -> void:
	if _obiettivo.is_empty():
		return
	var ob := _obiettivo
	_obiettivo = {}
	var bersaglio: Vector2i = ob.cella
	var dv := bersaglio - _cella
	dv = Vector2i(signi(dv.x), signi(dv.y))
	if DIREZIONI.has(dv):
		_dir = DIREZIONI[dv]
	_aggiorna_sirio()
	match ob.tipo:
		"oggetto":
			oggetto_toccato.emit(ob.dato)
		"persona":
			var sp: Sprite2D = _persone.get(ob.dato.id)
			if sp != null:
				var verso := _cella - Vector2i(int(ob.dato.pos[0]), int(ob.dato.pos[1]))
				sp.texture = PixelMondo.personaggio(ob.dato.aspetto, DIREZIONI.get(Vector2i(signi(verso.x), signi(verso.y)), 0), 0)
			persona_toccata.emit(ob.dato)
		"porta":
			porta_toccata.emit(ob.dato)


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if not attiva:
		return
	var premuto := false
	var punto := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		premuto = true
		punto = event.position
	elif event is InputEventScreenTouch and event.pressed:
		premuto = true
		punto = event.position
	if premuto:
		accept_event()
		tocca(_cella_da_schermo(punto))


func _unhandled_key_input(event: InputEvent) -> void:
	if not attiva or not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed:
		return
	var mappa := {KEY_UP: Vector2i(0, -1), KEY_W: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_S: Vector2i(0, 1),
		KEY_LEFT: Vector2i(-1, 0), KEY_A: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0), KEY_D: Vector2i(1, 0)}
	if mappa.has(event.keycode) and _percorso.is_empty():
		var dv: Vector2i = mappa[event.keycode]
		_dir = DIREZIONI[dv]
		var c := _cella + dv
		if _camminabile(c):
			_percorso = [c]
		_aggiorna_sirio()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E] and _percorso.is_empty():
		var davanti: Vector2i = _cella + DIREZIONI.find_key(_dir)
		tocca(davanti)
		get_viewport().set_input_as_handled()


func _cella_da_schermo(p: Vector2) -> Vector2i:
	var locale := (p - _mondo.position) / float(zoom)
	return Vector2i(floori(locale.x / T), floori(locale.y / T))


func _camminabile(c: Vector2i) -> bool:
	return _astar.is_in_boundsv(c) and not _astar.is_point_solid(c)


## Tocco su una cella: cammina, o va vicino a cosa c'è e ci interagisce.
func tocca(c: Vector2i) -> void:
	var bersaglio := cosa_in(c)
	if bersaglio.is_empty():
		if _camminabile(c):
			_vai(c, {})
		return
	var celle: Array[Vector2i] = bersaglio.celle
	var vicine: Array[Vector2i] = []
	for cc in celle:
		for dv in DIREZIONI:
			var n: Vector2i = cc + dv
			if _camminabile(n) or n == _cella:
				vicine.append(n)
	if bersaglio.tipo == "oggetto":
		for cc in celle:
			if cc.y <= 1:
				for k in [Vector2i(cc.x, 2)]:
					if _camminabile(k) or k == _cella:
						vicine.append(k)
	if vicine.has(_cella):
		_obiettivo = {"tipo": bersaglio.tipo, "dato": bersaglio.dato, "cella": _piu_vicina(celle, _cella)}
		_arrivato()
		return
	var migliore: Array[Vector2i] = []
	for v in vicine:
		var p := _astar.get_id_path(_cella, v)
		if not p.is_empty() and (migliore.is_empty() or p.size() < migliore.size()):
			migliore = p
	if migliore.is_empty():
		return
	_obiettivo = {"tipo": bersaglio.tipo, "dato": bersaglio.dato, "cella": _piu_vicina(celle, migliore[-1])}
	_avvia_percorso(migliore)


func _piu_vicina(celle: Array[Vector2i], da: Vector2i) -> Vector2i:
	var best := celle[0]
	for c in celle:
		if (c - da).length_squared() < (best - da).length_squared():
			best = c
	return best


func _vai(c: Vector2i, obiettivo: Dictionary) -> void:
	var p := _astar.get_id_path(_cella, c)
	if p.is_empty():
		return
	_obiettivo = obiettivo
	_avvia_percorso(p)
	_segno.position = Vector2(c.x * T + T / 2, c.y * T + T - 3)
	_segno.visible = true


func _avvia_percorso(p: Array[Vector2i]) -> void:
	_percorso.clear()
	for i in range(1, p.size()):
		_percorso.append(p[i])
	if _percorso.is_empty():
		_arrivato()


## Cosa c'è in una cella: oggetto, persona o porta, con le celle che occupa.
func cosa_in(c: Vector2i) -> Dictionary:
	for p in stanza.porte:
		if Vector2i(int(p.pos[0]), int(p.pos[1])) == c:
			var celle: Array[Vector2i] = [c]
			return {"tipo": "porta", "dato": p, "celle": celle}
	for n in stanza.npc:
		if Vector2i(int(n.pos[0]), int(n.pos[1])) == c or Vector2i(int(n.pos[0]), int(n.pos[1]) - 1) == c:
			var celle2: Array[Vector2i] = [Vector2i(int(n.pos[0]), int(n.pos[1]))]
			return {"tipo": "persona", "dato": n, "celle": celle2}
	for o in stanza.oggetti:
		var r := Rect2i(int(o.pos[0]), int(o.pos[1]) - 1, int(o.dim[0]), int(o.dim[1]) + 1)
		if r.has_point(c):
			var celle3: Array[Vector2i] = []
			for i in int(o.dim[0]):
				for j in int(o.dim[1]):
					celle3.append(Vector2i(int(o.pos[0]) + i, int(o.pos[1]) + j))
			return {"tipo": "oggetto", "dato": o, "celle": celle3}
	return {}


func cella_sirio() -> Vector2i:
	return _cella


## Per i test e le foto: posiziona Sirio su una cella libera.
func teletrasporta(c: Vector2i) -> void:
	_cella = c
	_pos = _centro(c)
	_percorso.clear()
	_aggiorna_sirio()
	_disponi()


func ferma() -> void:
	_percorso.clear()
	_obiettivo = {}
	_passo = 0
	if _segno != null:
		_segno.visible = false
