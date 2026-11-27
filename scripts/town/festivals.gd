class_name Festivals
extends RefCounted
## Phase 4b, step 12: the four festivals, one each season in the town square
## (Phase 4 Spec, Festivals).
##
## On festival day the square is dressed all day. During the festival's hours,
## walking into the square starts it: everyone is there, at their spots, and
## time stands still until the ranger walks out again, when the clock jumps
## to the festival's end. Skipping one costs nothing; it comes round next
## year, with its stall's stock a little different.
##
## Each festival has a gentle activity, chosen at its spot with X (the
## festival year was reworked in 0.8.6):
## - Spring, Lantern Night: choose a lantern's colour and a wish; someone
##   answers it.
## - Summer, Midsummer: tuck something into the wicker moose for luck; it's
##   lit, and then Agnes tells a story. Everyone wears a flower crown.
## - Autumn, Samhain: carve a pumpkin (one you grew yourself wins Best
##   Pumpkin), bob for apples, and take sweets from the bowls. The town is in
##   costume.
## - Winter, the Big Foot Supper: judge the look-alike contest; the supper
##   table restores full energy and warmth.

var _s: WeakRef
var content: ContentDB
var tuning: Tuning
var active: String = ""          # the festival the ranger is at now
var attended: Dictionary = {}    # "id:year" -> true
var done: Dictionary = {}        # "id:year:what" -> value (entry, colour, wish, winner, gave, supper)


func _init(session: GameSession) -> void:
	_s = weakref(session)
	content = session.content
	tuning = session.tuning


func s() -> GameSession:
	return _s.get_ref()


## What the ranger wears on top for the festival on now: the judge's sash
## at the Big Foot Supper (Mark's Art Request 23, facing down only), a
## flower crown at Midsummer.
func overlay() -> String:
	match active:
		"big_foot_supper":
			return "ranger_wear_sash"
		"midsummer":
			return "ranger_wear_crown"
	return ""


func row(id: String) -> Dictionary:
	return content.row("festivals", id)


func name_of(id: String) -> String:
	return content.text(str(row(id)["name"]))


## Today's festival row, or {}.
func today() -> Dictionary:
	var c := s().clock
	for r: Dictionary in content.rows("festivals"):
		if int(r["season"]) == c.season and int(r["day"]) == c.day:
			return r
	return {}


## Whether today's festival is on at this minute.
func on_now(minute: int = -1) -> bool:
	var r := today()
	if r.is_empty():
		return false
	if minute < 0:
		minute = s().clock.minute
	return minute >= int(r["start"]) and minute < int(r["end"])


func _key(id: String, what: String = "") -> String:
	var k := "%s:%d" % [id, s().clock.year]
	return k if what == "" else k + ":" + what


func been_this_year(id: String) -> bool:
	return attended.has(_key(id))


func in_area(id: String, pos: Vector2) -> bool:
	var a: Array = row(id)["area"]
	return pos.x >= float(a[0]) and pos.y >= float(a[1]) and pos.x < float(a[2]) + 1.0 and pos.y < float(a[3]) + 1.0


## Looked at as the ranger moves about town: starts the festival on walking
## into the square in its hours, ends it on walking out.
func update() -> void:
	var g := s()
	if active != "":
		if not g.in_town or g.in_town_room() or not in_area(active, g.town_pos):
			end()
		return
	if not g.in_town or g.in_town_room() or not on_now():
		return
	var r := today()
	if been_this_year(str(r["id"])) or not in_area(str(r["id"]), g.town_pos):
		return
	start(str(r["id"]))


func start(id: String) -> void:
	var g := s()
	active = id
	g.town.place_everyone()
	g.message.emit(content.text("fest_start", {"name": name_of(id)}))
	g.clothes_changed.emit()   # the judge's sash, at the Big Foot Supper


