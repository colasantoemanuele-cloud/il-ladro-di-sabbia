class_name PixelArt
extends RefCounted
## Pixel art generata via codice, nessun file immagine esterno. Ogni asset
## nasce come Image a bassa risoluzione e viene ingrandito a blocchi
## (nearest) quando serve, cosi il risultato resta nitido a qualunque scala.

const NERO := Color("0d0d0d")
const BLU_NOTTE := Color("1a1a2e")
const BLU_PANEL := Color("16213e")
const ROSSO := Color("e94560")
const SABBIA := Color("c8a97e")
const CHIARO := Color("e8e8e8")
const VERDE := Color("4a7c59")
const GRIGIO := Color("5a5a6e")
const GIALLO := Color("f0c050")
const ARANCIO := Color("e08030")
const PELLE := Color("d9b98f")

const COLORI_CATEGORIA := {
	"Lavoro": Color("2f5d4a"),
	"Mendicare": Color("5a5a6e"),
	"Acquisto": Color("3d4f7a"),
	"Compravendita": Color("3d4f7a"),
	"Evento": Color("6a3d6e"),
	"Azzardo": Color("8a5a2a"),
	"Furto": Color("7a3040"),
	"Crimine": Color("8a2a3a"),
	"Grande colpo": Color("b0283c"),
	"Minaccia 1 a 1": Color("7a3040"),
	"Crimine organizzato": Color("6a2030"),
	"Bisogni": Color("4a5a4a"),
	"Relazioni": Color("3d6a7a"),
	"Corruzione": Color("6a5a2a"),
	"Tradimento": Color("4a2a5a"),
	"Altruismo": Color("3d7a5a"),
	"Narrativo": Color("5a4a7a"),
}

static var _cache := {}


