class_name RangerPortrait
extends Control
## The ranger standing in a little window on the park at dusk, for the
## backpack page (0.7.9): the sky in bands, the far hills, the near grass,
## and the ranger facing out in what they're wearing, drawn twice size.
## Mark's backdrop (`ui_portrait_backdrop`) is used if it's there.

const SKY := [Color8(52, 46, 92), Color8(86, 64, 118), Color8(150, 86, 122), Color8(218, 120, 104), Color8(246, 178, 112)]
const HILLS_FAR := Color8(62, 74, 108)
const HILLS_NEAR := Color8(40, 97, 67)
const GRASS := Color8(56, 142, 76)
const GRASS_LIGHT := Color8(98, 178, 92)

var session: GameSession


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	session = _find_session()


func _find_session() -> GameSession:
	var n: Node = get_parent()
	while n != null:
		if "session" in n and n.get("session") is GameSession:
			return n.get("session")
		n = n.get_parent()
	return null


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var inner := r.grow(-2)
	if Art.has_picture("ui_portrait_backdrop"):
		draw_texture_rect(Art.texture("ui_portrait_backdrop"), inner, false)
	else:
		_backdrop(inner)
	if session == null:
		session = _find_session()
	if session != null:
		var w := session.wardrobe
		var sheets: Array[String] = [w.base_sheet()]
		sheets.append_array(w.overlays())
		var px := Vector2(32, 64)
		var at := Vector2(((size.x - px.x) / 2.0), size.y - px.y - 5).round()
		# A soft shadow under the feet.
		draw_rect(Rect2(at + Vector2(6, px.y - 3), Vector2(px.x - 12, 3)), Color(0, 0, 0, 0.25))
		for sheet: String in sheets:
			if Art.has_picture(sheet):
				draw_texture_rect_region(Art.texture(sheet), Rect2(at, px), Rect2(0, 0, 16, 32))
	# The window's wooden edge.
	draw_rect(r, KitStyle.WOOD_DARK, false, 2.0)
	draw_rect(r.grow(-2), KitStyle.WOOD_MID, false, 1.0)


func _backdrop(r: Rect2) -> void:
	# Dusk in five bands, darkest at the top.
	var band := ceilf(r.size.y * 0.62 / SKY.size())
	for i in SKY.size():
		draw_rect(Rect2(r.position + Vector2(0, i * band), Vector2(r.size.x, band + 1)), SKY[i])
	# A first star or two.
	draw_rect(Rect2(r.position + Vector2(9, 5), Vector2(1, 1)), Color(1, 1, 0.85))
	draw_rect(Rect2(r.position + Vector2(r.size.x - 12, 9), Vector2(1, 1)), Color(1, 1, 0.85, 0.7))
	var horizon := r.position.y + r.size.y * 0.58
	# Far hills, then pines on the near ridge, in steps of two pixels.
	var x := r.position.x
	while x < r.end.x:
		var t := (x - r.position.x) / r.size.x
		var h := 6.0 + 5.0 * sin(t * 5.2 + 0.6)
		draw_rect(Rect2(Vector2(x, horizon - h), Vector2(2, r.end.y - horizon + h)), HILLS_FAR)
		x += 2.0
	x = r.position.x
	while x < r.end.x:
		var t2 := (x - r.position.x) / r.size.x
		var h2 := 3.0 + 2.0 * sin(t2 * 9.0 + 2.0)
		if int(x) % 9 < 2:
			h2 += 6.0   # a pine's point
		draw_rect(Rect2(Vector2(x, horizon + 6 - h2), Vector2(2, r.end.y - horizon)), HILLS_NEAR)
		x += 2.0
	# The grass the ranger stands on.
	var gy := r.end.y - 14
	draw_rect(Rect2(Vector2(r.position.x, gy), Vector2(r.size.x, 14)), GRASS)
	for k in range(0, int(r.size.x), 5):
		draw_rect(Rect2(Vector2(r.position.x + k + (k % 3), gy + 2 + (k % 4)), Vector2(1, 2)), GRASS_LIGHT)
