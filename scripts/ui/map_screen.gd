class_name MapScreen
extends Panel
## The map sheet, drawn as a park poster map (docs/art/visual_direction_brief.md):
## blank parchment that fills in with revealed ground in flat poster colours
## from the bright palette, the dotted trace, red stars at mapped landmarks
## and, when the ranger knows where they are, the position marker. A compass
## rose, a legend and the park's name in big letters sit in the corners. The
## sheet covers the whole region, so the view pans (walking keys) and zooms
## (mouse wheel). Only changed chunks are redrawn. Mark's Art Request 13
## pieces (map_*) are used when they are there: his parchment shows through
## the land not yet surveyed, and his compass, star, site pictograms, legend
## frame and lettering dress the corners; drawn stand-ins fill any gaps.

const PAPER := Color8(225, 205, 160)
const TRACE := Color8(93, 62, 48)
const HINT := Color8(176, 40, 32)
const STAR := Color8(232, 115, 95)
const INK := Color8(26, 22, 32)
const GROUND_COLORS := {
	"trail": Color8(157, 102, 62),
	"grass": Color8(250, 240, 210),
	"tall_grass": Color8(214, 241, 162),
	"forest_floor": Color8(167, 218, 133),
	"shallows": Color8(95, 172, 207),
	"deep_water": Color8(38, 112, 157),
	"rock": Color8(198, 204, 210),
	"bog": Color8(182, 162, 110),
	"boards": Color8(93, 62, 48),
}
const ZOOMS: Array[float] = [0.25, 0.5, 1.0, 2.0]
const VIEW_SIZE := Vector2(384, 250)
const PAN_SPEED := 160.0   # map pixels per second at zoom 1

var session: GameSession
var clip: Control
var map_rect: TextureRect
var overlay: Control
var marker: ColorRect
var title: Label
var percent: Label
var lost: Label
var landmark_labels: Control
var travel_box: VBoxContainer
var deco: Control
var _painted: bool = false   # the first open paints the whole sheet
var paper_tile: TextureRect   # Mark's parchment, under the land not yet surveyed
var _blank: Color = PAPER     # what land not yet surveyed is painted on the screen's sheet
var image: Image
var texture: ImageTexture
var zoom_index: int = 2
var center: Vector2 = Vector2.ZERO   # the map point in the middle of the view


func setup(s: GameSession) -> void:
	session = s
	size = Vector2(400, 270)
	position = Vector2(40, 0)
	title = _label(Vector2(8, 2), s.content.text("map_title"))
	percent = _label(Vector2(150, 2), "")
	lost = _label(Vector2(250, 2), "")
	clip = Control.new()
	clip.position = Vector2(8, 13)
	clip.size = VIEW_SIZE
	clip.clip_contents = true
	add_child(clip)
	var paper := ColorRect.new()
	paper.color = PAPER
	paper.size = VIEW_SIZE
	clip.add_child(paper)
	if Art.has_picture("map_paper"):
		# The sheet leaves unsurveyed land clear, so the parchment shows.
		_blank = Color(0, 0, 0, 0)
		paper_tile = TextureRect.new()
		paper_tile.texture = Art.texture("map_paper")
		paper_tile.stretch_mode = TextureRect.STRETCH_TILE
		paper_tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		paper_tile.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		paper_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(paper_tile)
	map_rect = TextureRect.new()
	map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	clip.add_child(map_rect)
	overlay = Control.new()
	overlay.size = VIEW_SIZE
	overlay.draw.connect(_draw_overlay)
	clip.add_child(overlay)
	landmark_labels = Control.new()
	clip.add_child(landmark_labels)
	# The poster's corners: compass rose, legend and the park's name.
	deco = Control.new()
	deco.size = VIEW_SIZE
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(_draw_deco)
	clip.add_child(deco)
	marker = ColorRect.new()
	marker.size = Vector2(4, 4)
	marker.color = Color(0.85, 0.1, 0.1)
	clip.add_child(marker)
	image = Image.create(s.world.width, s.world.height, false, Image.FORMAT_RGBA8)
	image.fill(_blank)
	texture = ImageTexture.create_from_image(image)
	map_rect.texture = texture
	# Trail travel: places the ranger can walk to in one go, from the trail.
	travel_box = VBoxContainer.new()
	travel_box.position = Vector2(size.x - 4, 16)
	travel_box.add_theme_constant_override("separation", 1)
	add_child(travel_box)
	visible = false


