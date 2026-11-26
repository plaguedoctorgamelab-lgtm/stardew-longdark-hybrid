class_name ScreenEffects
extends CanvasLayer
## Light and weather drawn over the world: the time-of-day tint with weather
## tint on top, the lantern's circle of light, fog and blizzard closing in,
## the light shifting before a weather change, and moving rain, snow and wind
## streaks. Indoors is lit by day; at night a room dims, with warm light
## round its lamps and lit stove, and an open building's windows glow warm
## from outside (Art Request 16, "Light in cabins").

const TINT_SHADER := """
shader_type canvas_item;
render_mode blend_mul, unshaded;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 lamp : source_color = vec4(1.0);
uniform vec2 center = vec2(240.0, 135.0);
uniform float radius = 0.0;
uniform vec2 center2 = vec2(240.0, 135.0);
uniform float radius2 = 0.0;
uniform vec2 size = vec2(480.0, 270.0);
uniform vec4 glows[8];
uniform int glow_count = 0;
void fragment() {
	vec2 p = UV * size;
	float d = distance(p, center);
	float lit = radius > 0.0 ? 1.0 - smoothstep(radius * 0.55, radius, d) : 0.0;
	float d2 = distance(p, center2);
	float lit2 = radius2 > 0.0 ? 1.0 - smoothstep(radius2 * 0.4, radius2, d2) : 0.0;
	lit = max(lit, lit2);
	for (int i = 0; i < 8; i++) {
		if (i >= glow_count) { break; }
		float dg = distance(p, glows[i].xy);
		lit = max(lit, glows[i].w * (1.0 - smoothstep(glows[i].z * 0.3, glows[i].z, dg)));
	}
	vec3 lamp_c = max(tint.rgb, lamp.rgb);
	COLOR = vec4(mix(tint.rgb, lamp_c, lit), 1.0);
}
"""

