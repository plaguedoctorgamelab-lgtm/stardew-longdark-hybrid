class_name GuideScreen
extends Sheet
## The field guide (Phase 5 Spec, The field guide), on G and the Tab ring:
## a sheet on the clipboard with three pages, Animals, Strange cousins, and
## Places and nights.
##
## Each entry starts as a grey silhouette with a "?", becomes a pencil
## sketch once seen through the binoculars, and a photo once photographed
## (with a gold star for a good one). The chosen entry in full: its picture
## in its frame, chips for where and when it's been seen, what it eats once
## photographed, and a line in the ranger's voice. An unknown strange
## cousin's chips are its hint: when it's out and where.

const PAGES: Array[String] = ["animal", "cousin", "place"]
const TAB_PICS := {"animal": ["guide_tab_animals"], "cousin": ["guide_tab_strange"], "place": ["guide_tab_places"]}

var page: String = "animal"
var selected: String = ""
var _pic_box: Control


func setup(s: GameSession) -> void:
	setup_sheet(s)
	set_clip(["clip_guide", "clip_log"])


func open(pg: String = "") -> void:
	if pg != "":
		page = pg
	visible = true
	refresh()


func turn(d: int) -> void:
	page = PAGES[(PAGES.find(page) + PAGES.size() + d) % PAGES.size()]
	selected = ""
	refresh()


func entries() -> Array:
	return session.wildlife.entries(page)


func refresh() -> void:
	if not visible:
		return
	var c := session.content
	var w := session.wildlife
	var tabs := []
	for pg in PAGES:
		tabs.append({"id": pg, "label": c.text("guide_tab_" + pg), "icon": pick(TAB_PICS[pg]), "picture_only": true})
	set_index_tabs(tabs, page, func(pg: String) -> void:
		page = pg
		selected = ""
		refresh())
	clear(list)
	clear(detail)
	clear(stamps)
	var es := entries()
	empty_label.visible = es.is_empty()
	if es.is_empty():
		return
	if selected == "" or not es.any(func(r: Dictionary) -> bool: return str(r["id"]) == selected):
		selected = str(es[0]["id"])
	var known := 0
	for r: Dictionary in es:
		var id := str(r["id"])
		var lv := w.level_of(id)
		if lv != "":
			known += 1
		var name := c.text(str(r["name"])) if lv != "" else "?"
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation", 2)
		foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lab := text(c.text("guide_level_" + (lv if lv != "" else "none")), 7, KitStyle.TEXT_DARK, LIST_W - 40)
		foot.add_child(lab)
		if bool((w.guide.get(id, {}) as Dictionary).get("good", false)) and Art.has_picture("guide_good_stamp"):
			var st := TextureRect.new()
			st.texture = Art.texture("guide_good_stamp")
			st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			st.custom_minimum_size = Vector2(8, 8)
			foot.add_child(st)
		list.add_child(card(_small_pic(r, lv), name, foot, id == selected, func() -> void: _choose(id), lv == ""))
	_fill_detail(c.text("guide_progress", {"n": known, "of": es.size()}))
	set_keys([[["Tab"], c.text("key_sheets")], [["Q", "E"], c.text("guide_key_pages")], [["W", "S"], c.text("key_list")], [["G", "Esc"], c.text("key_close")]])


func _small_pic(r: Dictionary, lv: String) -> String:
	if lv == "":
		return pick(["guide_unknown"])
	if str(r["kind"]) == "place":
		return pick(r["chips"])
	return pick(["sketch_" + str(r["id"]), "guide_sketch_frame"])


func _choose(id: String) -> void:
	if id == selected:
		return
	selected = id
	refresh()


## The big picture: the entry in its frame (silhouette, sketch or photo).
func picture(r: Dictionary, lv: String) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(96, 80)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := "guide_unknown" if lv == "" else ("guide_photo_frame" if lv == "photo" else "guide_sketch_frame")
	if Art.has_picture(frame):
		box.add_child(Sheet._pic(frame, Vector2.ZERO, Vector2(96, 80)))
	var id := str(r["id"])
	if str(r["kind"]) == "place":
		if lv != "":
			box.add_child(Sheet._pic(pick(r["chips"]), Vector2(24, 14), Vector2(48, 40)))
		return box
	if lv == "sketch" and Art.has_picture("sketch_" + id):
		box.add_child(Sheet._pic("sketch_" + id, Vector2(24, 10), Vector2(48, 48)))
	elif lv == "photo" or lv == "":
		var tex := stand_frame(r)
		if tex != null:
			var t := TextureRect.new()
			t.texture = tex
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var fw := float(r["frame"][0])
			var fh := float(r["frame"][1])
			var k := minf(56.0 / fw, 46.0 / fh)
			t.size = Vector2(fw, fh) * k
			t.position = Vector2(48 - t.size.x / 2.0, 58 - t.size.y)
			if lv == "":
				# A silhouette: the shape, all one grey.
				t.modulate = Color(0.32, 0.3, 0.34, 0.85)
				t.position.x -= 14
			box.add_child(t)
	return box


