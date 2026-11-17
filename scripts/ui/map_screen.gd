class_name MapScreen
extends Panel
## The map sheet. Blank parchment that fills in with revealed ground, the
## dotted trace, mapped landmarks and, when the ranger knows where they are,
## the position marker. The sheet covers the whole region, so the view pans
## (walking keys) and zooms (mouse wheel). Only changed chunks are redrawn.

const PAPER := Color(0.9, 0.84, 0.68)
const TRACE := Color(0.25, 0.18, 0.12)
const HINT := Color(0.55, 0.15, 0.1)
const GROUND_COLORS := {
	"trail": Color(0.72, 0.55, 0.36),
	"grass": Color(0.68, 0.76, 0.5),
	"tall_grass": Color(0.6, 0.72, 0.42),
	"forest_floor": Color(0.47, 0.58, 0.38),
	"shallows": Color(0.55, 0.72, 0.8),
	"deep_water": Color(0.33, 0.5, 0.66),
	"rock": Color(0.55, 0.53, 0.5),
	"bog": Color(0.45, 0.52, 0.42),
	"boards": Color(0.62, 0.45, 0.3),
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
	marker = ColorRect.new()
	marker.size = Vector2(4, 4)
	marker.color = Color(0.85, 0.1, 0.1)
	clip.add_child(marker)
	image = Image.create(s.world.width, s.world.height, false, Image.FORMAT_RGB8)
	image.fill(PAPER)
	texture = ImageTexture.create_from_image(image)
	map_rect.texture = texture
	visible = false


func _label(pos: Vector2, text: String) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	add_child(l)
	return l


static func _paint_tile(img: Image, s: GameSession, t: Vector2i) -> void:
	var m := s.map
	var c := PAPER
	if m.is_revealed(t):
		c = GROUND_COLORS.get(s.world.ground_at(t), PAPER)
	if m.is_traced(t) and (t.x + t.y) % 2 == 0:
		c = TRACE
	img.set_pixelv(t, c)


static func _paint_chunk(img: Image, s: GameSession, c: Vector2i) -> void:
	var cs := s.world.chunk_size
	for ly in cs:
		for lx in cs:
			var t := c * cs + Vector2i(lx, ly)
			if t.x < img.get_width() and t.y < img.get_height():
				_paint_tile(img, s, t)


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
	if d["all"]:
		image.fill(PAPER)
		var b := session.world.baked_bounds()
		var cs := session.world.chunk_size
		for cy in range(b.position.y / cs, b.end.y / cs):
			for cx in range(b.position.x / cs, b.end.x / cs):
				var c := Vector2i(cx, cy)
				if session.world.has_chunk_file(c) and _chunk_has_marks(c):
					_paint_chunk(image, session, c)
	else:
		for c: Vector2i in d["chunks"]:
			_paint_chunk(image, session, c)
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