## Out of the square: the clock jumps to the festival's end.
func end() -> void:
	if active == "":
		return
	var g := s()
	var id := active
	active = ""
	attended[_key(id)] = true
	g.clothes_changed.emit()
	var to := int(row(id)["end"])
	if g.clock.minute < to:
		g.clock.set_minute(to)
		g.park.advance_to(float(g.clock.minute))
		g.weather.check_change(g.clock.minute)
	g.town.people = {}
	g.message.emit(content.text("fest_end", {"name": name_of(id), "time": g.clock.time_text()}))


## Where a person stands at the festival: the contest's line-up at the Big
## Foot Supper, otherwise their own spot round the square.
func spot_of(person: String) -> Vector2i:
	var r := row(active if active != "" else str(today().get("id", content.ids("festivals")[0])))
	var cont: Array = r.get("contestants", [])
	if cont.has(person):
		var c: Array = r["contest_spots"][cont.find(person)]
		return Vector2i(int(c[0]), int(c[1]))
	var spots: Array = r["spots"]
	var i := content.ids("townsfolk").find(person)
	var p: Array = spots[posmod(i, spots.size())]
	return Vector2i(int(p[0]), int(p[1]))


## Whether a person is in the Bigfoot suit now.
func in_suit(person: String) -> bool:
	return active == "big_foot_supper" and (row(active).get("contestants", []) as Array).has(person)


## A person's Samhain costume now ("ghost", "witch", "skeleton"), or "".
func costume_of(person: String) -> String:
	if active == "" or not row(active).has("costumes"):
		return ""
	return str((row(active)["costumes"] as Dictionary).get(person, ""))


## Whether everyone is in a flower crown now (Midsummer).
func crowned() -> bool:
	return active != "" and bool(row(active).get("crowns", false))


## The wicker moose today: "" (not Midsummer), "standing" until the ranger
## has given it something, "burning" from then, "embers" once it's over.
func moose_stage() -> String:
	var r := today()
	if r.is_empty() or not r.has("moose"):
		return ""
	var id := str(r["id"])
	if done.has(_key(id, "gave")):
		return "burning" if active == id else "embers"
	return "standing"


## Park visitors double on a festival's weekend and pick up the week before.
func visitor_mult() -> float:
	var c := s().clock
	var today_abs := c.absolute_day()
	var dps := c.days_per_season()
	for r: Dictionary in content.rows("festivals"):
		var f := (c.year - 1) * dps * 4 + int(r["season"]) * dps + int(r["day"])
		var d := f - today_abs
		var wd := s().town.weekday()
		if absi(d) <= 3 and (wd == "sat" or wd == "sun" or d == 0):
			return tuning.num("festivals.visitor_mult_weekend")
		if d > 0 and d <= 7:
			return tuning.num("festivals.visitor_mult_week_before")
	return 1.0


# --- the spots in the square ----------------------------------------------------

func _near(key: String, pos: Vector2, reach: float = 1.8) -> bool:
	if active == "":
		return false
	var r := row(active)
	if not r.has(key):
		return false
	var p: Array = r[key]
	return pos.distance_to(Vector2(float(p[0]) + 0.5, float(p[1]) + 0.5)) <= reach


## What X does at the festival here: "activity", "stall", "supper",
## "apples", "sweets:<bowl>" or "".
func spot_here(pos: Vector2) -> String:
	if _near("supper", pos, 2.2):
		return "supper"
	if _near("activity", pos, 2.0):
		return "activity"
	if _near("apples", pos, 1.6):
		return "apples"
	if active != "":
		var bowls: Array = row(active).get("sweets", [])
		for i in bowls.size():
			var b: Array = bowls[i]
			if pos.distance_to(Vector2(float(b[0]) + 0.5, float(b[1]) + 0.5)) <= 1.4:
				return "sweets:%d" % i
	if _near("stall", pos, 2.0):
		return "stall"
	return ""


func stall_stock() -> Array:
	var r := row(active)
	return r.get("sells_alt", r["sells"]) if s().clock.year % 2 == 0 else r["sells"]


func stall_options() -> Array:
	var out := []
	var wallet := s().park.money.wallet
	for it: Dictionary in stall_stock():
		var item := str(it["item"])
		out.append({"id": "buy:" + item, "label": content.text("shop_buy_line", {"name": content.item_name(item), "what": "", "price": int(it["price"])}).replace("  ·    ·  ", "  ·  "), "enabled": int(it["price"]) <= wallet})
	out.append({"id": "back", "label": content.text("shop_back")})
	return out


