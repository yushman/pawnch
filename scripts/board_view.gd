extends Control
class_name BoardView

# The board, in the orientation every child has already seen one in: files a-h
# left to right, rank 1 along the bottom, white nearest (ADR-0011 decisions 1,
# 2, 3, 4 and 6).
#
# It is a coordinate mapping, not a rotated node:
#
#     screen_col = file index      (file a leftmost)
#     screen_row = rank_count - rank   (rank 8 topmost)
#
# **This was a quarter turn clockwise until Day 8, and landscape is what undid
# it.** The rotation existed to put the two side-on armies in two facing columns
# and it cost two things: the crowding moved onto the axis that occludes -- eight
# figures stacked one behind another down a single column -- and the fix for that
# was a cell taller than it was wide, 135 x 170, which only portrait had the
# vertical room to pay for. Landscape has 1080 px of short edge and no such room,
# so the compensation had to go; removing the rotation removes what it was
# compensating for. Two armies in two *rows* overlap one layer deep, not eight,
# and one layer is what a 135 px square cell separates on its own.
#
# What the un-rotation costs is written into ADR-0011 decisions 1 and 5, because
# it is not free: the armies no longer face each other (the art is +-x side-on
# and cannot look up the board), and the board no longer agrees with the duel
# panel about which side of the screen a colour lives on.
#
# Nothing here is ever mirrored: a mirror reflects the position — king and queen
# swap files — which reads as a broken board. The rules know none of it; a1 is a1.
#
# Everything is drawn by this one CanvasItem, in one pass: squares, the marks
# that belong under a figure, then figures row by row from the top, then the
# marks that belong over one. Row by row from the top is the safe order for any
# figure that overhangs its own cell upward; at a 135 px square cell none does,
# and it is kept because it costs nothing and the alternative is a y-sort. The
# whole board stays two batches — the squares share the white texture and every
# mark comes off the same atlas page as the figures, so there is exactly one
# texture switch in the frame however the two are interleaved.
#
# Piece type is carried by the head crest and the weapon's outline (ADR-0011
# decision 4). A tile crest glyph shipped for one afternoon and was dropped: it
# cost a fifth of every figure's height and still could not separate the king
# from the queen.

## Square, since Day 8. The extra 35 px of pitch was compensation for the
## rotation above and went with it.
const CELL := Vector2(135, 135)
const ATLAS_PAGE := "res://assets/board/pieces.png"
const REGION_MAP := "res://assets/board/pieces.json"

const LIGHT_SQUARE := Color(0.93, 0.87, 0.74)
const DARK_SQUARE := Color(0.49, 0.35, 0.24)

# Five marks, all quads out of the same atlas page the figures come from, so
# they cost no draw call at all: Day 4 drew them as `draw_rect` outlines and
# measured +3..6, because an unbatched primitive breaks the run of textured
# quads either side of it. Geometry tells them apart before colour does — a
# blob in the middle, a wash on the cell's edges, and three nested edge marks:
# a frame flush to them, a rounded frame inside it, brackets inside that
# (tools/bake_board_atlas.py). The capture mark was a red ring until Day 9 --
# the only round thing on a board that speaks in squares, and it fought the
# last-move brackets on every cell that carried both.
const MARK_MOVE := "move"
const MARK_CAPTURE := "capture"
const MARK_CHECK := "check"
const MARK_SELECTED := "selected"
const MARK_LAST_MOVE := "last_move"

