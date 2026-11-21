class_name ClipboardScreen
extends Control
## The Jobs page (J): the ranger's clipboard, as in the designer's reference.
## Three tabs (Current, Noticed, Done); a list on the left, a third of the
## paper, grouped under a ribbon for each type; the chosen job in full on the
## right: name, giver, note, what you'll need, the steps, the rewards, and
## buttons to pin it or show it on the map. Long text wraps and long lists
## scroll, so nothing runs off the paper. Only reads the jobs module, apart
## from pinning.

signal show_on_map(pos: Vector2, text: String)
signal closed

const TABS: Array[String] = ["current", "noticed", "done"]
const FRAME := Rect2(12, 6, 456, 258)
const PAPER := Rect2(42, 44, 396, 192)     # inside the frame's border
const LIST_W := 112.0

var session: GameSession
var tab: String = "current"
var selected: String = ""
var _tab_buttons: Array[Button] = []
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail: VBoxContainer
var _pin_button: Button
var _map_button: Button
var _empty: Label
var _cards: Dictionary = {}       # key -> the card's Control
var _rule: ColorRect


func setup(s: GameSession) -> void:
	session = s
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var frame := TextureRect.new()
	frame.position = FRAME.position
	frame.size = FRAME.size
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture = Art.texture("ui_clipboard") if Art.has_picture("ui_clipboard") else null
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	if frame.texture == null:
		var p := Panel.new()
		p.position = FRAME.position
		p.size = FRAME.size
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
	# Tabs along the top of the paper, left of the clip.
	for i in TABS.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(PAPER.position.x + 2 + i * 40, PAPER.position.y)
		b.size = Vector2(39, 13)
		b.add_theme_font_size_override("font_size", 7)
		var t: String = TABS[i]
		b.pressed.connect(func() -> void: set_tab(t))
		add_child(b)
		_tab_buttons.append(b)
	_rule = ColorRect.new()
	_rule.color = Color(KitStyle.WOOD, 0.35)
	_rule.position = Vector2(PAPER.position.x + LIST_W + 3, PAPER.position.y + 16)
	_rule.size = Vector2(1, PAPER.size.y - 18)
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rule)
	_list_scroll = ScrollContainer.new()
	_list_scroll.position = PAPER.position + Vector2(2, 16)
	_list_scroll.size = Vector2(LIST_W, PAPER.size.y - 18)
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(LIST_W - 8, 0)
	_list.add_theme_constant_override("separation", 2)
	_list_scroll.add_child(_list)
	var dx := PAPER.position.x + LIST_W + 8
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.position = Vector2(dx, PAPER.position.y + 14)
	_detail_scroll.size = Vector2(PAPER.end.x - dx - 2, PAPER.size.y - 32)
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_detail_scroll)
	_detail = VBoxContainer.new()
	_detail.custom_minimum_size = Vector2(_detail_scroll.size.x - 8, 0)
	_detail.add_theme_constant_override("separation", 3)
	_detail_scroll.add_child(_detail)
	_pin_button = _button(Vector2(dx, PAPER.end.y - 16), func() -> void:
		if selected != "" and session.jobs.is_active(selected):
			session.jobs.toggle_pin(selected)
			refresh())
	_map_button = _button(Vector2(dx + 92, PAPER.end.y - 16), func() -> void: _show_on_map())
	_empty = Label.new()
	_empty.position = PAPER.position + Vector2(8, 26)
	_empty.size = Vector2(LIST_W - 8, 60)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD
	_empty.add_theme_font_size_override("font_size", 7)
	add_child(_empty)
	var keys := Label.new()
	keys.text = s.content.text("jt_keys")
	keys.position = Vector2(FRAME.position.x + 30, FRAME.end.y - 13)
	keys.add_theme_font_size_override("font_size", 6)
	keys.add_theme_color_override("font_color", KitStyle.TEXT_LIGHT)
	keys.add_theme_color_override("font_outline_color", KitStyle.INK)
	keys.add_theme_constant_override("outline_size", 2)
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(keys)