## Fills the trail travel list; hidden when there is nowhere to go.
func _fill_travel() -> void:
	for c in travel_box.get_children():
		c.queue_free()
	var opts := session.travel_options()
	travel_box.visible = not opts.is_empty()
	if opts.is_empty():
		return
	var head := Label.new()
	head.text = session.content.text("ui_travel_title")
	head.add_theme_font_size_override("font_size", 8)
	travel_box.add_child(head)
	for o: Dictionary in opts:
		var b := Button.new()
		b.text = str(o["label"])
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 8)
		var id: String = o["id"]
		b.pressed.connect(func() -> void:
			close()
			session.travel_to(id))
		travel_box.add_child(b)
	travel_box.reset_size()
	travel_box.position = Vector2(size.x - 6 - travel_box.get_combined_minimum_size().x, 16)


func _label(pos: Vector2, text: String) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	add_child(l)
	return l


static func _paint_tile(img: Image, s: GameSession, t: Vector2i, blank: Color = PAPER) -> void:
	var m := s.map
	var c := blank
	if m.is_revealed(t):
		c = GROUND_COLORS.get(s.world.ground_at(t), PAPER)
	if m.is_traced(t) and (t.x + t.y) % 2 == 0:
		c = TRACE
	img.set_pixelv(t, c)


static func _paint_chunk(img: Image, s: GameSession, c: Vector2i, blank: Color = PAPER) -> void:
	var cs := s.world.chunk_size
	for ly in cs:
		for lx in cs:
			var t := c * cs + Vector2i(lx, ly)
			if t.x < img.get_width() and t.y < img.get_height():
				_paint_tile(img, s, t, blank)


## Draws the whole map picture from the map state, over `area` (the built
## part of the world when left empty). Used by tests; the screen redraws only
## changed chunks.
static func render(s: GameSession, area: Rect2i = Rect2i()) -> Image:
	var img := Image.create(s.world.width, s.world.height, false, Image.FORMAT_RGB8)
	img.fill(PAPER)
	if area.size == Vector2i.ZERO:
		area = s.world.baked_bounds()
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			_paint_tile(img, s, Vector2i(x, y))
	for hint: Dictionary in hints(s):
		for px: Vector2i in hint_pixels(hint):
			if px.x >= 0 and px.y >= 0 and px.x < img.get_width() and px.y < img.get_height():
				img.set_pixelv(px, HINT)
	return img


