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
	s.debug_open_route(route)


## Runs the park from now to a minute of today.
static func run_to(s: GameSession, minute: int) -> void:
	s.park.advance_to(float(minute))
