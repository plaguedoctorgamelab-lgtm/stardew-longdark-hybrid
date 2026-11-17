extends RefCounted
## The park poster look's screens (0.4.5): the title sign's words, the kit
## theme, the poster map's words, and the Badges page, which never says what
## earns a strange badge.


func test_title_words_are_in_the_text_table(t: TestCase) -> void:
	var c := ContentDB.new()
	t.equal(c.text("title_park"), "Dusk River Park", "the park is Dusk River Park")
	for id in ["title_game", "title_welcome", "title_tagline", "map_legend", "map_poster_subtitle"]:
		t.check(c.has("text", id), "%s is in the text table" % id)


func test_kit_theme_styles_every_screen(t: TestCase) -> void:
	var th := KitStyle.theme()
	var panel := th.get_stylebox("panel", "Panel")
	if Art.has_picture("ui_paper"):
		t.check(panel is StyleBoxTexture and (panel as StyleBoxTexture).texture == Art.texture("ui_paper"), "panels are Mark's paper")
	else:
		t.check(panel is StyleBoxFlat, "panels are paper")
	for name in ["ui_paper", "ui_button_normal", "ui_button_hover", "ui_button_pressed", "ui_tab_open", "ui_tab", "ui_tag", "ui_clock_sign", "ui_wallet", "ui_peg", "ui_peg_held",
			"title_sign", "title_emblem", "title_logo", "title_plank", "map_compass", "map_paper", "badge_locked", "badge_strange_17", "badge_spec_seeker", "badge_foraging_4"]:
		t.check(Art.has_picture(name), "%s is in" % name)
	for state in ["normal", "hover", "pressed", "disabled"]:
		t.check(th.has_stylebox(state, "Button"), "buttons have a %s plank" % state)
	t.check(th.get_color("font_color", "Label") == KitStyle.TEXT_DARK, "text on paper is dark")


func test_badges_follow_progress_and_keep_secrets(t: TestCase) -> void:
	var s := TestCase.new_session()
	var v := BadgesView.new()
	v.setup(s, 360)
	v.size = Vector2(360, 300)
	v._draw()
	var locked := s.content.text("badge_locked")
	var tips: Array = v._spots.map(func(sp: Array) -> String: return sp[1])
	t.check(tips.all(func(x: String) -> bool: return x.contains(locked) or x == s.content.text("badge_strange_hidden")), "a new ranger has earned nothing")
	s.debug_set_skill("trailcraft", 3)
	s.finds_found["glowcap"] = true
	v._draw()
	tips = v._spots.map(func(sp: Array) -> String: return sp[1])
	t.equal(tips.filter(func(x: String) -> bool: return x.begins_with(s.content.text("skill_trailcraft")) and not x.contains(locked)).size(), 2, "Trailcraft 2 and 3 patches earned")
	t.check(tips.has(s.content.text("badge_strange_found", {"n": 1})), "a strange badge for the glowcap, numbered")
	for f: Dictionary in s.content.rows("spoiler_finds"):
		for x: String in tips:
			t.check(not x.contains(str(f["id"])), "no badge names a hidden find")
	v.free()
