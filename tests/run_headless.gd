extends SceneTree

# Reusable headless entry point: `godot --headless --script tests/run_headless.gd`.
# Runs every suite below, exits 0 if all pass and non-zero if any fail. Day 5's
# 200-random-games desync test and the Day 7 CI test hang off this same runner
# as additional suite functions.

const Chess = preload("res://vendor/chess/Chess.gd")
const RulesAdapter = preload("res://scripts/rules_adapter.gd")
const BoardViewScript = preload("res://scripts/board_view.gd")
const GameSessionScript = preload("res://scripts/game_session.gd")

const PERFT_EXPECTED := [20, 400, 8902, 197281]

const FILES := ["a", "b", "c", "d", "e", "f", "g", "h"]
const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const CHECKMATE_FEN := "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3"
const STALEMATE_FEN := "k7/8/1Q6/8/8/8/8/7K b - - 0 1"
const PROMOTION_FEN := "7k/4P3/8/8/8/8/8/4K3 w - - 0 1"
# Two pieces, on squares that a mirror would move and a rotation would not.
const TWO_PIECE_FEN := "8/8/8/8/8/8/8/3QK3 w - - 0 1"


# Stands in for the duel panel: a clash of zero duration, which is what the
# desync check wants. It also records what the board was showing at the moment
# the clash began, which is the only way to see the commit-before-present
# ordering from the outside.
class ClashStub:
	extends Node

	var board: BoardView
	var calls := 0
	var placement_during := ""
	var attacker := ""
	var attacker_type := ""
	var defender_type := ""

	func play_capture(a_color: String, a_type: String, d_type: String, _tap_usec := 0) -> void:
		calls += 1
		attacker = a_color
		attacker_type = a_type
		defender_type = d_type
		placement_during = board.placement()


func _init() -> void:
	var ok := _run_perft()
	ok = _run_adapter_smoke() and ok
	ok = _run_board_smoke() and ok
	ok = _run_hit_test() and ok
	ok = _run_session_smoke() and ok
	ok = _run_capture_ordering() and ok
	ok = _run_desync_smoke() and ok
	quit(0 if ok else 1)


func _run_perft() -> bool:
	var chess := Chess.new()
	chess.reset()

	var results := []
	var start_ms := Time.get_ticks_msec()
	for depth in range(1, PERFT_EXPECTED.size() + 1):
		results.append(_perft(chess, depth))
	var elapsed_ms := Time.get_ticks_msec() - start_ms

	print("perft 1..%d = %d %d %d %d" % [PERFT_EXPECTED.size(), results[0], results[1], results[2], results[3]])
	print("perft elapsed = %d ms" % elapsed_ms)

	var ok := results == PERFT_EXPECTED
	print("perft: %s" % ("PASS" if ok else "FAIL"))
	return ok


func _perft(chess: Chess, depth: int) -> int:
	if depth == 0:
		return 1
	var moves := chess.generate_legal_moves(false)
	if depth == 1:
		return moves.size()
	var nodes := 0
	for move in moves:
		chess.play_move(move)
		nodes += _perft(chess, depth - 1)
		chess.undo()
	return nodes


