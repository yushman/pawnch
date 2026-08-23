extends Control
class_name GameOverBanner

# The end of a game, said without words. The audience is six years old and does
# not read English (game-outcome spec), so the banner has to be legible as a
# picture first: the two commanders, the winner crowned and the loser run
# through, and a big round arrow to go again. The text under it is a caption for
# the adult holding the phone, not the message.
#
# **It stood in the top of the left-hand margin until Day 9, over white's
# commander and the turn card.** That placement was an argument about which
# margin furniture was expendable, and the argument went away when a person
# looking at the build asked for the ending in the middle of the screen. It now
# draws over the board and only over the board: x 700..1700 sits inside the
# board's own 660..1740, so neither graveyard and neither commander is covered,
# and what each army lost stays countable while the result is on screen.
#
# The two commanders keep their sides -- white left, black right, whoever won --
# for the same reason everything else in this game does (ADR-0011 decision 5).
# The crown and the spear are not new art and could not be: the king's crest is
# a crown and the knight's weapon is a spear, both already baked into
# assets/board/pieces.png, so ADR-0009 is satisfied by construction rather than
# by argument.
#
# Input is not handled here. InputRouter owns every tap in this game and asks
# restart_hit() and close_hit() whether one landed on a button, so there is
# exactly one place a pixel turns into a decision.

## Centred on the 2400x1080 screen and inside the board's 660..1740, which is
## what keeps it off both margins. The suite checks that, because "centred"
## drifts into "covering white's graveyard" with one wrong constant.
const PANEL := Rect2(700, 140, 1000, 810)
## The commanders are 300 px in the margin; a little larger here, because this
## is the one moment they are the subject rather than the furniture.
const HERO_SCALE := 1.18
const HERO_GAP := 215.0
## The line both commanders stand on, so the crowned one and the run-through one
## are the same height and only the crown and the spear separate them.
const HERO_BASE_Y := 590.0
## The crest is a whole 135 px cell with the crown sitting in register with a
## board figure's head, so it is placed by scaling that cell rather than by
## cropping it and these fractions undo where the crown sits inside it.
##
## **Per colour, because the two crests are not in the same place.** The crown's
## box is x 43..77 on the valkyrie king and x 62..99 on the skeleton one, since
## each sits on that army's own head; one shared fraction put black's crown
## 64 px to the left of the necromancer's head and into the close button.
const CROWN_CELL := 430.0
const CROWN_CENTER := {
	"white": Vector2(0.444, 0.207),
	"black": Vector2(0.596, 0.189),
}
## The knight's spear, cut out of its figure region. Measured off the page by
## walking the alpha rows, not guessed: white's points right out of the body at
## rows 95..113, black's points left at rows 90..108.
const SPEAR_CUT := {
	"white": Rect2(78, 95, 44, 18),
	"black": Rect2(9, 90, 50, 18),
}
const SPEAR_SCALE := 6.4
const SPEAR_ANGLE := 0.42

## The caption is for the adult holding the phone, not the message -- the
## audience cannot be assumed to read at all (game-outcome spec). Russian with
## everything else on screen: the app speaks one language and has no
## localisation mechanism behind it (hero-banter spec).
const WINNER_NAME := {"white": "БЕЛЫЕ", "black": "ЧЁРНЫЕ"}
const CAPTION_BASELINE := 690.0
const CAPTION_SIZE := 46
const RESTART_CENTER := Vector2(1200, 790)
const RESTART_RADIUS := 80.0
# Generously larger than the drawn circle: a six-year-old's tap lands near the
# button, not on it.
const RESTART_TOUCH := 130.0
## Smaller than the restart button and in the panel's own corner, because it is
## the secondary of the two: going again is the thing a child wants, and looking
## at the finished board is the thing an adult asks for.
##
## The bottom corner rather than the top one, which is where it sat until the
## first render of a black win: the winner's crown reaches into whichever top
## corner that winner stands in, so a top-corner button collides with it on one
## of the two outcomes and not on the other.
const CLOSE_CENTER := Vector2(1630, 875)
const CLOSE_RADIUS := 44.0
const CLOSE_TOUCH := 84.0

## Opaque, not 0.92: the board stands behind this panel and showed through it as
## a rank of pawns walking across the two commanders.
const PANEL_COLOR := Color(0.09, 0.10, 0.13, 1.0)
const PANEL_EDGE := Color(0.96, 0.62, 0.04, 1.0)
const GOLD := Color(0.96, 0.62, 0.04, 1.0)
## 0.30 first: on the necromancer, who is nearly black to begin with, it took
## the loser past "drained" and into an unreadable silhouette.
const LOSER_TINT := Color(0.42, 0.42, 0.47, 0.88)
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
	print("PAWNCH_BANNER show outcome=%s winner=%s restart=%s close=%s" % [
		outcome, winner, RESTART_CENTER, CLOSE_CENTER])


# The game is no longer over: forget the result as well as hiding the panel.
# Only restart and load_fen() reach this.
func hide_outcome() -> void:
	_outcome = ""
	visible = false
	queue_redraw()


# Put the panel away but keep the result. Distinct from hide_outcome() on
# purpose: the game is still over, the position underneath is the one that ended
# it, and reopen() can put the announcement back (game-outcome spec).
func dismiss() -> void:
	if not visible:
		return
	visible = false
	queue_redraw()
	print("PAWNCH_BANNER dismissed outcome=%s" % _outcome)


