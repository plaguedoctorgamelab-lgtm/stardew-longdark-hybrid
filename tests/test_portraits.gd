extends RefCounted
## Phase 4: Mark's portraits in the talk box.


func test_portraits_are_drawn(t: TestCase) -> void:
	var s := TestCase.new_session()
	for r: Dictionary in s.content.rows("townsfolk"):
		var id := str(r["id"])
		if id == "wren":
			continue   # her portrait waits for a redraw: the talk box shows her sprite's face
		for mood: String in ["neutral", "happy", "sad", "surprised"]:
			var pic := "portrait_%s_%s" % [id, mood]
			t.check(Art.has_picture(pic) and Art.texture(pic).get_size() == Vector2(64, 64), "%s is a 64 x 64 portrait" % pic)


func test_a_line_picks_a_mood(t: TestCase) -> void:
	t.equal(Town.mood_of({}, true), "happy", "glad to meet the ranger")
	t.equal(Town.mood_of({"min_hearts": 4}, false), "happy", "a friendship line")
	t.equal(Town.mood_of({"event": "site:old_cabin"}, false), "surprised", "news from the park")
	t.equal(Town.mood_of({}, false), "neutral", "otherwise as they are")
	var s := TestCase.new_session()
	var talk := s.town.talk("gus")
	t.equal(str(talk["mood"]), "happy", "the first talk with Gus is a happy one")