func _button(pos: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.size = Vector2(88, 13)
	b.add_theme_font_size_override("font_size", 7)
	b.pressed.connect(action)
	add_child(b)
	return b


## Opens at a job, or at the pinned job, or the first in the list.
func open(key: String = "") -> void:
	visible = true
	if key != "" and session.jobs.known.has(key):
		tab = session.jobs.tab_of(key)
		selected = key
	else:
		var shown := session.jobs.shown_job()
		if shown != "":
			tab = "current"
			selected = shown
		else:
			selected = ""
	refresh()


func close() -> void:
	visible = false
	closed.emit()


func set_tab(t: String) -> void:
	tab = t
	selected = ""
	refresh()


func refresh() -> void:
	var jb := session.jobs
	var keys := jb.list(tab)
	if selected == "" or not keys.has(selected):
		selected = keys[0] if not keys.is_empty() else ""
	for i in TABS.size():
		var b := _tab_buttons[i]
		var n := jb.list(TABS[i]).size()
		b.text = "%s %d%s" % [session.content.text("jt_tab_" + TABS[i]), n, " *" if jb.any_new(TABS[i]) and TABS[i] != tab else ""]
		var open_tab: bool = TABS[i] == tab
		var art := "ui_jtab_open" if open_tab else "ui_jtab"
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, _sb(art, 4, 1) if Art.has_picture(art) else KitStyle.tab(open_tab))
		b.add_theme_color_override("font_color", KitStyle.TEXT_LIGHT if open_tab else KitStyle.TEXT_DARK)
		b.add_theme_color_override("font_hover_color", KitStyle.TEXT_LIGHT if open_tab else KitStyle.INK)
	_fill_list(keys)
	_fill_detail()
	_empty.visible = keys.is_empty()
	_empty.text = session.content.text("jt_empty_" + tab)
	_pin_button.visible = selected != "" and jb.is_active(selected)
	_pin_button.text = session.content.text("jt_unpin" if selected == jb.pinned and selected != "" else "jt_pin")
	_map_button.visible = selected != "" and jb.is_active(selected) and jb.map_pos(selected, jb.next_step(selected)) != Vector2.INF
	_map_button.text = session.content.text("jt_show_map")
	if selected != "":
		jb.mark_seen(selected)


static func _sb(art: String, margin: int, content: float) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = Art.texture(art)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(content)
	return sb


# --- the list ----------------------------------------------------------------------

func _fill_list(keys: Array[String]) -> void:
	for c in _list.get_children():
		c.queue_free()
	_cards.clear()
	var jb := session.jobs
	var last_type := ""
	for k in keys:
		var d := jb.def(k)
		if tab != "done" and d["type"] != last_type:
			last_type = d["type"]
			_list.add_child(_ribbon(d["type"]))
		_list.add_child(_card(k))


## A ribbon heading in the type's color, with its icon.
func _ribbon(type_id: String) -> Control:
	var row := session.content.row("job_types", type_id)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(LIST_W - 10, 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = session.jobs.type_color(type_id)
	sb.set_corner_radius_all(2)
	p.add_theme_stylebox_override("panel", sb)
	var icon := TextureRect.new()
	icon.texture = Art.texture(row["icon"])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(11, 11)
	icon.position = Vector2(1, 0)
	p.add_child(icon)
	var l := Label.new()
	l.text = session.content.text(row["name"])
	l.position = Vector2(14, -1)
	l.add_theme_font_size_override("font_size", 7)
	KitStyle.over_world(l)
	l.add_theme_constant_override("outline_size", 2)
	p.add_child(l)
	return p


func _card(k: String) -> Control:
	var jb := session.jobs
	var d := jb.def(k)
	var st: Dictionary = jb.known[k]
	var p := Panel.new()
	p.custom_minimum_size = Vector2(LIST_W - 10, 26)
	var art := "ui_jcard_selected" if k == selected else "ui_jcard"
	if Art.has_picture(art):
		p.add_theme_stylebox_override("panel", _sb(art, 6, 2))
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = KitStyle.PAPER
		sb.border_color = KitStyle.CORAL if k == selected else KitStyle.WOOD
		sb.set_border_width_all(1)
		p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			selected = k
			refresh())
	var icon := TextureRect.new()
	icon.texture = Art.texture(kind_icon(k))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(14, 14)
	icon.position = Vector2(3, 3)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(icon)
	var name := Label.new()
	name.text = d["name"]
	name.position = Vector2(19, 1)
	name.size = Vector2(LIST_W - 32 - 7 * _card_marks(k, st).size(), 14)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_font_size_override("font_size", 7)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(name)
	var total := (d["steps"] as Array).size()
	var done := jb.steps_done_count(k)
	var bar := _bar(float(done) / float(maxi(1, total)), Vector2(19, 15), Vector2(LIST_W - 52, 5))
	p.add_child(bar)
	var cnt := Label.new()
	cnt.text = "%d/%d" % [done, total]
	cnt.position = Vector2(LIST_W - 31, 10)
	cnt.add_theme_font_size_override("font_size", 6)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(cnt)
	var x := LIST_W - 19.0
	for mark: String in _card_marks(k, st):
		var m := TextureRect.new()
		m.texture = Art.texture(mark)
		m.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		m.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		m.size = Vector2(7, 7)
		m.position = Vector2(x, 1)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(m)
		x -= 7
	_cards[k] = p
	return p


