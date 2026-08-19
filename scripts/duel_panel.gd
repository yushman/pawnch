extends Control
class_name DuelPanel

# Full-screen cutaway (ADR-0002). 1080x1500 panel centred in the 1080x1920
# safe band, itself centred in whatever the runtime viewport is, so the
# framing survives the 16:9-20:9 supported range without re-composing.
#
# play_capture() looks the attacker's type up in CLASH_BY_TYPE and dispatches to
# the beat function that clash names: _run_charge() for the knight's flat run
# across the ground, _run_pounce() for the pawn's leap. Both are driven by this
# script rather than by an authored Animation resource, because the beat times
# are cue points the debug overlay and JuiceBus read off the same schedule
# (impact-juice spec: "no consumer of those cues holds a duplicate copy of any of
# those times") -- CLASH_BEATS is that schedule, and it is the only place any of
# these numbers is written down.
#
# The rigs have five animations between them and nobody here draws (ADR-0009),
# so the whole difference between clash #1 and clash #2 is path, timing, tilt,
# squash and where the burst lands. All of it code.
#
# Sides are fixed by colour and never by role (ADR-0011 decision 5): white is
# always the left figure, black always the right one, and the capture resolves
# by who dies. So each clash has one timeline whichever colour is attacking, and
# the direction plus every staging position is derived from the two figures'
# home positions and a signed direction rather than authored twice.

const PANEL_SIZE := Vector2(1080, 1500)
const SAFE_BAND_SIZE := Vector2(1080, 1920)
const BOARD_RECEDE_SCALE := 0.94

const WIPE_OUT_DURATION := 0.3

# The beat schedule, per clash, in seconds from the tap that committed the
# capture. Every wait, every tween length and every clash duration is read out
# of here; nothing keeps a second copy.
#
#   charge -- the knight (Day 3). Impact at 0.55s, 1.90s end to end including
#     both wipes, with the wind-up running under wipe_in (0.15s) rather than
#     after it. Measured on the device; do not move these.
#   pounce -- the pawn (Day 6). Impact at 0.54s, exit at 1.50s, 1.80s end to
#     end. Deliberately shorter than the charge: two clashes of the same length
#     read as the same clash however differently they are staged.
#
# Block G re-cut the pounce's front half after a real game: "прыжок не заметен".
# The leap used to run one uninterrupted tween from the crouch straight into the
# impact, so the top of the arc was a transit, not a beat -- there was no frame
# in which the figure was simply *up there*. It now rises fast (0.14 -> 0.30),
# hangs (0.30 -> 0.44) and dives (0.44 -> 0.54). The hang is paid for twice
# over: 0.20s came out of the rise, which is a longer climb in under half the
# time and reads as a launch rather than a drift, and the 0.04s the impact moved
# back came out of the dead tail between hop_end and exit, where the attacker was
# already home and standing still (0.20s -> 0.16s). Total is unchanged at 1.80s
# and the impact stays inside the 0.6s budget with ~0.05s of device margin.
const CLASH_BEATS := {
	"charge": {
		"windup_end": 0.15,
		"impact": 0.55,
		"recoil": 0.85,
		"dying": 0.95,
		"exit": 1.60,
	},
	"pounce": {
		"crouch_end": 0.14,
		"apex": 0.30,
		"dive": 0.44,
		"impact": 0.54,
		"land": 0.72,
		"recoil": 0.84,
		"dying": 0.94,
		"hop_end": 1.34,
		"exit": 1.50,
	},
}

# The clash lookup (clash-sequencing spec: "The lookup MUST NOT be able to
# return nothing"). It is what makes "no capture is ever silent" testable --
# failure mode 3 in system-analysis.md is a capture that resolves to nothing and
# removes a piece with no animation and no error.
#
# Two types have a clash of their own today. The other four fall back to the
# charge, which is a real clash rather than a placeholder, until Day 7 authors
# the shared generic strike and takes that job over. Adding an entry here must
# never be able to weaken the guarantee for the types that still have none,
# which is why clash_for() defaults rather than indexing.
const PIECE_TYPES := ["pawn", "knight", "bishop", "rook", "queen", "king"]
const CLASH_BY_TYPE := {"pawn": "pounce", "knight": "charge"}
const FALLBACK_CLASH := "charge"

# Charge staging, as offsets rather than absolute x, so one set of numbers serves
# both attack directions: the attacker winds up WINDUP_BACK away from its own
# home and charges to CHARGE_GAP short of the defender's, on whichever side of
# the defender it happens to stand.
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

