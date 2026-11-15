extends RefCounted
## Performance: the game holds 60 frames per second while walking across the
## whole map. With no window this measures the game's own work each frame
## (moving, the clock, chunk loading and placing tiles), which must fit well
## inside 16.7 ms. Drawing time is checked separately with a window by
## tests/support/perf_window.gd.


func test_walk_whole_map_frame_budget(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_drain(false, false)
	s.debug_force_weather("clear")
	var view := WorldView.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	view.setup(s, RangerSprite.new())
	view.update_chunks(true)
	var route := s.world.route("cabin")
	var dt := 1.0 / 60.0
	var worst := 0.0
	var total := 0.0
	var frames := 0
	var slow := 0
	var i := 1
	while i < route.size():
		var to := route[i] - s.outdoor_pos
		if to.length() < 0.3:
			i += 1
			continue
		var t0 := Time.get_ticks_usec()
		s.move(to, dt)
		s.process(dt)
		view.update_chunks(false)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		worst = maxf(worst, ms)
		total += ms
		frames += 1
		if ms > 16.7:
			slow += 1
	print("        %d frames, average %.2f ms, worst %.2f ms, over budget %d" % [frames, total / frames, worst, slow])
	t.check(total / frames < 4.0, "average frame work %.2f ms" % (total / frames))
	t.check(float(slow) / frames < 0.01, "fewer than 1%% of frames over 16.7 ms (%d)" % slow)
	view.queue_free()
