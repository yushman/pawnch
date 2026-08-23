extends Node
class_name InputRouter

# The only place a pixel becomes a square. Everything past here speaks algebraic
# (InputRouter -> GameSession -> RulesAdapter).
#
# Two gestures, one path. A six-year-old and a ten-year-old do not reach for the
# same one, so both tap-then-tap and press-drag-release are supported — and both
# end in the same GameSession.tap() calls, because two ways into the rules is two
# ways for them to disagree.
#
# `@onready`, never an exported NodePath: four exported node references were
# silently null for a whole day on Day 3.

# Godot's mouse-from-touch emulation delivers a second, synthetic
# InputEventMouseButton for every touch, tagged with this device id. Acting on
# both would select a piece and immediately deselect it.
const EMULATED_DEVICE := -1

# Android 13+ delivers one back press twice: the legacy onBackPressed path and
# the predictive-back callback both reach the engine, ~13ms apart, and with
# `quit_on_go_back=false` both arrive here. Measured on the device — headless
# only ever delivers the notification once, so nothing but the phone could have
# found it. Unfiltered, one press with a piece selected cleared the selection
# and then quit the app. Same class of platform duplicate as EMULATED_DEVICE
# above, and far below a deliberate double press.
const BACK_DEDUPE_MSEC := 250

@onready var board: BoardView = get_node("../Board")
@onready var session: GameSession = get_node("../Session")
@onready var clash: Node = get_node("../DuelPanel")
@onready var banner: Node = get_node("../GameOverBanner")
@onready var banter: Node = get_node("../HeroBanter")
@onready var pause_menu: Node = get_node("../PauseMenu")
@onready var bot: Node = get_node("../GreedyBot")

# The square a drag started from, or "" when no drag is in flight. A press that
# selects a piece arms one; a release on the origin square leaves the selection
# alone, so a tap is a drag that went nowhere rather than a separate code path.
var _drag_from := ""
# Whether the piece the current press landed on was already selected before it.
# Read on the release and nowhere else: this is the whole of putting a piece
# back down, and it cannot live in GameSession.tap(), because the press that
# puts a piece down and the press that starts dragging it are the same press --
# deselecting on it would disarm the drag below and an already-selected piece
# could never be dragged again.
var _press_reselected := false
var _last_back_msec := -BACK_DEDUPE_MSEC


func _ready() -> void:
	session.clash = clash
	session.banner = banner
	session.banter = banter
	# One line, and cut order step 3 deletes it (ADR-0005).
	session.bot = bot
	# Last: attach() draws the opening position and pushes the first turn, so
	# everything it pushes to has to exist by now.
	session.attach(board)
	print("PAWNCH_INPUT board=%s session=%s clash=%s banner=%s banter=%s menu=%s bot=%s" % [
		board != null, session != null, clash != null, banner != null,
		banter != null, pause_menu != null, bot != null])


# The cold-start budget is "board on screen and taking taps", not "process
# alive". This is the first frame where both are true; `am start -W` supplies
# the part before the engine existed.
func _process(_delta: float) -> void:
	set_process(false)
	print("PAWNCH_READY interactive_at=%dms" % Time.get_ticks_msec())


func _notification(what: int) -> void:
	# Notifications arrive during construction too, before the @onready
	# references above exist.
	if not is_node_ready():
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_RESUMED:
		# A clash caught by the platform is finished, not resumed, on the way
		# out and again on the way back: the position was settled before it
		# started, so there is nothing left in it to resume. With nothing
		# playing this does nothing at all, which is what "backgrounded while
		# idle changes nothing" means.
		if session.is_frozen():
			clash.finish_now("lifecycle")
			print("PAWNCH_LIFECYCLE clash_finished what=%d" % what)


# The least destructive thing available, in that order (move-input spec). It is
# never the only way to any of them: the clash also ends by tapping it, the
# selection also clears by tapping elsewhere.
# Returns false when the press was a platform duplicate and nothing was done,
# which is the only thing about it a test can see without quitting the process.
func _back() -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_back_msec < BACK_DEDUPE_MSEC:
		print("PAWNCH_BACK duplicate")
		return false
	_last_back_msec = now
	if session.is_frozen():
		clash.finish_now("back")
		print("PAWNCH_BACK clash_finished")
		return true
	if session.selected() != "":
		session.tap("")
		print("PAWNCH_BACK selection_cleared")
		return true
	print("PAWNCH_BACK quit")
	get_tree().quit()
	return true


# _unhandled_input, so a Control that has already taken the tap — the debug
# button — keeps it.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch(event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_moved(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != EMULATED_DEVICE:
		_touch(event.position, event.pressed)
	elif event is InputEventMouseMotion and event.device != EMULATED_DEVICE:
		if _drag_from == "":
			return
		_moved(event.position)
	else:
		return
	get_viewport().set_input_as_handled()


func _touch(at: Vector2, pressed: bool) -> void:
	if pressed:
		_press(at)
	else:
		_release(at)


func _press(at: Vector2) -> void:
	# A tap during a clash means "finish it" rather than nothing. The position
	# is already settled, so the only thing a tap can cut short is presentation
	# -- and a child who has seen the clash twice should not have to sit
	# through the third one.
	if session.is_frozen():
		clash.finish_now("tap")
		return
	# Layout only, and answered before everything else so that they are dead in
	# exactly one way rather than dead only on a board that is still in play: a
	# tap resolves to a control and the control does nothing with it (board-view
	# spec). There is no pause state to enter and no history to take a move off.
	var control := board.control_at(_local(at))
	if control != "":
		print("PAWNCH_CONTROL %s does_nothing=true" % control)
		return
	if session.is_over():
		if banner.restart_hit(at):
			session.restart()
		elif banner.close_hit(at):
			banner.dismiss()
		else:
			# The result is still recoverable once the panel has been put away:
			# a tap anywhere else brings it back, and nothing else on a finished
			# board wants that tap (game-outcome spec).
			banner.reopen()
		return
	var square := _square_at(at)
	# Read before the tap, which re-selects the same square and would answer
	# "yes" to this whichever press it was.
	var already_selected := square != "" and session.selected() == square
	session.tap(square, Time.get_ticks_usec())
	_press_reselected = false
	# A drag is only armed by a press that left a piece selected — which is the
	# same press that a tap would have made, so nothing is decided twice.
	if square != "" and session.selected() == square:
		_drag_from = square
		_press_reselected = already_selected
		board.set_drag(square, _local(at))


func _moved(at: Vector2) -> void:
	if _drag_from == "":
		return
	board.set_drag(_drag_from, _local(at))


func _release(at: Vector2) -> void:
	if _drag_from == "":
		return
	var from := _drag_from
	_drag_from = ""
	board.clear_drag()
	var square := _square_at(at)
	if square == from:
		# The finger never left the square it pressed: that was a tap. A tap on
		# a piece nothing had selected picked it up and the selection stands; a
		# tap on the piece that was already selected puts it back down, which is
		# the most ordinary thing a hand does with a piece it has changed its
		# mind about. tap("") is the same clear the back button takes.
		if _press_reselected:
			session.tap("")
			print("PAWNCH_DESELECT %s" % from)
		return
	# Anything else goes through the same tap() a second tap would have: a legal
	# destination plays the move, everything else — including a release off the
	# board, which resolves to "" — plays nothing and puts the piece back.
	session.tap(square, Time.get_ticks_usec())


func _square_at(at: Vector2) -> String:
	return board.square_at(_local(at))


func _local(at: Vector2) -> Vector2:
	return board.get_global_transform().affine_inverse() * at
