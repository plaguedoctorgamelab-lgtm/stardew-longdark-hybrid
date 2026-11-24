class_name ParkView
extends Node2D
## Draws the park's people and things in the world: facilities and their
## pads, small placed things, litter, troll badgers and, near the ranger,
## visitors as small characters made from layered pictures. Visitors far away
## are records only; they are drawn as they come within the tuned distance,
## from the same record, so nothing about them changes when they appear.

const TILE := 16
const TAPE_TIE := 25           # the tape is tied this many pixels up a pad stake (Art Request 20)
const SKIN: Array[Color] = [Color(0.98, 0.84, 0.72), Color(0.9, 0.7, 0.55), Color(0.76, 0.56, 0.4), Color(0.55, 0.38, 0.26), Color(0.38, 0.26, 0.18)]
const HAIR: Array[Color] = [Color(0.2, 0.14, 0.1), Color(0.45, 0.3, 0.18), Color(0.8, 0.65, 0.35), Color(0.6, 0.25, 0.12), Color(0.75, 0.75, 0.75)]
const CLOTH: Array[Color] = [Color(0.85, 0.3, 0.25), Color(0.25, 0.45, 0.8), Color(0.95, 0.75, 0.25), Color(0.35, 0.65, 0.4), Color(0.7, 0.4, 0.75), Color(0.95, 0.55, 0.2), Color(0.3, 0.7, 0.75), Color(0.9, 0.9, 0.85)]
const PANTS: Array[Color] = [Color(0.3, 0.32, 0.45), Color(0.45, 0.38, 0.3), Color(0.25, 0.25, 0.25), Color(0.55, 0.5, 0.4), Color(0.2, 0.35, 0.55)]
const HATS: Array[String] = ["", "visitor_hat_cap", "visitor_hat_wide", "visitor_hat_beanie"]
const PACKS: Array[String] = ["", "visitor_pack_small", "visitor_pack_big"]

var session: GameSession
var sort_root: Node2D
var _fac: Dictionary = {}      # pad id -> Sprite2D
var _rope: Dictionary = {}     # pad id -> Array of Sprite2D: a staked pad's corner stakes and tape
var _things: Dictionary = {}   # tile -> Sprite2D
var _litter: Dictionary = {}   # tile -> Sprite2D
var _badgers: Array = []       # Sprite2D
var _people: Dictionary = {}   # "party:member" -> Node2D
var _rent: Sprite2D
var _mailbox: Sprite2D
var _time: float = 0.0
var _wait: float = 0.0
var show_all: bool = false     # debug: visitors are drawn wherever they are loaded


func setup(s: GameSession, root: Node2D) -> void:
	session = s
	sort_root = root
	_rent = _sprite("obj_rent_sign")
	var rt := session.rent_sign_tile()
	_place(_rent, Vector2(rt) + Vector2(0.5, 1.0))
	_mailbox = _sprite("obj_station_mailbox")
	_place(_mailbox, session.mailbox_pos() + Vector2(0, 0.5))
	session.park.changed.connect(refresh)
	session.day_began.connect(refresh)
	refresh()


func _sprite(art: String) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture = Art.texture(art)
	spr.offset = Vector2(-spr.texture.get_width() / 2.0, -spr.texture.get_height())
	sort_root.add_child(spr)
	return spr


## Stands a sprite with its bottom middle on a point given in tiles.
func _place(spr: Node2D, at: Vector2) -> void:
	spr.position = (at * TILE).round()


func _set_art(spr: Sprite2D, art: String) -> void:
	var tex := Art.texture(art)
	if spr.texture != tex:
		spr.texture = tex
		spr.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())


func _free_rope(id: String) -> void:
	for n: Node in _rope[id]:
		n.queue_free()
	_rope.erase(id)


## A pad's roping: four corner stakes, and a piece of tape per tile along
## each edge, tied TAPE_TIE pixels up the stakes. Each piece is sorted one
## pixel in front of the edge's ground line so the stakes stand over it.
func _rope_pad(rc: Rect2i) -> Array:
	var out := []
	for c: Vector2i in [rc.position, Vector2i(rc.end.x, rc.position.y), Vector2i(rc.position.x, rc.end.y), rc.end]:
		var stake := _sprite("obj_pad_stakes")
		_place(stake, Vector2(c))
		out.append(stake)
	for i in rc.size.x:
		for gy: int in [rc.position.y, rc.end.y]:
			var h := _sprite("obj_pad_tape_h")
			var th := h.texture.get_height()
			h.position = Vector2((rc.position.x + i) * TILE, gy * TILE - 1)
			h.offset = Vector2(0, 1 - TAPE_TIE - ceili(th / 2.0))
			out.append(h)
	for i in rc.size.y:
		for gx: int in [rc.position.x, rc.end.x]:
			var v := _sprite("obj_pad_tape_v")
			v.position = Vector2(gx * TILE, (rc.position.y + i + 1) * TILE - 1)
			v.offset = Vector2(-floori(v.texture.get_width() / 2.0), 1 - TILE - TAPE_TIE)
			out.append(v)
	return out


