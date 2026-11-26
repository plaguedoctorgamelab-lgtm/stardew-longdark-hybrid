class_name BookScreen
extends Sheet
## The Log (the cozy UI plan, 0.7.19), on B: the ranger's logbook on the
## clipboard, at its size like every page. Picture tabs along the top turn
## its pages:
## - Park: the park today as picture tiles (visitors, parties, arriving,
##   sites open, badgers, staff, the cabin), the park's ID card with the
##   wallet, and each facility with its state.
## - Ledger: the wallet, the week's takings as little stacks of coins, then
##   today, this week and last week, each source a chip in or out.
## - Cards: the suggestion cards read, as index cards; the chosen one large.
## - Letters: the letters read, as envelopes; the chosen one on stationery.
## - Notebook: the ranger's notes, as sticky notes with a doodle for what
##   each is about (strange ones on purple paper); the chosen one large.
## - Badges: the patches earned.

const PAGES: Array[String] = ["park", "ledger", "cards", "letters", "notes", "creatures", "badges"]
const TAB_PICTURES := {"park": ["log_site", "ui_tab_book"], "ledger": ["icon_coin", "ui_tab_ledger"], "cards": ["log_card"], "letters": ["log_envelope"], "notes": ["log_note_yellow"], "creatures": ["job_type_creature", "guide_tab_strange"], "badges": ["badge_locked"]}
const NOTE_PAPER := {"strange": "log_note_purple", "badger": "log_note_green", "story": "log_note_blue", "heart": "log_note_yellow", "found": "log_note_yellow", "": "log_note_yellow"}
const NOTE_INK := {"strange": Color8(47, 38, 80), "badger": Color8(30, 70, 30), "story": Color8(30, 50, 90), "": Color8(70, 52, 20)}

var page: String = "park"
var selected: int = 0
var _full: ScrollContainer      # the whole paper, for pages without a list
var _full_box: VBoxContainer
var _badges: BadgesView
var _title: Label


func setup(s: GameSession) -> void:
	setup_sheet(s)
	set_clip(["clip_log"])
	_full = ScrollContainer.new()
	_full.position = PAPER.position + Vector2(2, 16)
	_full.size = Vector2(PAPER.size.x - 4, PAPER.size.y - 18)
	_full.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_full)
	_full_box = VBoxContainer.new()
	_full_box.custom_minimum_size = Vector2(PAPER.size.x - 14, 0)
	_full_box.add_theme_constant_override("separation", 3)
	_full.add_child(_full_box)
	_badges = BadgesView.new()
	_badges.setup(s, PAPER.size.x - 14)
	_title = Label.new()
	_title.position = Vector2(316, PAPER.position.y + 1)
	_title.add_theme_font_size_override("font_size", 8)
	_title.add_theme_color_override("font_color", KitStyle.TEXT_DARK)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)


## The open page's name, beside the picture tabs.
func set_page_title(t: String) -> void:
	_title.text = t


func open(pg: String = "") -> void:
	visible = true
	show_page(pg if pg != "" else page)


## The lines of a page, as the Book had them (kept for tests and debugging).
func lines_for(pg: String) -> PackedStringArray:
	match pg:
		"park":
			return session.park.park_lines()
		"ledger":
			return session.park.ledger_lines()
		"cards":
			return session.park.card_lines()
		"letters":
			return session.park.letter_lines()
		"notes":
			return session.park.note_lines()
	return PackedStringArray()


func show_page(pg: String) -> void:
	if pg != page:
		selected = 0
	page = pg
	refresh()


func refresh() -> void:
	if not visible:
		return
	var c := session.content
	var tabs := []
	for pg in PAGES:
		tabs.append({"id": pg, "label": c.text("book_" + pg), "icon": pick(TAB_PICTURES[pg]), "picture_only": true})
	set_index_tabs(tabs, page, func(pg: String) -> void: show_page(pg))
	var title := c.text("book_" + page)
	set_page_title(title)
	clear(list)
	clear(detail)
	clear(stamps)
	if _badges.get_parent() != null:
		_badges.get_parent().remove_child(_badges)
	clear(_full_box)
	var listed := page in ["cards", "letters", "notes", "creatures"]
	list_scroll.visible = listed
	detail_scroll.visible = listed
	_full.visible = not listed
	empty_label.visible = false
	match page:
		"park":
			_park()
		"ledger":
			_ledger()
		"cards":
			_cards()
		"letters":
			_letters()
		"notes":
			_notes()
		"creatures":
			_creatures()
		"badges":
			_full_box.add_child(_badges)
			_badges.refresh()
	set_keys([[["Tab"], c.text("key_sheets")], [["Q", "E"], c.text("log_key_pages")], [["W", "S"], c.text("key_list")], [["B", "Esc"], c.text("key_close")]])