# The two margins the long edge leaves beside a square board, one per colour --
# white's on the left and black's on the right, following ADR-0011 decision 5's
# rule that sides are fixed by colour and never by role. "Left is me" is learned
# once and a graveyard that swapped sides between captures would spend it.
#
# Five columns of three is fifteen slots for the fifteen pieces a side can lose,
# 600 x 360 inside a 660 px margin. The frames are the board's own, drawn a
# little smaller, so a captured piece is literally the picture it was on the
# square it died on -- the cheapest possible guarantee of "identifiable by type",
# and free, since the frames are already on the page.
#
# **It was four by four until Day 9, and the shape is what paid for the room
# above the commanders.** Sixteen slots for fifteen losses was one spare slot
# bought with 120 px of a band that has 1080 to spend on a graveyard, a
# commander and the clear space a speech bubble needs above it; laid out the
# other way round the same fifteen fit and the 120 px goes to the gap. Fifteen
# is a hard ceiling, not a hope: a side has sixteen pieces and the king is not
# among the ones captured() counts.
const GRAVE_COLUMNS := 5
const GRAVE_ROWS := 3
const GRAVE_CELL := Vector2(120, 120)
const MARGIN_PAD := 20.0
## Most valuable first, so the biggest thing an army has lost is the first thing
## in the corner nearest the reader.
const GRAVE_ORDER := ["queen", "rook", "bishop", "knight", "pawn"]
## Multiplied into the fallen figure only. Six upright valkyries at full colour
## in a margin read as a reserve waiting to come on rather than as casualties;
## dimming them is what makes them dead.
##
## It is a multiply and therefore not a true desaturation -- Compatibility has no
## post-processing (ADR-0001) and a saturation shader would put the graveyard in
## its own material and cost the draw call this whole layout is avoiding. A cool
## grey multiply pulls the warm half of the palette most of the way there, which
## is what this needs and all it claims.
const FALLEN_TINT := Color(0.40, 0.42, 0.50, 0.90)
## The commander of each army, standing with that army's own graveyard at that
## colour's own end of the margin (see hero_origin). A static frame off the same
## atlas page: a mounted rig is ~12 draw calls and two of them would put the idle
## board near its whole budget.
const HERO_CELL := Vector2(300, 300)
## Whose move it is, said by the commander rather than by a panel of its own
## (board-view spec). Deliberately not hue: the two commanders are already two
## colours, so a colour-only treatment says nothing at a glance about which of
## them is the subject. Three channels instead -- the idle commander stands
## smaller, stands dimmer, and stands on nothing, while the active one keeps its
## size, its colour and a lit pedestal.
const HERO_IDLE_SCALE := 0.78
## Nowhere near FALLEN_TINT: an idle commander is waiting, not dead, and the two
## must not read the same way in the same margin.
const HERO_IDLE_TINT := Color(0.62, 0.64, 0.70, 1.0)
## The pedestal is its own region on the atlas page, stretched flat. It began as
## the destination blob tinted gold, which does not work and is worth writing
## down: draw_texture_rect_region *multiplies* the modulate into the texture, and
## gold times that blob's cyan is a pale green -- it rendered as a haze on the
## background's own green and read as nothing at all. A draw_circle here would
## have been the obvious fix and the wrong one; it breaks the margins' run of
## textured quads exactly as Day 4's draw_rect marks broke the board's.
const PEDESTAL_SIZE := Vector2(460, 190)
## How much of the pedestal sits above the feet line. The rest of it lands on
## the ground in front of the commander, and that overhang is why a commander
## cannot stand hard against the bottom of its band: at 20 px of pad the light
## under black's boots was cut off by the edge of the screen.
const PEDESTAL_ANCHOR := 0.45
const HUD_PEDESTAL := "pedestal"

# The pause and take-back controls, stacked in the outer strip of white's band
# beside the commander and exactly as tall as it is: 140 + 20 + 140 = 300 =
# HERO_CELL.y. That strip is the only rectangle on this screen wide enough for a
# finger that belongs to neither graveyard, neither commander, the board, nor the
# room reserved above a commander for a bubble.
#
# **Both are layout only in this change and neither does anything.** control_at()
# resolves a tap to one of them and InputRouter answers by printing; there is no
# pause state and no move history to take a move back off. Said out loud here,
# in the devlog and in both READMEs, because a dead control in front of a
# playtester silently redefines what the session measured.
const CONTROL_CELL := Vector2(140, 140)
const CONTROL_PAD := 20.0
const CONTROLS := ["pause", "takeback"]