## Redraws the facilities, placed things, litter and badgers.
func refresh() -> void:
	if session == null:
		return
	var park := session.park
	_rent.visible = session.structures.is_open("test_cabin")
	# The mailbox comes with the town; its flag is up when a letter waits.
	_mailbox.visible = session.town_open
	_set_art(_mailbox, "obj_station_mailbox_full" if not session.favors.mailbox.is_empty() or not session.life.mail_gifts.is_empty() else "obj_station_mailbox")
	# The second room pushes the mailbox along (Phase 4b).
	_place(_mailbox, session.mailbox_pos() + Vector2(0, 0.5))
	# Facilities, pads and kits.
	var want := {}
	for r: Dictionary in park.pad_rows():
		var id: String = r["id"]
		var st := park.pad_state(id)
		if st == "" and not park.pad_shown(id):
			continue
		var art := "obj_pad_stakes"
		var f := park.fac_row(id)
		if st == "kit" or st == "building":
			art = "obj_kit_crates"
		elif st == "built":
			art = f["sprite"]
			if f.has("sprite_badger") and park._badger_napping(id):
				art = f["sprite_badger"]
		want[id] = art
	for id: String in _fac.keys():
		if not want.has(id):
			(_fac[id] as Node).queue_free()
			_fac.erase(id)
	for id: String in want:
		if not _fac.has(id):
			_fac[id] = _sprite(want[id])
		var spr: Sprite2D = _fac[id]
		_set_art(spr, want[id])
		var rc := park.pad_rect(id)
		var at := Vector2(rc.position.x + rc.size.x / 2.0, rc.end.y)
		if park.pad_row(id)["facility"] == "tower_lookout":
			at = session.door_front("static_tower") + Vector2(1.5, -0.4)
		elif want[id] == "obj_pad_stakes" or want[id] == "obj_kit_crates":
			at = Vector2(rc.position.x + rc.size.x / 2.0, rc.position.y + rc.size.y / 2.0 + 0.5)
		elif park.pad_row(id)["facility"] == "dock":
			spr.z_index = -15
		_place(spr, at)
		# A staked pad is roped off: a stake at each corner and flagging
		# tape between them. The tower's lookout keeps its single stake by
		# the door.
		var roped: bool = want[id] == "obj_pad_stakes" and park.pad_row(id)["facility"] != "tower_lookout"
		spr.visible = not roped
		if roped and not _rope.has(id):
			_rope[id] = _rope_pad(rc)
		elif not roped and _rope.has(id):
			_free_rope(id)
	for id: String in _rope.keys():
		if not want.has(id):
			_free_rope(id)
	# Small things.
	for t: Vector2i in _things.keys():
		if not park.things.has(t):
			(_things[t] as Node).queue_free()
			_things.erase(t)
	for t: Vector2i in park.things:
		var th: Dictionary = park.things[t]
		var row := session.content.row("placeables", th["id"])
		var art: String = row["sprite"]
		if th["id"] == "trash_can":
			if bool(th["tipped"]):
				art = row["sprite_tipped"]
			elif int(th["trash"]) >= session.tuning.integer("upkeep.can_capacity"):
				art = row["sprite_full"]
		elif th["id"] == "fire_ring" and int(th["lit"]) > 0:
			art = row["sprite_lit"]
		if not _things.has(t):
			_things[t] = _sprite(art)
			_place(_things[t], Vector2(t) + Vector2(0.5, 1.0))
		_set_art(_things[t], art)
	# Litter.
	for t: Vector2i in _litter.keys():
		if not park.litter.has(t):
			(_litter[t] as Node).queue_free()
			_litter.erase(t)
	for t: Vector2i in park.litter:
		if not _litter.has(t):
			var spr := _sprite("obj_litter_%d" % int(park.litter[t]))
			spr.z_index = -15
			_place(spr, Vector2(t) + Vector2(0.5, 1.0))
			_litter[t] = spr
	# Badgers.
	for spr: Node in _badgers:
		spr.queue_free()
	_badgers = []
	for b: Dictionary in park.badgers:
		var spr := _sprite("troll_badger")
		spr.hframes = 4
		spr.offset = Vector2(-8, -16)
		spr.set_meta("tile", b["tile"])
		spr.visible = int(b["away_until"]) <= session.clock.absolute_day() and str(b.get("nap", "")) == ""
		_place(spr, Vector2(b["tile"]) + Vector2(0.5, 1.0))
		_badgers.append(spr)


func _process(delta: float) -> void:
	if session == null or not is_visible_in_tree():
		return
	_time += delta
	for i in _badgers.size():
		var spr: Sprite2D = _badgers[i]
		if spr.visible:
			spr.frame = int(_time * 3.0 + i) % 2 if int(_time) % 4 == 0 else 2
	_wait -= delta
	if _wait <= 0.0:
		_wait = 1.0
		# Pads appear as sites become ready; check now and then.
		var shown := 0
		for r: Dictionary in session.park.pad_rows():
			if session.park.pad_shown(r["id"]) or session.park.pad_state(r["id"]) != "":
				shown += 1
		if shown != _fac.size():
			refresh()
	_draw_people()


