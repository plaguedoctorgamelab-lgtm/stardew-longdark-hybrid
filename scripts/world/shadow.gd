class_name Shadow
extends RefCounted
## Soft ground shadows: a flat, see-through dark oval under anything that
## stands on the ground, so it looks planted instead of floating. Sizes and
## darkness are in the tuning file (look.*).

## Shadows draw above the ground layers and below everything that stands up.
const Z := -15

static var _cache: Dictionary = {}


## An oval for a thing width_px wide.
static func texture(width_px: float, t: Tuning) -> Texture2D:
	var w := maxi(4, roundi(width_px * t.num("look.shadow_width_share")))
	var h := clampi(roundi(w * t.num("look.shadow_height_share")), t.integer("look.shadow_min_height"), t.integer("look.shadow_max_height"))
	var key := Vector2i(w, h)
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Color(0, 0, 0, t.num("look.shadow_alpha"))
	var rx := w / 2.0
	var ry := h / 2.0
	for y in h:
		for x in w:
			var dx := (x + 0.5 - rx) / rx
			var dy := (y + 0.5 - ry) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Puts a shadow under a node whose origin is at its feet (bottom middle).
## Returns the shadow so the caller can resize or hide it.
static func attach(parent: Node2D, width_px: float, t: Tuning, z: int = Z) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = "Shadow"
	s.texture = texture(width_px, t)
	s.z_as_relative = false
	s.z_index = z
	s.position = Vector2(0, -2)
	parent.add_child(s)
	return s


## Resizes a shadow made by attach.
static func resize(s: Sprite2D, width_px: float, t: Tuning) -> void:
	s.texture = texture(width_px, t)
