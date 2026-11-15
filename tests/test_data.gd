extends RefCounted
## Data: every content table and the tuning file load; ids are unique;
## references resolve. (The Python data check covers the same ground from
## outside the game; this proves the game itself reads them.)


func test_tables_load(t: TestCase) -> void:
	var c := ContentDB.new()
	t.check(c.errors.is_empty(), "content loads without errors: %s" % [c.errors])
	for table in ContentDB.TABLES:
		t.check(c.rows(table).size() > 0, "table %s has rows" % table)


func test_tuning_loads(t: TestCase) -> void:
	var tun := Tuning.new()
	t.check(not tun.data.is_empty(), "tuning file loads")
	t.equal(tun.num("energy.max"), 270.0, "energy max")
	t.equal(tun.num("time.real_seconds_per_step"), 7.0, "seconds per step")


func test_ids_unique(t: TestCase) -> void:
	var c := ContentDB.new()
	for table in ContentDB.TABLES:
		var seen := {}
		for r: Dictionary in c.rows(table):
			t.check(not seen.has(r["id"]), "%s id %s unique" % [table, r["id"]])
			seen[r["id"]] = true


func test_references_resolve(t: TestCase) -> void:
	var c := ContentDB.new()
	for r: Dictionary in c.rows("items"):
		t.check(c.has("text", r["name"]), "item %s name text" % r["id"])
	for r: Dictionary in c.rows("foods"):
		t.check(c.has("items", r["item"]), "food %s item" % r["id"])
	for r: Dictionary in c.rows("weather_types"):
		t.check(c.has("text", r["name"]), "weather %s name text" % r["id"])
	for r: Dictionary in c.rows("weather_odds"):
		for w: String in r["odds"]:
			t.check(c.has("weather_types", w), "odds %s weather %s" % [r["id"], w])
	for r: Dictionary in c.rows("structures"):
		t.check(c.has("text", r["name"]), "structure %s name" % r["id"])
		for st: Dictionary in r["repair_steps"]:
			t.check(c.has("text", st["name"]), "step %s name" % st["id"])
			for m: String in st["materials"]:
				t.check(c.has("items", m), "step %s material %s" % [st["id"], m])
		for s: Dictionary in r["shelf_stock"]:
			t.check(c.has("items", s["item"]), "shelf item %s" % s["item"])
		for s: Dictionary in r["found_supplies"]:
			t.check(c.has("items", s["item"]), "supply item %s" % s["item"])
	for r: Dictionary in c.rows("landmarks"):
		t.check(c.has("text", r["name"]), "landmark %s name" % r["id"])


func test_every_picture_exists(t: TestCase) -> void:
	var c := ContentDB.new()
	var w := WorldData.new()
	var names: Array[String] = ["ranger", "interior_floor", "interior_wall", "furniture_stove_lit", "obj_stump", "obj_campfire", "obj_firepit", "obj_camp_bedroll"]
	for r: Dictionary in c.rows("items"):
		names.append(r["icon"])
		if r.has("sprite"):
			names.append(r["sprite"])
	for r: Dictionary in c.rows("weather_types"):
		names.append(r["icon"])
		if r.has("night_icon"):
			names.append(r["night_icon"])
	for r: Dictionary in c.rows("structures"):
		names.append(r["sprite"])
		names.append(r["sprite_repaired"])
		for f: Dictionary in r["interior"]["furniture"]:
			names.append(f["sprite"])
	for k: String in w.meta["object_types"]:
		names.append(w.meta["object_types"][k]["sprite"])
	for g: String in w.ground_codes.values():
		names.append("ground_" + g)
	for n in names:
		t.check(ResourceLoader.exists(Art.PLACEHOLDER_DIR + n + ".png"), "placeholder exists for %s" % n)
