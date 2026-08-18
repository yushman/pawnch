extends RefCounted

# Every check in the project, run by tests/run_headless.gd. It lives in its own
# file so that the runner that decides the exit code is small enough not to
# break: a parse error in this file makes the runner fail loudly, where a parse
# error in the runner itself is invisible -- Godot prints it and exits 0.
#
# Not a SceneTree: the tree is handed in, because the runner owns the loop.

const Chess = preload("res://vendor/chess/Chess.gd")
const RulesAdapter = preload("res://scripts/rules_adapter.gd")
const BoardViewScript = preload("res://scripts/board_view.gd")
const GameSessionScript = preload("res://scripts/game_session.gd")
const DuelPanelScript = preload("res://scripts/duel_panel.gd")

const PERFT_EXPECTED := [20, 400, 8902, 197281]

const FILES := ["a", "b", "c", "d", "e", "f", "g", "h"]
const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const CHECKMATE_FEN := "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3"
const STALEMATE_FEN := "k7/8/1Q6/8/8/8/8/7K b - - 0 1"
const PROMOTION_FEN := "7k/4P3/8/8/8/8/8/4K3 w - - 0 1"
# One move away from each ending, so the outcome is asserted after a move the
# session played rather than after a position that was simply loaded.
# The fool's mate, one move short of it: 1.f3 e5 2.g4, and Qh4 ends it.
const MATE_IN_ONE_FEN := "rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq g3 0 2"
const STALEMATE_IN_ONE_FEN := "7k/8/8/8/8/8/5Q2/6K1 w - - 0 1"
const CHECK_FEN := "rnbqkbnr/pppppppp/8/8/8/5Q2/PPPPPPPP/RNB1KBNR w KQkq - 0 1"
# Two pieces, on squares that a mirror would move and a rotation would not.
const TWO_PIECE_FEN := "8/8/8/8/8/8/8/3QK3 w - - 0 1"

## Every 10 ms across the full clash, as the plan asks. The epsilon is there so
## the last offset -- the clash's own length -- is not lost to float addition.
const SKIP_STEP_SEC := 0.01
const SKIP_EPSILON := 0.0001


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


# Stands in for the game-over banner: records what it was last told, which is
# how the outcome checks see that the banner is driven by the rules and not by
# the board.
class BannerStub:
	extends Node

	var shown := 0
	var hidden := 0
	var outcome := ""
	var winner := ""

	func show_outcome(new_outcome: String, new_winner: String) -> void:
		shown += 1
		outcome = new_outcome
		winner = new_winner

	func hide_outcome() -> void:
		hidden += 1
		outcome = ""
		winner = ""


## The tree the runner is driving. Suites that need the real scene add it here.
var tree: SceneTree
var passed := 0
var failed := 0


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	_run_perft()
	_run_adapter_smoke()
	_run_board_smoke()
	_run_hit_test()
	_run_session_smoke()
	_run_capture_ordering()
	_run_outcome_smoke()
	_run_capture_marks()
	_run_clash_lookup()
	await _run_gesture_smoke()
	await _run_clash_finish()
	await _run_skip_offsets()
	_run_desync_smoke()


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


