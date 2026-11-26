class_name Pet
extends RefCounted
## Phase 5a (Phase 5 Spec, A pet): the dog or the cat.
##
## The Chief's letter offers both; the ranger picks one (a game saved before
## Phase 5 gets the same letter). The pet lives at the station: its water
## bowl stands by the door, to be filled each day, and X on the pet pets it
## (once a day, for friendship), then tells it to come along or stay home.
## A pet along walks a little behind the ranger and waits outside doors.
##
## How each helps, in Phase 5a:
##   dog: stops and barks once near a find not yet found; with a lost party
##        in the park, says which way to look.
##   cat: shy animals let you come twice as close; after dark the lantern's
##        light reaches a little further; it stares at a strange cousin near
##        by.

var _s: WeakRef
var tuning: Tuning
var kind: String = ""           # "", "dog" or "cat"
var name: String = ""
var points: int = 0
var petted_day: int = -1
var bowl_day: int = -1           # the day the bowl was last filled
var along: bool = false
var offered: bool = false        # the letter has been offered this game
var pos: Vector2 = Vector2.INF
var facing: int = 0
var moving: bool = false
var _sniffed: Dictionary = {}    # find tile key -> day
var _stared: Dictionary = {}     # cousin seed -> true
var _hint_wait: float = 0.0


func _init(session: GameSession) -> void:
	_s = weakref(session)
	tuning = session.tuning


func s() -> GameSession:
	return _s.get_ref()


func has_pet() -> bool:
	return kind != ""


## The Chief's letter comes from summer of the first year (0.8.2: not on
## the first morning, when there's enough to learn already).
func offer_due() -> bool:
	var c := s().clock
	return c.year > 1 or c.season >= tuning.integer("pet.offer_from_season")


## The options for the Chief's letter.
func offer_options() -> Array:
	var c := s().content
	return [{"id": "dog", "label": c.text("pet_pick_dog", {"name": default_name("dog")})}, {"id": "cat", "label": c.text("pet_pick_cat", {"name": default_name("cat")})}]


func default_name(k: String) -> String:
	return str((tuning.value("pet.names") as Dictionary).get(k, k.capitalize()))


func choose(k: String) -> void:
	if k not in ["dog", "cat"]:
		return
	kind = k
	name = default_name(k)
	offered = true
	pos = home_spot()
	s().message.emit(s().content.text("pet_chosen_" + k, {"name": name}))


## Where the pet waits at home: beside the station door.
## Its bed: round the east side of the station, past the mailbox, well
## clear of the door (0.8.2: by the door, X kept patting it instead of
## going in).
func home_spot() -> Vector2:
	return s().mailbox_pos() + tuning_vec("pet.home_from_mailbox")


## The water bowl, beside its bed.
func bowl_spot() -> Vector2:
	return s().mailbox_pos() + tuning_vec("pet.bowl_from_mailbox")


func tuning_vec(key: String) -> Vector2:
	var a: Array = tuning.value(key)
	return Vector2(float(a[0]), float(a[1]))


func hearts() -> int:
	return mini(10, points / tuning.integer("pet.hearts_points"))


func morning() -> void:
	var g := s()
	if not has_pet():
		# Not chosen yet: the letter comes again.
		offered = false
		return
	if bowl_day == g.clock.absolute_day() - 1:
		points += tuning.integer("pet.bowl_points")
	along = false
	pos = home_spot()


# --- in the world ------------------------------------------------------------------------

func update(dt: float) -> void:
	var g := s()
	if not has_pet():
		return
	if pos == Vector2.INF:
		pos = home_spot()
	moving = false
	if not along or g.is_indoors() or g.in_town:
		if not along:
			pos = home_spot()
		return
	var to := g.outdoor_pos - pos
	var keep := tuning.num("pet.follow_tiles")
	if to.length() > 12.0:
		pos = g.outdoor_pos - to.normalized() * keep
	elif to.length() > keep:
		var step := minf(to.length() - keep, tuning.num("pet.speed") * dt)
		pos += to.normalized() * step
		moving = step > 0.001
		facing = Wildlife._facing_of(to)
	_hint_wait -= dt
	if _hint_wait <= 0.0:
		_hint_wait = 1.0
		_help()


