class_name BadgesView
extends Control
## The Badges page of the book (docs/art/visual_direction_brief.md): an
## embroidered patch for each skill level with a perk, a shield for each
## specialty, and the strange badges, one for each hidden find and magical
## ingredient. A strange badge never says what earned it: found ones are
## numbered, the rest are question marks. Hover a patch for what it is.
## Mark's Art Request 14 patches (badge_*) are used when they are there: a
## skill patch gets small gold pips for its level (his three are drawn alike),
## a patch not yet earned shows his locked patch, faded. Drawn stand-ins fill
## any gaps.

const INK := Color8(26, 22, 32)
const CREAM := Color8(246, 224, 180)
const PAPER := Color8(252, 248, 237)
const WOOD_DARK := Color8(93, 62, 48)
const LOCKED := Color8(214, 196, 160)
const STRANGE := Color8(80, 60, 110)
const GLOW := Color8(161, 241, 218)
## A colour for each skill's patches, in the order of skills.json.
const SKILL_COLOURS := [Color8(232, 115, 95), Color8(38, 112, 157), Color8(56, 142, 76), Color8(240, 128, 150), Color8(157, 102, 62)]

const R := 11.0          # a patch's radius
const STEP := 27.0       # from one patch to the next
const HEAD := 12.0       # a heading's height

var session: GameSession
var _spots: Array = []   # [centre, tooltip]


func setup(s: GameSession, width: float) -> void:
	session = s
	custom_minimum_size = Vector2(width, 0)
	tooltip_text = " "   # turns on _get_tooltip
	mouse_filter = Control.MOUSE_FILTER_PASS


func refresh() -> void:
	queue_redraw()


func _get_tooltip(at: Vector2) -> String:
	for sp: Array in _spots:
		if at.distance_to(sp[0]) <= R + 2:
			return sp[1]
	return ""


func _heading(text: String, y: float) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(4, y + 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, WOOD_DARK)