func _run_adapter_smoke() -> bool:
	var ok := true
	var a := RulesAdapter.new()

	var total := 0
	for f in FILES:
		for r in range(1, 9):
			total += a.legal_moves("%s%d" % [f, r]).size()
	ok = _check("adapter start legal move count == 20", total == 20) and ok
	ok = _check("adapter empty square returns no moves", a.legal_moves("e4").is_empty()) and ok
	ok = _check("adapter black piece returns no moves on white's turn", a.legal_moves("e7").is_empty()) and ok
	ok = _check("adapter fen() returns start FEN", a.fen() == START_FEN) and ok

	var original_fen := a.fen()
	var after_round_trip := a.fen(original_fen)
	ok = _check("adapter FEN round trip", after_round_trip == original_fen) and ok

	var checkmate := RulesAdapter.new()
	checkmate.fen(CHECKMATE_FEN)
	ok = _check("adapter reports checkmate", checkmate.status() == "checkmate") and ok

	var stalemate := RulesAdapter.new()
	stalemate.fen(STALEMATE_FEN)
	ok = _check("adapter reports stalemate", stalemate.status() == "stalemate") and ok

	# Every destination legal_moves() offers must be playable as a bare move.
	var promotion := RulesAdapter.new()
	promotion.fen(PROMOTION_FEN)
	ok = _check("adapter offers the promotion square once", promotion.legal_moves("e7") == ["e8"]) and ok
	ok = _check("adapter plays a bare promoting move", promotion.apply("e7e8")) and ok
	ok = _check("adapter auto-queens", promotion.piece_at("e8")["type"] == "queen") and ok

	var underpromotion := RulesAdapter.new()
	underpromotion.fen(PROMOTION_FEN)
	underpromotion.apply("e7e8n")
	ok = _check("adapter underpromotes when named", underpromotion.piece_at("e8")["type"] == "knight") and ok

	return ok


# ADR-0011 decision 6: the board takes its dimensions and its start position as
# parameters. Nothing in the game ever passes anything but 8x8 and the opening,
# so this is the only place the parameter is exercised at all.
func _run_board_smoke() -> bool:
	var ok := true

	var board: BoardView = BoardViewScript.new()
	board.set_position_from_fen(TWO_PIECE_FEN)
	var occupied := board.occupied_squares()
	ok = _check("board shows exactly the two pieces the FEN describes",
		occupied == ["d1", "e1"]) and ok
	# screen_col = rank - 1, screen_row = file index (ADR-0011 decision 1).
	ok = _check("board puts the queen at screen row 3, col 0",
		board.screen_cell("d1") == Vector2i(0, 3)) and ok
	ok = _check("board puts the king at screen row 4, col 0",
		board.screen_cell("e1") == Vector2i(0, 4)) and ok
	ok = _check("board is not reflected: the king is further from the a-file edge",
		board.screen_cell("e1").y > board.screen_cell("d1").y) and ok

	var full: BoardView = BoardViewScript.new()
	full.set_position_from_fen(START_FEN)
	ok = _check("board shows 32 pieces from the opening",
		full.occupied_squares().size() == 32) and ok
	ok = _check("board size is 1080x1360", full.board_size() == Vector2(1080, 1360)) and ok
	ok = _check("board corners are a1 top-left and h8 bottom-right",
		full.screen_cell("a1") == Vector2i(0, 0) and full.screen_cell("h8") == Vector2i(7, 7)) and ok
	ok = _check("a1 is dark and h1 is light",
		not full.square_is_light("a1") and full.square_is_light("h1")) and ok

	var small: BoardView = BoardViewScript.new()
	small.file_count = 4
	small.rank_count = 4
	small.set_position_from_fen("4/4/4/RQKR w - - 0 1")
	ok = _check("board accepts non-8x8 dimensions",
		small.occupied_squares().size() == 4 and small.board_size() == Vector2(540, 680)) and ok

	board.free()
	full.free()
	small.free()
	return ok


# The hit test has to invert exactly the rotation the drawing applies, and an
# off-by-one in one axis only ever shows itself in a corner — so every cell is
# probed at its centre and at all four of its corners.
func _run_hit_test() -> bool:
	var board: BoardView = BoardViewScript.new()
	board.size = Vector2(1080, 2400)
	board.set_position_from_fen(START_FEN)

	var checked := 0
	var wrong := PackedStringArray()
	for f in FILES:
		for r in range(1, 9):
			var square := "%s%d" % [f, r]
			var rect := board.cell_rect(square)
			for probe in [rect.get_center(), rect.position + Vector2.ONE,
					Vector2(rect.end.x - 1, rect.position.y + 1),
					Vector2(rect.position.x + 1, rect.end.y - 1),
					rect.end - Vector2.ONE]:
				checked += 1
				if board.square_at(probe) != square:
					wrong.append("%s@%s->%s" % [square, probe, board.square_at(probe)])

	var ok := _check("hit test round-trips all 64 cells (%d probes): %s"
		% [checked, "" if wrong.is_empty() else " ".join(wrong)], wrong.is_empty())
	ok = _check("a tap off the board resolves to no square",
		board.square_at(Vector2(-1, -1)) == "" and board.square_at(Vector2(2000, 2000)) == "") and ok
	board.free()
	return ok


