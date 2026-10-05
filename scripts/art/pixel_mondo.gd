class_name PixelMondo
extends RefCounted
## Pixel art procedurale del mondo esplorabile: stanze (pavimento, muri,
## porte) per tema, oggetti di scena, personaggi in quattro direzioni con
## passo a tre fotogrammi, ritratti con espressioni per i dialoghi. Nessun file
## immagine: tutto nasce da rettangoli e rumore deterministico, a 16 pixel per
## piastrella, e viene ingrandito a blocchi dalla scena.

const T := 16

const TEMI := {
	"casa": {"pav": "assi", "p1": "6a4a30", "p2": "5a3e28", "muro": "carta", "m1": "8a7a5a", "m2": "a89870", "cap": "3a2a20"},
	"ospedale": {"pav": "piastrelle", "p1": "c8d0d0", "p2": "a8b4b4", "muro": "liscio", "m1": "9ab8a8", "m2": "c0d8c8", "cap": "4a5a5a"},
	"osteria": {"pav": "assi", "p1": "4a3020", "p2": "3a2418", "muro": "mattoni", "m1": "7a3a28", "m2": "5a2a1c", "cap": "2a1810"},
	"porto": {"pav": "cemento", "p1": "6a6a6e", "p2": "5a5a5e", "muro": "mare", "m1": "1e3a5a", "m2": "2e5a7a", "cap": "3a2a1a", "aperto": true},
	"piazza": {"pav": "ciottoli", "p1": "8a7a6a", "p2": "6a5a4a", "muro": "facciate", "m1": "b08a60", "m2": "8a6a48", "cap": "4a3a2a", "aperto": true},
	"chiesa": {"pav": "scacchi", "p1": "d8d0c0", "p2": "3a3a40", "muro": "pietra", "m1": "8a8478", "m2": "6a645a", "cap": "3a3630"},
	"questura": {"pav": "linoleum", "p1": "a89a70", "p2": "988a62", "muro": "liscio", "m1": "c8b060", "m2": "d8c070", "cap": "4a4030"},
	"stazione": {"pav": "asfalto", "p1": "3a3a40", "p2": "2e2e34", "muro": "neon", "m1": "1a1a24", "m2": "e94560", "cap": "101018", "aperto": true},
	"giardini": {"pav": "erba", "p1": "3a6a3a", "p2": "2e5a2e", "muro": "siepe", "m1": "2a4a2a", "m2": "1e3a1e", "cap": "1a2a1a", "aperto": true},
	"banca": {"pav": "scacchi", "p1": "e8e0d0", "p2": "a89880", "muro": "legno", "m1": "5a3a28", "m2": "7a5038", "cap": "2a1a10"},
	"agenzia": {"pav": "moquette", "p1": "5a3a6a", "p2": "4a2e5a", "muro": "liscio", "m1": "c8c0d0", "m2": "e0d8e8", "cap": "3a304a"},
	"bottega": {"pav": "assi", "p1": "5a4a30", "p2": "4a3c26", "muro": "legno", "m1": "4a3a28", "m2": "6a5238", "cap": "2a2014"},
	"bisca": {"pav": "moquette", "p1": "2a4a34", "p2": "1e3a28", "muro": "carta", "m1": "5a1a20", "m2": "7a2a2a", "cap": "200a0c"},
	"retro": {"pav": "moquette", "p1": "5a1a20", "p2": "4a1218", "muro": "legno", "m1": "3a2018", "m2": "5a3020", "cap": "1a0a08"},
	"ring": {"pav": "cemento", "p1": "4a4a48", "p2": "3e3e3c", "muro": "rete", "m1": "2a2a2a", "m2": "6a6a6a", "cap": "151515"},
	"magazzino": {"pav": "cemento", "p1": "4e4e52", "p2": "424246", "muro": "lamiera", "m1": "3a4048", "m2": "4a5058", "cap": "1a1e24"},
	"bar": {"pav": "scacchi", "p1": "c0b098", "p2": "5a4030", "muro": "carta", "m1": "4a5a6a", "m2": "5a6a7a", "cap": "1a2028"},
	"villa": {"pav": "erba", "p1": "3a4a2a", "p2": "2e3a20", "muro": "rudere", "m1": "6a6050", "m2": "4a4438", "cap": "2a2620", "aperto": true},
	"aste": {"pav": "moquette", "p1": "7a1a20", "p2": "6a1218", "muro": "carta", "m1": "6a5020", "m2": "8a6a30", "cap": "2a1a08"},
	"cripta": {"pav": "pietra", "p1": "3a3632", "p2": "2e2a26", "muro": "teschi", "m1": "4a4440", "m2": "c8c0a8", "cap": "151210"},
}

static var _cache: Dictionary = {}


static func _c(hex: String) -> Color:
	return Color(hex)


static func _r(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var x0 := maxi(x, 0)
	var y0 := maxi(y, 0)
	var x1 := mini(x + w, img.get_width())
	var y1 := mini(y + h, img.get_height())
	if x1 > x0 and y1 > y0:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), c)


