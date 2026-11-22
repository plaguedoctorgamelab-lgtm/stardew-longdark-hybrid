class_name Polish
extends Node2D
## The Graphics Polish request's small touches outdoors (21 Nov 2026): chips
## bursting where a tool lands, the thing hit jolting a pixel, a felled tree
## tipping away in pixel steps, and the fog and snow overlay. Everything moves
## in whole pixels. Each group has its own switch on the Options screen:
## "motion" for the hits, "weather_effects" for the overlay.

const TILE := 16

var session: GameSession
var view: WorldView
var _chips: Array = []      # {"pos": Vector2, "vel": Vector2, "life": float, "color": Color}
var _ghosts: Array = []     # {"sprite": Sprite2D, "steps": Array[Vector2], "t": float, "i": int, "restore": Vector2i}
var _overlay: Texture2D
var _drift: float = 0.0


func setup(s: GameSession, v: WorldView) -> void:
	session = s
	view = v
	z_index = 40
	session.tool_landed.connect(_on_tool_landed)


func _look(key: String) -> Variant:
	return session.tuning.value("look.polish." + key)


## A tool landed on tile t: chips of the thing's material, and a jolt or a
## fall. kind is "tree", "fell", "brush", "trunk", "dirt" or "stone".
func _on_tool_landed(tool: String, t: Vector2i, kind: String) -> void:
	if not Settings.flag("motion"):
		return
	var colors: Dictionary = _look("chip_colors")
	var cs: Array = colors.get(kind, colors["dirt"])
	var n := int(_look("chips"))
	var from := Vector2(t) * TILE + Vector2(TILE / 2.0, TILE * 0.6)
	var away := (Vector2(t) + Vector2(0.5, 0.5) - session.outdoor_pos).normalized()
	for i in n:
		var a := randf_range(-PI * 0.9, -PI * 0.1)
		var sp := randf_range(30.0, 70.0)
		var c: Array = cs[i % cs.size()]
		_chips.append({"pos": from, "vel": Vector2(cos(a), sin(a)) * sp + away * 15.0, "life": float(_look("chip_seconds")), "color": Color8(int(c[0]), int(c[1]), int(c[2]))})
	if kind == "fell":
		_fall(t, away)
	elif kind in ["tree", "brush", "trunk"]:
		_jolt(t, away)


## The object's picture over its tile, as drawn there by the world view.
func _ghost_of(t: Vector2i) -> Sprite2D:
	var tex := view.object_texture(t)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture = tex
	spr.position = Vector2(t.x * TILE + TILE / 2.0, (t.y + 1) * TILE)
	spr.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	view.sort_root.add_child(spr)
	return spr


## Shakes the thing hit by a pixel, toward the ranger and back, twice.
func _jolt(t: Vector2i, away: Vector2) -> void:
	var spr := _ghost_of(t)
	if spr == null:
		return
	view.object_layer.erase_cell(t)
	var d := Vector2(signf(away.x) if absf(away.x) >= absf(away.y) else 0.0, 0.0 if absf(away.x) >= absf(away.y) else signf(away.y))
	_ghosts.append({"sprite": spr, "base": spr.position, "steps": [-d, Vector2.ZERO, -d, Vector2.ZERO], "fade": false, "t": 0.0, "i": 0, "restore": t})


## A felled tree tips away from the ranger in a few pixel steps and fades,
## leaving its stump. No smooth rotation: it slides and sinks a pixel a step.
func _fall(t: Vector2i, away: Vector2) -> void:
	var spr := _ghost_of_tree(t)
	if spr == null:
		return
	var sx := 1.0 if away.x >= 0.0 else -1.0
	var steps: Array = []
	for i in int(_look("fall_steps")):
		steps.append(Vector2(sx * (i + 1) * 2.0, float(i + 1)))
	_ghosts.append({"sprite": spr, "base": spr.position, "steps": steps, "fade": true, "t": 0.0, "i": 0, "restore": Vector2i(-99999, -99999)})