func reopen() -> bool:
	if visible or _outcome == "":
		return false
	visible = true
	queue_redraw()
	print("PAWNCH_BANNER reopen outcome=%s" % _outcome)
	return true


# `point` is in the viewport's space, the same space InputRouter reads taps in.
func restart_hit(point: Vector2) -> bool:
	return visible and _local(point).distance_to(RESTART_CENTER) <= RESTART_TOUCH


# Dismissing leaves the game over and the final position on screen; nothing
# about the position changes and no further move can be played, because
# GameSession.tap() refuses one on a finished game whatever is drawn over it.
func close_hit(point: Vector2) -> bool:
	return visible and _local(point).distance_to(CLOSE_CENTER) <= CLOSE_TOUCH


func _local(point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * point


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
	_draw_close()


# The winner stands crowned; the loser stands drained of colour with the
# winner's own knight's spear through them. Which is which is the only thing
# this banner has to get across.
func _draw_checkmate() -> void:
	var loser := "black" if _winner == "white" else "white"
	_draw_hero(_winner, Color.WHITE)
	_draw_hero(loser, LOSER_TINT)
	_draw_crown(_winner)
	_draw_spear(loser)


# Nobody won: two commanders the same size, the same brightness, an equals sign
# between them.
func _draw_stalemate() -> void:
	_draw_hero("white", Color.WHITE)
	_draw_hero("black", Color.WHITE)
	for dy in [-26.0, 26.0]:
		draw_rect(Rect2(PANEL.get_center().x - 62, HERO_BASE_Y - 190 + dy - 12,
			124, 24), TEXT_COLOR)


# White on the left and black on the right, won or lost. The board, the margins
# and the duel panel all agree about which side of the screen a colour lives on
# and this is not the place to disagree (ADR-0011 decision 5).
func _hero_rect(color: String) -> Rect2:
	var size := BoardView.HERO_CELL * HERO_SCALE
	var cx := PANEL.get_center().x + (HERO_GAP + size.x * 0.5) * (1.0 if color == "black" else -1.0)
	return Rect2(Vector2(cx - size.x * 0.5, HERO_BASE_Y - size.y), size)


func _draw_hero(color: String, tint: Color) -> void:
	if board == null or board.atlas_page() == null:
		return
	draw_texture_rect_region(board.atlas_page(), _hero_rect(color),
		board.hero_region(color), tint)


# The king's own crest, scaled up until the crown inside it is the size a crown
# should be and shifted so that it lands on the commander's head rather than
# where a board figure's head would have been.
func _draw_crown(color: String) -> void:
	if board == null or board.atlas_page() == null:
		return
	var body := _hero_rect(color)
	var head := body.position + Vector2(body.size.x * 0.5, 4.0)
	draw_texture_rect_region(board.atlas_page(),
		Rect2(head - CROWN_CENTER[color] * CROWN_CELL, Vector2.ONE * CROWN_CELL),
		board.crest_region(color, "king"))


# The winning side's knight's spear, run through the loser from the winner's own
# side of the panel: left to right when white wins, right to left when black
# does. Both source spears already point outward from their knight's body, so
# neither is mirrored -- a mirrored spear reads as a different weapon, and both
# of these are the same weapon held by two armies.
func _draw_spear(loser: String) -> void:
	if board == null or board.atlas_page() == null:
		return
	var winner := "black" if loser == "white" else "white"
	var cut: Rect2 = SPEAR_CUT[winner]
	var size := cut.size * SPEAR_SCALE
	var body := _hero_rect(loser)
	var forward := 1.0 if winner == "white" else -1.0
	# The head lands past the loser's middle rather than on it, so the point
	# comes out the far side. On the middle it read as a spear being handed over.
	var at := body.get_center() + Vector2(body.size.x * 0.20 * forward, body.size.y * 0.08)
	# Point-first: the head is the right-hand end of white's cut and the
	# left-hand end of black's, so the anchor flips with the winner.
	var anchor := Vector2(0.86 if winner == "white" else 0.14, 0.5)
	draw_set_transform(at, -SPEAR_ANGLE * forward, Vector2.ONE)
	draw_texture_rect_region(board.atlas_page(), Rect2(-size * anchor, size),
		board.figure_cut(winner, "knight", cut))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_caption() -> void:
	var font := ThemeDB.fallback_font
	var text := "ПАТ — НИЧЬЯ"
	if _outcome == "checkmate":
		text = "МАТ — ПОБЕДИЛИ %s" % WINNER_NAME.get(_winner, _winner.to_upper())
	draw_string(font, Vector2(PANEL.position.x, CAPTION_BASELINE), text,
		HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x, CAPTION_SIZE, TEXT_COLOR)


# One round arrow, big enough to be the obvious thing on the panel. Nothing else
# on it competes for the tap.
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
		Vector2(PANEL.position.x, RESTART_CENTER.y + RESTART_RADIUS + 42),
		"ЗАНОВО", HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x, 40, TEXT_COLOR)


# A cross in the panel's corner: put the banner away and look at the board that
# ended it. The game stays over underneath.
func _draw_close() -> void:
	draw_circle(CLOSE_CENTER, CLOSE_RADIUS, PANEL_COLOR)
	draw_arc(CLOSE_CENTER, CLOSE_RADIUS, 0.0, TAU, 40, GOLD, 5.0)
	for d in [Vector2(1, 1), Vector2(1, -1)]:
		draw_line(CLOSE_CENTER - d * CLOSE_RADIUS * 0.42,
			CLOSE_CENTER + d * CLOSE_RADIUS * 0.42, GOLD, 8.0)
