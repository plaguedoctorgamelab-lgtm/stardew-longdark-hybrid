extends RefCounted
## The tracker items fixed in 0.6.1: #26 the pond could never be found (its
## landmark is mid-water, out of reach of any shore) and the burn's brush was
## hard to tell from its bushes; #27 the station and tower insides were
## crowded, with pieces overlapping.


func test_every_site_is_found_from_its_door(t: TestCase) -> void:
	var s := TestCase.new_session()
	for row: Dictionary in s.content.rows("sites"):
		var id := str(row["id"])
		var door := s.site_door(id)
		t.check(not s.world.is_solid(Vector2i(door)), "%s: its door is open ground" % id)
		s.outdoor_pos = door
		s._look_for_sites()
		t.check(s.sites_found.has(id), "%s: standing at its door finds it" % id)


func test_the_pond_is_found_from_its_shore(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.jobs.add("open_pond", "debug")
	s.outdoor_pos = s.site_door("kettle_pond")
	s._look_for_sites()
	var d := s.jobs.def("open_pond")
	t.check(bool(s.jobs.check("open_pond", 0)["done"]), "Open Kettle Pond's 'Find the pond' ticks at the shore")
	t.equal(str(d["steps"][0]["kind"]), "find", "the first step is the find")


func test_brush_a_job_wants_cleared_is_marked(t: TestCase) -> void:
	var s := TestCase.new_session()
	var before := s.jobs.clear_marks().size()
	s.jobs.add("stake_west", "debug")
	var marks := s.jobs.clear_marks()
	t.equal(marks.size(), before + 3, "the west gap's three brush are marked")
	var tg: Dictionary = s.jobs._clear_targets(s.jobs.def("stake_west")["steps"][1])
	var first: Vector2i = tg["tiles"][0]
	s.cleared[first] = true
	s.world._cleared[first] = true
	t.equal(s.jobs.clear_marks().size(), before + 2, "a cleared one loses its mark")


func _pieces(s: GameSession, id: String) -> Array:
	var inside: Dictionary = s.content.row("structures", id)["interior"]
	var out := []
	for f: Dictionary in inside["furniture"]:
		if str(f["kind"]) != "exit":
			out.append({"id": f["id"], "use": str(f["kind"]) != "decor", "front": not str(f["kind"]) in ["decor", "chest"], "r": Rect2i(int(f["pos"][0]), int(f["pos"][1]), int(f["size"][0]), int(f["size"][1]))})
	for sp: String in s.jobs.spot_ids():
		var r: Dictionary = s.jobs.spot_row(sp)
		if str(r["where"]) == id and r.has("pos"):
			out.append({"id": sp, "use": true, "r": Rect2i(int(r["pos"][0]), int(r["pos"][1]), int(r["size"][0]), int(r["size"][1]))})
	if inside.has("kit_spot"):
		var k: Dictionary = inside["kit_spot"]
		out.append({"id": "kit_spot", "use": true, "r": Rect2i(int(k["pos"][0]), int(k["pos"][1]), int(k["size"][0]), int(k["size"][1]))})
	return out


func test_insides_have_room_between_pieces(t: TestCase) -> void:
	var s := TestCase.new_session()
	for row: Dictionary in s.content.rows("structures"):
		if not row.has("interior"):
			continue
		var id := str(row["id"])
		var inside: Dictionary = row["interior"]
		var pieces := _pieces(s, id)
		var entry := Vector2i(int(inside["entry"][0]), int(inside["entry"][1]))
		for i in pieces.size():
			var a: Rect2i = pieces[i]["r"]
			t.check(not a.has_point(entry), "%s: %s keeps off the doorway" % [id, pieces[i]["id"]])
			for j in range(i + 1, pieces.size()):
				t.check(not a.intersects(pieces[j]["r"]), "%s: %s and %s don't overlap" % [id, pieces[i]["id"], pieces[j]["id"]])
			for rug: Dictionary in inside.get("rugs", []):
				var tex := Art.texture(str(rug["sprite"]))
				var rr := Rect2i(int(rug["pos"][0]), int(rug["pos"][1]), tex.get_width() / 16, tex.get_height() / 16)
				if rr.has_point(entry):
					continue
				t.check(not a.intersects(rr), "%s: nothing stands on the rug (%s)" % [id, pieces[i]["id"]])
		# Every piece that does something can be walked up to from the door.
		var solid := {}
		for p: Dictionary in pieces:
			var r: Rect2i = p["r"]
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					solid[Vector2i(x, y)] = true
		var wh := int(inside.get("wall_height", 1))
		var sz := Vector2i(int(inside["size"][0]), int(inside["size"][1]))
		var seen := {entry: true}
		var q: Array[Vector2i] = [entry]
		var h := 0
		while h < q.size():
			var c := q[h]
			h += 1
			for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + dv
				if seen.has(n) or solid.has(n) or n.x <= 0 or n.y < wh or n.x >= sz.x - 1 or n.y >= sz.y - 1:
					continue
				seen[n] = true
				q.append(n)
		for p: Dictionary in pieces:
			if not bool(p["use"]):
				continue
			var r: Rect2i = p["r"]
			var near := false
			for y in range(r.position.y - 1, r.end.y + 1):
				for x in range(r.position.x - 1, r.end.x + 1):
					if seen.has(Vector2i(x, y)):
						near = true
			t.check(near, "%s: %s can be walked up to" % [id, p["id"]])
			# Faced from below, the way the ranger walks up to things.
			if bool(p.get("front", false)):
				t.check(seen.has(Vector2i(r.position.x, r.end.y)), "%s: the tile in front of %s is free" % [id, p["id"]])
