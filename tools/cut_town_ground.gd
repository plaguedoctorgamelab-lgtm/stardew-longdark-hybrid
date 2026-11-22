extends SceneTree
## Cuts Art Request 19's ground sheet (art/raw/raw_ar19_ground_edges.png)
## into 16 x 16 tiles in art/final/. Mark drew each piece as a 3 x 3 block of
## tiles with a thin line round each tile: this finds each block, splits it
## in nine, cuts just inside the lines, and shrinks each tile by the most
## common colour in each little square so edges stay hard.
##
## Edge sets (lawn outside, the other ground inside) come out as
## town_edge_<set>_<nw|n|ne|w|c|e|sw|s|se>. The inner corners on Mark's
## sheet are drawn as small ponds, so the lab makes its own: the middle tile
## with the outer corner tile's corner pasted in, as _inw, _ine, _isw, _ise.
## The plain grounds come out as numbered versions (town_water_0..17).
## Each set's middle tile also comes flipped (_c1, _c2, _c3) for variety.
##
## Mark's grass is brighter than the town's older lawn (21 Nov), so the lawn
## is recoloured to his grass, shade for shade, as town_grass_0..3: same
## texture, his colours, and the edges then meet it without a seam.
##
## Run: godot --headless --path . -s tools/cut_town_ground.gd

const RAW := "res://art/raw/raw_ar19_ground_edges.png"
const OUT := "res://art/final/"
const TILE := 16
const INSET := 0.06   # of a tile, cut off each side to lose the drawn lines
const CORNER := 5     # pixels of an outer corner pasted into an inner one

# Where each block lies on the sheet, roughly: [x0, y0, x1, y1]. The block's
# exact edges are found inside by its solid pixels.
const COLS := [[30, 340], [390, 700], [750, 1060], [1110, 1420]]
const ROWS := [[0, 298], [460, 766], [770, 1086]]
const POS := ["nw", "n", "ne", "w", "c", "e", "sw", "s", "se"]

var sheet: Image


func _initialize() -> void:
	sheet = Image.load_from_file(ProjectSettings.globalize_path(RAW))
	sheet.convert(Image.FORMAT_RGBA8)
	var made := 0
	for set_name: String in ["cobbles", "gravel", "bank", "bed"]:
		made += _edge_set(set_name, ["cobbles", "gravel", "bank", "bed"].find(set_name), 0)
	made += _edge_set("paving", 2, 1)
	made += _numbered("town_paving", 0, 1, 0)
	var crack := _tiles(1, 1)[4]
	_save(crack, "town_paving_crack")
	made += 1
	made += _numbered("town_lawn_dark", 3, 1, 0)
	made += _numbered("town_shallows", 0, 2, 0)
	made += _numbered("town_water", 1, 2, 0)
	made += _numbered("town_water", 2, 2, 9)
	var step := _tiles(3, 2)
	for i in 9:
		_save(step[i], "town_doorstep_" + POS[i])
	made += 9
	made += _flips()
	made += _bright_lawn()
	print("cut_town_ground: %d tiles" % made)
	quit(0)


## The block at column cx, row cy, as nine 16 x 16 tiles, left to right and
## top to bottom.
func _tiles(cx: int, cy: int) -> Array[Image]:
	var r := _block_rect(COLS[cx][0], ROWS[cy][0], COLS[cx][1], ROWS[cy][1])
	var out: Array[Image] = []
	var tw := r.size.x / 3.0
	var th := r.size.y / 3.0
	for ty in 3:
		for tx in 3:
			var x0 := r.position.x + tx * tw + tw * INSET
			var y0 := r.position.y + ty * th + th * INSET
			out.append(_shrink(x0, y0, tw * (1.0 - 2.0 * INSET), th * (1.0 - 2.0 * INSET)))
	return out


## The tight box of solid pixels inside a rough box. The soft glow round
## each block is see-through, so only near-solid pixels count.
func _block_rect(x0: int, y0: int, x1: int, y1: int) -> Rect2:
	var minx := x1
	var miny := y1
	var maxx := x0
	var maxy := y0
	for y in range(y0, min(y1, sheet.get_height())):
		for x in range(x0, min(x1, sheet.get_width())):
			if sheet.get_pixel(x, y).a > 0.95:
				minx = min(minx, x)
				maxx = max(maxx, x)
				miny = min(miny, y)
				maxy = max(maxy, y)
	return Rect2(minx, miny, maxx - minx + 1, maxy - miny + 1)


