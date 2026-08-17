extends Control
class_name DuelPanel

# Full-screen cutaway (ADR-0002). 1080x1500 panel centred in the 1080x1920
# safe band, itself centred in whatever the runtime viewport is, so the
# framing survives the 16:9-20:9 supported range without re-composing.

const PANEL_SIZE := Vector2(1080, 1500)
const SAFE_BAND_SIZE := Vector2(1080, 1920)
const BOARD_RECEDE_SCALE := 0.94

@export var board: CanvasItem

@onready var _board_dim: ColorRect = $BoardDim
@onready var _frame: Control = $Frame
@onready var _mask: Control = $Frame/Mask
@onready var _background: TextureRect = $Frame/Mask/Background
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _characters: Array[CharacterRig] = [$Frame/Mask/Knight, $Frame/Mask/Pawn]

var _board_scale := Vector2.ONE
var _is_open := false
var _board_tween: Tween


func _ready() -> void:
	if board:
		_board_scale = board.scale
	_layout()
	get_viewport().size_changed.connect(_layout)
	await _warm()
	close_now()


func _layout() -> void:
	var frame_rect := frame_rect_for(get_viewport_rect().size)
	_frame.position = frame_rect.position
	_frame.size = frame_rect.size
	_background.size = PANEL_SIZE
	_mask.size.y = PANEL_SIZE.y
	# A Control scales about its top-left by default; pivot it about its own
	# centre so the recede reads as "pull back", not "drift up-left". Set on
	# every layout pass, not just _ready(), since board's size tracks the
	# viewport too.
	if board is Control:
		board.pivot_offset = board.size * 0.5


# Centres the 1080x1500 panel in the 1080x1920 safe band, itself centred in
# whatever viewport size is reported. Pulled out of _layout() so the framing
# math is testable without depending on the project's stretch/aspect setup.
static func frame_rect_for(viewport_size: Vector2) -> Rect2:
	var band_y := (viewport_size.y - SAFE_BAND_SIZE.y) * 0.5
	var x := (viewport_size.x - PANEL_SIZE.x) * 0.5
	var y := band_y + (SAFE_BAND_SIZE.y - PANEL_SIZE.y) * 0.5
	return Rect2(Vector2(x, y), PANEL_SIZE)


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	_is_open = true
	_anim.stop()
	_anim.play("wipe_in")
	_tween_board_scale(_board_scale * BOARD_RECEDE_SCALE, 0.15)


func close() -> void:
	_is_open = false
	_anim.stop()
	_anim.play("wipe_out")
	_tween_board_scale(_board_scale, 0.3)


func close_now() -> void:
	_is_open = false
	_mask.size.x = 0
	_board_dim.modulate.a = 0
	if _board_tween and _board_tween.is_valid():
		_board_tween.kill()
	if board:
		board.scale = _board_scale


# One reused Tween rather than a fresh allocation per toggle — also fixes the
# competing-tweens race when the panel is toggled faster than a transition
# completes.
func _tween_board_scale(target_scale: Vector2, duration: float) -> void:
	if not board:
		return
	if _board_tween and _board_tween.is_valid():
		_board_tween.kill()
	_board_tween = create_tween()
	_board_tween.tween_property(board, "scale", target_scale, duration)


# Failure mode 4 (system-analysis.md): the first open after a cold start
# must not compile a shader or upload a texture. Draw everything once at
# zero opacity so the GPU work happens here, not on the player's first tap.
func _warm() -> void:
	modulate.a = 0.0
	_mask.size.x = PANEL_SIZE.x
	for c in _characters:
		c.play_state("Idle")
	await get_tree().process_frame
	await get_tree().process_frame
	modulate.a = 1.0