func buy(item: String) -> void:
	var g := s()
	for it: Dictionary in stall_stock():
		if str(it["item"]) == item:
			var price := int(it["price"])
			if not g.park.money.can_afford(price):
				g.message.emit(content.text("shop_cant_afford"))
				return
			if g.backpack.room_for(item) < 1:
				g.message.emit(content.text("shop_no_room"))
				return
			g.park.money.spend(g.clock.absolute_day(), "shops", price)
			g.backpack.add(item, 1)
			g.message.emit(content.text("shop_bought", {"item": content.item_name(item).to_lower(), "price": price}))
			return


# --- the activities ---------------------------------------------------------------

## The next choice the activity asks for: {kind, title, options}, or
## {"text": ...} when it's done.
func activity() -> Dictionary:
	var g := s()
	match active:
		"samhain":
			if done.has(_key(active, "carved")):
				return {"text": content.text("fest_carve_done")}
			var opts := []
			for f: Variant in row(active)["faces"]:
				opts.append({"id": str(f), "label": content.text("face_" + str(f))})
			return {"kind": "fest:carve", "title": content.text("fest_carve_title"), "options": opts}
		"lantern_night":
			if not done.has(_key(active, "colour")):
				var opts := []
				for c: String in ["red", "orange", "yellow", "green", "blue", "violet"]:
					opts.append({"id": c, "label": content.text("lantern_" + c)})
				return {"kind": "fest:colour", "title": content.text("fest_lantern_title"), "options": opts}
			if not done.has(_key(active, "wish")):
				var opts := []
				for w: String in ["park", "friend", "self", "town"]:
					opts.append({"id": w, "label": content.text("wish_" + w)})
				return {"kind": "fest:wish", "title": content.text("fest_wish_title"), "options": opts}
			return {"text": content.text("fest_lantern_done")}
		"big_foot_supper":
			if done.has(_key(active, "winner")):
				return {"text": content.text("fest_bigfoot_done", {"name": g.shops.first_name(str(done[_key(active, "winner")]))})}
			var opts := []
			for p: Variant in row(active)["contestants"]:
				opts.append({"id": str(p), "label": "%s: %s" % [g.shops.first_name(str(p)), content.text("bigfoot_" + str(p))]})
			return {"kind": "fest:winner", "title": content.text("fest_bigfoot_title"), "options": opts}
		"midsummer":
			if done.has(_key(active, "gave")):
				return {"text": content.text("fest_bonfire_done")}
			var opts := [{"id": "_word", "label": content.text("fest_bonfire_word")}]
			var seen := {}
			for i in g.backpack.slots.size():
				var item := g.backpack.item_at(i)
				if item == "" or seen.has(item) or g.town.taste("agnes", item) == "no":
					continue
				seen[item] = true
				opts.append({"id": item, "label": content.item_name(item)})
			return {"kind": "fest:gave", "title": content.text("fest_bonfire_title"), "options": opts}
	return {}


## Samhain's apple bobbing: the choice of apple, once a year.
func apples() -> Dictionary:
	if done.has(_key(active, "apples")):
		return {"text": content.text("fest_apples_done")}
	var opts := []
	for k: String in ["red", "green", "deep"]:
		opts.append({"id": k, "label": content.text("apple_" + k)})
	return {"kind": "fest:apples", "title": content.text("fest_apples_title"), "options": opts}


## Trick or treat: a handful of sweets from each bowl, once a year.
func sweets(bowl: int) -> String:
	var g := s()
	var k := _key(active, "sweets%d" % bowl)
	if done.has(k):
		return content.text("fest_sweets_done")
	if g.backpack.room_for("sweets") < 1:
		return content.text("shop_no_room")
	done[k] = true
	g.backpack.add("sweets", 1)
	return content.text("fest_sweets")


