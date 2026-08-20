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
const GreedyBotScript = preload("res://scripts/greedy_bot.gd")
const TurnIndicatorScript = preload("res://scripts/turn_indicator.gd")
const GameOverBannerScript = preload("res://scripts/game_over_banner.gd")

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

# Crafted for the bot, black to move in each. A knight offered a queen and a
# pawn; a pawn and a rook offered the same knight; a queen offered a pawn that
# is defended twice; a pawn offered en passant.
const BOT_MVV_FEN := "4k3/8/8/4n3/8/3Q1P2/8/4K3 b - - 0 1"
const BOT_LVA_FEN := "3rk3/8/2p5/3N4/8/8/8/4K3 b - - 0 1"
const BOT_LOSING_FEN := "4k3/8/8/3q4/8/8/3P4/3RK3 b - - 0 1"
const BOT_EP_FEN := "4k3/8/8/8/3pP3/8/8/4K3 b - e3 0 1"
# Nothing to take, and a mix of moves that carry a piece toward white and moves
# that do not -- seven of twelve advance, so a uniform draw would already be a
# majority and only a clear margin over that shows the bias exists.
const BOT_QUIET_FEN := "4k3/8/3n4/8/8/8/4P3/4K3 b - - 0 1"
# BOT_MVV_FEN a move earlier: white plays f3f4 and the queen is still hanging,
# so the reply is a capture and a clash.
const BOT_CAPTURE_FEN := "4k3/8/8/4n3/8/3Q1P2/8/4K3 w - - 0 1"
# 1.Ra8 is mate, played by the player, so the bot's turn never comes.
const BACK_RANK_MATE_FEN := "6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1"
const BOT_SEED := 20260818

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
	_run_last_move_marks()
	_run_clash_lookup()
	_run_bot_smoke()
	await _run_gesture_smoke()
	await _run_clash_finish()
	await _run_bot_turn()
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
	# screen_col = file index, screen_row = rank_count - rank (ADR-0011 decision 1,
	# un-rotated on Day 8). Both axes swapped, so both of these had to be rewritten
	# rather than renumbered -- the old pins passed on a board drawn sideways.
	ok = _check("board puts the queen at screen row 7, col 3",
		board.screen_cell("d1") == Vector2i(3, 7)) and ok
	ok = _check("board puts the king at screen row 7, col 4",
		board.screen_cell("e1") == Vector2i(4, 7)) and ok
	ok = _check("board is not reflected: the king is further from the a-file edge",
		board.screen_cell("e1").x > board.screen_cell("d1").x) and ok

	var full: BoardView = BoardViewScript.new()
	full.set_position_from_fen(START_FEN)
	ok = _check("board shows 32 pieces from the opening",
		full.occupied_squares().size() == 32) and ok
	ok = _check("board size is 1080x1080", full.board_size() == Vector2(1080, 1080)) and ok
	ok = _check("board corners are a8 top-left and h1 bottom-right",
		full.screen_cell("a8") == Vector2i(0, 0) and full.screen_cell("h1") == Vector2i(7, 7)) and ok
	ok = _check("a1 is dark and h1 is light",
		not full.square_is_light("a1") and full.square_is_light("h1")) and ok

	var small: BoardView = BoardViewScript.new()
	small.file_count = 4
	small.rank_count = 4
	small.set_position_from_fen("4/4/4/RQKR w - - 0 1")
	ok = _check("board accepts non-8x8 dimensions",
		small.occupied_squares().size() == 4 and small.board_size() == Vector2(540, 540)) and ok

	# The margins, which are half the screen since the landscape flip and had no
	# check at all until they carried something. Everything in them is placed by
	# arithmetic off board_origin(), so one wrong sign puts a graveyard on the
	# board and nothing else notices -- the Duel button landed on white's fourth
	# row exactly this way, and it took a screenshot to see.
	full.size = Vector2(2400, 1080)
	var margin := full.board_origin().x
	var board_rect := Rect2(full.board_origin(), full.board_size())
	var boxes := {}
	for color in ["white", "black"]:
		boxes["%s grave" % color] = Rect2(full.graveyard_origin(color),
			Vector2(BoardViewScript.GRAVE_COLUMNS, BoardViewScript.GRAVE_ROWS)
				* BoardViewScript.GRAVE_CELL)
		boxes["%s hero" % color] = Rect2(full.hero_origin(color), BoardViewScript.HERO_CELL)
	boxes["turn indicator"] = TurnIndicatorScript.PANEL
	boxes["game-over banner"] = GameOverBannerScript.PANEL
	boxes["restart button"] = Rect2(
		GameOverBannerScript.RESTART_CENTER - Vector2.ONE * GameOverBannerScript.RESTART_TOUCH,
		Vector2.ONE * GameOverBannerScript.RESTART_TOUCH * 2.0)
	var spills := PackedStringArray()
	for name: String in boxes:
		var box: Rect2 = boxes[name]
		if box.intersects(board_rect) or box.position.x < 0.0 or box.position.y < 0.0 \
				or box.end.x > full.size.x or box.end.y > full.size.y:
			spills.append("%s%s" % [name, box])
	ok = _check("nothing in the two margins touches the board or leaves the screen: %s"
		% " ".join(spills), spills.is_empty()) and ok
	ok = _check("each margin holds every piece its army can lose (%d slots, 15 needed)"
		% (BoardViewScript.GRAVE_COLUMNS * BoardViewScript.GRAVE_ROWS),
		BoardViewScript.GRAVE_COLUMNS * BoardViewScript.GRAVE_ROWS >= 15) and ok
	# White's dead sit low and black's high, echoing the board -- that echo is the
	# only thing on screen tying "the left margin is white's" to a board where
	# white is at the bottom (ADR-0011 decision 5).
	ok = _check("white's losses sit low and black's high, each in its own colour's margin",
		full.graveyard_origin("white").y > full.graveyard_origin("black").y
		and full.graveyard_origin("white").x < margin
		and full.graveyard_origin("black").x > margin) and ok
	# The commander carries that echo harder than the graveyard does, because it
	# is the army's face -- and for one day it was placed at the *opposite* end of
	# the margin from its own dead, which put white's commander at the top of the
	# left band level with black's army and black's at the bottom level with
	# white's. Each colour's pair is anchored to its own end of the band, and the
	# two of them are adjacent rather than opposite.
	var blocks := {}
	for color in ["white", "black"]:
		blocks[color] = (boxes["%s grave" % color] as Rect2).merge(boxes["%s hero" % color])
	ok = _check("and each commander stands with its own dead, at its own colour's end of the margin (white %s, black %s)"
		% [blocks["white"], blocks["black"]],
		blocks["white"].end.y == full.size.y - BoardViewScript.MARGIN_PAD
		and blocks["black"].position.y == BoardViewScript.MARGIN_PAD
		and full.hero_origin("white").y < full.graveyard_origin("white").y
		and full.hero_origin("black").y > full.graveyard_origin("black").y) and ok
	# Everything a margin carries at once is disjoint. The banner is the one thing
	# that overlaps by design, so it is not in this list -- what it may cover is
	# the check after this one, not an exception to this one.
	var permanent := ["white grave", "white hero", "black grave", "black hero", "turn indicator"]
	var overlaps := PackedStringArray()
	for i in permanent.size():
		for j in range(i + 1, permanent.size()):
			if (boxes[permanent[i]] as Rect2).intersects(boxes[permanent[j]]):
				overlaps.append("%s/%s" % [permanent[i], permanent[j]])
	ok = _check("nothing standing in a margin overlaps anything else standing in it: %s"
		% " ".join(overlaps), overlaps.is_empty()) and ok
	ok = _check("and the game-over banner covers whole the two things it is allowed to cover, and neither graveyard",
		(boxes["game-over banner"] as Rect2).encloses(boxes["turn indicator"])
		and (boxes["game-over banner"] as Rect2).encloses(boxes["white hero"])
		and not (boxes["game-over banner"] as Rect2).intersects(boxes["white grave"])
		and not (boxes["game-over banner"] as Rect2).intersects(boxes["black grave"])) and ok
	# Derived from the position, never tallied: an untouched board has lost
	# nothing, and a board with material missing reports exactly what is missing.
	ok = _check("an untouched board has an empty graveyard on both sides",
		full.captured("white").is_empty() and full.captured("black").is_empty()) and ok
	var stripped: BoardView = BoardViewScript.new()
	stripped.set_position_from_fen("4k3/8/8/8/8/8/4P3/4K3 w - - 0 1")
	ok = _check("and one stripped to two kings and a pawn reports 15 and 14 losses, most valuable first",
		stripped.captured("black").size() == 15 and stripped.captured("white").size() == 14
		and stripped.captured("white")[0] == "queen"
		and stripped.captured("white")[-1] == "pawn") and ok
	stripped.free()

	board.free()
	full.free()
	small.free()
	return ok


