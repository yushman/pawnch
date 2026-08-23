extends SceneTree

# Pulls a frame of every board state that has something to look at: the marks,
# a drag in flight, a check, and both game-over banners. Not a test — it asserts
# nothing. It exists so that "the glow and the ring are two different marks" and
# "the banner says who won without words" are claims someone can re-check with
# one command instead of a phone and a steady hand.
#
#   godot --rendering-driver opengl3 --script tests/render_board_states.gd -- <out_dir>
#
# The device is still where these have to be judged — the shots this writes are
# the render, not the phone. It inherits render_board_pieces.gd's constraint:
# `--headless` installs the dummy rendering server and Viewport.get_texture()
# returns null under it, so this needs a real window on the Compatibility
# renderer the game ships with. The scene is mounted in a 2400x1080 SubViewport
# so the framing does not depend on what size window the desktop allows.

# White to move, with a queen the opponent's knight can take and a bishop that
# can take the knight back afterwards.
const LAST_MOVE_FEN := "4k3/8/8/4n3/8/3Q1P2/8/5BK1 w - - 0 1"

# A mate reached with almost nothing left on either side, so the banner is
# judged over two full graveyards rather than two empty ones -- the one thing it
# is forbidden to cover. White is down to two rooks (13 lost), black to the bare
# king (15 lost); Rb1-b8 is mate with the rook on a7 holding the seventh.
const HEAVY_MATE_FEN := "7k/R7/8/8/8/8/8/1R2K3 w - - 0 1"
const HEAVY_MATE_UCI := "b1b8"
const BLACK_MATE_FEN := "1r2k3/8/8/8/8/8/r7/7K b - - 0 1"
const BLACK_MATE_UCI := "b8b1"

