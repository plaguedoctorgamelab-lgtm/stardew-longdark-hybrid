extends RefCounted
## Phase 2a, step 6: the fire tower as a shelter, its radio, the tower
## survey, waking there after a collapse, and rumors from notes.

const TOWER := "static_tower"


func _repair_tower(s: GameSession) -> void:
	for st: Dictionary in s.content.row("structures", TOWER)["repair_steps"]:
		s.structures.debug_complete_step(TOWER, st["id"])


func _stand_at(s: GameSession, kind: String) -> void:
	var layout: InteriorLayout = s.interiors[s.location]
	var r := layout.furniture_rect(layout.find(kind))
	s.interior_pos = Vector2(r.position.x + 0.5, r.end.y + 0.5)
	s.facing = GameSession.FACING_UP


func test_tower_is_a_shelter(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_teleport("tower")
	t.check(not s.enter_building(TOWER), "locked until repaired")
	_repair_tower(s)
	t.check(s.enter_building(TOWER), "repaired, it opens")
	var chest: Inventory = s.structures.chests[TOWER]
	var supplies := 0
	for i in chest.size():
		if chest.item_at(i) != "":
			supplies += 1
	t.check(supplies > 0, "its chest holds supplies (%d stacks)" % supplies)
	var heard := []
	s.radio_heard.connect(func(lines: PackedStringArray) -> void: heard.append(lines))
	_stand_at(s, "radio")
	s.interact()
	t.equal(heard.size(), 0, "the tower radio wants its valve first (jobs rebuild)")
	s.jobs.unlocks["tower_forecast"] = true
	s.interact()
	t.equal(heard.size(), 1, "with it fitted, the tower radio gives the forecast")
	s.debug_add_item("firewood", 1)
	t.check(s.feed_stove(), "the stove lights")
	t.check(s.needs_context()["stove_lit"], "and warms the room")
	var asked := []
	s.confirm_requested.connect(func(kind: String, _text: String) -> void: asked.append(kind))
	_stand_at(s, "bed")
	s.interact()
	t.equal(asked, ["sleep"], "the bed offers sleep")
	var saves := s.save_count
	s.answer_confirm(true)
	t.equal(s.save_count, saves + 1, "sleeping there saves")
	t.equal(s.location, TOWER, "and the ranger wakes in the tower")


func test_tower_survey(t: TestCase) -> void:
	var s := TestCase.new_session()
	_repair_tower(s)
	s.debug_teleport("tower")
	s.enter_building(TOWER)
	s.debug_force_weather("clear")
	s.debug_set_time(23 * 60)
	t.check(not s.start_survey(), "no survey in the dark")
	s.debug_set_time(10 * 60)
	s.debug_wipe_map()
	t.check(s.start_survey(), "the cab survey starts by day")
	s.pass_minutes(s.tuning.integer("map.survey_minutes"))
	var r := s.tuning.num("map.tower_radius")
	var at := s.door_front(TOWER)
	t.check(s.map.is_revealed(Vector2i(at + Vector2(r - 3, 0))), "it reveals out to %d tiles" % r)
	t.check(not s.map.is_revealed(Vector2i(at + Vector2(r + 3, 0))), "and no further")
	t.check(s.map.revealed_count > PI * r * r * 0.5, "a much larger patch than an outlook (%d tiles)" % s.map.revealed_count)


func test_collapse_wakes_in_the_nearest_shelter(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_teleport("tower")
	s.collapse()
	t.check(s.location != TOWER, "a run-down tower is no shelter")
	_repair_tower(s)
	s.leave_building()
	s.debug_teleport("tower")
	var texts := []
	s.collapsed.connect(func(text: String) -> void: texts.append(text))
	s.collapse()
	t.equal(s.location, TOWER, "near a repaired tower, the ranger wakes there")
	# Since 0.4.7 the note opens with why the ranger passed out (tracker #6).
	t.check(texts[0].contains(s.content.text("msg_rescue_tower")), "and the note says so")
	s.camp = {"bed": Vector2i(s.door_front("ranger_station")) + Vector2i(30, 0), "fire": Vector2i(s.door_front("ranger_station")) + Vector2i(30, 1), "fire_minutes": 0}
	s.leave_building()
	s.outdoor_pos = Vector2(s.camp["bed"]) + Vector2(0.5, 0.5)
	s.collapse()
	t.equal(s.location, "ranger_station", "a camp is never where you wake")


## Jobs rebuild: rumors now come with jobs (finishing one, or a job
## appearing); the last ranger's notes still read on the boards.
func test_rumors_from_jobs(t: TestCase) -> void:
	var s := TestCase.new_session()
	var ids := func() -> Array: return MapScreen.hints(s).map(func(h: Dictionary) -> String: return h["text"])
	t.check(not (ids.call() as Array).has(s.content.text("landmark_hint_static_tower")), "no tower rumor at the start")
	s.jobs.add("open_tower", "unlocked")
	t.check(s.rumors.has("static_tower"), "the tower's job brings its rumor")
	for h: Dictionary in MapScreen.hints(s):
		if h["text"] == s.content.text("landmark_hint_static_tower"):
			var c: Vector2 = h["center"]
			t.check(c.distance_to(s.world.landmark_pos(TOWER)) < float(h["radius"]), "the circle holds the tower")
			t.check(c.distance_to(s.world.landmark_pos(TOWER)) > 4.0, "but off-centre")
	s.map.mark_landmark(TOWER)
	t.check(not (ids.call() as Array).has(s.content.text("landmark_hint_static_tower")), "mapped, the rumor goes")
	_repair_tower(s)
	s.debug_teleport("tower")
	s.enter_building(TOWER)
	_stand_at(s, "note_board")
	var text := s.read_note_board()
	t.check(text.contains(s.content.text("note_bridge")), "the tower's note still reads")
	t.check(s.save_game(), "saved")
	var s2 := TestCase.new_session(1)
	s2.save_path = s.save_path
	s2.load_game()
	t.check(s2.rumors.has("static_tower") and s2.notes_read.has("note_bridge"), "rumors and notes kept in the save")


func test_debug_repairs_the_tower(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_repair_all(TOWER, true)
	t.check(s.structures.is_open(TOWER), "the debug panel can repair the tower")
	s.debug_repair_all(TOWER, false)
	t.check(not s.structures.is_open(TOWER), "and undo it")
