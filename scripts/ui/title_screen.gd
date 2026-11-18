class_name TitleScreen
extends Control
## The title screen: the entrance to Dusk River Park at dusk
## (docs/art/visual_direction_brief.md). A banded dusk sky, layered mountains
## and pines with the Dusk River winding through, drifting slowly; fireflies
## and fog; the game's name in big poster letters; and the park's routed-wood
## entrance sign with its compass-and-eye emblem and a lantern, the menu
## hanging under it on planks.
##
## Mark's Art Request 11 pictures (title_*) are used when they are there; the
## code-drawn stand-ins remain for any that are missing. The sky's bands, the
## sun, the fog and the chains are always drawn in code. Words for the
## stand-ins come from the text table; Mark's sign and logo carry their own.

const W := 480.0
const H := 270.0

# The bright palette (docs/art/palette_bright.json), by role.
const INK := Color8(26, 22, 32)
const NIGHT := Color8(31, 78, 107)
const BLUE := Color8(38, 112, 157)
const WATER := Color8(95, 172, 207)
const FOAM := Color8(185, 228, 232)
const VIOLET := Color8(166, 143, 219)
const PINK := Color8(240, 128, 150)
const CORAL := Color8(232, 115, 95)
const ORANGE := Color8(251, 177, 113)
const BUTTER := Color8(253, 230, 150)
const GOLD := Color8(255, 224, 102)
const SLATE := Color8(85, 96, 114)
const STONE := Color8(149, 157, 170)
const SNOW := Color8(198, 204, 210)
const PINE := Color8(40, 97, 67)
const LEAF := Color8(56, 142, 76)
const MOSS := Color8(97, 187, 97)
const WOOD_DARK := Color8(93, 62, 48)
const WOOD := Color8(157, 102, 62)
const WOOD_MID := Color8(199, 144, 95)
const WOOD_LIGHT := Color8(225, 189, 142)
const CREAM := Color8(246, 224, 180)
const PAPER := Color8(252, 248, 237)

var content: ContentDB
var buttons: VBoxContainer
var note: Label
var version_label: Label
var _time: float = 0.0
var _flies: Array[Vector3] = []   # x, y, phase
var _font: Font
var _art: bool = false            # Mark's title pictures are in
var _post_cols: Array = []        # [x, colour] of the sign picture's post pixels, carried to the ground

# Where Mark's pictures go on the 480 x 270 screen.
const LOGO_AT := Vector2(40, 6)
const LAYERS := {"title_layer_mountains": [38.0, 1.0], "title_layer_ridge": [78.0, 2.0], "title_layer_meadow": [150.0, 3.0], "title_layer_pines": [150.0, 5.0]}
const SIGN_AT := Vector2(96, 92)
const EMBLEM_AT := Vector2(352, 84)
const LANTERN_AT := Vector2(352, 186)


func setup(c: ContentDB, version_text: String, actions: Array) -> void:
	content = c
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	_art = Art.has_picture("title_sign") and Art.has_picture("title_layer_mountains")
	if _art:
		# The sign's posts end at the bottom of its picture: note each post
		# pixel a few rows up (the bottom row is the outline), to carry the
		# posts on down to the ground.
		var img := Art.image("title_sign")
		var y := img.get_height() - 4
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if px.a > 0.5:
				_post_cols.append([x, px])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1971
	for i in 18:
		_flies.append(Vector3(rng.randf_range(20, W - 20), rng.randf_range(170, H - 10), rng.randf() * TAU))
	buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 5)
	add_child(buttons)
	for pair: Array in actions:
		var b := Button.new()
		b.text = c.text(pair[0])
		b.custom_minimum_size = Vector2(84, 15)
		b.focus_mode = Control.FOCUS_NONE
		_plank(b)
		b.pressed.connect(pair[1])
		buttons.add_child(b)
	buttons.reset_size()
	var under := _sign_rect()
	buttons.position = Vector2(under.get_center().x - buttons.get_combined_minimum_size().x / 2.0, under.end.y + 8)
	note = Label.new()
	note.position = Vector2(110, 252)
	note.size = Vector2(260, 16)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.add_theme_color_override("font_color", PAPER)
	note.add_theme_color_override("font_outline_color", INK)
	note.add_theme_constant_override("outline_size", 3)
	add_child(note)
	version_label = Label.new()
	version_label.text = version_text
	version_label.position = Vector2(4, 256)
	version_label.add_theme_color_override("font_color", Color(PAPER, 0.7))
	version_label.add_theme_color_override("font_outline_color", INK)
	version_label.add_theme_constant_override("outline_size", 2)
	add_child(version_label)


