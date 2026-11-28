class_name VehicleView
extends Node2D
## Phase 6a: the canoe at the water's edge and the cart where it's parked
## (when the ranger isn't in them), Troll Badger Bridge's toll box once the
## bridge is mended, and the "trail closed" signs in winter.

const TILE := 16

var session: GameSession
var sort_root: Node2D
var _canoe: Sprite2D
var _cart: Sprite2D
var _toll: Sprite2D
var _signs: Array[Sprite2D] = []
var _signs_on: int = -1


func setup(s: GameSession, root: Node2D) -> void:
	session = s
	sort_root = root
	_canoe = _make("obj_canoe_beached")
	_cart = _make("vehicle_cart")
	_cart.region_enabled = true
	_cart.region_rect = Rect2(0, 0, 32, 32)
	_cart.offset = Vector2(-16, -28)
	_toll = _make("obj_toll_box")


func _make(art: String) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.centered = false
	if Art.has_picture(art):
		spr.texture = Art.texture(art)
		spr.offset = Vector2(-spr.texture.get_width() / 2.0, -spr.texture.get_height() + 4)
	spr.visible = false
	sort_root.add_child(spr)
	return spr


func _process(_delta: float) -> void:
	if session == null:
		return
	var outside := not session.is_indoors() and not session.in_town
	var v := session.vehicles
	_canoe.visible = outside and v.has_canoe() and v.riding != "canoe" and v.canoe_pos != Vector2.INF
	if _canoe.visible:
		_canoe.position = (v.canoe_pos * TILE).round()
	_cart.visible = outside and v.has_cart() and v.riding != "cart" and v.cart_pos != Vector2.INF
	if _cart.visible:
		_cart.position = (v.cart_pos * TILE).round()
	var tb := v.toll_box_pos()
	_toll.visible = outside and tb != Vector2.INF
	if _toll.visible:
		_toll.position = (tb * TILE).round()
	var winter := 1 if outside and bool(v.land_state()["snowed"]) else 0
	if winter != _signs_on:
		_signs_on = winter
		for spr in _signs:
			spr.queue_free()
		_signs.clear()
		if winter == 1:
			for p: Array in session.world.meta.get("seasonal", {}).get("closed_signs", []):
				var spr := _make("obj_sign_closed_winter")
				spr.visible = true
				spr.position = ((Vector2(float(p[0]), float(p[1])) + Vector2(0.5, 1.0)) * TILE).round()
				_signs.append(spr)