# --- park -----------------------------------------------------------------------------

func _stat(picture: String, value: String, caption: String) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(60, 34)
	p.add_theme_stylebox_override("panel", sb("ui_jcard", 6, 2) if Art.has_picture("ui_jcard") else KitStyle._box(KitStyle.PAPER, KitStyle.WOOD, 1, 2))
	if picture != "":
		p.add_child(Sheet._pic(picture, Vector2(5, 4), Vector2(16, 16)))
	var v := Label.new()
	v.text = value
	v.position = Vector2(24, 2)
	v.add_theme_font_size_override("font_size", 11)
	v.add_theme_color_override("font_color", KitStyle.TEXT_DARK)
	p.add_child(v)
	var cap := Label.new()
	cap.text = caption
	cap.position = Vector2(5, 21)
	cap.add_theme_font_size_override("font_size", 6)
	cap.add_theme_color_override("font_color", Color(KitStyle.TEXT_DARK, 0.75))
	p.add_child(cap)
	return p


func _sky_picture() -> String:
	var w := session.current_weather()
	for k in ["rain", "snow", "fog"]:
		if w.contains(k):
			return pick(["log_sky_" + k])
	if w.contains("cloud") or w.contains("overcast") or w.contains("grey"):
		return pick(["log_sky_cloud"])
	return pick(["log_sky_clear"])


func _park() -> void:
	var c := session.content
	var p := session.park
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	# The park's ID card: the wallet, what's been earned, today.
	var card := Panel.new()
	card.custom_minimum_size = Vector2(112, 72)
	card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if Art.has_picture("log_id_card"):
		card.add_child(Sheet._pic("log_id_card", Vector2(0, 0), Vector2(96, 56)))
	var ck := session.clock
	var lines := VBoxContainer.new()
	lines.position = Vector2(0, 50)
	lines.add_theme_constant_override("separation", 1)
	lines.add_child(Sheet.chip(pick(["icon_coin"]), c.text("ui_pack_wallet", {"gold": InventoryScreen._thousands(p.money.wallet)})))
	lines.add_child(Sheet.chip(pick(["icon_coins_up"]), c.text("ui_pack_earned", {"gold": InventoryScreen._thousands(p.money.earned)})))
	card.add_child(lines)
	var left := VBoxContainer.new()
	left.add_child(card)
	left.add_child(text(c.text("ui_pack_date", {"day": ck.day, "season": c.text("season_" + ck.season_name()), "year": ck.year}), 7, KitStyle.TEXT_DARK, 112))
	row.add_child(left)
	# The day in tiles.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	var coming := 0
	for a: Dictionary in p.schedule:
		coming += int(a["size"])
	var sites := p.visitable_sites()
	var staff_n := 0
	for st: Dictionary in p.staff:
		staff_n += 1
	grid.add_child(_stat(pick(["log_visitors"]), str(p.visitors_in_park()), c.text("log_visitors")))
	grid.add_child(_stat(pick(["log_party"]), str(p.parties.size()), c.text("log_parties")))
	grid.add_child(_stat(pick(["log_arriving"]), str(coming), c.text("log_arriving")))
	grid.add_child(_stat(pick(["log_site"]), str(sites.size()), c.text("log_sites")))
	grid.add_child(_stat(pick(["troll_badger", "log_litter"]), str(p.badgers.size()), c.text("log_badgers")))
	grid.add_child(_stat(pick(["log_staff"]), str(staff_n), c.text("log_staff")))
	grid.add_child(_stat(pick(["map_icon_test_cabin", "log_site"]), c.text("log_cabin_rent" if p.rent_mode == "rent" else "log_cabin_ranger"), c.text("log_cabin") + (" · " + c.text("park_cabin_booked") if p.cabin_booked() else "")))
	grid.add_child(_stat(_sky_picture(), "", c.text("log_sky")))
	row.add_child(grid)
	_full_box.add_child(row)
	# The facilities, each a chip with its state.
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 3)
	fl.add_theme_constant_override("v_separation", 2)
	fl.custom_minimum_size = Vector2(PAPER.size.x - 14, 0)
	for r: Dictionary in p.pad_rows():
		var st := p.pad_state(r["id"])
		if st == "" or bool(r.get("built", false)):
			continue
		var icon: String = {"built": "icon_have", "ordered": "icon_time", "kit": "icon_carry", "building": "verb_make"}.get(st, "")
		fl.add_child(Sheet.chip(pick([icon]), c.text(p.fac_row(r["id"])["name"]) + " · " + p.place_name(r["site"]), "good" if st == "built" else ""))
	if fl.get_child_count() > 0:
		_full_box.add_child(heading(c.text("park_facilities").trim_suffix(":")))
		_full_box.add_child(fl)


