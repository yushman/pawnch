extends Control
class_name BoardView

# The board, rotated a quarter turn clockwise so white stands on the left
# (ADR-0011 decisions 1, 2, 3, 4 and 6).
#
# The rotation is a coordinate mapping, not a rotated node:
#
#     screen_col = rank - 1        (rank 1 leftmost)
#     screen_row = file index      (file a topmost)
#
# Rotating this node instead would tip every figure onto its side. Nothing here
# is ever mirrored either: a mirror reflects the position — king and queen swap
# files — which reads as a broken board. The rules know none of it; a1 is a1.
#
# Everything is drawn by this one CanvasItem, in one pass: squares, the marks
# that belong under a figure, then figures row by row from the top, then the
# marks that belong over one. Row by row from the top is what makes a figure
# overlap the one in the cell above it without a y-sort, and the whole board
# stays two batches — the squares share the white texture and every mark comes
# off the same atlas page as the figures, so there is exactly one texture switch
# in the frame however the two are interleaved.
#
# Piece type is carried by the head crest and nothing else (ADR-0011 decision 4,
# reversed 2026-08-17). A tile crest glyph shipped for one afternoon and was
# dropped: it cost a fifth of every figure's height and still could not separate
# the king from the queen.

const CELL := Vector2(135, 170)
const ATLAS_PAGE := "res://assets/board/pieces.png"
const REGION_MAP := "res://assets/board/pieces.json"

const LIGHT_SQUARE := Color(0.93, 0.87, 0.74)
const DARK_SQUARE := Color(0.49, 0.35, 0.24)

# Four marks, all quads out of the same atlas page the figures come from, so
# they cost no draw call at all: Day 4 drew them as `draw_rect` outlines and
# measured +3..6, because an unbatched primitive breaks the run of textured
# quads either side of it. Geometry tells them apart before colour does — a
# blob in the middle, a ring round the figure, a wash on the cell's edges, a
# frame on them (tools/bake_board_atlas.py).
const MARK_MOVE := "move"
const MARK_CAPTURE := "capture"
const MARK_CHECK := "check"
const MARK_SELECTED := "selected"

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
var _mark_regions := {}  # "move" -> Rect2
var _breath_tick := 0
var _selected := ""
var _destinations: Array = []
var _captures: Array = []
var _check := ""
var _drag_square := ""
var _drag_point := Vector2.ZERO


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


# The board is centred on whatever it is given; on a 1080x2400 screen an 8x8
# board is 1080x1360 with 520 px of background above and below, which puts it
# under the same band the duel panel occupies.
func board_size() -> Vector2:
	return Vector2(rank_count * CELL.x, file_count * CELL.y)


func board_origin() -> Vector2:
	return ((size - board_size()) * 0.5).floor()


func screen_cell(square: String) -> Vector2i:
	return Vector2i(square.substr(1).to_int() - 1, FILES.find(square[0]))


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
	if col >= rank_count or row >= file_count:
		return ""
	return "%s%d" % [FILES[row], col + 1]


func set_marks(selected: String, destinations: Array, captures: Array = []) -> void:
	_selected = selected
	_destinations = destinations
	_captures = captures
	queue_redraw()


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


func _draw() -> void:
	var origin := board_origin()
	for row in file_count:
		for col in rank_count:
			var square := "%s%d" % [FILES[row], col + 1]
			draw_rect(Rect2(origin + Vector2(col * CELL.x, row * CELL.y), CELL),
				LIGHT_SQUARE if square_is_light(square) else DARK_SQUARE)

	if _page == null:
		return

	# Marks and figures all come off the one page, so the whole board is the 64
	# square fills plus a single unbroken run of textured quads however they are
	# interleaved. Which side of the figures a mark goes is therefore purely a
	# legibility decision: the check wash and the move glow read fine underneath,
	# the ring and the selection frame do not — a figure fills 123 of the cell's
	# 135 px and buries anything drawn under it.
	if _check != "":
		_draw_mark(_check, MARK_CHECK)
	for square in _destinations:
		if not _captures.has(square):
			_draw_mark(square, MARK_MOVE)

	# Top row first: a figure overhangs upward, so the lower cell must draw last.
	var by_row := {}
	for square in _pieces:
		if square != _drag_square:
			by_row.get_or_add(screen_cell(square).y, []).append(square)
	for row in file_count:
		for square in by_row.get(row, []):
			_draw_figure(_pieces[square], cell_rect(square), _breath_frame(square))

	for square in _captures:
		_draw_mark(square, MARK_CAPTURE)
	if _selected != "":
		_draw_mark(_selected, MARK_SELECTED)

	# Last, and over everything: the dragged piece belongs under the finger, not
	# on the square it left.
	if _drag_square != "" and _pieces.has(_drag_square):
		_draw_figure(_pieces[_drag_square],
			Rect2(_drag_point - CELL * Vector2(0.5, 0.75), CELL),
			_breath_frame(_drag_square))


func _draw_figure(piece: Dictionary, rect: Rect2, frame: int) -> void:
	draw_texture_rect_region(_page, rect,
		_figure_regions["%s_%s" % [piece["color"], piece["type"]]][frame])


func _draw_mark(square: String, mark: String) -> void:
	draw_texture_rect_region(_page, cell_rect(square), _mark_regions[mark])


# Stable per square rather than random per launch, and a bijection over the six
# frames down a screen column, so a file of eight pawns shows six different
# poses instead of two.


func _breath_frame(square: String) -> int:
	var cell := screen_cell(square)
	return (_breath_tick + cell.y * 5 + cell.x * 2) % BREATH_FRAMES


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


# The rotation is the one thing on this board that is easy to get backwards, and
# a mirror looks almost right. This prints what a screenshot has to agree with.
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

	# A mirrored board puts the white king one row nearer the a-file edge than
	# the queen instead of one row further.
	var king := screen_cell("e1")
	var queen := screen_cell("d1")
	print("PAWNCH_BOARD white_king=e1 row=%d col=%d white_queen=d1 row=%d col=%d reflected=%s" % [
		king.y, king.x, queen.y, queen.x, str(king.y < queen.y)])

	var per_col := {}
	for square in _pieces:
		var key := "%s_col%d" % [_pieces[square]["color"], screen_cell(square).x]
		per_col[key] = per_col.get(key, 0) + 1
	var counts := per_col.keys()
	counts.sort()
	var parts := PackedStringArray()
	for key in counts:
		parts.append("%s=%d" % [key, per_col[key]])
	print("PAWNCH_BOARD pieces=%d %s" % [_pieces.size(), " ".join(parts)])
