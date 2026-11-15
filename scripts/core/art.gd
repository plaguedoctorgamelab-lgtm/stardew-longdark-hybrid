class_name Art
extends RefCounted
## Loads pictures by name. Uses art/final/<name>.png if it exists, otherwise
## the stand-in art/placeholder/<name>.png, so finished art drops in with no
## change to code or data.

const FINAL_DIR := "res://art/final/"
const PLACEHOLDER_DIR := "res://art/placeholder/"

static var _cache: Dictionary = {}


static func path_for(art_name: String) -> String:
	var final_path := FINAL_DIR + art_name + ".png"
	if ResourceLoader.exists(final_path):
		return final_path
	return PLACEHOLDER_DIR + art_name + ".png"


static func texture(art_name: String) -> Texture2D:
	if _cache.has(art_name):
		return _cache[art_name]
	var p := path_for(art_name)
	var tex: Texture2D = null
	if ResourceLoader.exists(p):
		tex = load(p)
	if tex == null:
		push_warning("Art: missing picture %s" % art_name)
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
		tex = ImageTexture.create_from_image(img)
	_cache[art_name] = tex
	return tex


static func image(art_name: String) -> Image:
	return texture(art_name).get_image()


static func clear_cache() -> void:
	_cache.clear()
