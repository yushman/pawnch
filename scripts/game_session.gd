extends Node
class_name GameSession

# Owns the position and whose turn it is. Every move in the game goes through
# here — InputRouter -> GameSession -> RulesAdapter — and the board is told what
# to show rather than asked what is legal. The board never decides legality and
# never plays a move the rules refused (ADR-0004).
#
# The opponent plays through the same door: it hands back a UCI string and this
# file plays it with play_move(), so there is exactly one way a move reaches the
# rules. With no bot attached both colours are played on the same device, which
# is the session Days 1-5 shipped and the one cut order step 3 returns to.

const RulesAdapterScript = preload("res://scripts/rules_adapter.gd")

var board: BoardView
## Duck-typed: anything with `play_capture(attacker_color, attacker_type,
## defender_type)`. Null headless, which is the same thing as a clash of zero
## duration — the ordering below runs either way.
var clash: Node
## Duck-typed: anything with `show_outcome(outcome, winner)` and
## `hide_outcome()`. Null headless.
var banner: Node
## Duck-typed: anything with `set_state(state, color)`. Null headless.
var indicator: Node
## The opponent (ADR-0005). Duck-typed: anything with `color` and
## `choose(rules) -> String`. Null is the two-human session Days 1-5 were, and
## it must stay a session that changes nothing -- that is what keeps cut order
## step 3 a node and one wiring line.
var bot: Object
## Presentation only (opponent spec): a reply landing in the same frame as the
## player's move reads as the board twitching twice rather than as an opponent
## moving. Zeroed by the suite, which would otherwise pay it once per bot move.
var bot_pause_sec := 0.35

# Emitted when a move the bot played has finished being presented. play_move()
# is synchronous and its presentation is not, so this is how the turn below
# waits for the bot's own clash without a second way to apply a move.
signal reply_presented

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
# The two squares the opponent's last move joined, or [] for nothing to report.
# It exists because a reply that is over in 350 ms leaves nothing on screen
# saying which piece moved -- and after a capture the clash has had the player's
# eyes off the board for the whole of the move it is explaining. A longer pause
# is not the same answer: time lets them look and does not say where, and it is
# spent by the time they have looked.
var _last_move: Array = []
var _outcome := "in_play"
var _winner := ""
# True for the whole of the bot's turn, so the move it plays is presented
# without touching the freeze that turn owns, and so a second turn cannot start
# on top of one that is running.
var _in_bot_turn := false
var _reply_presenting := false


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


# [from, to] of the move the opponent just played, or [] when there is nothing
# to report -- a fresh game, and every moment after the player has committed a
# move of their own.
func last_move() -> Array:
	return _last_move.duplicate()


# Back to the standard opening, white to move, nothing selected and nothing left
# over from the game that just ended.
func restart() -> void:
	_rules = RulesAdapterScript.new()
	_turn = "white"
	_selected = ""
	_destinations = []
	_captures = []
	_last_move = []
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
	_last_move = []
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
	# The mark reports the opponent's move and only that: the player committing
	# a move of their own is what clears it, because from that instant the thing
	# on screen they are being told about is their own move, not the reply they
	# have already answered. `_in_bot_turn` is true for exactly the move the
	# opponent plays, so the two cases are the same line.
	_last_move = [uci.substr(0, 2), uci.substr(2, 2)] if _in_bot_turn else []
	# `last_move` is appended rather than woven in, so anything reading the line
	# by its leading fields still does. It is what the device pass points at when
	# it claims the reply is marked.
	print("PAWNCH_MOVE %s turn=%s status=%s fen=%s last_move=%s" % [
		uci, _turn, _rules.status(), _rules.fen(), ",".join(PackedStringArray(_last_move))])
	# Deliberately not awaited: play_move() stays synchronous and the position is
	# already correct. The board catches up when the presentation ends.
	_present(capture, tap_usec)
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


# One turn's presentation: the clash if the move took something, and then the
# opponent's whole reply -- its pause, its move and its own clash. Input is
# frozen once, on the commit above, and comes back once, when there is nothing
# left to play. Anything that lets the freeze come down in between lets a tap
# through between the two moves (opponent spec).
func _present(capture: Dictionary, tap_usec: int) -> void:
	if _in_bot_turn:
		# The bot's own move, played from inside the turn below. Its
		# presentation belongs to that turn, which owns the freeze, so nothing
		# here touches it.
		if capture.is_empty():
			_sync_board()
			return
		_reply_presenting = true
		await _present_capture(capture, tap_usec)
		_reply_presenting = false
		reply_presented.emit()
		return

	# Read before the presentation, because it decides whether input freezes at
	# all: a quiet move with no reply coming is the two-human session of Days
	# 1-5, drawn on the spot and freezing nothing.
	var reply_due: bool = bot != null and _turn == bot.color
	if capture.is_empty() and not reply_due:
		_sync_board()
		return

	_frozen = true
	_push_marks()
	_push_turn()
	if capture.is_empty():
		_sync_board()
	else:
		await _present_capture(capture, tap_usec)
	if reply_due:
		await _bot_turn()
	_frozen = false


# The opponent's turn, start to end. It is over when this returns, whether it
# moved or not, so the freeze above always comes back down.
func _bot_turn() -> void:
	# It never moves on a finished game and never moves out of turn: the outcome
	# is only true once the presentation above has synced the board, so this is
	# read here and not before the pause.
	if bot == null or is_over() or _turn != bot.color or _in_bot_turn:
		return
	_in_bot_turn = true
	if bot_pause_sec > 0.0 and is_inside_tree():
		# ignore_time_scale: a hitstop still running from the player's clash
		# must not stretch the pause into a hang.
		await get_tree().create_timer(bot_pause_sec, true, false, true).timeout
	var uci: String = bot.choose(_rules)
	if uci == "" or not play_move(uci):
		print("PAWNCH_BOT refused move=%s fen=%s" % [uci, _rules.fen()])
	elif _reply_presenting:
		# Its move captured and the clash is still running. play_move() is
		# synchronous by design, so the presentation reports back by signal.
		await reply_presented
	_in_bot_turn = false


# Input is already frozen, the clash plays, and only then is the board brought
# into agreement with the position.
func _present_capture(capture: Dictionary, tap_usec := 0) -> void:
	print("PAWNCH_CLASH start fen=%s board=%s" % [_rules.fen(), _board_placement()])
	if clash != null:
		await clash.play_capture(
			capture["attacker"], capture["attacker_type"], capture["defender_type"], tap_usec)
	_sync_board()
	print("PAWNCH_CLASH end fen=%s board=%s" % [_rules.fen(), _board_placement()])


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
	_push_turn()


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
		board.set_marks(_selected, _destinations, _captures, _last_move)


# Whose turn it is, pushed the same way the banner is: the indicator is told,
# and never asks. It follows the rules rather than the board, so it names the
# opponent from the moment the player's move is committed -- including while
# that move's clash is still playing over a deliberately stale board.
func _push_turn() -> void:
	if indicator == null:
		return
	if is_over():
		indicator.set_state("over", "")
	elif bot != null and _turn == bot.color:
		indicator.set_state("opponent", _turn)
	else:
		indicator.set_state("player", _turn)
