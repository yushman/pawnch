extends Control
class_name DuelPanel

# Full-screen cutaway (ADR-0002). A 1240x1080 panel centred in whatever the
# runtime viewport is, so the framing survives the 16:9-20:9 supported range
# without re-composing.
#
# play_capture() looks the attacker's type up in CLASH_BY_TYPE and dispatches to
# the beat function that clash names: _run_charge() for the knight's flat run
# across the ground, _run_pounce() for the pawn's leap, _run_strike() for the
# overhead smash every other type shares. All three are driven by this
# script rather than by an authored Animation resource, because the beat times
# are cue points the debug overlay and JuiceBus read off the same schedule
# (impact-juice spec: "no consumer of those cues holds a duplicate copy of any of
# those times") -- CLASH_BEATS is that schedule, and it is the only place any of
# these numbers is written down.
#
# The rigs have five animations between them and nobody here draws (ADR-0009),
# so the whole difference between the three clashes is path, timing, tilt,
# squash and where the burst lands. All of it code.
#
# Sides are fixed by colour and never by role (ADR-0011 decision 5): white is
# always the left figure, black always the right one, and the capture resolves
# by who dies. So each clash has one timeline whichever colour is attacking, and
# the direction plus every staging position is derived from the two figures'
# home positions and a signed direction rather than authored twice.

# The smallest viewport the supported aspect range guarantees. `keep_height`
# fixes the short edge at 1080 and lets the long one run with the device, so the
# width is what varies: 1920 at 16:9, 2400 at 20:9 on the target phone. Composing
# against 1920 is what makes the framing independent of which of those it gets.
const SAFE_BAND_SIZE := Vector2(1920, 1080)
## **The stage is not the band, and this is the case the two constants were kept
## separate for.** They answer different questions -- "how much screen is
## guaranteed" and "how much of it is the fight" -- and for one day they happened
## to have the same answer: the panel took the whole 1920 band and the duel stood
## in the middle of it with 304 px of empty stage to its left and 442 px to its
## right, which is what docs/media/day8-landscape-clash-impact.png shows.
##
## The height is the band's, because the height is what binds the mount scale
## (THE STAGE below). The width is derived from what the clashes actually cover
## and is 680 px narrower than the band: the derivation is in THE STAGE with the
## rest of the staging, because it is the same three constraints that used to
## decide the mount scale, read the other way round. frame_rect_for() centres it
## in the band and the band in the viewport, so the panel is still the same
## rectangle at 16:9 as at 20:9 -- what shows either side of it is board and
## margin, not stage.
const PANEL_SIZE := Vector2(1240, 1080)
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
#   strike -- everyone else (Day 7). Impact at 0.52s, exit at 1.40s, 1.70s end
#     to end, shorter than both on purpose. Day 6's playtest was 24 clashes in
#     one game -- 19 charge, 5 pounce -- and after this change the four types
#     that made those 19 all resolve here, so this is the clash of the game by
#     volume and it is the one that must not outstay its welcome. Same rule as
#     the pounce, applied a second time: three clashes, three lengths.
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
	# gather -- weight back and down; also where Slashing starts, so that its own
	#   0.40s swing lands its contact frame on impact without a second cue
	#   (0.12 + 0.40 = 0.52), the same trick the pounce plays at 0.14.
	# raise -- the whole figure rears up and cocks away from the target. The 0.24s
	#   here is the beat that makes this vertical rather than horizontal: the
	#   attacker's x does not move at all across it.
	# impact -- the slam. knock is where the defender stops travelling, and it is
	#   the only beat in this file that belongs to the defender.
	"strike": {
		"gather": 0.12,
		"raise": 0.36,
		"impact": 0.52,
		"knock": 0.72,
		"recoil": 0.82,
		"dying": 0.90,
		"exit": 1.40,
	},
}

