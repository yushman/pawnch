extends Control
class_name DuelPanel

# Full-screen cutaway (ADR-0002). 1080x1500 panel centred in the 1080x1920
# safe band, itself centred in whatever the runtime viewport is, so the
# framing survives the 16:9-20:9 supported range without re-composing.
#
# play_capture() is the one bespoke clash this change builds -- five beats
# (wind-up, charge, impact, recoil, knockout) driven by this script rather than
# by a single authored Animation resource, because the beat times are cue points
# the debug overlay and JuiceBus both read off the same schedule (impact-juice
# spec: "no consumer of those cues holds a duplicate copy of any of those
# times").
#
# Sides are fixed by colour and never by role (ADR-0011 decision 5): white is
# always the left figure, black always the right one, and the capture resolves
# by who dies. So there is one timeline and one set of beat times, and the
# charge direction plus the two staging positions are derived from the two
# figures' home positions and a signed direction rather than authored twice.

const PANEL_SIZE := Vector2(1080, 1500)
const SAFE_BAND_SIZE := Vector2(1080, 1920)
const BOARD_RECEDE_SCALE := 0.94

# Target layout (tasks.md decisions): impact at 0.55s, total 1.90s including
# both wipes, wind-up running under wipe_in (0.15s) rather than after it.
const WINDUP_END := 0.15
const IMPACT_T := 0.55
const RECOIL_CUE_T := 0.85
const DYING_T := 0.95
const EXIT_T := 1.60
const WIPE_OUT_DURATION := 0.3
## Tap to the board coming back: the whole <=2.0s budget, and the span a skip
## can land anywhere inside.
const CLASH_LENGTH := EXIT_T + WIPE_OUT_DURATION

# The clash lookup (clash-sequencing spec: "The lookup MUST NOT be able to
# return nothing"). It is what makes "no capture is ever silent" testable --
# failure mode 3 in system-analysis.md is a capture that resolves to nothing and
# removes a piece with no animation and no error.
#
# CLASH_BY_TYPE is empty on purpose: no piece type has a clash of its own yet, so
# all six resolve to FALLBACK_CLASH, which is the one authored strike. Day 7
# authors the shared generic strike and fills the table in; the guarantee has to
# hold before then, not after.
const PIECE_TYPES := ["pawn", "knight", "bishop", "rook", "queen", "king"]
const CLASH_BY_TYPE := {}
const FALLBACK_CLASH := "strike"
const CLASH_LENGTHS := {"strike": CLASH_LENGTH}

# Staging, as offsets rather than absolute x, so one set of numbers serves both
# attack directions: the attacker winds up WINDUP_BACK away from its own home
# and charges to CHARGE_GAP short of the defender's, on whichever side of the
# defender it happens to stand.
const WINDUP_BACK := 40.0
const CHARGE_GAP := 280.0
const IMPACT_Y := 900.0
# Staging fixes found by pulling accurate per-frame stills off an on-device
# recording (adb screencap and ffmpeg -ss both proved unreliable -- only a full
# frame-accurate decode caught these):
#   - 620 (100px gap to the defender's original 780 home) badly overlapped the
#     two rigs' bodies; widened to a 280px gap.
#   - The defender's own 780 home put its head's global x past the 1080-wide
#     panel edge -- confirmed by a transform diagnostic, not a scale bug in the
#     detach duplicate, which matched the original's global transform exactly.
#     Moved the defender to 660 and the attacker's charge target to 380,
#     keeping the same 280px gap between them.
#   - 380 alone did not clear it: a full-frame decode showed the two heads
#     overlapping with ZERO background gap between them even at rest (home
#     300/660, a horizontal scan at head height ran solid foreground from
#     x=131 to x=964), because the rig heads are wide relative to a 360px
#     root gap. The attacker's rest/wind-up position (scene home 300 -> 100,
#     wind-up 260 -> 60) was pulled back further left so the idle and
#     wind-up beats read as two separate characters; the charge target is left
#     at 380 on purpose, since it already lands the strike at the midpoint
#     between 380 and the defender's 660 -- contact between the rigs at the
#     instant of the hit is correct, it is the earlier beats that must not
#     show it.

# @onready, never an exported NodePath. Five node references written as
# `name = NodePath("...")` in a .tscn have now been silently null at runtime in
# this project; `board` was the fifth. get_node_or_null, because this scene is
# also opened on its own.
@onready var board: CanvasItem = get_node_or_null("../Board")
## Optional: scripts/frame_probe.gd, for per-clash region reporting (Block D).
## Duck-typed via has_method() so this scene still runs standalone without it.
@onready var frame_probe: Node = get_node_or_null("../FrameProbe")

