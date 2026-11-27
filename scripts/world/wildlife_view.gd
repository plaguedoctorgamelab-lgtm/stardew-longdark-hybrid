class_name WildlifeView
extends Node2D
## Phase 5a: draws the animals out now, the pet and its bowl, the
## moonflowers and night paths after dark, and fireflies over water on
## summer nights (Phase 5 Spec, Animals, A pet, Night).

const TILE := 16

var session: GameSession
var sort_root: Node2D
var _animals: Dictionary = {}    # animal dict id -> Sprite2D
var _glows: Dictionary = {}      # animal dict id -> Sprite2D (a magic deer's antlers)
var _pet: Sprite2D
var _bowl: Sprite2D
var _night: Array = []           # flowers, stones and spots
var _night_key: String = ""
var _feathers: Array = []        # today's dropped feathers
var _feather_key: String = ""
var _flies: Node2D
var _time: float = 0.0


func setup(s: GameSession, root: Node2D) -> void:
	session = s
	sort_root = root
	_pet = Sprite2D.new()
	_pet.centered = false
	_pet.visible = false
	sort_root.add_child(_pet)
	_bowl = Sprite2D.new()
	_bowl.centered = false
	_bowl.visible = false
	sort_root.add_child(_bowl)
	_flies = Node2D.new()
	_flies.z_index = 40
	_flies.draw.connect(_draw_flies)
	add_child(_flies)


func _sheet(art: String, cols: int, rows: int) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture = Art.texture(art)
	spr.hframes = cols
	spr.vframes = rows
	sort_root.add_child(spr)
	return spr


func _process(delta: float) -> void:
	if session == null or not is_visible_in_tree():
		return
	_time += delta
	var outside := not session.is_indoors() and not session.in_town
	_draw_animals(outside)
	_draw_pet(outside)
	_draw_night(outside)
	_draw_feathers(outside)
	_flies.queue_redraw()


func _draw_animals(outside: bool) -> void:
	var used := {}
	if outside:
		var near := session.tuning.num("wildlife.spawn_near_tiles") * 0.6
		for a: Dictionary in session.wildlife.visible_animals():
			if Vector2(a["pos"]).distance_to(session.outdoor_pos) > near:
				continue
			var key := int(a["key"])
			used[key] = true
			var r := session.wildlife.row(str(a["id"]))
			var spr: Sprite2D = _animals.get(key)
			if spr == null:
				spr = _sheet(str(r["sprite"]), int(r["cols"]), 3)
				_animals[key] = spr
				if r.has("glow") and Art.has_picture(str(r["glow"])):
					var gl := _sheet(str(r["glow"]), int(r["cols"]), 3)
					gl.z_index = 30
					_glows[key] = gl
			var fw := float(r["frame"][0])
			var fh := float(r["frame"][1])
			var fr := session.wildlife.frame_of(a, _time)
			spr.frame_coords = fr
			spr.flip_h = int(a["facing"]) == GameSession.FACING_LEFT
			spr.offset = Vector2(-fw / 2.0, -fh)
			# A bird on the wing is drawn a little above the ground.
			if session.wildlife.in_air(a):
				spr.offset.y -= session.tuning.num("wildlife.fly_lift_px")
			spr.position = (Vector2(a["pos"]) * TILE).round()
			if _glows.has(key):
				var gl: Sprite2D = _glows[key]
				gl.frame_coords = fr
				gl.flip_h = spr.flip_h
				gl.offset = spr.offset
				gl.position = spr.position
				# The antlers' glow shows after dark, and pulses.
				var night := Daylight.night_amount(session.tuning, session.clock.season_name(), session.clock.minute)
				gl.modulate = Color(1, 1, 1, clampf(0.25 + night * (0.6 + 0.25 * sin(_time * 2.5)), 0.0, 1.0))
	for key: int in _animals.keys():
		if not used.has(key):
			(_animals[key] as Node).queue_free()
			_animals.erase(key)
			if _glows.has(key):
				(_glows[key] as Node).queue_free()
				_glows.erase(key)