## The map points of a hint's dashed circle.
static func hint_pixels(hint: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c: Vector2 = hint["center"]
	var r: float = hint["radius"]
	var steps := int(TAU * r * 1.5)
	for i in steps:
		if (i / 3) % 2 == 1:
			continue
		var a := TAU * i / steps
		out.append(Vector2i((c + Vector2(cos(a), sin(a)) * r).round()))
	return out


## Hints for landmarks not yet mapped: {center, radius, text}.
static func hints(s: GameSession) -> Array:
	var out := []
	for r: Dictionary in s.content.rows("landmarks"):
		if not r.has("hint") or s.map.is_landmark_mapped(r["id"]):
			continue
		if not s.hint_known(r["id"]):
			continue
		var hint: Dictionary = r["hint"]
		var off := Vector2(float(hint["offset"][0]), float(hint["offset"][1]))
		out.append({"center": s.world.landmark_pos(r["id"]) + off, "radius": float(hint["radius"]), "text": s.content.text(hint["text"])})
	# A lost party: a rough circle around where they were last seen.
	var lost := s.lost_hint()
	if not lost.is_empty():
		out.append(lost)
	return out


## Redraws whatever changed since the picture was last drawn.
func refresh_picture() -> void:
	var d := session.map.take_dirty()
	if d["all"] or not _painted:
		_painted = true
		image.fill(_blank)
		var b := session.world.baked_bounds()
		var cs := session.world.chunk_size
		for cy in range(b.position.y / cs, b.end.y / cs):
			for cx in range(b.position.x / cs, b.end.x / cs):
				var c := Vector2i(cx, cy)
				if session.world.has_chunk_file(c) and _chunk_has_marks(c):
					_paint_chunk(image, session, c, _blank)
	else:
		for c: Vector2i in d["chunks"]:
			_paint_chunk(image, session, c, _blank)
	texture.update(image)


## True when a chunk holds anything revealed or traced, so blank chunks are skipped.
func _chunk_has_marks(c: Vector2i) -> bool:
	var m := session.map
	var cs := session.world.chunk_size
	for ly in cs:
		var at := (c.y * cs + ly) * m.width + c.x * cs
		if m.revealed.slice(at, at + cs).has(1) or m.traced.slice(at, at + cs).has(1):
			return true
	return false


func zoom() -> float:
	return ZOOMS[zoom_index]


func open() -> void:
	refresh_picture()
	percent.text = session.content.text("map_revealed", {"percent": "%d" % int(session.map.percent_revealed())})
	var shown := session.marker_visible()
	lost.text = "" if shown else session.content.text("map_lost")
	if shown:
		center = _ranger_map_pos()
	elif center == Vector2.ZERO:
		center = session.door_front("ranger_station")
	visible = true
	_fill_travel()
	_layout()


func _ranger_map_pos() -> Vector2:
	if session.is_indoors():
		return session.door_front(session.location)
	return session.outdoor_pos


## Places the picture, labels and marker for the current pan and zoom.
func _layout() -> void:
	var z := zoom()
	# Keep the built part of the world in view: centred when it all fits,
	# otherwise never panned past its edge.
	var b := session.world.baked_bounds()
	var half := VIEW_SIZE / 2.0 / z
	for axis in 2:
		var lo := float(b.position[axis]) + half[axis]
		var hi := float(b.end[axis]) - half[axis]
		center[axis] = (float(b.position[axis]) + float(b.end[axis])) / 2.0 if lo > hi else clampf(center[axis], lo, hi)
	map_rect.size = Vector2(image.get_width(), image.get_height()) * z
	map_rect.position = (VIEW_SIZE / 2.0 - center * z).round()
	if paper_tile != null:
		# The parchment moves with the map, so it pans with the land.
		paper_tile.position = map_rect.position
		paper_tile.size = map_rect.size
	for c in landmark_labels.get_children():
		c.queue_free()
	for r: Dictionary in session.content.rows("landmarks"):
		if session.map.is_landmark_mapped(r["id"]):
			var label := session.content.text(r["name"])
			if session.sites_open.has(r["id"]):
				label = session.content.text("map_site_open", {"name": label})
			_add_label(label, session.world.landmark_pos(r["id"]), Vector2(3, -6), Color.WHITE, false)
	if session.debug_show_visitors:
		for p: Dictionary in session.park.parties:
			var vp := map_rect.position + (p["pos"] as Vector2) * z
			overlay.draw_rect(Rect2(vp - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.9, 0.2, 0.6))
		for bd: Dictionary in session.park.badgers:
			var bp := map_rect.position + (Vector2(bd["tile"]) + Vector2(0.5, 0.5)) * z
			overlay.draw_rect(Rect2(bp - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.2, 0.2, 0.2))
	for h: Dictionary in hints(session):
		_add_label(h["text"], (h["center"] as Vector2) + Vector2(0, float(h["radius"])), Vector2(-18, 1), HINT, true)
	var shown := session.marker_visible()
	marker.visible = shown
	if shown:
		marker.position = map_rect.position + _ranger_map_pos() * z - Vector2(2, 2)
	overlay.queue_redraw()
	deco.queue_redraw()


func _add_label(text: String, at: Vector2, nudge: Vector2, color: Color, tinted: bool) -> void:
	var l := Label.new()
	l.text = text
	if tinted:
		l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 8)
	l.position = map_rect.position + at * zoom() + nudge
	landmark_labels.add_child(l)