const FILES := ["a", "b", "c", "d", "e", "f", "g", "h"]
const FEN_TYPES := {
	"p": "pawn", "n": "knight", "b": "bishop", "r": "rook", "q": "queen", "k": "king",
}
const FEN_CODES := {
	"pawn": "p", "knight": "n", "bishop": "b", "rook": "r", "queen": "q", "king": "k",
}

# Six frames of the pack's own `Idle Blinking`, looped at 10 fps — roughly what
# PvZ's idles run at, and six frames is what fits one atlas page (eighteen would
# be 21 MB of texture for a breathing loop nobody is looking closely at).
const BREATH_FRAMES := 6
const BREATH_STEP_MS := 100

const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

## ADR-0011 decision 6: dimensions and start position are parameters, even though
## nothing but 8x8 and the standard opening is ever passed.
@export var file_count := 8
@export var rank_count := 8
@export var start_fen := START_FEN

var _pieces := {}  # "e1" -> {"type": "king", "color": "white"}
var _page: Texture2D
var _figure_regions := {}  # "white_king" -> [Rect2 x6]
var _crest_regions := {}  # "white_king" -> Rect2, the crest alone, in register
var _hero_regions := {}  # "white" -> Rect2
var _mark_regions := {}  # "move" -> Rect2
var _control_regions := {}  # "pause" -> Rect2
var _hud_regions := {}  # "pedestal" -> Rect2
var _breath_tick := 0
var _selected := ""
var _destinations: Array = []
var _captures: Array = []
var _check := ""
var _last_move: Array = []
var _drag_square := ""
var _drag_point := Vector2.ZERO
# The colour whose move it is, or "" once the game is over. Pushed from
# GameSession, exactly like the marks and the check square -- the board never
# works out whose turn it is.
var _active_color := ""
# The material the game started from, per colour. The graveyard is the
# difference between this and what is on the board *right now*, which is what
# makes it correct for free: nothing increments it, nothing can drift from the
# rules, and it is stale exactly as long as the board is -- so it cannot
# announce a capture the clash has not delivered yet.
var _start_census := {}


func _ready() -> void:
	_load_atlas()
	set_position_from_fen(start_fen)
	resized.connect(queue_redraw)
	# Anchors are resolved before the first draw but not reliably before _ready,
	# and board_origin() is measured off `size`.
	log_layout.call_deferred()


func _process(_delta: float) -> void:
	# The phase offsets below are whole steps, so every figure changes frame on
	# the same 10 Hz boundary and the board redraws ten times a second rather
	# than sixty. Between redraws the renderer replays the same command buffer.
	var tick := Time.get_ticks_msec() / BREATH_STEP_MS
	if tick != _breath_tick:
		_breath_tick = tick
		queue_redraw()


# Placement field of a FEN -> the pieces on the board. Only the placement field
# is read: whose turn it is and what may castle are the rules' business, never
# the view's.
func set_position_from_fen(fen: String) -> void:
	_pieces.clear()
	var placement := fen.split(" ")[0]
	var rank := rank_count
	for row in placement.split("/"):
		var file_index := 0
		for ch in row:
			if ch.is_valid_int():
				file_index += int(ch)
				continue
			var square := "%s%d" % [FILES[file_index], rank]
			_pieces[square] = {
				"type": FEN_TYPES[ch.to_lower()],
				"color": "black" if ch == ch.to_lower() else "white",
			}
			file_index += 1
		rank -= 1
	queue_redraw()


