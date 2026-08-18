extends Node
class_name GameSession

# Owns the position and whose turn it is. Every move in the game goes through
# here — InputRouter -> GameSession -> RulesAdapter — and the board is told what
# to show rather than asked what is legal. The board never decides legality and
# never plays a move the rules refused (ADR-0004).
#
# Both colours are played on the same device until the bot lands on Day 6. That
# is the intended session, not a gap.

const RulesAdapterScript = preload("res://scripts/rules_adapter.gd")

var board: BoardView
## Duck-typed: anything with `play_capture(attacker_color, attacker_type,
## defender_type)`. Null headless, which is the same thing as a clash of zero
## duration — the ordering below runs either way.
var clash: Node
## Duck-typed: anything with `show_outcome(outcome, winner)` and
## `hide_outcome()`. Null headless.
var banner: Node

var _rules := RulesAdapterScript.new()
# The turn is tracked here rather than read back out of the FEN, because
# `fen()` is the adapter's tests-and-debugging function. It can only flip on a
# move the rules accepted, so it cannot drift; run_headless.gd asserts it
# against the FEN's own side-to-move field anyway.
var _turn := "white"
var _selected := ""
var _destinations: Array = []
var _frozen := false
# Everything below is read off the rules after every position change and cached
# here for the view. The board is never asked what the ending was, and never
# works out which king is attacked — it is told (ADR-0004).
var _captures: Array = []
var _check_square := ""
var _outcome := "in_play"
var _winner := ""


func attach(view: BoardView) -> void:
	board = view
	_sync_board()


func fen() -> String:
	return _rules.fen()


func status() -> String:
	return _rules.status()


func turn() -> String:
	return _turn


func selected() -> String:
	return _selected


func destinations() -> Array:
	return _destinations.duplicate()


# The subset of destinations() that takes something. Two marks, not one: an
# empty destination glows, a takeable piece gets the red ring (move-input spec).
func captures() -> Array:
	return _captures.duplicate()


func is_frozen() -> bool:
	return _frozen


# "in_play", "checkmate" or "stalemate". Never "check" — a check is a position
# in play, not an ending.
func outcome() -> String:
	return _outcome


# The colour that won a checkmate, or "" for a draw or a game still going.
func winner() -> String:
	return _winner


func is_over() -> bool:
	return _outcome != "in_play"


# The cell of the attacked king, or "" when nobody is in check.
func check_square() -> String:
	return _check_square


# Back to the standard opening, white to move, nothing selected and nothing left
# over from the game that just ended.
func restart() -> void:
	_rules = RulesAdapterScript.new()
	_turn = "white"
	_selected = ""
	_destinations = []
	_captures = []
	_frozen = false
	_sync_board()
	print("PAWNCH_RESTART turn=%s status=%s fen=%s" % [_turn, _rules.status(), _rules.fen()])


# Tests and debugging only, exactly like RulesAdapter.fen(): loads a position
# and brings the board, the marks and the outcome into agreement with it.
func load_fen(new_fen: String) -> void:
	_rules.fen(new_fen)
	_turn = "black" if _rules.fen().split(" ")[1] == "b" else "white"
	_selected = ""
	_destinations = []
	_captures = []
	_frozen = false
	_sync_board()


# One tap, already resolved to a square by InputRouter. "" is a tap off the board.
# Dropped outright while a clash runs — not queued, so mashing the screen through
# a clash cannot fire a move once it ends.
func tap(square: String, tap_usec := 0) -> void:
	if _frozen or is_over():
		return
	if square != "" and _destinations.has(square):
		play_move(_selected + square, tap_usec)
		return
	var piece = _rules.piece_at(square) if square != "" else null
	if piece != null and piece["color"] == _turn:
		# A piece with no legal move still selects, with nothing marked, so the
		# tap is visibly refused rather than silently lost.
		_selected = square
		_destinations = _rules.legal_moves(square)
		_captures = _destinations.filter(
			func(to: String) -> bool: return not _capture_in(square + to).is_empty())
		print("PAWNCH_SELECT %s %s destinations=%s captures=%s" % [
			square, piece["type"], ",".join(PackedStringArray(_destinations)),
			",".join(PackedStringArray(_captures))])
		_push_marks()
		return
	_selected = ""
	_destinations = []
	_captures = []
	_push_marks()


