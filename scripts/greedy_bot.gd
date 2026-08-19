extends Node
class_name GreedyBot

# The opponent, and deliberately a bad one (ADR-0005). One ply, no evaluation,
# no search, no book: it takes the most valuable thing it can reach and
# otherwise wanders forward. It hangs pieces constantly, and that is the
# behavior being specified rather than a defect -- a hung piece is an invitation
# to capture, a capture is a clash, and the clash is what this sprint measures.
# Making it play well would produce fewer clashes per session.
#
# It never touches the position: choose() returns a UCI string and GameSession
# plays it through the same play_move() a tap ends in. It sees the rules through
# piece_at() and legal_moves() and nothing else, so the adapter stays at five
# functions (ADR-0004) and nothing here reaches into vendor/chess/.
#
# Cut order step 3 deletes this file and one wiring line in InputRouter. Keep it
# that cheap.

const FILES := ["a", "b", "c", "d", "e", "f", "g", "h"]

# MVV-LVA, and the whole of the evaluation. The king's value is only ever read
# as the attacker's -- a king is never a victim, because a position where one
# could be taken is not reachable.
const VALUE := {"pawn": 1, "knight": 3, "bishop": 3, "rook": 5, "queen": 9, "king": 100}

# A quiet move that carries a piece toward the player is drawn twice as often as
# one that does not. Light on purpose: a hard bias marches the same pawn down
# the board every game, and the point is only that contact happens sooner.
const ADVANCE_WEIGHT := 2
const QUIET_WEIGHT := 1

## The colour it plays. GameSession reads it to know which turn is its turn, and
## choose() reads it to enumerate its own pieces -- 16 move generations a turn
## instead of 64.
@export var color := "black"

## Public so a strange game can be replayed: the seed is printed at startup and
## the suite sets it by hand.
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	print("PAWNCH_BOT ready color=%s seed=%d" % [color, rng.seed])


# `rules` is a RulesAdapter, duck-typed down to piece_at() and legal_moves().
# Returns a UCI move for its own colour, or "" when it has nothing to play --
# which the caller must already know, because a side with no move is mate or
# stalemate and the game is over.
func choose(rules) -> String:
	var started_usec := Time.get_ticks_usec()
	var captures: Array = []
	var best_score := -1
	var quiet: Array = []
	for square in _own_squares(rules):
		var attacker: String = rules.piece_at(square)["type"]
		for to in rules.legal_moves(square):
			var victim := _victim(rules, square, to, attacker)
			if victim == "":
				quiet.append({"uci": square + to, "weight": _weight(square, to)})
				continue
			# Most valuable victim first, ties to the least valuable attacker.
			# What the reply does to the piece it just moved is not looked at,
			# which is exactly how it hangs pieces.
			var score: int = VALUE[victim] * 100 - VALUE[attacker]
			if score > best_score:
				best_score = score
				captures = []
			if score == best_score:
				captures.append({"uci": square + to, "victim": victim})

	var chosen := ""
	var reason := "quiet"
	var victim_name := "none"
	if not captures.is_empty():
		# Genuinely equal captures are drawn rather than taken in board order, so
		# the same opening does not produce the same game every time.
		var pick: Dictionary = captures[rng.randi_range(0, captures.size() - 1)]
		chosen = pick["uci"]
		reason = "capture"
		victim_name = pick["victim"]
	elif not quiet.is_empty():
		chosen = _draw(quiet)
	print("PAWNCH_BOT move=%s reason=%s victim=%s ms=%d" % [
		chosen, reason, victim_name, (Time.get_ticks_usec() - started_usec) / 1000])
	return chosen


# Its own pieces, in board order so the search is reproducible from the seed.
# legal_moves() is asked only about these: it answers "" for the other side
# anyway, but asking costs a full legal-move generation per square.
func _own_squares(rules) -> Array:
	var squares := []
	for f in FILES:
		for r in range(1, 9):
			var square := "%s%d" % [f, r]
			var piece = rules.piece_at(square)
			if piece != null and piece["color"] == color:
				squares.append(square)
	return squares


# The type this move takes, or "" for a quiet move. legal_moves() never offers a
# square holding its own piece, so an occupied destination is always a victim.
func _victim(rules, from: String, to: String, attacker: String) -> String:
	var piece = rules.piece_at(to)
	if piece != null:
		return piece["type"]
	# En passant is the one capture whose victim is not on the destination
	# square: a pawn changing file onto an empty one has taken a pawn.
	if attacker == "pawn" and from[0] != to[0]:
		return "pawn"
	return ""


func _weight(from: String, to: String) -> int:
	var forward := -1 if color == "black" else 1
	var advance := (to.substr(1).to_int() - from.substr(1).to_int()) * forward
	return ADVANCE_WEIGHT if advance > 0 else QUIET_WEIGHT


func _draw(moves: Array) -> String:
	var total := 0
	for move in moves:
		total += int(move["weight"])
	var roll := rng.randi_range(1, total)
	for move in moves:
		roll -= int(move["weight"])
		if roll <= 0:
			return move["uci"]
	return moves[moves.size() - 1]["uci"]
