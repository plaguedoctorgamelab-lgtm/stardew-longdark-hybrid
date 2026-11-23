extends RefCounted
## Mark's 0.7.7 playtest: the mailbox off the path, orders shown in the
## catalog, and the Ranger page's clothes that take no backpack room.


func test_mailbox_beside_the_station(t: TestCase) -> void:
	var s := TestCase.new_session()
	var p: Dictionary = s.world.structure_placement("ranger_station")
	var m := s.mailbox_pos()
	t.check(m.x > float(p["pos"][0]) + float(p["size"][0]), "the mailbox stands right of the station")
	t.check(m.distance_to(s.door_front("ranger_station")) > 2.5, "and off the path in front of the door")


func test_orders_show_in_the_catalog(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.jobs.unlocks["catalog"] = true
	s.park.money.wallet = 500
	t.equal(s.park.order("planks"), "", "planks ordered")
	var first: Dictionary = s.park.catalog_options()[0]
	t.check(not bool(first["enabled"]), "the order is listed, greyed, at the top")
	t.check(str(first["label"]).begins_with("On order") and str(first["label"]).contains(s.content.text(s.content.row("catalog", "planks")["name"])), "and says what's on order")


func test_clothes_take_no_backpack_room(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.wardrobe.keep("wool_coat")
	var before := s.backpack.count("ranger_jacket")
	t.check(s.put_on("wool_coat"), "a spare coat put on")
	t.equal(str(s.wardrobe.worn["coat"]), "wool_coat", "worn")
	t.check(s.wardrobe.spare.has("ranger_jacket") and not s.wardrobe.spare.has("wool_coat"), "the jacket goes with the spare clothes")
	t.equal(s.backpack.count("ranger_jacket"), before, "not into the backpack")
	# A full backpack no longer stops a change of clothes.
	s.backpack.add("wool_toque", 1)
	for i in 40:
		if s.backpack.add("planks", 99) > 0:
			break
	t.check(s.put_on("wool_toque"), "a toque from a full backpack")
	t.check(s.wardrobe.spare.has("ranger_hat"), "the hat kept")
	var d := s.wardrobe.to_dict()
	var w := Wardrobe.new(s.content)
	w.from_dict(d)
	t.equal(w.spare.size(), s.wardrobe.spare.size(), "spare clothes are saved")


func test_ranger_page_says_what_clothes_do(t: TestCase) -> void:
	var s := TestCase.new_session()
	var r := RangerScreen.new()
	r.setup(s)
	for row: Dictionary in s.content.rows("clothing"):
		t.check(r.buff_text(str(row["id"])) != "", "%s says what it does" % row["id"])
	r.free()