# Pounce staging. The point of clash #2 is that it must not read as clash #1, so
# the attacker never crosses the floor at all: it gathers, leaves the ground,
# comes down on the defender from above and hops home. Same derivation rule as
# the charge -- everything below is an offset from the attacker's own home and a
# signed direction, so a black pawn (mounted at scale.x < 0, striking leftward)
# gets the same leap mirrored rather than a second set of numbers.
#
# Block G rewrote these after a full game on the device said the leap did not
# read ("прыжок не заметен"), and a frame-by-frame pass on that recording found
# why: the apex sat 185px from the defender's root, which is *inside* the two
# rigs' silhouettes, so the top of the arc was the one moment the attacker was
# glued to the defender rather than alone in open air. A figure with no
# background around it does not read as airborne however high it is.
#
# The arc therefore has two x stations instead of one. It peaks well short of
# the defender (POUNCE_APEX_GAP), hangs there in clear air, and only closes to
# contact range (POUNCE_GAP) on the dive. Contact still happens -- it happens in
# the 0.10s dive, where it belongs -- but nothing before it does.
const POUNCE_GATHER := 26.0          ## how far back the crouch slides
## x gap to the defender at the top of the arc. 185 was the whole bug: the
## silhouettes coincided there.
##
## 430, and the number is measured rather than chosen. The skeleton's skull is
## the top 45% of the whole figure and it is enormous -- on a contact sheet its
## left edge sits ~270px left of its own root, and its top edge is *above* where
## the attacker's feet reach at the apex. So an attacker whose silhouette
## overlaps the defender's x range at all has the skull, not the background,
## behind its feet, and a figure with foreground under its feet does not read as
## airborne however high it is. 430 puts the attacker's leading edge clear of
## the skull's left edge with ~70px of open background between them -- 330 was
## tried first and left the attacker's legs behind the skull.
##
## It also makes the rise almost vertical (154px forward against 380px up),
## which is what a pounce is: the ground is covered by the dive, not the climb.
const POUNCE_APEX_GAP := 430.0
## x gap at the moment of contact. Was narrowed 215 -> 185 on host-render
## evidence and the device said that was the wrong direction; back to 215, which
## is where the sword tip reaches the skull without the bodies interpenetrating.
const POUNCE_GAP := 215.0
## How far above its own feet the arc peaks. 300 -> 380: this is the ceiling,
## not a taste call -- at 0.714 mount scale the figure is ~695px tall and the
## panel is 1500, so a root at 1115 - 380 puts the helmet tip ~40px below the
## top edge. Anything more clips the crest, which is the one thing that must
## never leave frame.
const POUNCE_HEIGHT := 380.0
## Height above its own feet at the instant of the strike. The dive spends a
## third of the arc's height on the way in, so the hit visibly comes *down* out
## of the hang instead of being delivered from a hover.
const POUNCE_STRIKE_HEIGHT := 250.0
## Forward drift across the hang. Small on purpose: enough that the figure is
## floating rather than paused, not enough to turn the hang back into a transit.
const POUNCE_HANG_DRIFT := 18.0
const POUNCE_CARRY := 34.0           ## forward drift between the strike and the landing
## The lower second arc, going home. 165 -> 200, so the retreat still reads as
## the same character: the one that jumps.
const POUNCE_HOP_HEIGHT := 200.0
## The stage draws White before Black, so at contact a white attacker would pass
## *behind* the skeleton and the strike would happen out of sight.
##
## Engaged on the dive and dropped on landing -- deliberately not for the whole
## flight, which is what the first version did and what cost the defender ~3
## frames of total occlusion at the apex. One boundary, two failure modes: the
## lift is the fix for the contact frames only, and the apex gap above is the
## fix for everything before them. Verified on a frame strip of both colours
## (tests/render_clash_frames.gd); the black pounce reads correctly either way,
## which is exactly why it needs looking at in both.
const POUNCE_Z_LIFT := 10
## The burst sits at the defender's head rather than the charge's chest, because
## this hit comes down from above; the angle elongates it along the strike axis.
const POUNCE_IMPACT_Y := 730.0
const POUNCE_BURST_ANGLE := 0.9
## Radians. The sign comes from `toward`, so the lean is into the strike for
## either colour.
const POUNCE_TILT := 0.34
## The opposite lean, held through the rise. The tilt runs in three stages --
## cocked back on the climb, uprighting across the hang, snapping to
## POUNCE_TILT on the dive -- so the hang is a coil rather than a freeze, and
## the whole 0.34rad of the strike lean is spent in the 0.10s that is actually
## the strike.
##
## The rig's root is at its feet, so a lean is a long lever: 0.34rad swings the
## helmet ~230px sideways. That is why the back-lean is worth having at all
## (it buys separation at the apex for free) and why uprighting rather than
## leaning in is what the hang does.
const POUNCE_RISE_TILT := 0.16
## Squash and stretch as *factors* of each rig's authored scale, never absolute:
## the skeleton is mounted at (-0.714, 0.714) and an absolute Vector2 would
## unmirror it mid-leap. Deepened with the taller arc (1.14/0.86 -> 1.20/0.80):
## the anticipation has to be worth 380px, and a crouch that does not read is
## the cheapest half of a jump to lose.
const POUNCE_CROUCH := Vector2(1.20, 0.74)
const POUNCE_STRETCH := Vector2(0.80, 1.26)
const POUNCE_LANDING := Vector2(1.22, 0.78)
## Snappier than JuiceBus.HITSTOP_SEC, so the two hits do not land with the same
## weight. Read once here and passed in, rather than copied into JuiceBus.
const POUNCE_HITSTOP := 0.06

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
# Full rest transform per figure, not just x. The pounce lifts, tilts and
# squashes, so all three have to be recorded here to be restorable.
var _home_pos: Array[Vector2] = []
var _home_rotation: Array[float] = []
var _home_scale: Array[Vector2] = []
var _home_z: Array[int] = []
var _is_open := false
var _is_clashing := false
# Bumped on every start and every finish. A beat captures it and stops the
# moment it no longer matches, which is how a clash finished from the outside
# stops mid-await instead of running its remaining beats over a reset stage.
var _clash_seq := 0
var _board_tween: Tween
# Every tween a clash starts. Left alive, any one of them would drag a figure
# off its rest transform on the frame after a reset -- exactly the debris a skip
# must not leave. An array rather than the two named slots the charge alone
# needed, because the pounce runs the arc, the tilt and the squash at once.
var _clash_tweens: Array[Tween] = []
var _clash_start_usec := 0
var _awaiting_first_frame := false
var _cue_log: Array[String] = []