## The standing tree's picture, though the tile now shows its stump.
func _ghost_of_tree(t: Vector2i) -> Sprite2D:
	var tex := view.object_texture(t, true)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture = tex
	spr.position = Vector2(t.x * TILE + TILE / 2.0, (t.y + 1) * TILE)
	spr.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	view.sort_root.add_child(spr)
	return spr


func _process(delta: float) -> void:
	var step := float(_look("ghost_step_seconds"))
	for g: Dictionary in _ghosts.duplicate():
		g["t"] = float(g["t"]) + delta
		while float(g["t"]) >= step and int(g["i"]) < (g["steps"] as Array).size():
			g["t"] = float(g["t"]) - step
			var spr: Sprite2D = g["sprite"]
			spr.position = (g["base"] as Vector2) + (g["steps"] as Array)[g["i"]]
			if g["fade"]:
				spr.modulate.a = 1.0 - float(int(g["i"]) + 1) / float((g["steps"] as Array).size() + 1)
			g["i"] = int(g["i"]) + 1
		if int(g["i"]) >= (g["steps"] as Array).size() and float(g["t"]) >= step:
			(g["sprite"] as Sprite2D).queue_free()
			var r: Vector2i = g["restore"]
			if r.x > -99999:
				view.redraw_object(r)
			_ghosts.erase(g)
	for c: Dictionary in _chips.duplicate():
		c["life"] = float(c["life"]) - delta
		if float(c["life"]) <= 0.0:
			_chips.erase(c)
			continue
		c["vel"] = (c["vel"] as Vector2) + Vector2(0, 220.0) * delta
		c["pos"] = (c["pos"] as Vector2) + (c["vel"] as Vector2) * delta
	_drift += delta
	queue_redraw()


func _draw() -> void:
	for c: Dictionary in _chips:
		draw_rect(Rect2((c["pos"] as Vector2).round(), Vector2.ONE), c["color"])
	_draw_overlay()


## Fog and snow: a tiled texture of soft pale patches, two layers drifting at
## different speeds, lightly over the world. Drawn at game pixels, so sharp.
func _draw_overlay() -> void:
	if not Settings.flag("weather_effects") or session.is_indoors():
		return
	var all: Dictionary = session.tuning.value("look.weather_overlay")
	var w := session.current_weather()
	if not all.has(w):
		return
	var cfg: Dictionary = all[w]
	if _overlay == null:
		_overlay = make_overlay_texture(session.tuning.value("look.weather_overlay_color"))
	var xf := get_viewport().get_canvas_transform().affine_inverse()
	var view_rect := Rect2(xf.origin, Vector2(480, 270))
	var size := _overlay.get_size()
	var layers: Array = cfg["layers"]
	for li in layers.size():
		var ly: Array = layers[li]
		var off := Vector2(float(ly[0]), float(ly[1])) * _drift
		var start := ((view_rect.position - off) / size).floor() * size + off
		var a := float(cfg["strength"]) * float(ly[2])
		var y := start.y
		while y < view_rect.end.y:
			var x := start.x
			while x < view_rect.end.x:
				draw_texture(_overlay, Vector2(x, y).round(), Color(1, 1, 1, a))
				x += size.x
			y += size.y


## A 64 x 64 tile of soft pale patches in one palette colour, dithered so it
## has no smooth gradients; it repeats without a seam.
static func make_overlay_texture(color: Array) -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	var blobs: Array = []
	for i in 7:
		blobs.append([rng.randf() * n, rng.randf() * n, rng.randf_range(7.0, 14.0)])
	var base := Color8(int(color[0]), int(color[1]), int(color[2]))
	for y in n:
		for x in n:
			var v := 0.0
			for b: Array in blobs:
				var dx := absf(x - float(b[0]))
				var dy := absf(y - float(b[1]))
				dx = minf(dx, n - dx)
				dy = minf(dy, n - dy)
				v = maxf(v, 1.0 - sqrt(dx * dx + dy * dy) / float(b[2]))
			# Three steps of strength, dithered between them.
			var lvl := int(v * 3.0 + (0.5 if (x + y) % 2 == 0 else 0.0))
			if lvl > 0:
				img.set_pixel(x, y, Color(base.r, base.g, base.b, 0.33 * mini(lvl, 3)))
	return ImageTexture.create_from_image(img)