func _card_marks(k: String, st: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if k == session.jobs.pinned:
		out.append("mark_pin")
	if bool(st["new"]):
		out.append("mark_dot")
	var season := str(session.jobs.def(k).get("season", "until_done"))
	if season not in ["until_done"]:
		out.append("mark_leaf")
	return out


func _bar(share: float, pos: Vector2, sz: Vector2) -> Control:
	var back := Panel.new()
	back.position = pos
	back.size = sz
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel", _sb("ui_bar_back", 2, 0) if Art.has_picture("ui_bar_back") else KitStyle._box(Color(0.6, 0.6, 0.6), KitStyle.INK, 1, 2, 0))
	var fill := Panel.new()
	fill.position = Vector2.ZERO
	fill.size = Vector2(maxf(0.0, sz.x * clampf(share, 0.0, 1.0)), sz.y)
	fill.visible = share > 0.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override("panel", _sb("ui_bar_fill", 2, 0) if Art.has_picture("ui_bar_fill") else KitStyle._box(KitStyle.LEAF, KitStyle.INK, 1, 2, 0))
	back.add_child(fill)
	return back


## The icon for the kind of job: building, map, broom, shovel...
func kind_icon(k: String) -> String:
	var jb := session.jobs
	var d := jb.def(k)
	var id := str(d["id"])
	var by_id := {"open_cabin": "job_kind_cabin", "open_tower": "job_kind_tower", "open_pond": "job_kind_pond", "open_outlook": "job_kind_map",
		"find_bridge": "job_kind_map", "tower_radio": "job_kind_tower", "station_shipshape": "job_kind_broom", "spruce_gate": "job_kind_trash_can",
		"stock_cabin": "job_kind_crates", "stock_tower": "job_kind_crates", "stock_winter": "job_kind_crates", "check_cabins": "job_kind_cabin",
		"winter_mess": "job_kind_broom", "ready_crowds": "job_kind_trash_can", "point_fork": "job_kind_sign", "reopen_pond_trail": "job_kind_branch",
		"stake_west": "job_kind_shovel", "stake_east": "job_kind_shovel", "clear_old_road": "job_kind_branch", "scouts_badge": "job_kind_trash_can",
		"clean_up": "job_kind_bathroom", "empty_bins": "job_kind_trash_can", "litter_trail": "job_kind_trash_can", "more_cans": "job_kind_trash_can",
		"a_seat": "job_kind_bench", "restock": "job_kind_crates", "badger_at": "job_kind_badger", "tree_down": "job_kind_branch",
		"diggings": "job_kind_shovel", "point_junction": "job_kind_sign", "name_site": "job_kind_sign", "v_bench": "job_kind_bench",
		"v_picnic": "job_kind_bench", "v_sign": "job_kind_sign", "v_bathroom": "job_kind_bathroom", "v_cans": "job_kind_trash_can", "find_lost": "job_kind_lost"}
	if by_id.has(id):
		return by_id[id]
	return "job_kind_look" if bool(jb.known[k]["noticed"]) else "job_kind_note"


# --- the detail pane ---------------------------------------------------------------

func _fill_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	if selected == "":
		return
	var jb := session.jobs
	var c := session.content
	var k := selected
	var d := jb.def(k)
	var st: Dictionary = jb.known[k]
	var w := _detail.custom_minimum_size.x
	# Name, large, with the type's picture at the right.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	var name := _text(d["name"], 10, KitStyle.TEXT_DARK, w - 34)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	var pic := TextureRect.new()
	pic.texture = Art.texture(str(jb.type_row(k)["picture"]))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(26, 26)
	head.add_child(pic)
	_detail.add_child(head)
	# From: the giver, with how it came.
	var from := HBoxContainer.new()
	var how := jb.giver_how(k)
	var gi := TextureRect.new()
	gi.texture = Art.texture({"given": "reward_card", "found": "job_kind_note", "noticed": "mark_pencil"}.get(how, "reward_card"))
	gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gi.custom_minimum_size = Vector2(9, 9)
	from.add_child(gi)
	var size_txt := c.text("jt_size_" + str(d.get("size", "small")))
	from.add_child(_text(c.text("jt_from", {"giver": jb.giver_name(k)}) + "   " + c.text(jb.type_row(k)["name"]) + ", " + size_txt.to_lower(), 7, KitStyle.TEXT_DARK, w - 12))
	_detail.add_child(from)
	if str(d.get("season", "")) not in ["until_done", ""]:
		_detail.add_child(_text(c.text("jt_leaf"), 6, Color(KitStyle.PINE, 0.9), w))
	# The note, in the giver's voice.
	var note := _text(d["note"], 7, Color8(52, 60, 110), w)
	_detail.add_child(note)
	if tab == "done":
		_detail.add_child(_heading(c.text("jt_gave")))
		_detail.add_child(_text(c.text("jt_finished_on", {"day": session.clock.day_of(int(st["fin_day"])), "season": c.text("season_" + session.clock.season_name_of(int(st["fin_season"])))}), 7, KitStyle.TEXT_DARK, w))
		_detail.add_child(_reward_tiles(st.get("given", []), str(st.get("more_text", ""))))
		return
	# You'll need.
	_detail.add_child(_heading(c.text("jt_need")))
	var need := jb.needs(k)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 2)
	flow.custom_minimum_size = Vector2(w, 0)
	var shown := 0
	for it: String in need:
		if shown >= 6:
			break
		flow.add_child(_item_tile(k, it, int(need[it]), false))
		shown += 1
	for it: String in d.get("handy", []):
		if shown >= 6:
			break
		if not need.has(it):
			flow.add_child(_item_tile(k, it, 1, true))
			shown += 1
	if shown == 0:
		_detail.add_child(_text(c.text("jt_nothing_to_bring"), 7, KitStyle.TEXT_DARK, w))
	else:
		_detail.add_child(flow)
	# Steps.
	_detail.add_child(_heading(c.text("jt_steps")))
	var nxt := jb.next_step(k)
	for i in (d["steps"] as Array).size():
		_detail.add_child(_step_row(k, i, nxt, w))
	# Rewards.
	_detail.add_child(_heading(c.text("jt_rewards")))
	var lines := []
	for r: Dictionary in d.get("rewards", []):
		lines.append({"icon": _reward_icon(r), "text": _reward_label(r)})
	_detail.add_child(_reward_tiles(lines, "?" if str(d.get("more", "")) != "" else ""))