const FOG_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec4 fog : source_color = vec4(0.85, 0.87, 0.9, 1.0);
uniform vec2 center = vec2(240.0, 135.0);
uniform float radius = 0.0;
uniform float strength = 0.0;
uniform vec2 size = vec2(480.0, 270.0);
void fragment() {
	vec2 p = UV * size;
	float d = distance(p, center);
	float a = radius > 0.0 ? smoothstep(radius * 0.45, radius, d) : 0.0;
	COLOR = vec4(fog.rgb, a * strength);
}
"""

const VIEW := Vector2(480, 270)

var session: GameSession
var sky: Node2D
var tint_rect: ColorRect
var fog_rect: ColorRect
var streaks: Node2D
var _drops: Array = []
var _effect: String = "none"
var _wind: float = 0.0
var _rng := RandomNumberGenerator.new()
var ranger_screen: Vector2 = VIEW / 2.0
var fire_screen: Vector2 = Vector2(-1000, -1000)
var last_tint: Color = Color.WHITE
var last_visibility_px: float = 0.0
## Warm glows this frame, in screen pixels: [Vector4(x, y, radius, strength)].
var glows: Array[Vector4] = []


func setup(s: GameSession) -> void:
	session = s
	layer = 1
	tint_rect = _make_rect(TINT_SHADER)
	fog_rect = _make_rect(FOG_SHADER)
	streaks = Node2D.new()
	streaks.draw.connect(_draw_streaks)
	add_child(streaks)
	# Phase 5b: the full moon and the aurora, at the top of the sky.
	sky = Node2D.new()
	sky.draw.connect(_draw_sky)
	add_child(sky)
	_rng.seed = 7
	for i in 220:
		_drops.append(Vector3(_rng.randf() * VIEW.x, _rng.randf() * VIEW.y, _rng.randf()))


func _make_rect(code: String) -> ColorRect:
	var r := ColorRect.new()
	r.size = VIEW
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	add_child(r)
	return r


static func _c(a: Variant) -> Color:
	var arr: Array = a
	return Color(float(arr[0]), float(arr[1]), float(arr[2]))


## The tint for now: time of day times weather, shifting toward the coming
## weather during the warning hour.
func current_tint() -> Color:
	var t := session.tuning
	if (session.is_indoors() or session.in_town_room()):
		if Daylight.is_night(t, session.clock.season_name(), session.clock.minute):
			return _c(t.value("light.indoor_night_tint"))
		return Color.WHITE
	var day := Daylight.tint(t, session.clock.season_name(), session.clock.minute)
	var w := _c(session.weather_row()["tint"])
	var warn := session.weather.warning_amount(session.clock.minute)
	if warn > 0.0:
		var next_id := session.weather.next_weather(session.clock.minute)
		w = w.lerp(_c(session.weather.row(next_id)["tint"]), warn * 0.6)
	var col := Color(day.r * w.r, day.g * w.g, day.b * w.b)
	# Phase 5b: green and violet under the aurora; a little brighter under a
	# full moon.
	var cr := session.creatures
	var night := Daylight.night_amount(t, session.clock.season_name(), session.clock.minute)
	if cr != null and night > 0.0:
		if cr.aurora_on(session.clock.absolute_day()):
			col = col.lerp(Color(0.55, 0.95, 0.8), 0.3 * night)
		elif cr.is_full_moon_day():
			col = col.lerp(Color(0.8, 0.85, 1.0), 0.22 * night)
	return col


func visibility_tiles() -> float:
	if (session.is_indoors() or session.in_town_room()):
		return 0.0
	return float(session.weather_row().get("visibility_tiles", 0))


func _process(delta: float) -> void:
	if session == null:
		return
	var t := session.tuning
	last_tint = current_tint()
	var tm: ShaderMaterial = tint_rect.material
	tm.set_shader_parameter("tint", last_tint)
	tm.set_shader_parameter("lamp", _c(t.value("light.lantern_tint")))
	tm.set_shader_parameter("center", ranger_screen)
	var lantern := session.lantern_lit() and not (session.is_indoors() or session.in_town_room())
	tm.set_shader_parameter("radius", session.lantern_radius() * 16.0 if lantern else 0.0)
	var fire_on := session.campfire_lit() and not (session.is_indoors() or session.in_town_room())
	tm.set_shader_parameter("center2", fire_screen)
	tm.set_shader_parameter("radius2", t.num("camp.fire_light_tiles") * 16.0 * (0.95 + 0.05 * sin(Time.get_ticks_msec() / 90.0)) if fire_on else 0.0)
	var gl: Array[Vector4] = []
	for g in glows.slice(0, 8):
		gl.append(g)
	while gl.size() < 8:
		gl.append(Vector4.ZERO)
	tm.set_shader_parameter("glows", gl)
	tm.set_shader_parameter("glow_count", mini(glows.size(), 8))
	var fm: ShaderMaterial = fog_rect.material
	var vis := visibility_tiles()
	last_visibility_px = vis * 16.0
	fm.set_shader_parameter("center", ranger_screen)
	fm.set_shader_parameter("radius", last_visibility_px)
	fm.set_shader_parameter("strength", 1.0 if vis > 0.0 else 0.0)
	var wid: String = "" if (session.is_indoors() or session.in_town_room()) else session.current_weather()
	fm.set_shader_parameter("fog", Color(0.93, 0.95, 1.0) if wid == "blizzard" else Color(0.8, 0.82, 0.84))
	_effect = "none" if (session.is_indoors() or session.in_town_room()) else str(session.weather_row().get("effect", "none"))
	_wind = 0.0 if (session.is_indoors() or session.in_town_room()) else session.weather.warning_amount(session.clock.minute)
	_move_drops(delta)
	streaks.queue_redraw()
	sky.queue_redraw()


func _move_drops(delta: float) -> void:
	var vel := Vector2.ZERO
	match _effect:
		"rain":
			vel = Vector2(-40, 260)
		"storm":
			vel = Vector2(-140, 320)
		"snow":
			vel = Vector2(-12, 40)
		"blizzard":
			vel = Vector2(-320, 70)
	if _wind > 0.0:
		vel += Vector2(-220.0 * _wind, 0)
	for i in _drops.size():
		var d: Vector3 = _drops[i]
		var speed := 0.7 + d.z * 0.6
		d.x += vel.x * speed * delta
		d.y += vel.y * speed * delta
		d.x = fposmod(d.x, VIEW.x)
		d.y = fposmod(d.y, VIEW.y)
		_drops[i] = d


func _draw_streaks() -> void:
	var count := 0
	var col := Color(0.75, 0.82, 0.95, 0.55)
	var len_v := Vector2.ZERO
	match _effect:
		"rain":
			count = 110
			len_v = Vector2(-1, 6)
		"storm":
			count = 220
			len_v = Vector2(-3, 8)
		"snow":
			count = 140
			col = Color(1, 1, 1, 0.85)
		"blizzard":
			count = 220
			col = Color(1, 1, 1, 0.8)
			len_v = Vector2(-6, 1)
	for i in count:
		var d: Vector3 = _drops[i]
		var p := Vector2(d.x, d.y)
		if len_v == Vector2.ZERO:
			streaks.draw_rect(Rect2(p.floor(), Vector2(1, 1)), col)
		else:
			streaks.draw_line(p, p + len_v, col, 1.0)
	# Wind streaks: the warning sign before a change.
	if _wind > 0.0:
		var n := int(24 * _wind)
		for i in n:
			var d: Vector3 = _drops[(i * 7) % _drops.size()]
			var p := Vector2(d.x, d.y)
			streaks.draw_line(p, p + Vector2(-18 - 10 * d.z, 1), Color(1, 1, 1, 0.25 + 0.2 * _wind), 1.0)


func _draw_sky() -> void:
	if session == null or session.is_indoors() or session.in_town_room() or session.in_town:
		return
	var cr := session.creatures
	var night := Daylight.night_amount(session.tuning, session.clock.season_name(), session.clock.minute)
	if night <= 0.0:
		return
	var a := cr.aurora_amount()
	if a > 0.0 and Art.has_picture("sky_aurora"):
		var tex := Art.texture("sky_aurora")
		var frame := int(Time.get_ticks_msec() / 1400) % 3
		sky.draw_texture_rect_region(tex, Rect2(0, 0, VIEW.x, 64), Rect2(0, frame * 64, VIEW.x, 64), Color(1, 1, 1, 0.65 * a))
	elif cr.is_full_moon_day() and Art.has_picture("sky_full_moon"):
		sky.draw_texture_rect(Art.texture("sky_full_moon"), Rect2(Vector2(300, 8), Vector2(32, 32)), false, Color(1, 1, 1, night))