# The hit test has to invert exactly the rotation the drawing applies, and an
# off-by-one in one axis only ever shows itself in a corner — so every cell is
# probed at its centre and at all four of its corners.
func _run_hit_test() -> bool:
	var board: BoardView = BoardViewScript.new()
	board.size = Vector2(2400, 1080)
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
	# The margins are new since the flip and they are half the screen: a tap in
	# one of them has to miss the board, not land on the nearest file. Probed at
	# the middle of each band and one pixel either side of the board's own edge,
	# because "beside the board" is where an off-by-one in board_origin() shows.
	var edge := board.board_origin().x
	var beside := [
		Vector2(-1, -1), Vector2(2000, 2000),
		Vector2(edge * 0.5, 540), Vector2(edge - 1, 540),
		Vector2(edge + board.board_size().x, 540), Vector2(2100, 540),
		Vector2(540, 900),
	]
	var hits := PackedStringArray()
	for probe: Vector2 in beside:
		if board.square_at(probe) != "":
			hits.append("%s->%s" % [probe, board.square_at(probe)])
	ok = _check("a tap beside the board resolves to no square: %s" % " ".join(hits),
		hits.is_empty()) and ok
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


# The opponent's reply is over in a third of a second and the board used to say
# nothing about where it went (board-view spec). Neither node here is in a tree,
# which is what makes the whole reply -- the opponent's turn, its move and its
# clash -- land inside the play_move() call below: the pause is a scene-tree
# timer and is skipped, and a null clash is a clash of zero duration.
func _run_last_move_marks() -> bool:
	var ok := true
	var board: BoardView = BoardViewScript.new()
	var session: GameSession = GameSessionScript.new()
	var bot := GreedyBotScript.new()
	bot.rng.seed = BOT_SEED
	session.bot = bot
	session.attach(board)

	ok = _check("a fresh game has no last move to report",
		session.last_move().is_empty() and board.last_move().is_empty()) and ok

	session.play_move("e2e4")
	var reply := session.last_move()
	var pair := ",".join(PackedStringArray(reply))
	ok = _check("the opponent's quiet reply is reported as a pair of squares (%s)" % pair,
		reply.size() == 2) and ok
	ok = _check("the pair names the square it left and the square it landed on",
		reply.size() == 2 and board.piece_on(reply[0]) == null
		and board.piece_on(reply[1]) != null
		and board.piece_on(reply[1])["color"] == "black") and ok
	ok = _check("the board is told the pair rather than diffing it out of the position",
		board.last_move() == reply) and ok

	# The player's own commit clears it. The opponent is detached for this one
	# move because with it attached its reply lands in the same call and sets the
	# mark again — the moment being checked is between the two.
	session.bot = null
	ok = _check("the player's own move plays", session.play_move("g1f3")) and ok
	ok = _check("and committing it clears the opponent's mark",
		session.last_move().is_empty() and board.last_move().is_empty()) and ok
	session.bot = bot

	# A capture is the case the mark exists for: the clash has had the player's
	# eyes off the board for the whole of the move it is explaining.
	session.load_fen(BOT_CAPTURE_FEN)
	ok = _check("a position that was loaded rather than played reports nothing",
		session.last_move().is_empty()) and ok
	session.play_move("f3f4")
	ok = _check("a reply that captures is reported the same way, origin and destination",
		session.last_move() == ["e5", "d3"] and board.last_move() == ["e5", "d3"]) and ok
	ok = _check("and the mark is there once the clash is over and the board has caught up",
		board.piece_on("d3") != null
		and board.placement() == session.fen().split(" ")[0]) and ok

	session.restart()
	ok = _check("a restarted game has nothing left to report",
		session.last_move().is_empty() and board.last_move().is_empty()) and ok

	board.free()
	session.free()
	bot.free()
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
	# Both colours are played by hand here, so the opponent is detached: with it
	# attached this suite would be racing it for black. Detaching it is also the
	# check that a session without one is the session Days 1-5 shipped. After the
	# frames, not before: _ready() -- which wires it -- runs on the first one.
	main.get_node("Session").bot = null

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

	# Putting a piece back down, and the trap under it: the decision is taken on
	# the release, because the press that puts a piece down and the press that
	# starts dragging it are the same press. Taken on the press — in
	# GameSession.tap() — the second half of this block fails, because the piece
	# would have been deselected before there was a drag to arm.
	var down := board.cell_rect("e2").get_center()
	router._press(down)
	router._release(down)
	ok = _check("a tap on a piece nothing had selected picks it up",
		session.selected() == "e2") and ok
	router._press(down)
	ok = _check("pressing a piece that is already selected still arms a drag",
		board.dragging() == "e2" and session.selected() == "e2") and ok
	router._release(down)
	ok = _check("and releasing on the same square puts it back down",
		session.selected() == "" and session.destinations().is_empty()
		and session.fen() == before and board.placement() == placement) and ok

	# A different piece of the same colour still takes the selection over.
	router._press(down)
	router._release(down)
	var queen := board.cell_rect("d1").get_center()
	router._press(queen)
	router._release(queen)
	ok = _check("tapping a different piece of the same colour moves the selection to it",
		session.selected() == "d1" and not session.destinations().is_empty()) and ok

	# The same gesture that would have put d1 down, taken somewhere legal.
	var d3 := board.cell_rect("d3").get_center()
	router._press(queen)
	router._moved(queen.lerp(d3, 0.5))
	router._release(d3)
	ok = _check("an already-selected piece dragged to a legal square still plays the move",
		session.fen().split(" ")[0] == "rnbqkbnr/ppp1pppp/8/3p4/3P4/3Q4/PPP1PPPP/RNB1KBNR"
		and session.selected() == "") and ok

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

	# Day 7 replaced two checks here that were written to start failing on exactly
	# the day a type got a clash of its own -- "the pawn and the knight have
	# clashes of their own, and only those two do", and "the other four take the
	# fallback" -- and both duly did. Naming which rows the table has is not the
	# guarantee; the guarantee is that filling it in cannot weaken the one above
	# for the types still waiting, and that is what is checked instead.
	var named := PackedStringArray()
	var fell_back := PackedStringArray()
	for type: String in DuelPanelScript.PIECE_TYPES:
		if bool(DuelPanelScript.clash_for(type)["fallback"]):
			fell_back.append(type)
		else:
			named.append(String(DuelPanelScript.CLASH_BY_TYPE[type]))
	var missing := PackedStringArray()
	for clash_name in named:
		if not DuelPanelScript.CLASH_BEATS.has(clash_name):
			missing.append(clash_name)
	ok = _check("every clash the table names is a clash that has beats: %s" % " ".join(missing),
		missing.is_empty()) and ok
	var silent := PackedStringArray()
	for type in fell_back:
		if float(DuelPanelScript.clash_for(type)["duration"]) <= 0.0:
			silent.append(type)
	ok = _check("the types the table does not name still get a real clash (%s): %s"
		% [" ".join(fell_back), " ".join(silent)],
		not fell_back.is_empty() and silent.is_empty()) and ok
	ok = _check("and the fallback they take is a clash that actually exists",
		DuelPanelScript.CLASH_BEATS.has(DuelPanelScript.FALLBACK_CLASH)) and ok

	# Three clashes now, and the rule that made the pounce shorter than the charge
	# is not a rule about two: two clashes of one length read as one clash however
	# differently they are staged, and so do three.
	var same := PackedStringArray()
	for a: String in DuelPanelScript.CLASH_BEATS:
		for b: String in DuelPanelScript.CLASH_BEATS:
			if a < b and absf(DuelPanelScript.clash_length(a) - DuelPanelScript.clash_length(b)) <= 0.05:
				same.append("%s/%s" % [a, b])
	ok = _check("the three clashes run for three different lengths: %s" % " ".join(same),
		DuelPanelScript.CLASH_BEATS.size() == 3 and same.is_empty()) and ok

	var pawn: Dictionary = DuelPanelScript.clash_for("pawn")
	var knight: Dictionary = DuelPanelScript.clash_for("knight")
	ok = _check("the two bespoke clashes are two clashes, not one under two names",
		String(pawn["name"]) != String(knight["name"])) and ok
	ok = _check("and they run for different lengths (%.2fs vs %.2fs), because two clashes of one length read as one"
		% [float(pawn["duration"]), float(knight["duration"])],
		absf(float(pawn["duration"]) - float(knight["duration"])) > 0.05) and ok
	ok = _check("both stay inside the 2.0s budget end to end",
		float(pawn["duration"]) <= 2.0 and float(knight["duration"]) <= 2.0) and ok
	ok = _check("and the pawn's impact lands inside the first 0.6s (%.2fs)"
		% float(DuelPanelScript.CLASH_BEATS["pounce"]["impact"]),
		float(DuelPanelScript.CLASH_BEATS["pounce"]["impact"]) <= 0.6) and ok

	# Block G. The pounce failed its own "told apart with the crests hidden"
	# scenario in a real game -- the leap did not read -- and both fixes are
	# single staging numbers that a later tune could quietly undo, which is
	# exactly how the apex gap got narrowed 215 -> 185 in the first place. They
	# are pinned here so undoing them costs a red suite rather than a playtest.
	var pounce: Dictionary = DuelPanelScript.CLASH_BEATS["pounce"]
	var hang: float = float(pounce["dive"]) - float(pounce["apex"])
	ok = _check("the pounce holds the top of its arc for %.2fs, which is a beat rather than a transit"
		% hang, hang >= 0.12) and ok
	ok = _check("and it climbs, hangs, dives and only then hits, in that order",
		float(pounce["crouch_end"]) < float(pounce["apex"])
		and float(pounce["apex"]) < float(pounce["dive"])
		and float(pounce["dive"]) < float(pounce["impact"])) and ok
	# The z-lift is engaged on the dive, so nothing before it may be close
	# enough for draw order to hide the defender behind the attacker.
	# Was `>= POUNCE_GAP + 200.0`, and Day 8 found the 200 wrong on its own terms
	# rather than merely failing: it is a clearance between two rig silhouettes,
	# so it is a figure-relative quantity that had been written down in panel
	# pixels at one particular mount scale. Restaging the panel made it a
	# threshold about nothing. Both gaps scale with the figures, so their ratio
	# is the invariant that was always meant -- and unlike the old form, it
	# cannot go stale the next time the mount scale moves.
	ok = _check("the apex sits about twice as far back as the strike does (%.0fpx vs %.0fpx), so the attacker never covers the defender on the way in"
		% [DuelPanelScript.POUNCE_APEX_GAP, DuelPanelScript.POUNCE_GAP],
		DuelPanelScript.POUNCE_APEX_GAP >= DuelPanelScript.POUNCE_GAP * 1.9) and ok

	# Day 7's strike. It is the clash a session sees most -- 19 of Day 6's 24
	# clashes were made by types that now land here -- so the numbers that make it
	# a third fight rather than a shortened charge are pinned, the same way the
	# pounce's are.
	var strike: Dictionary = DuelPanelScript.CLASH_BEATS["strike"]
	var rook: Dictionary = DuelPanelScript.clash_for("rook")
	var queen: Dictionary = DuelPanelScript.clash_for("queen")
	ok = _check("the rook, the bishop and the king all play the strike",
		String(rook["name"]) == "strike"
		and String(DuelPanelScript.clash_for("bishop")["name"]) == "strike"
		and String(DuelPanelScript.clash_for("king")["name"]) == "strike") and ok
	ok = _check("the queen is the one type left to the fallback, and the fallback is the strike too",
		bool(queen["fallback"]) and String(queen["name"]) == "strike"
		and Array(fell_back) == ["queen"]) and ok
	ok = _check("the strike is the shortest of the three (%.2fs), because it is the one seen twenty times a session"
		% float(rook["duration"]),
		float(rook["duration"]) < float(pawn["duration"])
		and float(rook["duration"]) < float(knight["duration"])) and ok
	ok = _check("and it stays inside the 2.0s budget with its impact inside the first 0.6s (%.2fs)"
		% float(strike["impact"]),
		float(rook["duration"]) <= 2.0 and float(strike["impact"]) <= 0.6) and ok
	ok = _check("it gathers, raises, hits, knocks the defender back and only then recoils, in that order",
		float(strike["gather"]) < float(strike["raise"])
		and float(strike["raise"]) < float(strike["impact"])
		and float(strike["impact"]) < float(strike["knock"])
		and float(strike["knock"]) <= float(strike["recoil"])) and ok
	# The raise is the beat that makes the clash vertical: the attacker's x does
	# not move across it, so a tune that shortens it turns the strike back into a
	# short charge without failing anything else.
	ok = _check("it spends %.2fs of its %.2fs before impact going nowhere horizontally"
		% [float(strike["raise"]) - float(strike["gather"]), float(strike["impact"])],
		float(strike["raise"]) - float(strike["gather"]) >= 0.20) and ok
	# The pounce needed a z-lift because it closed to 215px; the strike closes to
	# less than the charge does, so draw order cannot hide the defender behind the
	# attacker and no lift is engaged anywhere in _run_strike().
	ok = _check("and it lands from further out than the charge (%.0fpx vs %.0fpx), so it needs no z-lift to keep the defender visible"
		% [DuelPanelScript.STRIKE_GAP, DuelPanelScript.CHARGE_GAP],
		DuelPanelScript.STRIKE_GAP >= DuelPanelScript.CHARGE_GAP) and ok
	# The one thing no other clash does, and the reason the strike gets a skip
	# sweep of its own: it moves the defender.
	ok = _check("the defender is driven back and keeps most of that ground when it settles (%.0fpx, giving back %.0fpx)"
		% [DuelPanelScript.STRIKE_KNOCKBACK, DuelPanelScript.STRIKE_RECOVER],
		DuelPanelScript.STRIKE_KNOCKBACK > 0.0
		and DuelPanelScript.STRIKE_RECOVER < DuelPanelScript.STRIKE_KNOCKBACK) and ok
	# Every wait in a beat function is polled off the wall clock while the tweens
	# run on the engine clock, so a hitstop longer than the beat it sits inside
	# would make a tween's duration negative and the knockback would snap.
	ok = _check("and its hitstop (%.2fs) fits inside the beat that follows it"
		% DuelPanelScript.STRIKE_HITSTOP,
		DuelPanelScript.STRIKE_HITSTOP < float(strike["knock"]) - float(strike["impact"])) and ok

	# The framing, which had no check at all until the landscape flip and needed
	# one the moment both of its axes changed meaning. frame_rect_for() exists to
	# be callable without the project's stretch/aspect setup, so this is the whole
	# of it: a viewport size in, a panel rect out.
	#
	# The property being pinned is not the numbers, it is that **the panel is the
	# same rectangle at every supported aspect** -- that is what "the framing
	# survives the 16:9-20:9 range without re-composing" means, and it is what
	# every staging constant in duel_panel.gd assumes when it is written in panel
	# pixels rather than as a fraction.
	var narrow := DuelPanelScript.frame_rect_for(Vector2(1920, 1080))  # 16:9
	var target := DuelPanelScript.frame_rect_for(Vector2(2400, 1080))  # 20:9, the device
	ok = _check("the duel panel is the same size at 16:9 and at 20:9 (%s vs %s)"
		% [narrow.size, target.size],
		narrow.size == target.size and narrow.size == DuelPanelScript.PANEL_SIZE) and ok
	ok = _check("it fills the short edge and is centred on the long one (%s)" % target,
		target.size.y == 1080.0 and target.position.y == 0.0
		and is_equal_approx(target.position.x, (2400.0 - target.size.x) * 0.5)) and ok
	# Getting `window/stretch/aspect` backwards is the failure this catches: it
	# letterboxes rather than erroring, and a panel wider than the viewport is
	# what that looks like from in here.
	var spills := PackedStringArray()
	for width in [1920, 2000, 2160, 2340, 2400]:
		var r: Rect2 = DuelPanelScript.frame_rect_for(Vector2(width, 1080))
		if r.position.x < 0.0 or r.end.x > float(width) or r.position.y < 0.0 or r.end.y > 1080.0:
			spills.append("%d(%s)" % [width, r])
	ok = _check("and it never spills past the viewport anywhere in the supported range: %s"
		% " ".join(spills), spills.is_empty()) and ok
	return ok


