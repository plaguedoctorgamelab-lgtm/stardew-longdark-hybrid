class_name SocialScreen
extends Control
## The People page and the calendar (Phase 4, 4a step 4), on O. Drawn on
## Mark's ledger page and wall calendar (Art Request 21, A6).
##
## People: everyone met, six to a page: their face, name, hearts (locked
## hearts past a romance's cap), birthday, and whether they've been talked
## to today and given gifts this week.
## Calendar: the season's four weeks, with today, every birthday (a face
## and a cake) and the festival.

const SCALE := 1.6
const SOCIAL_ROWS := [24.0, 42.0, 60.0, 78.0, 95.0, 113.0, 131.0]   # ruled lines on Mark's page
const SOCIAL_X := 22.0
const CAL_LEFT := 20.0
const CAL_TOP := 49.0
const CAL_W := 28.57
const CAL_H := 24.4
const PER_PAGE := 6

signal friends_asked(person: String)

var session: GameSession
var page: String = "people"
var people_page: int = 0
var _font: Font
var _rows: Array = []


func setup(s: GameSession) -> void:
	session = s
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	visible = false


func open(pg: String = "people") -> void:
	page = pg
	people_page = 0
	_rows = session.town.social_rows()
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func turn() -> void:
	page = "calendar" if page == "people" else "people"
	queue_redraw()


func pages() -> int:
	return maxi(1, ceili(float(_rows.size()) / PER_PAGE))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		# A sweetheart's row: talk about just being friends (Phase 4b).
		var who := _row_at((event as InputEventMouseButton).position)
		if who != "" and session.life.dating.has(who):
			friends_asked.emit(who)
			accept_event()
			return
		if page == "people" and pages() > 1:
			people_page = (people_page + 1) % pages()
			queue_redraw()
		accept_event()


## The person on the People page's row under a point, or "".
func _row_at(p: Vector2) -> String:
	if page != "people" or _rows.is_empty():
		return ""
	var o := _paper("ui_social").position
	var first := people_page * PER_PAGE
	for k in range(PER_PAGE):
		if first + k >= _rows.size():
			break
		var top: float = o.y + float(SOCIAL_ROWS[k]) * SCALE
		var bottom: float = o.y + float(SOCIAL_ROWS[k + 1]) * SCALE
		if p.y >= top and p.y < bottom:
			return str(_rows[first + k]["id"])
	return ""


func _paper(name: String) -> Rect2:
	var tex := Art.texture(name)
	var sz := Vector2(tex.get_size()) * SCALE
	return Rect2(((size - sz) / 2.0).round(), sz)