func _small(text: String, c: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
	draw_string(f, Vector2(c.x - w / 2.0, c.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, WOOD_DARK)


## A round embroidered patch: a twisted edge, a stitched ring, the field.
func _patch(c: Vector2, fill: Color, earned: bool) -> void:
	if earned:
		draw_circle(c, R + 1, INK)
		draw_circle(c, R, fill.darkened(0.25))
		draw_circle(c, R - 2, fill)
		for i in 16:
			var a := TAU * i / 16.0
			draw_rect(Rect2(c + Vector2(cos(a), sin(a)) * (R - 1) - Vector2(0.5, 0.5), Vector2(1, 1)), CREAM)
	else:
		draw_circle(c, R, LOCKED)
		for i in 12:
			if i % 2 == 0:
				draw_arc(c, R, TAU * i / 12.0, TAU * (i + 1) / 12.0, 4, WOOD_DARK, 1.0)


## A shield-shaped patch for a specialty.
func _shield(c: Vector2, fill: Color, earned: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(-R, -R), c + Vector2(R, -R), c + Vector2(R, R * 0.3), c + Vector2(0, R + 2), c + Vector2(-R, R * 0.3)])
	if earned:
		draw_colored_polygon(PackedVector2Array(Array(pts).map(func(p: Vector2) -> Vector2: return c + (p - c) * 1.12)), INK)
		draw_colored_polygon(pts, fill)
		draw_polyline(PackedVector2Array(Array(pts).map(func(p: Vector2) -> Vector2: return c + (p - c) * 0.8)) + PackedVector2Array([c + (pts[0] - c) * 0.8]), CREAM, 1.0)
	else:
		draw_colored_polygon(pts, LOCKED)
		draw_polyline(pts + PackedVector2Array([pts[0]]), WOOD_DARK, 1.0)


## Draws one of Mark's patches centred on c, faded when not yet earned.
## Returns false when the picture is not there, so the stand-in is drawn.
func _art(name: String, c: Vector2, earned: bool) -> bool:
	if not Art.has_picture(name):
		return false
	var tex := Art.texture(name if earned or not Art.has_picture("badge_locked") else "badge_locked")
	draw_texture(tex, (c - Vector2(tex.get_size()) / 2.0).round(), Color.WHITE if earned else Color(1, 1, 1, 0.75))
	return true


## Small gold pips under a skill patch: one for each level past the first.
func _pips(c: Vector2, n: int) -> void:
	for i in n:
		var x := c.x - (n - 1) * 2.5 + i * 5.0
		draw_rect(Rect2(x - 1.5, c.y + R - 3, 3, 3), INK)
		draw_rect(Rect2(x - 1, c.y + R - 2.5, 2, 2), Color8(255, 224, 102))


func _glyph(text: String, c: Vector2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string_outline(f, Vector2(c.x - w / 2.0, c.y + 3.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 2, INK)
	draw_string(f, Vector2(c.x - w / 2.0, c.y + 3.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)


func _draw() -> void:
	if session == null:
		return
	_spots.clear()
	var c := session.content
	var sk := session.skills
	var y := 0.0
	# Skill patches: one for each level with a perk.
	_heading(c.text("badges_skills"), y)
	y += HEAD + R + 2
	var x := 4.0 + R
	var rows := c.rows("skills")
	for i in rows.size():
		var row: Dictionary = rows[i]
		var col: Color = SKILL_COLOURS[i % SKILL_COLOURS.size()]
		var name := c.text(row["name"])
		for p: Dictionary in sk.perks(row["id"]):
			var lv := int(p["level"])
			var earned := sk.level(row["id"]) >= lv
			var at := Vector2(x, y)
			if _art("badge_%s_%d" % [row["id"], lv], at, earned):
				if earned:
					_pips(at, lv - 1)
				else:
					_glyph(name.substr(0, 1) + str(lv), at, WOOD_DARK)
			else:
				_patch(at, col, earned)
				_glyph(name.substr(0, 1) + str(lv), at, CREAM if earned else WOOD_DARK)
			var tip := c.text("badge_skill", {"skill": name, "level": lv, "perk": c.text(p["text"])})
			_spots.append([at, tip if earned else tip + "\n" + c.text("badge_locked")])
			x += STEP
		x += 6
	y += R + 10
	# Specialty shields: two on offer for each skill, one to be chosen.
	_heading(c.text("badges_specialties"), y)
	y += HEAD + R + 2
	x = 4.0 + R
	for srow: Dictionary in c.rows("specialties"):
		var sid: String = srow["skill"]
		var i := rows.map(func(r: Dictionary) -> String: return r["id"]).find(sid)
		var col: Color = SKILL_COLOURS[maxi(i, 0) % SKILL_COLOURS.size()]
		var earned: bool = str(sk.chosen.get(sid, "")) == str(srow["id"])
		var taken_other: bool = str(sk.chosen.get(sid, "")) not in ["", str(srow["id"])]
		var at := Vector2(x, y)
		var name := c.text(srow["name"])
		if _art("badge_spec_" + str(srow["id"]), at, earned):
			if not earned:
				_glyph(name.substr(0, 1), at, WOOD_DARK)
		else:
			_shield(at, col, earned)
			_glyph(name.substr(0, 1), at, CREAM if earned else WOOD_DARK)
		var tip := name + ": " + c.text(srow["desc"])
		if not earned:
			tip += "\n" + c.text("badge_spec_not_taken" if taken_other else "badge_locked")
		_spots.append([at, tip])
		x += STEP
	y += R + 10
	# Strange badges: what earns them stays a secret.
	var ids: Array[String] = []
	for f: Dictionary in c.rows("spoiler_finds"):
		ids.append(f["id"])
	for f: Dictionary in c.rows("forage"):
		if bool(f.get("magic", false)):
			ids.append(f["item"])
	var found := ids.filter(func(id: String) -> bool: return session.finds_found.has(id)).size()
	_heading(c.text("badges_strange", {"found": found, "total": ids.size()}), y)
	y += HEAD + R + 2
	x = 4.0 + R
	var n := 0
	for k in ids.size():
		var id: String = ids[k]
		if x > size.x - R:
			x = 4.0 + R
			y += STEP
		var at := Vector2(x, y)
		if session.finds_found.has(id):
			n += 1
			# Each find has its own strange badge, by its place in the list.
			if not _art("badge_strange_%d" % (k + 1), at, true):
				_patch(at, STRANGE, true)
				draw_circle(at, 3.5, PAPER)
				draw_circle(at, 1.8, GLOW)
				draw_circle(at, 0.9, INK)
			_spots.append([at, c.text("badge_strange_found", {"n": n})])
		else:
			if not _art("badge_strange_%d" % (k + 1), at, false):
				_patch(at, LOCKED, false)
			_glyph("?", at, WOOD_DARK)
			_spots.append([at, c.text("badge_strange_hidden")])
		x += STEP
	y += R + 6
	if custom_minimum_size.y != y:
		custom_minimum_size.y = y
