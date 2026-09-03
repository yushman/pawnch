extends SceneTree

# What this measures: for every frame of every clash, the alpha bounding box of
# each figure -- White and Black -- in Mask coordinates, i.e. the 1240x1080 panel
# the player actually sees (read off DuelPanel.PANEL_SIZE below, never restated
# here). It prints the worst edge either figure reaches on **both** axes, how
# far past the panel that is, and the same extents as offsets from that figure's
# own **home** divided by the mount scale, so they stay usable after a restage.
# Exit code is 0 only if nothing left the panel.
#
# Both axes, since Day 8's landscape flip. In portrait the panel was 1500 px tall
# against 1080 wide and nothing a clash did came near the top; x was the only
# axis worth reporting and this tool only reported x. Landscape swaps that: the
# panel is 1080 tall, the pounce lifts the attacker most of a figure's height off
# the floor, and height is now the constraint the mount scale is derived from
# (see THE STAGE in scripts/duel_panel.gd). A tool that measures the axis that
# stopped binding and not the one that started is the same class of blindness it
# was written to fix.
#
# The unit columns are **home-relative**, not pose-relative: `unit_u` is how far
# above its own rest position a figure reaches, in rig units, staging travel
# included. That is deliberately the number the derivation needs -- every
# staging constant scales with the mount scale, so these stay true across a
# restage and `(unit_u + unit_d) * s <= panel height` is the whole vertical
# constraint in one line.
#
#   godot --script tools/measure_stage_bounds.gd            # add --verbose for per-frame
#
# Why it exists. On Day 8 both figures were clipped by the panel edges standing
# still, and the valkyrie's defeat pose ran 231 px past the left edge -- for six
# days, in every clash -- and the suite was green the whole time. Nothing in
# tests/suite.gd can see this: every staging check there pins one staging number
# against another, and the numbers were consistently wrong together.
# tests/render_clash_frames.gd shows it, but only to a person who looks at the
# strip. This is what turns "is anything clipped" into a number, so run it
# whenever a staging constant, a mount scale or a home position moves.
#
# It is a tool rather than a suite check because it costs ~40s on top of a ~52s
# suite, not because it cannot run in CI: it reads each sprite's texture rather
# than the framebuffer, so unlike tests/render_clash_frames.gd it does **not**
# need a real window and runs fine under --headless. Promoting it to a check is
# a decision about suite time, and it has not been taken.
#
# The box is the sprite's own alpha, pushed through that sprite's global
# transform, and it therefore reports where a figure *is* even where the Mask has
# already clipped it away -- which is the entire point. Per-row extremes rather
# than a corner box: x is affine in (x, y), so the extreme x over a whole alpha
# mask is always attained on one of the per-row extreme pixels, and a corner box
# would have inflated a 0.26rad lean or a lying pose by up to 40%. Measuring the
# old staging that way put the valkyrie's defeat at 572 px instead of its real
# 483, which is a different answer to "how much smaller does this have to get".
#
# Two things are deliberately not counted in the figure rows. Detach duplicates:
# the flying skull is *meant* to leave frame, and counting it against the panel
# edge would report the torso's crest twice. SlashFX: a swing smear is not a
# figure, and a smear caught by the edge is not the failure this measures. Flip
# the `false` in the _bbox() call to include it; at the current staging that was
# checked and it fits too, the worst case being the black pounce's smear reaching
# 805 rig units left of its root against the sword's own 724.
#
#   godot --headless --script tools/measure_stage_bounds.gd -- --detach
#
# --detach measures the flying skull instead, and it is a *different* question
# with a different pass condition: the duplicates are allowed -- required -- to
# leave the panel, so what is checked is that they are already invisible when
# they do. Three numbers per clash whose defender is black:
#
#   grow    the group's alpha box at its widest, over its box at spawn. The
#           duplicates take the original's global transform and nothing tweens
#           scale, so anything but ~1.00 means the skull really is growing.
#   spread  how far the three duplicates' centres drift apart, in panel px,
#           over their separation at spawn. Head, Face and Crest are one rigid
#           object; anything but ~0 is the crest coming off the skull.
#   edge_a  the group's alpha at the first frame any part of it crosses a panel
#           edge, i.e. the moment the Mask starts cutting it. This is the one
#           with a pass condition: it must be 0.
#
# Exit code stays "did a figure leave the panel"; the detach rows carry their own
# OK/BAD on edge_a and are reported, not folded into it, because a skull that
# fades late is a different defect from a figure that is clipped standing still.

## Read off the panel rather than restated here: a tool that carries its own
## copy of the panel size reports "OK" against the wrong rectangle the first
## time the panel is recomposed, which is exactly when it is being run.
const PANEL := DuelPanel.PANEL_SIZE