func _heading(text: String) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(70, 10)
	if Art.has_picture("ui_ribbon_green"):
		p.add_theme_stylebox_override("panel", _sb("ui_ribbon_green", 4, 0))
	else:
		p.add_theme_stylebox_override("panel", KitStyle._box(KitStyle.PINE, KitStyle.INK, 1, 3, 0))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := Label.new()
	l.text = text
	l.position = Vector2(5, -2)
	l.add_theme_font_size_override("font_size", 7)
	KitStyle.over_world(l)
	l.add_theme_constant_override("outline_size", 2)
	p.add_child(l)
	return p


func _text(t: String, sz: int, col: Color, w: float) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l


func _item_tile(k: String, item: String, n: int, handy: bool) -> Control:
	var jb := session.jobs
	var have := session.backpack.count(item)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(80, 26)
	var art := "ui_tile_grey" if handy else "ui_tile"
	p.add_theme_stylebox_override("panel", _sb(art, 5, 1) if Art.has_picture(art) else KitStyle._box(KitStyle.PAPER, KitStyle.WOOD, 1, 2))
	var icon := TextureRect.new()
	icon.texture = Art.texture(session.content.row("items", item)["icon"])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(14, 14)
	icon.position = Vector2(2, 2)
	icon.modulate = Color(1, 1, 1, 0.6) if handy else Color.WHITE
	p.add_child(icon)
	var l := Label.new()
	var count := "" if handy else " " + session.content.text("jt_have_need", {"have": mini(have, n), "need": n})
	l.text = session.content.item_name(item) + count
	l.position = Vector2(17, 0)
	l.size = Vector2(62, 10)
	l.clip_text = true
	l.add_theme_font_size_override("font_size", 6)
	l.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45) if handy else (KitStyle.LEAF if have >= n else KitStyle.TEXT_DARK))
	p.add_child(l)
	var where := "" if have >= n else jb.where_to_get(k, item)
	if handy:
		where = session.content.text("jt_handy") + ("" if have > 0 else " " + session.guide.where_to_get(item))
	var wl := Label.new()
	wl.text = where
	wl.position = Vector2(17, 8)
	wl.size = Vector2(62, 18)
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wl.add_theme_font_size_override("font_size", 5)
	wl.add_theme_color_override("font_color", Color(0.4, 0.33, 0.28))
	wl.clip_text = true
	p.add_child(wl)
	return p