func _draw_pet(outside: bool) -> void:
	var p := session.pet
	_pet.visible = outside and p.has_pet() and p.pos != Vector2.INF
	_bowl.visible = outside and p.has_pet()
	if not p.has_pet():
		return
	var art := "pet_" + p.kind
	if _pet.texture != Art.texture(art):
		_pet.texture = Art.texture(art)
		_pet.hframes = 8
		_pet.vframes = 3
		_pet.offset = Vector2(-8, -16)
	var f := p.facing
	var col := 1 + int(_time * 8.0) % 3 if p.moving else (6 if not p.along else 0)
	_pet.frame_coords = Vector2i(col, 1 if f == GameSession.FACING_LEFT else f)
	_pet.flip_h = f == GameSession.FACING_LEFT
	_pet.position = (p.pos * TILE).round()
	if _bowl.texture == null:
		_bowl.texture = Art.texture("furniture_pet_bowl")
		_bowl.hframes = 2
		_bowl.offset = Vector2(-8, -16)
	_bowl.frame = 1 if p.bowl_day == session.clock.absolute_day() else 0
	_bowl.position = (p.bowl_spot() * TILE).round()


func _draw_night(outside: bool) -> void:
	var w := session.wildlife
	var night := outside and w.is_night()
	var key := "%s:%d:%d:%d" % [night, w.flowers.size(), w.paths.size(), session.clock.absolute_day()]
	if key == _night_key:
		return
	_night_key = key
	for n: Node in _night:
		n.queue_free()
	_night = []
	if not outside:
		return
	var nr := session.content.row("night_finds", "moonflower")
	for i in w.flowers.size():
		var t: Vector2i = w.flowers[i]
		var open := night and int(w.picked.get("moonflower:%d" % i, -99)) != session.clock.absolute_day()
		_night.append(_put(str(nr["sprite_open"] if open else nr["sprite_closed"]), t))
	var gr := session.content.row("night_finds", "glow")
	for i in w.paths.size():
		for t: Vector2i in w.paths[i]["stones"]:
			var st := _put(str(gr["stone"] if night else gr["stone_day"]), t)
			st.z_index = -5
			_night.append(st)
		if night:
			_night.append(_put(str(gr["sprite"]), w.paths[i]["spot"]))


## Feathers left by birds that flew off, lying where they fell.
func _draw_feathers(outside: bool) -> void:
	var w := session.wildlife
	var key := "%s:%d:%d" % [outside, w.feathers.size(), session.clock.absolute_day()]
	if key == _feather_key:
		return
	_feather_key = key
	for n: Node in _feathers:
		n.queue_free()
	_feathers = []
	if not outside:
		return
	for f: Dictionary in w.feathers:
		var art := str(session.content.row("items", str(f["item"]))["icon"])
		if not Art.has_picture(art):
			continue
		var spr := _put(art, Vector2i(f["pos"]))
		spr.scale = Vector2(0.5, 0.5)
		spr.position = (Vector2(f["pos"]) * TILE).round() + Vector2(0, 4)
		spr.z_index = -2
		_feathers.append(spr)


func _put(art: String, t: Vector2i) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture = Art.texture(art)
	spr.offset = Vector2(-spr.texture.get_width() / 2.0, -spr.texture.get_height())
	spr.position = ((Vector2(t) + Vector2(0.5, 1.0)) * TILE).round()
	sort_root.add_child(spr)
	return spr


## Fireflies drift over water near the ranger on summer nights.
func _draw_flies() -> void:
	if session.is_indoors() or session.in_town or not session.wildlife.is_night() or session.clock.season_name() != "summer":
		return
	var n := session.tuning.integer("wildlife.firefly_count")
	# Phase 5b: midsummer night, fireflies over every pond (three times as many).
	if session.clock.day == 14:
		n *= 3
	var near := session.tuning.integer("wildlife.firefly_near_tiles")
	var c := session.ranger_tile()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c / 8)
	var drawn := 0
	for i in n * 6:
		if drawn >= n:
			break
		var t := c / 8 * 8 + Vector2i(rng.randi_range(-near, near), rng.randi_range(-near, near))
		if not session.world.in_bounds(t) or not session.world.ground_at(t) in ["shallows", "deep_water", "bog", "tall_grass"]:
			continue
		drawn += 1
		var ph := rng.randf() * TAU
		var p := (Vector2(t) + Vector2(0.5 + 0.6 * sin(_time * 0.7 + ph), 0.3 * cos(_time * 0.9 + ph))) * TILE
		var a := 0.5 + 0.5 * sin(_time * 3.0 + ph * 3.0)
		_flies.draw_circle(p, 2.0, Color(0.85, 1.0, 0.4, 0.25 * a))
		_flies.draw_circle(p, 1.0, Color(0.95, 1.0, 0.6, 0.9 * a))
