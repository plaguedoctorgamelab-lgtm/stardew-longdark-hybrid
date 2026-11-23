extends RefCounted
## The game menu made over (0.7.9): every item has a card that says what it
## is, the backpack sorts, and everything earned is counted and saved.


func test_every_item_says_what_it_is(t: TestCase) -> void:
	var s := TestCase.new_session()
	for r: Dictionary in s.content.rows("items"):
		var id := str(r["id"])
		t.check(not ItemTip.lines_for(s, id).is_empty(), "%s has words on its card" % id)
		t.check(ItemTip.kind_text(s, id) != "", "%s says what kind of thing it is" % id)


func test_food_cards_say_what_eating_does(t: TestCase) -> void:
	var s := TestCase.new_session()
	var lines := "\n".join(ItemTip.lines_for(s, "hot_soup"))
	t.check(lines.contains("energy"), "hot soup's card gives its energy")


func test_sorting_leaves_the_item_bar(t: TestCase) -> void:
	var s := TestCase.new_session()
	var bar := []
	for i in InventoryScreen.COLS:
		bar.append(s.backpack.item_at(i))
	s.backpack.slots[s.backpack.size() - 1] = {"item": "planks", "count": 3}
	s.backpack.slots[s.backpack.size() - 2] = {"item": "planks", "count": 4}
	s.backpack.slots[s.backpack.size() - 3] = {"item": "apple", "count": 1}
	var before := s.backpack.count("planks")
	s.backpack.sort_from(InventoryScreen.COLS)
	for i in InventoryScreen.COLS:
		t.equal(s.backpack.item_at(i), bar[i], "slot %d of the item bar is left alone" % (i + 1))
	t.equal(s.backpack.count("planks"), before, "nothing lost")
	t.equal(s.backpack.item_at(InventoryScreen.COLS), "apple", "food sorts before materials")
	t.equal(int(s.backpack.slot(InventoryScreen.COLS + 1)["count"]), before, "planks merged into one stack")


func test_everything_earned_is_counted(t: TestCase) -> void:
	var s := TestCase.new_session()
	var e := s.park.money.earned
	s.park.money.earn(1, "test", 50)
	s.park.money.spend(1, "test", 20)
	t.equal(s.park.money.earned, e + 50, "earning counts, spending doesn't take it back")
	var m := Money.new()
	m.from_dict(s.park.money.to_dict())
	t.equal(m.earned, e + 50, "and it's saved")