# The opponent, on its own, with no session and no board: it is handed a rules
# adapter and hands back a string (ADR-0005). Everything here is a property of
# that one function, and every FEN is crafted so exactly one move is the right
# answer -- a bot that started looking at the reply would fail the third one.
func _run_bot_smoke() -> bool:
	var ok := true
	var bot := GreedyBotScript.new()
	bot.rng.seed = BOT_SEED

	# The opening is white's move, so this is the one place the bot is asked to
	# play white -- it plays black everywhere else in the game.
	bot.color = "white"
	ok = _check("the bot's move from the opening is legal",
		_bot_move_is_legal(bot, _rules_at(START_FEN))) and ok
	bot.color = "black"
	for fen in [BOT_MVV_FEN, BOT_LVA_FEN, BOT_QUIET_FEN]:
		ok = _check("the bot's move from %s is legal" % fen,
			_bot_move_is_legal(bot, _rules_at(fen))) and ok

	ok = _check("offered a queen and a pawn, the bot takes the queen",
		bot.choose(_rules_at(BOT_MVV_FEN)) == "e5d3") and ok
	ok = _check("two pieces on one victim: the pawn takes it, not the rook",
		bot.choose(_rules_at(BOT_LVA_FEN)) == "c6d5") and ok
	ok = _check("a capture that loses material next move is taken anyway",
		bot.choose(_rules_at(BOT_LOSING_FEN)) == "d5d2") and ok
	ok = _check("en passant is ranked as the capture of a pawn it is",
		bot.choose(_rules_at(BOT_EP_FEN)) == "d4e3") and ok

	# Two hundred draws from one quiet position: legal every time, forward more
	# often than not, and the same seed replaying the same game.
	var rules := _rules_at(BOT_QUIET_FEN)
	var picks := _bot_picks(bot, rules, BOT_SEED)
	var illegal := PackedStringArray()
	var advancing := 0
	for uci: String in picks:
		if not rules.legal_moves(uci.substr(0, 2)).has(uci.substr(2, 2)):
			illegal.append(uci)
		elif _advances(uci, "black"):
			advancing += 1
	ok = _check("every one of %d quiet picks is legal: %s"
		% [picks.size(), " ".join(illegal)], illegal.is_empty()) and ok
	ok = _check("more than half of them carry a piece toward the player (%d of %d)"
		% [advancing, picks.size()], advancing * 2 > picks.size()) and ok
	var uniform := picks.size() * _advancing_share(rules, "black")
	ok = _check("and clearly more than an unbiased draw would (%d vs %.0f)"
		% [advancing, uniform], advancing > uniform + 20) and ok
	ok = _check("the same seed replays the same sequence",
		_bot_picks(bot, rules, BOT_SEED) == picks) and ok
	ok = _check("a different seed does not",
		_bot_picks(bot, rules, BOT_SEED + 1) != picks) and ok

	bot.free()
	return ok