@onready var _board_dim: ColorRect = $BoardDim
@onready var _frame: Control = $Frame
@onready var _mask: Control = $Frame/Mask
@onready var _stage: Control = $Frame/Mask/Stage
@onready var _burst: Sprite2D = $Frame/Mask/Stage/Burst
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _juice: JuiceBus = $JuiceBus
@onready var _white: CharacterRig = $Frame/Mask/Stage/White
@onready var _black: CharacterRig = $Frame/Mask/Stage/Black
@onready var _characters: Array[CharacterRig] = [_white, _black]

var _board_scale := Vector2.ONE
var _home_x: Array[float] = []
var _is_open := false
var _is_clashing := false
# Bumped on every start and every finish. A beat captures it and stops the
# moment it no longer matches, which is how a clash finished from the outside
# stops mid-await instead of running its remaining beats over a reset stage.
var _clash_seq := 0
var _board_tween: Tween
var _root_tween: Tween
var _recoil_tween: Tween
var _clash_start_usec := 0
var _awaiting_first_frame := false
var _cue_log: Array[String] = []


func _ready() -> void:
	print("PAWNCH_PANEL board=%s frame_probe=%s" % [board != null, frame_probe != null])
	if board:
		_board_scale = board.scale
	for c in _characters:
		_home_x.append(c.position.x)
	_layout()
	get_viewport().size_changed.connect(_layout)
	await _warm()
	close_now()


func _layout() -> void:
	var frame_rect := frame_rect_for(get_viewport_rect().size)
	_frame.position = frame_rect.position
	_frame.size = frame_rect.size
	_mask.size.y = PANEL_SIZE.y
	# A Control scales about its top-left by default; pivot it about its own
	# centre so the recede reads as "pull back", not "drift up-left". Set on
	# every layout pass, not just _ready(), since board's size tracks the
	# viewport too.
	if board is Control:
		board.pivot_offset = board.size * 0.5


# Centres the 1080x1500 panel in the 1080x1920 safe band, itself centred in
# whatever viewport size is reported. Pulled out of _layout() so the framing
# math is testable without depending on the project's stretch/aspect setup.
static func frame_rect_for(viewport_size: Vector2) -> Rect2:
	var band_y := (viewport_size.y - SAFE_BAND_SIZE.y) * 0.5
	var x := (viewport_size.x - PANEL_SIZE.x) * 0.5
	var y := band_y + (SAFE_BAND_SIZE.y - PANEL_SIZE.y) * 0.5
	return Rect2(Vector2(x, y), PANEL_SIZE)


# The debug button's entry point: the clash this change was authored against.
func play() -> void:
	play_capture("white", "knight", "pawn")


# Which clash an attacker type gets, and how long it runs. Never returns
# nothing: an unauthored or unknown type falls back to the one clash that
# exists, so a capture can never resolve to silence.
static func clash_for(attacker_type: String) -> Dictionary:
	var authored: bool = CLASH_BY_TYPE.has(attacker_type)
	var clash_name: String = CLASH_BY_TYPE.get(attacker_type, FALLBACK_CLASH)
	return {
		"name": clash_name,
		"duration": CLASH_LENGTHS[clash_name],
		"fallback": not authored,
	}


# The one bespoke clash, for whichever colour is attacking. Re-entrant calls
# while a clash is already running are refused rather than queued or
# interrupted; ending one early is finish_now()'s job, not this function's.
func play_capture(attacker_color: String, attacker_type: String, defender_type: String,
		tap_usec := 0) -> void:
	if _is_clashing:
		return
	_is_clashing = true
	_clash_seq += 1
	var seq := _clash_seq
	_reset_stage()
	_cue_log.clear()
	# Cue zero is the tap that committed the capture, not the panel opening, so
	# the <200ms budget is measured from where the player's finger was.
	_clash_start_usec = tap_usec if tap_usec > 0 else Time.get_ticks_usec()
	if frame_probe and frame_probe.has_method("mark_region_start"):
		frame_probe.mark_region_start("clash")

	var attacking_white := attacker_color == "white"
	var attacker := _white if attacking_white else _black
	var defender := _black if attacking_white else _white
	# One bespoke clash serves every capture today, so the crests are the only
	# thing naming the pieces that are actually fighting.
	attacker.set_piece_type(attacker_type)
	defender.set_piece_type(defender_type)
	var chosen := clash_for(attacker_type)
	_cue_log.append("PAWNCH_CUE clash attacker=%s_%s defender=%s_%s clash=%s fallback=%s" % [
		attacker_color, attacker_type,
		"black" if attacking_white else "white", defender_type,
		chosen["name"], chosen["fallback"]])

	await _run_beats(seq, attacker, defender, attacking_white)
	_finish("natural", seq)