# What `color` has lost, most valuable first, derived from the position rather
# than tallied as captures happen: a counter incremented on each capture is a
# second source of truth about the game, and this project has exactly one
# (ADR-0004). The board is not refreshed until the clash reports done, so this
# is stale for precisely as long as the board is -- which is the behaviour the
# board-view spec asks for, obtained by not writing any code for it.
#
# Promotion is handled but not perfectly, and the imperfection is a property of
# deriving from the position rather than a bug in this function. Every promotion
# consumes one pawn and adds one piece, so the promoted pieces are counted and
# subtracted from the missing pawns; what that cannot see is a promoted queen
# being captured while the original still stands, which reports a lost pawn
# instead of a lost queen. Telling those apart needs move history, and history
# is the second source of truth this is avoiding.
func captured(color: String) -> Array:
	var have := {}
	for square in _pieces:
		var piece: Dictionary = _pieces[square]
		if piece["color"] == color:
			have[piece["type"]] = have.get(piece["type"], 0) + 1
	# Built on first use rather than in _ready(): `start_fen` is an exported
	# parameter (ADR-0011 decision 6) and a BoardView that never enters the tree
	# is a real case -- the suite makes several -- so a census computed in
	# _ready() reports "nothing has been captured" for all of them.
	if _start_census.is_empty():
		_start_census = _census(start_fen)
	var start: Dictionary = _start_census.get(color, {})
	var promoted := 0
	for type in start:
		if type != "pawn":
			promoted += maxi(0, int(have.get(type, 0)) - int(start[type]))
	var out := []
	for type in GRAVE_ORDER:
		var missing := int(start.get(type, 0)) - int(have.get(type, 0))
		if type == "pawn":
			missing -= promoted
		for i in maxi(0, missing):
			out.append(type)
	return out


# Where one colour's graveyard block sits, derived from the board rather than
# written down: the margin is whatever the long edge leaves beside a square
# board, so both follow the board if it ever moves.
#
# **Anchored vertically to match its own army**: white's losses sit low and
# black's sit high, because the board splits the colours top-to-bottom while the
# margins split them left-to-right. Without that echo nothing on screen connects
# "the left margin is white's" to a board where white is at the bottom; with it,
# the connection needs no explaining.
func graveyard_origin(color: String) -> Vector2:
	var y := MARGIN_PAD if color == "black" \
		else size.y - GRAVE_ROWS * GRAVE_CELL.y - MARGIN_PAD
	return Vector2(_margin_x(color, GRAVE_COLUMNS * GRAVE_CELL.x), y).floor()


# The clear band above each commander, reserved for a speech bubble this change
# does not draw. Nothing writes it down: it is whatever a margin has left once
# the graveyard, the commander, the pedestal's overhang and the two pads are
# taken out of it, which is why it comes out the same on both sides -- both
# margins hold the same things.
func hero_headroom() -> float:
	return floorf(size.y - 2.0 * MARGIN_PAD - GRAVE_ROWS * GRAVE_CELL.y - HERO_CELL.y
		- pedestal_drop())


# How far the pool of light reaches past the commander's feet.
func pedestal_drop() -> float:
	return PEDESTAL_SIZE.y * (1.0 - PEDESTAL_ANCHOR)


# The commander's slot, and the one thing in either margin placed by what has to
# be *above* it rather than by what is beside it.
#
# **It stood hard against its own graveyard until Day 9, and a person looking at
# the build said both commanders sit too high.** They were right, and the reason
# is the change that comes after this one: a speech bubble belongs above the
# character speaking, so a commander with 20 px of band over its head can never
# have one. Each margin now reads, top to bottom, as clear room and then the
# commander for white -- graveyard against the bottom -- and as graveyard, clear
# room, then the commander for black. Either way the room is directly above the
# commander and it is the same 275 px on both sides.
#
# The graveyards keep their own army's end of the band regardless (ADR-0011
# decision 5): white's dead low because white's army is at the bottom of the
# board, black's high. That echo is the only thing on screen tying "the left
# margin is white's" to the board, and it is what forces the two margins to
# order their contents differently -- the alternative, both bands ordered the
# same way, buys visual symmetry by spending the one thing the layout is for.
func hero_origin(color: String) -> Vector2:
	# Both sides say the same thing: the commander stands one headroom below
	# whatever is over it. Over white's there is nothing, so it measures from
	# the top of the band; over black's there is black's graveyard.
	var y := hero_headroom()
	if color == "black":
		y += graveyard_origin(color).y + GRAVE_ROWS * GRAVE_CELL.y
	return Vector2(_margin_x(color, HERO_CELL.x), y).floor()


