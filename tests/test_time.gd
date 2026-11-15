extends RefCounted
## Time: a day lasts 120 ten-minute steps; day 28 of winter is followed by
## spring 1 of the next year. Also light and the clock display.


func test_day_has_120_steps(t: TestCase) -> void:
	var tun := Tuning.new()
	var c := GameClock.new(tun)
	var steps := [0]
	c.step_passed.connect(func(_m: int) -> void: steps[0] += 1)
	while not c.is_day_over():
		c.advance_step()
	t.equal(steps[0], 120, "steps in a day")
	t.equal(c.steps_per_day(), 120, "steps_per_day")
	t.equal(c.minute, 1560, "day ends at 2:00")


func test_real_time_per_step(t: TestCase) -> void:
	var c := GameClock.new(Tuning.new())
	c.process(6.9)
	t.equal(c.minute, 360, "no step before 7 s")
	c.process(0.2)
	t.equal(c.minute, 370, "one step after 7 s")
	c.process(7.0 * 119.0)
	t.equal(c.minute, 1560, "a full day is 14 real minutes")
	c.paused = true
	c.minute = 400
	c.process(100.0)
	t.equal(c.minute, 400, "clock stops while paused")


func test_year_wraps(t: TestCase) -> void:
	var c := GameClock.new(Tuning.new())
	c.season = 3
	c.day = 28
	c.year = 1
	var changed := []
	c.season_changed.connect(func(s: int) -> void: changed.append(s))
	c.start_next_day()
	t.equal(c.day, 1, "day")
	t.equal(c.season, 0, "season is spring")
	t.equal(c.year, 2, "year")
	t.equal(changed, [0], "season change signalled")


func test_signals_each_hour_and_day(t: TestCase) -> void:
	var c := GameClock.new(Tuning.new())
	var counts := {"hours": 0, "days": 0}
	c.hour_passed.connect(func(_h: int) -> void: counts["hours"] += 1)
	c.day_started.connect(func(_d: int, _s: int, _y: int) -> void: counts["days"] += 1)
	while not c.is_day_over():
		c.advance_step()
	c.start_next_day()
	t.equal(counts["hours"], 20, "hours from 6:00 to 2:00")
	t.equal(counts["days"], 1, "day signal")


func test_time_text(t: TestCase) -> void:
	var c := GameClock.new(Tuning.new())
	t.equal(c.time_text(), "6:00 am", "start")
	c.minute = 13 * 60 + 30
	t.equal(c.time_text(), "1:30 pm", "afternoon")
	c.minute = 25 * 60 + 10
	t.equal(c.time_text(), "1:10 am", "after midnight")


func test_daylight_by_season(t: TestCase) -> void:
	var tun := Tuning.new()
	t.check(Daylight.is_night(tun, "winter", 7 * 60), "7:00 is dark in winter")
	t.check(not Daylight.is_night(tun, "summer", 6 * 60), "6:00 is light in summer")
	t.check(not Daylight.is_night(tun, "summer", 20 * 60), "20:00 is light in summer")
	t.check(Daylight.is_night(tun, "winter", 18 * 60), "18:00 is dark in winter")
	var noon := Daylight.tint(tun, "spring", 12 * 60)
	var dusk := Daylight.tint(tun, "spring", 19 * 60)
	var night := Daylight.tint(tun, "spring", 23 * 60)
	t.check(noon.is_equal_approx(Color(1, 1, 1)), "midday is plain")
	t.check(dusk.r > dusk.b, "sunset is warm")
	t.check(night.b > night.r and night.v < 0.5, "night is deep blue")