# Checkmate, stalemate and check all come from RulesAdapter.status() and nowhere
# else, and the banner is told what the rules said rather than what the board
# looks like.
func _run_outcome_smoke() -> bool:
	var ok := true

	var board: BoardView = BoardViewScript.new()
	var session: GameSession = GameSessionScript.new()
	var banner := BannerStub.new()
	session.banner = banner
	session.attach(board)
	ok = _check("a fresh game is in play with no banner",
		session.outcome() == "in_play" and not session.is_over()
		and banner.shown == 0) and ok

	session.load_fen(MATE_IN_ONE_FEN)
	ok = _check("a position one move from mate is still in play",
		session.outcome() == "in_play") and ok
	ok = _check("mate in one plays", session.play_move("d8h4")) and ok
	ok = _check("the rules call it checkmate, not stalemate",
		session.outcome() == "checkmate" and session.status() == "checkmate") and ok
	ok = _check("the banner names the side that just moved as the winner",
		banner.outcome == "checkmate" and banner.winner == "black") and ok
	ok = _check("the mated king's cell is marked",
		session.check_square() == "e1") and ok
	ok = _check("no further move can be played on a finished game",
		not session.play_move("e2e4")) and ok
	session.tap("e2")
	ok = _check("a tap on a finished game selects nothing",
		session.selected() == "") and ok

	var draw_board: BoardView = BoardViewScript.new()
	var draw_session: GameSession = GameSessionScript.new()
	var draw_banner := BannerStub.new()
	draw_session.banner = draw_banner
	draw_session.attach(draw_board)
	draw_session.load_fen(STALEMATE_IN_ONE_FEN)
	ok = _check("stalemate in one plays", draw_session.play_move("f2f7")) and ok
	ok = _check("the rules call it stalemate, not checkmate",
		draw_session.outcome() == "stalemate" and draw_session.winner() == "") and ok
	ok = _check("the banner names it a draw",
		draw_banner.outcome == "stalemate" and draw_banner.winner == "") and ok
	ok = _check("a stalemated king is not marked as in check",
		draw_session.check_square() == "") and ok

	var check_board: BoardView = BoardViewScript.new()
	var check_session: GameSession = GameSessionScript.new()
	check_session.attach(check_board)
	check_session.load_fen(CHECK_FEN)
	ok = _check("nobody is marked before the check is given",
		check_session.check_square() == "" and check_session.status() == "in_play") and ok
	ok = _check("giving check marks the attacked king",
		check_session.play_move("f3f7") and check_session.check_square() == "e8") and ok
	ok = _check("a check is reported as a check and not as an ending",
		check_session.status() == "check" and check_session.outcome() == "in_play"
		and not check_session.is_over()) and ok
	ok = _check("play continues while the mark is up", check_session.play_move("e8f7")) and ok
	ok = _check("the mark clears with the position",
		check_session.check_square() == "") and ok

	# Restart is the same reset the banner offers, and it has to leave nothing
	# behind — not a mark, not a captured piece, not the check from the game
	# that just ended.
	session.restart()
	ok = _check("restart returns the standard opening FEN, white to move",
		session.fen() == START_FEN and session.turn() == "white") and ok
	ok = _check("restart clears the banner, the selection and the check mark",
		not session.is_over() and session.selected() == ""
		and session.check_square() == "" and banner.hidden > 0) and ok
	ok = _check("restart leaves a full board with the rules and the view in step",
		board.occupied_squares().size() == 32
		and board.placement() == session.fen().split(" ")[0]) and ok
	for uci in ["e2e4", "e7e5", "g1f3"]:
		ok = _check("the restarted game plays %s" % uci, session.play_move(uci)) and ok

	banner.free()
	draw_banner.free()
	board.free()
	draw_board.free()
	check_board.free()
	session.free()
	draw_session.free()
	check_session.free()
	return ok


# The glow and the ring are two different marks, and which one a destination
# gets is decided by the rules — including for en passant, whose victim is not
# on the destination square at all.
func _run_capture_marks() -> bool:
	var ok := true
	var board: BoardView = BoardViewScript.new()
	var session: GameSession = GameSessionScript.new()
	session.attach(board)

	for uci in ["e2e4", "d7d5"]:
		session.play_move(uci)
	session.tap("e4")
	var destinations := session.destinations()
	destinations.sort()
	ok = _check("the e4 pawn is offered both an empty square and a capture",
		destinations == ["d5", "e5"]) and ok
	ok = _check("only the occupied destination is marked as a capture",
		session.captures() == ["d5"]) and ok

	var ep_board: BoardView = BoardViewScript.new()
	var ep: GameSession = GameSessionScript.new()
	ep.attach(ep_board)
	for uci in ["e2e4", "a7a6", "e4e5", "d7d5"]:
		ep.play_move(uci)
	ep.tap("e5")
	ok = _check("an en passant destination is marked as a capture even though it is empty",
		ep.captures() == ["d6"]) and ok

	board.free()
	ep_board.free()
	session.free()
	ep.free()
	return ok


