class_name ParkHelpers
extends RefCounted
## Helpers for the phase 3 tests: making sites ready, opening trail along a
## planned route, and running the park.


## Marks every step of a site done (the debug way), so it counts as ready.
static func ready_site(s: GameSession, site: String) -> void:
	for step in GameSession.SITE_STEPS:
		s.debug_site_step(site, step, true)


## Opens trail along a baked route: clears what is in the way and digs where
## the trail is missing, as a ranger with a shovel and saw would. The route
## is followed three tiles wide.
static func open_route(s: GameSession, route: String) -> void:
	# Snags standing in a gap (the stake trail) are felled first.
	for id: String in s.jobs.spot_ids():
		if bool(s.jobs.spot_row(id).get("blocks_dig", false)):
			s.jobs.spots_done[id] = true
	var pts := s.world.route(route)
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var n := maxi(1, ceili(a.distance_to(b) * 2.0))
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var t := Vector2i(floori(p.x), floori(p.y)) + o
				if not s.obstacle_at(t).is_empty():
					s.debug_clear_obstacle(t)
				if s.world.ground_at(t) != "trail" and s.world.ground_at(t) != "boards":
					if (s.tuning.value("trail.boardwalk_on") as Array).has(s.world.ground_at(t)):
						s._set_boardwalk(t, true)
					else:
						s.debug_dig(t)


## Runs the park from now to a minute of today.
static func run_to(s: GameSession, minute: int) -> void:
	s.park.advance_to(float(minute))
