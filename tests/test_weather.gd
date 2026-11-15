extends RefCounted
## Weather: over 10,000 simulated blocks per season, each weather's share is
## within 3 points of its odds; winter has no rain or storm; forecasts are
## right 85% of the time, within 3 points. Also the warning before a change.


func test_shares_match_odds(t: TestCase) -> void:
	var tun := Tuning.new()
	var c := ContentDB.new()
	var w := WeatherSystem.new(tun, c)
	for season: String in GameClock.SEASONS:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(season)
		var counts := {}
		var last := ""
		var n := 10000
		for i in n:
			last = w.next_block(last, season, 14, rng)
			counts[last] = int(counts.get(last, 0)) + 1
		var odds := w.odds(season)
		for id: String in odds:
			var share := 100.0 * float(counts.get(id, 0)) / n
			t.near(share, float(odds[id]), 3.0, "%s share of %s" % [season, id])


func test_winter_has_no_rain_or_storm(t: TestCase) -> void:
	var w := WeatherSystem.new(Tuning.new(), ContentDB.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var last := "rain"   # even starting from rain, winter must not keep it
	for day in range(1, 29):
		for i in 400:
			last = w.next_block(last, "winter", day, rng)
			if last in ["rain", "storm"]:
				t.check(false, "winter block is %s" % last)
	# Whole days, generated as the game makes them.
	w.new_game(5, 0)
	for d in range(84, 112):
		var blocks := w.generate_day(d, "rain")
		for b in blocks:
			if b in ["rain", "storm"]:
				t.check(false, "winter day %d has %s" % [d, b])


func test_snow_only_in_winter_and_shoulders(t: TestCase) -> void:
	var w := WeatherSystem.new(Tuning.new(), ContentDB.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var counts := {"summer": 0, "mid_autumn": 0, "late_autumn": 0, "early_spring": 0}
	for i in 4000:
		if w.draw("summer", 10, rng) in ["snow", "blizzard"]:
			counts["summer"] += 1
		if w.draw("autumn", 10, rng) in ["snow", "blizzard"]:
			counts["mid_autumn"] += 1
		if w.draw("autumn", 26, rng) == "snow":
			counts["late_autumn"] += 1
		if w.draw("spring", 3, rng) == "snow":
			counts["early_spring"] += 1
	t.equal(counts["summer"], 0, "no snow in summer")
	t.equal(counts["mid_autumn"], 0, "no snow in mid autumn")
	# Half of the 20% rain falls as snow: about 10%.
	t.near(100.0 * counts["late_autumn"] / 4000.0, 10.0, 2.5, "late autumn snow share")
	t.near(100.0 * counts["early_spring"] / 4000.0, 10.0, 2.5, "early spring snow share")


func test_forecast_accuracy(t: TestCase) -> void:
	var w := WeatherSystem.new(Tuning.new(), ContentDB.new())
	w.new_game(77, 0)
	var right := 0
	var total := 0
	for d in 4000:
		w.today = w.generate_day(d, "")
		w.tomorrow = w.generate_day(d + 1, w.today[2])
		var fc := w.forecast(d)
		for i in 3:
			total += 1
			if fc["blocks"][i] == w.today[i]:
				right += 1
	t.near(100.0 * right / total, 85.0, 3.0, "forecast blocks right")


func test_forecast_is_stable_within_a_day(t: TestCase) -> void:
	var s := TestCase.new_session()
	var a := s.use_radio()
	var b := s.use_radio()
	t.equal(a, b, "asking twice gives the same forecast")
	t.equal(a.size(), 5, "header, three blocks and tomorrow")


func test_effects_per_weather(t: TestCase) -> void:
	var s := TestCase.new_session()
	var fx := ScreenEffects.new()
	fx.session = s
	s.debug_set_time(12 * 60)
	for w: String in s.content.ids("weather_types"):
		s.debug_force_weather(w)
		var row := s.weather_row()
		t.equal(fx.visibility_tiles(), float(row["visibility_tiles"]), "%s sight" % w)
		t.equal(s.speed_tiles_per_second() > 0.0, true, "%s walking" % w)
	s.debug_force_weather("fog")
	t.equal(fx.visibility_tiles(), 6.0, "fog shrinks sight to 6 tiles")
	s.debug_force_weather("blizzard")
	t.equal(fx.visibility_tiles(), 4.0, "blizzard shrinks sight to 4 tiles")
	s.debug_force_weather("storm")
	var storm_tint := fx.current_tint()
	s.debug_force_weather("clear")
	t.check(storm_tint.v < fx.current_tint().v, "a storm darkens the light")
	fx.free()


func test_warning_before_a_change(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.weather.today = ["clear", "storm", "storm"]
	t.equal(s.weather.warning_amount(10 * 60), 0.0, "no warning two hours ahead")
	t.equal(s.weather.warning_amount(11 * 60 - 10), 0.0, "no warning 70 minutes ahead")
	t.check(s.weather.warning_amount(11 * 60 + 10) > 0.0, "warning within the last hour")
	t.check(s.weather.warning_amount(11 * 60 + 50) > s.weather.warning_amount(11 * 60 + 10), "warning grows")
	s.weather.today = ["clear", "clear", "rain"]
	t.equal(s.weather.warning_amount(11 * 60 + 30), 0.0, "no warning when nothing changes")
	var fx := ScreenEffects.new()
	fx.session = s
	s.debug_set_time(17 * 60 + 30)
	var warn_tint := fx.current_tint()
	s.debug_set_time(16 * 60)
	t.check(not warn_tint.is_equal_approx(fx.current_tint()), "the light shifts before the change")
	fx.free()


func test_weather_changes_at_block_boundaries(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.weather.today = ["clear", "rain", "fog"]
	var seen := []
	s.weather.weather_changed.connect(func(w: String) -> void: seen.append(w))
	s.debug_set_time(11 * 60 + 50)
	s.clock.advance_step()
	t.equal(s.current_weather(), "rain", "afternoon block")
	s.debug_set_time(17 * 60 + 50)
	s.clock.advance_step()
	t.equal(s.current_weather(), "fog", "evening block")
	t.check(seen.has("rain") and seen.has("fog"), "changes are signalled")
