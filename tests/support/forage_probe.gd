extends SceneTree
## Lab tool: the average forage an hour's walk on the trail gathers in each
## season, to tune forage. Not part of the tests.
## Run: godot --headless --path . -s tests/support/forage_probe.gd

func _initialize() -> void:
	var walker = load("res://tests/test_living.gd").new()
	for season: String in ["spring", "summer", "autumn", "winter"]:
		var kinds := {}
		var walks := 0
		for sd in range(1, 4):
			var s := TestCase.new_session(sd)
			var hour: float = walker._hour_tiles(s)
			var start := 0.0
			while start + hour <= float(s.world.meta["route_lengths"]["bridge"]):
				walker._walk_hour(s, season, start)
				walks += 1
				for k: String in walker.last_walk:
					kinds[k] = int(kinds.get(k, 0)) + 1
				start += hour
		var line := ""
		for k: String in kinds:
			line += "%s %.2f  " % [k, float(kinds[k]) / walks]
		print(season, "  avg slots %.2f   walks with: %s" % [walker._average_walk(season), line])
	quit()