## An animal's standing frame, facing right.
static func stand_frame(r: Dictionary) -> Texture2D:
	var art := str(r.get("sprite", ""))
	if art == "" or not Art.has_picture(art):
		return null
	var a := AtlasTexture.new()
	a.atlas = Art.texture(art)
	a.region = Rect2(0, float(r["frame"][1]), float(r["frame"][0]), float(r["frame"][1]))
	return a


func _fill_detail(progress: String) -> void:
	var c := session.content
	var w := session.wildlife
	var r := c.row("animals", selected)
	var lv := w.level_of(selected)
	var e: Dictionary = w.guide.get(selected, {})
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.add_child(picture(r, lv))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(text(c.text(str(r["name"])) if lv != "" else c.text("guide_unknown_name"), 10, KitStyle.TEXT_DARK, DETAIL_W - 110))
	v.add_child(text(progress, 7, KitStyle.TEXT_DARK, DETAIL_W - 110))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 3)
	chips.add_theme_constant_override("v_separation", 2)
	chips.custom_minimum_size = Vector2(DETAIL_W - 110, 0)
	# When and where: the hint for an unknown, what was seen for the rest.
	if str(r["kind"]) != "place":
		for ph: String in r["hours"]:
			chips.add_child(chip(pick(["chip_" + ph]), c.text("guide_when_" + ph)))
	for ch: String in r["chips"]:
		if str(r["kind"]) == "place" or not ch in ["chip_dawn", "chip_dusk", "chip_night"]:
			chips.add_child(chip(pick([ch]), c.text("guide_" + ch)))
	if str(r["cousin_of"]) != "":
		chips.add_child(chip(pick(["guide_tab_animals"]), c.text("guide_among", {"name": c.text("animal_" + str(r["cousin_of"]))})))
	if lv != "":
		chips.add_child(chip(pick(["icon_have"]), c.text("guide_seen_times", {"n": int(e.get("count", 1))}), "good"))
		if bool(e.get("good", false)):
			chips.add_child(chip(pick(["guide_good_stamp"]), c.text("guide_good_photo"), "good"))
	if lv == "photo" and str(r.get("eats", "")) != "":
		chips.add_child(chip(pick(["verb_give", "icon_gift_like"]), c.text("guide_eats", {"food": c.text(str(r["eats"]))})))
	if lv != "" and session.skills.flag("guide_homes"):
		var near := _home_place(selected)
		if near != "":
			chips.add_child(chip(pick(["icon_where"]), c.text("guide_lives_near", {"place": near})))
	v.add_child(chips)
	top.add_child(v)
	detail.add_child(top)
	if lv != "":
		var where: Array = (e.get("where", {}) as Dictionary).keys()
		if not where.is_empty():
			var names := PackedStringArray()
			for lm: String in where:
				names.append(c.text(c.row("landmarks", lm)["name"]))
			detail.add_child(voice(c.text("guide_seen_near", {"places": ", ".join(names)})))
		detail.add_child(voice(c.text(str(r["line"]))))
	else:
		detail.add_child(voice(c.text("guide_hint_" + str(r["kind"]))))


func _home_place(id: String) -> String:
	var hs: Array = session.wildlife.homes.get(id, [])
	if hs.is_empty():
		return ""
	var best := ""
	var bd := 1e9
	for lm: String in session.content.ids("landmarks"):
		var d := (hs[0] as Vector2).distance_to(session.world.landmark_pos(lm))
		if d < bd:
			bd = d
			best = session.content.text(session.content.row("landmarks", lm)["name"])
	return best


## Keys while the guide is open. True when the key was used.
func handle(event: InputEvent) -> bool:
	if event.is_action_pressed("tab_prev"):
		turn(-1)
		return true
	if event.is_action_pressed("tab_next"):
		turn(1)
		return true
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		var ids: Array = entries().map(func(r: Dictionary) -> String: return str(r["id"]))
		if ids.is_empty():
			return true
		var i := ids.find(selected)
		selected = str(ids[clampi(i + (1 if event.is_action_pressed("move_down") else -1), 0, ids.size() - 1)])
		refresh()
		return true
	return false
