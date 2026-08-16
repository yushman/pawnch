extends RefCounted
class_name RulesAdapter

# Five-function seam over the vendored chess rules (ADR-0004). Nothing outside
# this file and tests may reference vendor/chess/Chess.gd or vendor/chess/Move.gd.
# Squares are algebraic strings ("e4"); fen() is the only function meant for
# tests and debugging, not game code.

const Chess = preload("res://vendor/chess/Chess.gd")

const PIECE_TYPE_NAMES := {
	"p": "pawn", "n": "knight", "b": "bishop", "r": "rook", "q": "queen", "k": "king",
}

var _chess := Chess.new()


func _init() -> void:
	_chess.reset()


# Legal destination squares for the piece on `square`. Empty for an empty
# square or a piece of the side not to move.
func legal_moves(square: String) -> Array:
	var from_idx := Chess.square_index_from_name(square)
	var piece = _chess.pieces[from_idx] if from_idx >= 0 and from_idx < 64 else null
	if piece == null or Chess.piece_color(piece) != _chess.turn:
		return []

	var destinations := []
	for move in _chess.generate_legal_moves(false):
		if move.from_square == from_idx:
			var to_name = Chess.square_get_name(move.to_square)
			if not destinations.has(to_name):
				destinations.append(to_name)
	return destinations


# Plays `move` (UCI-style "e2e4", or "e7e8q" to name a promotion piece) if
# legal. Mutates the position and returns true, or refuses and returns false
# unchanged. A promoting move with no piece named auto-queens, so that every
# destination legal_moves() offers can be played back as a bare four-character
# move; underpromotion is reachable only by naming the piece.
func apply(move: String) -> bool:
	if move.length() < 4:
		return false
	var from_idx := Chess.square_index_from_name(move.substr(0, 2))
	var to_idx := Chess.square_index_from_name(move.substr(2, 2))
	var promotion := move.substr(4, 1).to_lower() if move.length() >= 5 else ""

	for candidate in _chess.generate_legal_moves(false):
		if candidate.from_square != from_idx or candidate.to_square != to_idx:
			continue
		var candidate_promotion = candidate.promotion.to_lower() if candidate.promotion else ""
		var wanted := promotion
		if wanted == "" and candidate_promotion != "":
			wanted = "q"
		if candidate_promotion != wanted:
			continue
		_chess.play_move(candidate)
		return true
	return false


# One of "in_play", "check", "checkmate", "stalemate".
func status() -> String:
	var has_moves := _chess.generate_legal_moves(false).size() > 0
	var in_check := _chess.in_check()
	if not has_moves:
		return "checkmate" if in_check else "stalemate"
	return "check" if in_check else "in_play"


# {type, color} for the piece on `square`, or null for an empty square.
func piece_at(square: String):
	var idx := Chess.square_index_from_name(square)
	if idx < 0 or idx >= 64:
		return null
	var piece = _chess.pieces[idx]
	if piece == null:
		return null
	return {
		"type": PIECE_TYPE_NAMES[piece.to_lower()],
		"color": "black" if Chess.piece_color(piece) else "white",
	}


# Tests and debugging only. With no argument, returns the current position as
# FEN. With `new_fen`, loads that position first (no-op if invalid), then
# always returns the resulting position as FEN.
func fen(new_fen: String = "") -> String:
	if new_fen != "":
		_chess.set_fen(new_fen)
	return _chess.get_fen()
