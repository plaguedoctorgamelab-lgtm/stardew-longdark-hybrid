class_name MapScreen
extends Panel
## The map sheet. Blank parchment that fills in with revealed ground, the
## dotted trace, mapped landmarks and, when the ranger knows where they are,
## the position marker.

const PAPER := Color(0.9, 0.84, 0.68)
const GROUND_COLORS := {
	"trail": Color(0.72, 0.55, 0.36),
	"grass": Color(0.68, 0.76, 0.5),
	"tall_grass": Color(0.6, 0.72, 0.42),
	"forest_floor": Color(0.47, 0.58, 0.38),
	"shallows": Color(0.55, 0.72, 0.8),
	"deep_water": Color(0.33, 0.5, 0.66),
	"rock": Color(0.55, 0.53, 0.5),
}

var session: GameSession
var map_rect: TextureRect
var marker: ColorRect
var title: Label
var percent: Label
var lost: Label
var landmark_labels: Node
var image: Image


func setup(s: GameSession) -> void:
	session = s
	size = Vector2(400, 270)
	position = Vector2(40, 0)
	title = _label(Vector2(8, 2), s.content.text("map_title"))
	percent = _label(Vector2(150, 2), "")
	lost = _label(Vector2(250, 2), "")
	map_rect = TextureRect.new()
	map_rect.position = Vector2(8, 13)
	map_rect.size = Vector2(s.world.width, s.world.height)
	add_child(map_rect)
	landmark_labels = Node2D.new()
	add_child(landmark_labels)
	marker = ColorRect.new()
	marker.size = Vector2(4, 4)
	marker.color = Color(0.85, 0.1, 0.1)
	add_child(marker)
	visible = false


func _label(pos: Vector2, text: String) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	add_child(l)
	return l


## Draws the map picture from the map state. Also used by tests.
static func render(s: GameSession) -> Image:
	var w := s.world.width
	var h := s.world.height
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(PAPER)
	var m := s.map
	for y in h:
		for x in w:
			var t := Vector2i(x, y)
			if m.is_revealed(t):
				img.set_pixel(x, y, GROUND_COLORS.get(s.world.ground_at(t), PAPER))
			if m.is_traced(t) and (x + y) % 2 == 0:
				img.set_pixel(x, y, Color(0.25, 0.18, 0.12))
	# Rough hints of places not yet mapped, drawn as dashed circles.
	for hint: Dictionary in hints(s):
		var c: Vector2 = hint["center"]
		var r: float = hint["radius"]
		var steps := int(TAU * r * 1.5)
		for i in steps:
			if (i / 3) % 2 == 1:
				continue
			var a := TAU * i / steps
			var px := Vector2i((c + Vector2(cos(a), sin(a)) * r).round())
			if px.x >= 0 and px.y >= 0 and px.x < w and px.y < h:
				img.set_pixelv(px, Color(0.55, 0.15, 0.1))
	return img


## Hints for landmarks not yet mapped: {center, radius, text}.
static func hints(s: GameSession) -> Array:
	var out := []
	for r: Dictionary in s.content.rows("landmarks"):
		if not r.has("hint") or s.map.is_landmark_mapped(r["id"]):
			continue
		var hint: Dictionary = r["hint"]
		var off := Vector2(float(hint["offset"][0]), float(hint["offset"][1]))
		out.append({"center": s.world.landmark_pos(r["id"]) + off, "radius": float(hint["radius"]), "text": s.content.text(hint["text"])})
	return out


func open() -> void:
	image = render(session)
	map_rect.texture = ImageTexture.create_from_image(image)
	percent.text = session.content.text("map_revealed", {"percent": "%d" % int(session.map.percent_revealed())})
	for c in landmark_labels.get_children():
		c.queue_free()
	for r: Dictionary in session.content.rows("landmarks"):
		if session.map.is_landmark_mapped(r["id"]):
			var p := session.world.landmark_pos(r["id"])
			var l := Label.new()
			l.text = session.content.text(r["name"])
			l.add_theme_font_size_override("font_size", 8)
			l.position = map_rect.position + p + Vector2(3, -6)
			landmark_labels.add_child(l)
	for h: Dictionary in hints(session):
		var l := Label.new()
		l.text = h["text"]
		l.add_theme_color_override("font_color", Color(0.55, 0.15, 0.1))
		l.add_theme_font_size_override("font_size", 8)
		l.position = map_rect.position + (h["center"] as Vector2) + Vector2(-18, float(h["radius"]) + 1.0)
		landmark_labels.add_child(l)
	var shown := session.marker_visible()
	marker.visible = shown
	lost.text = "" if shown else session.content.text("map_lost")
	if shown:
		var p := session.outdoor_pos
		if session.is_indoors():
			p = session.door_front(session.location)
		marker.position = map_rect.position + p - Vector2(2, 2)
	visible = true


func close() -> void:
	visible = false
