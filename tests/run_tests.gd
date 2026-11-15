extends SceneTree
## Runs every automated test with no window and exits with 0 on pass, 1 on
## fail. Each tests/test_*.gd file holds test_* methods that take a TestCase.
## Run: godot --headless --path . -s tests/run_tests.gd [-- filter]

const TEST_DIR := "res://tests/"


func _initialize() -> void:
	# A broken test must never hang the run.
	create_timer(900.0).timeout.connect(func() -> void:
		print("TIMED OUT")
		quit(2))
	_run()


func _run() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var files: Array[String] = []
	for f in DirAccess.get_files_at(TEST_DIR):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	var passed := 0
	var failed: Array[String] = []
	var started := Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load(TEST_DIR + f)
		if script == null:
			failed.append("%s (did not compile)" % f)
			continue
		var suite: Object = script.new()
		for m in script.get_script_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			var full := "%s:%s" % [f.get_basename(), mname]
			if filter != "" and not full.contains(filter):
				continue
			var tc := TestCase.new(full)
			var t0 := Time.get_ticks_msec()
			await suite.call(mname, tc)
			var ms := Time.get_ticks_msec() - t0
			if tc.failures.is_empty():
				passed += 1
				print("  PASS  %s  (%d ms)" % [full, ms])
			else:
				failed.append(full)
				print("  FAIL  %s" % full)
				for msg in tc.failures:
					print("        - %s" % msg)
		if suite.has_method("cleanup"):
			suite.call("cleanup")
	print("")
	print("%d passed, %d failed  (%.1f s)" % [passed, failed.size(), (Time.get_ticks_msec() - started) / 1000.0])
	for f in failed:
		print("FAILED: %s" % f)
	quit(0 if failed.is_empty() and passed > 0 else 1)