const CLASHES := [
	# label, defender-is, fen ("" = start position), moves
	["pounce-white", "black", "", ["e2e4", "d7d5", "e4d5"]],
	["charge-white", "black", "", ["g1f3", "e7e5", "f3e5"]],
	["pounce-black", "white", "4k3/8/8/3p4/4P3/8/8/4K3 b - - 0 1", ["d5e4"]],
	# Not in the strip set, and measured anyway: a black knight charges in a real
	# game, and leftward travel is where a clash authored for white shows itself.
	["charge-black", "white", "4k3/8/3n4/8/4P3/8/8/4K3 b - - 0 1", ["d6e4"]],
	["strike-white", "black", "", ["e2e4", "d7d5", "f1b5", "c7c6", "b5c6"]],
	["strike-black", "white", "4k3/8/2b5/8/4P3/8/8/4K3 b - - 0 1", ["c6e4"]],
]

var _bbox_cache := {}
var _verbose := false
var _detach := false


func _initialize() -> void:
	_verbose = OS.get_cmdline_user_args().has("--verbose")
	_detach = OS.get_cmdline_user_args().has("--detach")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var session: GameSession = main.get_node("Session")
	session.bot = null  # its reply would be a second clash inside the sweep
	var panel: Node = main.get_node("DuelPanel")
	var mask: Control = panel.get_node("Frame/Mask")
	var rigs := {
		"white": panel.get_node("Frame/Mask/Stage/White") as Node2D,
		"black": panel.get_node("Frame/Mask/Stage/Black") as Node2D,
	}
	print("PAWNCH_BOUNDS scale=%s homes=white:%s black:%s" % [
		rigs["white"].scale, rigs["white"].position, rigs["black"].position])

	var clipped := 0
	for row in CLASHES:
		clipped += await _run(session, panel, mask, rigs, row[0], row[1], row[2], row[3])
	print("PAWNCH_BOUNDS %s clipped_clashes=%d" % [
		"OK" if clipped == 0 else "CLIPPED", clipped])
	quit(0 if clipped == 0 else 1)


