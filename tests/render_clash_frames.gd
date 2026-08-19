extends SceneTree

# A contact sheet of each bespoke clash: one thumbnail of the panel per sample
# time, laid out left to right. Not a test — it asserts nothing, and it is not
# the device. It exists so that "the pounce and the charge read as two different
# fights" is a claim someone can re-check with one command instead of a phone
# and a steady hand.
#
#   godot --rendering-driver opengl3 --script tests/render_clash_frames.gd -- <out_dir>
#
# It inherits render_board_states.gd's constraint: `--headless` installs the
# dummy rendering server and Viewport.get_texture() returns null under it, so
# this needs a real window on the Compatibility renderer the game ships with.
# The scene is mounted in a 1080x2400 SubViewport so the framing does not depend
# on what size window the desktop allows.

## Seconds from the tap, dense through the approach and the strike and sparser
## through the retreat, which is where the two clashes differ least.
##
## The approach is sampled every 40ms rather than every 80ms because of what it
## is now asked to answer: Block G's second failure was the attacker fully
## covering the defender for about three frames, and a strip that steps over the
## approach in eight samples cannot see a three-frame hole in it.
const SAMPLE_SEC := [
	0.06, 0.10, 0.14, 0.18, 0.22, 0.26, 0.30,
	0.34, 0.38, 0.42, 0.46, 0.50, 0.54, 0.58,
	0.66, 0.78, 0.92, 1.10, 1.30, 1.50, 1.70,
]
const COLUMNS := 7
const THUMB_SCALE := 0.24
## The panel's own rect inside a 1080x2400 viewport: the 1080x1500 panel centred
## in a 1080x1920 safe band, itself centred in the viewport. Cropped to it so a
## thumbnail is all clash and no board.
const PANEL_RECT := Rect2i(0, 450, 1080, 1500)
const WARM_FRAMES := 30

var out_dir := "/tmp/pawnch-clash"
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
	# The panel's own _ready() awaits its warm-up and only then calls
	# close_now(). Two frames is enough in the suite and is not enough here: a
	# capture played inside that window has its wipe_in stopped by the
	# close_now() that lands a frame later, and every thumbnail comes out
	# showing the board. Wait the warm-up out.
	for i in WARM_FRAMES:
		await process_frame
	# No opponent: its reply would be a second clash inside the strip.
	main.get_node("Session").bot = null
	var session: GameSession = main.get_node("Session")
	var panel: Node = main.get_node("DuelPanel")

	# 1.e4 d5 2.exd5 -- the pawn's pounce, white attacking rightward.
	await _strip(session, panel, "pounce-white", "", ["e2e4", "d7d5", "e4d5"])
	# 1.Nf3 e5 2.Nxe5 -- the knight's charge, for the side-by-side.
	await _strip(session, panel, "charge-white", "", ["g1f3", "e7e5", "f3e5"])
	# The same pounce made by black, which the opponent makes reachable in a
	# real session: it strikes leftward off a rig mounted at scale.x < 0, so
	# this is where a leap authored for white only would show itself.
	await _strip(session, panel, "pounce-black", "4k3/8/8/3p4/4P3/8/8/4K3 b - - 0 1", ["d5e4"])
	quit(0)


func _strip(session: GameSession, panel: Node, label: String, fen: String, moves: Array) -> void:
	# The samples stop before the clash does, so the previous one has to be let
	# finish rather than played over.
	var waited := 0
	while (panel.is_clashing() or session.is_frozen()) and waited < 600:
		await process_frame
		waited += 1

	if fen == "":
		session.restart()
	else:
		session.load_fen(fen)
	for i in moves.size() - 1:
		session.play_move(moves[i])

	# The capture is timestamped now, so the sample clock and the clash's own
	# cue clock are the same clock.
	var start_usec := Time.get_ticks_usec()
	session.play_move(moves[-1], start_usec)

	var frames: Array[Image] = []
	var next := 0
	while next < SAMPLE_SEC.size():
		await process_frame
		var t := (Time.get_ticks_usec() - start_usec) / 1_000_000.0
		if t >= float(SAMPLE_SEC[next]):
			frames.append(_grab())
			next += 1
	_sheet(frames, label)


func _grab() -> Image:
	var image := viewport.get_texture().get_image()
	var thumb := image.get_region(PANEL_RECT)
	thumb.resize(int(PANEL_RECT.size.x * THUMB_SCALE), int(PANEL_RECT.size.y * THUMB_SCALE),
		Image.INTERPOLATE_BILINEAR)
	return thumb


func _sheet(frames: Array[Image], label: String) -> void:
	var tw := frames[0].get_width()
	var th := frames[0].get_height()
	var rows := int(ceil(float(frames.size()) / COLUMNS))
	var sheet := Image.create_empty(tw * COLUMNS, th * rows, false, frames[0].get_format())
	sheet.fill(Color(0.05, 0.05, 0.07))
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(Vector2i.ZERO, Vector2i(tw, th)),
			Vector2i((i % COLUMNS) * tw, (i / COLUMNS) * th))
	var path := "%s/clash-%s.png" % [out_dir, label]
	sheet.save_png(path)
	print("PAWNCH_STRIP %s %dx%d samples=%s" % [path, sheet.get_width(), sheet.get_height(),
		",".join(SAMPLE_SEC.map(func(t: float) -> String: return "%.2f" % t))])