# --- ledger ---------------------------------------------------------------------------

func _ledger() -> void:
	var c := session.content
	var p := session.park
	var t := p.today()
	var wd := p.week_day()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(Sheet.chip(pick(["icon_coin"]), c.text("ledger_wallet", {"n": p.money.wallet})))
	# The week as stacks of coins: one for each day so far.
	var bars := Control.new()
	bars.custom_minimum_size = Vector2(110, 36)
	var nets := []
	var most := 1
	for d in range(t - wd + 1, t + 1):
		var n := p.money.net(d, d)
		nets.append(n)
		most = maxi(most, absi(n))
	bars.draw.connect(func() -> void:
		var bar := Art.texture("log_bar") if Art.has_picture("log_bar") else null
		for i in nets.size():
			var h := roundf(30.0 * absf(float(nets[i])) / float(most))
			var r := Rect2(Vector2(4 + i * 14, 32 - h), Vector2(8, h))
			if int(nets[i]) < 0:
				bars.draw_rect(r, Color8(200, 90, 70))
			elif bar != null:
				bars.draw_texture_rect_region(bar, r, Rect2(Vector2(0, bar.get_height() - h * bar.get_height() / 32.0), Vector2(bar.get_width(), h * bar.get_height() / 32.0)))
			else:
				bars.draw_rect(r, KitStyle.GOLD)
			bars.draw_rect(Rect2(Vector2(2 + i * 14, 33), Vector2(12, 1)), Color(KitStyle.WOOD, 0.5)))
	top.add_child(bars)
	_full_box.add_child(top)
	var spans := [["ledger_today", t, t], ["ledger_this_week", t - wd + 1, t], ["ledger_last_week", t - wd - 6, t - wd]]
	for sp: Array in spans:
		_full_box.add_child(heading(c.text(sp[0]).trim_suffix(":")))
		var tot := p.money.totals(int(sp[1]), int(sp[2]))
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 3)
		fl.add_theme_constant_override("v_separation", 2)
		fl.custom_minimum_size = Vector2(PAPER.size.x - 14, 0)
		var sum := 0
		for r: Dictionary in c.rows("income_sources"):
			var v := int(tot.get(r["id"], 0))
			if v == 0:
				continue
			sum += v
			fl.add_child(Sheet.chip(pick(["icon_coins_up"] if v > 0 else ["icon_coins_down"]), "%s %s%d" % [c.text(r["name"]), "+" if v > 0 else "-", absi(v)], "good" if v > 0 else "bad"))
		if fl.get_child_count() == 0:
			fl.add_child(text(c.text("ledger_none"), 7, Color(KitStyle.TEXT_DARK, 0.7), 200))
		else:
			fl.add_child(Sheet.chip(pick(["icon_coin"]), c.text("ledger_total", {"sign": "+" if sum >= 0 else "-", "n": absi(sum)})))
		_full_box.add_child(fl)


# --- cards, letters, notes ------------------------------------------------------------

func _choose(i: int) -> void:
	if i == selected:
		return
	selected = i
	refresh()