func _ready() -> void:
	if board:
		_board_scale = board.scale
	for c in _characters:
		_home_pos.append(c.position)
		_home_rotation.append(c.rotation)
		_home_scale.append(c.scale)
		_home_z.append(c.z_index)
	# The homes and the mount scales are printed because every pounce number is
	# derived from them: a rig that moved in the scene, or a mirror that is not
	# where this script thinks it is, shows up here rather than mid-leap.
	print("PAWNCH_PANEL board=%s frame_probe=%s homes=%s scales=%s" % [
		board != null, frame_probe != null, _home_pos, _home_scale])
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


# The debug button's entry point: clash #1, the one this panel was authored
# against.
func play() -> void:
	play_capture("white", "knight", "pawn")


## Tap to the board coming back: the whole <=2.0s budget for that clash, and the
## span a skip can land anywhere inside. Derived from the beat schedule rather
## than written down a second time.
static func clash_length(clash_name: String) -> float:
	return float(CLASH_BEATS[clash_name]["exit"]) + WIPE_OUT_DURATION


# Which clash an attacker type gets, and how long it runs. Never returns
# nothing: an unauthored or unknown type falls back to a clash that does exist,
# so a capture can never resolve to silence.
static func clash_for(attacker_type: String) -> Dictionary:
	var authored: bool = CLASH_BY_TYPE.has(attacker_type)
	var clash_name: String = CLASH_BY_TYPE.get(attacker_type, FALLBACK_CLASH)
	return {
		"name": clash_name,
		"duration": clash_length(clash_name),
		"fallback": not authored,
	}


# The bespoke clash for whichever colour is attacking, chosen by what the
# attacker is. Re-entrant calls while a clash is already running are refused
# rather than queued or interrupted; ending one early is finish_now()'s job, not
# this function's.
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
	# Four of the six types share a clash, so the crests are the only thing
	# naming the pieces that are actually fighting.
	attacker.set_piece_type(attacker_type)
	defender.set_piece_type(defender_type)
	var chosen := clash_for(attacker_type)
	_cue_log.append("PAWNCH_CUE clash attacker=%s_%s defender=%s_%s clash=%s fallback=%s" % [
		attacker_color, attacker_type,
		"black" if attacking_white else "white", defender_type,
		chosen["name"], chosen["fallback"]])

	match String(chosen["name"]):
		"pounce":
			await _run_pounce(seq, attacker, defender, attacking_white)
		_:
			await _run_charge(seq, attacker, defender, attacking_white)
	_finish("natural", seq)


