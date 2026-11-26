class_name CreatureView
extends Node2D
## Phase 5b: draws the creatures' things in the world (the jackalopes'
## burrows and trail, the badgers' stone, Gord's meadow sign, the bell on
## its hook), Gord himself on full-moon nights, and the second pet.

const TILE := 16

var session: GameSession
var sort_root: Node2D
var _things: Array = []
var _key: String = ""
var _gord: Sprite2D
var _spare: Sprite2D
var _spare_bowl: Sprite2D
var _time: float = 0.0


func setup(s: GameSession, root: Node2D) -> void:
	session = s
	sort_root = root
	_gord = _sprite("npc_gord", 4, 4)
	_spare = _sprite("pet_dog", 8, 3)
	_spare_bowl = _sprite("furniture_pet_bowl", 2, 1)


func _sprite(art: String, cols: int, rows: int) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.centered = false
	if Art.has_picture(art):
		spr.texture = Art.texture(art)
	spr.hframes = cols
	spr.vframes = rows
	spr.visible = false
	sort_root.add_child(spr)
	return spr


func _put(art: String, p: Vector2, w: float = 16.0, h: float = 16.0) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.centered = false
	if Art.has_picture(art):
		spr.texture = Art.texture(art)
		w = spr.texture.get_width()
		h = spr.texture.get_height()
	spr.offset = Vector2(-w / 2.0, -h)
	spr.position = (p * TILE).round()
	sort_root.add_child(spr)
	return spr


func _process(delta: float) -> void:
	if session == null or not is_visible_in_tree():
		return
	_time += delta
	var outside := not session.is_indoors() and not session.in_town
	_draw_things(outside)
	_draw_gord(outside)
	_draw_spare(outside)


func _draw_things(outside: bool) -> void:
	var c := session.creatures
	var key := "%s:%d:%d:%d:%s:%d:%s:%s" % [outside, c.burrows.size(), c.filled.size(), c.trail_laid, c.deal_place, c.offered_week.size(), c.bell_hung, c.job_active("jackalopes")]
	key += ":%d" % session.clock.absolute_day()
	if key == _key:
		return
	_key = key
	for n: Node in _things:
		n.queue_free()
	_things = []
	if not outside:
		return
	for t: Vector2i in c.burrows:
		_things.append(_put("obj_burrow_filled" if c.filled.has(t) else "obj_burrow", Vector2(t) + Vector2(0.5, 0.9)))
	if c.job_active("jackalopes") or c.settled("jackalopes"):
		var spots := c.trail_spots()
		for k in mini(c.trail_laid, spots.size()):
			# Eaten overnight: only today's is still there.
			if k == c.trail_laid - 1 and c.trail_day == session.clock.absolute_day():
				_things.append(_put("obj_trail_food", spots[k] + Vector2(0, 0.4)))
	var st := c.stone()
	if st != Vector2.INF and (c.job_active("troll_badgers") or c.settled("troll_badgers")):
		var full := c.offered_week.has(session.clock.absolute_day() / 7)
		var spr := _put("obj_offering_stone_full" if full else "obj_offering_stone", st + Vector2(0, 0.4))
		spr.z_index = -2
		_things.append(spr)
	if session.jobs.known.has("cj_gord") or session.wildlife.level_of("gord_moose") != "":
		_things.append(_put("obj_gord_meadow_sign", c.gord_meadow() + Vector2(-2.0, -1.0)))
	if c.bell_hung:
		var b := _put("item_old_bell", c.hook_spot() + Vector2(0, -0.6))
		b.scale = Vector2(0.4, 0.4)
		b.offset *= 1.0
		_things.append(b)


func _draw_gord(outside: bool) -> void:
	var c := session.creatures
	var show := outside and c.gord_man_out()
	_gord.visible = show
	if not show:
		return
	var art := "npc_gord_dressed" if c.fact("gord_dressed") > 0 else "npc_gord"
	if Art.has_picture(art) and _gord.texture != Art.texture(art):
		_gord.texture = Art.texture(art)
	_gord.offset = Vector2(-8, -32)
	var p := c.gord_spot()
	var row := 0
	var col := 0
	if c.gord_along:
		var to := session.outdoor_pos - p
		row = [0, 1, 2, 3][Wildlife._facing_of(to)] if to.length() > 0.1 else 0
		col = int(_time * 6.0) % 4 if to.length() > 1.7 else 0
	_gord.frame_coords = Vector2i(col, row)
	_gord.position = (p * TILE).round()


func _draw_spare(outside: bool) -> void:
	var p := session.pet
	var c := session.creatures
	var waiting := c.spare_waiting and p.spare.is_empty() and p.has_pet()
	var home := not p.spare.is_empty()
	_spare.visible = outside and (waiting or home)
	_spare_bowl.visible = outside and home
	if not _spare.visible:
		return
	var kind := p.other_kind() if waiting else str(p.spare["kind"])
	var art := "pet_" + kind
	if Art.has_picture(art) and _spare.texture != Art.texture(art):
		_spare.texture = Art.texture(art)
	_spare.offset = Vector2(-8, -16)
	_spare.frame_coords = Vector2i(6, 0)
	_spare.position = ((c.spare_spot() if waiting else p.spare_spot()) * TILE).round()
	if home:
		_spare_bowl.offset = Vector2(-8, -16)
		_spare_bowl.frame = 1 if int(p.spare.get("bowl", -1)) == session.clock.absolute_day() else 0
		_spare_bowl.position = (p.spare_bowl_spot() * TILE).round()