## Where the sign stands: Mark's picture, or the drawn stand-in.
func _sign_rect() -> Rect2:
	if _art:
		return Rect2(SIGN_AT, Vector2(Art.texture("title_sign").get_size()))
	return SIGN


## A menu button as a small hanging plank: Mark's plank, lighter on hover and
## darker when pressed, or the drawn stand-in.
func _plank(b: Button) -> void:
	if Art.has_picture("title_plank"):
		for state in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxTexture.new()
			sb.texture = Art.texture("title_plank")
			sb.set_texture_margin_all(3)
			sb.set_content_margin_all(1)
			sb.modulate_color = {"normal": Color.WHITE, "hover": Color(1.15, 1.12, 1.05), "pressed": Color(0.82, 0.8, 0.78), "focus": Color.WHITE}[state]
			b.add_theme_stylebox_override(state, sb)
		# Mark's plank has a groove along its middle: cream words with a dark
		# edge read clearly over it.
		b.add_theme_color_override("font_color", CREAM)
		b.add_theme_color_override("font_hover_color", PAPER)
		b.add_theme_color_override("font_pressed_color", CREAM)
		b.add_theme_color_override("font_outline_color", INK)
		b.add_theme_constant_override("outline_size", 3)
		return
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": WOOD_MID, "hover": WOOD_LIGHT, "pressed": WOOD}[state]
		sb.border_color = WOOD_DARK
		sb.set_border_width_all(1)
		sb.border_width_bottom = 2
		sb.set_corner_radius_all(2)
		sb.set_content_margin_all(2)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", WOOD_DARK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _art:
		_draw_with_art()
		return
	_draw_sky()
	_draw_mountains()
	_draw_river_valley()
	_draw_fog()
	_draw_near_pines()
	_draw_title()
	_draw_chains()
	_draw_sign()
	_draw_fireflies()


# --- with Mark's pictures (Art Request 11) -----------------------------------------

func _draw_with_art() -> void:
	_draw_sky()
	# The layers drift slowly, the nearest fastest. They are 32 px wider than
	# the screen, so the drift never shows an edge.
	# Far to near: the meadow's own distant treeline stands in front of the ridge.
	for layer: String in ["title_layer_mountains", "title_layer_ridge", "title_layer_meadow", "title_layer_pines"]:
		_layer(layer)
	if Art.has_picture("title_logo"):
		draw_texture(Art.texture("title_logo"), LOGO_AT)
	else:
		_draw_title()
	_draw_chains()
	# The sign's posts, carried on from the bottom of its picture to the ground.
	var sign_tex := Art.texture("title_sign")
	var foot := SIGN_AT.y + sign_tex.get_height() - 4
	draw_texture(sign_tex, SIGN_AT)
	# Over the picture's last rows, so its bottom outline leaves no seam.
	for pc: Array in _post_cols:
		draw_rect(Rect2(SIGN_AT.x + float(pc[0]), foot, 1, H - foot), pc[1])
	# Mark's sign carries the park's emblem itself (since 0.4.8), so it is
	# not laid over it again.
	var frame := int(_time * 3.0) % 2
	var glow := 0.8 + 0.2 * sin(_time * 3.1)
	draw_circle(LANTERN_AT + Vector2(6, 10), 20 * glow, Color(GOLD, 0.10))
	draw_circle(LANTERN_AT + Vector2(6, 10), 10 * glow, Color(GOLD, 0.16))
	if Art.has_picture("title_lantern_0"):
		draw_texture(Art.texture("title_lantern_%d" % frame), LANTERN_AT)
	else:
		_draw_lantern(LANTERN_AT + Vector2(6, 0))
	for f in _flies:
		var p := Vector2(f.x + sin(_time * 0.7 + f.z) * 8.0, f.y + cos(_time * 0.9 + f.z * 2.0) * 5.0).round()
		var a := clampf(sin(_time * 2.2 + f.z * 3.0) * 1.4, 0.0, 1.0)
		if a > 0.05 and Art.has_picture("title_firefly_0"):
			draw_texture(Art.texture("title_firefly_%d" % (int(_time * 4.0 + f.z) % 2)), p - Vector2(2, 2), Color(1, 1, 1, a))


func _layer(layer: String) -> void:
	var at: Array = LAYERS[layer]
	var drift := sin(_time * 0.05) * float(at[1]) - 16.0
	draw_texture(Art.texture(layer), Vector2(round(drift), float(at[0])))


