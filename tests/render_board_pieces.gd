extends SceneTree

# Bakes the board's pieces (ADR-0011 decision 3). Thirty-two live rigs is ~350
# draw calls against a ~60 budget, so the board draws single sprites rendered
# out of the same rigs by this script: six frames of `Idle Blinking` per piece
# type per colour, sized to a 135x170 cell with the feet near the bottom.
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

const CELL := Vector2i(135, 170)
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
# came back with it. Above 1.00 a figure crosses into the cell above, and at the
# start position that is a column of eight — the case decision 2 exists to protect.
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
		var rig := _mount(viewport, family)
		for type in TYPES:
			rig.set_piece_type(type)
			for i in FRAMES:
				var img := await _capture(viewport, rig, i)
				img.save_png("%s/%s_%s_%d.png" % [raw_dir, family, type, i])
				var used := img.get_used_rect()
				unions[family] = unions[family].merge(used) if unions.has(family) else used
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
	var s := FIGURE_SCALE * minf(
		float(CELL.x - 2 * SIDE_PAD) / widest,
		float(CELL.y - TOP_PAD - BOTTOM_PAD) / tallest)
	var crop := Vector2i(roundi(CELL.x / s), roundi(CELL.y / s))
	var floor_gap := maxf(BOTTOM_PAD, CELL.y - TOP_PAD - tallest * s)

	var written := 0
	for family in FAMILIES:
		var u: Rect2i = unions[family]
		var origin := Vector2i(
			roundi(u.position.x + u.size.x * 0.5 - crop.x * 0.5),
			roundi(ground + floor_gap / s) - crop.y)
		if want_family != "all" and want_family != family:
			continue
		for type in TYPES:
			if want_type != "all" and want_type != type:
				continue
			for i in FRAMES:
				var src := Image.load_from_file("%s/%s_%s_%d.png" % [raw_dir, family, type, i])
				var cell := Image.create(crop.x, crop.y, false, src.get_format())
				cell.blit_rect(src, Rect2i(origin, crop), Vector2i.ZERO)
				cell.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
				var path := "%s/%s_%s_%d.png" % [out_dir, family, type, i]
				cell.save_png(path)
				print("PAWNCH_BAKE wrote %s" % path)
				written += 1
	print("PAWNCH_BAKE %d frames, cell=%dx%d scale=%.5f figure=%dx%d floor_gap=%d" % [
		written, CELL.x, CELL.y, s, roundi(widest * s), roundi(tallest * s), roundi(floor_gap)])
	quit(0)


func _mount(viewport: SubViewport, family: String) -> CharacterRig:
	var rig: CharacterRig = (load(FAMILIES[family]["scene"]) as PackedScene).instantiate()
	# The pack's own `Idle Blinking` keys the sword's alpha to 0 on its first key,
	# so the weapon is hidden in this animation whatever the flag says. Setting it
	# explicitly makes that the same on every frame instead of leaking a visible
	# sword into whichever capture happens before the mixer's first apply. On the
	# board the identity carrier is the head crest (ADR-0011 decision 4); the
	# weapon is a duel-panel affordance, and at cell scale it is a thin diagonal
	# bar that costs 30% of every figure's size.
	rig.show_idle_weapon = false
	rig.position = ROOT_AT
	rig.scale = Vector2(-REF_SCALE if FAMILIES[family]["mirror"] else REF_SCALE, REF_SCALE)
	viewport.add_child(rig)
	var player: AnimationPlayer = rig.get_node("AnimationPlayer")
	# Same reason as tests/render_rig_frames.gd: without manual callbacks the
	# mixer advances a frame delta between seek() and the capture.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play(ANIM)
	return rig


func _capture(viewport: SubViewport, rig: CharacterRig, index: int) -> Image:
	var player: AnimationPlayer = rig.get_node("AnimationPlayer")
	var length := player.get_animation(ANIM).length
	player.seek(index * length / FRAMES, true, true)
	await process_frame
	await process_frame
	return viewport.get_texture().get_image()