func _paper_page(paper: String, words: String, ink: Color, doodle: String, foot: String) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(DETAIL_W - 16, 130)
	if Art.has_picture(paper):
		var b := sb(paper, 10, 0)
		p.add_theme_stylebox_override("panel", b)
	else:
		p.add_theme_stylebox_override("panel", KitStyle._box(Color8(251, 243, 223), KitStyle.WOOD, 1, 2))
	p.custom_minimum_size = Vector2(DETAIL_W - 16, 140)
	var l := Label.new()
	l.text = words
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(18, 40)
	l.custom_minimum_size = Vector2(DETAIL_W - (84 if doodle != "" else 50), 0)
	l.size = Vector2(DETAIL_W - (84 if doodle != "" else 50), 90)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", ink)
	p.add_child(l)
	if doodle != "" and Art.has_picture(doodle):
		p.add_child(Sheet._pic(doodle, Vector2(DETAIL_W - 60, 46), Vector2(32, 32)))
	if foot != "":
		var f := Label.new()
		f.text = foot
		f.position = Vector2(16, 118)
		f.add_theme_font_size_override("font_size", 6)
		f.add_theme_color_override("font_color", Color(ink, 0.7))
		p.add_child(f)
	return p


func _small(picture: String, top: String, words: String, i: int, dim: bool = false) -> Control:
	var foot := Label.new()
	foot.text = words
	foot.size = Vector2(LIST_W - 36, 10)
	foot.clip_text = true
	foot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	foot.add_theme_font_size_override("font_size", 6)
	foot.add_theme_color_override("font_color", Color(KitStyle.TEXT_DARK, 0.8))
	var k := i
	return card(picture, top, foot, i == selected, func() -> void: _choose(k), dim)


func _day(d: int) -> String:
	return session.content.text("log_day", {"n": d + 1})


func _cards() -> void:
	var c := session.content
	var read := session.park.cards.filter(func(x: Dictionary) -> bool: return bool(x["read"]))
	if read.is_empty():
		empty_label.visible = true
		empty_label.text = c.text("cards_none")
		return
	selected = clampi(selected, 0, read.size() - 1)
	for i in read.size():
		list.add_child(_small(pick(["log_card"]), _day(int(read[i]["day"])), str(read[i]["text"]), i))
	var cd: Dictionary = read[selected]
	detail.add_child(_paper_page(pick(["log_card_big", "ui_paper"]), str(cd["text"]), Color8(52, 60, 110), "", _day(int(cd["day"]))))
	if bool(cd.get("pinned", false)):
		detail.add_child(Sheet.chip(pick(["log_stamp_done", "icon_have"]), c.text("log_card_pinned"), "good"))


func _letters() -> void:
	var c := session.content
	var read := letters_to_reread()
	if read.is_empty():
		empty_label.visible = true
		empty_label.text = c.text("letters_none")
		return
	selected = clampi(selected, 0, read.size() - 1)
	for i in read.size():
		var pic: Array = ["log_note_yellow", "log_envelope"] if bool(read[i]["ranger"]) else ["log_envelope_open", "log_envelope"]
		list.add_child(_small(pick(pic), str(read[i]["when"]), str(read[i]["text"]), i))
	var l: Dictionary = read[selected]
	detail.add_child(_paper_page(pick(["log_letter_paper", "ui_paper"]), str(l["text"]), Color8(52, 40, 30), "", str(l["when"])))


## The letters read, then the last ranger's notes found on the boards, so
## any can be read again (tracker #50).
func letters_to_reread() -> Array:
	var c := session.content
	var out := []
	for x: Dictionary in session.park.letters:
		if bool(x["read"]):
			out.append({"text": str(x["text"]), "when": _day(int(x["day"])), "ranger": false})
	for n: Dictionary in c.rows("notes"):
		if session.notes_read.has(n["id"]):
			out.append({"text": c.text(n["text"]), "when": c.text("letters_last_ranger"), "ranger": true})
	return out