# Clash #1: the knight's flat run across the ground. Five beats -- wind-up,
# charge, impact, recoil, knockout. Every wait can come back false -- the clash
# was finished from the outside while it was in flight -- and every one of them
# then returns without touching the stage, because whoever finished it has
# already reset it.
func _run_charge(seq: int, attacker: CharacterRig, defender: CharacterRig,
		attacking_white: bool) -> void:
	var beats: Dictionary = CLASH_BEATS["charge"]
	var t_windup := float(beats["windup_end"])
	var t_impact := float(beats["impact"])
	var t_recoil := float(beats["recoil"])
	var t_dying := float(beats["dying"])
	var t_exit := float(beats["exit"])

	var idx := 0 if attacking_white else 1
	var attacker_home: float = _home_pos[idx].x
	var defender_home: float = _home_pos[1 - idx].x
	var toward := signf(defender_home - attacker_home)
	var windup_x := attacker_home - toward * WINDUP_BACK
	var charge_x := defender_home - toward * CHARGE_GAP
	var impact_point := Vector2((charge_x + defender_home) * 0.5, IMPACT_Y)

	open()  # wipe_in begins; wind-up starts on the same frame (tap -> < 200ms)
	_arm_first_frame_cue()

	var run := _new_tween()
	run.tween_property(attacker, "position:x", windup_x, t_windup) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	run.tween_property(attacker, "position:x", charge_x, t_impact - t_windup) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if not await _wait_until(seq, t_windup):
		return
	# Each rig's own Slashing already points at the other side, and the
	# skeleton's does so through duel_panel.tscn's static per-colour mirror --
	# measured, not assumed: see ADR-0011 decision 5.
	attacker.play_state("Slashing")
	_juice.play_swing()

	if not await _wait_until(seq, t_impact):
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
	var back := _new_tween()
	back.tween_property(attacker, "position:x", attacker_home,
			t_exit - t_impact - JuiceBus.HITSTOP_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if not await _wait_until(seq, t_recoil):
		return
	_fire_cue("recoil")

	if not await _wait_until(seq, t_dying):
		return
	defender.play_state("Dying")

	if not await _wait_until(seq, t_exit):
		return
	_fire_cue("exit")
	close()

	await _wait_until(seq, t_exit + WIPE_OUT_DURATION)


# Clash #2: the pawn's pounce. Same contract as the charge above -- every wait
# can come back false and returns without touching the stage -- and the same
# derivation from home positions and a signed direction, so black's leap is
# white's mirrored.
#
# Seven beats. Crouch (gather and squash), rise (a fast ballistic launch to a
# point well short of the defender, cocked away from it), hang (the top of the
# arc held as its own beat, the back-lean coiling out of it), dive (down and
# forward into contact), impact from above, the fall with an overshoot squash on
# landing, a low hop home, exit. The attacker's feet are off the ground from
# 0.14s to 0.72s and again from 0.84s to 1.34s, which is the whole difference
# from the charge: that one never leaves the floor.
func _run_pounce(seq: int, attacker: CharacterRig, defender: CharacterRig,
		attacking_white: bool) -> void:
	var beats: Dictionary = CLASH_BEATS["pounce"]
	var t_crouch := float(beats["crouch_end"])
	var t_apex := float(beats["apex"])
	var t_dive := float(beats["dive"])
	var t_impact := float(beats["impact"])
	var t_land := float(beats["land"])
	var t_recoil := float(beats["recoil"])
	var t_dying := float(beats["dying"])
	var t_hop := float(beats["hop_end"])
	var t_exit := float(beats["exit"])

	var idx := 0 if attacking_white else 1
	var home: Vector2 = _home_pos[idx]
	var home_scale: Vector2 = _home_scale[idx]
	var defender_x: float = _home_pos[1 - idx].x
	var toward := signf(defender_x - home.x)
	var crouch_pos := home - Vector2(toward * POUNCE_GATHER, 0.0)
	# Two stations, both derived from the defender's home and the same signed
	# direction, so black's leap is white's mirrored and neither is authored
	# twice: the apex sits back in open air, the strike closes to contact.
	var apex_pos := Vector2(defender_x - toward * POUNCE_APEX_GAP, home.y - POUNCE_HEIGHT)
	var hang_pos := Vector2(apex_pos.x + toward * POUNCE_HANG_DRIFT, apex_pos.y)
	var strike_pos := Vector2(defender_x - toward * POUNCE_GAP, home.y - POUNCE_STRIKE_HEIGHT)
	var land_pos := Vector2(strike_pos.x + toward * POUNCE_CARRY, home.y)
	var impact_point := Vector2((strike_pos.x + defender_x) * 0.5, POUNCE_IMPACT_Y)

	open()  # wipe_in begins; the crouch starts on the same frame (tap -> < 200ms)
	_arm_first_frame_cue()

	# Beat 1 -- the gather. The rig's root sits at its feet, so squashing about
	# it presses the figure into the floor instead of sinking it through.
	var crouch := _new_tween()
	crouch.set_parallel(true)
	crouch.tween_property(attacker, "position", crouch_pos, t_crouch) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	crouch.tween_property(attacker, "scale", home_scale * POUNCE_CROUCH, t_crouch) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if not await _wait_until(seq, t_crouch):
		return
	# Beat 2 -- the launch. y decelerates into the apex while x eases forward,
	# which is a ballistic rise rather than a straight line between two points.
	# Under half the time the old single tween had, and it ends short of the
	# defender rather than on top of it: 380px of rise in 0.16s is what a pounce
	# leaving the ground looks like. The stretch snaps out on the
	# launch and relaxes in the air, and the lean goes *backwards* -- the figure
	# is cocked away from the target all the way up.
	var rise_sec := t_apex - t_crouch
	var leap := _new_tween()
	leap.set_parallel(true)
	leap.tween_property(attacker, "position:x", apex_pos.x, rise_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	leap.tween_property(attacker, "position:y", apex_pos.y, rise_sec) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	leap.tween_property(attacker, "rotation", -toward * POUNCE_RISE_TILT, rise_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var stretch := _new_tween()
	stretch.tween_property(attacker, "scale", home_scale * POUNCE_STRETCH, rise_sec * 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stretch.tween_property(attacker, "scale", home_scale, rise_sec * 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# No z-lift yet: at POUNCE_APEX_GAP the two silhouettes do not touch, so
	# draw order cannot matter here, and lifting through the arc is exactly what
	# hid the defender last time.
	#
	# Slashing runs 0.4s and its swing lands near its own end, so starting it on
	# the launch puts the blade's own contact frame on the impact beat without a
	# second cue: 0.14 + 0.40 = 0.54.
	attacker.play_state("Slashing")
	_juice.play_swing()

	if not await _wait_until(seq, t_apex):
		return
	# Beat 3 -- the hang. The whole point of Block G: a top of the arc that is a
	# beat someone can see rather than the instant a tween turns around. Position
	# barely moves; the back-lean comes out and the figure coils upright, which
	# is motion the eye reads as gathering rather than as a dropped frame -- and
	# it swings the silhouette *away* from the defender rather than over it.
	var hang_sec := t_dive - t_apex
	var hang := _new_tween()
	hang.set_parallel(true)
	hang.tween_property(attacker, "position", hang_pos, hang_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hang.tween_property(attacker, "rotation", _home_rotation[idx], hang_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if not await _wait_until(seq, t_dive):
		return
	# Beat 4 -- the dive. The only part of the leap that closes on the defender,
	# and the only part that needs to be in front of it. Accelerating, because
	# this is the strike falling rather than the figure travelling: the whole
	# forward lean is spent here too, in 0.10s, so the lunge and the blade arrive
	# on the same frame.
	attacker.z_index = _home_z[idx] + POUNCE_Z_LIFT
	var dive := _new_tween()
	dive.set_parallel(true)
	dive.tween_property(attacker, "position", strike_pos, t_impact - t_dive) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	dive.tween_property(attacker, "rotation", toward * POUNCE_TILT, t_impact - t_dive) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if not await _wait_until(seq, t_impact):
		return
	_fire_cue("impact")
	defender.play_state("Hurt")
	if defender == _black:
		defender.detach_head()
	# An aimed burst, not the charge's random one: placed at head height and
	# elongated along the downward strike axis, so the hit reads as coming from
	# above rather than as the same round pop from across the floor.
	var dispatch: Dictionary = await _juice.fire_impact(impact_point,
		toward * POUNCE_BURST_ANGLE, POUNCE_HITSTOP)
	if seq != _clash_seq:
		return
	_log_dispatch(dispatch)

	# Beat 5 -- the fall. Accelerating, coming upright on the way down. The
	# hitstop is subtracted because the beats are timed off the wall clock while
	# the tween runs on the (frozen, then released) engine clock.
	attacker.play_state("Idle Blinking")
	var fall_sec := t_land - t_impact - POUNCE_HITSTOP
	var fall := _new_tween()
	fall.set_parallel(true)
	fall.tween_property(attacker, "position", land_pos, fall_sec) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(attacker, "rotation", _home_rotation[idx], fall_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if not await _wait_until(seq, t_land):
		return
	# Beat 6 -- the landing. The overshoot squash is what sells the weight of a
	# figure that has just come down from 380px; it is a factor of the authored
	# scale, so the mirrored skeleton stays mirrored through it. The z-lift comes
	# off here, the frame the feet are back on the floor.
	attacker.z_index = _home_z[idx]
	var settle_sec := t_recoil - t_land
	var settle := _new_tween()
	settle.tween_property(attacker, "scale", home_scale * POUNCE_LANDING, settle_sec * 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle.tween_property(attacker, "scale", home_scale, settle_sec * 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if not await _wait_until(seq, t_recoil):
		return
	_fire_cue("recoil")
	# Beat 7 -- the hop home. A second, much lower arc, so even the retreat is
	# airborne and still not a walk back across the floor.
	var hop_sec := t_hop - t_recoil
	var hop := _new_tween()
	hop.tween_property(attacker, "position:x", home.x, hop_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var hop_arc := _new_tween()
	hop_arc.tween_property(attacker, "position:y", home.y - POUNCE_HOP_HEIGHT, hop_sec * 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop_arc.tween_property(attacker, "position:y", home.y, hop_sec * 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if not await _wait_until(seq, t_dying):
		return
	defender.play_state("Dying")

	if not await _wait_until(seq, t_exit):
		return
	_fire_cue("exit")
	close()

	await _wait_until(seq, t_exit + WIPE_OUT_DURATION)


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


# Every tween a beat starts goes through here, so _reset_stage() can kill all of
# them without each beat function having to own a named slot.
func _new_tween() -> Tween:
	var t := create_tween()
	_clash_tweens.append(t)
	return t


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


# Idempotent: puts everything a clash moves, lifts, tilts, squashes, detaches or
# hides back to its authored rest state. Called on entry to play_capture()
# (defensive, in case a previous clash left something behind) and from
# close_now(), which every ending path reaches through _finish() -- so
# back-to-back clashes start from the same place every time, and a clash cut
# short at any instant ends where a clash allowed to run in full does.
func _reset_stage() -> void:
	Engine.time_scale = 1.0
	for t in _clash_tweens:
		if t and t.is_valid():
			t.kill()
	_clash_tweens.clear()
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
		# The whole transform, not just x: the pounce leaves the ground, leans
		# and squashes, so a skip caught mid-leap would otherwise put the figure
		# back on its home file still airborne, tilted and flattened. Scale goes
		# back to the authored value -- (-0.714, 0.714) for the mirrored
		# skeleton -- never to Vector2.ONE.
		c.position = _home_pos[i]
		c.rotation = _home_rotation[i]
		c.scale = _home_scale[i]
		c.z_index = _home_z[i]


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
#
# The frame count is deliberately unchanged at two: _ready() awaits this before
# close_now(), and callers that instantiate the scene and wait two frames before
# playing a capture would otherwise have close_now() land in the middle of their
# clash.
func _warm() -> void:
	modulate.a = 0.0
	_mask.size.x = PANEL_SIZE.x
	# Every animation either clash can reach, on both rigs. Only the last is
	# drawn, but an AnimationPlayer resolves and caches a track's NodePaths at
	# play() time, and that is the part that stalls -- the pounce is the first
	# thing that would otherwise make the player pay for Slashing on their own
	# first capture.
	for state in ["Idle", "Hurt", "Dying", "Slashing", "Idle Blinking"]:
		for c in _characters:
			c.play_state(state)
	# And the pounce's own transform path: off the ground, tilted and squashed
	# as a factor of the authored scale. Drawn once here rather than on the
	# player's first leap; close_now() puts it all back immediately after.
	for i in _characters.size():
		var c := _characters[i]
		c.position = _home_pos[i] - Vector2(0.0, POUNCE_HEIGHT)
		c.rotation = POUNCE_TILT
		c.scale = _home_scale[i] * POUNCE_STRETCH
	_juice.warm()
	_characters[1].warm_detach()
	await get_tree().process_frame
	await get_tree().process_frame
	modulate.a = 1.0
