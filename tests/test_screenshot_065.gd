extends RefCounted
## 0.6.5: F12 saves a screenshot named with the game and the date and time.


func test_names_carry_the_game_and_date(t: TestCase) -> void:
	var when := {"year": 2026, "month": 11, "day": 2, "hour": 9, "minute": 5, "second": 7}
	t.equal(Screenshot.file_name("Strange Ranger", when), "Strange Ranger 2026-11-02 09-05-07.png", "game name, then the date and time")
	t.equal(Screenshot.file_name("Strange Ranger", when, 2), "Strange Ranger 2026-11-02 09-05-07 (2).png", "a second in the same second is numbered")


func test_a_taken_name_is_never_overwritten(t: TestCase) -> void:
	var dir := ProjectSettings.globalize_path("user://test_screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var when := {"year": 2026, "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0}
	var first := Screenshot.free_path(dir, "Test", when)
	FileAccess.open(first, FileAccess.WRITE).store_string("x")
	var second := Screenshot.free_path(dir, "Test", when)
	t.check(second != first and second.ends_with(" (2).png"), "the next picture gets its own name")
	DirAccess.remove_absolute(first)


func test_the_key_is_f12(t: TestCase) -> void:
	t.check(InputMap.has_action("screenshot"), "there is a screenshot action")
	var keys := InputMap.action_get_events("screenshot").map(func(e: InputEvent) -> int: return (e as InputEventKey).physical_keycode)
	t.check(keys.has(KEY_F12), "on F12")
	t.check(TestCase.new_session().content.has("text", "msg_screenshot"), "with a message saying where it went")
