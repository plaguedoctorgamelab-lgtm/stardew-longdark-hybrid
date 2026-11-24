extends RefCounted
## The cozy UI, step one (0.7.15): the shared clipboard sheet and the Make
## sheet built on it.


func _sheet(s: GameSession) -> MakeSheet:
	var m := MakeSheet.new()
	m.setup(s)
	return m


func _cards_text(m: MakeSheet) -> String:
	var out := PackedStringArray()
	for c in m.list.get_children():
		for k in c.get_children():
			if k is Label:
				out.append((k as Label).text)
	return "\n".join(out)


func test_the_sheet_sits_on_the_clipboard(t: TestCase) -> void:
	var s := TestCase.new_session()
	var m := _sheet(s)
	m.open("anywhere")
	t.check(m.visible, "it opens")
	t.equal(Sheet.FRAME, ClipboardScreen.FRAME, "the same board as the jobs sheet")
	t.equal(Sheet.PAPER, ClipboardScreen.PAPER, "and the same paper")
	for r: Rect2 in [m.list_scroll.get_rect(), m.detail_scroll.get_rect()]:
		t.check(Sheet.FRAME.encloses(r), "nothing past the board's edge")
	t.check(m.stamps.position.y + 16 <= Sheet.PAPER.end.y, "the stamps sit on the paper")
	m.close()
	t.check(not m.visible, "and closes")
	m.free()


func test_only_known_recipes_in_kind_order(t: TestCase) -> void:
	var s := TestCase.new_session()
	var m := _sheet(s)
	m.open("anywhere")
	var ids := m.recipes()
	t.check(not ids.is_empty(), "the starting recipes are listed")
	var last := -1
	for id in ids:
		t.check(s.recipes_known.has(id), "%s is known" % id)
		var g := MakeSheet.GROUPS.find(m.group_of(id))
		t.check(g >= last, "%s comes in its kind's place" % id)
		last = g
	t.equal(m.group_of("cairn"), "park", "a cairn is for the trail")
	t.equal(m.group_of("planks"), "workshop", "planks are workshop")
	t.equal(m.group_of("hot_soup"), "food", "soup is food")
	t.check(_cards_text(m).contains(s.content.text("make_group_park")), "the list has its kind ribbons")
	m.free()


func test_short_then_ready_then_made(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.backpack.remove("stones", s.backpack.count("stones"))
	var m := _sheet(s)
	m.open("anywhere")
	m.selected = "cairn"
	m.refresh()
	t.equal(str(m.status_of("cairn")[0]), s.content.text("make_short"), "no stones: short")
	t.equal(m.how_many("cairn"), 0, "none can be made")
	t.check(m.stamps.get_child_count() >= 1 and (m.stamps.get_child(0) as Button).disabled, "the Make stamp is greyed")
	s.backpack.add("stones", 9)
	m.refresh()
	t.equal(str(m.status_of("cairn")[0]), s.content.text("make_ready"), "with stones: ready")
	t.equal(m.how_many("cairn"), 3, "nine stones make three")
	t.check(not (m.stamps.get_child(0) as Button).disabled, "the Make stamp works")
	t.equal(m.stamps.get_child_count(), 2, "and a Make 3 stamp beside it")
	var before := s.backpack.count("cairn")
	t.equal(m.make(1), 1, "Make makes one")
	t.equal(s.backpack.count("cairn"), before + 1, "a cairn in the pack")
	t.equal(s.backpack.count("stones"), 6, "three stones used")
	t.equal(m.make(5), 2, "Make many stops when the stones run out")
	t.equal(s.backpack.count("stones"), 0, "every stone used")
	m.free()


func test_tabs_sort_by_where_things_are_made(t: TestCase) -> void:
	var s := TestCase.new_session()
	var m := _sheet(s)
	m.open("anywhere")
	t.equal(m.tab, "all", "the menu opens on All")
	for tb in ["anywhere", "workbench", "fire"]:
		m.set_tab(tb)
		for id in m.recipes():
			t.equal(str(s.content.row("recipes", id)["station"]), tb, "%s on the %s tab" % [id, tb])
	m.set_tab("workbench")
	if not m.recipes().is_empty():
		var id: String = m.recipes()[0]
		t.equal(str(m.status_of(id)[0]), s.content.text("make_at_workbench"), "away from a bench, bench things say where")
	m.open("fire")
	t.equal(m.tab, "fire", "at a fire it opens on Fire")
	var found := false
	for b in m.stamps.get_children():
		if (b as Button).text.begins_with(s.content.text("make_firewood", {"n": s.backpack.count("firewood")})):
			found = true
	t.check(found, "at a fire, a stamp feeds it")
	m.free()


func test_need_tiles_turn_red_when_short(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.backpack.remove("stones", s.backpack.count("stones"))
	s.backpack.add("stones", 1)
	var m := _sheet(s)
	m.open("anywhere")
	m.selected = "cairn"
	m.refresh()
	var e: Dictionary = m.inputs_of("cairn")[0]
	t.equal([e["item"], e["have"], e["need"]], ["stones", 1, 3], "the cairn needs three stones, one at hand")
	var red := false
	for c in m.detail.get_children():
		for f in c.get_children():
			if f is Panel and f.self_modulate != Color.WHITE:
				red = true
	t.check(red or Art.has_picture("ui_tile_red"), "the stones tile is red")
	m.free()