# The session is the only thing that plays a move, and the board never decides
# what is legal.
func _run_session_smoke() -> bool:
	var ok := true
	var board: BoardView = BoardViewScript.new()
	var session: GameSession = GameSessionScript.new()
	session.attach(board)

	var before := session.fen()
	ok = _check("session refuses an illegal move", not session.play_move("e2e5")) and ok
	ok = _check("a refused move leaves the FEN, side to move included, unchanged",
		session.fen() == before and session.fen().split(" ")[1] == "w") and ok
	ok = _check("a refused move leaves the board unchanged",
		board.occupied_squares().size() == 32 and board.piece_on("e2") != null) and ok

	session.tap("b1")
	var knight := session.destinations()
	knight.sort()
	ok = _check("selecting a knight marks its two destinations",
		session.selected() == "b1" and knight == ["a3", "c3"]) and ok

	session.tap("g1")
	ok = _check("tapping another own piece reselects",
		session.selected() == "g1" and session.destinations().size() == 2) and ok

	session.tap("a1")
	ok = _check("a piece with nowhere to go still selects, with nothing marked",
		session.selected() == "a1" and session.destinations().is_empty()) and ok

	session.tap("b1")
	session.tap("e7")
	ok = _check("tapping the other side's piece clears the selection and plays nothing",
		session.selected() == "" and session.fen() == before) and ok

	session.tap("b1")
	session.tap("e5")
	ok = _check("tapping a square that is not a destination clears and plays nothing",
		session.selected() == "" and session.fen() == before) and ok

	session.tap("e2")
	session.tap("e4")
	ok = _check("tapping a marked destination plays the move",
		board.piece_on("e4") != null and board.piece_on("e2") == null) and ok
	ok = _check("the move clears the marks", session.selected() == ""
		and session.destinations().is_empty()) and ok
	ok = _check("the turn passes to black",
		session.turn() == "black" and session.fen().split(" ")[1] == "b") and ok
	ok = _check("the board agrees with the rules",
		board.placement() == session.fen().split(" ")[0]) and ok

	# Ten quiet moves in a row, no capture anywhere, board and rules in step.
	var quiet := ["e7e5", "g1f3", "b8c6", "f1c4", "f8c5", "e1g1", "g8f6", "d2d3", "d7d6"]
	for uci in quiet:
		ok = _check("quiet move %s plays" % uci, session.play_move(uci)) and ok
	ok = _check("ten quiet moves leave the board equal to the rules",
		board.placement() == session.fen().split(" ")[0]) and ok
	ok = _check("the tracked turn still agrees with the FEN",
		session.fen().split(" ")[1] == ("w" if session.turn() == "white" else "b")) and ok

	board.free()
	session.free()
	return ok