func _rules_at(fen: String) -> RulesAdapter:
	var rules := RulesAdapter.new()
	rules.fen(fen)
	return rules


func _bot_move_is_legal(bot: Node, rules: RulesAdapter) -> bool:
	var uci: String = bot.choose(rules)
	if uci.length() < 4:
		return false
	var piece = rules.piece_at(uci.substr(0, 2))
	return piece != null and piece["color"] == bot.color \
		and rules.legal_moves(uci.substr(0, 2)).has(uci.substr(2, 2))


func _bot_picks(bot: Node, rules: RulesAdapter, seed_value: int) -> Array:
	bot.rng.seed = seed_value
	var picks := []
	for i in 200:
		picks.append(bot.choose(rules))
	return picks


func _advances(uci: String, color: String) -> bool:
	var from_rank := uci.substr(1, 1).to_int()
	var to_rank := uci.substr(3, 1).to_int()
	return to_rank < from_rank if color == "black" else to_rank > from_rank


# What the share of advancing moves would be if the bot drew uniformly, which is
# the only number the bias can be measured against.
func _advancing_share(rules: RulesAdapter, color: String) -> float:
	var moves := 0
	var forward := 0
	for f in FILES:
		for r in range(1, 9):
			var square := "%s%d" % [f, r]
			var piece = rules.piece_at(square)
			if piece == null or piece["color"] != color:
				continue
			for to: String in rules.legal_moves(square):
				moves += 1
				if _advances(square + to, color):
					forward += 1
	return float(forward) / moves if moves > 0 else 0.0


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
	# Both colours by hand again: _play_capture() below plays black's move too.
	main.get_node("Session").bot = null

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