func _step_row(k: String, i: int, nxt: int, w: float) -> Control:
	var jb := session.jobs
	var c := jb.check(k, i)
	var st: Dictionary = jb.known[k]
	var done := bool(c["done"])
	var broken := not done and (st["broken"] as Dictionary).has(str(i))
	var row := PanelContainer.new()
	if i == nxt:
		row.add_theme_stylebox_override("panel", _sb("ui_band", 3, 1) if Art.has_picture("ui_band") else KitStyle._box(Color(1, 0.95, 0.6), Color(1, 0.95, 0.6), 0, 1, 1))
	else:
		row.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	row.add_child(h)
	var m := TextureRect.new()
	m.texture = Art.texture("mark_tick_box" if done else ("mark_arrow" if i == nxt else ("mark_undone" if broken else "mark_box")))
	m.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	m.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	m.custom_minimum_size = Vector2(8, 8)
	h.add_child(m)
	var text := jb.step_label(k, i)
	if int(c["total"]) > 1 and not done:
		text += "  " + session.content.text("jt_count", {"done": c["n"], "total": c["total"]})
	if broken:
		text += "  (" + session.content.text("jt_broken") + ")"
	var link := jb.link_of(k, i)
	var l := _text(text, 7, Color(KitStyle.TEXT_DARK, 0.6) if done else KitStyle.TEXT_DARK, w - 16)
	if link == "":
		h.add_child(l)
	else:
		var v := VBoxContainer.new()
		v.add_child(l)
		var lb := LinkButton.new()
		lb.text = session.content.text("jt_see_job", {"job": jb.def(link)["name"]})
		lb.add_theme_font_size_override("font_size", 6)
		lb.add_theme_color_override("font_color", Color8(52, 60, 160))
		lb.pressed.connect(func() -> void: open(link))
		v.add_child(lb)
		h.add_child(v)
	return row


func _reward_icon(r: Dictionary) -> String:
	var c := session.content
	var kind := str(r["kind"])
	if kind == "things":
		var items: Dictionary = r["items"]
		if items.has("firewood"):
			return "reward_firewood"
		if items.has("nails") or items.has("planks"):
			return "reward_supplies"
		return "reward_things"
	if kind == "story" and bool(r.get("letter", false)):
		return "reward_card"
	return str(c.row("rewards", kind)["icon"]) if c.has("rewards", kind) else "reward_things"