# Tap and drag are two gestures and one path (move-input spec), and the only way
# to prove they are one path is to drive InputRouter itself. This is also the
# one suite that loads the real scene, so it is the one that would catch a node
# reference that came back null — five of them have in this project.
func _run_gesture_smoke() -> bool:
	var ok := true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame

	var router: InputRouter = main.get_node("InputRouter")
	var board: BoardView = main.get_node("Board")
	var session: GameSession = main.get_node("Session")
	ok = _check("the scene wires the router to a board, a session, a clash and a banner",
		router.board != null and router.session != null and router.clash != null
		and router.banner != null) and ok

	# 1.d4 by drag.
	var from := board.cell_rect("d2").get_center()
	var to := board.cell_rect("d4").get_center()
	router._press(from)
	ok = _check("a press on an own piece selects it and arms a drag",
		session.selected() == "d2" and board.dragging() == "d2") and ok
	router._moved(from.lerp(to, 0.5))
	ok = _check("the piece stays under the finger for the whole drag",
		board.dragging() == "d2" and board.piece_on("d2") != null) and ok
	router._release(to)
	ok = _check("releasing on a legal destination plays the move",
		session.fen().split(" ")[0] == "rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR") and ok
	ok = _check("the drag is over and the board agrees with the rules",
		board.dragging() == "" and board.placement() == session.fen().split(" ")[0]) and ok

	# 1...d5 by tap: press and release on the same square is a drag that went
	# nowhere, so the selection it made stands and the second tap commits.
	router._press(board.cell_rect("d7").get_center())
	router._release(board.cell_rect("d7").get_center())
	ok = _check("a press and release on the same square leaves the piece selected",
		session.selected() == "d7" and board.dragging() == "") and ok
	router._press(board.cell_rect("d5").get_center())
	router._release(board.cell_rect("d5").get_center())
	ok = _check("tapping a marked destination plays the same move a drag would have",
		session.fen().split(" ")[0] == "rnbqkbnr/ppp1pppp/8/3p4/3P4/8/PPP1PPPP/RNBQKBNR") and ok

	# A release nowhere legal plays nothing and puts the piece back.
	var before := session.fen()
	var placement := board.placement()
	router._press(board.cell_rect("g1").get_center())
	router._release(board.cell_rect("g4").get_center())
	ok = _check("a drag released on an illegal square plays nothing",
		session.fen() == before and board.placement() == placement) and ok
	ok = _check("and puts the piece back on the square it started from",
		board.dragging() == "" and board.piece_on("g1") != null
		and session.selected() == "") and ok

	router._press(board.cell_rect("b1").get_center())
	router._release(Vector2(-80, -80))
	ok = _check("a drag released off the board plays nothing either",
		session.fen() == before and board.piece_on("b1") != null
		and board.dragging() == "" and session.selected() == "") and ok

	# The other side's pieces are not draggable.
	router._press(board.cell_rect("e7").get_center())
	ok = _check("pressing the other side's piece arms nothing",
		session.selected() == "" and board.dragging() == "") and ok

	# Back with a piece selected clears it. The clash branch needs finish_now()
	# (Block C) and the third branch quits the app, so neither is driven here.
	router._press(board.cell_rect("e2").get_center())
	router._release(board.cell_rect("e2").get_center())
	router._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	ok = _check("back with a piece selected clears the selection and plays nothing",
		session.selected() == "" and session.destinations().is_empty()
		and session.fen() == before) and ok

	# Android 13+ hands one back press to the engine twice (measured on device,
	# ~13ms apart). Unfiltered, the first press cleared the selection and the
	# second fell through to quit(), so a single back closed the app. _back()
	# reports whether it acted, because the alternative -- letting the second
	# one run -- ends the process the suite is running in.
	var wait_until := Time.get_ticks_msec() + InputRouter.BACK_DEDUPE_MSEC + 1
	while Time.get_ticks_msec() < wait_until:
		await tree.process_frame
	router._press(board.cell_rect("e2").get_center())
	router._release(board.cell_rect("e2").get_center())
	ok = _check("the first back press acts", router._back()) and ok
	ok = _check("a back press duplicated by the platform is dropped, not a quit",
		not router._back()) and ok

	main.free()
	return ok


# Failure mode 3 (system-analysis.md): a capture that resolves to no clash takes
# a piece off the board with no animation and no error to notice. The lookup has
# to be incapable of returning nothing, and it has to be incapable of it today,
# before the shared generic strike is authored -- that is what makes "no capture
# is ever silent" a thing a test can hold. Moves into CI on Day 7.
func _run_clash_lookup() -> bool:
	var ok := true
	var wrong := PackedStringArray()
	for type: String in DuelPanelScript.PIECE_TYPES:
		var chosen: Dictionary = DuelPanelScript.clash_for(type)
		if chosen.is_empty() or String(chosen["name"]) == "" or float(chosen["duration"]) <= 0.0:
			wrong.append(type)
	ok = _check("all six attacker types resolve to a clash of non-zero duration: %s"
		% " ".join(wrong), wrong.is_empty()) and ok
	ok = _check("the six types are the six piece types",
		DuelPanelScript.PIECE_TYPES.size() == 6) and ok
	var unknown: Dictionary = DuelPanelScript.clash_for("archbishop")
	ok = _check("a type the table has never heard of falls back rather than returning nothing",
		bool(unknown["fallback"]) and float(unknown["duration"]) > 0.0) and ok
	ok = _check("every type takes the fallback today, because none has a clash of its own yet",
		DuelPanelScript.CLASH_BY_TYPE.is_empty()) and ok
	return ok