# --- the landscape ---------------------------------------------------------------

func _draw_sky() -> void:
	# Flat bands, as a poster would print them.
	var bands := [[0, NIGHT], [34, BLUE], [62, VIOLET], [84, PINK], [102, CORAL], [116, ORANGE], [130, BUTTER]]
	for i in bands.size():
		var y0: float = bands[i][0]
		var y1: float = bands[i + 1][0] if i + 1 < bands.size() else 175.0
		draw_rect(Rect2(0, y0, W, y1 - y0), bands[i][1])
	# A few early stars in the top band.
	for p: Vector2 in [Vector2(40, 10), Vector2(96, 22), Vector2(150, 8), Vector2(300, 16), Vector2(352, 6), Vector2(430, 24)]:
		var a := 0.55 + 0.45 * sin(_time * 1.3 + p.x)
		draw_rect(Rect2(p, Vector2(1, 1)), Color(PAPER, a))
	# The low sun, half behind the far range.
	var sun := Vector2(372, 138)
	draw_circle(sun, 19, BUTTER)
	draw_circle(sun, 15, GOLD)


func _ridge(base: float, peaks: Array, drift: float, col: Color) -> void:
	var pts := PackedVector2Array([Vector2(-20, H)])
	for p: Vector2 in peaks:
		pts.append(Vector2(p.x + drift, p.y))
	pts.append(Vector2(W + 20, base))
	pts.append(Vector2(W + 20, H))
	draw_colored_polygon(pts, col)


func _draw_mountains() -> void:
	var d := sin(_time * 0.05) * 2.0
	var far := [Vector2(-20, 150), Vector2(30, 118), Vector2(70, 136), Vector2(120, 104), Vector2(170, 132),
		Vector2(220, 112), Vector2(268, 140), Vector2(320, 120), Vector2(350, 142), Vector2(410, 108), Vector2(460, 134), Vector2(500, 124)]
	_ridge(150, far, d, SLATE)
	# Snow on the tallest peaks.
	for pk: Vector2 in [Vector2(120, 104), Vector2(220, 112), Vector2(410, 108)]:
		var p := pk + Vector2(d, 0)
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(-7, 7), p + Vector2(-3, 6), p + Vector2(0, 9), p + Vector2(3, 6), p + Vector2(7, 7)]), SNOW)
	var mid := [Vector2(-20, 160), Vector2(40, 146), Vector2(110, 156), Vector2(180, 144), Vector2(250, 158),
		Vector2(330, 146), Vector2(400, 156), Vector2(500, 148)]
	_ridge(160, mid, d * 2.0, PINE)
	_pine_row(150, 168, 9, d * 2.0, LEAF, 23)


