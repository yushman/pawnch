extends Node

# In-app frame timing, read off the device with `tools/frametime.sh`.
#
# Godot draws into a SurfaceView, so Android's HWUI counters
# (`dumpsys gfxinfo ... framestats`) never see the render loop, and
# `dumpsys SurfaceFlinger --latency` no longer returns per-frame rows on
# Android 12+. Measuring inside the engine is the only way left to get the
# frame numbers the budgets are written against. See ADR-0006.
#
# Two numbers, because they answer different questions:
#
#   dropped  — intervals longer than 1.5 vsync periods, i.e. a refresh the
#              user waited an extra beat for. This is what "no frame over
#              20 ms" was reaching for. Wall-clock jitter in when _process is
#              scheduled routinely stretches one interval to 22 ms and
#              shortens the next to 8 ms without dropping anything, so a raw
#              interval threshold reports hitches that do not exist.
#   busy     — milliseconds the engine actually spent on the frame, from the
#              engine's own process-time monitor. This is the part we control
#              and the one that will move when the clash lands.

const REPORT_INTERVAL_SEC := 5.0
const DROP_THRESHOLD := 1.5

var _last_usec := 0
var _window_start_usec := 0
var _intervals: Array[float] = []
var _busy: Array[float] = []
var _vsync_ms := 16.667


func _ready() -> void:
	var hz := DisplayServer.screen_get_refresh_rate()
	if hz > 0.0:
		_vsync_ms = 1000.0 / hz
	_last_usec = Time.get_ticks_usec()
	_window_start_usec = _last_usec


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	_intervals.append((now - _last_usec) / 1000.0)
	_busy.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_last_usec = now

	if now - _window_start_usec < int(REPORT_INTERVAL_SEC * 1_000_000):
		return
	_report()
	_intervals.clear()
	_busy.clear()
	_window_start_usec = now


func _report() -> void:
	if _intervals.size() < 3:
		return

	# The first interval of a window spans the reporting gap, not a frame.
	var intervals := _intervals.slice(1)
	var busy := _busy.slice(1)

	var wall_ms := 0.0
	var dropped := 0
	var worst_drop_at := -1
	var worst_interval := 0.0
	for i in intervals.size():
		wall_ms += intervals[i]
		if intervals[i] > _vsync_ms * DROP_THRESHOLD:
			dropped += 1
			if intervals[i] > worst_interval:
				worst_interval = intervals[i]
				worst_drop_at = i

	busy.sort()
	var p := func(q: float) -> float:
		return busy[mini(busy.size() - 1, int(busy.size() * q))]

	print("PAWNCH_FRAME frames=%d fps=%.1f dropped=%d worst_gap=%.1fms@%d busy_p50=%.2f busy_p95=%.2f busy_max=%.2f vsync=%.2f" % [
		intervals.size(), intervals.size() * 1000.0 / wall_ms,
		dropped, worst_interval, worst_drop_at,
		p.call(0.50), p.call(0.95), busy[-1], _vsync_ms,
	])
