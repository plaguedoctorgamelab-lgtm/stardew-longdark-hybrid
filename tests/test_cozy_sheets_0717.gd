extends RefCounted
## The cozy UI, step two (0.7.17): Pack, Map and Town on the clipboard, at
## its size, and the label strip in place of the item tag.


func _inside(t: TestCase, c: Control, what: String) -> void:
	var r := Rect2(c.global_position if c.is_inside_tree() else c.position, c.size)
	t.check(Sheet.FRAME.encloses(r), "%s sits on the board" % what)


func test_the_pack_sits_on_the_clipboard(t: TestCase) -> void:
	var s := TestCase.new_session()
	var inv := InventoryScreen.new()
	inv.setup(s)
	inv.open(null, "")
	t.equal(inv.size, Vector2(480, 270), "the pack covers the screen like every sheet")
	for b in inv._pack_buttons:
		_inside(t, b, "a pocket")
	for b: Button in [inv.sort_button, inv.drop_button, inv.trash_button]:
		_inside(t, b, "a stamp")
	_inside(t, inv._strip, "the label strip")
	inv.close()
	inv.free()


func test_the_label_strip_says_what_a_thing_is(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.backpack.add("hot_soup", 2)
	var inv := InventoryScreen.new()
	inv.setup(s)
	inv.open(null, "")
	t.check(inv._strip_idle, "with nothing pointed at, the strip shows the park")
	inv.show_item("hot_soup", 2)
	t.check(inv._strip_name.text.begins_with(s.content.item_name("hot_soup")), "pointing fills the strip with the item's name")
	t.equal(inv._strip_chips.get_child_count(), InventoryScreen.item_chips(s, "hot_soup").size(), "and its facts as chips")
	t.check(inv._strip_chips.get_child_count() >= 2, "soup gives energy and warmth")
	inv._idle_strip()
	t.check(inv._strip_idle, "and empties back to the park")
	inv.free()


func test_a_chest_takes_the_gear_walls_place(t: TestCase) -> void:
	var s := TestCase.new_session()
	var inv := InventoryScreen.new()
	inv.setup(s)
	var chest: Inventory = s.structures.chests["ranger_station"]
	inv.open(chest, s.content.text("ui_chest"))
	t.equal(inv._other_buttons.size(), chest.size(), "a slot for each of the chest's")
	for b in inv._other_buttons:
		_inside(t, b, "a chest slot")
	for slot: String in inv._wear:
		t.check(not (inv._wear[slot] as Button).visible, "the gear wall makes way")
	inv.close()
	inv.free()


func test_the_map_sits_on_the_clipboard(t: TestCase) -> void:
	var s := TestCase.new_session()
	var m := MapScreen.new()
	m.setup(s)
	t.equal(m.size, Vector2(480, 270), "the map covers the screen like every sheet")
	t.check(Sheet.FRAME.encloses(Rect2(m.clip.position, m.clip.size)), "the map's window sits on the paper")
	t.check(m.clip.size.x < Sheet.PAPER.size.x and m.clip.size.y <= Sheet.PAPER.size.y, "never bigger than the paper")
	t.check(Sheet.FRAME.encloses(Rect2(m.legend_strip.position, m.legend_strip.size)), "the legend sits under it")
	m.free()


func test_giving_teaches_what_someone_loves(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.town_open = true
	var who := "gus"
	var loves := s.town.taste_list(who, "love")
	t.check(not loves.is_empty(), "Gus loves something")
	var item: String = loves[0]
	t.check(not s.town.gifts_known.get(who, {}).has(item), "not known before it's given")
	s.backpack.add(item, 1)
	var r := s.town.give(who, item)
	t.check(bool(r["ok"]), "the gift is given")
	t.equal(str(s.town.gifts_known[who][item]), "love", "now the ranger knows Gus loves it")
	var d := s.town.to_dict()
	var s2 := TestCase.new_session()
	s2.town.from_dict(d)
	t.equal(str(s2.town.gifts_known[who][item]), "love", "and remembers it after a save")


func test_the_town_sheet_shows_people_and_the_calendar(t: TestCase) -> void:
	var s := TestCase.new_session()
	for r: Dictionary in s.content.rows("townsfolk"):
		s.town.met[str(r["id"])] = true
	var sc := SocialScreen.new()
	sc.setup(s)
	sc.open("people")
	t.equal(sc.list.get_child_count(), s.town.social_rows().size(), "a card for each person met")
	t.check(sc.detail.get_child_count() > 0, "the first one shown in full")
	t.check(Sheet.FRAME.encloses(sc.list_scroll.get_rect()) and Sheet.FRAME.encloses(sc.detail_scroll.get_rect()), "both sides on the board")
	sc.turn()
	t.equal(sc.page, "calendar", "Q or E turns to the calendar")
	t.check(not sc.list_scroll.visible and sc._cal.visible, "the calendar fills the paper")
	sc.free()