# The clash lookup (clash-sequencing spec: "The lookup MUST NOT be able to
# return nothing"). It is what makes "no capture is ever silent" testable --
# failure mode 3 in system-analysis.md is a capture that resolves to nothing and
# removes a piece with no animation and no error.
#
# Two types have a bespoke clash. Three more are named onto the shared strike,
# and the queen is deliberately left out of the table so that the fallback path
# is a path something real takes rather than dead code -- she lands on the strike
# and stays there. Cut order step 1 fired on 2026-08-23: the queen gets no clash
# of her own, which is a decision and not an unfinished row. Adding an entry here
# must never be able to weaken the guarantee for the types that still have none,
# which is why clash_for() defaults rather than indexing.
const PIECE_TYPES := ["pawn", "knight", "bishop", "rook", "queen", "king"]
const CLASH_BY_TYPE := {
	"pawn": "pounce", "knight": "charge",
	"bishop": "strike", "rook": "strike", "king": "strike",
}
const FALLBACK_CLASH := "strike"

# THE STAGE -- the mount scale, the two homes, the panel's own width, and which
# axis buys which.
#
# duel_panel.tscn mounts both rigs at 0.52 (the skeleton mirrored, -0.52) with
# homes at white x=483, black x=893, both standing on y=930. Through Day 7 those
# were 0.714 and x=252/810 on y=1115 in a 1080-wide portrait panel, where both
# figures were clipped by the panel edges standing still and the loser's defeat
# pose ran 231 px past the left edge; Day 8 fixed that by shrinking to 0.45, and
# this is the number that fix cost, being taken back.
#
# **The axis that binds has swapped, and that is the whole point of the flip.**
# The three constraints below are the width ones, unchanged as arithmetic:
#
#   x_white           >= 868*s
#   panel_w - x_black >= 604*s
#   x_black - x_white  = 654*s + clear background between them at rest
#
# In portrait they decided the mount scale: they sum to ~2260*s <= panel_w, and
# at 1080 px of panel that gave s <= 0.467 and the answer was 0.45. **They do not
# decide s any more -- height does, below -- so with s fixed they decide panel_w
# instead, and that is the only way to read them that leaves no slack in the
# frame.** The first two are the two figures' worst horizontal reach, both of
# them the *defender* driven back by the strike and measured with
# tools/measure_stage_bounds.gd, in rig units from that figure's own home:
#
#   868 rig units    the valkyrie knocked back, reeling and then lying, at
#                    t=0.78 of strike-black. Her own defeat is 676 of it; the
#                    rest is STRIKE_KNOCKBACK carrying her there.
#   604 rig units    the skeleton doing the same at t=0.73 of strike-white --
#                    343 of pose past a root that STRIKE_KNOCKBACK has already
#                    moved 133 px.
#
# The third is not a constraint being satisfied but a number being held: the
# separation is 410 px and it stays 410 px, because the charge covers home to
# home minus CHARGE_GAP in a fixed 0.40 s and moving the homes apart re-times a
# beat schedule measured on the device. So the content is
#
#   (868 + 604)*0.52 + 410 = 1176 px
#
# and the panel is that plus a margin at each edge. The margin to want is the one
# the height derivation already left -- 33 px above the highest frame of the
# pounce, 30 px below the lowest frame of the defeat -- because 33 px of air
# above the fight and 304 px beside it is not one framing, it is two, and the
# wide one is the one nobody chose:
#
#   panel_w = 1176 + 2*32  =>  **1240**, and x_white = 868*0.52 + 32 = 483.
#
# Measured back with tools/measure_stage_bounds.gd across all six clash x colour
# runs: 31.5 px clear on the left and 33.1 on the right, against 33.4 above and
# 30.4 below. The panel was 1920 px wide for one day, and the 680 px this takes
# out of it were 304 px of empty stage on the left and 442 on the right at 0.52
# -- nothing ever reached them.
#
# What it does *not* do is grow the figures. s is bound by height and is
# untouched at 0.52; the whole change is that the frame stops carrying 744 px of
# stage nothing ever stands on (the fight spans 95% of the panel's width now,
# against 61% before).
#
# Height binds instead, and it did not exist as a constraint before -- the
# portrait panel was 1500 px tall for a figure that reached 973 rig units, so
# nothing a clash did came near either edge. Two numbers, both measured with
# tools/measure_stage_bounds.gd (which had to learn the vertical axis for this;
# it only ever reported x):
#
#   1724 rig units   the highest anything reaches above its own home -- the black
#                    pawn's crest at t=0.22, which is *mid-rise*, not the apex:
#                    POUNCE_STRETCH's 1.26 peaks before the arc does. 1191 of it
#                    is the figure's own stretched reach and 533 is POUNCE_HEIGHT.
#    230 rig units   the deepest anything reaches below it -- the valkyrie's head
#                    at t=1.26, lying in the pack's own `Dying`. Her feet are her
#                    root; the pose puts her head below the floor line.
#
# Both figures stand on one ground line, so those add:
#
#   y_home >= 1724*s   and   y_home <= 1080 - 230*s
#   => 1954*s <= 1080  =>  **s <= 0.5527**
#
# 0.52 is that bound with the margin it needs, and the margin is deliberately in
# the same proportion the width had at 0.45: y_home = 930 leaves 33 px above the
# highest frame of the pounce and 30 px below the lowest frame of the defeat,
# against the 38.7 / 30.7 px the old staging cleared left and right. Measured
# clearances at this staging are in the block comment on POUNCE_HEIGHT.
#
# What that buys, stated the way the clash-animation spec asks for it: the
# standing figure goes from 438 px in a 1500 px panel to **506 px in a 1080 px
# one -- 29% of the panel's height to 47%.** The mount scale itself only grows
# 15.6%; the rest of it is the panel no longer being three times taller than the
# thing it frames.
#
# **The slack was taken out of the panel, not out of the staging, and that is a
# decision.** Three things would have filled a 1920 px frame. Pushing the homes
# apart is wrong because the charge covers home-to-home minus CHARGE_GAP in a
# fixed 0.40 s, so a wider separation is a faster run and the beat schedule above
# is measured on the device and pinned. Lowering the pounce is wrong for the
# reason written on POUNCE_HEIGHT: that arc is what fixed "the leap does not
# read" after a real game, and it is not spare change. Growing the figures is not
# available at all -- height binds s, and 1954*s <= 1080 is where 0.52 comes
# from. What is left is the frame itself, which costs nothing that was ever
# measured: narrowing it moves both homes by -272 px together, so every offset,
# every gap and every beat sees exactly the stage it saw before.
#
# The figures' own extents, measured by alpha profile (not a bounding box: a
# 0.26rad lean inflates a corner box by a third) and written in **rig units** --
# multiply by the mount scale for panel pixels. These are properties of the two
# packs' art, so they stay true whatever the scale becomes:
#
#   valkyrie, standing              437 left of her root,  326 right
#   valkyrie, mid-raise, leaning    511 left
#   valkyrie, defeated and lying    676 left,              458 right,  230 below
#   skeleton, standing              328 left,              448 right
#   skeleton, mid-raise, leaning                           549 right
#   either, stretched on the rise                                     1191 above
#
# The 676 is why the left-hand constraint is the widest of the three. The
# valkyrie always falls to her own left, and the direction is not ours to change:
# the fall is the pack's own `Dying` and nobody here draws (ADR-0009).
#
# Every number from here down is panel pixels at 0.52. A constant that was a
# measurement of the figures was scaled by 0.52/0.45 = 1.1556, which keeps the
# staging reading exactly as it did; a constant that was pinned against a panel
# edge was re-derived from the numbers above. Which of the two it is, is
# recorded on each one.