var out_dir := "/tmp/pawnch-shots"
var viewport: SubViewport


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	viewport = SubViewport.new()
	viewport.size = Vector2i(2400, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(main)
	await process_frame
	await process_frame
	var session: GameSession = main.get_node("Session")
	var board: BoardView = main.get_node("Board")
	# Both colours are played by hand below, so the opponent is detached for all
	# of it and attached again for the last two shots, which are the two it is
	# the subject of.
	var bot: Node = main.get_node("GreedyBot")
	session.bot = null

	await _shot("01-start")

	# Legal-move glow only.
	session.tap("b1")
	await _shot("02-glow")

	# Glow and capture ring together.
	session.load_fen("rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2")
	session.tap("e4")
	await _shot("03-glow-and-ring")

	# Mid-drag: the figure under the finger, marks still up.
	board.set_drag("e4", board.cell_rect("d5").get_center() + Vector2(0, -60))
	await _shot("04-drag")
	board.clear_drag()

	# Check: 1.e4 d5 2.Bb5+, a check delivered without a capture.
	session.restart()
	for uci in ["e2e4", "d7d5", "f1b5"]:
		session.play_move(uci)
	await _shot("05-check")
	session.play_move("c7c6")
	await _shot("05b-check-cleared")

	# Checkmate banner.
	session.load_fen("rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq g3 0 2")
	session.play_move("d8h4")
	await _shot("06-checkmate")

	# Stalemate banner.
	session.load_fen("7k/8/8/8/8/8/5Q2/6K1 w - - 0 1")
	session.play_move("f2f7")
	await _shot("07-stalemate")

	session.restart()
	await _shot("08-restarted")

	# The opponent's reply, marked. White plays a quiet f3f4 into a hanging
	# queen, the opponent takes it, and the pair of squares its knight joined is
	# still on the board once the clash is over.
	session.bot = bot
	session.load_fen(LAST_MOVE_FEN)
	session.play_move("f3f4")
	await _unfrozen(session)
	await _shot("09-last-move")

	# And the shot the third mark has to survive: the bishop on f1 may take the
	# knight that just landed on d3, so that cell carries a capture ring and a
	# last-move bracket at once, while e5 carries the other half of the pair and
	# three empty squares glow. Four marks, one frame, nothing ambiguous.
	session.tap("f1")
	await _shot("10-three-marks")

	# Whose move it is, now said by the commander and by nothing else: two
	# frames, one per side, judged against each other. The bot is detached
	# again, because the point of the pair is the emphasis and not the reply.
	session.bot = null
	session.restart()
	await _shot("11-turn-white")
	session.play_move("e2e4")
	await _shot("12-turn-black")

	# The ending, in the middle of the screen, over a game that cost both sides
	# nearly everything. Three of them: white winning, black winning, and a draw
	# that crowns nobody.
	session.load_fen(HEAVY_MATE_FEN)
	session.play_move(HEAVY_MATE_UCI)
	await _shot("14-white-wins")
	var banner: Node = main.get_node("GameOverBanner")
	banner.dismiss()
	await _shot("15-banner-dismissed")
	banner.reopen()

	session.load_fen(BLACK_MATE_FEN)
	session.play_move(BLACK_MATE_UCI)
	await _shot("16-black-wins")

	# The bubbles, over both margins at once and over a game that has cost both
	# sides nearly everything -- which is the frame that shows whether one covers
	# a graveyard. The board is deliberately left one move short of the mate, so
	# the game is still in play and the commanders are still allowed to speak.
	session.bot = null
	session.load_fen(HEAVY_MATE_FEN)
	var banter: HeroBanter = main.get_node("HeroBanter")
	_say_longest(banter, "black", "took")
	_say_longest(banter, "white", "check")
	# Past the rise, so the shot catches the bubbles at full opacity rather than
	# two frames into a fade-in.
	banter.advance(HeroBanter.RISE_SEC)
	await _shot("18-banter-longest")

	# And the ordinary case: one line each, the way a turn actually produces
	# them, with white to move and lit and black idle and dimmed under its own.
	session.restart()
	banter.say("black", "idle")
	banter.say("white", "idle")
	banter.advance(HeroBanter.RISE_SEC)
	await _shot("19-banter-turn")

	# The pause menu, which nothing in the game opens (board-view spec). This is
	# the only caller and the whole of what "layout only" means.
	session.restart()
	main.get_node("PauseMenu").show_menu()
	await _shot("17-pause-menu")
	main.get_node("PauseMenu").hide_menu()
	# quit() from inside the frame_post_draw await above leaves the process
	# alive with nothing left to run; one more ordinary frame unwinds it.
	await process_frame
	quit(0)


# The longest line of a group, put on screen through the same say() the game
# uses: the bag hands every line out once before it repeats, so draining it is
# guaranteed to reach the long one and no test-only setter has to exist for it.
func _say_longest(banter: HeroBanter, side: String, group: String) -> void:
	var longest := ""
	for line: String in banter.lines_in(side, group):
		if line.length() > longest.length():
			longest = line
	for i in banter.lines_in(side, group).size():
		if banter.say(side, group) == longest:
			return


# The opponent's turn owns the freeze from the player's commit until its own
# clash has finished and the board has caught up.
func _unfrozen(session: GameSession, max_frames := 900) -> void:
	var frames := 0
	while (session.is_frozen() or session.turn() != "white") and frames < max_frames:
		await process_frame
		frames += 1


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	# The trap that has now bitten four renderers in this repo: get_image() can
	# hand back the SubViewport's texture as it stood *before* this frame was
	# drawn. Here it did not lose one shot, it lost nine -- everything from the
	# first clash onward came out as one frozen duel frame under nine different
	# names, and the draw-call line printed beside each of them agreed with the
	# lie. Waiting on the draw itself is the fix, and it is the same fix
	# tools/bake_board_atlas.py needed.
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.save_png("%s/%s.png" % [out_dir, name])
	# Not the device's number and not comparable to tools/frametime.sh: this
	# frame carries a SubViewport the game does not have. What it is good for is
	# the difference between one shot and the next, which is where a mark that
	# broke the figures' batch would show up.
	print("PAWNCH_SHOT %s/%s.png %dx%d draw_calls=%d" % [
		out_dir, name, image.get_width(), image.get_height(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