func _draw_overlay() -> void:
	var z := zoom()
	# A mapped landmark: its pictogram if Mark drew one, else a red star.
	for r: Dictionary in session.content.rows("landmarks"):
		if session.map.is_landmark_mapped(r["id"]):
			_mark(overlay, map_rect.position + session.world.landmark_pos(r["id"]) * z, str(r["id"]))
	# The station is always on the map, as home.
	if Art.has_picture("map_icon_ranger_station"):
		_mark(overlay, map_rect.position + session.door_front("ranger_station") * z + Vector2(0, -8), "ranger_station")
	for t: Vector2i in session.placed:
		# A cairn shows only once its ground is revealed.
		if not session.map_shows_placed(t):
			continue
		var p := map_rect.position + (Vector2(t) + Vector2(0.5, 0.5)) * z
		var is_sign := str(session.placed[t]["place"]) != ""
		var r := 2.0 if is_sign else 1.0
		overlay.draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), Color(0.4, 0.22, 0.1) if is_sign else HINT)
	for h: Dictionary in hints(session):
		var c: Vector2 = h["center"]
		var r: float = h["radius"]
		var steps := maxi(24, int(TAU * r * z / 3.0))
		for i in steps:
			if i % 2 == 1:
				continue
			var a0 := TAU * i / steps
			var a1 := TAU * (i + 1) / steps
			var p0 := map_rect.position + (c + Vector2(cos(a0), sin(a0)) * r) * z
			var p1 := map_rect.position + (c + Vector2(cos(a1), sin(a1)) * r) * z
			overlay.draw_line(p0, p1, HINT, 1.0)


## A place's mark: Mark's pictogram for it, his star, or a drawn star.
func _mark(on: CanvasItem, c: Vector2, place: String) -> void:
	var icon := "map_icon_" + place
	if Art.has_picture(icon):
		var tex := Art.texture(icon)
		on.draw_texture(tex, (c - Vector2(tex.get_size()) / 2.0).round())
	elif Art.has_picture("map_star"):
		var star := Art.texture("map_star")
		on.draw_texture(star, (c - Vector2(star.get_size()) / 2.0).round())
	else:
		_star(on, c, 4.5, STAR)


## A five-pointed star with a dark edge.
static func _star(on: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	var edge := PackedVector2Array(Array(pts).map(func(p: Vector2) -> Vector2: return c + (p - c) * 1.35))
	on.draw_colored_polygon(edge, INK)
	on.draw_colored_polygon(pts, col)


func _deco_text(s: String, at: Vector2, px: int, col: Color, outline: int) -> void:
	var f := ThemeDB.fallback_font
	if outline > 0:
		deco.draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, PAPER)
	deco.draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


## The poster's fixed corners: a compass rose at the top left, a legend at
## the bottom right, and the park's name along the bottom right under it.
func _draw_deco() -> void:
	var c := session.content
	# Compass rose.
	var o := Vector2(24, 24)
	if Art.has_picture("map_compass"):
		deco.draw_texture(Art.texture("map_compass"), Vector2(6, 6))
		_draw_legend_and_name()
		return
	deco.draw_circle(o, 15, Color(PAPER, 0.85))
	deco.draw_arc(o, 15, 0, TAU, 32, TRACE, 1.0)
	for i in 8:
		var a := -PI / 2.0 + i * PI / 4.0
		var long := i % 2 == 0
		var tip := o + Vector2(cos(a), sin(a)) * (13.0 if long else 7.0)
		var side := Vector2(cos(a + PI / 2.0), sin(a + PI / 2.0)) * (2.5 if long else 1.5)
		deco.draw_colored_polygon(PackedVector2Array([o + side, tip, o - side]), STAR if i == 0 else TRACE)
	_deco_text("N", o + Vector2(-3, -17), 7, TRACE, 2)
	_draw_legend_and_name()


