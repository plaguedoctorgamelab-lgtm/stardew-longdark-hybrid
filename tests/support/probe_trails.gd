extends SceneTree
## Lab probe for tracker #19, #23, #24 (signs) and #25: digs the job gaps the
## way a player would (around snags and brush), puts up signs and the cairn,
## and prints every trail job's steps. Not part of the automated tests.
##   godot --headless --path . -s tests/support/probe_trails.gd


func _initialize() -> void:
	var s := GameSession.new()
	s.save_path = "user://probe_save2.json"
	s.new_game(777)
	s.debug_reveal_map()
	for id in ["station_papers", "station_shelf", "station_boots"]:
		s.jobs.work_spot(id)
	s.backpack.add("axe")
	s.jobs.work_spot("station_branch")
	s.jobs.work_spot("station_can")
	var m := Vector2i(s.jobs.spot_pos("gate_marker"))
	s.park.put_thing(m, "trash_can")
	s.jobs.update(true)
	for site in ["old_cabin", "outlook"]:
		s.debug_open_site(site)
	s.jobs.update(true)
	_show(s, "after cabin+outlook")
	# Clear what the pond trail job asks for, then dig each gap.
	_clear_step(s, "reopen_pond_trail", 1)
	for gname in ["pond_gap_1", "pond_gap_2"]:
		_dig_gap(s, gname)
	s.jobs.update(true)
	_show(s, "pond gaps dug")
	s._reach_cache.clear()
	var sp := Vector2i(s.site_door("kettle_pond"))
	for dy in range(-4, 6):
		var row := ""
		for dx in range(-5, 6):
			var t := sp + Vector2i(dx, dy)
			var g := s.world.ground_at(t)
			var ch := g.substr(0, 1)
			if s.world.object_at(t) != "":
				ch = "O"
			elif s.world.is_solid(t):
				ch = "#"
			if t == sp:
				ch = "@"
			row += ch
		print("   ", row)
	print("pond reached from station: ", s.site_reached("kettle_pond"), " joined cabin->pond: ", s.trail_reach_near(s.site_door("old_cabin"), s.site_door("kettle_pond"), 3))
	var ra := s._trail_reach_from(_near_trail(s, s.site_door("old_cabin")))
	var rb := s._trail_reach_from(_near_trail(s, s.site_door("kettle_pond")))
	var best := 99999.0
	var pa := Vector2i.ZERO
	var pb := Vector2i.ZERO
	for x: Vector2i in rb:
		for y: Vector2i in ra:
			var dd := Vector2(x).distance_to(Vector2(y))
			if dd < best:
				best = dd
				pa = y
				pb = x
	print("cabin reach ", ra.size(), " pond reach ", rb.size(), " closest ", pa, " - ", pb, " d=", best)
	var line := ""
	for i in 12:
		var t := Vector2i(Vector2(pa).lerp(Vector2(pb), i / 11.0).round())
		line += "%s:%s%s " % [t, s.world.ground_at(t), "#" if s.world.is_solid(t) else ""]
	print(line)
	for gname in ["pond_gap_1", "pond_gap_2"]:
		var gp := s.jobs.gap(gname)
		var a := Vector2i(int(gp["a"][0]), int(gp["a"][1]))
		var b := Vector2i(int(gp["b"][0]), int(gp["b"][1]))
		print(gname, " a in cabin ", ra.has(a), " in pond ", rb.has(a), " | b in cabin ", ra.has(b), " in pond ", rb.has(b), " a ground ", s.world.ground_at(a), " b ground ", s.world.ground_at(b))
	var r1 := s._trail_reach_from(Vector2i(int(s.jobs.gap("pond_gap_1")["b"][0]), int(s.jobs.gap("pond_gap_1")["b"][1])))
	var g2a := Vector2i(int(s.jobs.gap("pond_gap_2")["a"][0]), int(s.jobs.gap("pond_gap_2")["a"][1]))
	print("from gap1 b reach ", r1.size(), " has gap2 a ", r1.has(g2a))
	var near := 9999.0
	var nt := Vector2i.ZERO
	for x: Vector2i in r1:
		var dd := Vector2(x).distance_to(Vector2(g2a))
		if dd < near:
			near = dd
			nt = x
	print("closest of gap1b-net to gap2a: ", nt, " d=", near)
	var g2b := Vector2i(int(s.jobs.gap("pond_gap_2")["b"][0]), int(s.jobs.gap("pond_gap_2")["b"][1]))
	near = 9999.0
	for x: Vector2i in rb:
		var dd := Vector2(x).distance_to(Vector2(g2b))
		if dd < near:
			near = dd
			nt = x
	print("closest of pond-net to gap2b: ", nt, " d=", near, " pond door ", s.site_door("kettle_pond"))
	s.debug_open_site("kettle_pond")
	s.jobs.update(true)
	_clear_step(s, "stake_west", 1)
	_clear_step(s, "stake_east", 1)
	for gname in ["stake_gap_west", "stake_gap_east"]:
		_dig_gap(s, gname)
	s.jobs.update(true)
	_show(s, "stake gaps dug")
	s._reach_cache.clear()
	_diag(s, "pond->mid", s.site_door("kettle_pond"), s.jobs._point("stake_mid", 0))
	_diag(s, "mid->tower", s.jobs._point("stake_mid", 0), s.site_door("static_tower"))
	# The cairn by the middle stake.
	var ms := s.jobs.spot_pos("middle_stake")
	print("middle stake at ", ms, " shown ", s.jobs.spot_shown("middle_stake"))
	s.backpack.add("cairn", 1)
	s.backpack.add("hammer", 1)
	var put := false
	for r in range(1, 4):
		for d: Vector2i in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
			var t := Vector2i(ms) + d
			if not put and s.place_problem(t, "cairn") == "":
				put = s.debug_put_up(t, "cairn", "")
				print("cairn at ", t, " ok ", put)
	s.jobs.update(true)
	_show(s, "cairn up")
	# X at the pond's cairn, with forage around it, as a player would.
	var lmo := s.world.interactive_near(s.site_door("kettle_pond"), 8.0)
	print("near pond: ", lmo)
	s.map.mapped_landmarks.erase("kettle_pond")
	print("pond mapped before X: ", s.map.is_landmark_mapped("kettle_pond"))
	if not lmo.is_empty():
		var p0: Vector2 = lmo["pos"]
		for off: Vector2 in [Vector2(0, 1.2), Vector2(1.2, 0), Vector2(-1.2, 0), Vector2(0, -1.2)]:
			if not s.world.is_solid(Vector2i(p0 + off)):
				s.outdoor_pos = p0 + off
				break
		s.debug_spawn_forage(Vector2i(s.outdoor_pos) + Vector2i(1, 0), "reeds")
		s.interact()
		print("pond mapped after X: ", s.map.is_landmark_mapped("kettle_pond"), " pending ", s.pending_confirm)
	# A sign naming the pond, put up as a player would: face a tile beside
	# the trail near the pond, use the sign, answer which place.
	s.pending_confirm = ""
	s.backpack.add("trail_sign", 2)
	var target := s.site_door("kettle_pond")
	var done_sign := false
	for r in range(2, 12):
		for dx in range(-r, r + 1):
			if done_sign:
				break
			var t := Vector2i(target) + Vector2i(dx, r)
			if s.place_problem(t, "trail_sign") == "":
				s.outdoor_pos = Vector2(t) + Vector2(0.5, 1.5)
				s.facing = 2
				for i in s.backpack.size():
					if s.backpack.item_at(i) == "trail_sign":
						s.selected_slot = i
				s.use_item()
				print("sign ask: ", s.pending_confirm, " places: ", s.sign_places().map(func(e: Dictionary) -> String: return e["id"]))
				s.answer_choice("sign_place", "kettle_pond")
				done_sign = true
	s.jobs.update(true)
	print("pond signed: ", s.site_signed("kettle_pond"))
	_show(s, "pond sign up")
	s.save_game()
	quit(0)


