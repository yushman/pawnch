extends SceneTree

# Renders the ported rig one frame at a time so tools/verify_rig.py can compare it
# against the Craftpix pack's own rendered PNG sequences. The rig is drawn at
# native .scml scale (1/RASTER) with the origin where the pack puts it, so the
# two images overlay directly and the IoU is a real number, not an alignment
# artefact.
#
# Run through tools/verify_rig.py. `--headless` is not usable here: it installs
# the dummy rendering server, and `Viewport.get_texture()` returns null under it
# (servers/rendering/dummy/storage/texture_storage.h). The run therefore needs a
# real window, on the same Compatibility/OpenGL renderer the game ships with.
#
#   godot --rendering-driver opengl3 --script tests/render_rig_frames.gd -- <out_dir> <rig.tscn>

const CANVAS := 900
const ORIGIN := Vector2(450, 750)
const FRAME_MS := 33.0
# Frame counts are the pack's: PNG Sequences/<name>/ at its 33 ms interval.
const SEQUENCES := {"Idle": 18, "Slashing": 12, "Hurt": 12, "Dying": 15}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "/tmp/pawnch_rig"
	var scene_path: String = args[1] if args.size() > 1 else "res://scenes/character_rig_valkyrie.tscn"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(CANVAS, CANVAS)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var rig: CharacterRig = (load(scene_path) as PackedScene).instantiate()
	rig.show_crest = false
	rig.show_idle_weapon = false
	rig.position = ORIGIN
	# The generator writes the family's raster factor onto the Rig node; undoing it
	# here puts the scene back in native .scml units, where the pack's own frames are.
	rig.scale = Vector2.ONE / (rig.get_node("Rig") as Node2D).scale.x
	viewport.add_child(rig)

	var player: AnimationPlayer = rig.get_node("AnimationPlayer")
	# Without this the mixer advances by a frame delta between seek() and the
	# capture, and every fast animation is sampled slightly late.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for anim_name in SEQUENCES:
		player.play(anim_name)
		for i in range(SEQUENCES[anim_name]):
			player.seek(i * FRAME_MS / 1000.0, true, true)
			await process_frame
			await process_frame
			var img := viewport.get_texture().get_image()
			img.save_png("%s/%s_%03d.png" % [out_dir, anim_name.to_lower(), i])
			for sprite in rig.find_children("*", "Sprite2D"):
				if sprite.name == "Crest":
					continue
				var xf: Transform2D = sprite.global_transform
				print("PAWNCH_XFORM %s %d %s %.4f %.4f %.6f %.6f" % [
					anim_name, i, sprite.name, xf.origin.x - ORIGIN.x, xf.origin.y - ORIGIN.y,
					xf.get_rotation(), xf.get_scale().x])
		print("PAWNCH_RIG rendered %s %d frames" % [anim_name, SEQUENCES[anim_name]])

	# The crest is rigid on the head bone: its global transform must stay a fixed
	# offset from the head's through every animation, including Dying. Drift alone
	# proved that once before and shipped a crest lying on its side anyway --
	# rigidity says nothing about orientation, so that is checked separately below.
	rig.show_crest = true
	var crest: Node2D = rig.get_node("%Crest")
	var head_bone: Node2D = crest.get_parent()
	var head_sprite: Node2D = head_bone.get_node("Head")
	var checks_ok := true

	# Upright at rest: world rotation ~0, not the ~271 deg it renders at when the
	# crest has no compensating rotation of its own.
	player.play("Idle")
	player.seek(0.0, true, true)
	await process_frame
	await process_frame
	var rest_rot := wrapf(crest.global_transform.get_rotation(), -PI, PI)
	var upright_ok := absf(rest_rot) < 0.01
	checks_ok = checks_ok and upright_ok
	print("PAWNCH_CREST_UPRIGHT rot_deg=%.4f %s" % [rad_to_deg(rest_rot), "PASS" if upright_ok else "FAIL"])

	for anim_name in ["Slashing", "Dying"]:
		player.play(anim_name)
		var worst_pos := 0.0
		var worst_rot := 0.0
		var length := player.get_animation(anim_name).length
		var t := 0.0
		while t <= length:
			player.seek(t, true, true)
			await process_frame
			var local := head_bone.global_transform.affine_inverse() * crest.global_position
			worst_pos = maxf(worst_pos, local.distance_to(crest.position))
			# Orientation must track the head sprite's, not just the head bone's --
			# a fixed local rotation on the crest would drift as the bone chain moves.
			var d_rot: float = wrapf(
				crest.global_transform.get_rotation() - head_sprite.global_transform.get_rotation(),
				-PI, PI)
			worst_rot = maxf(worst_rot, absf(d_rot))
			t += 0.01
		var rot_ok := worst_rot < 0.01
		checks_ok = checks_ok and rot_ok
		print("PAWNCH_CREST %s max_drift_px=%.4f max_rot_delta_deg=%.4f %s" % [
			anim_name, worst_pos, rad_to_deg(worst_rot), "PASS" if rot_ok else "FAIL"])

	if not checks_ok:
		push_error("PAWNCH_CREST orientation check failed")
		quit(1)

	# Cue markers must survive the rig replacement (task: cue markers on the timeline).
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	var fired: Array[String] = []
	rig.cue_fired.connect(func(n: String) -> void: fired.append(n))
	rig.play_cue_demo()
	var deadline := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline:
		await process_frame
	print("PAWNCH_CUES %s" % ", ".join(fired))
	quit(0)
