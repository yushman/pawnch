extends Node
class_name InputRouter

# The only place a pixel becomes a square. Everything past here speaks algebraic
# (InputRouter -> GameSession -> RulesAdapter).
#
# `@onready`, never an exported NodePath: four exported node references were
# silently null for a whole day on Day 3.

# Godot's mouse-from-touch emulation delivers a second, synthetic
# InputEventMouseButton for every touch, tagged with this device id. Acting on
# both would select a piece and immediately deselect it.
const EMULATED_DEVICE := -1

@onready var board: BoardView = get_node("../Board")
@onready var session: GameSession = get_node("../Session")
@onready var clash: Node = get_node("../DuelPanel")


func _ready() -> void:
	session.attach(board)
	session.clash = clash
	print("PAWNCH_INPUT board=%s session=%s clash=%s" % [
		board != null, session != null, clash != null])


# The cold-start budget is "board on screen and taking taps", not "process
# alive". This is the first frame where both are true; `am start -W` supplies
# the part before the engine existed.
func _process(_delta: float) -> void:
	set_process(false)
	print("PAWNCH_READY interactive_at=%dms" % Time.get_ticks_msec())


# _unhandled_input, so a Control that has already taken the tap — the debug
# button — keeps it.
func _unhandled_input(event: InputEvent) -> void:
	var at: Vector2
	if event is InputEventScreenTouch and event.pressed:
		at = event.position
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and event.device != EMULATED_DEVICE:
		at = event.position
	else:
		return
	session.tap(board.square_at(board.get_global_transform().affine_inverse() * at),
		Time.get_ticks_usec())
	get_viewport().set_input_as_handled()