# finish_now() is the one way a clash ends, and every path that ends one goes
# through it. What has to be true of it: it is idempotent, it is reachable from
# a tap and from the back button, it works when nothing is running, and a clash
# cannot start on top of one that is already going.
func _run_clash_finish() -> bool:
	var ok := true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame

	var router: InputRouter = main.get_node("InputRouter")
	var session: GameSession = main.get_node("Session")
	var board: BoardView = main.get_node("Board")
	var panel: Node = main.get_node("DuelPanel")
	var white: CharacterRig = panel.get_node("Frame/Mask/Stage/White")
	var black: CharacterRig = panel.get_node("Frame/Mask/Stage/Black")

	ok = _check("nothing is clashing before a capture is played",
		not panel.is_clashing() and not session.is_frozen()) and ok
	panel.finish_now("test")
	ok = _check("finishing a clash that is not running does nothing",
		not panel.is_clashing() and not session.is_frozen()) and ok

	_play_capture(session)
	ok = _check("a capture starts a clash and freezes input",
		panel.is_clashing() and session.is_frozen()) and ok
	ok = _check("the clash is dressed as the pieces that are fighting",
		white.piece_type == "pawn" and black.piece_type == "pawn") and ok
	panel.play_capture("black", "queen", "rook")
	ok = _check("a clash cannot start while one is already running",
		white.piece_type == "pawn" and black.piece_type == "pawn") and ok

	panel.finish_now("test")
	ok = _check("finish_now ends the clash on the spot", not panel.is_clashing()) and ok
	panel.finish_now("test")
	panel.finish_now("test")
	ok = _check("asking twice more changes nothing and raises nothing",
		not panel.is_clashing()) and ok
	ok = _check("input comes back after a skip", await _await_unfrozen(session)) and ok
	ok = _check("the board caught up with the rules anyway",
		board.placement() == session.fen().split(" ")[0]) and ok
	ok = _check("a skipped capture is still a capture",
		board.piece_on("d5") != null and board.piece_on("e4") == null) and ok

	# The back button, which had nothing to call until now (Block B).
	_play_capture(session)
	router._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	ok = _check("back during a clash finishes it instead of quitting",
		not panel.is_clashing()) and ok
	ok = _check("and input comes back", await _await_unfrozen(session)) and ok

	# A tap anywhere, which is what a child will actually do.
	_play_capture(session)
	var before := session.fen()
	router._press(board.cell_rect("a1").get_center())
	ok = _check("a tap during a clash finishes it", not panel.is_clashing()) and ok
	ok = _check("and plays nothing of its own", session.fen() == before) and ok
	ok = _check("and input comes back", await _await_unfrozen(session)) and ok

	# Backgrounded mid-clash: finished, not resumed.
	_play_capture(session)
	router._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	router._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	ok = _check("a clash caught by the platform is finished, not resumed",
		not panel.is_clashing()) and ok
	ok = _check("and the app comes back usable", await _await_unfrozen(session)) and ok
	ok = _check("with the board and the rules in step",
		board.placement() == session.fen().split(" ")[0]) and ok

	# Backgrounded with nothing playing changes nothing at all.
	var idle_fen := session.fen()
	var idle_placement := board.placement()
	session.tap("b8")
	router._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	router._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	ok = _check("backgrounded while idle leaves the position, the board and the selection alone",
		session.fen() == idle_fen and board.placement() == idle_placement
		and session.selected() == "b8" and not session.is_frozen()) and ok

	main.free()
	return ok


# Skip fired at every 10 ms across the whole clash, every run compared against
# one that was allowed to finish. No run waits out its own offset: play_move()
# already takes the moment the tap landed, so a tap timestamped N seconds in the
# past starts a clash that is already N seconds old and stalls at the first beat
# past it. That is the same code path a real skip at N seconds takes -- the only
# thing faked is the clock the beats read.
func _run_skip_offsets() -> bool:
	var ok := true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame

	var session: GameSession = main.get_node("Session")
	var board: BoardView = main.get_node("Board")
	var panel: Node = main.get_node("DuelPanel")

	var start_msec := Time.get_ticks_msec()
	var unskipped := await _capture_run(session, board, panel, -1.0)
	print("unskipped clash rest state: %s" % unskipped)
	ok = _check("the unskipped clash ends with input back and nothing left on the stage",
		unskipped.contains("frozen=false") and unskipped.contains("clashing=false")
		and unskipped.contains("time_scale=1.000") and unskipped.contains("mask_w=0.0")
		and unskipped.contains("stage=(0.0, 0.0)") and unskipped.contains("burst_a=0.000")
		and unskipped.contains("white_debris=0") and unskipped.contains("black_debris=0")) and ok

	var fired := 0
	var diverged := PackedStringArray()
	var offset := 0.0
	while offset <= DuelPanelScript.CLASH_LENGTH + SKIP_EPSILON:
		var state := await _capture_run(session, board, panel, offset)
		fired += 1
		if state != unskipped:
			diverged.append("%.2fs(%s)" % [offset, state])
		offset += SKIP_STEP_SEC
	var elapsed_sec := (Time.get_ticks_msec() - start_msec) / 1000.0

	print("skip offsets: %d fired every %.0fms across the whole %.2fs clash, %.1fs"
		% [fired, SKIP_STEP_SEC * 1000.0, DuelPanelScript.CLASH_LENGTH, elapsed_sec])
	ok = _check("the offsets covered the clash end to end",
		fired >= int(DuelPanelScript.CLASH_LENGTH / SKIP_STEP_SEC) + 1) and ok
	ok = _check("a skip at any offset leaves exactly what the unskipped clash leaves: %s"
		% " ".join(diverged), diverged.is_empty()) and ok

	main.free()
	return ok