# The single commit point. Nothing outside this function calls apply().
#
# The invariant with no compiler behind it (ADR-0002, CLAUDE.md): the move is
# committed here, the instant the rules accept it, and everything after that is
# presentation replaying a fact that is already settled. Do not reorder it — it
# is what makes Day 5's skip safe and desync impossible.
# `tap_usec` is the moment the finger landed, so the clash's cue log is timed
# from the tap that committed the capture rather than from the panel opening.
# Zero for a move with no tap behind it (tests, and the bot on Day 6).
func play_move(uci: String, tap_usec := 0) -> bool:
	# Read before apply(): afterwards the captured piece is gone.
	var capture := _capture_in(uci)
	if not _rules.apply(uci):
		print("PAWNCH_MOVE refused=%s fen=%s" % [uci, _rules.fen()])
		return false
	_turn = "black" if _turn == "white" else "white"
	_selected = ""
	_destinations = []
	_captures = []
	print("PAWNCH_MOVE %s turn=%s status=%s fen=%s" % [uci, _turn, _rules.status(), _rules.fen()])
	if capture.is_empty():
		_sync_board()
	else:
		# Deliberately not awaited: play_move() stays synchronous and the
		# position is already correct. The board catches up when the clash ends.
		_present_capture(capture, tap_usec)
	return true


# {attacker, attacker_type, defender_type} for a move that takes something, or
# {} for a quiet move. Called before apply(), on the position the move starts in.
func _capture_in(uci: String) -> Dictionary:
	if uci.length() < 4:
		return {}
	var from := uci.substr(0, 2)
	var to := uci.substr(2, 2)
	var attacker = _rules.piece_at(from)
	if attacker == null:
		return {}
	var defender = _rules.piece_at(to)
	if defender == null:
		# En passant is the one capture whose victim is not on the destination
		# square: a pawn changing file onto an empty one.
		if attacker["type"] != "pawn" or from[0] == to[0]:
			return {}
		defender = {"type": "pawn"}
	elif defender["color"] == attacker["color"]:
		return {}
	return {
		"attacker": attacker["color"],
		"attacker_type": attacker["type"],
		"defender_type": defender["type"],
	}


# Input freezes, the clash plays, and only then is the board brought into
# agreement with the position. Input returns by itself, with nothing selected.
func _present_capture(capture: Dictionary, tap_usec := 0) -> void:
	_frozen = true
	_push_marks()
	print("PAWNCH_CLASH start fen=%s board=%s" % [_rules.fen(), _board_placement()])
	if clash != null:
		await clash.play_capture(
			capture["attacker"], capture["attacker_type"], capture["defender_type"], tap_usec)
	_sync_board()
	print("PAWNCH_CLASH end fen=%s board=%s" % [_rules.fen(), _board_placement()])
	_frozen = false


# The board catches up here and nowhere else, which is also why the check mark
# and the banner are pushed from here: until the clash reports done the board is
# deliberately showing the position before the move, and a check mark or a
# game-over banner belonging to the position after it would be a lie drawn on
# top of a stale board.
func _sync_board() -> void:
	_refresh_outcome()
	if board != null:
		board.set_position_from_fen(_rules.fen())
		board.set_check(_check_square)
	_push_marks()
	if banner != null:
		if is_over():
			banner.show_outcome(_outcome, _winner)
		else:
			banner.hide_outcome()


# Everything the view needs to know about the state of the game, asked of the
# rules. status() is the single source: checkmate and stalemate are told apart
# there, never here and never on the board.
func _refresh_outcome() -> void:
	var status := _rules.status()
	_outcome = status if status == "checkmate" or status == "stalemate" else "in_play"
	_winner = ("black" if _turn == "white" else "white") if _outcome == "checkmate" else ""
	# A mate is a check, so the attacked king stays marked under the banner.
	_check_square = _king_square(_turn) if status != "in_play" and _outcome != "stalemate" \
		else ""
	if is_over():
		print("PAWNCH_OUTCOME outcome=%s winner=%s fen=%s" % [_outcome, _winner, _rules.fen()])


# The side-to-move's king, found by asking the rules about each square rather
# than by reading the board — the adapter stays at five functions and the view
# stays out of it.
func _king_square(color: String) -> String:
	for file in ["a", "b", "c", "d", "e", "f", "g", "h"]:
		for rank in range(1, 9):
			var square := "%s%d" % [file, rank]
			var piece = _rules.piece_at(square)
			if piece != null and piece["type"] == "king" and piece["color"] == color:
				return square
	return ""


func _board_placement() -> String:
	return board.placement() if board != null else ""


func _push_marks() -> void:
	if board != null:
		board.set_marks(_selected, _destinations, _captures)
