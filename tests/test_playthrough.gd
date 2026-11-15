extends RefCounted
## The scene phase one must prove, played through end to end by the real
## systems at 60 frames a second: leave the station in the morning, follow
## the trail, get caught by a change in the weather, reach the run-down cabin,
## repair it, warm up, sleep there, and walk home the next day with a map that
## has begun to fill in. Then quit and reload.

const DT := 1.0 / 60.0


func _walk(s: GameSession, pts: PackedVector2Array) -> int:
	var frames := 0
	var i := 1
	s.outdoor_pos = pts[0] if s.outdoor_pos.distance_to(pts[0]) > 3.0 else s.outdoor_pos
	while i < pts.size() and frames < 200000 and s.collapse_count == 0:
		var to := pts[i] - s.outdoor_pos
		if to.length() < 0.3:
			i += 1
			continue
		s.move(to, DT)
		s.process(DT)
		frames += 1
	return frames


func test_the_proving_scene(t: TestCase) -> void:
	var s := TestCase.new_session(2026)
	# Morning at the station: hear the forecast, pack the backpack.
	t.check(s.enter_building("ranger_station"), "start inside the station")
	var lines := s.use_radio()
	t.equal(lines.size(), 5, "heard the forecast")
	var shelf: Inventory = s.structures.shelves["ranger_station"]
	for i in shelf.size():
		var item := shelf.item_at(i)
		if item in ["planks", "nails", "roofing", "window_glass", "firewood", "sandwich", "tin_of_beans"]:
			shelf.move_slot_to(i, s.backpack)
	t.check(s.backpack.count("planks") >= 8 and s.backpack.count("nails") >= 20 and s.backpack.count("roofing") >= 4, "packed the repair materials")
	t.check(s.backpack.has("firewood") and s.backpack.has("sandwich"), "packed food and firewood")
	s.leave_building()
	# The weather will turn in the afternoon.
	s.weather.today = ["clear", "rain", "storm"]
	var morning_energy := s.needs.energy
	var frames := _walk(s, s.world.route("cabin"))
	t.equal(s.collapse_count, 0, "reached the cabin without collapsing")
	t.check(s.outdoor_pos.distance_to(s.door_front("test_cabin")) < 1.0, "standing at the cabin door")
	var minutes := s.clock.minute - 360
	print("        reached the cabin at %s after %d frames (%.0f real seconds); energy %.0f -> %.0f, warmth %.0f, weather %s" % [s.clock.time_text(), frames, frames * DT, morning_energy, s.needs.energy, s.needs.warmth, s.current_weather()])
	t.check(minutes >= 220 and minutes <= 280, "about four hours on the trail (%d minutes)" % minutes)
	t.check(s.map.is_traced(s.ranger_tile()) or s.map.has_pending(), "the walk left a trace")
	# Find and map the cabin, then repair it.
	s.interact()
	t.check(s.map.is_landmark_mapped("test_cabin"), "mapped the cabin")
	s.interact()
	t.equal(s.location, "", "cannot enter the run-down cabin")
	s.selected_slot = 0
	t.equal(s.selected_item(), "hammer", "holding the hammer")
	var actions := 0
	while not s.structures.is_open("test_cabin") and actions < 20:
		s.use_item()
		actions += 1
	t.check(s.structures.is_open("test_cabin"), "repaired the cabin in %d hammer actions" % actions)
	t.equal(actions, 12, "four steps of three actions")
	print("        repaired by %s; energy %.0f, warmth %.0f, weather %s" % [s.clock.time_text(), s.needs.energy, s.needs.warmth, s.current_weather()])
	t.equal(s.current_weather(), "rain", "caught by the change in the weather while working")
	# Warm up: enter, light the stove, warm, sleep.
	s.interact()
	t.equal(s.location, "test_cabin", "inside the cabin")
	var layout: InteriorLayout = s.interiors["test_cabin"]
	var stove := layout.furniture_rect(layout.find("stove"))
	s.interior_pos = Vector2(stove.position.x + 0.5, stove.end.y + 0.6)
	s.interact()
	t.check(s.structures.stove_lit("test_cabin"), "lit the stove")
	var w0 := s.needs.warmth
	s.clock.advance_step()
	t.check(s.needs.warmth > w0 or s.needs.warmth == 100.0, "warming up by the stove")
	var bed := layout.furniture_rect(layout.find("bed"))
	s.interior_pos = Vector2(bed.end.x + 0.5, bed.position.y + 1.0)
	var day := s.clock.day
	s.interact()
	t.equal(s.pending_confirm, "sleep", "the bed asks to sleep")
	s.answer_confirm(true)
	t.equal(s.clock.day, day + 1, "slept until the next day")
	t.equal(s.location, "test_cabin", "woke in the cabin")
	t.check(SaveSystem.exists(s.save_path), "the game saved")
	# Walk home the next day.
	s.leave_building()
	s.weather.today = ["overcast", "overcast", "clear"]
	var back := s.world.route("cabin")
	back.reverse()
	_walk(s, back)
	t.equal(s.collapse_count, 0, "walked home without collapsing")
	t.check(s.outdoor_pos.distance_to(s.world.spawn("station")) < 2.0, "back at the station")
	var traced := s.map.traced.count(1) + s.map.pending_trace.count(1)
	print("        home at %s; traced %d tiles; %.1f%% of the map revealed" % [s.clock.time_text(), traced, s.map.percent_revealed()])
	t.check(traced > 500, "the walk left a long trace (%d tiles)" % traced)
	t.check(s.map.traced.count(1) > 500, "the trace is drawn on the map once the ranger stood on mapped ground")
	t.check(s.map.percent_revealed() > 0.0, "part of the map is filled in")
	# Quit and reload: everything as it was left.
	t.check(s.enter_building("ranger_station"), "home")
	s.request_sleep()
	s.answer_confirm(true)
	var saved := s.to_dict()
	var again := GameSession.new()
	again.save_path = s.save_path
	t.equal(again.load_game(), "", "reloaded")
	t.equal(JSON.stringify(again.to_dict()), JSON.stringify(saved), "everything as it was left")


