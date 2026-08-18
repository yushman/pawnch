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
# renderer the game ships with. The scene is mounted in a 1080x2400 SubViewport
# so the framing does not depend on what size window the desktop allows.

var out_dir := "/tmp/pawnch-shots"
var viewport: SubViewport


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1080, 2400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(main)
	await process_frame
	await process_frame
	var session: GameSession = main.get_node("Session")
	var board: BoardView = main.get_node("Board")

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
	quit(0)


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	image.save_png("%s/%s.png" % [out_dir, name])
	# Not the device's number and not comparable to tools/frametime.sh: this
	# frame carries a SubViewport the game does not have. What it is good for is
	# the difference between one shot and the next, which is where a mark that
	# broke the figures' batch would show up.
	print("PAWNCH_SHOT %s/%s.png %dx%d draw_calls=%d" % [
		out_dir, name, image.get_width(), image.get_height(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