func _draw_legend_and_name() -> void:
	var c := session.content
	# Legend.
	var box := Rect2(VIEW_SIZE.x - 92, VIEW_SIZE.y - 80, 86, 50)
	if Art.has_picture("map_legend"):
		var frame := StyleBoxTexture.new()
		frame.texture = Art.texture("map_legend")
		frame.set_texture_margin_all(6)
		# The frame's border only: its middle has ruled lines that would run
		# through the legend's words, so the inside is plain paper.
		frame.draw_center = false
		deco.draw_rect(box, Color(PAPER, 0.95))
		deco.draw_style_box(frame, box.grow(2))
	else:
		deco.draw_rect(box, Color(PAPER, 0.92))
		deco.draw_rect(box, TRACE, false, 1.0)
	_deco_text(c.text("map_legend").to_upper(), box.position + Vector2(4, 9), 7, TRACE, 0)
	var rows := [["star", "map_legend_landmark"], ["trail", "map_legend_trail"], ["water", "map_legend_water"], ["forest", "map_legend_forest"], ["you", "map_legend_you"]]
	for i in rows.size():
		var y := box.position.y + 16 + i * 7.5
		var k: String = rows[i][0]
		var at := Vector2(box.position.x + 9, y)
		match k:
			"star":
				if Art.has_picture("map_star"):
					var st := Art.texture("map_star")
					deco.draw_texture(st, (at - Vector2(st.get_size()) / 2.0).round())
				else:
					_star(deco, at, 3.0, STAR)
			"trail":
				deco.draw_line(at - Vector2(4, 0), at + Vector2(4, 0), GROUND_COLORS["trail"], 2.0)
			"water":
				deco.draw_rect(Rect2(at - Vector2(4, 2), Vector2(8, 4)), GROUND_COLORS["shallows"])
			"forest":
				deco.draw_rect(Rect2(at - Vector2(4, 2), Vector2(8, 4)), GROUND_COLORS["forest_floor"])
			"you":
				deco.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), marker.color)
		_deco_text(c.text(rows[i][1]), at + Vector2(8, 2.5), 7, TRACE, 0)
	# The park's name, poster-style, along the bottom right.
	var f := ThemeDB.fallback_font
	if Art.has_picture("map_park_name"):
		var pn := Art.texture("map_park_name")
		deco.draw_texture(pn, Vector2(VIEW_SIZE.x - 188, VIEW_SIZE.y - 27))
		var sub0 := c.text("map_poster_subtitle").to_upper()
		var sw0 := f.get_string_size(sub0, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		_deco_text(sub0, Vector2(VIEW_SIZE.x - sw0 - 8, VIEW_SIZE.y - 4), 7, TRACE, 2)
		return
	var name := c.text("title_park").to_upper()
	var w := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var at2 := Vector2(VIEW_SIZE.x - w - 8, VIEW_SIZE.y - 14)
	_deco_text(name, at2 + Vector2(1, 1), 16, STAR, 3)
	_deco_text(name, at2, 16, TRACE, 0)
	var sub := c.text("map_poster_subtitle").to_upper()
	var sw := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	_deco_text(sub, Vector2(VIEW_SIZE.x - sw - 8, VIEW_SIZE.y - 4), 7, TRACE, 2)


func pan(dir: Vector2, delta: float) -> void:
	if dir == Vector2.ZERO:
		return
	center += dir * PAN_SPEED * delta / zoom()
	_layout()


func change_zoom(step: int) -> void:
	zoom_index = clampi(zoom_index + step, 0, ZOOMS.size() - 1)
	_layout()


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	pan(Input.get_vector("move_left", "move_right", "move_up", "move_down"), delta)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			change_zoom(1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			change_zoom(-1)