# Charge staging, as offsets rather than absolute x, so one set of numbers serves
# both attack directions: the attacker winds up WINDUP_BACK away from its own
# home and charges to CHARGE_GAP short of the defender's, on whichever side of
# the defender it happens to stand.
const WINDUP_BACK := 29.0    ## 25 * 1.1556
const CHARGE_GAP := 203.0    ## 176 * 1.1556
## Chest height for the burst: 135 px above the feet at 0.45, so 135 * 1.1556 =
## 156 above the new home y of 930.
const IMPACT_Y := 774.0
# Day 3 found the charge's staging by pulling frame-accurate stills off an
# on-device recording (adb screencap and ffmpeg -ss both proved unreliable). Two
# of the three fixes it made are still the reason these numbers exist, and both
# survive the restage because they are about the figures rather than the panel:
#   - a 100px root gap at contact badly overlapped the two rigs' bodies, so the
#     charge stops CHARGE_GAP short instead. At 176 px the silhouettes still
#     overlap by ~125 px, which is contact and is what the instant of the hit is
#     supposed to show -- it is the beats *before* it that must not.
#   - at rest the two heads touched with ZERO background between them (a scan at
#     head height ran solid foreground from x=131 to x=964), because the rig
#     heads are wide relative to the root gap. The homes were pulled apart for
#     that, and it is now the third constraint above: 654*s of figure plus real
#     background. At 0.52 the homes are 410 apart and 70 px of that is
#     background -- the same proportion 0.45's 355/61 held, scaled with the
#     figures. It is the number the panel's width is now derived *from* rather
#     than a number the panel's width allows: see THE STAGE.
# The third fix -- moving the defender's home in because its head crossed the
# panel edge -- was the same bug as this restage, patched one figure at a time.
# It is now handled by the constraints above rather than by moving a home when
# something is seen to be clipped.

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
const POUNCE_GATHER := 18.0          ## how far back the crouch slides; 16 * 1.1556
## x gap to the defender at the top of the arc. 185 (at 0.714) was the whole bug:
## the silhouettes coincided there.
##
## 271 * 1.1556, and the 271 before it was measured rather than chosen. The skeleton's
## skull is the top 45% of the whole figure and its left edge sits 328 rig units
## left of its own root -- so an attacker whose silhouette overlaps the
## defender's x range at all has the skull, not the background, behind its feet,
## and a figure with foreground under its feet does not read as airborne however
## high it is. This is a measurement of the two figures, so it scales with them:
## the leading edge still clears the skull's left edge by the same open
## background *per unit of mount scale* that 430 bought at 0.714, and the
## geometry that made it work is unchanged -- the attacker's feet at the apex
## still sit just below the bottom of the skull.
##
## It also keeps the rise almost vertical (97px forward against 240px up), which
## is what a pounce is: the ground is covered by the dive, not the climb.
const POUNCE_APEX_GAP := 313.0
## x gap at the moment of contact. 136 * 1.1556. The original 215 was narrowed to
## 185 on host-render evidence and the device said that was the wrong way; it is
## where the sword tip reaches the skull without the bodies interpenetrating,
## which is a fact about the two figures and therefore scales with them.
const POUNCE_GAP := 157.0
## How far above its own feet the arc peaks. 240 * 1.1556.
##
## **The ceiling that set this number at 0.714 is back, and this time it decides
## the mount scale rather than the other way round.** In portrait it stopped
## binding: at 0.45 the crest did not leave a 1500px frame until a root height of
## ~507, and 240 cleared the top edge by 317. A 1080px panel has no such slack --
## this leap plus the figure's own stretched reach is the 1724 rig units in THE
## STAGE, and dividing 1080 between that and the defeat pose *is* the derivation
## of s.
##
## It is still scaled rather than re-chosen, and that is a decision rather than
## laziness. Shrinking the leap is the one lever that would buy a bigger figure
## -- holding it to 300 rig units instead of 533 would allow s = 0.628 -- and
## Block G re-cut this whole clash after a real game said the leap did not read:
## "прыжок не заметен". Spending the thing a playtest already flagged, to grow
## every figure by 14%, is the wrong side of that trade.
##
## Measured at 0.52 with tools/measure_stage_bounds.gd: the black pounce is the
## highest frame of any clash and it clears the panel's top edge by 33 px.
const POUNCE_HEIGHT := 277.0
## Height above its own feet at the instant of the strike. 158 * 1.1556. The dive
## spends a third of the arc's height on the way in, so the hit visibly comes
## *down* out of the hang instead of being delivered from a hover.
const POUNCE_STRIKE_HEIGHT := 183.0
## Forward drift across the hang. 11 * 1.1556. Small on purpose: enough that the
## figure is floating rather than paused, not enough to turn the hang back into
## a transit.
const POUNCE_HANG_DRIFT := 13.0
const POUNCE_CARRY := 24.0           ## strike-to-landing drift; 21 * 1.1556
## The lower second arc, going home. 126 * 1.1556, holding the 0.53 of the main
## arc that makes the retreat read as the same character: the one that jumps.
const POUNCE_HOP_HEIGHT := 146.0
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
## 243 px above the feet at 0.45, so 243 * 1.1556 = 281 above y=930.
const POUNCE_IMPACT_Y := 649.0
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
## helmet ~168px sideways at 0.52. That is why the back-lean is worth having at
## all (it buys separation at the apex for free) and why uprighting rather than
## leaning in is what the hang does. Radians scale with nothing, so this number
## did not move -- but what it costs in pixels did, and the lean is one of the
## two things that decide how close the homes can be (see THE STAGE).
const POUNCE_RISE_TILT := 0.16
## Squash and stretch as *factors* of each rig's authored scale, never absolute:
## the skeleton is mounted at (-0.52, 0.52) and an absolute Vector2 would
## unmirror it mid-leap. Deepened with the taller arc (1.14/0.86 -> 1.20/0.80):
## the anticipation has to be worth the whole rise, and a crouch that does not
## read is the cheapest half of a jump to lose.
const POUNCE_CROUCH := Vector2(1.20, 0.74)
const POUNCE_STRETCH := Vector2(0.80, 1.26)
const POUNCE_LANDING := Vector2(1.22, 0.78)
## Snappier than JuiceBus.HITSTOP_SEC, so the two hits do not land with the same
## weight. Read once here and passed in, rather than copied into JuiceBus.
const POUNCE_HITSTOP := 0.06