## Draws the visitors near the ranger, one figure per person.
func _draw_people() -> void:
	var used := {}
	if not session.is_indoors():
		var near := session.tuning.num("visitors.near_tiles")
		var r := session.outdoor_pos
		for p: Dictionary in session.park.parties:
			var pos: Vector2 = p["pos"]
			if not show_all and pos.distance_to(r) > near:
				continue
			var n := int(p["size"]) + int(p["guide"])
			for i in n:
				var key := "%d:%d" % [int(p["id"]), i]
				used[key] = true
				var node: Node2D = _people.get(key)
				if node == null:
					node = _make_person(p, i)
					_people[key] = node
				_pose(node, p, i)
	for key: String in _people.keys():
		if not used.has(key):
			(_people[key] as Node).queue_free()
			_people.erase(key)


func _make_person(p: Dictionary, i: int) -> Node2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(p["look"]), i])
	var node := Node2D.new()
	sort_root.add_child(node)
	var kind: String = p["kind"]
	var guide := i >= int(p["size"])
	var leader := kind == "scout_troop" and i == int(p["size"]) - 1
	var kid := (kind == "family" and i >= 2) or (kind == "scout_troop" and not leader)
	var shirt := CLOTH[rng.randi() % CLOTH.size()]
	var pants := PANTS[rng.randi() % PANTS.size()]
	var hat := HATS[rng.randi() % HATS.size()]
	var pack := PACKS[rng.randi() % PACKS.size()]
	var scarf := false
	if kind == "scout_troop":
		shirt = Color(0.78, 0.7, 0.45)
		pants = Color(0.4, 0.42, 0.3)
		hat = "visitor_hat_beanie" if not leader else "visitor_hat_wide"
		pack = "visitor_pack_small" if not leader else "visitor_pack_big"
		scarf = true
	elif guide:
		shirt = Color(0.3, 0.5, 0.3)
		pants = Color(0.45, 0.38, 0.3)
		hat = "visitor_hat_wide"
		pack = ""
	elif kind == "campers":
		pack = "visitor_pack_big"
	elif kind == "anglers":
		hat = "visitor_hat_wide"
	var layers := [["visitor_body", SKIN[rng.randi() % SKIN.size()]], ["visitor_hair", HAIR[rng.randi() % HAIR.size()]], ["visitor_pants", pants], ["visitor_shirt", shirt]]
	if scarf:
		layers.append(["visitor_scarf", Color(0.2, 0.55, 0.3)])
	if pack != "":
		layers.append([pack, Color(0.55, 0.4, 0.3).lerp(shirt, 0.3)])
	if hat != "":
		layers.append([hat, CLOTH[rng.randi() % CLOTH.size()]])
	for l: Array in layers:
		var spr := Sprite2D.new()
		spr.centered = false
		spr.texture = Art.texture(l[0])
		spr.hframes = 4
		spr.vframes = 4
		# Hair and hats can sit a pixel higher than drawn, to clear the eyes.
		var lift := float((session.tuning.value("look.visitor_layer_lift") as Dictionary).get(l[0], 0))
		spr.offset = Vector2(-8, -24 - lift)
		spr.modulate = l[1]
		node.add_child(spr)
	if kid:
		node.scale = Vector2(0.8, 0.8)
	node.set_meta("jitter", Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.25, 0.25)))
	return node


## Where one person of a party stands, and which way they face.
func _pose(node: Node2D, p: Dictionary, i: int) -> void:
	var pos: Vector2 = p["pos"]
	var state: String = p["state"]
	var path: PackedVector2Array = p["path"]
	var dir := Vector2.DOWN
	var pi := int(p["pi"])
	if state == "walk" and pi < path.size():
		var d := path[pi] - pos
		if d.length() > 0.01:
			dir = d.normalized()
	var jit: Vector2 = node.get_meta("jitter")
	var at := pos
	var walking := state == "walk"
	if walking:
		# A loose line behind the leader.
		at = pos - dir * (0.75 * i) + Vector2(-dir.y, dir.x) * jit.x
	elif state == "camp" and str(p["home"]) != "" and str(p["home"]) != "cabin":
		var c := session.park.pad_center(str(p["home"]))
		var a := TAU * float(i) / maxf(1.0, float(p["size"]))
		at = c + Vector2(cos(a), sin(a) * 0.6) * 1.6
	else:
		var a := TAU * float(i) / maxf(1.0, float(p["size"]) + float(p["guide"]))
		at = pos + Vector2(cos(a), sin(a) * 0.6) * (0.4 + 0.25 * float(i % 3)) + jit
	_place(node, at + Vector2(0.0, 0.5))
	var row := 0
	if absf(dir.x) > absf(dir.y):
		row = 1 if dir.x > 0.0 else 3
	else:
		row = 0 if dir.y > 0.0 else 2
	var frame := 0
	if walking:
		frame = int(_time * 6.0 + i) % 4
	for c: Node in node.get_children():
		(c as Sprite2D).frame = row * 4 + frame
