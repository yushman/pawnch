extends Node
class_name JuiceBus

# Hitstop, screen shake, one impact VFX burst, SFX and haptic thump -- all fired
# off the `impact` cue (impact-juice spec). Every device call here is
# fire-and-forget: JuiceBus never blocks a frame or gates a state transition on
# a device call (system-analysis component contract) -- a phone with no
# vibrator, or one that is muted, must get the same clash on the same schedule.
#
# No latency compensation: Godot's Android audio driver does not implement
# AudioServer.get_output_latency() and returns 0 regardless of the hardware
# (godotengine/godot#35509), so a compensation built on it subtracts zero while
# logging a number that looks like a pass. Sound and haptic both fire on the
# `impact` cue itself; fire_impact() owns the freeze end to end and the caller
# awaits it, so the next beat (recoil) naturally begins once hitstop releases.

const HITSTOP_SEC := 0.09
const SHAKE_AMPLITUDE := 10.0
const SHAKE_STEPS := 5
const SHAKE_STEP_SEC := 0.032
const BURST_SCALE_SEC := 0.12
const BURST_GROWN := Vector2(1.0, 1.0)
const BURST_AIMED_GROWN := Vector2(1.3, 0.62)
const HAPTIC_MS := 60
const WARM_VOLUME_DB := -80.0

# Node references, not @export: a hand-written NodePath value in a .tscn
# (`stage = NodePath("../Frame/Mask/Stage")`) never resolves to the actual Node
# at runtime -- that auto-conversion only happens for values the Godot editor
# itself wrote through its node-picker UI, not for text typed straight into the
# scene file. duel_panel.tscn's JuiceBus node was wired that way and every one
# of these four properties silently stayed null: _burst() and _shake() both
# guard on `if not burst/stage: return` and were no-ops on every clash, and
# fire_impact()'s `if impact_player: impact_player.play()` never actually
# played the crunch (sfx_delta_ms was still ~0 because that timing math runs
# whether or not .play() actually fired -- it is not proof the sound played).
# Resolved by path instead, the same way every other cross-node reference in
# this codebase already works (character_rig.gd's %Head, duel_panel.gd's own
# $Frame/Mask/Stage).
@onready var stage: Control = get_node("../Frame/Mask/Stage")
@onready var burst: Sprite2D = get_node("../Frame/Mask/Stage/Burst")
@onready var swing_player: AudioStreamPlayer = $SwingPlayer
@onready var impact_player: AudioStreamPlayer = $ImpactPlayer

var _shake_tween: Tween
var _burst_tween: Tween
var _freeze_released := false


func play_swing() -> void:
	if swing_player:
		swing_player.play()


# Call this exactly on the impact cue. Fires sound, haptic, shake and burst
# together, then awaits the freeze it starts, so the caller's next beat
# (recoil) naturally begins once hitstop releases. Returns cue->dispatch
# deltas for the debug overlay -- dispatch times only, no budget attached
# (criterion 3 was dropped; see the header comment).
#
# `burst_angle` and `hitstop_sec` are how a clash gives its hit its own weight
# without this bus growing a table of clash names: the caller passes what it
# wants, HITSTOP_SEC is only the default. Leaving burst_angle unset keeps the
# original random-angle round pop.
func fire_impact(local_pos: Vector2, burst_angle := NAN,
		hitstop_sec := HITSTOP_SEC) -> Dictionary:
	var cue_usec := Time.get_ticks_usec()
	_shake()
	_burst(local_pos, burst_angle)
	if impact_player:
		impact_player.play()
	var sfx_delta_ms := (Time.get_ticks_usec() - cue_usec) / 1000.0
	Input.vibrate_handheld(HAPTIC_MS)
	var haptic_delta_ms := (Time.get_ticks_usec() - cue_usec) / 1000.0
	await _freeze(hitstop_sec)
	return {
		"sfx_delta_ms": sfx_delta_ms,
		"haptic_delta_ms": haptic_delta_ms,
	}


# Freeze via Engine.time_scale, released by polling the frame signal rather than
# by a timer. A timer created with the default (scaled) settings never fires at
# time_scale 0, and the unscaled one that replaced it could not be cut short --
# a skip landing inside the hitstop then held input for up to HITSTOP_SEC after
# the panel had already closed. Frames are emitted whatever the time scale is,
# and a timer only ever fired on a frame boundary anyway, so the granularity is
# unchanged.
func _freeze(hitstop_sec := HITSTOP_SEC) -> void:
	Engine.time_scale = 0.0
	_freeze_released = false
	var until_usec := Time.get_ticks_usec() + int(hitstop_sec * 1_000_000.0)
	while not _freeze_released and Time.get_ticks_usec() < until_usec:
		await get_tree().process_frame
	_freeze_released = false
	Engine.time_scale = 1.0


# Everything this bus can leave running, stopped. Called from the panel's stage
# reset, so a clash finished early cannot bleed a shake, a burst or a stopped
# clock into the next one. Idempotent, and safe when nothing is running.
func cancel() -> void:
	_freeze_released = true
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	if _burst_tween and _burst_tween.is_valid():
		_burst_tween.kill()
	Engine.time_scale = 1.0


# Shakes `stage`, never `Frame` or `Mask` -- those define the wipe's clip rect,
# and moving them reveals the board at the panel edges. Runs on real time
# (ignores time_scale) so the shake reads through the freeze rather than
# freezing with it.
func _shake() -> void:
	if not stage:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.set_ignore_time_scale(true)
	for i in SHAKE_STEPS:
		var amp := SHAKE_AMPLITUDE * (1.0 - float(i) / SHAKE_STEPS)
		var offset := Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		_shake_tween.tween_property(stage, "position", offset, SHAKE_STEP_SEC)
	_shake_tween.tween_property(stage, "position", Vector2.ZERO, SHAKE_STEP_SEC)


# The star is radially symmetric, so an angle on its own would not read. An
# aimed burst is therefore also an elongated one: it grows along the strike axis
# and stays thin across it, which is what makes a hit that came down from above
# look different from one that came in flat. Unaimed (burst_angle unset) keeps
# the round pop the charge has always had.
func _burst(local_pos: Vector2, burst_angle := NAN) -> void:
	if not burst:
		return
	if _burst_tween and _burst_tween.is_valid():
		_burst_tween.kill()
	var aimed := not is_nan(burst_angle)
	burst.position = local_pos
	burst.rotation = burst_angle if aimed else randf_range(0.0, TAU)
	burst.scale = Vector2(0.4, 0.4)
	burst.modulate.a = 1.0
	_burst_tween = create_tween()
	_burst_tween.set_parallel(true)
	_burst_tween.tween_property(burst, "scale",
			BURST_AIMED_GROWN if aimed else BURST_GROWN, BURST_SCALE_SEC) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_burst_tween.tween_property(burst, "modulate:a", 0.0, BURST_SCALE_SEC) \
		.set_delay(BURST_SCALE_SEC * 0.3)


# Failure mode 4: pay first-play decode/allocate costs (burst texture upload,
# both audio streams) at boot, not on the player's first clash. Leaves the
# burst drawn at negligible scale and alpha for the two frames duel_panel's
# own _warm() awaits while the whole panel is at modulate.a=0; close_now()
# resets it to fully hidden afterwards.
func warm() -> void:
	if burst:
		burst.visible = true
		burst.scale = Vector2(0.02, 0.02)
		burst.modulate.a = 0.02
	for player: AudioStreamPlayer in [swing_player, impact_player]:
		if not player:
			continue
		var db: float = player.volume_db
		player.volume_db = WARM_VOLUME_DB
		player.play()
		player.stop()
		player.volume_db = db