## Answers a pick. Returns the lines to show (several paragraphs).
func choose(kind: String, option: String) -> String:
	var g := s()
	var out := PackedStringArray()
	match kind:
		"fest:carve":
			if not (row(active)["faces"] as Array).has(option):
				return ""
			done[_key(active, "carved")] = option
			# A pumpkin the ranger grew wins Best Pumpkin; the town's own
			# pumpkins get kind words.
			var own := g.backpack.has("pumpkin")
			if own:
				g.backpack.remove("pumpkin", 1)
			out.append(content.text("fest_carve_own" if own else "fest_carve_town"))
			for j: Variant in row(active)["judges"]:
				out.append("%s: %s" % [g.shops.first_name(str(j)), content.text("judge_%s_face_%s" % [j, option])])
				g.town.add_points(str(j), tuning.integer("festivals.judge_points"))
			out.append(content.text("fest_carve_rival"))
			if own:
				out.append(content.text("fest_carve_win"))
				g.park.money.earn(g.clock.absolute_day(), "budget", int(row(active)["prize_money"]))
				prize()
			else:
				out.append(content.text("fest_carve_lose"))
			out.append(content.text("fest_carve_keep"))
			g.life.give_keepsake("decor_jack_" + option)
		"fest:apples":
			if done.has(_key(active, "apples")):
				return ""
			done[_key(active, "apples")] = option
			out.append(content.text("fest_apples_" + option))
			if g.backpack.room_for("apple") >= 1:
				g.backpack.add("apple", 1)
		"fest:colour":
			done[_key(active, "colour")] = option
			return content.text("fest_lantern_set", {"colour": content.text("lantern_" + option).to_lower()})
		"fest:wish":
			done[_key(active, "wish")] = option
			out.append(content.text("wish_reply_" + option, {"name": g.shops.first_name(_answerer())}))
			prize()
		"fest:winner":
			done[_key(active, "winner")] = option
			g.town.add_points(option, tuning.integer("festivals.bigfoot_points"))
			out.append(content.text("fest_bigfoot_win", {"name": g.shops.first_name(option)}))
			prize()
		"fest:gave":
			done[_key(active, "gave")] = option
			if option == "_word":
				out.append(content.text("fest_bonfire_gave_word"))
			else:
				g.backpack.remove(option, 1)
				out.append(content.text("fest_bonfire_gave", {"item": content.item_name(option).to_lower()}))
			var story := content.text(story_id())
			out.append(content.text("fest_story_title") + "\n" + story)
			g.park.add_note(story, "story")
			prize()
	return "\n\n".join(out)


## Whose kind line answers the wish: the friend the ranger knows best.
func _answerer() -> String:
	var g := s()
	var best := "agnes"
	var most := -1
	for id: String in content.ids("townsfolk"):
		if id == "pip":
			continue
		if g.town.points(id) > most:
			most = g.town.points(id)
			best = id
	return best


## Midsummer's story this year: a new one each year, then round again.
func story_id() -> String:
	var n := 0
	while content.has("text", "fest_story_%d" % (n + 1)):
		n += 1
	return "fest_story_%d" % (posmod(s().clock.year - 1, maxi(1, n)) + 1)


func prize() -> void:
	var item := str(row(active).get("prize_item", ""))
	if item != "" and not done.has(_key(active, "prize")):
		done[_key(active, "prize")] = item
		s().life.give_keepsake(item)


## The supper table: full energy and warmth, once.
func supper() -> String:
	var g := s()
	if done.has(_key(active, "supper")):
		return content.text("fest_supper_done")
	done[_key(active, "supper")] = true
	g.needs.add_energy(g.needs.max_energy())
	g.needs.add_warmth(g.needs.max_warmth())
	return content.text("fest_supper")


# --- saving -------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"active": active, "attended": attended.keys(), "done": done.duplicate()}


func from_dict(d: Dictionary) -> void:
	attended = {}
	for k: Variant in d.get("attended", []):
		attended[str(k)] = true
	done = {}
	for k: String in d.get("done", {}):
		done[k] = d["done"][k]
	active = str(d.get("active", ""))


func new_game() -> void:
	from_dict({})
