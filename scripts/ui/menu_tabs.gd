class_name MenuTabs
extends Control
## The game menu's tabs (0.7.9): round scout patches sewn along the top of
## whichever menu page is open: Pack, Jobs, Map, Town, Make and Book. Click
## one to turn to that page; each also keeps its own key. The open page's
## patch is bigger, with a gold stitch.

signal chosen(id: String)

## [id, pictures (the first found is used), text id, patch colour]
const TABS := [
	["backpack", ["ui_patch_pack", "ui_tab_backpack", "item_backpack"], "menu_tab_backpack", Color8(56, 142, 76)],
	["jobs", ["ui_patch_jobs", "ui_tab_ledger"], "menu_tab_jobs", Color8(199, 144, 95)],
	["map", ["ui_patch_map", "item_map"], "menu_tab_map", Color8(78, 140, 190)],
	["people", ["ui_patch_town", "ui_heart_full"], "menu_tab_people", Color8(232, 115, 95)],
	["crafting", ["ui_patch_make", "item_hammer"], "menu_tab_crafting", Color8(157, 102, 62)],
	["book", ["ui_patch_book", "ui_tab_book"], "menu_tab_book", Color8(120, 92, 150)],
]
const R := 10.0          # a patch's radius
const R_OPEN := 12.0
const STEP := 27.0

var current: String = ""
var _hover: int = -1
var _labels: Array[String] = []
var _icons: Array[Texture2D] = []


func setup(c: ContentDB) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(TABS.size() * STEP + 4, R_OPEN * 2 + 4)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for t: Array in TABS:
		_labels.append(c.text(t[2]))
		var tex: Texture2D = null
		for pic: String in t[1]:
			if Art.has_picture(pic):
				tex = Art.texture(pic)
				break
		_icons.append(tex)
	visible = false


func _center(i: int) -> Vector2:
	return Vector2(R_OPEN + 2 + i * STEP, R_OPEN + 2)


func _at(p: Vector2) -> int:
	for i in TABS.size():
		if p.distance_to(_center(i)) <= R + 2:
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _at((event as InputEventMouseMotion).position)
		if h != _hover:
			_hover = h
			tooltip_text = _labels[h] if h >= 0 else ""
			queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var i := _at((event as InputEventMouseButton).position)
		if i >= 0:
			chosen.emit(str(TABS[i][0]))
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		queue_redraw()


## Shows the patches over a page whose top-left corner is `at`.
func show_over(id: String, at: Vector2) -> void:
	position = (at - Vector2(-8, size.y - 8)).round()
	position.y = maxf(0.0, position.y)
	position.x = clampf(position.x, 0.0, 480.0 - size.x)
	if id != current:
		current = id
		queue_redraw()
	visible = true


func _draw() -> void:
	for i in TABS.size():
		var open := str(TABS[i][0]) == current
		var r := R_OPEN if open else R
		var c := _center(i) + (Vector2(0, 0) if open else Vector2(0, 1))
		var art: String = "ui_patch_" + str(["pack", "jobs", "map", "town", "make", "book"][i])
		if Art.has_picture(art):
			# Mark's patches (Art Request 22): the open one bigger, the rest
			# a touch dimmer until pointed at.
			var s := 24.0   # pixel for pixel, so the stitching stays crisp
			c.y = R_OPEN + 2 - (2.0 if open else 0.0)
			var m := Color.WHITE if open or i == _hover else Color(0.82, 0.8, 0.78)
			draw_circle(c + Vector2(0, 1.5), s / 2.0, Color(KitStyle.INK, 0.45))
			draw_texture_rect(Art.texture(art), Rect2((c - Vector2(s, s) / 2.0).round(), Vector2(s, s)), false, m)
			if open:
				draw_arc(c, s / 2.0 + 0.5, 0, TAU, 32, KitStyle.GOLD, 1.0)
			continue
		var col: Color = TABS[i][3]
		if not open:
			col = col.lerp(Color8(120, 110, 100), 0.35)
		if i == _hover and not open:
			col = col.lightened(0.15)
		# Shadow, the cloth, the rolled edge, then the stitches round it.
		draw_circle(c + Vector2(0, 1), r + 1, Color(KitStyle.INK, 0.45))
		draw_circle(c, r + 1, KitStyle.INK)
		draw_circle(c, r, col.darkened(0.25))
		draw_circle(c, r - 1.5, col)
		var stitch := KitStyle.GOLD if open else KitStyle.CREAM
		var n := 14 if open else 12
		for k in n:
			var a := TAU * k / n
			var p := c + Vector2(cos(a), sin(a)) * (r - 1.0)
			draw_rect(Rect2(p.round() - Vector2(0.5, 0.5), Vector2(1, 1)), stitch)
		var tex := _icons[i]
		if tex != null:
			var s := 14.0 if open else 12.0
			draw_texture_rect(tex, Rect2((c - Vector2(s, s) / 2.0).round(), Vector2(s, s)), false)
