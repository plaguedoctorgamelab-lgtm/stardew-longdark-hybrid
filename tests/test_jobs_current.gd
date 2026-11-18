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


## Sites with no building are opened at their post or cairn: before 0.4.10
## X there only ever said the place's name, so the outlook and the pond
## could never be declared open.
func test_outlook_and_pond_open_at_their_post(t: TestCase) -> void:
	for pair: Array in [["outlook", "scenic_outlook"], ["kettle_pond", "kettle_pond"]]:
		var s := TestCase.new_session()
		var site: String = pair[0]
		var lm: String = pair[1]
		# Stand where X reaches the place's post.
		var at := Vector2.ZERO
		var c := s.site_door(site)
		for dy in range(-6, 7):
			for dx in range(-6, 7):
				var p := c + Vector2(dx, dy)
				if at == Vector2.ZERO and not s.world.is_solid(Vector2i(p)):
					var o := s.world.interactive_near(p, s.tuning.num("world.interact_reach_tiles") + 0.5)
					if not o.is_empty() and o["interact"] == "landmark:" + lm:
						at = p
		t.check(at != Vector2.ZERO, "%s: a spot by its post" % site)
		s.outdoor_pos = at
		s.interact()
		t.check(s.map.is_landmark_mapped(lm), "%s: X at the post maps it" % site)
		for step in ["find", "reach", "sign"]:
			s.debug_site_step(site, step, true)
		t.check(s.site_ready(site), "%s: every step done" % site)
		t.equal(s.guide.x_hint(), s.content.text("hint_x_open_site"), "%s: the hint says X declares it open" % site)
		var asked := [""]
		s.confirm_requested.connect(func(kind: String, _text: String) -> void: asked[0] = kind)
		s.interact()
		t.equal(asked[0], "open_site", "%s: X asks to declare it open" % site)
		s.answer_confirm(true)
		t.check(s.sites_open.has(site), "%s: and it is open" % site)


## Joining a site's trail to the station's is told the moment it happens,
## and its flags leave the map (0.4.10; before, nothing was said).
func test_joining_the_trail_is_told(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.check(s.site_reached("outlook"), "the outlook's trail already reaches its post in a new game")
	s.sites_found["kettle_pond"] = true
	s.debug_site_step("kettle_pond", "map", true)
	t.check(not s.site_reached("kettle_pond"), "the pond starts apart from the station's trail")
	t.equal(s.guide.trail_gaps().size(), 1, "so the map shows its flags")
	var told: Array[String] = []
	s.message.connect(func(m: String) -> void: told.append(m))
	ParkHelpers.open_route(s, "pond")
	s.process(0.01)
	var want := s.content.text("msg_trail_joined", {"name": s.content.text("landmark_kettle_pond")})
	t.check(told.has(want), "joining it is told")
	t.equal(s.guide.trail_gaps().size(), 0, "and its flags are gone")
	told.clear()
	s.process(0.01)
	t.check(not told.has(want), "told once")
