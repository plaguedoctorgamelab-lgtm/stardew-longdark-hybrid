extends RefCounted
## Phase 4, 4a step 4: the People page and the calendar.


func test_people_page_lists_only_those_met(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.equal(s.town.social_rows().size(), 0, "nobody met at the start")
	s.town.met["wren"] = true
	s.town.met["gus"] = true
	s.town.add_points("wren", 2 * 250 + 10)
	s.town.talked_day["wren"] = s.clock.absolute_day()
	var rows := s.town.social_rows()
	t.equal(rows.size(), 2, "the two met")
	t.equal(str(rows[0]["id"]), "wren", "in the cast's order")
	t.equal(int(rows[0]["hearts"]), 2, "with their hearts")
	t.equal(int(rows[0]["cap"]), 8, "Wren's hearts stop at 8 until dating")
	t.equal(int(rows[1]["cap"]), 10, "Gus's reach 10")
	t.check(bool(rows[0]["talked"]) and not bool(rows[1]["talked"]), "who has been talked to today")
	t.check(Art.has_picture(str(rows[1]["sprite"])), "each has a face to show")


func test_gifts_this_week_are_counted(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.town.met["gus"] = true
	s.backpack.add("planks", 2)
	s.town.give("gus", "planks")
	t.equal(int(s.town.social_rows()[0]["gifts"]), 1, "one gift this week")


func test_the_calendar_shows_birthdays_and_festivals(t: TestCase) -> void:
	var s := TestCase.new_session()
	var spring := s.town.calendar(0)
	t.equal(spring.size(), s.clock.days_per_season(), "every day of the season")
	t.check((spring[5]["birthdays"] as Array).has("bev"), "Bev's birthday on spring 6")
	t.equal(str(spring[12]["festival"]), "thaw_fair", "the Thaw Fair on spring 13")
	var all := 0
	for season in 4:
		for d: Dictionary in s.town.calendar(season):
			all += (d["birthdays"] as Array).size()
	t.equal(all, s.content.rows("townsfolk").size(), "every birthday falls on the calendar")
	t.check(InputMap.has_action("social"), "O opens the page")
	for n: String in ["ui_social", "ui_calendar", "ui_heart_full", "ui_heart_empty", "ui_heart_locked", "ui_cal_birthday", "ui_cal_festival", "ui_talk_tick", "ui_gift_tick"]:
		t.check(Art.has_picture(n), "%s is drawn" % n)