## A row of pine silhouettes along a ridge line.
func _pine_row(y_top: float, y_base: float, step: float, drift: float, col: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var x := -10.0
	while x < W + 10:
		var h := rng.randf_range(8, 16)
		var bx := x + drift
		var by := y_base - rng.randf_range(0, y_base - y_top) * 0.4
		draw_colored_polygon(PackedVector2Array([Vector2(bx, by - h), Vector2(bx - h * 0.35, by), Vector2(bx + h * 0.35, by)]), col)
		x += step + rng.randf_range(-2, 3)


func _draw_river_valley() -> void:
	var d := sin(_time * 0.05) * 3.0
	# The meadow floor the river crosses.
	draw_rect(Rect2(0, 166, W, H - 166), LEAF)
	draw_rect(Rect2(0, 186, W, H - 186), MOSS)
	# The Dusk River: from the foot of the far range, winding toward us.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		var y := lerpf(164, H, t)
		var x := 300 + sin(t * 4.2 + 0.6) * 46.0 * t - t * 90.0 + d * t
		var half := lerpf(2, 34, t * t)
		left.append(Vector2(x - half, y))
		right.append(Vector2(x + half, y))
	var poly := left.duplicate()
	right.reverse()
	poly.append_array(right)
	draw_colored_polygon(poly, WATER)
	# The sky's warm colours caught on the water, shimmering.
	for i in 9:
		var t := 0.15 + i * 0.09
		var y := lerpf(164, H, t)
		var x := 300 + sin(t * 4.2 + 0.6) * 46.0 * t - t * 90.0 + d * t
		var w := lerpf(2, 34, t * t) * (0.6 + 0.2 * sin(_time * 2.0 + i))
		draw_rect(Rect2(x - w * 0.5, y, w, 1), ORANGE if i % 2 == 0 else FOAM)


func _draw_fog() -> void:
	for i in 3:
		var y := 168.0 + i * 9.0
		var x := fmod(_time * (4.0 + i * 2.0) + i * 160.0, W + 200.0) - 200.0
		draw_rect(Rect2(x, y, 180, 3), Color(PAPER, 0.18))
		draw_rect(Rect2(x - 260, y + 4, 140, 2), Color(PAPER, 0.12))


func _draw_near_pines() -> void:
	var d := sin(_time * 0.05) * 5.0
	for side in [-1.0, 1.0]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 if side < 0 else 11
		for i in 7:
			var x := (18.0 + i * 15.0 + rng.randf_range(-4, 4)) if side < 0 else (W - 18.0 - i * 15.0 + rng.randf_range(-4, 4))
			var h := rng.randf_range(70, 120) - i * 8.0
			var base := H + 4
			var bx := x + d
			var col := PINE if i % 2 == 0 else Color8(31, 78, 60)
			draw_rect(Rect2(bx - 1.5, base - 10, 3, 10), WOOD_DARK)
			for tier in 4:
				var ty := base - 8 - tier * h * 0.22
				var tw := h * (0.34 - tier * 0.06)
				draw_colored_polygon(PackedVector2Array([Vector2(bx, ty - h * 0.32), Vector2(bx - tw, ty), Vector2(bx + tw, ty)]), col)


func _draw_fireflies() -> void:
	for f in _flies:
		var p := Vector2(f.x + sin(_time * 0.7 + f.z) * 8.0, f.y + cos(_time * 0.9 + f.z * 2.0) * 5.0)
		var a := clampf(sin(_time * 2.2 + f.z * 3.0) * 1.4, 0.0, 1.0)
		if a > 0.05:
			draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(GOLD, a))
			draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(3, 3)), Color(GOLD, a * 0.25))


# --- the words ---------------------------------------------------------------------

func _text(s: String, centre_x: float, baseline: float, px: int, col: Color, outline: Color, outline_px: int) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := Vector2(round(centre_x - w / 2.0), baseline)
	if outline_px > 0:
		draw_string_outline(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline_px, outline)
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw_title() -> void:
	var t := content.text("title_game").to_upper()
	# A coral shadow under cream poster letters.
	_text(t, W / 2.0 + 2, 64, 38, CORAL, INK, 6)
	_text(t, W / 2.0, 62, 38, PAPER, INK, 6)


# --- the entrance sign -------------------------------------------------------------

const SIGN := Rect2(100, 96, 280, 78)
const BAND := 30.0


func _sign_shape(r: Rect2) -> PackedVector2Array:
	# Rounded at the left, the top right cut on a slant like a park sign.
	return PackedVector2Array([
		r.position + Vector2(4, 0), Vector2(r.end.x - 26, r.position.y), Vector2(r.end.x, r.position.y + 18),
		Vector2(r.end.x, r.end.y - 4), r.end - Vector2(4, 0), Vector2(r.position.x + 4, r.end.y),
		Vector2(r.position.x, r.end.y - 4), r.position + Vector2(0, 4)])


func _draw_sign() -> void:
	var r := SIGN
	# Posts down into the ground.
	for px in [r.position.x + 30, r.end.x - 40]:
		draw_rect(Rect2(px, r.end.y - 4, 9, H - r.end.y + 4), WOOD)
		draw_rect(Rect2(px + 6, r.end.y - 4, 3, H - r.end.y + 4), WOOD_DARK)
	# The board: a dark outline, then the light upper band and the dark lower one.
	var outer := _sign_shape(r.grow(2))
	draw_colored_polygon(outer, INK)
	draw_colored_polygon(_sign_shape(r), WOOD_DARK)
	var top := _sign_shape(Rect2(r.position, Vector2(r.size.x, BAND + 6)))
	draw_colored_polygon(top, WOOD_LIGHT)
	draw_rect(Rect2(r.position.x, r.position.y + BAND, r.size.x - 2, 2), WOOD)
	# Wood grain.
	for i in 5:
		var y := r.position.y + 5 + i * 5
		draw_line(Vector2(r.position.x + 6 + i * 9, y), Vector2(r.end.x - 34 - i * 6, y), Color(WOOD_MID, 0.7), 1)
	for i in 6:
		var y := r.position.y + BAND + 8 + i * 7
		draw_line(Vector2(r.position.x + 4 + (i % 3) * 11, y), Vector2(r.end.x - 8 - (i % 2) * 20, y), Color(WOOD, 0.45), 1)
	# Routed lettering: the light band's words cut dark, the dark band's cream.
	# The words sit centred in the space left of the emblem.
	var cx := r.position.x + (r.size.x - 56) / 2.0
	_text(content.text("title_welcome"), cx, r.position.y + 22, 16, WOOD_DARK, WOOD_MID, 1)
	_text(content.text("title_park").to_upper(), cx, r.position.y + BAND + 30, 20, CREAM, INK, 2)
	_text(content.text("title_tagline"), cx, r.position.y + BAND + 43, 9, WOOD_LIGHT, INK, 0)
	_draw_emblem(Vector2(r.end.x - 20, r.position.y + 34))
	_draw_lantern(Vector2(r.end.x - 36, r.end.y + 6))