# Where the commander is *actually drawn*, which is hero_origin()'s cell for the
# side to move and a cell shrunk about its own bottom edge for the other one.
# The bubble above it reads this rather than hero_origin(), so its tail lands on
# the head of an idle commander instead of 66 px above it -- and only the tail
# moves, because the box is placed off the full cell and stays put.
func hero_rect(color: String) -> Rect2:
	var cell := Rect2(hero_origin(color), HERO_CELL)
	if _active_color == "" or color == _active_color:
		return cell
	var shrink := HERO_CELL * (1.0 - HERO_IDLE_SCALE)
	return Rect2(cell.position + Vector2(shrink.x * 0.5, shrink.y),
		HERO_CELL * HERO_IDLE_SCALE)


# Where one of the two controls is drawn and where a tap on it lands. Both are
# 140 px, which is wider than a board cell -- the smallest thing this game asks
# a finger to hit.
func control_rect(name: String) -> Rect2:
	var slot := CONTROLS.find(name)
	return Rect2(Vector2(MARGIN_PAD,
		hero_origin("white").y + slot * (CONTROL_CELL.y + CONTROL_PAD)).floor(),
		CONTROL_CELL)


# Which control a point in this control's own space is on, or "" for none.
# Answering it is the whole of what the controls do in this change.
func control_at(point: Vector2) -> String:
	for name in CONTROLS:
		if control_rect(name).has_point(point):
			return name
	return ""


func _margin_x(color: String, width: float) -> float:
	var margin := board_origin().x
	var x := (margin - width) * 0.5
	return x + (margin + board_size().x if color == "black" else 0.0)


func occupied_squares() -> Array:
	var names := _pieces.keys()
	names.sort()
	return names


func piece_on(square: String):
	return _pieces.get(square)


# The inverse of set_position_from_fen(): the placement field of a FEN, rebuilt
# from what the board is actually showing. Nothing in the game reads it — it is
# how the desync check compares the view against RulesAdapter.fen(), and how the
# clash proves the board was still stale while it ran.
func placement() -> String:
	var rows := PackedStringArray()
	for rank in range(rank_count, 0, -1):
		var row := ""
		var gap := 0
		for file_index in file_count:
			var piece = _pieces.get("%s%d" % [FILES[file_index], rank])
			if piece == null:
				gap += 1
				continue
			if gap > 0:
				row += str(gap)
				gap = 0
			var code: String = FEN_CODES[piece["type"]]
			row += code if piece["color"] == "black" else code.to_upper()
		if gap > 0:
			row += str(gap)
		rows.append(row)
	return "/".join(rows)


# The board is centred on whatever it is given; on a 2400x1080 screen an 8x8
# board is 1080x1080 -- the short edge, which is what sets a chessboard's size in
# either orientation -- with 660 px of background to the left of it and 660 to
# the right. That is the space the two commanders, the two graveyards and the
# controls live in (board-view spec), and it is the only thing landscape gives
# the board.
func board_size() -> Vector2:
	return Vector2(file_count * CELL.x, rank_count * CELL.y)


func board_origin() -> Vector2:
	return ((size - board_size()) * 0.5).floor()


func screen_cell(square: String) -> Vector2i:
	return Vector2i(FILES.find(square[0]), rank_count - square.substr(1).to_int())


func cell_rect(square: String) -> Rect2:
	var cell := screen_cell(square)
	return Rect2(board_origin() + Vector2(cell.x * CELL.x, cell.y * CELL.y), CELL)


func square_is_light(square: String) -> bool:
	return (FILES.find(square[0]) + square.substr(1).to_int()) % 2 == 0


# The exact inverse of screen_cell(), and the reason it lives next to it: an
# off-by-one in one axis only shows itself in a corner. "" for a point off the
# board.
func square_at(point: Vector2) -> String:
	var local := point - board_origin()
	if local.x < 0.0 or local.y < 0.0:
		return ""
	var col := int(local.x / CELL.x)
	var row := int(local.y / CELL.y)
	if col >= file_count or row >= rank_count:
		return ""
	return "%s%d" % [FILES[col], rank_count - row]


