extends RefCounted
## 0.4.9: the Jobs page works on the site the ranger last found, mapped or
## reached (at the outlook it no longer shows the tower), and each thing to
## bring says where to get it (the bedroll, axe and shovel are in the
## station's chest), never pointing into a building still locked.


func _page_title(s: GameSession) -> String:
	return s.guide.job_page_lines()[0]


func test_the_job_follows_the_ranger(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.outdoor_pos = s.site_door("static_tower")
	s._look_for_sites()
	t.equal(_page_title(s), s.content.text("job_current", {"title": s.content.text("job_site_title", {"name": s.content.text("landmark_static_tower")})}), "finding the tower makes it the job")
	s.outdoor_pos = s.site_door("outlook")
	s._look_for_sites()
	t.check(_page_title(s).contains(s.content.text("landmark_scenic_outlook")), "at the outlook, the outlook is the job, not the tower")
	s.outdoor_pos = s.door_front("ranger_station")
	s._watch_visits()
	s.outdoor_pos = s.site_door("static_tower")
	s._watch_visits()
	t.check(_page_title(s).contains(s.content.text("landmark_static_tower")), "going back to the tower makes it the job again")
	s.save_game()
	var s2 := TestCase.new_session()
	s2.save_path = s.save_path
	s2.load_game()
	t.equal(s2.current_job, "static_tower", "the job being worked on is saved")


func test_things_to_bring_say_where_they_are(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.enter_building("ranger_station")
	s.read_note_board()
	s.leave_building()
	var lines := "\n".join(s.guide.job_page_lines())
	var station := s.content.text(s.content.row("structures", "ranger_station")["name"])
	t.check(lines.contains(s.content.item_name("bedroll") + " " + s.content.text("where_chest", {"place": station})), "the bedroll to bring is in the station's chest")
	t.check(lines.contains(s.content.item_name("axe") + " " + s.content.text("where_chest", {"place": station})), "so is the axe")
	var tower := s.content.text(s.content.row("structures", "static_tower")["name"])
	var cabin := s.content.text(s.content.row("structures", "test_cabin")["name"])
	t.check(not lines.contains(tower) and not lines.contains(s.content.text("where_chest", {"place": cabin})), "never a chest in a building still locked")
	s.sites_found["static_tower"] = true
	s.current_job = "static_tower"
	lines = "\n".join(s.guide.job_page_lines())
	t.check(lines.contains(s.content.item_name("shovel") + " 0/1 " + s.content.text("where_chest", {"place": station})), "the tower's trail needs the shovel, in the station's chest")
	s.backpack.add("shovel")
	s.structures.chests["ranger_station"].remove("shovel", 1)
	lines = "\n".join(s.guide.job_page_lines())
	t.check(not lines.contains(s.content.item_name("shovel") + " 0/1"), "once carried, no need to say where")