func _clear_step(s: GameSession, job: String, i: int) -> void:
	if not s.jobs.known.has(job):
		s.jobs.add(job, "given")
	var stp: Dictionary = s.jobs.def(job)["steps"][i]
	var tg := s.jobs._clear_targets(stp)
	for t: Vector2i in tg["tiles"]:
		s.debug_clear_obstacle(t)
	for sp: String in tg["spots"]:
		s.jobs.spots_done[sp] = true
	print("cleared ", job, " ", (tg["tiles"] as Array).size(), " tiles, ", (tg["spots"] as Array).size(), " spots")


func _diag(s: GameSession, what: String, from: Vector2, to: Vector2) -> void:
	var ra := s._trail_reach_from(_near_trail(s, from))
	var best := 99999.0
	var pa := Vector2i.ZERO
	for y: Vector2i in ra:
		var dd := Vector2(y).distance_to(to)
		if dd < best:
			best = dd
			pa = y
	print(what, ": reach ", ra.size(), " nearest to goal ", pa, " d=", snappedf(best, 0.1), " joined=", s.trail_reach_near(from, to, 4))
	if best > 4:
		var line := ""
		for i in 10:
			var t := Vector2i(Vector2(pa).lerp(to, i / 9.0).round())
			line += "%s:%s%s%s " % [t, s.world.ground_at(t), "#" if s.world.is_solid(t) else "", "(" + s.world.object_at(t) + ")" if s.world.object_at(t) != "" else ""]
		print("   ", line)