# The turn chain, in the real scene: the player's move, the opponent's pause,
# its move, and its clash, as one stretch of unavailable input that comes back
# by itself. The freeze is sampled every frame, because the failure this guards
# is not "input never came back" but "it came back for a moment in the middle".
func _run_bot_turn() -> bool:
	var ok := true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame

	var session: GameSession = main.get_node("Session")
	var board: BoardView = main.get_node("Board")
	var panel: Node = main.get_node("DuelPanel")
	var banner: Node = main.get_node("GameOverBanner")
	var indicator: Node = main.get_node("TurnIndicator")
	var bot: Node = main.get_node("GreedyBot")
	bot.rng.seed = BOT_SEED

	ok = _check("the scene wires the session to an opponent playing black and an indicator",
		session.bot != null and session.bot.color == "black"
		and session.indicator != null) and ok
	ok = _check("the indicator opens on the player's turn",
		indicator.state() == "player" and indicator.turn_color() == "white") and ok
	ok = _check("the indicator consumes no input",
		indicator.mouse_filter == Control.MOUSE_FILTER_IGNORE) and ok

	# A quiet move with the pause left in, so the reply is a separate event.
	session.bot_pause_sec = 0.15
	session.play_move("e2e4")
	ok = _check("input freezes on the player's commit, before the reply lands",
		session.is_frozen() and session.turn() == "black"
		and board.placement().begins_with("rnbqkbnr/pppppppp")) and ok
	ok = _check("the indicator names the opponent from the commit onward",
		indicator.state() == "opponent" and indicator.turn_color() == "black") and ok
	var thaws := await _watch_freeze(session)
	ok = _check("input thaws once, after the reply, and never between the two moves (%d)"
		% thaws, thaws == 1) and ok
	ok = _check("the reply is on the board and it is the player's move again",
		session.turn() == "white" and board.placement() == session.fen().split(" ")[0]) and ok
	ok = _check("input came back by itself with nothing selected",
		not session.is_frozen() and session.selected() == "") and ok
	ok = _check("the indicator followed the rules back to the player",
		indicator.state() == "player" and indicator.turn_color() == "white") and ok

	# A capture by the opponent takes the same clash path a player capture does,
	# and ends in the same place whether it is watched or cut short.
	session.bot_pause_sec = 0.0
	var full := await _bot_capture_run(session, board, panel, false)
	print("opponent capture rest state: %s" % full)
	ok = _check("the opponent's capture plays a clash and the board catches up",
		full.contains("fen=4k3/8/8/8/5P2/3n4/8/4K3") and full.contains("frozen=false")
		and full.contains("clashing=false") and full.contains("returned=true")) and ok
	ok = _check("the indicator follows a capture too, back to the player",
		indicator.state() == "player" and indicator.turn_color() == "white") and ok
	var skipped := await _bot_capture_run(session, board, panel, true)
	ok = _check("a skipped opponent capture ends exactly where the unskipped one does: %s"
		% skipped, skipped == full) and ok

	var settled := session.fen()
	for i in 5:
		await tree.process_frame
	ok = _check("the opponent moves once per turn and then waits",
		session.fen() == settled and session.turn() == "white"
		and not session.is_frozen()) and ok

	# It answers a move; it does not wake up on a position.
	session.load_fen(BOT_MVV_FEN)
	var loaded := session.fen()
	for i in 5:
		await tree.process_frame
	ok = _check("the opponent never moves on its own, only in answer to a move",
		session.fen() == loaded and not session.is_frozen()) and ok

	# The player mates: the opponent has no turn to take, and the ending speaks.
	session.load_fen(BACK_RANK_MATE_FEN)
	ok = _check("the mating move plays", session.play_move("a1a8")) and ok
	ok = _check("the game is over and the opponent played nothing",
		session.is_over() and session.fen().split(" ")[0] == "R5k1/5ppp/8/8/8/8/8/4K3") and ok
	ok = _check("a finished game does not leave input frozen",
		not session.is_frozen()) and ok
	ok = _check("the indicator goes silent and lets the banner speak",
		indicator.state() == "over" and not indicator.visible and banner.visible) and ok

	# Wired to a colour that is not to move it plays nothing, rather than
	# playing the player's move for them.
	bot.color = "white"
	session.load_fen(BOT_CAPTURE_FEN)
	session.play_move("f3f4")
	ok = _check("the opponent does not move when it is not its turn",
		not session.is_frozen() and session.turn() == "black"
		and session.fen().split(" ")[0] == "4k3/8/8/4n3/5P2/3Q4/8/4K3") and ok
	bot.color = "black"

	main.free()
	return ok


