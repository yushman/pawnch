extends Control
class_name GameOverBanner

# The end of a game, said without words. The audience is six years old and does
# not read English (board-view spec), so the banner has to be legible as a
# picture first: the winning side's king wearing a crown, the losing side's king
# on its face and greyed out, and a big round arrow to go again. The text under
# it is a caption for the adult holding the phone, not the message.
#
# It draws into the top 540 px of the left-hand of the two 660 px bands a 1080 px
# square board leaves free on a 2400x1080 screen, so the final position stays
# visible beside it. That is the whole point: the child has to see the position
# that ended it.
#
# The left band rather than the right, and covering the whole top of it, because
# that is the region whose contents are the most expendable at game over: white's
# commander, which is decoration, and the turn indicator, which has just hidden
# itself. Everything that is still worth reading survives — both graveyards, so
# the material that decided it stays countable, and black's commander.
#
# Input is not handled here. InputRouter owns every tap in this game and asks
# restart_hit() whether one landed on the arrow, so there is exactly one place a
# pixel turns into a decision.

## The left band runs x = 0..660 and white's graveyard starts at y = 580. Pushed
## right of x = 100 to leave the debug button its corner. The two things it is
## allowed to cover are wholly inside it and are checked to be: the turn
## indicator at y 35..225 and white's commander at y 260..560, which moved down
## the band when everything of white's was gathered at white's own end.
const PANEL := Rect2(100, 20, 540, 550)
## 1.5 and a 200 px gap until the band went from 940 px wide to 540.
const FIGURE_SCALE := 1.4
const FIGURE_GAP := 145.0
## The kings sit high in the panel rather than on its centre, because the panel
## also has to hold the caption and the button under them.
const FIGURE_ROW_Y := 190.0
const CAPTION_BASELINE := 378.0
const CAPTION_SIZE := 34
const RESTART_CENTER := Vector2(370, 448)
const RESTART_RADIUS := 80.0
# Generously larger than the drawn circle: a six-year-old's tap lands near the
# button, not on it.
const RESTART_TOUCH := 130.0

## Opaque, not 0.92: white's commander stands behind this panel and showed
## through it as a face looming over the two kings.
const PANEL_COLOR := Color(0.09, 0.10, 0.13, 1.0)
const PANEL_EDGE := Color(0.96, 0.62, 0.04, 1.0)
const GOLD := Color(0.96, 0.62, 0.04, 1.0)
const LOSER_TINT := Color(0.30, 0.30, 0.34, 0.85)
const TEXT_COLOR := Color(0.97, 0.96, 0.93, 1.0)

@onready var board: BoardView = get_node_or_null("../Board")

var _outcome := ""
var _winner := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	print("PAWNCH_BANNER board=%s" % (board != null))


func show_outcome(outcome: String, winner: String) -> void:
	_outcome = outcome
	_winner = winner
	visible = true
	queue_redraw()
	print("PAWNCH_BANNER show outcome=%s winner=%s restart=%s" % [
		outcome, winner, RESTART_CENTER])


func hide_outcome() -> void:
	_outcome = ""
	visible = false
	queue_redraw()


# `point` is in the viewport's space, the same space InputRouter reads taps in.
func restart_hit(point: Vector2) -> bool:
	if not visible:
		return false
	var local := get_global_transform().affine_inverse() * point
	return local.distance_to(RESTART_CENTER) <= RESTART_TOUCH


func _draw() -> void:
	if _outcome == "":
		return
	draw_rect(PANEL, PANEL_COLOR)
	draw_rect(PANEL, PANEL_EDGE, false, 6.0)
	if _outcome == "checkmate":
		_draw_checkmate()
	else:
		_draw_stalemate()
	_draw_caption()
	_draw_restart()


# The winner stands crowned; the loser is face down and drained of colour. Which
# is which is the only thing this banner has to get across.
func _draw_checkmate() -> void:
	var centre := Vector2(PANEL.get_center().x, FIGURE_ROW_Y)
	var loser := "black" if _winner == "white" else "white"
	_draw_king(_winner, centre - Vector2(FIGURE_GAP, 20), FIGURE_SCALE, Color.WHITE, 0.0)
	_draw_crown(centre - Vector2(FIGURE_GAP, 20 + BoardView.CELL.y * FIGURE_SCALE * 0.52))
	_draw_king(loser, centre + Vector2(FIGURE_GAP, 40), FIGURE_SCALE, LOSER_TINT, PI * 0.5)


# Nobody won: two kings the same size, the same brightness, an equals sign
# between them.
func _draw_stalemate() -> void:
	var centre := Vector2(PANEL.get_center().x, FIGURE_ROW_Y)
	_draw_king("white", centre - Vector2(FIGURE_GAP, 20), FIGURE_SCALE, Color.WHITE, 0.0)
	_draw_king("black", centre + Vector2(FIGURE_GAP, 20), FIGURE_SCALE, Color.WHITE, 0.0)
	for dy in [-22.0, 22.0]:
		draw_rect(Rect2(centre.x - 55, centre.y + dy - 11, 110, 22), TEXT_COLOR)


func _draw_king(color: String, at: Vector2, scale: float, tint: Color, rotation: float) -> void:
	if board == null or board.atlas_page() == null:
		return
	# BoardView.CELL rather than a second copy of it: the cell went 135x170 ->
	# 135x135 with the un-rotation and a literal here would have drawn both kings
	# stretched by a quarter with nothing failing.
	var size := BoardView.CELL * scale
	draw_set_transform(at, rotation, Vector2.ONE)
	draw_texture_rect_region(board.atlas_page(), Rect2(-size * 0.5, size),
		board.figure_region(color, "king"), tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_crown(at: Vector2) -> void:
	var u := 26.0
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-2.0 * u, 0.7 * u), at + Vector2(-2.0 * u, -0.9 * u),
		at + Vector2(-1.0 * u, 0.0), at + Vector2(0.0, -1.2 * u),
		at + Vector2(1.0 * u, 0.0), at + Vector2(2.0 * u, -0.9 * u),
		at + Vector2(2.0 * u, 0.7 * u),
	]), GOLD)


func _draw_caption() -> void:
	var font := ThemeDB.fallback_font
	var text := "STALEMATE — DRAW"
	if _outcome == "checkmate":
		text = "CHECKMATE — %s WINS" % _winner.to_upper()
	draw_string(font, Vector2(PANEL.position.x, CAPTION_BASELINE), text,
		HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x, CAPTION_SIZE, TEXT_COLOR)


# One round arrow, big enough to be the obvious thing on an otherwise empty
# band. Nothing else down there competes for the tap.
func _draw_restart() -> void:
	draw_circle(RESTART_CENTER, RESTART_RADIUS, GOLD)
	draw_arc(RESTART_CENTER, RESTART_RADIUS * 0.52, deg_to_rad(-60), deg_to_rad(240), 48,
		PANEL_COLOR, 14.0)
	var head := RESTART_CENTER + Vector2(RESTART_RADIUS * 0.52, 0).rotated(deg_to_rad(-60))
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-26, -6), head + Vector2(14, -22), head + Vector2(6, 20),
	]), PANEL_COLOR)
	# Centred on the button, not on `size.x`: this control spans the whole 2400 px
	# viewport, so centring across it put the caption in the middle of the board.
	draw_string(ThemeDB.fallback_font,
		Vector2(PANEL.position.x, RESTART_CENTER.y + RESTART_RADIUS + 36),
		"NEW GAME", HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x, 40, TEXT_COLOR)