static func _p(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _o(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	_r(img, x, y, w, 1, c)
	_r(img, x, y + h - 1, w, 1, c)
	_r(img, x, y, 1, h, c)
	_r(img, x + w - 1, y, 1, h, c)


static func _disco(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(int(cy - ry), int(cy + ry) + 1):
		for x in range(int(cx - rx), int(cx + rx) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_p(img, x, y, c)


static func _h(x: int, y: int, s: int = 0) -> int:
	var n := x * 374761393 + y * 668265263 + s * 2147483647
	n = (n ^ (n >> 13)) * 1274126177
	return absi(n ^ (n >> 16))


static func _nuova(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


# =================================================================== stanze

static func _pavimento(img: Image, tema: Dictionary, x: int, y: int) -> void:
	var a := _c(tema.p1)
	var b := _c(tema.p2)
	var px := x * T
	var py := y * T
	match tema.pav:
		"assi":
			for k in 4:
				var col := a if (k + (x if k % 2 == 0 else x + 1)) % 2 == 0 else a.lerp(b, 0.6)
				_r(img, px, py + k * 4, T, 4, col)
				_r(img, px, py + k * 4 + 3, T, 1, b.darkened(0.25))
				_r(img, px + (_h(x, y + k) % 12) + 2, py + k * 4, 1, 3, b.darkened(0.2))
		"piastrelle", "linoleum":
			_r(img, px, py, T, T, a)
			_r(img, px, py, T, 1, b)
			_r(img, px, py, 1, T, b)
			if tema.pav == "piastrelle":
				_p(img, px + 3 + _h(x, y) % 9, py + 4 + _h(y, x) % 8, b.lightened(0.2))
		"scacchi":
			_r(img, px, py, T, T, a if (x + y) % 2 == 0 else b)
			_r(img, px, py, T, 1, Color(0, 0, 0, 0.15))
		"cemento", "asfalto":
			_r(img, px, py, T, T, a)
			for k in 5:
				var hh := _h(x * 7 + k, y * 3)
				_p(img, px + hh % T, py + (hh / T) % T, b)
			if _h(x, y, 3) % 9 == 0:
				for k in 6:
					_p(img, px + 3 + k, py + 6 + (k % 3), b.darkened(0.3))
		"ciottoli":
			_r(img, px, py, T, T, b.darkened(0.3))
			for j in 4:
				for i in 4:
					var off := 2 if j % 2 == 1 else 0
					var col := a.lerp(b, float(_h(x * 4 + i, y * 4 + j) % 4) / 5.0)
					_r(img, px + i * 4 + off, py + j * 4, 3, 3, col)
		"moquette":
			_r(img, px, py, T, T, a)
			for k in 8:
				var hh := _h(x * 11 + k, y * 5)
				_p(img, px + hh % T, py + (hh / T) % T, b)
			if (x + y) % 3 == 0:
				_p(img, px + 8, py + 8, a.lightened(0.15))
		"erba":
			_r(img, px, py, T, T, a)
			for k in 6:
				var hh := _h(x * 13 + k, y * 7)
				var gx := px + hh % T
				var gy := py + (hh / T) % (T - 2)
				_p(img, gx, gy, b)
				_p(img, gx, gy + 1, b.darkened(0.2))
			if _h(x, y, 5) % 11 == 0:
				_p(img, px + 7, py + 7, _c("e8d050"))
		"pietra":
			_r(img, px, py, T, T, a)
			_r(img, px, py + 7, T, 1, b.darkened(0.3))
			_r(img, px + (4 if y % 2 == 0 else 11), py, 1, 7, b.darkened(0.3))
			_r(img, px + (9 if y % 2 == 0 else 2), py + 8, 1, 8, b.darkened(0.3))
			_p(img, px + _h(x, y) % T, py + _h(y, x) % T, b.lightened(0.1))


static func _muro_faccia(img: Image, tema: Dictionary, x: int, w: int) -> void:
	var a := _c(tema.m1)
	var b := _c(tema.m2)
	var px := x * T
	var py := T
	match tema.muro:
		"carta":
			_r(img, px, py, T, T, a)
			for k in range(0, T, 4):
				_r(img, px + k + 1, py, 1, T, b)
			_r(img, px, py + T - 3, T, 3, a.darkened(0.35))
		"liscio":
			_r(img, px, py, T, T, a)
			_r(img, px, py + 9, T, 1, b)
			_r(img, px, py + T - 3, T, 3, a.darkened(0.3))
		"mattoni":
			_r(img, px, py, T, T, b)
			for j in 4:
				var off := 4 if j % 2 == 1 else 0
				for i in range(-1, 3):
					_r(img, px + i * 8 + off + 1, py + j * 4, 7, 3, a.lerp(b, float(_h(x * 3 + i, j) % 3) / 4.0))
		"pietra", "rudere":
			_r(img, px, py, T, T, b)
			for j in 3:
				for i in 2:
					var off := 4 if j % 2 == 1 else 0
					_r(img, px + i * 8 + off, py + j * 5 + 1, 7, 4, a.lerp(b, float(_h(x * 2 + i, j) % 3) / 5.0))
			if tema.muro == "rudere" and _h(x, 9) % 3 == 0:
				_r(img, px + 3, py + 2, 3, 10, _c("3a5a2a"))
		"legno":
			_r(img, px, py, T, T, a)
			_r(img, px, py, T, 2, b)
			_r(img, px + 1, py + 4, T - 2, 8, b)
			_r(img, px + 2, py + 5, T - 4, 6, a.lightened(0.05))
		"teschi":
			_r(img, px, py, T, T, a.darkened(0.3))
			for i in 2:
				for j in 2:
					var cx := px + 4 + i * 8
					var cy := py + 4 + j * 7
					_r(img, cx - 2, cy - 2, 5, 4, b)
					_p(img, cx - 1, cy - 1, _c("151210"))
					_p(img, cx + 1, cy - 1, _c("151210"))
					_r(img, cx - 1, cy + 2, 3, 1, b.darkened(0.3))
		"rete":
			_r(img, px, py, T, T, a)
			for k in T:
				_p(img, px + k, py + (k % 8), b)
				_p(img, px + k, py + 7 - (k % 8), b)
				_p(img, px + k, py + 8 + (k % 8), b)
		"lamiera":
			_r(img, px, py, T, T, a)
			for k in range(0, T, 3):
				_r(img, px + k, py, 1, T, b)
			_r(img, px, py + 12, T, 1, _c("8a4a20"))
		"mare":
			for j in T:
				var col := a.lerp(b, float(j) / T)
				_r(img, px, py + j - T, T, 1, col.darkened(0.2))
				_r(img, px, py + j, T, 1, col)
			for k in 3:
				var hh := _h(x, k)
				_r(img, px + hh % 12, py - T + 4 + k * 8, 4, 1, b.lightened(0.3))
			_r(img, px, py + T - 3, T, 3, _c("5a4a3a"))
			_r(img, px, py + T - 3, T, 1, _c("7a6a5a"))
		"facciate":
			_r(img, px, py - T, T, 2 * T, a if (x / 3) % 2 == 0 else b)
			_r(img, px + 4, py - 10, 8, 6, _c("2a2a3a"))
			_r(img, px + 4, py - 10, 8, 1, _c("e8e0c0").darkened(0.3))
			_r(img, px + 3, py + 2, 10, 4, _c("c84030") if (x % 3) == 1 else _c("308050"))
			_r(img, px + 5, py + 6, 6, 10, _c("3a2a20"))
			_r(img, px, py + T - 2, T, 2, a.darkened(0.4))
		"neon":
			_r(img, px, py - T, T, 2 * T, a)
			_r(img, px, py - 6, T, 2, b)
			_r(img, px + 2, py + 2, 12, 10, _c("2a3a4a"))
			_r(img, px + 2, py + 2, 12, 1, _c("8fb0c8"))
		"siepe":
			_r(img, px, py - T, T, 2 * T, a)
			for k in 10:
				var hh := _h(x * 9 + k, 2)
				_disco(img, px + hh % T, py - T + 4 + (hh / T) % 24, 3, 3, b if k % 2 == 0 else a.lightened(0.1))
			for k in range(1, T, 5):
				_r(img, px + k, py + 6, 1, 10, _c("1a1a1a"))
			_r(img, px, py + 8, T, 1, _c("1a1a1a"))


static func stanza(s: Dictionary) -> ImageTexture:
	var chiave: String = "stanza_" + str(s.id)
	if _cache.has(chiave):
		return _cache[chiave]
	var w: int = s.w
	var h: int = s.h
	var tema: Dictionary = TEMI.get(s.tema, TEMI.casa)
	var img := _nuova(w * T, h * T)
	for y in range(1, h):
		for x in w:
			_pavimento(img, tema, x, y)
	var cap := _c(tema.cap)
	_r(img, 0, 0, w * T, T, cap)
	for x in w:
		_muro_faccia(img, tema, x, w)
	if not tema.get("aperto", false):
		_r(img, 0, 0, w * T, 4, cap.darkened(0.4))
	_r(img, 0, 0, 6, h * T, cap)
	_r(img, w * T - 6, 0, 6, h * T, cap)
	_r(img, 6, 2 * T, 2, (h - 3) * T, Color(0, 0, 0, 0.25))
	_r(img, 0, (h - 1) * T + 6, w * T, T - 6, cap)
	_r(img, 0, (h - 1) * T + 6, w * T, 1, cap.lightened(0.2))
	_r(img, 6, 2 * T, (w - 2) * T - 4, 3, Color(0, 0, 0, 0.3))
	for p in s.porte:
		_porta(img, s, tema, p)
	var t := _tex(img)
	_cache[chiave] = t
	return t


static func _porta(img: Image, s: Dictionary, tema: Dictionary, p: Dictionary) -> void:
	var x: int = p.pos[0]
	var y: int = p.pos[1]
	var w: int = s.w
	var h: int = s.h
	var px := x * T
	var py := y * T
	var buio := Color("0a0a0e")
	var legno := Color("4a3020")
	if p.get("scala", false):
		for k in 5:
			_r(img, px + 1, py + 2 + k * 3, T - 2, 3, Color("3a3632").darkened(k * 0.15))
			_r(img, px + 1, py + 2 + k * 3, T - 2, 1, Color("6a6458").darkened(k * 0.12))
		_o(img, px, py + 1, T, T - 1, Color("151210"))
		return
	if y == h - 1:
		_pavimento(img, tema, x, y)
		_r(img, px, py, T, T, Color(0, 0, 0, 0))
		_pavimento(img, tema, x, y)
		_r(img, px + 2, py + 2, T - 4, T - 4, Color("c8a97e").darkened(0.4))
		_r(img, px + 6, py + 5, 4, 6, Color("f0c050"))
		_r(img, px + 4, py + 9, 8, 2, Color("f0c050"))
		_r(img, px + 5, py + 11, 6, 1, Color("f0c050"))
		_r(img, px + 7, py + 12, 2, 1, Color("f0c050"))
	elif y <= 1:
		_r(img, px + 1, T - 2, T - 2, T + 2, legno.darkened(0.3))
		_r(img, px + 3, T, T - 6, T, buio if p.verso == "@mappa" else legno)
		_r(img, px + 3, T, T - 6, 1, legno.lightened(0.2))
		_p(img, px + T - 5, T + 9, Color("f0c050"))
	elif x == 0 or x == w - 1:
		_pavimento(img, tema, x, y)
		_r(img, px + (0 if x == 0 else T - 4), py - 6, 4, T + 6, legno.darkened(0.3))
	if p.has("richiede"):
		_r(img, px + 6, py + 6 if y > 1 else T + 6, 4, 4, Color("e94560"))


# =================================================================== oggetti

static func oggetto(tipo: String, dim: Array) -> ImageTexture:
	var w: int = int(dim[0]) * T
	var h: int = int(dim[1]) * T
	var chiave := "ogg_%s_%dx%d" % [tipo, w, h]
	if _cache.has(chiave):
		return _cache[chiave]
	var img := _nuova(w, h + 8)
	_disegna_oggetto(img, tipo, w, h)
	var t := _tex(img)
	_cache[chiave] = t
	return t


## Gli oggetti si disegnano in un riquadro alto 8 pixel più della loro
## impronta: la parte in eccesso sporge in alto, sopra la piastrella dietro.
static func _disegna_oggetto(img: Image, tipo: String, w: int, h: int) -> void:
	var o := 8
	var ombra := Color(0, 0, 0, 0.3)
	var nero := Color("0d0d0d")
	_r(img, 2, o + h - 3, w - 4, 3, ombra)
	match tipo:
		"divano":
			_r(img, 0, o - 2, w, h, Color("6a2a30"))
			_r(img, 0, o - 2, w, 5, Color("8a3a40"))
			_r(img, 2, o + 4, w - 4, h - 8, Color("7a3238"))
			_o(img, 0, o - 2, w, h, nero)
		"cornice", "quadro":
			_r(img, 3, o - 4, w - 6, h - 2, Color("c8a040"))
			_r(img, 5, o - 2, w - 10, h - 6, Color("8fb0c8") if tipo == "cornice" else Color("c84030"))
			if tipo == "cornice":
				_r(img, 6, o + 2, w - 12, 4, Color("d9b98f"))
				_r(img, 6, o + 6, w - 12, h - 12, Color("e8e8e8"))
		"scrivania", "tavolino":
			_r(img, 0, o, w, h - 6, Color("5a3a24"))
			_r(img, 0, o, w, 3, Color("7a5234"))
			_r(img, 1, o + h - 6, 2, 5, Color("3a2414"))
			_r(img, w - 3, o + h - 6, 2, 5, Color("3a2414"))
			if tipo == "scrivania":
				_r(img, 4, o - 3, 8, 4, Color("e8e8e8"))
				_r(img, w - 10, o - 5, 5, 6, Color("c8a040"))
			else:
				_r(img, 6, o - 1, 6, 3, Color("e8e0c0"))
			_o(img, 0, o, w, h - 6, nero)
		"letto", "lettino":
			_r(img, 0, o - 4, w, h + 2, Color("4a3020") if tipo == "letto" else Color("a0a8b0"))
			_r(img, 2, o - 2, w - 4, h - 2, Color("e8e8e8"))
			_r(img, 3, o - 1, w - 6, 6, Color("f8f8f8"))
			_r(img, 2, o + 8, w - 4, h - 12, Color("4a5a8a") if tipo == "letto" else Color("8fb0c8"))
			if tipo == "lettino":
				_disco(img, w / 2, o + 3, 4, 3, Color("d9b98f"))
				_r(img, w / 2 - 3, o + 1, 6, 2, Color("e0e0e0"))
			_o(img, 0, o - 4, w, h + 2, nero)
		"culla":
			_r(img, 1, o, w - 2, h - 4, Color("e8d8b8"))
			for k in range(2, w - 2, 3):
				_r(img, k, o - 3, 1, h - 3, Color("c8b898"))
			_r(img, 1, o - 3, w - 2, 1, Color("c8b898"))
			_r(img, 3, o + 2, w - 6, 5, Color("e8b0c0"))
		"armadio", "scaffale", "frigo", "distributore", "jukebox", "cassaforte":
			var col: Color = {"armadio": Color("4a3020"), "scaffale": Color("5a4a30"), "frigo": Color("d8d8d8"),
				"distributore": Color("a03030"), "jukebox": Color("8a4a8a"), "cassaforte": Color("4a4e58")}[tipo]
			_r(img, 0, o - 8, w, h + 6, col)
			_o(img, 0, o - 8, w, h + 6, nero)
			match tipo:
				"armadio":
					_r(img, w / 2, o - 6, 1, h + 2, nero)
					_p(img, w / 2 - 2, o, Color("c8a040"))
					_p(img, w / 2 + 2, o, Color("c8a040"))
				"scaffale":
					for k in 3:
						_r(img, 1, o - 3 + k * 5, w - 2, 1, nero)
						for i in range(2, w - 3, 4):
							_r(img, i, o - 6 + k * 5, 3, 3, Color("a08060").darkened(float(_h(i, k) % 3) * 0.15))
				"frigo":
					_r(img, 1, o - 1, w - 2, 1, Color("a0a0a0"))
					_r(img, w - 4, o - 5, 1, 3, Color("808080"))
					_r(img, 4, o + 1, 4, 3, Color("f0c050"))
				"distributore":
					_r(img, 3, o - 5, w - 6, 7, Color("2a3a4a"))
					_r(img, 4, o + 4, w - 8, 2, nero)
				"jukebox":
					_disco(img, w / 2, o - 3, w / 2 - 1, 5, Color("f0c050"))
					_r(img, 3, o + 2, w - 6, 3, Color("e94560"))
				"cassaforte":
					_disco(img, w / 2, o + 1, 3, 3, Color("8a8e98"))
					_r(img, w / 2, o - 2, 1, 3, nero)
		"fornello":
			_r(img, 0, o - 2, w, h, Color("c8c8c8"))
			_r(img, 0, o - 2, w, 6, Color("2a2a2a"))
			for k in range(4, w, 8):
				_disco(img, k, o + 1, 2, 1.5, Color("e94560").darkened(0.3))
			_r(img, w / 2 - 4, o - 5, 8, 4, Color("8a8a8a"))
			_o(img, 0, o - 2, w, h, nero)
		"tavolo":
			_r(img, 0, o, w, h - 5, Color("7a5234"))
			_r(img, 0, o, w, 2, Color("9a6a44"))
			_r(img, 1, o + h - 5, 2, 4, Color("3a2414"))
			_r(img, w - 3, o + h - 5, 2, 4, Color("3a2414"))
			_r(img, 3, o + 2, 4, 3, Color("e8e8e8"))
			_r(img, w - 8, o + 3, 3, 3, Color("6a2030"))
			_o(img, 0, o, w, h - 5, nero)
		"sedie":
			for k in range(0, w, 8):
				_r(img, k + 1, o + 2, 6, 6, Color("e08030"))
				_r(img, k + 1, o - 2, 6, 4, Color("c06020"))
				_r(img, k + 2, o + 8, 1, 4, nero)
				_r(img, k + 5, o + 8, 1, 4, nero)
		"incubatrice":
			_r(img, 2, o + 6, w - 4, h - 8, Color("c8d0d8"))
			_r(img, 0, o - 6, w, 14, Color(0.7, 0.85, 1.0, 0.55))
			_o(img, 0, o - 6, w, 14, Color("e8f0f8"))
			_disco(img, w / 2, o + 1, 5, 3, Color("e8c8a8"))
			_disco(img, w / 2 - 4, o, 2.5, 2.5, Color("e8c8a8"))
			_r(img, w / 2 - 1, o - 1, 6, 4, Color("f0e0e8"))
			_r(img, w - 6, o + 8, 4, 3, Color("3d7a5a"))
			_r(img, 3, o + 8, 2, 2, Color("f0c050"))
		"monitor":
			_r(img, 1, o - 6, w - 2, 10, Color("1a1a1a"))
			for k in range(2, w - 2):
				_p(img, k, o - 1 - int(3.0 * absf(sin(k * 0.9))), Color("4aff7a"))
			_r(img, w / 2 - 1, o + 4, 2, h - 6, Color("8a8a8a"))
		"bancone":
			_r(img, 0, o - 6, w, h + 4, Color("5a3420"))
			_r(img, 0, o - 6, w, 4, Color("8a5a38"))
			_r(img, 0, o + h - 4, w, 2, Color("3a2010"))
			for k in range(6, w - 4, 14):
				_r(img, k, o - 10, 3, 5, Color("3d7a5a").lightened(float(_h(k, 1) % 3) * 0.2))
				_r(img, k + 5, o - 9, 2, 4, Color("e8e0c0"))
			_o(img, 0, o - 6, w, h + 4, nero)
		"casse":
			for j in range(0, h, 12):
				for i in range(0, w, 12):
					var col := Color("8a6a40").darkened(float(_h(i, j) % 3) * 0.12)
					_r(img, i + 1, o + j - 6, 11, 11, col)
					_o(img, i + 1, o + j - 6, 11, 11, Color("3a2814"))
					_r(img, i + 1, o + j - 1, 11, 1, Color("3a2814"))
					if _h(i, j, 2) % 4 == 0:
						_r(img, i + 3, o + j - 4, 4, 2, Color("c03030"))
		"gru":
			_r(img, 4, o - 8, 6, h + 6, Color("e0a020"))
			for k in range(o - 8, o + h - 2, 4):
				_r(img, 4, k, 6, 1, Color("8a6010"))
			_r(img, 0, o - 8, w, 4, Color("e0a020"))
			_r(img, w - 6, o - 4, 1, 12, nero)
			_r(img, w - 8, o + 8, 5, 3, Color("6a6a6a"))
		"bitta":
			_disco(img, w / 2, o + 2, 5, 4, Color("2a2a2a"))
			_r(img, w / 2 - 3, o - 4, 6, 7, Color("3a3a3a"))
			_r(img, w / 2 - 5, o - 5, 10, 3, Color("4a4a4a"))
		"fontana":
			_disco(img, w / 2, o + h / 2, w / 2 - 1, h / 2 - 2, Color("8a8478"))
			_disco(img, w / 2, o + h / 2, w / 2 - 4, h / 2 - 5, Color("4a5a6a"))
			_r(img, w / 2 - 2, o - 4, 4, h / 2 + 4, Color("a8a090"))
			_disco(img, w / 2, o - 4, 4, 3, Color("a8a090"))
		"bancarella":
			_r(img, 0, o - 6, w, 6, Color("e8e8e8"))
			for k in range(0, w, 6):
				_r(img, k, o - 6, 3, 6, Color("c03030"))
			_r(img, 1, o, w - 2, h - 4, Color("7a5234"))
			for k in range(3, w - 3, 5):
				_disco(img, k, o + 2, 2, 2, [Color("e08030"), Color("4a7c3a"), Color("e8c050")][k % 3])
		"botteghe":
			for k in range(0, w, 16):
				_r(img, k, o - 8, 16, h + 6, Color("b08a60").darkened(float(k / 16 % 2) * 0.15))
				_r(img, k + 1, o - 8, 14, 4, [Color("c84030"), Color("3080a0"), Color("308050"), Color("a050c0")][k / 16 % 4])
				_r(img, k + 3, o - 3, 10, 7, Color("2a3a4a"))
				_r(img, k + 3, o - 3, 10, 1, Color("8fb0c8"))
				_r(img, k + 6, o + 4, 4, h - 6, Color("3a2a20"))
		"folla":
			for k in range(0, w, 7):
				var col: Color = [Color("6a3a4a"), Color("3a5a6a"), Color("7a6a3a"), Color("4a4a6a")][(k / 7) % 4]
				var dy := (k / 7 % 2) * 3
				_r(img, k + 1, o - 2 + dy, 5, 9, col)
				_disco(img, k + 3.5, o - 4 + dy, 2.5, 2.5, Color("d9b98f"))
				_r(img, k + 1, o - 7 + dy, 5, 2, Color("2a2018"))
				if k % 14 == 0:
					_r(img, k + 5, o + 2 + dy, 3, 3, Color("a06030"))
		"altare", "podio":
			_r(img, 0, o - 6, w, h + 4, Color("e8e0d0") if tipo == "altare" else Color("5a3a24"))
			_r(img, 0, o - 6, w, 3, Color("c8a040"))
			if tipo == "altare":
				_r(img, w / 2 - 1, o - 14, 2, 9, Color("c8a040"))
				_r(img, w / 2 - 4, o - 11, 8, 2, Color("c8a040"))
			else:
				_r(img, w / 2 - 3, o - 9, 6, 3, Color("e8e0c0"))
			_o(img, 0, o - 6, w, h + 4, nero)
		"ceri", "candele":
			_r(img, 0, o + 2, w, h - 6, Color("3a3028"))
			for k in range(2, w - 1, 3):
				var hh := 4 + _h(k, 4) % 5
				_r(img, k, o + 2 - hh, 2, hh, Color("e8e0c8"))
				_p(img, k, o + 1 - hh, Color("f0c050"))
				_p(img, k, o - hh, Color("e08030"))
		"banchi":
			_r(img, 0, o - 2, w, 6, Color("5a3a24"))
			_r(img, 0, o + 4, w, 3, Color("3a2414"))
			_r(img, 0, o - 2, w, 1, Color("7a5234"))
		"registro", "teca":
			if tipo == "teca":
				_r(img, 0, o - 4, w, h + 2, Color("4a3020"))
				_r(img, 2, o - 2, w - 4, 7, Color(0.7, 0.85, 1.0, 0.6))
				for k in range(4, w - 4, 6):
					_disco(img, k, o + 1, 2, 2, [Color("f0c050"), Color("c8c8d0"), Color("e94560")][k % 3])
			else:
				_r(img, 0, o, w, h - 6, Color("5a3a24"))
				_r(img, w / 2 - 9, o - 4, 18, 9, Color("e8e0c8"))
				_r(img, w / 2, o - 4, 1, 9, Color("8a7a5a"))
				for k in 3:
					_r(img, w / 2 - 7, o - 2 + k * 2, 5, 1, Color("5a5a6e"))
					_r(img, w / 2 + 2, o - 2 + k * 2, 5, 1, Color("5a5a6e"))
		"sportello", "cassa":
			_r(img, 0, o - 8, w, h + 6, Color("6a5a48") if tipo == "sportello" else Color("3a3a40"))
			_r(img, 2, o - 6, w - 4, 7, Color(0.75, 0.85, 0.9, 0.6))
			for k in range(8, w - 2, 16):
				_r(img, k, o - 6, 1, 7, Color("4a3a28"))
			_r(img, 0, o + 1, w, 2, Color("c8a040") if tipo == "sportello" else Color("e94560"))
			_o(img, 0, o - 8, w, h + 6, nero)
		"bacheca":
			_r(img, 0, o - 4, w, h - 2, Color("8a6a40"))
			for k in range(3, w - 4, 7):
				_r(img, k, o - 2, 5, 6, Color("e8e0c8"))
				_disco(img, k + 2.5, o, 1.5, 1.5, Color("6a5a4a"))
		"pompe":
			for k in range(2, w, 16):
				_r(img, k, o - 8, 10, h + 4, Color("e94560"))
				_r(img, k + 2, o - 6, 6, 4, Color("e8e8e8"))
				_r(img, k + 10, o - 2, 2, 6, nero)
				_o(img, k, o - 8, 10, h + 4, nero)
		"cancello":
			_r(img, 0, o - 8, w, 2, Color("1a1a1a"))
			for k in range(1, w, 3):
				_r(img, k, o - 8, 1, h + 4, Color("1a1a1a"))
				_p(img, k, o - 9, Color("c8a040"))
			_r(img, 0, o + 2, w, 1, Color("1a1a1a"))
		"palazzo":
			_r(img, 0, o - 8, w, h + 4, Color("c8b898"))
			for i in range(4, w - 4, 10):
				for j in range(o - 4, o + h - 8, 10):
					_r(img, i, j, 6, 7, Color("2a3a4a"))
			_disco(img, w / 2, o - 2, 5, 5, Color("c8a040"))
			_r(img, w / 2 - 4, o + h - 10, 8, 10, Color("3a2a20"))
		"siepe":
			_r(img, 0, o - 4, w, h, Color("2a4a2a"))
			for k in range(0, w, 4):
				_disco(img, k + 2, o - 4, 3, 3, Color("3a6a3a"))
		"caveau":
			_r(img, 0, o - 8, w, h + 4, Color("4a4e58"))
			_disco(img, w / 2, o + h / 2 - 6, w / 2 - 3, h / 2 - 4, Color("8a8e98"))
			_disco(img, w / 2, o + h / 2 - 6, w / 2 - 7, h / 2 - 8, Color("6a6e78"))
			for k in 6:
				var a := k * PI / 3.0
				_r(img, int(w / 2 + cos(a) * 6) - 1, int(o + h / 2 - 6 + sin(a) * 6) - 1, 3, 3, Color("c8a040"))
		"roulette":
			_r(img, 0, o + 4, w, h - 6, Color("2a4a34"))
			_disco(img, w / 2, o + h / 2 - 4, w / 2 - 2, h / 2 - 4, Color("5a3420"))
			_disco(img, w / 2, o + h / 2 - 4, w / 2 - 5, h / 2 - 7, Color("101010"))
			for k in 12:
				var a := k * TAU / 12.0
				_p(img, int(w / 2 + cos(a) * (w / 2 - 7)), int(o + h / 2 - 4 + sin(a) * (h / 2 - 9)), Color("c03030") if k % 2 == 0 else Color("e8e8e8"))
			_disco(img, w / 2, o + h / 2 - 4, 3, 3, Color("c8a040"))
		"tavolo_verde":
			_r(img, 0, o - 4, w, h, Color("5a3420"))
			_r(img, 2, o - 2, w - 4, h - 4, Color("2a6a44"))
			for k in range(6, w - 6, 9):
				_r(img, k, o + 2, 4, 6, Color("e8e8e8"))
				_p(img, k + 1, o + 3, Color("c03030"))
			for k in 5:
				_disco(img, w / 2 - 6 + k * 3, o + h - 9, 1.5, 1.5, [Color("c03030"), Color("3050a0"), Color("e8e8e8")][k % 3])
			_o(img, 0, o - 4, w, h, nero)
		"ring":
			_r(img, 0, o - 6, w, h + 2, Color("8a7a6a"))
			_r(img, 3, o - 3, w - 6, h - 4, Color("a0482a"))
			for k in 3:
				_o(img, 2 + k, o - 4 + k * 2, w - 4 - k * 2, h - 2 - k * 4, Color("e8e8e8") if k != 1 else Color("c03030"))
			for c in [[0, o - 8], [w - 4, o - 8], [0, o + h - 6], [w - 4, o + h - 6]]:
				_r(img, c[0], c[1], 4, 8, Color("2a2a2a"))
		"furgone":
			_r(img, 0, o - 6, w, h + 2, Color("4a5a3a"))
			_r(img, 0, o - 6, 12, 10, Color("2a3a4a"))
			_r(img, 0, o - 6, w, 2, Color("6a7a5a"))
			_disco(img, 9, o + h - 3, 4, 4, nero)
			_disco(img, w - 9, o + h - 3, 4, 4, nero)
			_o(img, 0, o - 6, w, h + 2, nero)
		"portone":
			_r(img, 0, o - 8, w, h + 6, Color("3a2a1a"))
			_r(img, 2, o - 6, w / 2 - 3, h + 2, Color("5a3a24"))
			_r(img, w / 2 + 1, o - 6, w / 2 - 3, h + 2, Color("5a3a24"))
			_r(img, 4, o + 2, w - 8, 3, Color("e8e0c8"))
			_r(img, w / 2 - 2, o + 2, 4, 3, Color("c03030"))
		"lapide":
			_r(img, 2, o - 6, w - 4, h + 2, Color("6a645a"))
			_r(img, 2, o - 6, w - 4, 2, Color("8a8478"))
			for k in 3:
				_r(img, 4, o - 2 + k * 3, w - 8, 1, Color("3a3630"))
		"ossa":
			for i in range(0, w, 6):
				for j in 2:
					_r(img, i + 1, o - 6 + j * 6, 4, 4, Color("c8c0a8"))
					_p(img, i + 2, o - 5 + j * 6, Color("151210"))
					_p(img, i + 3, o - 5 + j * 6, Color("151210"))
		"altare_rituale":
			_r(img, 0, o - 4, w, h + 2, Color("1a1820"))
			_r(img, 0, o - 4, w, 2, Color("3a3640"))
			_disco(img, w / 2, o + 2, w / 2 - 4, 4, Color("0a0a0e"))
			_disco(img, w / 2, o + 2, w / 2 - 7, 2, Color("c8a97e"))
			for k in [2, w - 4]:
				_r(img, k, o - 10, 2, 6, Color("e8e0c8"))
				_p(img, k, o - 11, Color("e94560"))
		"sarcofago":
			_r(img, 0, o - 4, w, h + 2, Color("5a5448"))
			_r(img, 2, o - 2, w - 4, h - 2, Color("7a7468"))
			_disco(img, 7, o + 2, 3, 3, Color("8a8478"))
			_r(img, 10, o + 1, w - 14, 3, Color("8a8478"))
	img.convert(Image.FORMAT_RGBA8)


# =================================================================== personaggi

static func _asp(id: String) -> Dictionary:
	return DialogoSystem.dati().get("aspetti", {}).get(id, {"pelle": "d9b98f", "capelli": "2a2018", "stile": "corti", "vestito": "4a4a5a", "vestito2": "2a2a3a"})


## Sprite 16x24. direzione: 0 giù, 1 su, 2 sinistra, 3 destra. passo 0-2.
static func personaggio(id: String, direzione: int, passo: int) -> ImageTexture:
	var chiave := "pg_%s_%d_%d" % [id, direzione, passo]
	if _cache.has(chiave):
		return _cache[chiave]
	var a := _asp(id)
	var img := _nuova(16, 24)
	var pelle := _c(a.pelle)
	var cap := _c(a.capelli)
	var v1 := _c(a.vestito)
	var v2 := _c(a.vestito2)
	var nero := Color("0d0d0d")
	var largo: bool = a.get("corpulento", false)
	var bx := 3 if largo else 4
	var bw := 10 if largo else 8
	_disco(img, 8, 22.5, 5, 1.5, Color(0, 0, 0, 0.35))
	var gamba: int = [0, 1, -1][passo]
	var su := 1 if passo != 0 else 0
	if direzione >= 2:
		_r(img, 6, 17, 3, 5 + gamba, v2.darkened(0.4))
		_r(img, 8, 17, 3, 5 - gamba, v2.darkened(0.25))
	else:
		_r(img, 5, 17, 2, 5 + gamba, v2.darkened(0.35))
		_r(img, 9, 17, 2, 5 - gamba, v2.darkened(0.35))
	_r(img, 5, 21 + gamba, 3, 2, nero)
	_r(img, 8, 21 - gamba, 3, 2, nero)
	var lungo: bool = a.stile == "cappuccio" or id == "anselmo" or id == "sirio"
	_r(img, bx, 9 - su, bw, 9 if not lungo else 11, v1)
	_r(img, bx, 9 - su, bw, 1, v1.lightened(0.15))
	if direzione == 0:
		_r(img, 7, 9 - su, 2, 6, v2)
	elif direzione >= 2:
		_r(img, 7 + (2 if direzione == 3 else -2), 10 - su, 2, 5, v1.darkened(0.2))
	var braccio: int = [0, 1, -1][passo]
	if direzione < 2:
		_r(img, bx - 1, 10 - su + braccio, 2, 6, v1.darkened(0.15))
		_r(img, bx + bw - 1, 10 - su - braccio, 2, 6, v1.darkened(0.15))
		_r(img, bx - 1, 16 - su + braccio, 2, 1, pelle)
		_r(img, bx + bw - 1, 16 - su - braccio, 2, 1, pelle)
	else:
		_r(img, 7, 10 - su + braccio, 2, 6, v1.darkened(0.2))
		_r(img, 7, 16 - su + braccio, 2, 1, pelle)
	var hy := 2 - su
	if a.stile == "volpe":
		_r(img, 4, hy + 1, 8, 7, Color("e08030"))
		_r(img, 4, hy - 1, 2, 3, Color("e08030"))
		_r(img, 10, hy - 1, 2, 3, Color("e08030"))
		_r(img, 6, hy + 5, 4, 3, Color("f0f0f0"))
		if direzione != 1:
			_p(img, 6, hy + 3, nero)
			_p(img, 9, hy + 3, nero)
			_p(img, 8, hy + 6, nero)
	else:
		_r(img, 5, hy + 1, 6, 7, pelle)
		_capelli_sprite(img, a, cap, direzione, hy)
		if direzione == 0:
			_p(img, 6, hy + 4, nero)
			_p(img, 9, hy + 4, nero)
			if a.get("occhiali", false):
				_r(img, 5, hy + 4, 6, 1, Color("2a2a2a"))
			if a.get("barba", false):
				_r(img, 5, hy + 6, 6, 2, cap.lerp(pelle, 0.3))
			if a.get("baffi", false):
				_r(img, 6, hy + 6, 4, 1, cap)
			if a.get("rossetto", false):
				_r(img, 7, hy + 6, 2, 1, Color("c02030"))
		elif direzione >= 2:
			var ox := 5 if direzione == 2 else 9
			_p(img, ox, hy + 4, nero)
			_p(img, 4 if direzione == 2 else 11, hy + 5, pelle)
			if a.get("barba", false):
				_r(img, 5, hy + 6, 6, 2, cap.lerp(pelle, 0.3))
	if a.has("cappello"):
		var cc := _c(a.cappello)
		_r(img, 4, hy - 1, 8, 3, cc)
		_r(img, 3, hy + 1, 10, 1, cc.darkened(0.2))
		if id == "sirio":
			_r(img, 4, hy + 1, 8, 1, Color("e94560"))
	if id == "sirio" and direzione != 1:
		_r(img, 12 if direzione != 2 else 2, 12 - su, 2, 3, Color("c8a97e"))
	var out := _contorno(img)
	var t := _tex(out)
	_cache[chiave] = t
	return t


static func _capelli_sprite(img: Image, a: Dictionary, cap: Color, direzione: int, hy: int) -> void:
	match a.stile:
		"calvo":
			_r(img, 5, hy + 1, 6, 1, cap.lerp(_c(a.pelle), 0.7))
		"corti", "spettinati", "riporto":
			_r(img, 5, hy, 6, 2, cap)
			if direzione == 1:
				_r(img, 5, hy, 6, 6, cap)
			if a.stile == "spettinati":
				_p(img, 4, hy + 1, cap)
				_p(img, 11, hy, cap)
		"radi":
			_r(img, 5, hy + 1, 1, 3, cap)
			_r(img, 10, hy + 1, 1, 3, cap)
			if direzione == 1:
				_r(img, 5, hy + 2, 6, 4, cap)
		"chignon":
			_r(img, 5, hy, 6, 2, cap)
			_r(img, 7, hy - 2, 3, 2, cap)
			if direzione == 1:
				_r(img, 5, hy, 6, 5, cap)
		"caschetto":
			_r(img, 4, hy, 8, 3, cap)
			_r(img, 4, hy + 2, 2, 5, cap)
			_r(img, 10, hy + 2, 2, 5, cap)
			if direzione == 1:
				_r(img, 4, hy, 8, 7, cap)
		"lunghi":
			_r(img, 4, hy, 8, 2, cap)
			_r(img, 4, hy + 1, 2, 9, cap)
			_r(img, 10, hy + 1, 2, 9, cap)
			if direzione == 1:
				_r(img, 4, hy, 8, 10, cap)
		"cappuccio":
			_r(img, 4, hy - 1, 8, 4, _c(a.vestito))
			_r(img, 4, hy + 1, 2, 7, _c(a.vestito))
			_r(img, 10, hy + 1, 2, 7, _c(a.vestito))
			if direzione == 1:
				_r(img, 4, hy - 1, 8, 9, _c(a.vestito))


static func _contorno(img: Image) -> Image:
	var out := img.duplicate()
	var nero := Color("0d0d0d")
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < img.get_width() and ny < img.get_height() and img.get_pixel(nx, ny).a > 0.9:
					out.set_pixel(x, y, nero)
					break
	return out


# =================================================================== ritratti

## Ritratto 48x48 per i dialoghi. espressione: neutro, felice, arrabbiato,
## triste, sorpreso, duro, stanco.
static func ritratto(id: String, espressione: String) -> ImageTexture:
	var chiave := "rit_%s_%s" % [id, espressione]
	if _cache.has(chiave):
		return _cache[chiave]
	var a := _asp(id)
	var img := _nuova(48, 48)
	var pelle := _c(a.pelle)
	var ombra := pelle.darkened(0.25)
	var cap := _c(a.capelli)
	var v1 := _c(a.vestito)
	var v2 := _c(a.vestito2)
	var nero := Color("0d0d0d")
	var largo: bool = a.get("corpulento", false)
	_r(img, 6 if largo else 9, 38, 36 if largo else 30, 10, v1)
	_r(img, 20, 38, 8, 10, v2)
	_r(img, 21, 33, 6, 6, ombra)
	if a.stile == "volpe":
		_ritratto_volpe(img, espressione)
	else:
		_disco(img, 24, 22, 11 if largo else 10, 13, pelle)
		_r(img, 14, 27, 20, 1, ombra)
		_disco(img, 13 if not largo else 12, 22, 2, 3, pelle)
		_disco(img, 35 if not largo else 36, 22, 2, 3, pelle)
		_capelli_ritratto(img, a, cap)
		_volto(img, a, espressione, pelle, cap)
		if a.has("cappello"):
			var cc := _c(a.cappello)
			_r(img, 12, 6, 24, 6, cc)
			_r(img, 8, 11, 32, 3, cc.darkened(0.2))
			if id == "sirio":
				_r(img, 12, 10, 24, 2, Color("e94560"))
	if id == "sirio":
		_r(img, 18, 38, 12, 3, Color("3a3a60"))
	var out := _contorno(img)
	var t := _tex(out)
	_cache[chiave] = t
	return t


static func _capelli_ritratto(img: Image, a: Dictionary, cap: Color) -> void:
	match a.stile:
		"calvo":
			_r(img, 17, 10, 14, 2, _c(a.pelle).lightened(0.15))
		"corti", "riporto", "spettinati":
			_disco(img, 24, 13, 11, 5, cap)
			_r(img, 13, 13, 3, 7, cap)
			_r(img, 32, 13, 3, 7, cap)
			if a.stile == "riporto":
				_r(img, 16, 11, 16, 2, cap.lightened(0.15))
			if a.stile == "spettinati":
				for k in [14, 19, 26, 31]:
					_r(img, k, 7, 2, 4, cap)
		"radi":
			_r(img, 13, 16, 3, 8, cap)
			_r(img, 32, 16, 3, 8, cap)
		"chignon":
			_disco(img, 24, 13, 11, 5, cap)
			_disco(img, 24, 7, 5, 4, cap)
			_r(img, 13, 13, 2, 9, cap)
			_r(img, 33, 13, 2, 9, cap)
		"caschetto":
			_disco(img, 24, 14, 13, 7, cap)
			_r(img, 11, 14, 5, 16, cap)
			_r(img, 32, 14, 5, 16, cap)
			_r(img, 15, 13, 18, 3, cap)
		"lunghi":
			_disco(img, 24, 13, 12, 6, cap)
			_r(img, 11, 13, 5, 28, cap)
			_r(img, 32, 13, 5, 28, cap)
		"cappuccio":
			var v := _c(a.vestito)
			_disco(img, 24, 16, 15, 14, v)
			_disco(img, 24, 24, 9, 11, _c(a.pelle))


static func _volto(img: Image, a: Dictionary, espressione: String, pelle: Color, cap: Color) -> void:
	var nero := Color("0d0d0d")
	var bianco := Color("f0f0f0")
	var ey := 20
	var sopr := cap.darkened(0.2) if a.stile != "calvo" else pelle.darkened(0.45)
	match espressione:
		"arrabbiato", "duro":
			_r(img, 16, ey - 4, 6, 1, sopr)
			_r(img, 19, ey - 3, 3, 1, sopr)
			_r(img, 26, ey - 4, 6, 1, sopr)
			_r(img, 26, ey - 3, 3, 1, sopr)
		"triste", "stanco":
			_r(img, 16, ey - 3, 3, 1, sopr)
			_r(img, 19, ey - 4, 3, 1, sopr)
			_r(img, 26, ey - 4, 3, 1, sopr)
			_r(img, 29, ey - 3, 3, 1, sopr)
		"sorpreso":
			_r(img, 16, ey - 6, 6, 1, sopr)
			_r(img, 26, ey - 6, 6, 1, sopr)
		_:
			_r(img, 16, ey - 4, 6, 1, sopr)
			_r(img, 26, ey - 4, 6, 1, sopr)
	var occhio_h := 3 if espressione == "sorpreso" else (1 if espressione == "duro" or espressione == "stanco" else 2)
	for ex in [17, 27]:
		_r(img, ex, ey - 1, 4, occhio_h + 1, bianco)
		_r(img, ex + 1, ey - 1, 2, occhio_h + 1, nero)
		if espressione == "felice":
			_r(img, ex, ey + occhio_h, 4, 1, pelle.darkened(0.15))
	if espressione == "stanco":
		_r(img, 17, ey + 2, 4, 1, pelle.darkened(0.3))
		_r(img, 27, ey + 2, 4, 1, pelle.darkened(0.3))
	_r(img, 23, ey + 1, 2, 5, pelle.darkened(0.18))
	_r(img, 22, ey + 5, 4, 1, pelle.darkened(0.3))
	var bocca := Color("7a3a30") if not a.get("rossetto", false) else Color("c02030")
	var my := 30
	match espressione:
		"felice":
			_r(img, 20, my, 8, 1, bocca)
			_p(img, 19, my - 1, bocca)
			_p(img, 28, my - 1, bocca)
		"triste", "stanco":
			_r(img, 20, my, 8, 1, bocca)
			_p(img, 19, my + 1, bocca)
			_p(img, 28, my + 1, bocca)
		"arrabbiato":
			_r(img, 20, my, 8, 2, bocca.darkened(0.3))
			_r(img, 21, my, 6, 1, bianco)
		"sorpreso":
			_disco(img, 24, my + 0.5, 2, 2, bocca.darkened(0.3))
		_:
			_r(img, 20, my, 8, 1, bocca)
	if a.get("barba", false):
		_disco(img, 24, 31, 9, 5, cap.lerp(pelle, 0.25))
		_r(img, 20, my, 8, 1, bocca)
	if a.get("baffi", false):
		_r(img, 18, my - 2, 12, 2, cap)
	if a.get("occhiali", false):
		_o(img, 16, ey - 2, 6, 5, Color("1a1a1a"))
		_o(img, 26, ey - 2, 6, 5, Color("1a1a1a"))
		_r(img, 22, ey, 4, 1, Color("1a1a1a"))


static func _ritratto_volpe(img: Image, espressione: String) -> void:
	var arancio := Color("e08030")
	var bianco := Color("f0f0f0")
	var nero := Color("0d0d0d")
	_poligono(img, [Vector2(10, 2), Vector2(20, 12), Vector2(12, 16)], arancio)
	_poligono(img, [Vector2(38, 2), Vector2(28, 12), Vector2(36, 16)], arancio)
	_poligono(img, [Vector2(12, 6), Vector2(17, 12), Vector2(13, 14)], Color("1a1a2e"))
	_poligono(img, [Vector2(36, 6), Vector2(31, 12), Vector2(35, 14)], Color("1a1a2e"))
	_disco(img, 24, 22, 13, 12, arancio)
	_poligono(img, [Vector2(12, 24), Vector2(36, 24), Vector2(24, 38)], bianco)
	_disco(img, 24, 36, 2, 2, nero)
	var occhio := 1 if espressione != "sorpreso" else 2
	_r(img, 16, 20, 5, occhio, Color("f0c050"))
	_r(img, 27, 20, 5, occhio, Color("f0c050"))
	_r(img, 18, 20, 1, occhio, nero)
	_r(img, 29, 20, 1, occhio, nero)
	if espressione == "felice":
		_r(img, 20, 33, 8, 1, nero)
		_p(img, 19, 32, nero)
		_p(img, 28, 32, nero)


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
			if PixelArt._dentro(pts, Vector2(x + 0.5, y + 0.5)):
				_p(img, x, y, c)


# =================================================================== luce

## Velo di buio con un cerchio di luce al centro (cripta). raggio in pixel.
static func buio(raggio: int) -> ImageTexture:
	var chiave := "buio_%d" % raggio
	if _cache.has(chiave):
		return _cache[chiave]
	var lato := 512
	var img := _nuova(lato, lato)
	var c := lato / 2
	for y in lato:
		for x in lato:
			var d := Vector2(x - c, y - c).length() / float(raggio)
			var alfa := clampf((d - 0.55) / 0.45, 0.0, 1.0)
			alfa = floorf(alfa * 4.0) / 4.0
			img.set_pixel(x, y, Color(0.02, 0.01, 0.02, alfa * 0.93))
	var t := _tex(img)
	_cache[chiave] = t
	return t


# =================================================================== vignette

## Illustrazioni 160x90 per le cutscene a pannelli.
static func vignetta(nome: String) -> ImageTexture:
	var chiave := "vig_" + nome
	if _cache.has(chiave):
		return _cache[chiave]
	var w := 160
	var h := 90
	var img := _nuova(w, h)
	match nome:
		"pioggia", "ospedale", "tomba":
			for y in h:
				_r(img, 0, y, w, 1, Color("0a0a18").lerp(Color("1e2238"), float(y) / h))
			for i in 22:
				var bw := 6 + _h(i, 1) % 9
				var bh := 18 + _h(i, 2) % 40
				var bx := i * 8 - 4
				_r(img, bx, h - bh, bw, bh, Color("10101c"))
				for k in 6:
					if _h(i, k, 3) % 3 == 0:
						_r(img, bx + 1 + (_h(i, k) % maxi(bw - 2, 1)), h - bh + 3 + k * 5, 1, 2, Color("f0c050").darkened(0.3))
			if nome == "ospedale":
				_r(img, 58, 20, 44, 70, Color("2a2e3a"))
				for j in 6:
					for i in 5:
						_r(img, 62 + i * 8, 24 + j * 10, 4, 5, Color("151822"))
				_r(img, 78, 44, 4, 5, Color("f8e8a0"))
				_r(img, 72, 14, 16, 6, Color("c03030"))
				_r(img, 79, 15, 2, 4, Color("f0f0f0"))
				_r(img, 77, 16, 6, 2, Color("f0f0f0"))
			if nome == "tomba":
				_r(img, 0, 70, w, 20, Color("1a1a14"))
				_r(img, 72, 48, 16, 24, Color("5a5a5e"))
				_disco(img, 80, 48, 8, 6, Color("5a5a5e"))
				_r(img, 79, 52, 2, 10, Color("2a2a2e"))
				_r(img, 76, 55, 8, 2, Color("2a2a2e"))
			for k in 120:
				var x := _h(k, 7) % w
				var y := _h(k, 9) % h
				_r(img, x, y, 1, 3, Color(0.7, 0.75, 0.9, 0.35))
		"clessidra":
			_r(img, 0, 0, w, h, Color("0a0a10"))
			_disco(img, 80, 45, 50, 40, Color("1a1420"))
			_r(img, 60, 8, 40, 4, Color("c8a040"))
			_r(img, 60, 78, 40, 4, Color("c8a040"))
			for y in range(12, 78):
				var t := absf(float(y - 45)) / 33.0
				var half := int(2 + 16 * t)
				_r(img, 80 - half, y, half * 2, 1, Color(0.6, 0.75, 0.9, 0.35))
				if y > 50:
					var sab := int(2 + 16 * t * clampf(float(y - 50) / 14.0, 0.0, 1.0))
					if y > 62:
						_r(img, 80 - sab, y, sab * 2, 1, Color("c8a97e"))
				elif y < 34 and y > 26:
					_r(img, 80 - half + 2, y, half * 2 - 4, 1, Color("c8a97e"))
			_r(img, 79, 34, 2, 30, Color("e0c090"))
		"incubatrice":
			_r(img, 0, 0, w, h, Color("101820"))
			_disco(img, 80, 30, 60, 30, Color("1a2a3a"))
			_r(img, 30, 40, 100, 34, Color(0.7, 0.85, 1.0, 0.25))
			_o(img, 30, 40, 100, 34, Color("c0d8e8"))
			_r(img, 34, 64, 92, 10, Color("e8e0f0"))
			_r(img, 64, 54, 34, 11, Color("f0c8d8"))
			_r(img, 64, 54, 34, 2, Color("f8e0e8"))
			_disco(img, 58, 58, 7, 6.5, Color("e8c8a8"))
			_r(img, 53, 51, 9, 2, Color("8a5a30"))
			_r(img, 54, 58, 3, 1, Color("6a4030"))
			_r(img, 60, 58, 3, 1, Color("6a4030"))
			_p(img, 57, 61, Color("c08070"))
			_disco(img, 66, 62, 2, 2, Color("e8c8a8"))
			_r(img, 98, 46, 2, 18, Color("c8d0d8"))
			_r(img, 120, 10, 30, 20, Color("0a0a0a"))
			for x in range(122, 148):
				_p(img, x, 20 - int(4.0 * absf(sin(x * 0.7))), Color("4aff7a"))
		"sirio", "volpe", "serena":
			for y in h:
				_r(img, 0, y, w, 1, Color("0c0c16").lerp(Color("2a1a26") if nome == "volpe" else Color("1a2030"), float(y) / h))
			var rit := ritratto("sirio" if nome == "sirio" else ("volpe" if nome == "volpe" else "serena"), "stanco" if nome == "sirio" else ("felice" if nome == "volpe" else "neutro")).get_image()
			rit.resize(96, 96, Image.INTERPOLATE_NEAREST)
			img.blend_rect(rit, Rect2i(0, 0, 96, 96), Vector2i(32, 4))
			if nome == "sirio":
				for k in 90:
					_r(img, _h(k, 3) % w, _h(k, 5) % h, 1, 3, Color(0.7, 0.75, 0.9, 0.3))
			if nome == "serena":
				_r(img, 0, 0, w, h, Color(0.9, 0.85, 0.8, 0.12))
		"cripta":
			_r(img, 0, 0, w, h, Color("0a0806"))
			for k in 9:
				var lw := 120 - k * 12
				_r(img, 80 - lw / 2, 20 + k * 7, lw, 6, Color("3a3632").darkened(k * 0.08))
				_r(img, 80 - lw / 2, 20 + k * 7, lw, 1, Color("6a6458").darkened(k * 0.08))
			for x in [18, 140]:
				_r(img, x, 30, 3, 10, Color("e8e0c8"))
				_disco(img, x + 1, 27, 2, 3, Color("f0c050"))
				_disco(img, x + 1, 32, 14, 14, Color(1.0, 0.7, 0.3, 0.06))
		"alba":
			for y in h:
				_r(img, 0, y, w, 1, Color("2a1a3a").lerp(Color("e08050"), float(y) / 55.0) if y < 55 else Color("1e3a5a").lerp(Color("0a1a2a"), float(y - 55) / 35.0))
			_disco(img, 80, 55, 14, 14, Color("f8d070"))
			_r(img, 0, 55, w, 35, Color("1e3a5a"))
			for k in 12:
				_r(img, 66 + _h(k, 1) % 28, 58 + k * 2, 6 + _h(k, 2) % 6, 1, Color("f8d070").darkened(k * 0.05))
			var sil := personaggio("sirio", 1, 0).get_image()
			sil.resize(32, 48, Image.INTERPOLATE_NEAREST)
			for y in sil.get_height():
				for x in sil.get_width():
					if sil.get_pixel(x, y).a > 0.5:
						sil.set_pixel(x, y, Color("0a0a10"))
			img.blend_rect(sil, Rect2i(0, 0, 32, 48), Vector2i(30, 40))
		"culla":
			_r(img, 0, 0, w, h, Color("14141c"))
			_r(img, 0, 66, w, 24, Color("2a2018"))
			var cul := oggetto("culla", [1, 1]).get_image()
			cul.resize(64, 96, Image.INTERPOLATE_NEAREST)
			img.blend_rect(cul, Rect2i(0, 0, 64, 96), Vector2i(48, 6))
			_r(img, 110, 10, 30, 40, Color("1e2638"))
			_r(img, 124, 10, 1, 40, Color("14141c"))
			_r(img, 110, 29, 30, 1, Color("14141c"))
	var t := _tex(img)
	_cache[chiave] = t
	return t