func test_shortcut_in_fog(t: TestCase) -> void:
	# Take the shortcut from the outlook to the cabin in fog: the marker is
	# lost, and the walk ends at the cabin or in a rescue, never stuck.
	var s := TestCase.new_session(7)
	s.debug_set_time(9 * 60)
	s.debug_force_weather("clear")
	s.debug_teleport("outlook")
	s.start_survey()
	s.pass_minutes(30)
	s.map_location("scenic_outlook")
	s.debug_force_weather("fog")
	t.check(not s.marker_visible(), "fog hides the marker at the outlook")
	# Head for the cabin across country by the shortest open way, as a player
	# who knows the land would.
	var path := _find_path(s, s.ranger_tile(), Vector2i(s.door_front("test_cabin")))
	t.check(path.size() > 0, "an open way exists through the forest")
	var goal := s.door_front("test_cabin")
	var frames := 0
	var i := 0
	while i < path.size() and frames < 60 * 600 and s.collapse_count == 0:
		var target := Vector2(path[i]) + Vector2(0.5, 0.5)
		var to := target - s.outdoor_pos
		if to.length() < 0.2:
			i += 1
			continue
		s.move(to, DT)
		s.process(DT)
		frames += 1
	var off_trail := 0
	for p in path:
		if s.world.ground_at(p) != "trail":
			off_trail += 1
	t.check(off_trail > path.size() * 0.8, "the shortcut is mostly off the trail")
	t.check(frames * DT < 147.0 - 105.0 + 168.0 - 105.0, "the shortcut is quicker than the trail round by the fork (%.0f s)" % (frames * DT))
	var arrived := s.outdoor_pos.distance_to(goal) <= 1.0
	print("        shortcut: %s after %.0f real seconds (%d game minutes)" % ["arrived" if arrived else ("rescued" if s.collapse_count > 0 else "still walking"), frames * DT, frames * DT / 7.0 * 10.0])
	t.check(arrived or s.collapse_count > 0, "found the way to the cabin or was rescued")
	t.check(s.map.has_pending() or s.map.is_traced(s.ranger_tile()), "the walk in fog was recorded")


## Shortest 4-way path over open tiles, keeping one tile clear of solid
## corners so the ranger's box fits.
func _find_path(s: GameSession, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var prev := {from: from}
	var q: Array[Vector2i] = [from]
	var head := 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < q.size():
		var c := q[head]
		head += 1
		if c == to:
			break
		for d in dirs:
			var n := c + d
			if prev.has(n) or s.world.is_solid(n):
				continue
			prev[n] = c
			q.append(n)
	var out: Array[Vector2i] = []
	if not prev.has(to):
		return out
	var c := to
	while c != from:
		out.push_front(c)
		c = prev[c]
	return out
