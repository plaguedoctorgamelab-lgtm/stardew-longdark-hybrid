class_name RangerSprite
extends Node2D
## Shows the ranger: 16 by 32, four facings, a four-frame walk. The sheet has
## rows for down, right, up and left. The node's position is the feet.

const FRAME := Vector2i(16, 32)
const FRAMES_PER_SECOND := 8.0

var sprite: Sprite2D
var _anim: float = 0.0


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = Art.texture("ranger")
	sprite.region_enabled = true
	sprite.centered = false
	sprite.offset = Vector2(-FRAME.x / 2.0, -FRAME.y + 2)
	add_child(sprite)


func show_state(pixel_pos: Vector2, facing: int, walking: bool, delta: float) -> void:
	position = pixel_pos.round()
	if walking:
		_anim += delta * FRAMES_PER_SECOND
	else:
		_anim = 0.0
	var frame := int(_anim) % 4
	sprite.region_rect = Rect2(frame * FRAME.x, facing * FRAME.y, FRAME.x, FRAME.y)
