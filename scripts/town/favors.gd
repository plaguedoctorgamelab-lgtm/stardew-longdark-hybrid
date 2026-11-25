class_name Favors
extends RefCounted
## Where Townsfolk Favors come from (Phase 4, 4a step 7). The jobs system
## holds the favors themselves; this keeps the three ways they reach the
## ranger:
##   the town notice board: notes pinned up, read to take them all;
##   asked in person: when talked to, someone asks, and "not now" leaves
##     it on offer for a week;
##   the station's mailbox: a letter from someone in town.
## The board is kept stocked with template favors each morning, up to its
## target. A favor that wants something found has it put out on the trail
## as it is taken on.

const LOST_THINGS := ["song_notebook", "lost_mitten", "lost_keys", "lost_locket", "lost_glasses"]

var _s: WeakRef
var board: Array = []            # offers pinned up: {"id"} hand-written, {"tpl", "blanks"} template
var declined: Dictionary = {}    # favor id -> day the ranger said "not now"
var mailbox: Array = []          # favor ids in letters not yet read
var mailed: Dictionary = {}      # favor id -> true: its letter has come
var placed: Dictionary = {}      # job key -> true: its lost thing is out on the trail
var rng := RandomNumberGenerator.new()


func _init(session: GameSession) -> void:
	_s = weakref(session)


func s() -> GameSession:
	return _s.get_ref() as GameSession


func _rows(offer: String) -> Array:
	return s().content.rows("town_favors").filter(func(r: Dictionary) -> bool: return str(r["offer"]) == offer)


func _taken(id: String) -> bool:
	return s().jobs.known.has(id) and not (s().jobs.known[id] as Dictionary).is_empty()


# --- each morning ----------------------------------------------------------------

func morning() -> void:
	var g := s()
	if not g.town_open:
		return
	rng.seed = hash([g.seed_value, g.clock.absolute_day(), "favors"])
	_stock_board()
	for r: Dictionary in _rows("mail"):
		var id := str(r["id"])
		if not mailed.has(id) and not _taken(id) and g.jobs.cond(str(r["appears"])):
			mailed[id] = true
			mailbox.append(id)


func _on_board(id: String) -> bool:
	for o: Dictionary in board:
		if str(o.get("id", "")) == id:
			return true
	return false


func _stock_board() -> void:
	var g := s()
	for r: Dictionary in _rows("board"):
		var id := str(r["id"])
		if not _taken(id) and not _on_board(id) and g.jobs.cond(str(r["appears"])):
			board.append({"id": id})
	# Template favors, up to the board's target, counting those taken on.
	var target := g.tuning.integer("jobs.template_target_townsfolk")
	var have := 0
	for k: String in g.jobs.order:
		if g.jobs.is_active(k) and bool(g.jobs.known[k]["tpl"]) and str(g.jobs.def(k)["type"]) == "townsfolk":
			have += 1
	var keys := {}
	for o: Dictionary in board:
		if o.has("tpl"):
			have += 1
			keys[_tpl_key(o)] = true
	while have < target:
		var cands := []
		for t: Dictionary in g.content.rows("job_templates"):
			if str(t["type"]) != "townsfolk":
				continue
			for b: Dictionary in g.jobs.candidates(str(t["id"])):
				var o := {"tpl": str(t["id"]), "blanks": b}
				var key := _tpl_key(o)
				if not g.jobs.is_active(key) and not keys.has(key):
					cands.append(o)
		if cands.is_empty():
			break
		var pick: Dictionary = cands[rng.randi() % cands.size()]
		board.append(pick)
		keys[_tpl_key(pick)] = true
		have += 1


func _tpl_key(o: Dictionary) -> String:
	return "tpl:%s:%s" % [o["tpl"], str((o["blanks"] as Dictionary).get("_at", ""))]


# --- the board -------------------------------------------------------------------

## Reads the board: every note on it becomes a favor on the clipboard.
func read_board() -> String:
	var g := s()
	if board.is_empty():
		_stock_board()
	var names: PackedStringArray = []
	for o: Dictionary in board:
		var key := ""
		if o.has("id"):
			if g.jobs.add(str(o["id"]), "board"):
				key = str(o["id"])
		else:
			key = g.jobs.draw(str(o["tpl"]), o["blanks"])
		if key != "":
			names.append(str(g.jobs.def(key)["name"]))
			put_out_lost(key)
	board.clear()
	if names.is_empty():
		return g.content.text("fv_board_none")
	return g.content.text("fv_board_new", {"n": names.size(), "names": ", ".join(names)})


## The notes waiting on the board, for its picture.
func notes_up() -> int:
	return board.size()


