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
var _draw_calls: Array[float] = []
var _vsync_ms := 16.667

# Per-frame (end_usec, interval_ms) samples for region attribution -- kept
# independent of the periodic window above, which clears every 5s. A region
# that begins and ends inside one 5s window would otherwise be indistinguishable
# from the wipes on either side of it, whose cost is separately known and dirty.
var _samples: Array[Dictionary] = []
var _region_start_usec: Dictionary = {}


func _ready() -> void:
	var hz := DisplayServer.screen_get_refresh_rate()
	if hz > 0.0:
		_vsync_ms = 1000.0 / hz
	_last_usec = Time.get_ticks_usec()
	_window_start_usec = _last_usec


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var interval_ms := (now - _last_usec) / 1000.0
	_intervals.append(interval_ms)
	_busy.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_samples.append({"t": now, "ms": interval_ms})
	_last_usec = now

	if now - _window_start_usec < int(REPORT_INTERVAL_SEC * 1_000_000):
		return
	_report()
	_intervals.clear()
	_busy.clear()
	_window_start_usec = now


# Marks the start of a named region (e.g. "clash") on the same clock as the
# per-frame samples above. Call again with the same name to move the start
# forward (e.g. a re-triggered clash before the previous one's end was marked).
func mark_region_start(region_name: String) -> void:
	_region_start_usec[region_name] = Time.get_ticks_usec()


# Reports the region immediately -- not on the next periodic window -- so a
# region entirely inside one 5s window is still reported (see PAWNCH_CLASH
# below). Silently does nothing if mark_region_start() was never called.
func mark_region_end(region_name: String) -> void:
	if not _region_start_usec.has(region_name):
		return
	var start_usec: int = _region_start_usec[region_name]
	var end_usec := Time.get_ticks_usec()
	_region_start_usec.erase(region_name)

	var frames := 0
	var dropped := 0
	var worst := 0.0
	for s in _samples:
		if s["t"] < start_usec or s["t"] > end_usec:
			continue
		frames += 1
		if s["ms"] > _vsync_ms * DROP_THRESHOLD:
			dropped += 1
			worst = maxf(worst, s["ms"])
	print("PAWNCH_CLASH region=%s frames=%d dropped=%d worst_gap=%.1fms" % [
		region_name, frames, dropped, worst,
	])

	# Samples strictly before this region's start cannot belong to any region
	# still open or yet to come; drop them so the array does not grow unbounded
	# over a long measurement session.
	_samples = _samples.filter(func(s): return s["t"] >= start_usec)


func _report() -> void:
	if _intervals.size() < 3:
		return

	# The first interval of a window spans the reporting gap, not a frame.
	var intervals := _intervals.slice(1)
	var busy := _busy.slice(1)
	var draw_calls := _draw_calls.slice(1)

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

	draw_calls.sort()
	print("PAWNCH_FRAME frames=%d fps=%.1f dropped=%d worst_gap=%.1fms@%d busy_p50=%.2f busy_p95=%.2f busy_max=%.2f draw_calls_max=%d vsync=%.2f" % [
		intervals.size(), intervals.size() * 1000.0 / wall_ms,
		dropped, worst_interval, worst_drop_at,
		p.call(0.50), p.call(0.95), busy[-1], int(draw_calls[-1]), _vsync_ms,
	])
