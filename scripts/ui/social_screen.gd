class_name SocialScreen
extends Sheet
## The Town sheet (the cozy UI plan, 0.7.17), on O: the People page and the
## calendar on the ranger's clipboard, at its size like every page. Two
## picture tabs turn between them (Q and E too).
##
## People: a card for everyone met, with their face and ten small hearts.
## The chosen one in full on the right: their portrait, their hearts (a
## sweetheart's heart when dating), chips for their birthday, whether
## they've been talked to today, the week's gifts and where they are now,
## then tiles for the gifts they love and like that the ranger has learned
## by giving them, with a "?" for each still to find. A sweetheart's sheet
## has a "Just friends" stamp.
## Calendar: the season's four weeks on the paper, with today, every
## birthday (a face and a cake) and the festival.

signal friends_asked(person: String)

const PER_PAGE := 6   # kept for older callers
const CAL_COLS := 7

var page: String = "people"
var people_page: int = 0
var selected: String = ""
var _rows: Array = []
var _cal: Control


func setup(s: GameSession) -> void:
	setup_sheet(s)
	set_clip(["clip_town"])
	_cal = Control.new()
	_cal.position = PAPER.position + Vector2(2, 16)
	_cal.size = Vector2(PAPER.size.x - 4, PAPER.size.y - 20)
	_cal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cal.draw.connect(_draw_calendar)
	add_child(_cal)


func open(pg: String = "people") -> void:
	page = pg
	people_page = 0
	_rows = session.town.social_rows()
	if selected == "" or not _rows.any(func(r: Dictionary) -> bool: return str(r["id"]) == selected):
		selected = str(_rows[0]["id"]) if not _rows.is_empty() else ""
	visible = true
	refresh()


func turn() -> void:
	page = "calendar" if page == "people" else "people"
	refresh()


func pages() -> int:
	return 1


func refresh() -> void:
	if not visible:
		return
	var c := session.content
	set_index_tabs([
		{"id": "people", "label": c.text("town_tab_people"), "icon": pick(["ui_heart_full"])},
		{"id": "calendar", "label": c.text("town_tab_calendar"), "icon": pick(["icon_cake", "ui_cal_birthday"])},
	], page, func(t: String) -> void:
		page = t
		refresh())
	var people := page == "people"
	list_scroll.visible = people
	detail_scroll.visible = people
	stamps.visible = people
	_cal.visible = not people
	empty_label.visible = people and _rows.is_empty()
	empty_label.text = c.text("social_none")
	clear(list)
	clear(detail)
	clear(stamps)
	if people:
		_fill_list()
		_fill_detail()
	else:
		_cal.queue_redraw()
	set_keys([[["Tab"], c.text("key_sheets")], [["Q", "E"], c.text("town_key_turn")], [["W", "S"], c.text("key_list")], [["O", "Esc"], c.text("key_close")]])


## A face: the top of the person's standing frame.
static func face(sheet: String) -> Texture2D:
	if sheet == "" or not Art.has_picture(sheet):
		return null
	var a := AtlasTexture.new()
	a.atlas = Art.texture(sheet)
	a.region = Rect2(0, 4, 16, 16)
	return a


func _choose(id: String) -> void:
	if id == selected:
		return
	selected = id
	refresh()


func _hearts(n: int, cap: int, px: float) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 1)
	for i in 10:
		var r := TextureRect.new()
		var pic := "ui_heart_full" if i < n else ("ui_heart_locked" if i >= cap else "ui_heart_empty")
		r.texture = Art.texture(pic) if Art.has_picture(pic) else null
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.custom_minimum_size = Vector2(px, px)
		h.add_child(r)
	return h


func _fill_list() -> void:
	for r: Dictionary in _rows:
		var id := str(r["id"])
		var foot := _hearts(int(r["hearts"]), int(r["cap"]), 5)
		var cd := card("", str(r["name"]).get_slice(" ", 0), foot, id == selected, func() -> void: _choose(id))
		var f := TextureRect.new()
		f.texture = face(str(r["sprite"]))
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.position = Vector2(3, 3)
		f.size = Vector2(19, 19)
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd.add_child(f)
		if session.life.dating.has(id) and Art.has_picture("ui_heart_sweet"):
			var sw := Sheet._pic("ui_heart_sweet", Vector2(LIST_W - 22, 2), Vector2(8, 8))
			cd.add_child(sw)
		list.add_child(cd)


func _row(id: String) -> Dictionary:
	for r: Dictionary in _rows:
		if str(r["id"]) == id:
			return r
	return {}


