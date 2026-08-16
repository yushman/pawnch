extends SceneTree

# Reusable headless entry point: `godot --headless --script tests/run_headless.gd`.
# Runs every suite below, exits 0 if all pass and non-zero if any fail. Day 5's
# 200-random-games desync test and the Day 7 CI test hang off this same runner
# as additional suite functions.

const Chess = preload("res://vendor/chess/Chess.gd")
const RulesAdapter = preload("res://scripts/rules_adapter.gd")

const PERFT_EXPECTED := [20, 400, 8902, 197281]

const FILES := ["a", "b", "c", "d", "e", "f", "g", "h"]
const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const CHECKMATE_FEN := "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3"
const STALEMATE_FEN := "k7/8/1Q6/8/8/8/8/7K b - - 0 1"
const PROMOTION_FEN := "7k/4P3/8/8/8/8/8/4K3 w - - 0 1"


func _init() -> void:
	var ok := _run_perft()
	ok = _run_adapter_smoke() and ok
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


func _check(name: String, condition: bool) -> bool:
	print("adapter smoke: %s %s" % [name, "PASS" if condition else "FAIL"])
	return condition
