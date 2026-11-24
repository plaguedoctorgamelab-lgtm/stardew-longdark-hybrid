class_name HeartEvents
extends RefCounted
## Phase 4b, steps 9 and 10: heart events and romance (Phase 4 Spec, Romance;
## the outlines are in the spoiler addendum).
##
## A heart event is a short scene in the content table spoiler_heart_events.
## It plays once, when the ranger walks into its place during its hours with
## the hearts reached and the person's earlier events seen. Because hours come
## round every day, no event can be missed for good. The scene's lines,
## pauses, walks and choices are played by ScenePlayer; the steps that change
## the game (a keepsake, friendship, a notebook line, a flag) are applied here
## as the scene reaches them, so a test can play a scene straight through.
##
## Romance: a bouquet given at 8 hearts to Wren, Teo, Nell or Sol starts
## dating, which lifts their cap to 10 hearts, opens their 10-heart event and
## their dating lines, and sometimes leaves a gift in the station's mailbox.
## "Just friends" ends it at any time; the hearts stay.

signal scene_started(id: String)

const PLACE_KINDS: Array[String] = ["room", "town", "park"]

var _s: WeakRef
var content: ContentDB
var tuning: Tuning
var seen: Dictionary = {}        # event id -> absolute day it played
var dating: Dictionary = {}      # person -> true
var flags: Dictionary = {}       # what events opened: "archive"
var mail_gifts: Array = []       # [person, item] waiting in the mailbox
var playing: String = ""         # the event on screen now, or ""
var cast: Dictionary = {}        # person -> true while their scene plays
var _wait: float = 0.0


func _init(session: GameSession) -> void:
	_s = weakref(session)
	content = session.content
	tuning = session.tuning


func s() -> GameSession:
	return _s.get_ref()


func row(id: String) -> Dictionary:
	return content.row("spoiler_heart_events", id)


## A person's events, fewest hearts first.
func events_for(person: String) -> Array:
	var out := content.rows("spoiler_heart_events").filter(func(r: Dictionary) -> bool: return str(r["person"]) == person)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["hearts"]) < int(b["hearts"]))
	return out


# --- when an event can play -----------------------------------------------------

## Whether the ranger is at an event's place: "room:<town room>", "town:<town
## place>" (outdoors, near it), or "park:<station|porch|gate|outlook|tower|
## tower_or_outlook>".
func at(where: String) -> bool:
	var g := s()
	var kind := where.get_slice(":", 0)
	var id := where.get_slice(":", 1)
	match kind:
		"room":
			return g.in_town_room() and g.town_inside == id
		"town":
			if not g.in_town or g.in_town_room() or not g.town.places.has(id):
				return false
			var p: Vector2i = g.town.places[id]
			return g.town_pos.distance_to(Vector2(p) + Vector2(0.5, 0.5)) <= tuning.num("heart_events.place_reach_tiles")
		"park":
			if g.in_town:
				return false
			var reach := tuning.num("heart_events.park_reach_tiles")
			match id:
				"station":
					return g.location == "ranger_station"
				"porch":
					return g.location == "" and g.outdoor_pos.distance_to(g.door_front("ranger_station")) <= reach
				"gate":
					return g.location == "" and g.outdoor_pos.distance_to(g.gate_front()) <= reach
				"outlook":
					return g.location == "" and g.outdoor_pos.distance_to(g.site_pos("outlook")) <= tuning.num("heart_events.outlook_reach_tiles")
				"tower":
					return g.location == "static_tower" and g.sites_open.has("static_tower")
				"tower_or_outlook":
					return at("park:tower") if g.sites_open.has("static_tower") else at("park:outlook")
	return false


func time_ok(r: Dictionary, minute: int) -> bool:
	return minute >= int(r["from"]) and minute < int(r["to"])


## The weather, weekday, festival and dating an event asks for.
func conditions_ok(r: Dictionary) -> bool:
	var g := s()
	if r.has("weather"):
		var wet: bool = g.town._rainy()
		if (str(r["weather"]) == "rain") != wet:
			return false
	if r.has("day") and g.town.weekday() != str(r["day"]):
		return false
	if bool(r.get("festival_day", false)) and g.festivals.today().is_empty():
		return false
	if bool(r.get("dating", false)) and not dating.has(str(r["person"])):
		return false
	return true


## Whether an event is next for its person: not yet seen, the hearts there,
## the earlier events seen, and what it asks for true (not its place or time).
func ready(id: String) -> bool:
	if seen.has(id) or not content.has("spoiler_heart_events", id):
		return false
	var r := row(id)
	var who := str(r["person"])
	if s().town.hearts(who) < int(r["hearts"]):
		return false
	for e: Dictionary in events_for(who):
		if int(e["hearts"]) < int(r["hearts"]) and not seen.has(str(e["id"])):
			return false
	return conditions_ok(r)


## The event that would start here and now, or "".
func due() -> String:
	var g := s()
	for r: Dictionary in content.rows("spoiler_heart_events"):
		var id := str(r["id"])
		if not time_ok(r, g.clock.minute) or not ready(id) or not at(str(r["where"])):
			continue
		# At a festival only a festival-day event breaks in.
		if g.festivals.active != "" and not bool(r.get("festival_day", false)):
			continue
		return id
	return ""