# The invariant with no compiler behind it: the position is settled before the
# clash starts, and the board is stale until the clash reports done.
func _run_capture_ordering() -> bool:
	var ok := true
	var board: BoardView = BoardViewScript.new()
	var session: GameSession = GameSessionScript.new()
	var stub := ClashStub.new()
	stub.board = board
	session.attach(board)
	session.clash = stub

	for uci in ["e2e4", "d7d5"]:
		session.play_move(uci)
	var before := board.placement()
	ok = _check("a quiet move plays no clash", stub.calls == 0) and ok

	session.play_move("e4d5")
	ok = _check("a capture plays exactly one clash", stub.calls == 1) and ok
	ok = _check("the clash is told who is fighting",
		stub.attacker == "white" and stub.attacker_type == "pawn"
		and stub.defender_type == "pawn") and ok
	ok = _check("the position already holds the capture when the clash starts",
		session.fen().split(" ")[0] == "rnbqkbnr/ppp1pppp/8/3P4/8/8/PPPP1PPP/RNBQKBNR") and ok
	ok = _check("the board still shows the pre-capture arrangement while the clash runs",
		stub.placement_during == before) and ok
	ok = _check("the board catches up once the clash is done",
		board.placement() == session.fen().split(" ")[0]) and ok
	ok = _check("input is frozen for the clash and returns by itself",
		not session.is_frozen()) and ok

	# En passant is the one capture whose victim is not on the destination square.
	var ep_board: BoardView = BoardViewScript.new()
	var ep: GameSession = GameSessionScript.new()
	var ep_stub := ClashStub.new()
	ep_stub.board = ep_board
	ep.attach(ep_board)
	ep.clash = ep_stub
	for uci in ["e2e4", "a7a6", "e4e5", "d7d5", "e5d6"]:
		ep.play_move(uci)
	ok = _check("en passant is a capture, not a quiet move", ep_stub.calls == 1) and ok
	ok = _check("en passant leaves the board equal to the rules",
		ep_board.placement() == ep.fen().split(" ")[0]) and ok

	stub.free()
	ep_stub.free()
	board.free()
	ep_board.free()
	session.free()
	ep.free()
	return ok


# Twenty random legal games with the clash stubbed to zero duration, asserting
# after every single move that the position rebuilt from what the board shows is
# the position the rules hold. A scaled-down rehearsal of Day 5's 200-game test,
# run today so the invariant is defended before a day of code lands on it.
func _run_desync_smoke() -> bool:
	const GAMES := 20
	const MAX_PLIES := 60
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260817

	var moves := 0
	var captures := 0
	var wrong := PackedStringArray()
	var stale_wrong := 0

	for game in GAMES:
		var board: BoardView = BoardViewScript.new()
		var session: GameSession = GameSessionScript.new()
		var stub := ClashStub.new()
		stub.board = board
		session.attach(board)
		session.clash = stub

		for ply in MAX_PLIES:
			var uci := _random_legal_move(session, board, rng)
			if uci == "":
				break
			var before := board.placement()
			var clashes_before := stub.calls
			if not session.play_move(uci):
				wrong.append("game%d refused %s" % [game, uci])
				break
			moves += 1
			if stub.calls > clashes_before:
				captures += 1
				if stub.placement_during != before:
					stale_wrong += 1
			if board.placement() != session.fen().split(" ")[0]:
				wrong.append("game%d ply%d %s" % [game, ply, uci])
				break

		stub.free()
		board.free()
		session.free()

	print("desync smoke: %d games, %d moves, %d captures" % [GAMES, moves, captures])
	var ok := _check("the board equals the rules after every move: %s"
		% ("" if wrong.is_empty() else " ".join(wrong)), wrong.is_empty())
	ok = _check("the board was stale for every one of those clashes", stale_wrong == 0) and ok
	ok = _check("the smoke actually played captures", captures > 0) and ok
	return ok


# A move for the side to move, picked by choosing a random own piece that has
# somewhere to go. Own pieces are read off the board rather than the rules,
# because the board is the thing being checked.
func _random_legal_move(session: GameSession, board: BoardView, rng: RandomNumberGenerator) -> String:
	if session.status() == "checkmate" or session.status() == "stalemate":
		return ""
	var own := []
	for square in board.occupied_squares():
		if board.piece_on(square)["color"] == session.turn():
			own.append(square)
	while not own.is_empty():
		var square: String = own.pop_at(rng.randi_range(0, own.size() - 1))
		session.tap(square)
		var destinations := session.destinations()
		if destinations.is_empty():
			continue
		var to: String = destinations[rng.randi_range(0, destinations.size() - 1)]
		session.tap("")
		return square + to
	session.tap("")
	return ""


func _check(name: String, condition: bool) -> bool:
	print("check: %s %s" % [name, "PASS" if condition else "FAIL"])
	return condition