# 1.e4 d5 2.exd5 -- three moves from a fresh game to a capture, so every run in
# the skip sweep starts from the same place.
func _play_capture(session: GameSession, tap_usec := 0) -> void:
	session.restart()
	session.play_move("e2e4")
	session.play_move("d7d5")
	session.play_move("e4d5", tap_usec)


# One capture, skipped `offset` seconds in, or allowed to run in full when
# `offset` is negative. Returns everything a skip could leave behind, as one
# string, so a divergence names itself.
func _capture_run(session: GameSession, board: BoardView, panel: Node, offset: float) -> String:
	var tap_usec := 0
	if offset > 0.0:
		tap_usec = Time.get_ticks_usec() - int(offset * 1_000_000.0)
	_play_capture(session, tap_usec)
	if offset >= 0.0:
		panel.finish_now("test")
	var returned := await _await_unfrozen(session)
	return "returned=%s %s" % [returned, _rest_state(session, board, panel)]


# Bounded, because a clash that never hands control back is the failure this
# whole block exists to catch, and a hung suite reports nothing.
func _await_unfrozen(session: GameSession, max_frames := 600) -> bool:
	var frames := 0
	while session.is_frozen() and frames < max_frames:
		await tree.process_frame
		frames += 1
	return not session.is_frozen()


func _rest_state(session: GameSession, board: BoardView, panel: Node) -> String:
	var mask: Control = panel.get_node("Frame/Mask")
	var stage: Control = panel.get_node("Frame/Mask/Stage")
	var burst: Sprite2D = panel.get_node("Frame/Mask/Stage/Burst")
	return " ".join(PackedStringArray([
		"fen=%s" % session.fen(),
		"board=%s" % board.placement(),
		"selected=%s" % session.selected(),
		"frozen=%s" % session.is_frozen(),
		"clashing=%s" % panel.is_clashing(),
		"time_scale=%.3f" % Engine.time_scale,
		"mask_w=%.1f" % mask.size.x,
		"stage=%s" % stage.position,
		"burst_a=%.3f" % burst.modulate.a,
		"board_scale=%s" % board.scale,
		_rig_state("white", panel.get_node("Frame/Mask/Stage/White")),
		_rig_state("black", panel.get_node("Frame/Mask/Stage/Black")),
	]))


# The detached head is the one piece of debris with a life of its own: it is a
# duplicate sprite parented to the rig, so anything left flying shows up here as
# a child that should not be there.
func _rig_state(label: String, rig: CharacterRig) -> String:
	var debris := 0
	for child in rig.get_children():
		if String(child.name).ends_with("Duplicate") and not child.is_queued_for_deletion():
			debris += 1
	var anim: AnimationPlayer = rig.get_node("AnimationPlayer")
	return "%s_x=%.1f %s_anim=%s %s_debris=%d" % [
		label, rig.position.x, label, anim.current_animation, label, debris]


# Two hundred random legal games with the clash stubbed to zero duration,
# asserting after every single move that the position rebuilt from what the
# board shows is the position the rules hold. The seed is fixed and printed, so
# a failure is replayable from the one line that reports it.
func _run_desync_smoke() -> bool:
	const GAMES := 200
	const MAX_PLIES := 60
	const SEED := 20260817
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

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

	print("desync smoke: %d games, %d moves, %d captures, seed %d"
		% [GAMES, moves, captures, SEED])
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
	if condition:
		passed += 1
	else:
		failed += 1
	print("check: %s %s" % [name, "PASS" if condition else "FAIL"])
	return condition