func _near_trail(s: GameSession, p: Vector2) -> Vector2i:
	var grounds: Array = s.tuning.value("sites.reach_grounds")
	for r in 6:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := Vector2i(p) + Vector2i(dx, dy)
				if grounds.has(s.world.ground_at(t)) and not s.world.is_solid(t):
					return t
	return Vector2i(p)


func _dig_gap(s: GameSession, gname: String) -> void:
	var gp := s.jobs.gap(gname)
	if gp.is_empty():
		print("no gap ", gname)
		return
	var tiles: Array = gp["tiles"]
	var a := Vector2i(int(gp["a"][0]), int(gp["a"][1]))
	var b := Vector2i(int(gp["b"][0]), int(gp["b"][1]))
	var blocked := 0
	for p: Array in tiles:
		var t := Vector2i(int(p[0]), int(p[1]))
		if s.world.is_solid(t) or s.jobs.spot_blocks_dig(t) or s.world.object_at(t) != "":
			blocked += 1
			# Step round: dig the tiles beside it.
			for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, 1)]:
				if not s.world.is_solid(t + d) and s.world.object_at(t + d) == "":
					s.debug_dig(t + d)
			continue
		s.debug_dig(t)
	if not s.trail_joins(a, b, 6):
		# Route round whatever is in the way, the shortest open walk.
		var prev := {a: a}
		var q: Array[Vector2i] = [a]
		var h := 0
		while h < q.size():
			var t := q[h]
			h += 1
			if t == b:
				break
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := t + d
				if prev.has(n) or s.world.is_solid(n) or absi(n.x - a.x) > 30 or absi(n.y - a.y) > 30:
					continue
				prev[n] = t
				q.append(n)
		var why := {}
		for p2: Array in tiles:
			var t2 := Vector2i(int(p2[0]), int(p2[1]))
			if s.world.is_solid(t2):
				why[t2] = "solid:%s:%s" % [s.world.object_at(t2), s.world.ground_at(t2)]
			elif not s.can_dig(t2) and s.world.ground_at(t2) != "trail":
				why[t2] = "cant_dig:%s:%s:%s" % [s.world.object_at(t2), s.world.ground_at(t2), s.jobs.spot_blocks_dig(t2)]
		print("   in the way: ", why)
		if prev.has(b):
			var t3 := b
			while t3 != a:
				s.debug_dig(t3)
				t3 = prev[t3]
		print("   routed: ", prev.has(b))
	print(gname, " a=", a, " b=", b, " tiles=", tiles.size(), " blocked=", blocked, " joins=", s.trail_joins(a, b, 6), " check=", s.jobs._check_dig({"gap": gname}))


func _show(s: GameSession, when: String) -> void:
	print("== ", when)
	for k: String in s.jobs.order:
		if not s.jobs.is_active(k) and not s.jobs.is_done(k):
			continue
		var d := s.jobs.def(k)
		var line := "%s %s:" % [k, "DONE" if s.jobs.is_done(k) else ""]
		for i in (d["steps"] as Array).size():
			line += " %d%s" % [i, "+" if bool(s.jobs.check(k, i)["done"]) else "-"]
		print("  ", line)
