extends Control
class_name TurnIndicator

# Whose move it is, said without words. With two people at one phone nobody had
# to be told; with an opponent that thinks for a third of a second and then
# moves on its own, "is it my turn" and "is it stuck" are real questions a
# six-year-old cannot answer from a board that looks the same in both cases
# (board-view spec).
#
# Three states, and the third one is silence: the player's turn, the opponent
# deciding, and the game being over -- where the banner is the message and a
# second thing naming a turn would only compete with it.
#
# It draws at the top of the left-hand margin -- one of the two 660 px bands a
# 1080 px square board leaves on a 2400 px screen since Day 8's landscape flip.
# The band is white's, and everything of white's is at white's own end of it:
# the graveyard fills the bottom (y 580..1060) and the commander stands on top
# of it (y 260..560). This is the 260 px they leave over at the far end, which
# is the end nothing of white's wants.
#
# The game-over banner takes the whole top of this band, commander and all, and
# this hides itself then -- so the left margin says either whose move it is or
# how the game ended, never both.
#
# It is a readout and nothing else: pushed from GameSession, never asking the
# board or the rules anything, and MOUSE_FILTER_IGNORE so that InputRouter stays
# the only place a pixel turns into a decision.

## Centred in the 260 px above the commander in the left band, which runs
## x = 0..660: (260 - 190) / 2 = 35. Clear of the debug Duel button, which owns
## the top-left corner out to x = 100.
const PANEL := Rect2(120, 35, 420, 190)
const FIGURE_SCALE := 0.85
const FIGURE_OFFSET := Vector2(-95, 0)
const MARK_CENTER := Vector2(85, 0)
# The opponent's dots step at this rate, which is also the only reason this
# node redraws at all.
const DOT_STEP_MSEC := 250
const DOTS := 3

const PANEL_COLOR := Color(0.09, 0.10, 0.13, 0.82)
const PANEL_EDGE := Color(0.96, 0.62, 0.04, 1.0)
const GOLD := Color(0.96, 0.62, 0.04, 1.0)
const DIM := Color(0.42, 0.42, 0.46, 1.0)

@onready var board: BoardView = get_node_or_null("../Board")

var _state := "player"
var _color := "white"
var _dot_tick := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	print("PAWNCH_TURN board=%s" % (board != null))


func _process(_delta: float) -> void:
	# Only the thinking dots animate, so only they cost a redraw -- and at 4 Hz,
	# not 60.
	if _state != "opponent":
		return
	var tick := Time.get_ticks_msec() / DOT_STEP_MSEC
	if tick != _dot_tick:
		_dot_tick = tick
		queue_redraw()


# `state` is "player", "opponent" or "over"; `color` is the side to move, or ""
# once the game is over.
func set_state(state: String, color: String) -> void:
	if state == _state and color == _color:
		return
	_state = state
	_color = color
	visible = state != "over"
	queue_redraw()
	print("PAWNCH_TURN state=%s color=%s" % [state, color])


func state() -> String:
	return _state


func turn_color() -> String:
	return _color


func _draw() -> void:
	if _state == "over" or _color == "":
		return
	draw_rect(PANEL, PANEL_COLOR)
	draw_rect(PANEL, PANEL_EDGE, false, 5.0)
	_draw_figure()
	if _state == "opponent":
		_draw_thinking()
	else:
		_draw_ready()


# The side's own figure, so which colour is to move is legible from the picture
# rather than from a word.
func _draw_figure() -> void:
	if board == null or board.atlas_page() == null:
		return
	# BoardView.CELL rather than a second copy of it: the cell went 135x170 ->
	# 135x135 with the un-rotation and a literal here would have drawn the king
	# stretched by a quarter with nothing failing.
	var size := BoardView.CELL * FIGURE_SCALE
	var at := PANEL.get_center() + FIGURE_OFFSET
	draw_texture_rect_region(board.atlas_page(), Rect2(at - size * 0.5, size),
		board.figure_region(_color, "king"), Color.WHITE)


# A chevron pointing down at the board: your move, and it is down there.
func _draw_ready() -> void:
	var at := PANEL.get_center() + MARK_CENTER
	var u := 34.0
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-1.4 * u, -0.8 * u), at + Vector2(0.0, 0.5 * u),
		at + Vector2(1.4 * u, -0.8 * u), at + Vector2(1.4 * u, -0.1 * u),
		at + Vector2(0.0, 1.2 * u), at + Vector2(-1.4 * u, -0.1 * u),
	]), GOLD)


# Three dots with one lit, stepping left to right: something is happening and it
# is not the game being stuck.
func _draw_thinking() -> void:
	var at := PANEL.get_center() + MARK_CENTER
	var lit := _dot_tick % DOTS
	for i in DOTS:
		draw_circle(at + Vector2((i - 1) * 42.0, 0.0), 15.0, GOLD if i == lit else DIM)
