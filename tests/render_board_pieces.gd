extends SceneTree

# Bakes the board's pieces (ADR-0011 decision 3). Thirty-two live rigs is ~350
# draw calls against a ~60 budget, so the board draws single sprites rendered
# out of the same rigs by this script: six frames of `Idle Blinking` per piece
# type per colour, sized to a 135x135 cell with the feet near the bottom.
#
# Modelled on tests/render_rig_frames.gd, and it inherits that script's
# constraint: `--headless` installs the dummy rendering server and
# `Viewport.get_texture()` returns null under it, so this needs a real window on
# the Compatibility/OpenGL renderer the game ships with.
#
#   godot --rendering-driver opengl3 --script tests/render_board_pieces.gd -- <out_dir> [type] [family]
#
# `type` and `family` filter what is *written*; the measuring pass always covers
# all 72 frames, so a one-type run and a full run produce identical files. Run
# through tools/bake_board_atlas.py.
#
# It writes three things, all cropped out of the same captures and therefore all
# in register with each other:
#
#   72 figure frames   six per type per colour, at cell size.
#   12 crest frames    the same crop with everything but %Crest hidden. The
#                      graveyard draws the body dimmed and the crest over it at
#                      full colour, and it can only do that if the crest is a
#                      separate quad -- on the board the crest is baked into the
#                      figure, and dimming the figure would take the one channel
#                      that says which piece has been lost with it.
#
# The two margin commanders are *not* rendered here. They are different
# characters from different packs, and one still frame each is all they need, so
# tools/bake_board_atlas.py lifts them straight out of the pack .zip -- no rig,
# no second importer (ADR-0009).

const CELL := Vector2i(135, 135)
const FRAMES := 6
const ANIM := "Idle Blinking"

# Big enough that no pose, crest or weapon touches an edge; the figure is cropped
# out of it afterwards, so the only cost of slack is temp-file size.
const CANVAS := Vector2i(1400, 1500)
const ROOT_AT := Vector2(700, 1330)
const REF_SCALE := 0.75

# Breathing room inside the cell, in final pixels.
const SIDE_PAD := 3
const TOP_PAD := 2
const BOTTOM_PAD := 6

# The figure fills the cell (ADR-0011 decision 2). It was 0.80 for one afternoon,
# to open a band under the feet for a tile glyph; the glyph was dropped because it
# never separated the king from the queen, and the fifth of the figure it cost
# came back with it.
#
# The cell went 135x170 -> 135x135 on Day 8 and **this bake did not change size**,
# because the fit takes the smaller of the two axes and width has been the binding
# one since the weapon went on the board: (135 - 2*3)/922 = 0.1399 against
# (135 - 2 - 6)/841 = 0.1510. The figure is 129x118 either way. What the shorter
# cell changes is the slack under the feet, 50 px -> 15, and therefore the gap
# between adjacent ranks -- which is the measurement ADR-0011 decision 2 turns on.
const FIGURE_SCALE := 1.00