func _help() -> void:
	var g := s()
	if kind == "dog":
		var r := tuning.num("pet.dog_sniff_tiles")
		var finds: Dictionary = g.world.meta.get("finds", {})
		for fid: String in finds:
			var t := Vector2i(int(finds[fid][0]), int(finds[fid][1]))
			if g.finds_found.has(fid):
				continue
			var key := fid
			if g.outdoor_pos.distance_to(Vector2(t)) <= r and int(_sniffed.get(key, -1)) != g.clock.absolute_day():
				_sniffed[key] = g.clock.absolute_day()
				g.message.emit(g.content.text("pet_dog_sniff", {"name": name}))
				return
		var lp: Dictionary = g.park.lost_party()
		if not lp.is_empty() and int(_sniffed.get("lost", -1)) != g.clock.absolute_day():
			_sniffed["lost"] = g.clock.absolute_day()
			var v: Vector2 = (g.park.lost["center"] as Vector2) - g.outdoor_pos
			var dir: String = ["dir_e", "dir_se", "dir_s", "dir_sw", "dir_w", "dir_nw", "dir_n", "dir_ne"][posmod(int(round(v.angle() / (PI / 4.0))), 8)]
			g.message.emit(g.content.text("pet_dog_lost", {"name": name, "dir": g.content.text(dir)}))
	else:
		var r := tuning.num("pet.cat_stare_tiles")
		for a: Dictionary in g.wildlife.visible_animals():
			if str(a["id"]) == str(a["kind"]):
				continue
			if Vector2(a["pos"]).distance_to(g.outdoor_pos) <= r and not _stared.has(int(a["seed"])):
				_stared[int(a["seed"])] = true
				g.message.emit(g.content.text("pet_cat_stare", {"name": name}))
				return


func in_reach(p: Vector2, reach: float) -> bool:
	return has_pet() and pos != Vector2.INF and p.distance_to(pos) <= reach + 0.6


func bowl_in_reach(p: Vector2, reach: float) -> bool:
	return has_pet() and p.distance_to(bowl_spot()) <= reach + 0.6


## X on the pet: a pat first each day, then come along or stay.
func touch() -> String:
	var g := s()
	if petted_day != g.clock.absolute_day():
		petted_day = g.clock.absolute_day()
		points += tuning.integer("pet.pet_points")
		g.skills.act("pet")
		g.message.emit(g.content.text("pet_petted_" + kind, {"name": name}))
		return "petted"
	along = not along
	g.message.emit(g.content.text("pet_along" if along else "pet_stay", {"name": name}))
	return "along" if along else "stay"


func fill_bowl() -> bool:
	var g := s()
	if bowl_day == g.clock.absolute_day():
		g.message.emit(g.content.text("pet_bowl_full", {"name": name}))
		return false
	bowl_day = g.clock.absolute_day()
	g.message.emit(g.content.text("pet_bowl_filled", {"name": name}))
	return true


func give_treat() -> bool:
	var g := s()
	if not g.backpack.remove("pet_treat", 1):
		return false
	points += tuning.integer("pet.treat_points")
	g.message.emit(g.content.text("pet_treat", {"name": name}))
	return true


## The cat's night eyes: the lantern reaches a little further.
func lantern_add() -> float:
	var g := s()
	if kind == "cat" and along and g.wildlife.is_night():
		return tuning.num("pet.cat_night_lantern_add")
	return 0.0


func to_dict() -> Dictionary:
	return {"kind": kind, "name": name, "points": points, "petted": petted_day, "bowl": bowl_day, "offered": offered}


func from_dict(d: Dictionary) -> void:
	kind = str(d.get("kind", ""))
	name = str(d.get("name", ""))
	points = int(d.get("points", 0))
	petted_day = int(d.get("petted", -1))
	bowl_day = int(d.get("bowl", -1))
	offered = bool(d.get("offered", false))
	along = false
	pos = Vector2.INF