## Looked at as the ranger moves: starts the event due here, if any. Not
## while a screen is open (the clock is paused) or another scene plays.
func check(delta: float = 1.0) -> String:
	var g := s()
	_wait -= delta
	if _wait > 0.0:
		return ""
	_wait = 0.5
	if playing != "" or g.clock.paused or g.pending_confirm != "":
		return ""
	var id := due()
	if id != "":
		start(id)
	return id


func start(id: String) -> void:
	playing = id
	cast = {}
	var r := row(id)
	for c: Array in r.get("cast", [[r["person"], 0, -1]]):
		cast[str(c[0])] = true
	scene_started.emit(id)


## A step that changes the game, as the scene reaches it.
func apply_step(id: String, step: Array) -> void:
	var g := s()
	var who := str(row(id)["person"])
	match str(step[0]):
		"give":
			give_keepsake(str(step[1]))
		"pts":
			g.town.add_points(who, int(step[1]))
		"note":
			g.park.add_note(str(step[1]), "heart")
		"flag":
			flags[str(step[1])] = true


## A keepsake from an event: clothes to the spare rail, anything else to the
## backpack, or the station chest if the backpack is full.
func give_keepsake(item: String) -> void:
	var g := s()
	if not content.has("items", item):
		return
	var name := content.item_name(item)
	if g.wardrobe.is_clothing(item):
		g.wardrobe.keep(item)
		g.clothes_changed.emit()
	elif g.backpack.add(item, 1) > 0:
		(g.structures.chests["ranger_station"] as Inventory).add(item, 1)
		g.message.emit(content.text("fest_prize_chest", {"item": name}))
		return
	g.message.emit(content.text("fest_prize", {"item": name}))


func finish(id: String) -> void:
	if id == "":
		return
	seen[id] = s().clock.absolute_day()
	s().town.met[str(row(id)["person"])] = true
	if playing == id:
		playing = ""
	cast = {}


## The steps a scene takes with these choices (the first option where none
## is given), choices opened in place. For tests and the debug panel.
static func flatten(steps: Array, picks: Array = []) -> Array:
	var out := []
	var left := picks.duplicate()
	var queue := steps.duplicate()
	while not queue.is_empty():
		var st: Array = queue.pop_front()
		if str(st[0]) == "choice":
			var opts: Array = st[1]
			var i: int = int(left.pop_front()) if not left.is_empty() else 0
			i = clampi(i, 0, opts.size() - 1)
			var then: Array = (opts[i] as Array)[1]
			queue = then + queue
			continue
		out.append(st)
	return out


## Plays an event at once, applying what it changes.
func play_through(id: String, picks: Array = []) -> void:
	for st: Array in flatten(row(id)["steps"], picks):
		apply_step(id, st)
	finish(id)


# --- romance ----------------------------------------------------------------------

func can_date(person: String) -> bool:
	return content.has("townsfolk", person) and bool(content.row("townsfolk", person).get("romance", false))


## Gives the bouquet in the backpack. Returns the text id of what happened.
func give_bouquet(person: String) -> String:
	var g := s()
	if not can_date(person):
		return "romance_not_them"
	if dating.has(person):
		return "romance_already"
	if g.town.hearts(person) < tuning.integer("romance.hearts_before_dating"):
		return "romance_not_yet"
	if not g.backpack.remove("bouquet", 1):
		return ""
	dating[person] = true
	g.town.met[person] = true
	return "romance_accept"


## "I think we should just be friends." The hearts stay; dating ends.
func end_dating(person: String) -> bool:
	if not dating.has(person):
		return false
	dating.erase(person)
	return true


## Each morning, a sweetheart may leave a small gift in the mailbox.
func morning() -> void:
	var g := s()
	var gifts: Dictionary = tuning.value("romance.gifts")
	for p: String in dating:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%s:%d" % [g.seed_value, p, g.clock.absolute_day()])
		if rng.randf() < tuning.num("romance.mailbox_gift_chance") and gifts.has(p):
			var list: Array = gifts[p]
			mail_gifts.append([p, str(list[rng.randi_range(0, list.size() - 1)])])


## Takes the gifts from the mailbox into the backpack; the lines to show.
func take_mail_gifts() -> PackedStringArray:
	var g := s()
	var out := PackedStringArray()
	for e: Array in mail_gifts:
		var item := str(e[1])
		if g.backpack.add(item, 1) > 0:
			(g.structures.chests["ranger_station"] as Inventory).add(item, 1)
		out.append(content.text("romance_gift_mail", {"name": g.shops.first_name(str(e[0])), "item": content.item_name(item).to_lower()}))
	mail_gifts.clear()
	return out


# --- saving -------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"seen": seen.duplicate(), "dating": dating.keys(), "flags": flags.keys(), "mail": mail_gifts.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	seen = {}
	for k: String in d.get("seen", {}):
		seen[k] = int(d["seen"][k])
	dating = {}
	for k: Variant in d.get("dating", []):
		dating[str(k)] = true
	flags = {}
	for k: Variant in d.get("flags", []):
		flags[str(k)] = true
	mail_gifts = []
	for e: Variant in d.get("mail", []):
		mail_gifts.append([str((e as Array)[0]), str((e as Array)[1])])
	playing = ""
	cast = {}


func new_game() -> void:
	from_dict({})