# Strike staging -- clash #3, the one four types share and the one a session sees
# most. Same derivation rule as the other two: every number below is an offset
# from the attacker's own home or from the defender's, taken along a signed
# direction, so black's smash is white's mirrored rather than a second set of
# numbers.
#
# The charge is horizontal travel and the pounce leaves the ground; the strike is
# vertical energy delivered from roughly where the attacker stands. What carries
# that is the split of the 0.52s before impact: 0.40s of it moves the attacker's
# x by nothing at all (gather back, rise, lean away), and only the last 0.16s is
# forward motion. The charge spends 0.40s of its 0.55s travelling.
## How far back the wind-up slides; 21 * 1.1556. It moves the attacker *away*
## from the defender, which is why it appears on the right-hand constraint in
## THE STAGE: it is the skeleton's own outward step before it leans further out.
## 21 * 1.1556.
const STRIKE_GATHER := 24.0
## How far the whole figure lifts across the raise. 69 * 1.1556. Not a leap and
## deliberately nowhere near one -- POUNCE_HEIGHT is 277 -- this is rearing up,
## which is what makes room for the blow to come *down*. 70 (at 0.714) was the
## first try and a frame strip said it did nothing, lost inside the stretch; 110
## plus the 14% stretch was ~210px of movement on a ~730px figure, and the ratio
## is what mattered, so it scales. Unlike the pounce, this one is nowhere near
## the new ceiling: the strike's highest frame reaches 1344 rig units above the
## home against the pounce's 1725, so it clears the panel's top edge by 231 px
## where the pounce clears it by 33.
const STRIKE_RISE := 80.0
## x gap to the defender at the moment of the blow. 189 * 1.1556, still wider
## than the charge's 203 because the blade arrives from overhead rather than
## thrust along the floor. The silhouettes *do* overlap here -- 654 rig units of
## figure against a 218px stop, so ~122px of overlap -- and that is contact,
## which is what the instant of the hit is supposed to show. What the pounce
## shipped with was different and is not possible here: it was total occlusion
## for ~3 frames *before* the hit. The gather moves the attacker away from the
## defender, so it is never closer than at the blow itself, and no z-lift is
## engaged anywhere in _run_strike().
##
## It is also the one staging number that buys room at both edges: the attacker
## stops STRIKE_GAP short, so a wider gap pulls the swinging weapon back inside
## the panel on whichever side it is swinging towards.
const STRIKE_GAP := 218.0
## Radians, cocked away from the target across the raise, then spent into the blow
## in the 0.16s that is actually the strike. The rig root is at its feet, so a lean
## is a long lever -- 0.26rad swings the helmet ~133px sideways at 0.52, which is
## most of what makes the wind-up visible at all, and it swings it *outwards*:
## this is the 549-unit figure in THE STAGE's second constraint, and it, not the
## figure standing still, is what decides how close the black home can be to the
## right-hand edge.
const STRIKE_LEAN_BACK := 0.26
const STRIKE_LEAN_IN := 0.30
## Squash and stretch as *factors* of each rig's authored scale, never absolute:
## the skeleton is mounted at (-0.52, 0.52) and an absolute Vector2 would
## unmirror it mid-swing.
const STRIKE_CROUCH := Vector2(1.10, 0.88)
const STRIKE_STRETCH := Vector2(0.90, 1.14)
const STRIKE_SLAM := Vector2(1.16, 0.86)
## The defender is driven backwards -- the only clash that moves it, and the whole
## reason this one has a skip sweep of its own.
##
## **Re-derived rather than scaled, twice now, and this time the derivation came
## back empty.** At 0.714 it was 150 and most of it happened outside the mask; at
## 0.45 it was 115, and that was not a taste call but a *ceiling* -- the panel's
## right-hand edge stayed slack only until STRIKE_KNOCKBACK + 343*s passed
## STRIKE_GATHER + 549*s, and 115 was where those met.
##
## On a 1920px panel that ceiling went to ~441 px and stopped deciding anything,
## and the number kept was the one property the ceiling had happened to give it:
## 0.26 of the figure's own height, which is a knockback that reads. 115 * 1.1556
## = 133 keeps exactly that.
##
## **Narrowing the panel to 1240 puts the ceiling back within sight, and this
## number is now the thing the right-hand margin is spent on.** The knocked
## defender's own pose reaches 343*s = 181 px past its root, the margin between
## the black home and the panel edge is 347 px, so the ceiling is ~166 px and
## there is 33 px of headroom rather than 308. It is not a constraint being
## violated -- 133 fits, with the same clearance the top and bottom edges get --
## but it is no longer a number that can be raised without re-deriving panel_w
## along with it.
const STRIKE_KNOCKBACK := 133.0
## How much of that ground it takes back as it settles, holding the old 0.31
## ratio. It stays pushed back: a figure that walks all the way home after being
## hit did not lose. What it settles on is where it dies, so this is the number
## that decides whether the lying pose fits -- see THE STAGE's first constraint.
const STRIKE_RECOVER := 41.0
const STRIKE_KNOCK_TILT := 0.22
## The burst sits between the two figures at chest height and is aimed nearly
## straight down the strike axis -- the pounce's 0.9rad is a dive coming in at an
## angle; this one falls. Sign from `toward`, so it tips into the blow either way.
## 199 px above the feet at 0.45, so 199 * 1.1556 = 230 above y=930.
const STRIKE_IMPACT_Y := 700.0
const STRIKE_BURST_ANGLE := 1.45
## Heavier than the charge's JuiceBus.HITSTOP_SEC (0.09) and much heavier than the
## pounce's 0.06, because this hit is a mass coming down rather than a body
## arriving. Read once here and passed in, rather than copied into JuiceBus.
const STRIKE_HITSTOP := 0.11

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


