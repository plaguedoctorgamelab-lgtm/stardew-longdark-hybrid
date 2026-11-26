class_name LensView
extends Control
## Phase 5a: looking through the binoculars (Mark's two round lenses over
## the screen) and the camera's moment (the viewfinder and a flash).

var session: GameSession
var _lens: TextureRect
var _finder: TextureRect
var _flash: TextureRect
var _shot: float = 0.0


func setup(s: GameSession) -> void:
	session = s
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(480, 270)
	_lens = _rect("ui_binocular_view", Vector2.ZERO, Vector2(480, 270))
	_finder = _rect("ui_viewfinder", Vector2(240 - 48, 135 - 52), Vector2(96, 72))
	_flash = _rect("ui_shutter", Vector2(240 - 16, 135 - 32), Vector2(32, 32))
	_lens.visible = false
	_finder.visible = false
	_flash.visible = false
	s.photo_taken.connect(func(_r: Dictionary) -> void: _shot = 0.6)


func _rect(art: String, at: Vector2, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Art.texture(art) if Art.has_picture(art) else null
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.position = at
	t.size = sz
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


func _process(delta: float) -> void:
	if session == null:
		return
	_lens.visible = session.wildlife.looking
	_shot = maxf(0.0, _shot - delta)
	_finder.visible = _shot > 0.0
	_flash.visible = _shot > 0.4
	_flash.modulate.a = clampf((_shot - 0.4) * 5.0, 0.0, 1.0)
