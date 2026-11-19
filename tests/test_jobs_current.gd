extends RefCounted
## 0.4.9: the Jobs page works on the site the ranger last found, mapped or
## reached (at the outlook it no longer shows the tower), and each thing to
## bring says where to get it (the bedroll, axe and shovel are in the
## station's chest), never pointing into a building still locked.


func test_things_to_bring_say_where_they_are(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.jobs.add("open_cabin", "given")
	var station := s.content.text(s.content.row("structures", "ranger_station")["name"])
	t.equal(s.jobs.where_to_get("open_cabin", "shovel"), s.content.text("where_chest", {"place": station}), "the shovel is in the station's chest")
	var tower := s.content.text(s.content.row("structures", "static_tower")["name"])
	t.check(not s.jobs.where_to_get("open_cabin", "planks").contains(tower), "never a chest in a building still locked")
	t.check(s.jobs.where_to_get("open_cabin", "radio_valve").contains(s.content.text("jt_lock_catalog")), "a catalog thing says what it waits for")


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


## Joining a site's trail is told the moment it happens, as its job's step
## (a toast), and its flags leave the map.
func test_joining_the_trail_is_told(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.sites_found["kettle_pond"] = true
	s.map.mark_landmark("kettle_pond")
	s.jobs.update(true)
	t.check(not s.site_reached("kettle_pond"), "the pond starts apart from the station's trail")
	var told: Array[String] = []
	s.jobs.toast.connect(func(_i: String, _c: Color, m: String, _snd: String) -> void: told.append(m))
	ParkHelpers.open_route(s, "pond")
	s.jobs.update(true)
	var k := "open_pond"
	var join := -1
	for i in (s.jobs.def(k)["steps"] as Array).size():
		if s.jobs.def(k)["steps"][i]["kind"] == "join_trail":
			join = i
	var want := s.content.text("jt_step_done", {"step": s.jobs.step_label(k, join)})
	t.check(told.has(want), "joining it is told")
	told.clear()
	s.jobs.update(true)
	t.check(not told.has(want), "told once")