## A favor on the board that wants this item from this person: takes it on
## (as reading the board would) and returns its key, or "".
func take_for(person: String, item: String) -> String:
	var g := s()
	for o: Dictionary in board.duplicate():
		var steps: Array = []
		var blanks: Dictionary = {}
		if o.has("id"):
			steps = g.content.row("town_favors", str(o["id"]))["steps"]
		else:
			steps = g.content.row("job_templates", str(o["tpl"]))["steps"]
			blanks = o["blanks"]
		for stp: Dictionary in steps:
			if str(stp["kind"]) != "give_to":
				continue
			var who := str(stp["person"]).replace("{person}", str(blanks.get("person", "")))
			var what := str(stp["item"]).replace("{item}", str(blanks.get("item", "")))
			if who != person or what != item:
				continue
			var key := ""
			if o.has("id"):
				if g.jobs.add(str(o["id"]), "board"):
					key = str(o["id"])
			else:
				key = g.jobs.draw(str(o["tpl"]), blanks)
			board.erase(o)
			if key != "":
				put_out_lost(key)
				g.message.emit(g.content.text("fv_taken_on", {"name": str(g.jobs.def(key)["name"])}))
			return key
	return ""


# --- asked in person -------------------------------------------------------------

## A favor this person would ask for now, or "".
func ask_offer(person: String) -> String:
	var g := s()
	for r: Dictionary in _rows("ask"):
		var id := str(r["id"])
		if str(r["from"]) != person or _taken(id):
			continue
		if declined.has(id) and g.clock.absolute_day() < int(declined[id]) + 7:
			continue
		if g.jobs.cond(str(r["appears"])):
			return id
	return ""


func answer(id: String, yes: bool) -> String:
	var g := s()
	var who := g.shops.first_name(str(g.content.row("town_favors", id)["from"]))
	if yes:
		g.jobs.add(id, "asked")
		put_out_lost(id)
		return g.content.text("fv_ask_yes", {"name": who})
	declined[id] = g.clock.absolute_day()
	return g.content.text("fv_ask_no", {"name": who})


# --- the mailbox -----------------------------------------------------------------

func read_mail() -> String:
	var g := s()
	if mailbox.is_empty():
		return g.content.text("fv_mail_none")
	var parts: PackedStringArray = []
	var names: PackedStringArray = []
	for id: String in mailbox:
		if g.jobs.add(id, "mail"):
			names.append(str(g.jobs.def(id)["name"]))
			parts.append(str(g.jobs.def(id)["note"]))
			put_out_lost(id)
	mailbox.clear()
	parts.append(g.content.text("fv_mail_new", {"n": names.size(), "names": ", ".join(names)}))
	return "\n\n".join(parts)


# --- lost things -----------------------------------------------------------------

## Puts a favor's lost thing out on a trail tile, as a little pile to pick
## up, and marks a spot near it on the map (not on it: the ranger looks).
func put_out_lost(key: String) -> void:
	var g := s()
	if placed.has(key) or not g.jobs.known.has(key):
		return
	var d := g.jobs.def(key)
	for stp: Dictionary in d["steps"]:
		if str(stp["kind"]) != "find_thing":
			continue
		var t := _lost_tile(key)
		if t.x < 0:
			return
		var item := str(stp["item"])
		if not g.piles.has(t):
			g.piles[t] = Inventory.new(g.content, g.tuning.integer("storage.pile_slots"))
		(g.piles[t] as Inventory).add(item, 1)
		g.piles_changed.emit()
		var b: Dictionary = g.jobs.known[key]["blanks"]
		var off := Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0))
		b["lost_x"] = t.x
		b["lost_y"] = t.y
		b["lost_cx"] = float(t.x) + 0.5 + off.x
		b["lost_cy"] = float(t.y) + 0.5 + off.y
		g.jobs._defs.erase(key)
		placed[key] = true
		return


## A trail tile on the park road or a trail to an open site.
func _lost_tile(key: String) -> Vector2i:
	var g := s()
	rng.seed = hash([g.seed_value, key])
	var routes: Array[String] = ["fork"]
	var by_site := {"old_cabin": "cabin", "outlook": "outlook", "kettle_pond": "pond", "static_tower": "tower"}
	for id: String in g.sites_open:
		if by_site.has(id):
			routes.append(by_site[id])
	for attempt in 30:
		var pts := g.world.route(routes[rng.randi() % routes.size()])
		if pts.size() < 2:
			continue
		var p := pts[rng.randi_range(1, pts.size() - 1)]
		for r in range(0, 4):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var t := Vector2i(floori(p.x), floori(p.y)) + Vector2i(dx, dy)
					if g.world.ground_at(t) == "trail" and not g.world.is_solid(t) and not g.piles.has(t):
						return t
	return Vector2i(-1, -1)


# --- saving ----------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"board": board.duplicate(true), "declined": declined.duplicate(), "mailbox": mailbox.duplicate(), "mailed": mailed.keys(), "placed": placed.keys()}


func from_dict(d: Dictionary) -> void:
	board = (d.get("board", []) as Array).duplicate(true)
	declined = {}
	for k: String in d.get("declined", {}):
		declined[k] = int(d["declined"][k])
	mailbox = []
	for id: Variant in d.get("mailbox", []):
		mailbox.append(str(id))
	mailed = {}
	for id: Variant in d.get("mailed", []):
		mailed[str(id)] = true
	placed = {}
	for id: Variant in d.get("placed", []):
		placed[str(id)] = true


func new_game() -> void:
	from_dict({})