# `last_move` is the pair of squares the opponent's move joined, or [] for none.
# Told, never worked out: the board does not diff one position against the next
# to find what moved (ADR-0004), for the same reason it is not asked what is
# legal.
func set_marks(selected: String, destinations: Array, captures: Array = [],
		last_move: Array = []) -> void:
	_selected = selected
	_destinations = destinations
	_captures = captures
	_last_move = last_move
	queue_redraw()


# The pair the board is currently marking. Nothing in the game reads it — it is
# how the checks see that the session pushed the pair rather than the board
# inventing it.
func last_move() -> Array:
	return _last_move.duplicate()


# Whose move it is, or "" for a game that is over. Pushed from the session on
# the same beat the position is, which is what keeps the emphasis from moving
# mid-clash: until the clash reports done the board is deliberately showing the
# position before the move, and a commander lit for the side that is about to
# reply would be the one thing on a stale board telling the truth.
func set_active_color(color: String) -> void:
	if color == _active_color:
		return
	_active_color = color
	queue_redraw()
	print("PAWNCH_TURN active=%s" % color)


func active_color() -> String:
	return _active_color


# The cell of the king that is currently attacked, or "" for no check. Pushed
# from the session, which asks the rules — the board never works it out.
func set_check(square: String) -> void:
	_check = square
	queue_redraw()


# The piece under the finger during a drag. `point` is in this control's own
# space, and the figure is drawn centred on it instead of on `square`, so the
# origin cell reads as empty for as long as the drag lasts.
func set_drag(square: String, point: Vector2) -> void:
	_drag_square = square
	_drag_point = point
	queue_redraw()


func clear_drag() -> void:
	_drag_square = ""
	queue_redraw()


func dragging() -> String:
	return _drag_square


func atlas_page() -> Texture2D:
	return _page


func figure_region(color: String, type: String, frame := 0) -> Rect2:
	return _figure_regions["%s_%s" % [color, type]][frame]


func hero_region(color: String) -> Rect2:
	return _hero_regions[color]


func crest_region(color: String, type: String) -> Rect2:
	return _crest_regions["%s_%s" % [color, type]]


# A sub-rectangle of one figure's own region, given in that figure's own cell
# coordinates. The game-over banner cuts the knight's spear out of the knight
# this way rather than shipping a second copy of it (ADR-0009).
func figure_cut(color: String, type: String, cut: Rect2, frame := 0) -> Rect2:
	return Rect2(figure_region(color, type, frame).position + cut.position, cut.size)