# Samples is_frozen() every frame from a commit until the opponent's turn is
# over, and returns how many times input came back. Two is the flicker the
# opponent spec forbids: a gap between the player's move and the reply.
func _watch_freeze(session: GameSession, max_frames := 900) -> int:
	var thaws := 0
	var was_frozen := session.is_frozen()
	var frames := 0
	while frames < max_frames:
		var frozen := session.is_frozen()
		if was_frozen and not frozen:
			thaws += 1
		was_frozen = frozen
		if not frozen and session.turn() == "white":
			break
		await tree.process_frame
		frames += 1
	return thaws


# White plays a quiet move into a hanging queen; the opponent takes it. `skip`
# cuts the clash short the moment it is up, which is the one thing a child does
# to an opponent's clash that they cannot do to their own.
func _bot_capture_run(session: GameSession, board: BoardView, panel: Node, skip: bool) -> String:
	session.load_fen(BOT_CAPTURE_FEN)
	session.play_move("f3f4")
	if skip:
		var frames := 0
		while not panel.is_clashing() and frames < 300:
			await tree.process_frame
			frames += 1
		panel.finish_now("test")
	var returned := await _await_unfrozen(session)
	return "returned=%s %s" % [returned, _rest_state(session, board, panel)]


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
	# And here, where an opponent answering every one of the sweep's runs would
	# be a second clash inside the run being measured.
	main.get_node("Session").bot = null

	var session: GameSession = main.get_node("Session")
	var board: BoardView = main.get_node("Board")
	var panel: Node = main.get_node("DuelPanel")

	# All three clashes, each swept to its own length. The pawn one is not
	# optional coverage: _play_capture() plays 1.e4 d5 2.exd5, so the moment the
	# pawn got a clash of its own this sweep moved onto the pounce and the charge
	# would have lost the only skip coverage it ever had, silently, from a green
	# suite.
	#
	# The bishop's is not a third helping of the same thing either. The strike is
	# the first clash that moves the *defender*, so it is the first whose skip can
	# leave the defender somewhere wrong -- new failure surface, and this is what
	# covers it. ~4s of suite time.
	ok = await _sweep_clash(session, board, panel, "pawn", _play_capture) and ok
	ok = await _sweep_clash(session, board, panel, "knight", _play_knight_capture) and ok
	ok = await _sweep_clash(session, board, panel, "bishop", _play_bishop_capture) and ok

	main.free()
	return ok