func _fill_detail() -> void:
	var r := _row(selected)
	if r.is_empty():
		return
	var c := session.content
	var id := selected
	var t := session.town
	# The portrait in its mount, the name, the hearts.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var portrait := pick(["portrait_%s_neutral" % id])
	var m := mount(portrait)
	if portrait == "":
		var f := TextureRect.new()
		f.texture = face(str(r["sprite"]))
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.position = Vector2(4, 4)
		f.size = Vector2(32, 32)
		m.add_child(f)
	head.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(text(str(r["name"]), 10, KitStyle.TEXT_DARK, DETAIL_W - 60))
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 3)
	hr.add_child(_hearts(int(r["hearts"]), int(r["cap"]), 8))
	if session.life.dating.has(id):
		hr.add_child(chip(pick(["ui_heart_sweet"]), c.text("social_dating"), "good"))
	v.add_child(hr)
	head.add_child(v)
	detail.add_child(head)
	# Chips: birthday, talked today, the week's gifts, where now.
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 3)
	chips.add_theme_constant_override("v_separation", 2)
	chips.custom_minimum_size = Vector2(DETAIL_W - 10, 0)
	var b: Dictionary = r["birthday"]
	chips.add_child(chip(pick(["icon_cake", "ui_cal_birthday"]), c.text("town_birthday", {"season": c.text("season_" + GameClock.SEASONS[int(b["season"])]), "day": int(b["day"])})))
	chips.add_child(chip(pick(["verb_talk", "ui_talk_tick"]), c.text("town_talked" if bool(r["talked"]) else "town_not_talked"), "good" if bool(r["talked"]) else ""))
	var per := session.tuning.integer("friendship.gifts_per_week")
	chips.add_child(chip(pick(["verb_give", "ui_gift_tick"]), c.text("town_gifts", {"n": int(r["gifts"]), "of": per})))
	chips.add_child(chip(pick(["icon_where", "icon_marks_map"]), t.where_now(id)))
	detail.add_child(chips)
	# Loves and likes: what giving has taught the ranger, "?" for the rest.
	var known: Dictionary = t.gifts_known.get(id, {})
	for level in ["love", "like"]:
		var all := t.taste_list(id, level)
		if all.is_empty():
			continue
		detail.add_child(heading(c.text("town_" + level + "s")))
		var row := tile_row()
		for it in all:
			if known.get(it, "") == level:
				var ic := str(c.row("items", it).get("icon", ""))
				row.add_child(tile(ic, "", "gold", c.item_name(it)))
			else:
				row.add_child(tile(pick(["icon_unknown"]), "", "grey"))
		detail.add_child(row)
	if session.life.dating.has(id):
		add_stamp(pick(["ui_heart_sweet", "ui_heart_full"]), c.text("town_just_friends"), "", true, func() -> void: friends_asked.emit(id))


# --- the calendar ---------------------------------------------------------------------

func _draw_calendar() -> void:
	var on := _cal
	var c := session.clock
	var f := ThemeDB.fallback_font
	var season_name := session.content.text("season_" + c.season_name())
	on.draw_string(f, Vector2(0, 8), session.content.text("ui_calendar_title", {"season": season_name, "year": c.year}), HORIZONTAL_ALIGNMENT_CENTER, on.size.x, 8, KitStyle.TEXT_DARK)
	var days := session.town.calendar(c.season)
	var rows := ceili(float(days.size()) / CAL_COLS)
	var cw := on.size.x / CAL_COLS
	var ch := (on.size.y - 26) / rows
	for d: Dictionary in days:
		var i := int(d["day"]) - 1
		var cell := Rect2(Vector2((i % CAL_COLS) * cw, 12 + (i / CAL_COLS) * ch), Vector2(cw, ch)).grow(-1)
		on.draw_rect(cell, Color8(251, 243, 223))
		on.draw_rect(cell, Color(KitStyle.WOOD, 0.5), false, 1.0)
		if int(d["day"]) == c.day:
			on.draw_rect(cell.grow(-1), Color(0.95, 0.75, 0.3, 0.45))
		on.draw_string(f, cell.position + Vector2(3, 8), str(d["day"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, KitStyle.TEXT_DARK)
		var bx := cell.end.x - 2
		for id: String in d["birthdays"]:
			var row := session.content.row("townsfolk", id)
			var fc := face(str(row.get("sprite", "")))
			if fc != null:
				on.draw_texture_rect(fc, Rect2(Vector2(bx - 14, cell.end.y - 15), Vector2(14, 14)), false)
			bx -= 15
			var cake := pick(["icon_cake", "ui_cal_birthday"])
			if cake != "":
				on.draw_texture_rect(Art.texture(cake), Rect2(cell.position + Vector2(2, cell.size.y - 12), Vector2(10, 10)), false)
		if str(d["festival"]) != "" and Art.has_picture("ui_cal_festival"):
			on.draw_texture_rect(Art.texture("ui_cal_festival"), Rect2(cell.position + Vector2(2, cell.size.y - 12), Vector2(10, 10)), false)
	# Today's events, under the grid.
	var today: Dictionary = days[c.day - 1] if c.day - 1 < days.size() else {}
	var notes := PackedStringArray()
	for id: String in today.get("birthdays", []):
		notes.append(session.content.text("cal_birthday", {"name": str(session.content.row("townsfolk", id)["name"]).get_slice(" ", 0)}))
	if str(today.get("festival", "")) != "":
		notes.append(session.content.text("cal_festival", {"name": session.content.text(str(session.content.row("festivals", today["festival"])["name"]))}))
	if not notes.is_empty():
		on.draw_string(f, Vector2(0, on.size.y - 3), session.content.text("cal_today") + ": " + ", ".join(notes), HORIZONTAL_ALIGNMENT_CENTER, on.size.x, 7, KitStyle.TEXT_DARK)


## Keys while the sheet is open. True when the key was used.
func handle(event: InputEvent) -> bool:
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		if page != "people" or _rows.is_empty():
			return true
		var ids := _rows.map(func(r: Dictionary) -> String: return str(r["id"]))
		var i := ids.find(selected)
		i = clampi(i + (1 if event.is_action_pressed("move_down") else -1), 0, ids.size() - 1)
		selected = str(ids[i])
		refresh()
		return true
	return false