## Shrinks a box of the sheet to one tile by the most common colour in each
## little square.
func _shrink(x0: float, y0: float, w: float, h: float) -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var sx := w / TILE
	var sy := h / TILE
	for ty in TILE:
		for tx in TILE:
			var votes := {}
			var best := Color()
			var best_n := 0
			for j in 5:
				for i in 5:
					var c := sheet.get_pixel(int(x0 + (tx + (i + 0.5) / 5.0) * sx), int(y0 + (ty + (j + 0.5) / 5.0) * sy))
					var key := Vector3i(int(c.r8) >> 3, int(c.g8) >> 3, int(c.b8) >> 3)
					var n: int = votes.get(key, 0) + 1
					votes[key] = n
					if n > best_n:
						best_n = n
						best = Color8(key.x * 8 + 4, key.y * 8 + 4, key.z * 8 + 4)
			img.set_pixel(tx, ty, best)
	return img


func _edge_set(set_name: String, cx: int, cy: int) -> int:
	var t := _tiles(cx, cy)
	for i in 9:
		_save(t[i], "town_edge_%s_%s" % [set_name, POS[i]])
	# Inner corners: the middle with the outer corner's corner pasted in.
	var mid: Image = t[4]
	for c: Array in [["inw", 0, Vector2i(0, 0)], ["ine", 2, Vector2i(TILE - CORNER, 0)], ["isw", 6, Vector2i(0, TILE - CORNER)], ["ise", 8, Vector2i(TILE - CORNER, TILE - CORNER)]]:
		var img := mid.duplicate() as Image
		img.blit_rect(t[c[1]], Rect2i(c[2], Vector2i(CORNER, CORNER)), c[2])
		_save(img, "town_edge_%s_%s" % [set_name, c[0]])
	return 13


func _numbered(prefix: String, cx: int, cy: int, first: int) -> int:
	var t := _tiles(cx, cy)
	for i in 9:
		_save(t[i], "%s_%d" % [prefix, first + i])
	return 9


## Each edge set's middle tile flipped three ways, as _c1, _c2 and _c3.
func _flips() -> int:
	for set_name: String in ["cobbles", "gravel", "bed", "paving"]:
		var c := Image.load_from_file(ProjectSettings.globalize_path(OUT + "town_edge_%s_c.png" % set_name))
		var a := c.duplicate() as Image
		a.flip_x()
		_save(a, "town_edge_%s_c1" % set_name)
		var b := c.duplicate() as Image
		b.flip_y()
		_save(b, "town_edge_%s_c2" % set_name)
		var d := a.duplicate() as Image
		d.flip_y()
		_save(d, "town_edge_%s_c3" % set_name)
	return 12


## The town lawn in Mark's grass colours: four of his grass shades (from
## the greens in the edge tiles' corners), darkest to lightest, given to the
## lawn's own shades in the same order of lightness.
func _bright_lawn() -> int:
	var counts := {}
	for set_name: String in ["cobbles", "gravel", "bank", "bed"]:
		for pos: String in ["nw", "ne", "sw", "se"]:
			var im := Image.load_from_file(ProjectSettings.globalize_path(OUT + "town_edge_%s_%s.png" % [set_name, pos]))
			for y in TILE:
				for x in TILE:
					var c := im.get_pixel(x, y)
					if c.g8 > c.r8 + 20 and c.g8 > c.b8 + 30:
						counts[c] = int(counts.get(c, 0)) + 1
	# Every grass pixel, darkest to lightest; the shades a fifth, two
	# fifths, three fifths and four fifths of the way along make the ramp.
	var all: Array = []
	for c: Color in counts:
		for i in int(counts[c]):
			all.append(c)
	all.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	var ramp: Array = []
	for q: float in [0.2, 0.45, 0.7, 0.92]:
		ramp.append(all[int(q * (all.size() - 1))])
	var made := 0
	for src: String in ["town_lawn", "town_lawn_alt_1", "town_lawn_alt_2", "town_lawn_alt_3"]:
		var im := Image.load_from_file(ProjectSettings.globalize_path(OUT + src + ".png"))
		im.convert(Image.FORMAT_RGBA8)
		var shades := {}
		for y in im.get_height():
			for x in im.get_width():
				shades[im.get_pixel(x, y)] = true
		var order: Array = shades.keys()
		order.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
		var out := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
		for y in TILE:
			for x in TILE:
				var i := order.find(im.get_pixel(x, y))
				var k := clampi(int(float(i) / max(1, order.size() - 1) * (ramp.size() - 1) + 0.5), 0, ramp.size() - 1)
				out.set_pixel(x, y, ramp[k])
		_save(out, "town_grass_%d" % made)
		made += 1
	return made


func _save(img: Image, art_name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT + art_name + ".png"))