# One clash, swept end to end. The bound is the clash's own length out of the
# lookup rather than a single panel constant, because the two clashes are
# deliberately different lengths.
func _sweep_clash(session: GameSession, board: BoardView, panel: Node,
		attacker_type: String, play: Callable) -> bool:
	var ok := true
	var chosen: Dictionary = DuelPanelScript.clash_for(attacker_type)
	var clash_name := String(chosen["name"])
	var length := float(chosen["duration"])

	var start_msec := Time.get_ticks_msec()
	var unskipped := await _capture_run(session, board, panel, -1.0, play)
	print("unskipped %s rest state: %s" % [clash_name, unskipped])
	ok = _check("the unskipped %s ends with input back and nothing left on the stage" % clash_name,
		unskipped.contains("frozen=false") and unskipped.contains("clashing=false")
		and unskipped.contains("time_scale=1.000") and unskipped.contains("mask_w=0.0")
		and unskipped.contains("stage=(0.0, 0.0)") and unskipped.contains("burst_a=0.000")
		and unskipped.contains("white_debris=0") and unskipped.contains("black_debris=0")) and ok
	# The pounce lifts, tilts, squashes and pulls the attacker in front of the
	# defender, so "back where it started" is a whole transform plus a draw
	# order. The mirror is asserted by its sign: an absolute Vector2 squash would
	# have unmirrored the skeleton and left it facing away.
	ok = _check("and with both figures back on the ground, upright, unsquashed and in draw order, black still mirrored",
		unskipped.contains("white_pos=(483.0, 930.0)") and unskipped.contains("white_rot=0.000")
		and unskipped.contains("white_scale=(0.52, 0.52)") and unskipped.contains("white_z=0")
		and unskipped.contains("black_pos=(893.0, 930.0)") and unskipped.contains("black_rot=0.000")
		and unskipped.contains("black_scale=(-0.52, 0.52)") and unskipped.contains("black_z=0")) and ok

	var fired := 0
	var diverged := PackedStringArray()
	var offset := 0.0
	while offset <= length + SKIP_EPSILON:
		var state := await _capture_run(session, board, panel, offset, play)
		fired += 1
		if state != unskipped:
			diverged.append("%.2fs(%s)" % [offset, state])
		offset += SKIP_STEP_SEC
	var elapsed_sec := (Time.get_ticks_msec() - start_msec) / 1000.0

	print("skip offsets (%s): %d fired every %.0fms across the whole %.2fs clash, %.1fs"
		% [clash_name, fired, SKIP_STEP_SEC * 1000.0, length, elapsed_sec])
	ok = _check("the offsets covered the %s end to end" % clash_name,
		fired >= int(length / SKIP_STEP_SEC) + 1) and ok
	ok = _check("a skip at any offset of the %s leaves exactly what the unskipped one leaves: %s"
		% [clash_name, " ".join(diverged)], diverged.is_empty()) and ok
	return ok


