extends SceneTree
## Calmer copies of the interior floors (tracker #36: "the floor of the
## interior is too busy"), until Mark redraws them (Art Request 20). Each
## pixel is drawn halfway to the tile's own average colour, and the
## brightest specks (the nail heads on every plank) are pulled down to the
## plank colour, so the boards read as one floor rather than a pattern.
## Writes <name>_calm.png beside each original; the originals are untouched.
##
## Run: godot --headless --path . -s tools/calm_floors.gd

const FLOORS := ["interior_plank_floor", "interior_boards_warm", "interior_boards_warm_alt_1", "interior_boards_warm_alt_2"]
const KEEP := 0.5        # how much of each pixel's difference from the average stays
const SPECK := 0.12      # lighter than the average by more than this is a speck


func _initialize() -> void:
	for n: String in FLOORS:
		var path := ProjectSettings.globalize_path("res://art/final/%s.png" % n)
		var im := Image.load_from_file(path)
		if im == null:
			push_error("calm_floors: no %s" % n)
			continue
		im.convert(Image.FORMAT_RGBA8)
		var avg := Color(0, 0, 0, 0)
		var count := 0
		for y in im.get_height():
			for x in im.get_width():
				var c := im.get_pixel(x, y)
				avg += c
				count += 1
		avg = avg / float(count)
		var avg_l := avg.get_luminance()
		for y in im.get_height():
			for x in im.get_width():
				var c := im.get_pixel(x, y)
				if c.get_luminance() > avg_l + SPECK:
					c = avg
				var o := Color(avg.r + (c.r - avg.r) * KEEP, avg.g + (c.g - avg.g) * KEEP, avg.b + (c.b - avg.b) * KEEP, c.a)
				im.set_pixel(x, y, o)
		im.save_png(ProjectSettings.globalize_path("res://art/final/%s_calm.png" % n))
		print("calm_floors: ", n, "_calm")
	quit(0)