static func _nuova(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in range(maxi(y, 0), mini(y + h, img.get_height())):
		for i in range(maxi(x, 0), mini(x + w, img.get_width())):
			img.set_pixel(i, j, c)


static func _disco(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			if i * i + j * j <= r * r:
				_px(img, cx + i, cy + j, c)


static func _linea(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		_px(img, x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func _poligono(img: Image, pts: Array, c: Color) -> void:
	var minx := 9999.0
	var maxx := -9999.0
	var miny := 9999.0
	var maxy := -9999.0
	for p in pts:
		minx = minf(minx, p.x)
		maxx = maxf(maxx, p.x)
		miny = minf(miny, p.y)
		maxy = maxf(maxy, p.y)
	for y in range(int(miny), int(maxy) + 1):
		for x in range(int(minx), int(maxx) + 1):
			if _dentro(pts, Vector2(x + 0.5, y + 0.5)):
				_px(img, x, y, c)


static func _dentro(pts: Array, p: Vector2) -> bool:
	var dentro := false
	var j := pts.size() - 1
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[j]
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			dentro = not dentro
		j = i
	return dentro


static func ingrandisci(img: Image, f: int) -> Image:
	var out := img.duplicate()
	out.resize(img.get_width() * f, img.get_height() * f, Image.INTERPOLATE_NEAREST)
	return out


static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


## Sprite da mappa ASCII (16 righe), con contorno nero automatico attorno ai
## pixel pieni: tiene coerente lo stile di tutte le icone.
static func _da_ascii(righe: Array, mappa: Dictionary, contorno: bool = true) -> Image:
	var h := righe.size()
	var w := 0
	for r in righe:
		w = maxi(w, String(r).length())
	var img := _nuova(w, h)
	for y in h:
		var riga: String = righe[y]
		for x in riga.length():
			var ch := riga[x]
			if mappa.has(ch):
				img.set_pixel(x, y, mappa[ch])
	if contorno:
		var base := img.duplicate()
		for y in h:
			for x in w:
				if base.get_pixel(x, y).a > 0.0:
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and base.get_pixel(nx, ny).a > 0.0:
						img.set_pixel(x, y, NERO)
						break
	return img


static func _mappa() -> Dictionary:
	return {
		"k": NERO, "r": ROSSO, "s": SABBIA, "w": CHIARO, "b": BLU_PANEL, "g": GRIGIO,
		"y": GIALLO, "o": ARANCIO, "v": VERDE, "p": PELLE, "n": BLU_NOTTE,
	}


# ---------------------------------------------------------------- icone

static func icona_risorsa(nome: String) -> ImageTexture:
	var chiave := "ris_" + nome
	if _cache.has(chiave):
		return _cache[chiave]
	var img: Image
	match nome:
		"polizia":
			img = _da_ascii([
				"................",
				"................",
				"....wwwwwwww....",
				"..wwwbbbbbbwww..",
				".wwbbbbwwbbbbww.",
				"wwbbbbwwwwbbbbww",
				"wwbbbwwkkwwbbbww",
				"wwbbbwwkkwwbbbww",
				"wwbbbbwwwwbbbbww",
				".wwbbbbwwbbbbww.",
				"..wwwbbbbbbwww..",
				"....wwwwwwww....",
				"................",
				"................",
				"................",
				"................",
			], _mappa())
		"rivalita":
			img = _nuova(16, 16)
			_linea(img, 2, 13, 12, 3, CHIARO)
			_linea(img, 3, 13, 13, 3, GRIGIO)
			_linea(img, 13, 13, 3, 3, CHIARO)
			_linea(img, 12, 13, 2, 3, GRIGIO)
			_rect(img, 1, 12, 3, 3, ROSSO)
			_rect(img, 12, 12, 3, 3, ROSSO)
			_rect(img, 2, 1, 2, 2, GRIGIO)
			_rect(img, 12, 1, 2, 2, GRIGIO)
			img = _da_ascii_da_immagine(img)
		"fama":
			img = _da_ascii([
				".......yy.......",
				".......yy.......",
				"......yyyy......",
				"......yyyy......",
				"yyyyyyyyyyyyyyyy",
				".yyyyyyyyyyyyyy.",
				"..yyyyyyyyyyyy..",
				"...yyyyyyyyyy...",
				"....yyyyyyyy....",
				"....yyyyyyyy....",
				"...yyyy..yyyy...",
				"...yyy....yyy...",
				"..yyy......yyy..",
				"..yy........yy..",
				"................",
				"................",
			], _mappa())
		"karma":
			img = _da_ascii([
				".......ss.......",
				".......ss.......",
				".ssssssssssssss.",
				"..s....ss....s..",
				"..s....ss....s..",
				"..s....ss....s..",
				".sss...ss...sss.",
				"ssssss.ss.ssssss",
				".......ss.......",
				".......ss.......",
				"......ssss......",
				".....ssssss.....",
				"................",
				"................",
				"................",
				"................",
			], _mappa())
		"fede":
			img = _da_ascii([
				".......o........",
				"......ooo.......",
				"......oyo.......",
				"......oyo.......",
				".......y........",
				".......k........",
				"......www.......",
				"......www.......",
				"......www.......",
				"......www.......",
				"......www.......",
				".....wwwww......",
				".....ggggg......",
				"................",
				"................",
				"................",
			], _mappa())
		_:
			img = _nuova(16, 16)
	var t := _tex(img)
	_cache[chiave] = t
	return t


static func _da_ascii_da_immagine(img: Image) -> Image:
	var righe: Array = []
	var inverso := {NERO: "k", ROSSO: "r", CHIARO: "w", GRIGIO: "g"}
	for y in img.get_height():
		var s := ""
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			s += inverso.get(c, ".") if c.a > 0.0 else "."
		righe.append(s)
	return _da_ascii(righe, _mappa())


static func icona_tab(nome: String) -> ImageTexture:
	var chiave := "tab_" + nome
	if _cache.has(chiave):
		return _cache[chiave]
	var righe: Array
	match nome:
		"azioni":
			righe = [
				"................", "...wwwwwwwwww...", "....wwwwwwww....", ".....wwwwww.....",
				"......wssw......", ".......ss.......", ".......ss.......", "......ssss......",
				".....ssssss.....", "....sssssss.....", "...ssssssssss...", "...wwwwwwwwww...",
				"................", "................", "................", "................",
			]
		"tracce":
			righe = [
				"................", "............ssss", "............ssss", "........ssssssss",
				"........ssssssss", "....ssssssssssss", "....ssssssssssss", "ssssssssssssssss",
				"ssssssssssssssss", "................", "................", "................",
				"................", "................", "................", "................",
			]
		"profilo":
			righe = [
				"................", "......wwww......", ".....wwwwww.....", ".....wwwwww.....",
				"......wwww......", "................", "....wwwwwwww....", "...wwwwwwwwww...",
				"...wwwwwwwwww...", "...wwwwwwwwww...", "................", "................",
				"................", "................", "................", "................",
			]
		"sottotrame":
			righe = [
				"................", "....yyyy........", "...yy..yy.......", "...yy..yy.......",
				"....yyyy........", ".....yy.........", ".....yy.........", ".....yyyy.......",
				".....yy.........", ".....yyyy.......", ".....yy.........", "................",
				"................", "................", "................", "................",
			]
		_:
			righe = ["................"]
	var t := _tex(_da_ascii(righe, _mappa()))
	_cache[chiave] = t
	return t


# ---------------------------------------------------------------- avatar

## 4 frame idle: respiro del cappotto e granello di sabbia che cade nella
## clessidra.
static func avatar_frame(frame: int) -> ImageTexture:
	var chiave := "avatar_%d" % frame
	if _cache.has(chiave):
		return _cache[chiave]
	var img := _nuova(32, 48)
	var respiro := 1 if frame == 1 or frame == 2 else 0
	var cappotto := Color("23233f")
	var cappotto_luce := Color("2f2f52")
	# gambe e scarpe
	_rect(img, 11, 34 + respiro, 4, 11 - respiro, NERO)
	_rect(img, 17, 34 + respiro, 4, 11 - respiro, NERO)
	_rect(img, 10, 44, 6, 3, Color("151515"))
	_rect(img, 16, 44, 6, 3, Color("151515"))
	# cappotto lungo
	_rect(img, 8, 17 + respiro, 16, 20 - respiro, cappotto)
	_rect(img, 8, 17 + respiro, 2, 20 - respiro, cappotto_luce)
	_rect(img, 15, 20 + respiro, 2, 17 - respiro, NERO)
	_rect(img, 8, 36, 16, 1, NERO)
	# bavero
	_poligono(img, [Vector2(10, 17 + respiro), Vector2(16, 24 + respiro), Vector2(16, 17 + respiro)], Color("3a3a60"))
	_poligono(img, [Vector2(22, 17 + respiro), Vector2(16, 24 + respiro), Vector2(16, 17 + respiro)], Color("3a3a60"))
	# braccio sinistro lungo il fianco
	_rect(img, 5, 19 + respiro, 3, 14, cappotto)
	_rect(img, 5, 33 + respiro, 3, 2, PELLE)
	# braccio destro piegato con clessidra
	_rect(img, 24, 19 + respiro, 3, 8, cappotto)
	_rect(img, 25, 27 + respiro, 3, 2, PELLE)
	# clessidra
	var cx := 27
	var cy := 22 + respiro
	_rect(img, cx - 2, cy - 1, 5, 1, SABBIA)
	_rect(img, cx - 2, cy + 7, 5, 1, SABBIA)
	_poligono(img, [Vector2(cx - 2, cy), Vector2(cx + 3, cy), Vector2(cx + 1, cy + 3), Vector2(cx, cy + 3)], Color("8fb0c8"))
	_poligono(img, [Vector2(cx, cy + 4), Vector2(cx + 1, cy + 4), Vector2(cx + 3, cy + 7), Vector2(cx - 2, cy + 7)], Color("8fb0c8"))
	_rect(img, cx - 1, cy + 5 + (frame % 2), 3, 2 - (frame % 2), SABBIA)
	_px(img, cx, cy + 3 + (1 if frame % 3 == 0 else 0), SABBIA)
	# collo, testa e volto
	_rect(img, 14, 14 + respiro, 4, 3, PELLE)
	_rect(img, 12, 7 + respiro, 8, 8, PELLE)
	_px(img, 14, 11 + respiro, NERO)
	_px(img, 18, 11 + respiro, NERO)
	_rect(img, 14, 13 + respiro, 4, 1, Color("8a6a50"))
	# cappello
	_rect(img, 8, 6 + respiro, 16, 2, Color("101018"))
	_rect(img, 11, 1 + respiro, 10, 6, Color("1a1a28"))
	_rect(img, 11, 5 + respiro, 10, 1, ROSSO)
	_rect(img, 12, 8 + respiro, 8, 1, Color("0a0a10"))
	var t := _tex(_aggiungi_contorno(img))
	_cache[chiave] = t
	return t


static func _aggiungi_contorno(img: Image) -> Image:
	var out := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < img.get_width() and ny < img.get_height() and img.get_pixel(nx, ny).a > 0.0:
					out.set_pixel(x, y, Color(0.02, 0.02, 0.03, 1.0))
					break
	return out


# ---------------------------------------------------------------- dado

const _CIFRE := {
	"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"],
	"4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
}


static func _numero(img: Image, n: int, cx: int, cy: int, c: Color) -> void:
	var s := str(n)
	var larghezza := s.length() * 4 - 1
	var x0 := cx - larghezza / 2
	for k in s.length():
		var cifra: Array = _CIFRE[s[k]]
		for ry in 5:
			for rx in 3:
				if cifra[ry][rx] == "1":
					_px(img, x0 + k * 4 + rx, cy - 2 + ry, c)


## Frame 0..4: dado che rotola (larghezza che oscilla), frame 5: faccia con
## il numero e lampo. Se numero < 0 il frame mostra solo la forma.
static func dado_frame(frame: int, numero: int = -1, colore: Color = ROSSO) -> ImageTexture:
	var img := _nuova(32, 32)
	var larghezza: float = [0.55, 0.85, 0.5, 0.9, 0.7, 1.0][clampi(frame, 0, 5)]
	var cx := 16.0
	var cy := 16.0
	var rx: float = 14.0 * larghezza
	var ry := 14.0
	var esa: Array = []
	for k in 6:
		var a := deg_to_rad(60.0 * k - 90.0)
		esa.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	var luce := colore.lightened(0.25)
	var ombra := colore.darkened(0.35)
	_poligono(img, esa, colore)
	var alto := [esa[0], esa[1], esa[5]]
	_poligono(img, alto, luce)
	var basso := [esa[3], esa[2], esa[4]]
	_poligono(img, basso, ombra)
	for k in 6:
		_linea(img, int(esa[k].x), int(esa[k].y), int(esa[(k + 1) % 6].x), int(esa[(k + 1) % 6].y), NERO)
	if frame == 5:
		_linea(img, int(esa[1].x), int(esa[1].y), int(esa[3].x), int(esa[3].y), ombra)
		_linea(img, int(esa[5].x), int(esa[5].y), int(esa[3].x), int(esa[3].y), ombra)
		_linea(img, int(esa[5].x), int(esa[5].y), int(esa[1].x), int(esa[1].y), ombra)
		if numero >= 0:
			_numero(img, numero, 16, 17, CHIARO)
		for p in [Vector2i(2, 3), Vector2i(29, 4), Vector2i(3, 27), Vector2i(28, 28)]:
			_px(img, p.x, p.y, CHIARO)
	else:
		_linea(img, int(esa[0].x), int(esa[0].y), int(esa[2].x), int(esa[2].y), ombra)
		_linea(img, int(esa[0].x), int(esa[0].y), int(esa[4].x), int(esa[4].y), ombra)
	return _tex(img)


# ---------------------------------------------------------------- carta

## Cornice a nove parti: 8x8 pixel d'arte ingranditi 3x. Il colore di fondo
## cambia per categoria.
static func stile_carta(categoria: String, stato: String = "normale") -> StyleBoxTexture:
	var chiave := "carta_%s_%s" % [categoria, stato]
	if _cache.has(chiave):
		return _cache[chiave]
	var base: Color = COLORI_CATEGORIA.get(categoria, BLU_PANEL)
	var fondo := base.darkened(0.45)
	var bordo := base.lightened(0.15)
	var luce := base.lightened(0.45)
	match stato:
		"premuto":
			fondo = fondo.lightened(0.18)
		"disabilitato":
			fondo = Color("17171f")
			bordo = Color("2a2a36")
			luce = Color("2a2a36")
	var img := _nuova(8, 8)
	for y in 8:
		for x in 8:
			var c := fondo
			if x == 0 or y == 0 or x == 7 or y == 7:
				c = NERO
			elif x == 1 or y == 1 or x == 6 or y == 6:
				c = bordo
			elif x == 2 and y == 2:
				c = luce
			img.set_pixel(x, y, c)
	for p in [Vector2i(0, 0), Vector2i(7, 0), Vector2i(0, 7), Vector2i(7, 7)]:
		img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
	var sb := StyleBoxTexture.new()
	sb.texture = _tex(ingrandisci(img, 3))
	sb.texture_margin_left = 9.0
	sb.texture_margin_right = 9.0
	sb.texture_margin_top = 9.0
	sb.texture_margin_bottom = 9.0
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	_cache[chiave] = sb
	return sb


static func icona_d20_piccola() -> ImageTexture:
	if _cache.has("d20p"):
		return _cache["d20p"]
	var t := dado_frame(5, -1, GRIGIO)
	_cache["d20p"] = t
	return t


# ---------------------------------------------------------------- icona app

static func icona_app() -> Image:
	var img := _nuova(48, 48)
	_rect(img, 0, 0, 48, 48, BLU_NOTTE)
	for y in 48:
		var t := float(y) / 47.0
		_rect(img, 0, y, 48, 1, BLU_NOTTE.lerp(Color("2a2040"), t * t))
	_disco(img, 36, 11, 5, Color("e8e0c8"))
	_disco(img, 38, 10, 4, BLU_NOTTE.lerp(Color("2a2040"), 0.1))
	for p in [Vector2i(6, 6), Vector2i(14, 12), Vector2i(24, 5), Vector2i(10, 20), Vector2i(42, 24)]:
		_px(img, p.x, p.y, CHIARO)
	_rect(img, 0, 40, 48, 8, NERO)
	# silhouette: cappello, volto in ombra, cappotto
	var sil := Color("08080c")
	_rect(img, 13, 14, 22, 3, sil)
	_rect(img, 17, 7, 14, 8, sil)
	_rect(img, 17, 12, 14, 1, ROSSO)
	_rect(img, 19, 17, 10, 8, sil)
	_poligono(img, [Vector2(10, 46), Vector2(14, 25), Vector2(34, 25), Vector2(38, 46)], sil)
	# granello di sabbia al centro
	_rect(img, 22, 30, 4, 4, SABBIA)
	_rect(img, 23, 29, 2, 1, SABBIA)
	_rect(img, 23, 34, 2, 1, SABBIA)
	_rect(img, 21, 31, 1, 2, SABBIA.darkened(0.2))
	_rect(img, 26, 31, 1, 2, SABBIA.lightened(0.2))
	return ingrandisci(img, 4)


# ---------------------------------------------------------------- skyline

const SKY_W := 320
const SKY_H := 200


## Quattro livelli per la parallasse (indice 0 = cielo, 3 = edifici vicini).
## Disegnati a 320x200 e ingranditi 4x al momento della visualizzazione.
static func skyline_livello(indice: int) -> ImageTexture:
	var chiave := "sky_%d" % indice
	if _cache.has(chiave):
		return _cache[chiave]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977 + indice
	var img := _nuova(SKY_W, SKY_H)
	match indice:
		0:
			var bande := [Color("0b0b16"), BLU_NOTTE, Color("1c2040"), BLU_PANEL, Color("2a2c52"), Color("3a3150"), Color("5a3c50"), Color("7a4a50")]
			for y in SKY_H:
				var t := float(y) / float(SKY_H - 1) * (bande.size() - 1)
				var i := mini(int(t), bande.size() - 2)
				var f := t - i
				for x in SKY_W:
					var soglia := 0.25 if (x + y) % 2 == 0 else 0.75
					img.set_pixel(x, y, bande[i + 1] if f > soglia else bande[i])
		1:
			for k in 90:
				var x := rng.randi_range(0, SKY_W - 1)
				var y := rng.randi_range(0, 110)
				_px(img, x, y, CHIARO if k % 5 == 0 else Color("8a8aa8"))
			_disco(img, 236, 46, 24, Color("c8b890").darkened(0.5))
			_disco(img, 236, 46, 20, Color("e8e0c8"))
			for c in [Vector2i(228, 40), Vector2i(244, 52), Vector2i(240, 36), Vector2i(230, 54)]:
				_disco(img, c.x, c.y, 3, Color("cfc4a4"))
		2:
			var colore := Color("2a3358")
			var x := 0
			while x < SKY_W:
				var w := rng.randi_range(14, 30)
				var h := rng.randi_range(30, 62)
				_rect(img, x, SKY_H - 70 - h + 70 - 0, w, h + 2, colore)
				_rect(img, x, SKY_H - 70 - h + 70, w, 1, colore.lightened(0.12))
				if rng.randf() < 0.35:
					_rect(img, x + w / 2 - 1, SKY_H - h - 8, 2, 8, colore)
				x += w + rng.randi_range(0, 3)
			# campanile
			var tx := 70
			_rect(img, tx, 78, 14, 94, colore)
			_poligono(img, [Vector2(tx - 1, 78), Vector2(tx + 7, 56), Vector2(tx + 15, 78)], colore)
			_rect(img, tx + 5, 84, 4, 8, Color("0b0b16"))
			_rect(img, tx + 7, 52, 1, 6, colore)
			_rect(img, tx + 5, 54, 5, 1, colore)
			for f in 3:
				_rect(img, 0, SKY_H - 28 + f, 1, 1, colore)
		3:
			var scuro := Color("0f0f1a")
			var x := -6
			while x < SKY_W:
				var w := rng.randi_range(26, 52)
				var h := rng.randi_range(34, 74)
				var y0 := SKY_H - h
				_rect(img, x, y0, w, h, scuro)
				_rect(img, x, y0, w, 2, scuro.lightened(0.18))
				_rect(img, x - 1, y0 - 2, w + 2, 2, scuro.lightened(0.1))
				for wy in range(y0 + 8, SKY_H - 16, 12):
					for wx in range(x + 5, x + w - 7, 10):
						var acceso := rng.randf() < 0.4
						_rect(img, wx, wy, 5, 7, SABBIA if acceso else Color("181828"))
						if acceso:
							_rect(img, wx, wy, 5, 1, Color("e8d8a8"))
				if rng.randf() < 0.4:
					_rect(img, x + w - 9, y0 - 8, 4, 8, scuro)
				x += w + rng.randi_range(2, 8)
			# strada e marciapiede
			_rect(img, 0, SKY_H - 10, SKY_W, 10, Color("0a0a10"))
			_rect(img, 0, SKY_H - 10, SKY_W, 1, Color("2a2a3a"))
			# cactus
			for cx in [34, 168, 290]:
				var verde := Color("2f5a40")
				_rect(img, cx, SKY_H - 34, 5, 24, verde)
				_rect(img, cx - 6, SKY_H - 28, 4, 3, verde)
				_rect(img, cx - 6, SKY_H - 34, 3, 9, verde)
				_rect(img, cx + 8, SKY_H - 24, 4, 3, verde)
				_rect(img, cx + 9, SKY_H - 30, 3, 8, verde)
				_rect(img, cx, SKY_H - 34, 1, 24, Color("3f7a52"))
			# lampione
			_rect(img, 118, SKY_H - 52, 2, 44, Color("2a2a3a"))
			_rect(img, 114, SKY_H - 54, 10, 3, Color("2a2a3a"))
			_rect(img, 116, SKY_H - 51, 6, 2, GIALLO)
	var t := _tex(img)
	_cache[chiave] = t
	return t


# ---------------------------------------------------------------- mondo

const COLORI_LUOGO := {
	"casa": Color("c8a97e"), "ospedale": Color("8fb0c8"), "porto": Color("4a7cb0"), "piazza": Color("d0a030"),
	"villa": Color("4a7c59"), "stazione": Color("e08030"), "chiesa": Color("b08ad0"), "banca": Color("f0c050"),
	"questura": Color("4a6fb0"), "palazzo": Color("a0a0b8"), "agenzia": Color("a050c0"), "bottega": Color("8a6a50"),
	"bisca": Color("c03040"), "magazzino": Color("6a2030"), "bar": Color("d07050"), "laboratorio": Color("50b080"),
	"catacombe": Color("8a5a2a"),
}


static func icona_ui(nome: String) -> ImageTexture:
	var chiave := "ui_" + nome
	if _cache.has(chiave):
		return _cache[chiave]
	var righe: Array
	match nome:
		"sonno":
			righe = ["................", ".....yyyy.......", "...yyyy.........", "..yyy...........", "..yyy......kkkk.",
				".yyy.........k..", ".yyy........k...", ".yyy.......kkkk.", "..yyy...........", "..yyyy......yy..",
				"...yyyyy..yyyy..", ".....yyyyyyy....", "................", "................", "................", "................"]
		"fame":
			righe = ["................", "................", "....ssssssss....", "..ssssssssssss..", ".ssswssswssswss.",
				".ssssssssssssss.", ".oooooooooooooo.", ".oooooooooooooo.", "..oooooooooooo..", "................",
				"................", "................", "................", "................", "................", "................"]
		"telefono":
			righe = ["....gggggggg....", "....gnnnnnng....", "....gnbbbbng....", "....gnbwwbng....", "....gnbbbbng....",
				"....gnbwwbng....", "....gnbbbbng....", "....gnbbbbng....", "....gnbbbbng....", "....gnnnnnng....",
				"....gnnwwnng....", "....gggggggg....", "................", "................", "................", "................"]
		"mappa":
			righe = ["................", ".sss.sss.sss....", ".sss.sss.sss....", ".srs.sss.sss....", ".srrrrrrrsss....",
				".sss.sss.rss....", ".sss.sss.rss....", ".sss.sss.sss....", "................", "................",
				"................", "................", "................", "................", "................", "................"]
		"taccuino":
			righe = ["................", "...rwwwwwwwww...", "...rwkkkkkkkw...", "...rwwwwwwwww...", "...rwkkkkkkww...",
				"...rwwwwwwwww...", "...rwkkkkkkkw...", "...rwwwwwwwww...", "...rwkkkkwwww...", "...rwwwwwwwww...",
				"...rrrrrrrrrr...", "................", "................", "................", "................", "................"]
		_:
			righe = ["................"]
	var t := _tex(_da_ascii(righe, _mappa()))
	_cache[chiave] = t
	return t


## Segnaposto della mappa: goccia colorata con l'iniziale del tipo di luogo.
static func pin_luogo(tipo: String, corrente: bool) -> ImageTexture:
	var chiave := "pin_%s_%s" % [tipo, corrente]
	if _cache.has(chiave):
		return _cache[chiave]
	var img := _nuova(16, 20)
	var c: Color = COLORI_LUOGO.get(tipo, SABBIA)
	if corrente:
		c = CHIARO
	_disco(img, 8, 7, 6, c)
	_poligono(img, [Vector2(3, 9), Vector2(13, 9), Vector2(8, 18)], c)
	_disco(img, 8, 7, 2, ROSSO if corrente else NERO)
	var t := _tex(_aggiungi_contorno(img))
	_cache[chiave] = t
	return t


## Mappa di Ledune a 160x100: mare a sud ovest, porto, strade, quartieri.
static func mappa_ledune() -> ImageTexture:
	if _cache.has("mappa"):
		return _cache["mappa"]
	var w := 160
	var h := 100
	var img := _nuova(w, h)
	var terra := Color("1c1c2c")
	_rect(img, 0, 0, w, h, terra)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for y in h:
		for x in w:
			if (x + y * 3) % 7 == 0 and rng.randf() < 0.5:
				img.set_pixel(x, y, terra.lightened(0.04))
	var mare := Color("12263e")
	_poligono(img, [Vector2(0, 58), Vector2(10, 60), Vector2(22, 70), Vector2(30, 86), Vector2(46, 92), Vector2(80, 96), Vector2(80, 100), Vector2(0, 100)], mare)
	for k in 30:
		_px(img, rng.randi_range(0, 60), rng.randi_range(80, 99), mare.lightened(0.15))
	# moli
	_rect(img, 16, 76, 10, 2, Color("3a3a4a"))
	_rect(img, 22, 82, 2, 8, Color("3a3a4a"))
	# parco del quartiere alto
	_rect(img, 112, 8, 34, 22, Color("1f3a2a"))
	for k in 40:
		_px(img, rng.randi_range(113, 145), rng.randi_range(9, 29), Color("2f5a40"))
	# citta vecchia
	_rect(img, 76, 56, 30, 22, Color("2a2420"))
	# strade principali
	var strada := Color("3e3a48")
	_rect(img, 0, 46, w, 3, strada)
	_rect(img, 72, 0, 3, h, strada)
	_linea(img, 20, 30, 140, 74, strada)
	_linea(img, 21, 30, 141, 74, strada)
	_linea(img, 40, 10, 100, 96, strada)
	_rect(img, 0, 22, w, 1, strada.darkened(0.2))
	_rect(img, 0, 70, w, 1, strada.darkened(0.2))
	_rect(img, 40, 0, 1, h, strada.darkened(0.2))
	_rect(img, 110, 0, 1, h, strada.darkened(0.2))
	# isolati
	for k in 120:
		var x := rng.randi_range(2, w - 6)
		var y := rng.randi_range(2, h - 6)
		if img.get_pixel(x, y) == mare:
			continue
		_rect(img, x, y, 3, 2, Color("262636"))
	var t := _tex(img)
	_cache["mappa"] = t
	return t


## Illustrazione del luogo (200x56): cielo notturno e una silhouette tipica.
static func scena_luogo(tipo: String) -> ImageTexture:
	var chiave := "scena_" + tipo
	if _cache.has(chiave):
		return _cache[chiave]
	var w := 200
	var h := 56
	var img := _nuova(w, h)
	var bande := [Color("0b0b16"), BLU_NOTTE, Color("1c2040"), Color("2a2c52")]
	for y in h:
		var i := mini(y * bande.size() / h, bande.size() - 1)
		_rect(img, 0, y, w, 1, bande[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tipo)
	for k in 25:
		_px(img, rng.randi_range(0, w - 1), rng.randi_range(0, 22), Color("8a8aa8"))
	# skyline lontano
	var lontano := Color("20284a")
	var x := 0
	while x < w:
		var bw := rng.randi_range(8, 18)
		var bh := rng.randi_range(10, 26)
		_rect(img, x, h - bh, bw, bh, lontano)
		x += bw + 1
	var scuro := Color("0f0f1a")
	var acc: Color = COLORI_LUOGO.get(tipo, SABBIA)
	var luce := SABBIA
	_rect(img, 0, h - 4, w, 4, Color("0a0a10"))
	match tipo:
		"casa":
			_rect(img, 70, 18, 60, 34, scuro)
			_poligono(img, [Vector2(66, 18), Vector2(100, 6), Vector2(134, 18)], scuro)
			_rect(img, 80, 26, 8, 8, luce)
			_rect(img, 112, 26, 8, 8, Color("181828"))
			_rect(img, 96, 38, 8, 14, Color("2a2018"))
		"ospedale":
			_rect(img, 50, 10, 100, 42, Color("1a1a28"))
			for wy in range(16, 46, 8):
				for wx in range(56, 146, 10):
					_rect(img, wx, wy, 5, 4, Color("8fb0c8") if rng.randf() < 0.5 else Color("202034"))
			_rect(img, 96, 2, 8, 2, ROSSO)
			_rect(img, 99, 0, 2, 8, ROSSO)
		"porto":
			_rect(img, 0, 44, w, 8, Color("12263e"))
			_rect(img, 40, 8, 4, 40, scuro)
			_rect(img, 40, 8, 50, 3, scuro)
			_rect(img, 84, 11, 1, 16, GRIGIO)
			for k in 5:
				_rect(img, 110 + k * 16, 34 - (k % 2) * 8, 14, 10 + (k % 2) * 8, [Color("6a2030"), Color("2f5d4a"), Color("3d4f7a")][k % 3])
		"piazza":
			_rect(img, 90, 34, 20, 4, GRIGIO)
			_rect(img, 98, 26, 4, 8, GRIGIO)
			for k in 4:
				_rect(img, 20 + k * 44, 30, 26, 18, scuro)
				_rect(img, 18 + k * 44, 26, 30, 4, [ROSSO, VERDE, GIALLO, Color("4a6fb0")][k])
		"villa":
			_rect(img, 60, 16, 80, 36, scuro)
			_rect(img, 60, 16, 80, 2, acc)
			for k in 12:
				_rect(img, 20 + k * 14, 36, 2, 16, GRIGIO)
			_rect(img, 20, 36, 160, 2, GRIGIO)
			_disco(img, 30, 26, 10, Color("1f3a2a"))
			_disco(img, 172, 24, 12, Color("1f3a2a"))
		"stazione":
			_rect(img, 40, 14, 120, 4, acc)
			_rect(img, 50, 18, 3, 34, GRIGIO)
			_rect(img, 146, 18, 3, 34, GRIGIO)
			_rect(img, 80, 34, 8, 18, ROSSO)
			_rect(img, 110, 34, 8, 18, ROSSO)
			_rect(img, 160, 26, 30, 26, scuro)
			_rect(img, 164, 30, 22, 6, GIALLO)
		"chiesa":
			_rect(img, 70, 22, 60, 30, scuro)
			_rect(img, 90, 4, 20, 48, scuro)
			_rect(img, 99, 0, 2, 6, acc)
			_rect(img, 96, 2, 8, 2, acc)
			_rect(img, 96, 14, 8, 10, GIALLO)
		"banca", "palazzo", "questura":
			_rect(img, 40, 14, 120, 38, Color("1a1a28"))
			_poligono(img, [Vector2(36, 14), Vector2(100, 2), Vector2(164, 14)], Color("1a1a28"))
			for k in 6:
				_rect(img, 50 + k * 20, 18, 6, 32, Color("2a2a3a"))
			_rect(img, 96, 6, 8, 4, acc)
		"agenzia", "bottega", "bar", "bisca":
			_rect(img, 50, 14, 100, 38, scuro)
			_rect(img, 46, 22, 108, 4, acc)
			_rect(img, 60, 32, 30, 16, Color("2a2a1a") if tipo != "bisca" else Color("401018"))
			_rect(img, 110, 32, 14, 20, Color("2a2018"))
			_rect(img, 62, 34, 26, 2, acc.lightened(0.3))
		"magazzino":
			_rect(img, 30, 16, 140, 36, Color("1a1416"))
			_poligono(img, [Vector2(26, 16), Vector2(100, 6), Vector2(174, 16)], Color("1a1416"))
			_rect(img, 84, 28, 32, 24, Color("2a2a2a"))
			for k in 6:
				_rect(img, 34 + k * 9, 40, 8, 12, Color("5a4030"))
		"laboratorio":
			_rect(img, 40, 20, 120, 32, scuro)
			_rect(img, 50, 42, 30, 8, Color("50b080"))
			_rect(img, 120, 42, 30, 8, Color("50b080").darkened(0.4))
		"catacombe":
			_rect(img, 0, 20, w, 36, Color("1a1410"))
			for k in 5:
				_disco(img, 20 + k * 40, 36, 12, Color("0a0806"))
				_rect(img, 8 + k * 40, 36, 24, 16, Color("0a0806"))
				_px(img, 20 + k * 40, 30, GIALLO)
	var t := _tex(img)
	_cache[chiave] = t
	return t