const TYPES := ["pawn", "knight", "bishop", "rook", "queen", "king"]
# ADR-0011 decision 5: white is always drawn unflipped on the left, black always
# mirrored on the right, so the two face each other. The flip is baked in here.
const FAMILIES := {
	"valkyrie": {"scene": "res://scenes/character_rig_valkyrie.tscn", "mirror": false},
	"skeleton_warrior": {"scene": "res://scenes/character_rig_skeleton_warrior.tscn", "mirror": true},
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "/tmp/pawnch_board"
	var want_type: String = args[1] if args.size() > 1 else "all"
	var want_family: String = args[2] if args.size() > 2 else "all"
	var raw_dir := out_dir.path_join("_raw")
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.make_dir_recursive_absolute(raw_dir)

	var viewport := SubViewport.new()
	viewport.size = CANVAS
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	# One measuring pass over every variant, whatever the filters ask for, so a
	# one-type run writes the same bytes a full run does. The union is kept per
	# family: the scale and the ground line are then global — a king is not
	# silently smaller than a pawn because its crest is taller — while the
	# horizontal centring is each family's own, because the mirrored skeleton's
	# art sits on the other side of the rig root and a shared centre would push
	# every white figure against the left wall of its cell.
	var unions := {}
	for family in FAMILIES:
		var rig: CharacterRig = await _mount(viewport, family)
		for type in TYPES:
			rig.set_piece_type(type)
			for i in FRAMES:
				var img := await _capture(viewport, rig, i)
				img.save_png("%s/%s_%s_%d.png" % [raw_dir, family, type, i])
				var used := img.get_used_rect()
				unions[family] = unions[family].merge(used) if unions.has(family) else used
			# The crest on its own, from the same pose and the same viewport, so
			# it lands exactly where it does inside the figure frame. Deliberately
			# not merged into the union: it is a subset of frame 0 and counting it
			# could only ever leave the union unchanged, but saying so is cheaper
			# than someone re-deriving it.
			var crest := await _capture_crest(viewport, rig)
			crest.save_png("%s/%s_%s_crest.png" % [raw_dir, family, type])
		rig.queue_free()

	var widest := 0
	var tallest := 0
	var ground := 0
	for family in unions:
		var u: Rect2i = unions[family]
		print("PAWNCH_BAKE union %s = %d,%d %dx%d (canvas %dx%d)" % [
			family, u.position.x, u.position.y, u.size.x, u.size.y, CANVAS.x, CANVAS.y])
		if u.position.x <= 0 or u.position.y <= 0 or u.end.x >= CANVAS.x or u.end.y >= CANVAS.y:
			push_error("PAWNCH_BAKE figure touches the canvas edge — raise CANVAS or lower REF_SCALE")
			quit(1)
			return
		widest = maxi(widest, u.size.x)
		tallest = maxi(tallest, u.size.y)
		ground = maxi(ground, u.end.y)

	# Final pixels per source pixel, then the crop window that puts the figure's
	# width centred in the cell and whatever slack is left under its feet. Slack
	# above the head buys nothing: the figure never overhangs its own cell, so
	# nothing is ever drawn there.
	var fit := _fit(CELL, widest, tallest)
	var s: float = fit["scale"]
	var crop: Vector2i = fit["crop"]

	var written := 0
	for family in FAMILIES:
		var u: Rect2i = unions[family]
		var origin := _origin(u, ground, fit)
		if want_family != "all" and want_family != family:
			continue
		for type in TYPES:
			if want_type != "all" and want_type != type:
				continue
			for i in FRAMES:
				_crop_to("%s/%s_%s_%d.png" % [raw_dir, family, type, i],
					"%s/%s_%s_%d.png" % [out_dir, family, type, i], origin, crop, CELL)
				written += 1
			_crop_to("%s/%s_%s_crest.png" % [raw_dir, family, type],
				"%s/%s_%s_crest.png" % [out_dir, family, type], origin, crop, CELL)
			print("PAWNCH_BAKE crest %s_%s" % [family, type])

	print("PAWNCH_BAKE %d frames, cell=%dx%d scale=%.5f figure=%dx%d floor_gap=%d" % [
		written, CELL.x, CELL.y, s, roundi(widest * s), roundi(tallest * s),
		roundi(float(fit["floor_gap"]))])
	quit(0)


# The shared union scaled to whichever axis runs out first, with the padding this
# bake has always used.
func _fit(cell: Vector2i, widest: int, tallest: int) -> Dictionary:
	var s := FIGURE_SCALE * minf(
		float(cell.x - 2 * SIDE_PAD) / widest,
		float(cell.y - TOP_PAD - BOTTOM_PAD) / tallest)
	return {
		"scale": s,
		"crop": Vector2i(roundi(cell.x / s), roundi(cell.y / s)),
		"floor_gap": maxf(BOTTOM_PAD, cell.y - TOP_PAD - tallest * s),
	}


func _origin(u: Rect2i, ground: int, fit: Dictionary) -> Vector2i:
	var crop: Vector2i = fit["crop"]
	return Vector2i(
		roundi(u.position.x + u.size.x * 0.5 - crop.x * 0.5),
		roundi(ground + float(fit["floor_gap"]) / float(fit["scale"])) - crop.y)


func _crop_to(src_path: String, out_path: String, origin: Vector2i, crop: Vector2i,
		cell: Vector2i) -> void:
	var src := Image.load_from_file(src_path)
	var cut := Image.create(crop.x, crop.y, false, src.get_format())
	cut.blit_rect(src, Rect2i(origin, crop), Vector2i.ZERO)
	cut.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
	cut.save_png(out_path)
	print("PAWNCH_BAKE wrote %s" % out_path)


func _mount(viewport: SubViewport, family: String) -> CharacterRig:
	var rig: CharacterRig = (load(FAMILIES[family]["scene"]) as PackedScene).instantiate()
	# The board shows the weapon (ADR-0011 decision 4, reversed 2026-08-20). It was
	# hidden here for as long as the crest was the board's only type channel, on the
	# arithmetic that the weapon widens the shared union by ~30% and therefore
	# shrinks all twelve figures by that much for a bar nobody can read. What that
	# arithmetic left out is that the six heads are identical -- 0.98..1.00 pairwise
	# IoU filled black, pawn and knight exactly 1.0000 -- so the price bought the
	# board a *single* type channel, and a person shown the board named the problem
	# in one second: "all the pieces are the same". The weapons do differ in
	# outline, which is the channel that survives at this size, and the crest grew
	# 18% -> 25% of character height in the same pass to pay for the shrink.
	rig.show_idle_weapon = true
	rig.position = ROOT_AT
	rig.scale = Vector2(-REF_SCALE if FAMILIES[family]["mirror"] else REF_SCALE, REF_SCALE)
	viewport.add_child(rig)
	var player: AnimationPlayer = rig.get_node("AnimationPlayer")
	# Same reason as tests/render_rig_frames.gd: without manual callbacks the
	# mixer advances a frame delta between seek() and the capture.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play(ANIM)
	# Touch all six weapons once before anything is measured. `set_piece_type()`
	# resolves the per-type weapon with `load()`, and the first use of each of the
	# six is a disk read plus a texture upload; paying for them here rather than
	# inside the capture loop is what makes this script deterministic. Without it
	# two runs disagreed about the union bounding box by 100 px and one of them
	# wrote a frame that still held the *previous* piece type's crest.
	for type in TYPES:
		rig.set_piece_type(type)
		await process_frame
	return rig


# Frame 0 with everything but the crest hidden. Visibility is put back before
# returning, because the same rig goes straight on to the next piece type.
func _capture_crest(viewport: SubViewport, rig: CharacterRig) -> Image:
	var hidden: Array[Sprite2D] = []
	var crest: Sprite2D = rig.get_node("%Crest")
	for sprite in _sprites(rig):
		if sprite != crest and sprite.visible:
			sprite.visible = false
			hidden.append(sprite)
	var img := await _capture(viewport, rig, 0)
	for sprite in hidden:
		sprite.visible = true
	return img


func _sprites(n: Node) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for c in n.get_children():
		if c is Sprite2D:
			out.append(c)
		out.append_array(_sprites(c))
	return out


func _capture(viewport: SubViewport, rig: CharacterRig, index: int) -> Image:
	var player: AnimationPlayer = rig.get_node("AnimationPlayer")
	var length := player.get_animation(ANIM).length
	player.seek(index * length / FRAMES, true, true)
	# `Idle Blinking` keys the sword's alpha to 0 on its first key, so the flag on
	# the rig is not enough on its own: the alpha has to be forced open *after* the
	# seek has applied the track. Same thing tests/render_legibility.gd does, and
	# the same thing ADR-0007 decision 8 had to do to run its own silhouette test.
	(rig.get_node("%Sword") as Sprite2D).modulate.a = 1.0
	await process_frame
	await process_frame
	# The two frames above are the scene tree catching up; this one is the GPU.
	# `get_image()` reads whatever was last drawn into the render target, and
	# without waiting for the draw that follows the second frame it can hand back
	# the previous capture -- which is exactly how a king ended up wearing the
	# queen's crest, byte-identical to the frame before it.
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