func _run(session: GameSession, panel: Node, mask: Control, rigs: Dictionary,
		label: String, defender: String, fen: String, moves: Array) -> int:
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

	# The rest transform, captured before the clash moves anything: every unit
	# column below is measured from here rather than from the rig's live
	# transform, because the home and the mount scale are what a restage
	# re-derives. Dividing by the live `scale.x` -- which is what this did until
	# Day 8 -- divides by whatever the squash happens to be on that frame, so
	# POUNCE_STRETCH's 0.80 reported the pounce 25% further out than it goes.
	var homes := {}
	var mounts := {}
	for side: String in rigs:
		homes[side] = (rigs[side] as Node2D).position
		mounts[side] = absf((rigs[side] as Node2D).scale.x)

	var start := Time.get_ticks_usec()
	session.play_move(moves[-1], start)
	# worst[side]["l"|"r"|"t"|"b"] = [edge, t, sprite]; ["u"] = home-relative units
	var worst := {}
	for side in rigs:
		worst[side] = {
			"l": [INF, 0.0, "?"], "r": [-INF, 0.0, "?"],
			"t": [INF, 0.0, "?"], "b": [-INF, 0.0, "?"],
			"u": [INF, -INF, INF, -INF],
		}
	# The flying skull, when there is one. Sampled outside the mask gate below:
	# the duplicates are measured against the panel rectangle itself, and the
	# question is when they cross it, which is exactly the frames that gate drops.
	var det := {
		"spawn": Rect2(), "spawn_spread": -1.0, "grow": 0.0, "spread": 0.0,
		"edge_t": -1.0, "edge_a": -1.0, "gone_t": -1.0,
		"lit": [INF, -INF, INF, -INF],
	}
	while panel.is_clashing():
		await process_frame
		var t := (Time.get_ticks_usec() - start) / 1_000_000.0
		if _detach and defender == "black":
			# Off the stage, not off the rig: the flight is parented to the stage
			# so the body's knockback cannot drag it (CharacterRig.detach_head).
			_sample_detach(rigs["black"].get_parent(), mask, det, t)
		# Only while the panel is fully open. The wipe-in and the wipe-out narrow
		# the Mask on purpose, so a figure outside it during those is clipped by
		# the transition rather than by the staging, and counting it would report
		# a failure on every clash forever.
		if mask.size.x < PANEL.x:
			continue
		for side: String in rigs:
			var rig: Node2D = rigs[side]
			var names := {}
			var r: Variant = _bbox(rig, mask, false, names)
			if r == null:
				continue
			var rect: Rect2 = r
			var w: Dictionary = worst[side]
			_worst(w["l"], rect.position.x, true, t, names.get("left", "?"))
			_worst(w["r"], rect.end.x, false, t, names.get("right", "?"))
			_worst(w["t"], rect.position.y, true, t, names.get("top", "?"))
			_worst(w["b"], rect.end.y, false, t, names.get("bottom", "?"))
			var unit: float = mounts[side]
			var home: Vector2 = homes[side]
			var u: Array = w["u"]
			u[0] = minf(u[0], (rect.position.x - home.x) / unit)
			u[1] = maxf(u[1], (rect.end.x - home.x) / unit)
			u[2] = minf(u[2], (rect.position.y - home.y) / unit)
			u[3] = maxf(u[3], (rect.end.y - home.y) / unit)
			if _verbose:
				print("  %s %s t=%.3f root=%s box=%.1f,%.1f %.1fx%.1f" % [
					label, side, t, rig.position, rect.position.x, rect.position.y,
					rect.size.x, rect.size.y])

	var bad := 0
	for side: String in rigs:
		var w: Dictionary = worst[side]
		var role := "defender" if side == defender else "attacker"
		var over_l: float = maxf(0.0, -w["l"][0])
		var over_r: float = maxf(0.0, w["r"][0] - PANEL.x)
		var over_t: float = maxf(0.0, -w["t"][0])
		var over_b: float = maxf(0.0, w["b"][0] - PANEL.y)
		if over_l > 0.0 or over_r > 0.0 or over_t > 0.0 or over_b > 0.0:
			bad = 1
		var u: Array = w["u"]
		print("%-13s %-5s %-8s l=%7.1f(%.2f %s) r=%7.1f(%.2f %s) t=%7.1f(%.2f %s) b=%7.1f(%.2f %s)  over l=%5.1f r=%5.1f t=%5.1f b=%5.1f  unit l=%7.1f r=%7.1f u=%7.1f d=%7.1f" % [
			label, side, role,
			w["l"][0], w["l"][1], w["l"][2], w["r"][0], w["r"][1], w["r"][2],
			w["t"][0], w["t"][1], w["t"][2], w["b"][0], w["b"][1], w["b"][2],
			over_l, over_r, over_t, over_b, u[0], u[1], u[2], u[3]])
	if _detach and defender == "black":
		if det["spawn_spread"] < 0.0:
			print("%-13s detach  NONE (no duplicates were ever visible)" % label)
		else:
			var lit: Array = det["lit"]
			print("%-13s detach  %s  grow=%.2f spread=%5.1fpx edge_t=%6.3f edge_a=%.2f gone_t=%.3f  spawn=%.0f,%.0f %.0fx%.0f  lit l=%6.1f r=%6.1f t=%6.1f b=%6.1f" % [
				label, "OK " if det["edge_a"] <= 0.0 else "BAD",
				det["grow"], det["spread"], det["edge_t"], det["edge_a"],
				det["gone_t"], det["spawn"].position.x, det["spawn"].position.y,
				det["spawn"].size.x, det["spawn"].size.y,
				lit[0], lit[1], lit[2], lit[3]])
	return bad


# One frame of the flying skull: the group's alpha box in Mask coordinates, how
# far its three parts have drifted apart, and the alpha it is carrying when it
# first touches a panel edge. Everything is folded into `det` as a running worst.
func _sample_detach(host: Node, mask: Control, det: Dictionary, t: float) -> void:
	var inv := mask.get_global_transform().affine_inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var centres: Array[Vector2] = []
	var alpha := 0.0
	for s: Sprite2D in _sprites(host):
		if not String(s.name).ends_with("Duplicate") or s.texture == null:
			continue
		if not s.is_visible_in_tree():
			continue
		var prof := _profile(s.texture)
		if prof.is_empty():
			continue
		var xf: Transform2D = inv * s.get_global_transform()
		var slo := Vector2(INF, INF)
		var shi := Vector2(-INF, -INF)
		for pt: Vector2 in prof:
			var p := xf * (pt + s.offset)
			slo = slo.min(p)
			shi = shi.max(p)
		lo = lo.min(slo)
		hi = hi.max(shi)
		centres.append((slo + shi) * 0.5)
		alpha = maxf(alpha, _alpha_to(s, host))
	if centres.is_empty():
		return
	# Widest gap between any two of the three parts. Rigid means this never moves
	# off its value at spawn; the Day-5 defect is it growing without bound.
	var spread := 0.0
	for a in centres:
		for b in centres:
			spread = maxf(spread, a.distance_to(b))
	var box := Rect2(lo, hi - lo)
	if det["spawn_spread"] < 0.0:
		det["spawn"] = box
		det["spawn_spread"] = spread
	det["grow"] = maxf(det["grow"], maxf(
		box.size.x / maxf(1.0, det["spawn"].size.x),
		box.size.y / maxf(1.0, det["spawn"].size.y)))
	det["spread"] = maxf(det["spread"], spread - float(det["spawn_spread"]))
	# Only frames the player can still see: an extent reached at alpha 0 is not
	# a thing that happened on screen.
	if alpha > 0.001:
		var lit: Array = det["lit"]
		lit[0] = minf(lit[0], lo.x)
		lit[1] = maxf(lit[1], hi.x)
		lit[2] = minf(lit[2], lo.y)
		lit[3] = maxf(lit[3], hi.y)
	var out := lo.x < 0.0 or lo.y < 0.0 or hi.x > PANEL.x or hi.y > PANEL.y
	if out and det["edge_t"] < 0.0:
		det["edge_t"] = t
		det["edge_a"] = alpha
	if alpha <= 0.001 and det["gone_t"] < 0.0:
		det["gone_t"] = t