## The park's emblem: a shield with a compass rose and an eye at its heart.
func _draw_emblem(c: Vector2) -> void:
	var w := 25.0
	var h := 32.0
	var shield := PackedVector2Array([c + Vector2(-w, -h), c + Vector2(w, -h), c + Vector2(w, h * 0.3),
		c + Vector2(0, h), c + Vector2(-w, h * 0.3)])
	draw_colored_polygon(PackedVector2Array(Array(shield).map(func(p: Vector2) -> Vector2: return c + (p - c) * 1.12)), INK)
	draw_colored_polygon(shield, WOOD_DARK)
	var inner := PackedVector2Array(Array(shield).map(func(p: Vector2) -> Vector2: return c + (p - c) * 0.86))
	draw_colored_polygon(inner, BLUE)
	# The lower half of the shield is forest, the upper sky.
	var forest := PackedVector2Array([c + Vector2(-w * 0.86, 4), c + Vector2(w * 0.86, 4), c + Vector2(w * 0.86, h * 0.26),
		c + Vector2(0, h * 0.86), c + Vector2(-w * 0.86, h * 0.26)])
	draw_colored_polygon(forest, LEAF)
	# The compass rose: four long points and four short.
	var o := c + Vector2(0, -3)
	for i in 8:
		var a := -PI / 2.0 + i * PI / 4.0
		var long := i % 2 == 0
		var len := 17.0 if long else 9.0
		var tip := o + Vector2(cos(a), sin(a)) * len
		var side := Vector2(cos(a + PI / 2.0), sin(a + PI / 2.0)) * (3.0 if long else 2.0)
		draw_colored_polygon(PackedVector2Array([o + side, tip, o - side]), CORAL if i == 0 else CREAM)
	# The eye at the heart of it.
	var eye := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		eye.append(o + Vector2(lerpf(-8, 8, t), -sin(t * PI) * 4.5))
	for i in range(15, 0, -1):
		var t := float(i) / 16.0
		eye.append(o + Vector2(lerpf(-8, 8, t), sin(t * PI) * 4.5))
	draw_colored_polygon(eye, INK)
	var white := PackedVector2Array(Array(eye).map(func(p: Vector2) -> Vector2: return o + (p - o) * 0.78))
	draw_colored_polygon(white, PAPER)
	draw_circle(o, 2.6, BLUE)
	draw_circle(o, 1.3, INK)


## A lantern hanging from the sign's post, its glow breathing.
func _draw_lantern(p: Vector2) -> void:
	var glow := 0.8 + 0.2 * sin(_time * 3.1) + 0.05 * sin(_time * 17.0)
	draw_circle(p + Vector2(0, 8), 22 * glow, Color(GOLD, 0.10))
	draw_circle(p + Vector2(0, 8), 12 * glow, Color(GOLD, 0.18))
	draw_line(p, p + Vector2(0, 3), INK, 1)
	draw_rect(Rect2(p + Vector2(-4, 3), Vector2(8, 2)), INK)
	draw_rect(Rect2(p + Vector2(-3, 5), Vector2(6, 7)), Color(BUTTER, glow))
	draw_rect(Rect2(p + Vector2(-3, 5), Vector2(6, 7)), INK, false, 1)
	draw_rect(Rect2(p + Vector2(-4, 12), Vector2(8, 2)), INK)


## Short chains from the sign to the hanging menu planks.
func _draw_chains() -> void:
	var r := _sign_rect()
	var top := r.end.y + (-2.0 if _art else 2.0)
	var bottom := buttons.position.y if buttons != null else top + 10
	var cx := r.get_center().x
	for x in [cx - 34.0, cx + 34.0]:
		var y := top
		while y < bottom:
			draw_rect(Rect2(x - 1, y, 2, 2), STONE)
			y += 3
