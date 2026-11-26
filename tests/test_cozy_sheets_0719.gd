extends RefCounted
## The cozy UI, last step (0.7.19): the Log, the shops on the clipboard, and
## the world without tags (the action chip and the toast).


func test_the_log_sits_on_the_clipboard(t: TestCase) -> void:
	var s := TestCase.new_session()
	var b := BookScreen.new()
	b.setup(s)
	b.open("park")
	for pg in BookScreen.PAGES:
		b.show_page(pg)
		t.equal(b.page, pg, "%s opens" % pg)
		var listed := pg in ["cards", "letters", "notes", "creatures"]
		t.equal(b.list_scroll.visible, listed, "%s: a list only where there are things to pick" % pg)
		t.check(Sheet.FRAME.encloses(b._full.get_rect()) and Sheet.FRAME.encloses(b.detail_scroll.get_rect()), "%s: on the board" % pg)
	t.check(not b.lines_for("ledger").is_empty(), "the ledger's lines are still there for checks")
	b.free()


func test_notes_know_their_kind_and_doodle(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.park.add_note("A badger has dug in by the gate.", "badger")
	s.park.add_note("Behind a loose board: a chipped mug.", "strange")
	s.park.add_note("An old note from before kinds.")
	var n: Array = s.park.notes
	t.equal(BookScreen.doodle_for(n[n.size() - 3]), "doodle_paw", "a badger gets a paw")
	t.equal(BookScreen.doodle_for(n[n.size() - 2]), "doodle_mug", "a strange mug gets a mug")
	t.equal(str(n[n.size() - 1]["kind"]), "", "a note with no kind")
	t.check(BookScreen.doodle_for(n[n.size() - 1]) != "", "still gets a doodle")
	var s2 := TestCase.new_session()
	s2.park.from_dict(s.park.to_dict())
	t.equal(str(s2.park.notes[s2.park.notes.size() - 2]["kind"]), "strange", "the kind is saved")


func test_buying_and_selling_on_the_shop_sheet(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.town_open = true
	s.debug_money(500)
	var sh := ShopSheet.new()
	sh.setup(s)
	sh.open("outfitters")
	t.equal(sh.tab, "buy", "the outfitters open on Buy")
	var gs := sh.goods()
	t.check(not gs.is_empty(), "there are goods")
	t.check(sh.list.get_child_count() == gs.size(), "a card for each")
	var g: Dictionary = gs[0]
	var item := str(g["item"])
	var before := s.park.money.wallet
	var had := s.backpack.count(item) + s.wardrobe.spare.count(item)
	sh._do_buy("buy", item)
	t.equal(s.park.money.wallet, before - int(g["price"]), "the price is paid")
	t.check(s.backpack.count(item) + s.wardrobe.spare.count(item) > had, "and it's ours")
	t.check(Sheet.FRAME.encloses(sh.list_scroll.get_rect()) and Sheet.FRAME.encloses(sh.detail_scroll.get_rect()), "on the board")
	sh.free()


func test_the_action_chip_replaces_the_tags(t: TestCase) -> void:
	var s := TestCase.new_session()
	var h := Hud.new()
	h.setup(s, KitStyle.theme())
	h.look_text = "Supply catalog"
	h._update_tip()
	t.check(h.action_chip.visible, "facing something shows the chip")
	t.equal(h._chip_label.text, "Supply catalog", "with its name")
	t.check(not h.look_tag.visible and not h.tip.visible, "and no tag floats")
	t.equal(h.action_chip.position.y, Hud.CHIP_Y, "it sits just above the item bar")
	h.look_text = ""
	h.world_hint = "X: go in"
	h._update_tip()
	t.check(not h.action_chip.visible or h._chip_label.text == "go in", "a hint drops its key into a key cap")
	h.show_toast("item_trail_mix", "Trail mix")
	h._update_toast(0.1)
	t.check(h.toast.visible, "a new idea slides in as a toast")
	t.equal(h._toast_name.text, "Trail mix", "with its name")
	h.free()
