extends RefCounted
## Mark's music and Art Request 16 (21 November 2026): which piece plays when,
## the music setting, every music file loading, and the new pictures in use.


func test_each_moment_has_its_piece(t: TestCase) -> void:
	var s := TestCase.new_session()
	var rows := s.content.rows("music")
	t.equal(Music.pick(rows, true, "", false, false), "title", "the title screen")
	t.equal(Music.pick(rows, false, "spring", false, false), "outdoors", "a spring day outdoors")
	t.equal(Music.pick(rows, false, "summer", false, true), "indoors", "indoors")
	t.equal(Music.pick(rows, false, "autumn", true, false), "night", "an autumn night outdoors")
	t.equal(Music.pick(rows, false, "autumn", true, true), "indoors", "an autumn night indoors")
	t.equal(Music.pick(rows, false, "winter", false, false), "winter", "a winter day")
	t.equal(Music.pick(rows, false, "winter", false, true), "winter", "winter indoors")


func test_every_music_file_loads(t: TestCase) -> void:
	var s := TestCase.new_session()
	for r: Dictionary in s.content.rows("music"):
		var f := str(r["file"])
		t.check(ResourceLoader.exists(f) and load(f) is AudioStream, "%s loads as sound" % f)


func test_the_music_setting_cycles_and_off_is_silent(t: TestCase) -> void:
	var s := TestCase.new_session()
	var m := Music.new()
	m.setup(s.content, s.tuning)
	var start := Settings.music()
	var seen: Array[String] = []
	for i in Settings.MUSIC.size():
		seen.append(Settings.next_music())
	t.equal(Settings.music(), start, "four presses come back round")
	t.check(seen.has("off") and seen.has("low") and seen.has("high"), "off, quiet and loud are all offered")
	while Settings.music() != "off":
		Settings.next_music()
	t.check(m.volume_db() <= -79.0, "off is silent")
	while Settings.music() != start:
		Settings.next_music()
	m.free()


func test_the_new_pictures_are_in_use(t: TestCase) -> void:
	var s := TestCase.new_session()
	for n in ["item_sticks", "item_true_compass", "furniture_trunk", "furniture_bunk_bed", "obj_tree_birch", "obj_tree_pine_alt_3", "ground_grass_plain", "ui_wood_frame", "ui_tab_backpack"]:
		t.check(ResourceLoader.exists("res://art/final/%s.png" % n), "%s is finished art" % n)
	var grass := s.content.row("art_variety", "ground_grass")
	t.equal(str(grass["pictures"][0]), "ground_grass_plain", "the plain grass leads the mix")
	var oak := s.content.row("art_variety", "obj_tree_oak")
	t.check((oak["pictures"] as Array).has("obj_tree_maple") and (oak["pictures"] as Array).has("obj_tree_birch"), "maple and birch grow among the oaks")