func _draw() -> void:
	var origin := board_origin()
	for row in rank_count:
		for col in file_count:
			var square := "%s%d" % [FILES[col], rank_count - row]
			draw_rect(Rect2(origin + Vector2(col * CELL.x, row * CELL.y), CELL),
				LIGHT_SQUARE if square_is_light(square) else DARK_SQUARE)

	if _page == null:
		return

	# Marks and figures all come off the one page, so the whole board is the 64
	# square fills plus a single unbroken run of textured quads however they are
	# interleaved. Which side of the figures a mark goes is therefore purely a
	# legibility decision: the check wash and the move glow read fine underneath,
	# the ring and the selection frame do not — a figure fills 129 of the cell's
	# 135 px and buries anything drawn under it.
	if _check != "":
		_draw_mark(_check, MARK_CHECK)
	for square in _destinations:
		if not _captures.has(square):
			_draw_mark(square, MARK_MOVE)

	# Top row first, so a figure that overhangs its own cell upward is drawn
	# under the one behind it rather than over it. At a square cell nothing
	# overhangs; this is the order that stays correct if anything ever does.
	var by_row := {}
	for square in _pieces:
		if square != _drag_square:
			by_row.get_or_add(screen_cell(square).y, []).append(square)
	for row in rank_count:
		for square in by_row.get(row, []):
			_draw_figure(_pieces[square], cell_rect(square), _breath_frame(square))

	# Over the figures, because half of this pair is a cell with one standing in
	# it and the corners are the only part of a cell a figure leaves clear —
	# and under the ring and the frame, so that the marks the player can act on
	# stay the loud ones on any cell carrying two.
	for square in _last_move:
		_draw_mark(square, MARK_LAST_MOVE)
	for square in _captures:
		_draw_mark(square, MARK_CAPTURE)
	if _selected != "":
		_draw_mark(_selected, MARK_SELECTED)

	# The two margins. Same page as everything above, drawn in the same unbroken
	# run of textured quads, so a commander and fifteen dead a side cost no
	# texture switch and no draw call -- confirmed against the count
	# tests/render_board_states.gd prints, not assumed.
	for color in ["white", "black"]:
		_draw_hero(color)
		var grave := graveyard_origin(color)
		var lost := captured(color)
		for i in mini(lost.size(), GRAVE_COLUMNS * GRAVE_ROWS):
			var at := grave + Vector2((i % GRAVE_COLUMNS) * GRAVE_CELL.x,
				(i / GRAVE_COLUMNS) * GRAVE_CELL.y)
			var cell := Rect2(at, GRAVE_CELL)
			# Two quads, not one: the body dimmed and the crest over it at full
			# colour. The crest is the only thing in the margin saying which
			# piece this was, and dimming it away would leave a row of grey
			# bodies -- which is the graveyard failing at the one job it has.
			draw_texture_rect_region(_page, cell,
				_figure_regions["%s_%s" % [color, lost[i]]][0], FALLEN_TINT)
			draw_texture_rect_region(_page, cell, _crest_regions["%s_%s" % [color, lost[i]]])

	# The two controls, last in the margin run and still on the same page, so
	# they cost no draw call either.
	for name in CONTROLS:
		if _control_regions.has(name):
			draw_texture_rect_region(_page, control_rect(name), _control_regions[name])

	# Last, and over everything: the dragged piece belongs under the finger, not
	# on the square it left.
	if _drag_square != "" and _pieces.has(_drag_square):
		_draw_figure(_pieces[_drag_square],
			Rect2(_drag_point - CELL * Vector2(0.5, 0.75), CELL),
			_breath_frame(_drag_square))


# The commander, and whether it is the one whose move it is. A finished game
# lights neither: nothing on this screen announces a turn that no longer exists,
# and the banner is the message instead.
func _draw_hero(color: String) -> void:
	if not _hero_regions.has(color):
		return
	# Shrunk about the bottom edge when this is not the side to move, so both
	# commanders keep standing on the same line as their own graveyard however
	# small one of them gets.
	var cell := hero_rect(color)
	if color == _active_color:
		# Straddling the feet line, not sitting above it. At 0.62 the figure
		# stood on the *middle* of the pedestal and hid all but its fringe,
		# which rendered as a pale wash nobody would read as emphasis; a little
		# under half of it above the line leaves a pool of light around the
		# boots and the rest of it on the ground in front.
		if _hud_regions.has(HUD_PEDESTAL):
			draw_texture_rect_region(_page, Rect2(
				Vector2(cell.get_center().x, cell.end.y)
					- PEDESTAL_SIZE * Vector2(0.5, PEDESTAL_ANCHOR),
				PEDESTAL_SIZE), _hud_regions[HUD_PEDESTAL])
	draw_texture_rect_region(_page, cell, _hero_regions[color],
		HERO_IDLE_TINT if _active_color != "" and color != _active_color else Color.WHITE)


func _draw_figure(piece: Dictionary, rect: Rect2, frame: int) -> void:
	draw_texture_rect_region(_page, rect,
		_figure_regions["%s_%s" % [piece["color"], piece["type"]]][frame])


func _draw_mark(square: String, mark: String) -> void:
	draw_texture_rect_region(_page, cell_rect(square), _mark_regions[mark])


