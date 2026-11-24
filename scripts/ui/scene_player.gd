class_name ScenePlayer
extends Node
## Plays a heart event (Phase 4b, step 9): a small scene in which the people
## in it walk, face, show a feeling over their heads, speak and pause on cue,
## while the player watches. Lines and choices are shown by the game's talk
## box and choice list (main.gd listens for `line` and `choose`); the steps
## that change the game are handed to HeartEvents as they're reached.
##
## The people stand in whichever view the ranger is in (the town, a room,
## the park, the station), placed beside the ranger by the event's cast.

signal line(person: String, mood: String, text: String)
signal choose(title: String, options: Array)
signal ended(id: String)

const TILE := 16
const WALK_TILES_PER_SECOND := 2.5
const EMOTE_SECONDS := 1.4

var session: GameSession
var id: String = ""
var waiting: String = ""        # "line", "choice", "pause", "walk" or ""
var _queue: Array = []
var _choice: Array = []         # the options of the choice on screen
var _actors: Dictionary = {}    # person -> {node, pos (px), to (px), facing}
var _parent: Node2D
var _timer: float = 0.0
var _time: float = 0.0
var _bubbles: Array = []        # [sprite, seconds left]


func setup(s: GameSession) -> void:
	session = s


func active() -> bool:
	return id != ""


## Starts a scene in `parent` (a view's sorting node), with the ranger at
## `origin` (pixels in that node) facing `facing`.
func start(event_id: String, parent: Node2D, origin: Vector2, facing: int) -> void:
	id = event_id
	_parent = parent
	_queue = (session.life.row(id)["steps"] as Array).duplicate(true)
	_clear_actors()
	var r := session.life.row(id)
	for c: Array in r.get("cast", [[r["person"], 0, -1]]):
		var who := str(c[0])
		if not session.content.has("townsfolk", who):
			continue
		var at := origin + Vector2(float(c[1]), float(c[2])) * TILE
		var node := TownView.person_node(session, session.content.row("townsfolk", who))
		node.z_index = 1
		parent.add_child(node)
		var to_ranger := origin - at
		var f := Town._facing_of(to_ranger) if to_ranger.length() > 1.0 else GameSession.FACING_DOWN
		_actors[who] = {"node": node, "pos": at, "to": at, "facing": f}
		_show(who)
	_next()


func _clear_actors() -> void:
	for a: Dictionary in _actors.values():
		(a["node"] as Node2D).queue_free()
	_actors.clear()
	for b: Array in _bubbles:
		(b[0] as Node2D).queue_free()
	_bubbles.clear()


func _show(who: String) -> void:
	var a: Dictionary = _actors[who]
	var node: Node2D = a["node"]
	node.position = (a["pos"] as Vector2).round()
	var walking: bool = (a["pos"] as Vector2).distance_to(a["to"]) > 0.5
	var frame := int(_time * 6.0) % 4 if walking else 0
	for c: Node in node.get_children():
		if c is Sprite2D and (c as Sprite2D).hframes > 1:
			(c as Sprite2D).frame = int(a["facing"]) * 4 + frame


func _next() -> void:
	while not _queue.is_empty():
		var st: Array = _queue.pop_front()
		match str(st[0]):
			"say":
				waiting = "line"
				line.emit(str(st[1]), str(st[3]) if st.size() > 3 else "neutral", str(st[2]))
				return
			"do":
				waiting = "line"
				line.emit("", "", str(st[1]))
				return
			"emote":
				_emote(str(st[1]), str(st[2]))
				waiting = "pause"
				_timer = 0.5
				return
			"pause":
				waiting = "pause"
				_timer = float(st[1])
				return
			"walk":
				var who := str(st[1])
				if _actors.has(who):
					var a: Dictionary = _actors[who]
					a["to"] = (a["pos"] as Vector2) + Vector2(float(st[2]), float(st[3])) * TILE
					var d: Vector2 = (a["to"] as Vector2) - (a["pos"] as Vector2)
					if d.length() > 0.5:
						a["facing"] = Town._facing_of(d)
						waiting = "walk"
						return
			"face":
				var who := str(st[1])
				if _actors.has(who):
					_actors[who]["facing"] = {"down": 0, "right": 1, "up": 2, "left": 3}.get(str(st[2]), 0)
					_show(who)
			"choice":
				_choice = st[1]
				var opts := []
				for i in _choice.size():
					opts.append({"id": str(i), "label": str((_choice[i] as Array)[0])})
				waiting = "choice"
				choose.emit(session.content.text("scene_next"), opts)
				return
			_:
				session.life.apply_step(id, st)
	_finish()


func _finish() -> void:
	var done := id
	waiting = ""
	session.life.finish(done)
	_clear_actors()
	id = ""
	ended.emit(done)


## The line on screen was read.
func advance() -> void:
	if waiting == "line":
		waiting = ""
		_next()


## An option of the choice on screen was picked.
func pick(i: int) -> void:
	if waiting != "choice":
		return
	waiting = ""
	var opt: Array = _choice[clampi(i, 0, _choice.size() - 1)]
	_queue = (opt[1] as Array).duplicate(true) + _queue
	_next()


func _emote(who: String, e: String) -> void:
	if not _actors.has(who) or not Art.has_picture("emote_" + e):
		return
	var spr := Sprite2D.new()
	spr.texture = Art.texture("emote_" + e)
	spr.position = Vector2(0, -40)
	spr.z_index = 5
	(_actors[who]["node"] as Node2D).add_child(spr)
	_bubbles.append([spr, EMOTE_SECONDS])


func _process(delta: float) -> void:
	if id == "":
		return
	_time += delta
	for b: Array in _bubbles.duplicate():
		b[1] = float(b[1]) - delta
		var spr: Sprite2D = b[0]
		spr.position.y = -40 - minf(3.0, (EMOTE_SECONDS - float(b[1])) * 12.0)
		if float(b[1]) <= 0.0:
			spr.queue_free()
			_bubbles.erase(b)
	var moving := false
	for who: String in _actors:
		var a: Dictionary = _actors[who]
		var p: Vector2 = a["pos"]
		var to: Vector2 = a["to"]
		if p.distance_to(to) > 0.5:
			a["pos"] = p.move_toward(to, WALK_TILES_PER_SECOND * TILE * delta)
			moving = true
		_show(who)
	if waiting == "walk" and not moving:
		waiting = ""
		_next()
	elif waiting == "pause":
		_timer -= delta
		if _timer <= 0.0:
			waiting = ""
			_next()


## The top middle of a person's picture in the scene, for the talk box.
func has_actor(who: String) -> bool:
	return _actors.has(who)