func _text(at: Vector2, t: String, col: Color = KitStyle.TEXT_DARK, fs: int = 8, w: float = -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(_font, at.round(), t, align, w, fs, col)


## A face: the top of the person's standing frame.
func _face(sheet: String, at: Vector2, px: float) -> void:
	if sheet == "" or not Art.has_picture(sheet):
		return
	draw_texture_rect_region(Art.texture(sheet), Rect2(at, Vector2(px, px)), Rect2(0, 4, 16, 16))


func _draw() -> void:
	if session == null:
		return
	if page == "people":
		_draw_people()
	else:
		_draw_calendar()
	_text(Vector2(0, size.y - 4), session.content.text("ui_social_hint"), KitStyle.TEXT_LIGHT, 8, size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_people() -> void:
	var r := _paper("ui_social")
	draw_texture_rect(Art.texture("ui_social"), r, false)
	var o := r.position
	# The title on the leather strap, in light paint.
	draw_string_outline(_font, (o + Vector2(0, 11) * SCALE).round(), session.content.text("ui_social_title"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, 3, KitStyle.INK)
	_text(o + Vector2(0, 11) * SCALE, session.content.text("ui_social_title"), KitStyle.TEXT_LIGHT, 10, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if _rows.is_empty():
		_text(o + Vector2(SOCIAL_X, 52) * SCALE, session.content.text("social_none"))
		return
	var full := Art.texture("ui_heart_full")
	var empty := Art.texture("ui_heart_empty")
	var locked := Art.texture("ui_heart_locked")
	var first := people_page * PER_PAGE
	for k in range(PER_PAGE):
		if first + k >= _rows.size():
			break
		var row: Dictionary = _rows[first + k]
		var top: float = o.y + float(SOCIAL_ROWS[k]) * SCALE
		var bottom: float = o.y + float(SOCIAL_ROWS[k + 1]) * SCALE
		var h := bottom - top
		var x := o.x + SOCIAL_X * SCALE
		_face(str(row["sprite"]), Vector2(x, top + 2), h - 4)
		x += h + 2
		_text(Vector2(x, top + 11), str(row["name"]), KitStyle.TEXT_DARK, 8)
		# On the birthday line: the name line of the top row sits under the
		# page's banner.
		if session.life.dating.has(str(row["id"])):
			var dx := x + 96
			if Art.has_picture("ui_heart_sweet"):
				draw_texture_rect(Art.texture("ui_heart_sweet"), Rect2(Vector2(dx, top + h - 10), Vector2(8, 8)), false)
				dx += 10
			_text(Vector2(dx, top + h - 3), session.content.text("social_dating"), KitStyle.CORAL.darkened(0.2), 7)
		var b: Dictionary = row["birthday"]
		_text(Vector2(x, top + h - 3), session.content.text("social_birthday", {"season": session.content.text("season_" + GameClock.SEASONS[int(b["season"])]), "day": int(b["day"])}), Color(KitStyle.TEXT_DARK, 0.75), 7)
		# Ten hearts: earned, open, or locked past the cap.
		var hx := o.x + 128 * SCALE
		for i in 10:
			var tex := full if i < int(row["hearts"]) else (locked if i >= int(row["cap"]) else empty)
			draw_texture_rect(tex, Rect2(Vector2(hx + i * 9, top + (h - 8) / 2.0), Vector2(8, 8)), false)
		var tx := hx + 92
		if bool(row["talked"]):
			draw_texture_rect(Art.texture("ui_talk_tick"), Rect2(Vector2(tx, top + (h - 8) / 2.0), Vector2(8, 8)), false)
		for g in int(row["gifts"]):
			draw_texture_rect(Art.texture("ui_gift_tick"), Rect2(Vector2(tx + 10 + g * 9, top + (h - 8) / 2.0), Vector2(8, 8)), false)
	if pages() > 1:
		_text(o + Vector2(0, 143) * SCALE, session.content.text("social_more", {"page": people_page + 1, "pages": pages()}), Color(KitStyle.TEXT_DARK, 0.7), 7, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_calendar() -> void:
	var r := _paper("ui_calendar")
	draw_texture_rect(Art.texture("ui_calendar"), r, false)
	var o := r.position
	var c := session.clock
	var season_name := session.content.text("season_" + c.season_name())
	_text(o + Vector2(0, 40) * SCALE - Vector2(0, 2), session.content.text("ui_calendar_title", {"season": season_name, "year": c.year}), KitStyle.TEXT_DARK, 9, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var days := session.town.calendar(c.season)
	for d: Dictionary in days:
		var i := int(d["day"]) - 1
		var cell := Rect2(o + Vector2(CAL_LEFT + (i % 7) * CAL_W, CAL_TOP + (i / 7) * CAL_H) * SCALE, Vector2(CAL_W, CAL_H) * SCALE)
		if int(d["day"]) == c.day:
			draw_rect(cell.grow(-2), Color(0.95, 0.75, 0.3, 0.45))
		_text(cell.position + Vector2(3, 9), str(d["day"]), KitStyle.TEXT_DARK, 8)
		var bx := cell.position.x + cell.size.x - 3
		for id: String in d["birthdays"]:
			var row := session.content.row("townsfolk", id)
			_face(str(row.get("sprite", "")), Vector2(bx - 16, cell.position.y + cell.size.y - 18), 16)
			draw_texture_rect(Art.texture("ui_cal_birthday"), Rect2(Vector2(cell.position.x + 3, cell.position.y + cell.size.y - 15), Vector2(12, 12)), false)
			bx -= 17
		if str(d["festival"]) != "":
			draw_texture_rect(Art.texture("ui_cal_festival"), Rect2(Vector2(cell.position.x + 3, cell.position.y + cell.size.y - 15), Vector2(12, 12)), false)
	# Today's events, written under the grid.
	var today: Dictionary = days[c.day - 1] if c.day - 1 < days.size() else {}
	var notes := PackedStringArray()
	for id: String in today.get("birthdays", []):
		notes.append(session.content.text("cal_birthday", {"name": str(session.content.row("townsfolk", id)["name"]).get_slice(" ", 0)}))
	if str(today.get("festival", "")) != "":
		notes.append(session.content.text("cal_festival", {"name": session.content.text(str(session.content.row("festivals", today["festival"])["name"]))}))
	if not notes.is_empty():
		_text(o + Vector2(0, 156) * SCALE, session.content.text("cal_today") + ": " + ", ".join(notes), KitStyle.TEXT_DARK, 8, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