# Stable per square rather than random per launch, and a bijection over the six
# frames *along a screen row*, so a rank of eight pawns shows six different poses
# instead of two. The coefficients swapped with the un-rotation and they are not
# arbitrary: 5 is coprime with 6 and 2 is not, so the axis a whole army stands
# along has to be the one carrying the 5. Left as it was, the pawn rank would
# have cycled three poses.


func _breath_frame(square: String) -> int:
	var cell := screen_cell(square)
	return (_breath_tick + cell.x * 5 + cell.y * 2) % BREATH_FRAMES


# A FEN placement field -> how many of each type each colour has. Used once, on
# the start position, to give the graveyard something to subtract from.
func _census(fen: String) -> Dictionary:
	var out := {"white": {}, "black": {}}
	for ch in fen.split(" ")[0]:
		if not FEN_TYPES.has(ch.to_lower()):
			continue
		var color := "black" if ch == ch.to_lower() else "white"
		var type: String = FEN_TYPES[ch.to_lower()]
		out[color][type] = out[color].get(type, 0) + 1
	return out


func _load_atlas() -> void:
	_page = load(ATLAS_PAGE)
	var map = load(REGION_MAP)
	var data: Dictionary = map.data if map is JSON \
		else JSON.parse_string(FileAccess.get_file_as_string(REGION_MAP))
	for key in data["figures"]:
		var boxes: Array[Rect2] = []
		for b in data["figures"][key]:
			boxes.append(Rect2(b[0], b[1], b[2], b[3]))
		_figure_regions[key] = boxes
	for key in data["marks"]:
		var b: Array = data["marks"][key]
		_mark_regions[key] = Rect2(b[0], b[1], b[2], b[3])
	for key in data.get("controls", {}):
		var b: Array = data["controls"][key]
		_control_regions[key] = Rect2(b[0], b[1], b[2], b[3])
	for key in data.get("hud", {}):
		var b: Array = data["hud"][key]
		_hud_regions[key] = Rect2(b[0], b[1], b[2], b[3])
	for key in data.get("crests", {}):
		var b: Array = data["crests"][key]
		_crest_regions[key] = Rect2(b[0], b[1], b[2], b[3])
	for key in data.get("heroes", {}):
		var b: Array = data["heroes"][key]
		_hero_regions[key] = Rect2(b[0], b[1], b[2], b[3])


# Which way round the board is drawn is the one thing here that is easy to get
# backwards, and a mirror looks almost right. This prints what a screenshot has
# to agree with.
func log_layout() -> void:
	var origin := board_origin()
	var corners := PackedStringArray()
	for square in ["a1", "h1", "a8", "h8"]:
		var cell := screen_cell(square)
		corners.append("%s=row%d,col%d,%s" % [
			square, cell.y, cell.x, "light" if square_is_light(square) else "dark"])
	print("PAWNCH_BOARD size=%dx%d origin=%d,%d cell=%dx%d %s" % [
		board_size().x, board_size().y, origin.x, origin.y, CELL.x, CELL.y,
		" ".join(corners)])

	# A mirrored board puts the white king one column nearer the a-file edge than
	# the queen instead of one column further. The axis this is read on swapped
	# with the un-rotation, which is exactly the sort of thing that survives a
	# green suite and shows up as a broken board on the phone.
	var king := screen_cell("e1")
	var queen := screen_cell("d1")
	print("PAWNCH_BOARD white_king=e1 row=%d col=%d white_queen=d1 row=%d col=%d reflected=%s" % [
		king.y, king.x, queen.y, queen.x, str(king.x < queen.x)])

	var per_row := {}
	for square in _pieces:
		var key := "%s_row%d" % [_pieces[square]["color"], screen_cell(square).y]
		per_row[key] = per_row.get(key, 0) + 1
	var counts := per_row.keys()
	counts.sort()
	var parts := PackedStringArray()
	for key in counts:
		parts.append("%s=%d" % [key, per_row[key]])
	print("PAWNCH_BOARD pieces=%d %s" % [_pieces.size(), " ".join(parts)])
