class_name RangerSprite
extends Node2D
## Shows the ranger: 16 by 32, four facings, a four-frame walk. The sheet has
## rows for down, right, up and left. The node's position is the feet.

const FRAME := Vector2i(16, 32)
const FRAMES_PER_SECOND := 8.0

var sprite: Sprite2D
var _anim: float = 0.0
var _still: float = 0.0     # seconds standing still, for the idle bob
var frozen: int = 0         # frames left of a hit-stop: the ranger holds still
## The idle bob (Graphics Polish): after `bob_delay` seconds still, the
## ranger rises a pixel and settles, once each `bob_period` seconds.
var bob_delay: float = 2.0
var bob_period: float = 2.4
var motion: bool = true


func _init() -> void:
	sprite = Sprite2D.new()
	sprite.texture = Art.texture("ranger")
	sprite.region_enabled = true
	sprite.centered = false
	sprite.offset = Vector2(-FRAME.x / 2.0, -FRAME.y + 2)
	add_child(sprite)


## Holds the ranger still for a few frames: a tool has landed.
func freeze(frames: int) -> void:
	if motion:
		frozen = maxi(frozen, frames)


func show_state(pixel_pos: Vector2, facing: int, walking: bool, delta: float) -> void:
	if frozen > 0:
		frozen -= 1
		return
	position = pixel_pos.round()
	if walking:
		_anim += delta * FRAMES_PER_SECOND
		_still = 0.0
	else:
		_anim = 0.0
		_still += delta
	var frame := int(_anim) % 4
	sprite.region_rect = Rect2(frame * FRAME.x, facing * FRAME.y, FRAME.x, FRAME.y)
	sprite.position.y = -1.0 if bob_up() else 0.0


## Whether the idle bob has the ranger risen a pixel just now.
func bob_up() -> bool:
	if not motion or _still < bob_delay:
		return false
	return fmod(_still - bob_delay, bob_period) < bob_period * 0.4