# The five beats. Every wait can come back false -- the clash was finished from
# the outside while it was in flight -- and every one of them then returns
# without touching the stage, because whoever finished it has already reset it.
func _run_beats(seq: int, attacker: CharacterRig, defender: CharacterRig,
		attacking_white: bool) -> void:
	var attacker_home := _home_x[0] if attacking_white else _home_x[1]
	var defender_home := _home_x[1] if attacking_white else _home_x[0]
	var toward := signf(defender_home - attacker_home)
	var windup_x := attacker_home - toward * WINDUP_BACK
	var charge_x := defender_home - toward * CHARGE_GAP
	var impact_point := Vector2((charge_x + defender_home) * 0.5, IMPACT_Y)

	open()  # wipe_in begins; wind-up starts on the same frame (tap -> < 200ms)
	_arm_first_frame_cue()

	_root_tween = create_tween()
	_root_tween.tween_property(attacker, "position:x", windup_x, WINDUP_END) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_root_tween.tween_property(attacker, "position:x", charge_x, IMPACT_T - WINDUP_END) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if not await _wait_until(seq, WINDUP_END):
		return
	# Each rig's own Slashing already points at the other side, and the
	# skeleton's does so through duel_panel.tscn's static per-colour mirror --
	# measured, not assumed: see ADR-0011 decision 5.
	attacker.play_state("Slashing")
	_juice.play_swing()

	if not await _wait_until(seq, IMPACT_T):
		return
	_fire_cue("impact")
	defender.play_state("Hurt")
	# The defeat is asymmetric and it is a property of the character, not of the
	# position (ADR-0007 decision 4): the skeleton's head comes off, the
	# valkyrie's does not -- she gets Dying and the pain face below.
	if defender == _black:
		defender.detach_head()
	var dispatch: Dictionary = await _juice.fire_impact(impact_point)
	if seq != _clash_seq:
		return
	_log_dispatch(dispatch)

	attacker.play_state("Idle Blinking")
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(attacker, "position:x", attacker_home,
			EXIT_T - IMPACT_T - JuiceBus.HITSTOP_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if not await _wait_until(seq, RECOIL_CUE_T):
		return
	_fire_cue("recoil")

	if not await _wait_until(seq, DYING_T):
		return
	defender.play_state("Dying")

	if not await _wait_until(seq, EXIT_T):
		return
	_fire_cue("exit")
	close()

	await _wait_until(seq, EXIT_T + WIPE_OUT_DURATION)


# The one and only way a clash ends. The natural end of the beats, a tap on the
# screen, the back button and coming back from the background all arrive here,
# because two ways to end a clash is two ways for it to end slightly wrong and
# the skip test only ever proves the path it fires.
#
# Idempotent: a second call finds no clash running and does nothing.
func finish_now(path := "skip") -> void:
	_finish(path, _clash_seq)


func _finish(path: String, seq: int) -> void:
	if not _is_clashing or seq != _clash_seq:
		return
	# Invalidates whatever beat is still in flight: it resumes on the next
	# frame, sees a sequence that is no longer its own, and returns.
	_clash_seq += 1
	_is_clashing = false
	_awaiting_first_frame = false
	if RenderingServer.frame_post_draw.is_connected(_check_first_frame):
		RenderingServer.frame_post_draw.disconnect(_check_first_frame)
	if frame_probe and frame_probe.has_method("mark_region_end"):
		frame_probe.mark_region_end("clash")
	close_now()
	# Cue zero was the tap, so this one is the whole <=2.0s budget: tap to the
	# board coming back and input returning.
	_fire_cue("done")
	_cue_log.append("PAWNCH_CLASH_END path=%s" % path)
	_flush_cue_log()


func is_clashing() -> bool:
	return _is_clashing


# Returns false the moment this clash stops being the current one, which is what
# lets a beat awaiting the next cue abandon the rest of the timeline. Polled per
# frame rather than slept on a Timer for exactly that reason -- a timer cannot be
# cut short, so a skip would have waited for the beat it landed in to elapse.
func _wait_until(seq: int, t_sec: float) -> bool:
	while seq == _clash_seq:
		if (Time.get_ticks_usec() - _clash_start_usec) / 1_000_000.0 >= t_sec:
			return true
		await get_tree().process_frame
	return false


# "First clash frame" is the first frame that actually presented any of the
# panel: the wipe is keyed from zero width, so the frame the tap lands on still
# shows nothing. frame_post_draw rather than _process, because _process for the
# tap's own frame runs after _unhandled_input and before anything is drawn.
func _arm_first_frame_cue() -> void:
	_awaiting_first_frame = true
	if not RenderingServer.frame_post_draw.is_connected(_check_first_frame):
		RenderingServer.frame_post_draw.connect(_check_first_frame)


func _check_first_frame() -> void:
	if not _awaiting_first_frame or _mask.size.x <= 0.0:
		return
	_awaiting_first_frame = false
	_fire_cue("first_frame")
	RenderingServer.frame_post_draw.disconnect(_check_first_frame)


func _fire_cue(cue_name: String) -> void:
	var t := (Time.get_ticks_usec() - _clash_start_usec) / 1_000_000.0
	_cue_log.append("PAWNCH_CUE %s t=%.3f" % [cue_name, t])


# Dispatch times only -- no budget asserted (criterion 3 dropped, tasks.md).
func _log_dispatch(d: Dictionary) -> void:
	_cue_log.append("PAWNCH_CUE dispatch sfx_delta=%.1fms haptic_delta=%.1fms" % [
		d["sfx_delta_ms"], d["haptic_delta_ms"],
	])


# Buffered rather than printed live (trap: a print() on the impact frame would
# land inside the very window criterion 2 measures). One flush after the
# panel has fully closed.
func _flush_cue_log() -> void:
	for line in _cue_log:
		print(line)
	_cue_log.clear()


func open() -> void:
	_is_open = true
	_anim.stop()
	_anim.play("wipe_in")
	_tween_board_scale(_board_scale * BOARD_RECEDE_SCALE, 0.15)


func close() -> void:
	_is_open = false
	_anim.stop()
	_anim.play("wipe_out")
	_tween_board_scale(_board_scale, 0.3)


func close_now() -> void:
	_is_open = false
	# Stopped, not just overwritten: wipe_in keys Mask:size:x, so a wipe still
	# running would put the panel straight back on screen the next frame.
	_anim.stop()
	_mask.size.x = 0
	_board_dim.modulate.a = 0
	if _board_tween and _board_tween.is_valid():
		_board_tween.kill()
	if board:
		board.scale = _board_scale
	_reset_stage()


# Idempotent: puts everything the clash moves, detaches or hides back to its
# authored rest state. Called on entry to play_capture() (defensive, in case a
# previous clash left something behind) and from close_now(), which every
# ending path reaches through _finish() -- so back-to-back clashes start from
# the same place every time, and a clash cut short at any instant ends where a
# clash allowed to run in full does.
func _reset_stage() -> void:
	Engine.time_scale = 1.0
	# The charge and the recoil are tweens on the attacker's position: left
	# alive they would drag it off its home square again on the frame after the
	# reset, which is exactly the debris a skip must not leave.
	for t in [_root_tween, _recoil_tween]:
		if t and t.is_valid():
			t.kill()
	if _juice:
		_juice.cancel()
	if _stage:
		_stage.position = Vector2.ZERO
	if _burst:
		_burst.modulate.a = 0.0
	for i in _characters.size():
		var c := _characters[i]
		c.reset_defeat()
		c.play_state("Idle Blinking")
		c.position.x = _home_x[i]


# One reused Tween rather than a fresh allocation per toggle — also fixes the
# competing-tweens race when the panel is toggled faster than a transition
# completes.
func _tween_board_scale(target_scale: Vector2, duration: float) -> void:
	if not board:
		return
	if _board_tween and _board_tween.is_valid():
		_board_tween.kill()
	_board_tween = create_tween()
	_board_tween.tween_property(board, "scale", target_scale, duration)


# Failure mode 4 (system-analysis.md): the first clash after a cold start
# must not compile a shader, upload a texture or decode a sound. Draw and
# play everything once at zero opacity so that work happens here, not on the
# player's first tap.
func _warm() -> void:
	modulate.a = 0.0
	_mask.size.x = PANEL_SIZE.x
	for c in _characters:
		c.play_state("Idle Blinking")
	_juice.warm()
	_characters[1].warm_detach()
	await get_tree().process_frame
	await get_tree().process_frame
	modulate.a = 1.0