## Effective modulate alpha of `node` as seen under `stop`, i.e. every modulate
## between the sprite and the rig multiplied together. A group that fades by
## fading its container has no alpha on the sprite at all.
func _alpha_to(node: CanvasItem, stop: Node) -> float:
	var a := 1.0
	var n: Node = node
	while n != null and n != stop:
		if n is CanvasItem:
			a *= (n as CanvasItem).modulate.a * (n as CanvasItem).self_modulate.a
		n = n.get_parent()
	return a


# One extreme, with the time and the sprite that reached it.
func _worst(slot: Array, value: float, want_min: bool, t: float, sprite: String) -> void:
	if (value < slot[0]) if want_min else (value > slot[0]):
		slot[0] = value
		slot[1] = t
		slot[2] = sprite


func _bbox(rig: Node2D, mask: Control, include_fx := false, out_names := {}) -> Variant:
	var inv := mask.get_global_transform().affine_inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var found := false
	for s: Sprite2D in _sprites(rig):
		if not s.is_visible_in_tree() or s.modulate.a < 0.02 or s.self_modulate.a < 0.02:
			continue
		if s.name.ends_with("Duplicate"):
			continue
		if s.name == "SlashFX" and not include_fx:
			continue
		if s.texture == null:
			continue
		var prof := _profile(s.texture)
		if prof.is_empty():
			continue
		var xf: Transform2D = inv * s.get_global_transform()
		var off := s.offset
		for pt: Vector2 in prof:
			var p := xf * (pt + off)
			if p.x < lo.x:
				lo.x = p.x
				out_names["left"] = s.name
			if p.x > hi.x:
				hi.x = p.x
				out_names["right"] = s.name
			if p.y < lo.y:
				lo.y = p.y
				out_names["top"] = s.name
			if p.y > hi.y:
				hi.y = p.y
				out_names["bottom"] = s.name
			found = true
	if not found:
		return null
	return Rect2(lo, hi - lo)


func _sprites(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is Sprite2D:
			out.append(c)
		out.append_array(_sprites(c))
	return out


## The silhouette's four profiles: the leftmost and rightmost opaque pixel of
## every row, and the topmost and bottommost of every column. Rotating a corner
## box inflates it by up to 41%; these points are the real alpha, so a lean or a
## lying pose is measured for what it covers rather than for the box it is drawn
## in.
##
## Both profiles rather than the rows alone, because both axes are now reported.
## A transformed coordinate is affine in (x, y), so the extreme x over a whole
## alpha mask is attained on one of the per-row extreme pixels and the extreme y
## on one of the per-column ones. Every point returned is a real corner of a real
## opaque pixel, so the box can never come out larger than the figure; the two
## profiles only ever meet at half of each pixel's corners, which leaves the
## result short of exact by at most one transformed pixel -- sub-pixel at any
## mount scale this stage will ever use.
func _profile(tex: Texture2D) -> PackedVector2Array:
	var key := tex.resource_path
	if _bbox_cache.has(key):
		return _bbox_cache[key]
	var pts := PackedVector2Array()
	var img := tex.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		for y in h:
			var lo := -1
			var hi := -1
			for x in w:
				if img.get_pixel(x, y).a > 0.1:
					if lo < 0:
						lo = x
					hi = x
			if lo >= 0:
				pts.append(Vector2(lo, y))
				pts.append(Vector2(hi + 1, y))
		for x in w:
			var lo := -1
			var hi := -1
			for y in h:
				if img.get_pixel(x, y).a > 0.1:
					if lo < 0:
						lo = y
					hi = y
			if lo >= 0:
				pts.append(Vector2(x, lo))
				pts.append(Vector2(x, hi + 1))
	_bbox_cache[key] = pts
	return pts
