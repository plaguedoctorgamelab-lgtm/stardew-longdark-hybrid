extends RefCounted
## Tuning: changing a value in the file and reloading changes behavior without
## a restart. Also: every debug action is callable from the tests.

const TMP := "user://test_tuning.json"


func test_reload_changes_behavior(t: TestCase) -> void:
	var src := FileAccess.get_file_as_string(Tuning.DEFAULT_PATH)
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(src)
	f.close()
	var s := GameSession.new(TMP)
	s.new_game(1)
	s.debug_force_weather("clear")
	s.outdoor_pos = s.world.spawn("station") + Vector2(6, 0)
	var before := s.speed_tiles_per_second()
	var data: Dictionary = JSON.parse_string(src)
	data["movement"]["trail_speed_tiles"] = 9.0
	data["energy"]["walk_per_step"] = 3.0
	f = FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	t.equal(s.speed_tiles_per_second(), before, "no change before reloading")
	t.check(s.debug_reload_tuning(), "reloaded")
	t.near(s.speed_tiles_per_second(), before * 2.0, 0.001, "speed doubled after reload")
	t.equal(s.needs.walk_cost({"walked": true, "weather": s.weather_row()}), 3.0, "walking cost changed after reload")
	DirAccess.remove_absolute(TMP)


func test_debug_actions(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_set_time(15 * 60)
	t.equal(s.clock.minute, 900, "set time")
	s.debug_skip_block()
	t.equal(s.clock.minute, 1080, "skip to next block")
	var d := s.clock.day
	s.debug_skip_day()
	t.equal(s.clock.day, d + 1, "skip day")
	s.debug_skip_season()
	t.equal(s.clock.season, 1, "skip season")
	s.debug_fast(true)
	t.equal(s.clock.speed_multiplier, 10.0, "clock x10")
	s.debug_set_time(600)
	s.process(7.0)
	t.equal(s.clock.minute, 600 + 100, "ten steps in 7 real seconds at x10")
	s.debug_fast(false)
	s.debug_force_weather("storm")
	t.equal(s.current_weather(), "storm", "force weather")
	s.debug_set_next_weather("snow")
	t.equal(s.weather.next_weather(s.clock.minute), "snow", "set next block")
	s.debug_set_needs(12, 34)
	t.equal(s.needs.energy, 12.0, "set energy")
	t.equal(s.needs.warmth, 34.0, "set warmth")
	s.debug_drain(false, false)
	s.clock.advance_step()
	t.equal(s.needs.warmth, 34.0, "drain off")
	for spot in ["station", "fork", "outlook", "cabin"]:
		s.debug_teleport(spot)
		t.equal(s.outdoor_pos, s.world.spawn(spot), "teleport to %s" % spot)
	s.debug_add_item("roofing", 3)
	t.equal(s.backpack.count("roofing"), 3, "add item")
	s.debug_cabin_step("roof", true)
	t.check(s.structures.step_done("test_cabin", "roof"), "complete step")
	s.debug_cabin_step("roof", false)
	t.check(not s.structures.step_done("test_cabin", "roof"), "undo step")
	s.debug_overlay = true
	t.check(s.debug_overlay, "overlay flag")