## The doodle for a note: by its kind, and for strange ones by what's in it.
static func doodle_for(note: Dictionary) -> String:
	var k := str(note.get("kind", ""))
	var t := str(note["text"]).to_lower()
	match k:
		"badger":
			return "doodle_paw"
		"found":
			return "doodle_question"
		"heart":
			return "doodle_ribbon" if t.contains("ribbon") else "doodle_star"
		"story":
			return "doodle_star"
	for pair: Array in [["mug", "doodle_mug"], ["cup", "doodle_mug"], ["ribbon", "doodle_ribbon"], ["sign", "doodle_sign"], ["track", "doodle_tracks"], ["walked", "doodle_tracks"], ["footprint", "doodle_footprint"], ["paw", "doodle_paw"], ["watch", "doodle_eye"], ["eye", "doodle_eye"]]:
		if t.contains(str(pair[0])):
			return str(pair[1])
	return "doodle_eye" if k == "strange" else "doodle_star"


func _notes() -> void:
	var c := session.content
	var notes: Array = session.park.notes
	if notes.is_empty():
		empty_label.visible = true
		empty_label.text = c.text("notes_none")
		return
	selected = clampi(selected, 0, notes.size() - 1)
	for i in notes.size():
		var n: Dictionary = notes[i]
		var cd := _small(pick([NOTE_PAPER.get(str(n.get("kind", "")), "log_note_yellow")]), _day(int(n["day"])), str(n["text"]), i)
		var dd := doodle_for(n)
		if Art.has_picture(dd):
			cd.add_child(Sheet._pic(dd, Vector2(8, 8), Vector2(11, 11)))
		list.add_child(cd)
	var nt: Dictionary = notes[selected]
	var kind := str(nt.get("kind", ""))
	detail.add_child(_paper_page(pick(["log_note_big", "ui_paper"]), str(nt["text"]), NOTE_INK.get(kind, NOTE_INK[""]), doodle_for(nt), _day(int(nt["day"]))))
	if kind == "strange":
		detail.get_child(0).self_modulate = Color(0.86, 0.8, 1.0)


## Phase 5b: the creatures met, each with its paw hearts and its stamp.
func _creatures() -> void:
	var c := session.content
	var cr := session.creatures
	var ids: Array = Creatures.IDS.filter(func(id: String) -> bool: return session.jobs.known.has(str(cr.row(id).get("job", ""))))
	if ids.is_empty():
		empty_label.visible = true
		empty_label.text = c.text("log_creatures_none")
		return
	selected = clampi(selected, 0, ids.size() - 1)
	for i in ids.size():
		var id: String = ids[i]
		var ch := str(cr.choice.get(id, ""))
		var foot := c.text("log_creature_hearts", {"n": cr.hearts(id)})
		list.add_child(_small(pick(["stamp_" + ch, "job_type_creature"]) if ch != "" else pick(["job_type_creature"]), cr.name_of(id), foot, i))
	var id: String = ids[selected]
	var ch := str(cr.choice.get(id, ""))
	var hearts := HBoxContainer.new()
	hearts.add_theme_constant_override("separation", 1)
	for k in 5:
		var pic := "ui_paw_heart_full" if k < cr.hearts(id) else "ui_paw_heart_empty"
		if Art.has_picture(pic):
			var tr := TextureRect.new()
			tr.texture = Art.texture(pic)
			tr.custom_minimum_size = Vector2(8, 8)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			hearts.add_child(tr)
	detail.add_child(text(cr.name_of(id), 10, KitStyle.TEXT_DARK, DETAIL_W - 10))
	detail.add_child(hearts)
	if ch == "":
		detail.add_child(voice(c.text("log_creature_unsettled")))
	else:
		detail.add_child(Sheet.chip(pick(["stamp_" + ch]), c.text("log_creature_choice", {"choice": c.text("cr_stamp_" + ch)})))
		if ch == "public" and Art.has_picture("brochure_creature"):
			var b := TextureRect.new()
			b.texture = Art.texture("brochure_creature")
			b.custom_minimum_size = Vector2(96, 72)
			b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			detail.add_child(b)
		if ch != "secret":
			detail.add_child(voice(c.text("cr_brochure_%s_%s" % [ch, id])))


## Keys while the Log is open. True when the key was used.
func handle(event: InputEvent) -> bool:
	if event.is_action_pressed("tab_prev") or event.is_action_pressed("tab_next"):
		var d := -1 if event.is_action_pressed("tab_prev") else 1
		show_page(PAGES[(PAGES.find(page) + PAGES.size() + d) % PAGES.size()])
		return true
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		selected = maxi(0, selected + (1 if event.is_action_pressed("move_down") else -1))
		refresh()
		return true
	return false