## A reward as shown before the job is started.
func _reward_label(r: Dictionary) -> String:
	var c := session.content
	match str(r["kind"]):
		"money":
			return c.text("jt_r_money", {"n": int(r["n"])})
		"xp":
			return c.text("jt_r_xp", {"n": int(r["n"]), "skill": session._skill_name(str(r["skill"]))})
		"rumor":
			return c.text("jt_r_rumor")
		"travel":
			if r.has("label"):
				return c.text(r["label"])
			return c.text("jt_r_travel", {"name": session.travel_name(str(r.get("site", r.get("place", ""))))})
		"unlock":
			return c.text("jt_r_unlock_" + str(r["what"]))
		"job":
			return c.text("jt_r_job", {"name": session.jobs.def(str(r["job"])).get("name", c.text(c.row("jobs", r["job"])["name"])) if session.jobs.known.has(str(r["job"])) else c.text(c.row("jobs", r["job"])["name"])})
		"things":
			if r.has("label"):
				return c.text(r["label"])
			var parts: PackedStringArray = []
			for it: String in r["items"]:
				parts.append("%s x%d" % [c.item_name(it), int(r["items"][it])])
			return ", ".join(parts)
	return c.text(str(r.get("label", ""))) if str(r.get("label", "")) != "" else ""


func _reward_tiles(lines: Array, more: String) -> Control:
	var flow := HFlowContainer.new()
	flow.custom_minimum_size = Vector2(_detail.custom_minimum_size.x, 0)
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 2)
	for e: Dictionary in lines:
		flow.add_child(_reward_tile(str(e["icon"]), str(e["text"])))
	if more != "":
		flow.add_child(_reward_tile("reward_more", session.content.text("jt_more") if more == "?" else more))
	return flow


func _reward_tile(icon_name: String, text: String) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(80, 22)
	p.add_theme_stylebox_override("panel", _sb("ui_tile_gold", 5, 1) if Art.has_picture("ui_tile_gold") else KitStyle._box(KitStyle.PAPER, KitStyle.GOLD, 1, 2))
	var icon := TextureRect.new()
	icon.texture = Art.texture(icon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(14, 14)
	icon.position = Vector2(2, 4)
	p.add_child(icon)
	var l := Label.new()
	l.text = text
	l.position = Vector2(17, 1)
	l.size = Vector2(62, 20)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.clip_text = true
	l.add_theme_font_size_override("font_size", 6)
	p.add_child(l)
	return p


# --- input ---------------------------------------------------------------------------

## Keys while the clipboard is open. True when the key was used.
func handle(event: InputEvent) -> bool:
	if event.is_action_pressed("jobs") or event.is_action_pressed("pause") or event.is_action_pressed("cancel"):
		close()
		return true
	if event.is_action_pressed("tab_prev"):
		set_tab(TABS[(TABS.find(tab) + TABS.size() - 1) % TABS.size()])
		return true
	if event.is_action_pressed("tab_next") or event.is_action_pressed("backpack"):
		set_tab(TABS[(TABS.find(tab) + 1) % TABS.size()])
		return true
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		var keys := session.jobs.list(tab)
		if keys.is_empty():
			return true
		var i := keys.find(selected)
		i = clampi(i + (1 if event.is_action_pressed("move_down") else -1), 0, keys.size() - 1)
		selected = keys[i]
		refresh()
		_scroll_to_selected.call_deferred()
		return true
	if event.is_action_pressed("pin_job"):
		if selected != "" and session.jobs.is_active(selected):
			session.jobs.toggle_pin(selected)
			refresh()
		return true
	if event.is_action_pressed("open_map"):
		_show_on_map()
		return true
	if event.is_action_pressed("interact"):
		if selected != "":
			for i in (session.jobs.def(selected)["steps"] as Array).size():
				var l := session.jobs.link_of(selected, i)
				if l != "":
					open(l)
					return true
		return true
	return false


func _scroll_to_selected() -> void:
	if _cards.has(selected):
		_list_scroll.ensure_control_visible(_cards[selected])


func _show_on_map() -> void:
	if selected == "" or not session.jobs.is_active(selected):
		return
	var i := session.jobs.next_step(selected)
	var p := session.jobs.map_pos(selected, i)
	if p == Vector2.INF:
		return
	close()
	show_on_map.emit(p, session.jobs.def(selected)["name"] + ": " + session.jobs.step_label(selected, i))


func _gui_input(event: InputEvent) -> void:
	# A click outside the paper closes the clipboard.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if not FRAME.has_point((event as InputEventMouseButton).position):
			close()