# Centres the panel in the safe band, itself centred in whatever viewport size is
# reported. The varying axis is x now rather than y -- `keep_height` is what the
# project setting became -- so the band offset moved with it. Pulled out of
# _layout() so the framing math is testable without depending on the project's
# stretch/aspect setup.
static func frame_rect_for(viewport_size: Vector2) -> Rect2:
	var band_x := (viewport_size.x - SAFE_BAND_SIZE.x) * 0.5
	var y := (viewport_size.y - PANEL_SIZE.y) * 0.5
	var x := band_x + (SAFE_BAND_SIZE.x - PANEL_SIZE.x) * 0.5
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
	# Four of the six types share the strike, so the crest and the weapon are the
	# only things naming the pieces that are actually fighting.
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
		"charge":
			await _run_charge(seq, attacker, defender, attacking_white)
		_:
			await _run_strike(seq, attacker, defender, attacking_white)
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


# Clash #3: the shared overhead smash, and the one a session sees most -- Day 6's
# playtest was 24 clashes in one game, 19 of them by types that now land here.
# Same contract as the other two: every wait can come back false and returns
# without touching the stage, every tween goes through _new_tween(), and all
# staging is derived from the two home positions and a signed direction.
#
# Six beats. Gather (weight back and down, Slashing starts so its own swing lands
# on impact), raise (up on the toes, cocked away, blade overhead -- x does not
# move at all), lunge and slam (the only forward motion in the whole clash, 0.16s
# of it), impact, the knockback, the settle, the defeat, exit.
#
# It is also the only clash that moves the *defender*, which is new failure
# surface rather than a flourish: the defender's rest position is now something a
# skip can leave wrong. _reset_stage() already restores position, rotation, scale
# and z for both figures -- confirmed before this was written, not after.
func _run_strike(seq: int, attacker: CharacterRig, defender: CharacterRig,
		attacking_white: bool) -> void:
	var beats: Dictionary = CLASH_BEATS["strike"]
	var t_gather := float(beats["gather"])
	var t_raise := float(beats["raise"])
	var t_impact := float(beats["impact"])
	var t_knock := float(beats["knock"])
	var t_recoil := float(beats["recoil"])
	var t_dying := float(beats["dying"])
	var t_exit := float(beats["exit"])

	var idx := 0 if attacking_white else 1
	var home: Vector2 = _home_pos[idx]
	var home_scale: Vector2 = _home_scale[idx]
	var defender_home: Vector2 = _home_pos[1 - idx]
	var toward := signf(defender_home.x - home.x)
	var gather_pos := home - Vector2(toward * STRIKE_GATHER, 0.0)
	var raise_pos := gather_pos - Vector2(0.0, STRIKE_RISE)
	var slam_pos := Vector2(defender_home.x - toward * STRIKE_GAP, home.y)
	var knock_pos := defender_home + Vector2(toward * STRIKE_KNOCKBACK, 0.0)
	var settle_pos := knock_pos - Vector2(toward * STRIKE_RECOVER, 0.0)
	var impact_point := Vector2((slam_pos.x + defender_home.x) * 0.5, STRIKE_IMPACT_Y)

	open()  # wipe_in begins; the gather starts on the same frame (tap -> < 200ms)
	_arm_first_frame_cue()

	# Beat 1 -- the gather. The rig's root sits at its feet, so squashing about it
	# presses the figure into the floor instead of sinking it through.
	var gather := _new_tween()
	gather.set_parallel(true)
	gather.tween_property(attacker, "position", gather_pos, t_gather) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	gather.tween_property(attacker, "scale", home_scale * STRIKE_CROUCH, t_gather) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if not await _wait_until(seq, t_gather):
		return
	# Slashing runs 0.4s and its swing lands near its own end, so starting it here
	# puts the blade's own contact frame on the impact beat without a second cue:
	# 0.12 + 0.40 = 0.52.
	attacker.play_state("Slashing")
	_juice.play_swing()

	# Beat 2 -- the raise. Straight up and cocked away, x untouched. This is the
	# 0.24s that makes the clash vertical: the charge has been running across the
	# floor since its own 0.15s by the time this one has moved at all.
	var rise_sec := t_raise - t_gather
	var rise := _new_tween()
	rise.set_parallel(true)
	rise.tween_property(attacker, "position", raise_pos, rise_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rise.tween_property(attacker, "rotation", -toward * STRIKE_LEAN_BACK, rise_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rise.tween_property(attacker, "scale", home_scale * STRIKE_STRETCH, rise_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if not await _wait_until(seq, t_raise):
		return
	# Beat 3 -- the lunge and the slam. Accelerating, and the whole 0.56rad from
	# the back-lean to the forward lean is spent here, in 0.16s, so the step in
	# and the blade coming down arrive on the same frame. Back to home.y: the
	# figure drops out of the raise onto the blow.
	var slam_sec := t_impact - t_raise
	var slam := _new_tween()
	slam.set_parallel(true)
	slam.tween_property(attacker, "position", slam_pos, slam_sec) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slam.tween_property(attacker, "rotation", toward * STRIKE_LEAN_IN, slam_sec) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slam.tween_property(attacker, "scale", home_scale * STRIKE_SLAM, slam_sec) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if not await _wait_until(seq, t_impact):
		return
	_fire_cue("impact")
	defender.play_state("Hurt")
	# The defeat is asymmetric and it is a property of the character, not of the
	# position (ADR-0007 decision 4): the skeleton's head comes off, the
	# valkyrie's does not.
	if defender == _black:
		defender.detach_head()
	var dispatch: Dictionary = await _juice.fire_impact(impact_point,
		toward * STRIKE_BURST_ANGLE, STRIKE_HITSTOP)
	if seq != _clash_seq:
		return
	_log_dispatch(dispatch)

	# Beat 4 -- the knockback. Created after the freeze rather than before it, so
	# the defender launches out of the hitstop instead of creeping through it: the
	# beats are timed off the wall clock while a tween runs on the (frozen, then
	# released) engine clock, which is also why the hitstop comes off the duration.
	var knock_sec := t_knock - t_impact - STRIKE_HITSTOP
	var knock := _new_tween()
	knock.set_parallel(true)
	knock.tween_property(defender, "position", knock_pos, knock_sec) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	knock.tween_property(defender, "rotation", toward * STRIKE_KNOCK_TILT, knock_sec) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# The attacker comes upright and unsquashes on the recoil beat but walks home
	# across the whole rest of the clash, so the follow-through and the recovery
	# are two different lengths out of one parallel tween.
	attacker.play_state("Idle Blinking")
	var recover := _new_tween()
	recover.set_parallel(true)
	recover.tween_property(attacker, "position", home, t_exit - t_impact - STRIKE_HITSTOP) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	recover.tween_property(attacker, "rotation", _home_rotation[idx],
			t_recoil - t_impact - STRIKE_HITSTOP) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	recover.tween_property(attacker, "scale", home_scale,
			t_recoil - t_impact - STRIKE_HITSTOP) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if not await _wait_until(seq, t_knock):
		return
	# Beat 5 -- the settle. It gives back STRIKE_RECOVER of the ground it lost and
	# comes upright, and it stops there rather than walking home: a figure that
	# tidies itself up after being hit did not lose the fight.
	var settle_sec := t_recoil - t_knock
	var settle := _new_tween()
	settle.set_parallel(true)
	settle.tween_property(defender, "position", settle_pos, settle_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	settle.tween_property(defender, "rotation", _home_rotation[1 - idx], settle_sec) \
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
		# back to the authored value -- (-0.52, 0.52) for the mirrored
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
	# Every per-type weapon, on both rigs: twelve textures that would otherwise be
	# loaded and uploaded on the player's own first capture -- and after Day 7 that
	# capture is far more likely to be one of the four types sharing the strike
	# than the knight this panel was authored against. Going through
	# set_piece_type() warms the swap and not just the texture, and the authored
	# type is put back so the warm-up leaves no trace on the closed panel.
	for c in _characters:
		var authored: String = c.piece_type
		for type: String in PIECE_TYPES:
			c.set_piece_type(type)
		c.set_piece_type(authored)
	# And both clashes' transform paths -- the pounce off the ground and tilted
	# one way, the strike up on the toes leaning the other way and squashed the
	# other way -- one per warm-up frame, so the frame count stays at two. Both
	# are factors of the authored scale, so the mirrored skeleton stays mirrored.
	for i in _characters.size():
		var c := _characters[i]
		c.position = _home_pos[i] - Vector2(0.0, POUNCE_HEIGHT)
		c.rotation = POUNCE_TILT
		c.scale = _home_scale[i] * POUNCE_STRETCH
	_juice.warm()
	_characters[1].warm_detach()
	await get_tree().process_frame
	for i in _characters.size():
		var c := _characters[i]
		c.position = _home_pos[i] - Vector2(0.0, STRIKE_RISE)
		c.rotation = -STRIKE_LEAN_BACK
		c.scale = _home_scale[i] * STRIKE_STRETCH
	await get_tree().process_frame
	modulate.a = 1.0