# 1.e4 d5 2.exd5 -- three moves from a fresh game to a pawn capture, so every run
# in the sweep starts from the same place. This is the pounce.
func _play_capture(session: GameSession, tap_usec := 0) -> void:
	session.restart()
	session.play_move("e2e4")
	session.play_move("d7d5")
	session.play_move("e4d5", tap_usec)


# 1.Nf3 e5 2.Nxe5 -- the same shape taken by a knight, which is the charge.
func _play_knight_capture(session: GameSession, tap_usec := 0) -> void:
	session.restart()
	session.play_move("g1f3")
	session.play_move("e7e5")
	session.play_move("f3e5", tap_usec)


# 1.e4 d5 2.Bb5+ c6 3.Bxc6 -- five moves rather than three, because a bishop
# cannot reach anything worth taking in fewer: the check on move 2 is what forces
# c7-c6 into range. This is the strike.
func _play_bishop_capture(session: GameSession, tap_usec := 0) -> void:
	session.restart()
	session.play_move("e2e4")
	session.play_move("d7d5")
	session.play_move("f1b5")
	session.play_move("c7c6")
	session.play_move("b5c6", tap_usec)


# One capture, skipped `offset` seconds in, or allowed to run in full when
# `offset` is negative. Returns everything a skip could leave behind, as one
# string, so a divergence names itself.
func _capture_run(session: GameSession, board: BoardView, panel: Node, offset: float,
		play: Callable) -> String:
	var tap_usec := 0
	if offset > 0.0:
		tap_usec = Time.get_ticks_usec() - int(offset * 1_000_000.0)
	play.call(session, tap_usec)
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
		# The margins are board state and a skip can leave them wrong exactly the
		# way it can leave a figure airborne. Recorded here *before* the graveyard
		# was written, so the sweep was the thing that had to be satisfied rather
		# than something adjusted afterwards to agree with it.
		"graves=%s|%s" % [
			"".join(board.captured("white")), "".join(board.captured("black"))],
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
#
# The whole transform, not just x. Until the pounce there was nothing that moved
# a figure off the floor, so position.x alone was the whole story; a leap that
# was cut short mid-air, tilted or squashed would have passed the skip sweep
# without a word. rotation and scale are here for the same reason -- and scale
# especially, because a squash written as an absolute Vector2 rather than as a
# factor of the authored one silently unmirrors the skeleton.
func _rig_state(label: String, rig: CharacterRig) -> String:
	var debris := 0
	for child in rig.get_children():
		if String(child.name).ends_with("Duplicate") and not child.is_queued_for_deletion():
			debris += 1
	var anim: AnimationPlayer = rig.get_node("AnimationPlayer")
	return "%s_pos=%s %s_rot=%.3f %s_scale=%s %s_z=%d %s_anim=%s %s_debris=%d" % [
		label, rig.position, label, rig.rotation, label, rig.scale,
		label, rig.z_index, label, anim.current_animation, label, debris]


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
